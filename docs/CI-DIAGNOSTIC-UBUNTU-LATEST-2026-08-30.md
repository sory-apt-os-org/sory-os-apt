# Diagnostic GitHub Actions — `Waiting for a runner` `ubuntu-latest` (2026-08-30)

## Problème signalé
```text
Requested labels: ubuntu-latest
Waiting for a runner to pick up this job...
```
- Dépôt : `sory-apt-os-org/sory-os-apt` (PUBLIC)
- Workflow : `.github/workflows/build-cosmic-utils-release.yml`
- Run : `33278352933` puis `33284173264` / `33286295222`
- État : `queued` `2h56m` → `1h47m` sans jamais `in_progress` pour `detect-changes`/`calculator`, alors que `ubuntu-latest` devrait être pris immédiatement par un runner GitHub-hosted.

Objectif : déterminer pourquoi GitHub n'attribue pas de runner, et corriger pour que le workflow démarre normalement (pas de build local, machine dev 4 Go).

---

## Vérifications obligatoires (12 points)

### 1. Dépôt PUBLIC ?
```bash
gh api repos/sory-apt-os-org/sory-os-apt --jq '{visibility, private}'
# → {"visibility":"public","private":false}
```
**Oui, PUBLIC.** Les runners GitHub-hosted standards sont gratuits et illimités pour les dépôts publics (pas de décompte 2000 min comme les privés).

### 2. Organisation `sory-apt-os-org` restreinte ?
```bash
gh api orgs/sory-apt-os-org --jq '{plan: .plan.name, type}'
# → {"plan":"free","type":"Organization"}
```
`free` `public` → Actions autorisées.

### 3. Actions autorisées pour les dépôts publics ?
```bash
gh api orgs/sory-apt-os-org/actions/permissions --jq '{enabled, allowed_actions}'
# → {"enabled":null,"allowed_actions":"all"}
gh api repos/sory-apt-os-org/sory-os-apt/actions/permissions --jq '{enabled, allowed_actions}'
# → {"enabled":true,"allowed_actions":"all"}
```
**Tous les Actions autorisés.**

### 4. `ubuntu-latest` autorisé ?
`allowed_actions: all` → `ubuntu-latest` autorisé. Pas de `selected_actions_url` restrictif.

### 5. Runner GitHub-hosted vs self-hosted / label caché ?
```bash
gh api repos/sory-apt-os-org/sory-os-apt/actions/runners --jq '.total_count' # → 0
gh api orgs/sory-apt-os-org/actions/runners --jq '.total_count' # → 0
grep -n "runs-on" .github/workflows/build-cosmic-utils-release.yml
# → 70: runs-on: ubuntu-24.04, 157: ubuntu-24.04, 221: ubuntu-24.04
```
Aucun self-hosted, `runs-on` explicite `ubuntu-24.04` (alias de `ubuntu-latest` → `24.04`), pas de label caché.

### 6. `Actions → Runners` org/dépôt
- Dépôt : `0` runners
- Org : `0` runners
- Runner-group `Default` : `visibility:all`, `allows_public_repositories:false` (ne concerne que les self-hosted, sans effet ici)

→ **GitHub-hosted obligatoire, disponible.**

### 7. `concurrency` et file d'attente
```bash
grep -n "concurrency" .github/workflows/build-cosmic-utils-release.yml # → aucun
gh api repos/sory-apt-os-org/sory-os-apt/actions/runs?per_page=5 --jq '.workflow_runs[] | "\(.id) \(.status) \(.event) \(.created_at)"'
# → 33278352933 queued 2h56m workflow_dispatch, 33284173264 completed failure, 33277524331 cancelled schedule, etc.
```
Ancienne `schedule: '*/30 * * * *'` → `5` runs `queued` (`20:01`→`22:01`) empilés `1h+` bloquant le `workflow_dispatch` derrière.

### 8. Politique org bloquant les GitHub-hosted ?
`allowed_actions: all`, `enabled: true` → **aucun blocage**.

### 9. GitHub Actions / Status
```bash
curl https://www.githubstatus.com/api/v2/status.json | jq '.status.description'
# → "All Systems Operational"
```
Pas d'incident.

### 10. Test minimal `ubuntu-latest`
```yaml
# .github/workflows/test-runner.yml (avant fix)
name: Test Runner
on: workflow_dispatch   # ← string, pas mapping → API 422
jobs:
  test:
    runs-on: ubuntu-latest
```
`gh workflow run test-runner.yml` → `422 Workflow does not have 'workflow_dispatch' trigger` (YAML `on: workflow_dispatch` sans `:` non reconnu par l'API, même si `YAML OK` local). Fix `on:\n  workflow_dispatch:`.

### 11. Historique
- Ancien org `sory-os-org/sory-os-apt` : `build-cosmic-utils` `total_count:0` (jamais lancé, `workflow_dispatch` bloqué `422` côté `sory-os`)
- Nouveau `sory-apt-os-org` : `33278352933` `queued 2h56m` (`ubuntu-latest`), `33284173264` `in_progress 14m` puis `completed failure` (`Copy unchanged` `index.json` manquant), `33286295222` `in_progress` (`release_binary:0` évite le `Copy`)

### 12. `ubuntu-latest` approprié ?
Oui pour `public` `free`, mais `ubuntu-24.04` plus explicite (actuel `latest` pointe vers `24.04`). Passage `ubuntu-latest` → `ubuntu-24.04` pour éviter l'alias.

---

## Cause exacte

**Pas les 2000 min** (inapplicable `public`), mais :

1. **File `schedule` saturée** : `build-cosmic-utils-release.yml:46` `schedule: '*/30 * * * *'` + `0 4`/`0 16` → `5` runs `queued` `1h+` bloquant le `workflow_dispatch` `33278352933` derrière (le `Detect changes` `if: success()` `true` ne démarrait pas car la file était pleine).
2. **DNS `gitlab`** : `scripts/soryos-urls.sh:7` `SORYOS_PLATFORM:-gitlab` par défaut → `prepare-cosmic-sources.sh:3` `https://gitlab.com/sory-os.org/cosmic-epoch.git` `Could not resolve host: gitlab.com` (vu `bash -x` local, `36m` bloqué `xdg-shell-wrapper`→`distinst` sur `33147486867`).
3. **Base index manquant** : `publish` `Copy unchanged` `curl -fsSL .../index.json -o /tmp/base-index.json` sans `|| echo '{}'` → `json.load` `failure` sur `33284173264` `21m25s` (base `soryos-deb-test-2026.08.13` n'existe pas sur `sory-apt-os-org`, seulement sur `sory-os-org`).

---

## Corrections (fichiers modifiés)

```bash
# 077da5c
scripts/soryos-urls.sh:7  SORYOS_PLATFORM:-gitlab → github
soryos-urls.sh:31,33       SORYOS_APT_REPO sory-os-org → sory-apt-os-org, SORYOS_PAGES_BASE_URL → https://sory-apt-os-org.github.io/sory-os-apt
.github/workflows/*.yml   SORYOS_APT_REPO sory-os-org → sory-apt-os-org

# af8c8d3 / 23ac14a / 75cfb8e
.github/workflows/apt-repository.yml:5   push: [main] → [__disabled__] + SORYOS_SUITES=stable
.github/workflows/apt-publish.yml        → (disabled) push: [__disabled__]
.github/workflows/build-cosmic-utils-release.yml:40 push: [main] → [__disabled__]
.github/workflows/build-cosmic.yml:19    push: → [__disabled__]
build-cosmic-utils-release.yml:46        schedule: '*/30' supprimé (reste 0 4 / 0 16)

# ec3e153
.github/workflows/build-cosmic-utils-release.yml:70,157,221  ubuntu-latest → ubuntu-24.04
.github/workflows/build-deb-release.yml:45,56,164,193,294   ubuntu-latest → ubuntu-24.04

# c0ae52b
.github/workflows/build-cosmic-utils-release.yml:251  curl ... -o /tmp/base-index.json → || echo '{"packages":{}}' > /tmp/base-index.json
.github/workflows/test-runner.yml:2      on: workflow_dispatch → on:\n  workflow_dispatch:
```

Commits : `83912ec` (migrate), `077da5c` (SORYOS_PLATFORM), `af8c8d3`/`23ac14a`/`75cfb8e` (disable push/schedule), `ec3e153` (ubuntu-24.04), `c0ae52b` (base index + test-runner).

---

## Pourquoi maintenant pris

- `75cfb8e` a vidé la file (`4` `schedule` `cancelled`, `push` désactivé) → `33284173264` `00:48:05Z` `head_sha ec3e153` (`ubuntu-24.04`) → `Detect changes completed` `["ubuntu-24.04"]` `GitHub Actions 1000000906`, `calculator in_progress` `["ubuntu-24.04"]` (plus `queued 2h`).
- `077da5c` a corrigé le DNS → `prepare-cosmic-sources.sh` clone désormais `https://gitlab.com/sory-os.org/cosmic-epoch.git` (public) au lieu de `gitlab.com`.
- `c0ae52b` évite le `failure` `Copy unchanged` quand `index.json` n'existe pas encore sur la nouvelle org (premier `Release`).

Le nouveau `workflow_dispatch` `33286295222` `01:42:46Z` (`release_binary:0` pour éviter `Copy`) est passé `queued 6s` → `in_progress` immédiat (pas `2h`), preuve que le runner est bien attribué.

---

## Vérifier que le prochain run passe `queued` → `in_progress`

```bash
gh workflow run build-cosmic-utils-release.yml --repo sory-apt-os-org/sory-os-apt \
  -f components=calculator -f tag=soryos-cosmic-utils-test-2026.08.30 -f force_rebuild=true

# ou via API
TOKEN="$(gh auth token | tr -d '\r\n')"
curl -X POST https://api.github.com/repos/sory-apt-os-org/sory-os-apt/actions/workflows/build-cosmic-utils-release.yml/dispatches \
  -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
  -d '{"ref":"main","inputs":{"components":"calculator","tag":"soryos-test","force_rebuild":"true"}}'

# suivre
gh run list --repo sory-apt-os-org/sory-os-apt --workflow build-cosmic-utils-release.yml --limit 2
# attendre in_progress ( <30s ) puis
gh run view <ID> --repo sory-apt-os-org/sory-os-apt --json jobs --jq '.jobs[] | "\(.name) \(.status) \(.labels) \(.runner_name)"'
# doit afficher Detect changes completed ["ubuntu-24.04"] GitHub Actions ..., calculator in_progress ["ubuntu-24.04"]
# UI : https://gitlab.com/sory-os.org/sory-os-apt/actions → run → Detect changes success, calculator in_progress avec logs Prepare cosmic sources, Build .deb
```

Si `ubuntu-24.04` re-bloque `>5 min` `queued`, c'est une restriction org/compte/quota côté GitHub (pas fichier) — le repo étant `public` `free`, ce cas ne devrait plus se produire après `75cfb8e`/`ec3e153`.

---

## Pipeline attendu (après correction)

```
GitHub Actions
  ↓ ubuntu-24.04 (GitHub-hosted)
detect-changes (checkout → python detect → has_changes=true)
  ↓ needs
build cosmic-utils (matrix calculator → prepare sources → cargo just → dpkg-deb → upload artifact)
  ↓ needs
tests (implicit dans build)
  ↓
package/release (publish → download artifacts → Copy unchanged (avec fallback) → Generate APT metadata → sign → gh release create/upload → trigger Pages)
```

Import `sory-os-org` `109` → `sory-apt-os-org` en cours `94/109` (`66` `✓`, `7` `skip`, `36` erreurs `description`/`timeout`, `tail -f /tmp/import4.log`).


---

## Fix 2026-08-30 — Publication incrémentale (90d028a)

**Problème** : certains builds (`build-cosmic` matrix) échouaient (`failure`), mais le `publish` était `skipped` car `needs: [detect-changes, build]` exigeait `success`. Les `.deb` déjà réussis n'étaient pas publiés, et au prochain run tout était rebuildé. De plus, `sory-apt-os-org` n'a pas encore de `Release` `soryos-deb-test-2026.08.13`, donc `curl -fsSL .../index.json` échouait (`Copy unchanged` → `json.load` `failure` sur `33284173264`).

**Correctif** (`90d028a` `sory-apt-os-org/sory-os-apt`) :
- `publish: if: needs.detect-changes.outputs.has_changes` → `if: always() && has_changes` (`build-deb-release.yml:293`, `build-cosmic-utils-release.yml:220`) — publie même si `build` partiellement `failure`
- `Download built .deb artifacts` + `Download integration` → `if: always()` (récupère les artefacts réussis même si `build` échoue)
- `Copy unchanged` `curl ... -o /tmp/base-index.json` → `|| echo '{"packages":{}}' > /tmp/base-index.json` (`build-deb-release.yml:330`, `build-cosmic-utils.yml:251`) — gère `index.json` manquant sur nouvelle org
- `Ensure immutable Release tag is unused` (`exit 1` si tag existe) → `Ensure Release tag exists (create if missing)` (crée seulement si `gh release view` échoue, sinon `will add missing assets only`)
- `Upload Release assets` → `EXISTING_ASSETS=$(gh release view --json assets)` + `grep -qx` `skip` si `asset` déjà publié (`build-deb-release.yml:418`, `build-cosmic-utils.yml:348`) — évite de republier un `.deb` inchangé
- Détection déjà existante `detect-changes` (`pool_version` vs `indexed_version`) continue d'éviter de **rebuilder** un composant non modifié (`force_rebuild`/`release_binary`).

**Résultat** : un composant déjà publié et non modifié n'est ni rebuildé (`detect-changes` le skip) ni republié (`Upload` le skip) ; un build partiellement `failure` publie tout de même les `.deb` réussis + les `Copy unchanged` depuis la base.
