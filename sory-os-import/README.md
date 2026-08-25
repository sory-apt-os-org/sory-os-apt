# SoryOS — Import automatique vers GitLab

Scripts pour importer des dépôts vers le groupe **sory-os.org** sur GitLab.com.

| Script | Source | Destination |
|--------|--------|-------------|
| `redox-auto-import.sh` | `gitlab.redox-os.org/redox-os` | `gitlab.com/sory-os` |
| `github-auto-import.sh` | `github.com/sory-os-org` | `gitlab.com/sory-os.org` |

## Prérequis

- `curl` et `jq`
- **GitLab** : token avec scopes `api` + `write_repository` (ou `glab auth login`)
- **GitHub** : token avec accès lecture sur `sory-os-org` (ou `gh auth login`)

## Configuration rapide

```bash
# GitLab (glab déjà connecté en sory.os.dev)
export GITLAB_TOKEN="$(glab config get token -h gitlab.com)"

# GitHub
export GITHUB_TOKEN="$(gh auth token)"
```

## Import GitHub → GitLab (sory-os-org)

```bash
cd sory-os-apt
chmod +x sory-os-import/github-auto-import.sh

# Simulation (liste sans créer)
DRY_RUN=1 bash sory-os-import/github-auto-import.sh

# Import réel (~110 dépôts, quelques minutes)
bash sory-os-import/github-auto-import.sh
```

Variables optionnelles :

| Variable | Défaut | Description |
|----------|--------|-------------|
| `GITHUB_ORG` | `sory-os-org` | Organisation GitHub source |
| `GITLAB_GROUP` | `sory-os.org` | Groupe GitLab cible |
| `IMPORT_DELAY` | `2` | Pause (s) entre chaque import |
| `DRY_RUN` | `0` | `1` = ne pas appeler l'API d'import |

## Import Redox → GitLab (sory-os)

```bash
export GITLAB_TOKEN="..."
bash sory-os-import/redox-auto-import.sh
```

## Ce que fait `github-auto-import.sh`

1. Vérifie `curl`, `jq`, tokens GitLab + GitHub
2. Résout l'ID du groupe `sory-os.org` sur GitLab
3. Liste tous les dépôts de `sory-os-org` (pagination GitHub)
4. Pour chaque dépôt : skip si déjà présent ou import en cours
5. Lance l'import GitLab via `import_url` (git mirror depuis GitHub)
6. Affiche un résumé

Les imports GitLab sont **asynchrones** : le script lance l'import ; la copie complète peut prendre plusieurs minutes par gros dépôt.

## Résultat

👉 https://gitlab.com/sory-os.org
