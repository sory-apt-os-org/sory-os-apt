# GitLab CI — SoryOS APT (source de vérité)

GitHub Actions n’est **plus fiable** (compte `sory-os` bloqué).  
Toute la CI `.deb`, Releases et Pages passe par **GitLab** :

| Ressource | URL |
|-----------|-----|
| Dépôt | https://gitlab.com/sory-os.org/sory-os-apt |
| Releases | https://gitlab.com/sory-os.org/sory-os-apt/-/releases |
| Pages (catalogue) | https://sory-os-org.gitlab.io/sory-os-apt/ |

## Fichiers CI

| GitHub (legacy) | GitLab (actif) |
|-----------------|----------------|
| `.github/workflows/build-deb-release.yml` | `scripts/gitlab-ci/build-deb-release.sh` |
| `.github/workflows/build-cosmic-utils-release.yml` | `scripts/gitlab-ci/build-cosmic-utils-release.sh` |
| `.github/workflows/publish-pages.yml` | `scripts/gitlab-ci/publish-pages.sh` |
| `.github/workflows/update-deb-release.yml` | `scripts/gitlab-ci/update-deb-release.sh` |
| — | `.gitlab-ci.yml` |
| — | `scripts/soryos-urls.sh` (URLs GitLab par défaut) |

## Variables CI/CD (Settings → CI/CD → Variables)

| Variable | Masquée | Description |
|----------|---------|-------------|
| `SORYOS_GPG_PRIVATE_KEY` | oui | Clé GPG apt@soryos.local (armored) |
| `SORYOS_INDEX_PRIVATE_KEY_PEM` | oui | Clé PEM signature `index.json` |
| `GITLAB_TOKEN` | oui | Token projet (api + write_repository) si job token insuffisant |

## Lancer un pipeline (Run pipeline)

Variable **`SORYOS_PIPELINE`** :

| Valeur | Action |
|--------|--------|
| `desktop` | Build Release desktop (`build-deb-release`) |
| `cosmic-utils` | Build Release cosmic-utils phase 1 |
| `pages` | Publier catalogue Pages depuis `SORYOS_RELEASE_TAG` |
| `update` | Mise à jour incrémentale (nécessite `SORYOS_COMPONENTS`) |

Variables optionnelles :

```
SORYOS_RELEASE_TAG=soryos-deb-test-2026.08.13
SORYOS_CU_TAG=soryos-cosmic-utils-2026.08.22
SORYOS_COMPONENTS=all
SORYOS_CU_COMPONENTS=phase1
SORYOS_FORCE_REBUILD=false
```

### Exemples

**Build desktop complet :**
```
SORYOS_PIPELINE=desktop
SORYOS_RELEASE_TAG=soryos-deb-test-2026.08.14
```

**Build cosmic-utils phase 1 :**
```
SORYOS_PIPELINE=cosmic-utils
SORYOS_CU_TAG=soryos-cosmic-utils-2026.08.22
```

**Publier Pages après Release :**
```
SORYOS_PIPELINE=pages
SORYOS_RELEASE_TAG=soryos-deb-test-2026.08.14
```

**Mise à jour incrémentale :**
```
SORYOS_PIPELINE=update
SORYOS_COMPONENTS=cosmic-greeter pop-launcher
SORYOS_RELEASE_TAG=soryos-deb-test-2026.08.13
```

## Schedule

Pipeline planifié `cosmic-utils-schedule` : build cosmic-utils phase 1 (comme GitHub cron).

## ISO live

`iso/config/soryos/24.04.mk` pointe vers GitLab Pages + Release :

```
SORYOS_PAGES_BASE_URL=https://sory-os-org.gitlab.io/sory-os-apt
SORYOS_RELEASE_INDEX_URL=https://gitlab.com/sory-os.org/sory-os-apt/-/releases/<tag>/downloads/index.json
```

Build ISO : `make DISTRO_CODE=soryos iso`

## Activer GitLab Pages

1. Projet → Settings → Pages → activer
2. Lancer pipeline `SORYOS_PIPELINE=pages` après une Release publiée
3. Vérifier https://sory-os-org.gitlab.io/sory-os-apt/index.json

## Clones sources (CI)

Tous les clones utilisent `gitlab.com/sory-os.org/*` via `scripts/soryos-urls.sh`  
Auth : `CI_JOB_TOKEN` ou `GITLAB_TOKEN`.

Pour forcer GitHub (legacy) : `SORYOS_PLATFORM=github`
