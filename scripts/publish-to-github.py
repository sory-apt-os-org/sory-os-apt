#!/usr/bin/env python3
"""
publish-to-github.py — Pousse pool/ + dists/ vers GitHub Pages via API Git Database
Évite les timeouts HTTPS de git push en uploadant blob par blob via l'API.
"""

import os, sys, json, base64, glob, subprocess, time, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOKEN_FILE = os.path.join(ROOT, '..', 'token-classic')

if not os.path.exists(TOKEN_FILE):
    print("ERROR: token-classic not found at", TOKEN_FILE)
    sys.exit(1)

with open(TOKEN_FILE) as f:
    TOKEN = f.read().strip()

OWNER = "sory-x"
REPO = "soryos-apt"
BRANCH = "main"
API = f"https://api.github.com/repos/{OWNER}/{REPO}"
HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/vnd.github.v3+json"
}

FORCE = '--force' in sys.argv
DRY_RUN = '--dry-run' in sys.argv

def ghreq(method, url, data=None):
    """Fait une requête API GitHub et retourne le JSON parsé."""
    req = urllib.request.Request(url, method=method, headers=HEADERS)
    if data is not None:
        req.data = json.dumps(data).encode('utf-8')
    try:
        with urllib.request.urlopen(req) as resp:
            body = resp.read().decode('utf-8')
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as e:
        body = e.read().decode('utf-8')
        print(f"  ✗ HTTP {e.code}: {body[:200]}")
        return None
    except Exception as e:
        print(f"  ✗ Erreur requête: {e}")
        return None

# Vérifications
pool_dir = os.path.join(ROOT, 'pool')
dists_dir = os.path.join(ROOT, 'dists')
for d in [pool_dir, dists_dir]:
    if not os.path.isdir(d):
        print(f"ERROR: {d} not found")
        sys.exit(1)

debs = sorted(glob.glob(os.path.join(pool_dir, '**/*.deb'), recursive=True))
print(f"Pool: {len(debs)} .deb files")
print()

###########################################################################
# Étape 1 : Récupérer l'état actuel
###########################################################################
print("═══ Étape 1/6 : Récupération état distant ═══")

def get_ref():
    data = ghreq('GET', f"{API}/git/refs/heads/{BRANCH}")
    if data and 'object' in data:
        return data['object']['sha']
    return None

def get_tree(commit_sha):
    data = ghreq('GET', f"{API}/git/commits/{commit_sha}")
    if data and 'tree' in data:
        return data['tree']['sha']
    return None

latest_sha = get_ref()
if latest_sha:
    print(f"→ Dernier commit: {latest_sha[:8]}")
    tree_sha = get_tree(latest_sha)
    print(f"→ Arbre existant: {tree_sha[:8]}")
else:
    print("→ Aucun commit existant")
    tree_sha = None

###########################################################################
# Étape 2 : Uploader les fichiers en blobs
###########################################################################
print()
print("═══ Étape 2/6 : Upload des fichiers ═══")

ALL_FILES = []
for dirpath, _, filenames in os.walk(dists_dir):
    for fn in filenames:
        full = os.path.join(dirpath, fn)
        rel = os.path.relpath(full, ROOT)
        ALL_FILES.append((full, rel))

for deb in debs:
    rel = os.path.relpath(deb, ROOT)
    ALL_FILES.append((deb, rel))

total = len(ALL_FILES)
uploaded = 0
blob_entries = []

for idx, (full_path, rel_path) in enumerate(ALL_FILES, 1):
    size = os.path.getsize(full_path)
    size_mb = size / 1048576
    pct = idx * 100 // total
    print(f"\r  [{pct:3d}%] Upload {rel_path} ({size_mb:.0f} Mo)...", end='')

    if DRY_RUN:
        blob_entries.append({'path': rel_path, 'mode': '100644', 'type': 'blob', 'sha': 'dry-run'})
        uploaded += 1
        continue

    with open(full_path, 'rb') as f:
        b64_content = base64.b64encode(f.read()).decode('utf-8')

    data = ghreq('POST', f"{API}/git/blobs",
                 {'content': b64_content, 'encoding': 'base64'})
    if data is None or 'sha' not in data:
        print(f"\n  ✗ Échec upload {rel_path}")
        sys.exit(1)

    blob_entries.append({
        'path': rel_path,
        'mode': '100644',
        'type': 'blob',
        'sha': data['sha']
    })
    uploaded += 1

print()
print(f"✓ {uploaded} fichiers uploadés")
print(f"  Dernier SHA: {blob_entries[-1]['sha'][:8]} (fichier: {blob_entries[-1]['path']})")

###########################################################################
# Étape 3 : Construire l'arbre
###########################################################################
print()
print("═══ Étape 3/6 : Construction de l'arbre ═══")

if DRY_RUN:
    new_tree_sha = 'dry-run'
    print("→ (dry-run) Tree SHA: dry-run")
else:
    tree_payload = {'tree': blob_entries}
    if tree_sha:
        tree_payload['base_tree'] = tree_sha
    
    data = ghreq('POST', f"{API}/git/trees", tree_payload)
    if data is None or 'sha' not in data:
        print("✗ Échec création arbre")
        sys.exit(1)
    new_tree_sha = data['sha']
    print(f"→ Arbre: {new_tree_sha[:8]}")

###########################################################################
# Étape 4 : Créer le commit
###########################################################################
print()
print("═══ Étape 4/6 : Création du commit ═══")

from datetime import datetime, timezone
timestamp = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')
commit_msg = f"Update APT repository ({len(debs)} packages) — {timestamp}"

if DRY_RUN:
    new_commit_sha = 'dry-run'
    print("→ (dry-run) Commit:", commit_msg)
else:
    commit_payload = {
        'message': commit_msg,
        'tree': new_tree_sha,
    }
    if latest_sha:
        commit_payload['parents'] = [latest_sha]
    
    data = ghreq('POST', f"{API}/git/commits", commit_payload)
    if data is None or 'sha' not in data:
        print("✗ Échec création commit")
        sys.exit(1)
    new_commit_sha = data['sha']
    print(f"→ Commit: {new_commit_sha[:8]}")

###########################################################################
# Étape 5 : Mettre à jour la branche
###########################################################################
print()
print(f"═══ Étape 5/6 : Mise à jour de {BRANCH} ═══")

if DRY_RUN:
    print(f"→ (dry-run) Branche {BRANCH} ← {new_commit_sha}")
else:
    data = ghreq('PATCH', f"{API}/git/refs/heads/{BRANCH}",
                 {'sha': new_commit_sha, 'force': FORCE})
    if data is None:
        print("✗ Échec mise à jour de la branche")
        sys.exit(1)
    ref_name = data.get('ref', '?')
    print(f"→ Branche mise à jour: {ref_name}")

###########################################################################
# Étape 6 : Résumé
###########################################################################
print()
print("═══ Étape 6/6 : Résultat ═══")
print()
print(f"  Dépôt   : https://github.com/{OWNER}/{REPO}")
print(f"  Pages   : https://{OWNER}.github.io/{REPO}")
print(f"  Index   : https://{OWNER}.github.io/{REPO}/dists/stable/main/binary-amd64/Packages")
print(f"  Fichiers: {uploaded} ({len(debs)} .deb)")
print()
print("✓ Terminé.")
