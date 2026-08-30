# CI — Problème actuel (2026-08-29)

## Contexte
- Ancien CI `sory-os-org/sory-os-apt` bloqué `workflow_dispatch 422` (`Actions disabled for user`)
- CI `gitlab.com/sory-os.org/sory-os-apt` bloqué `Identity verification required` (SMS `+224` non reçu, même avec runner local `soryos-local` `55538160`)
- Migration vers nouveau **GitHub** `sory-apt-os-org/sory-os-apt` (`sorydev`, `public`, `Actions enabled`)

## Nouveau dépôt
- Org : `sory-apt-os-org` (`id 321947897`, `2026-08-27`)
- Repo : `sory-apt-os-org/sory-os-apt` (`id 1349032329`, `main` `75cfb8e`)
- Pages : `https://sory-apt-os-org.github.io/sory-os-apt/` (`build_type=workflow`, `201`)
- Release : `https://gitlab.com/sory-os.org/sory-os-apt/releases`
- Secrets posés : `SORYOS_GPG_PRIVATE_KEY`, `SORYOS_INDEX_PRIVATE_KEY_PEM` (`2026-08-27T23:55Z`)

## Import GitHub → GitHub
- Source `sory-os-org` `109` repos → Dest `sory-apt-os-org`
- État : `94/109` (`66` `✓ créé, push --mirror`, `7` `skip` `size>0`, `36` erreurs `description control characters` / `clone timeout`)
- Script : `/tmp/opencode/github-to-github-import.sh` (`SRC_ORG=sory-os-org` `DEST_ORG=sory-apt-os-org`, `timeout 300/600`)
- Log : `/tmp/import4.log` (`wizard` `✓`, `cosmic-app-template` `✓`, `libcosmic` `size=0` re-push fix `SKIP_CREATE`)
- Reste `15` repos à importer (réseau Guinée lent)

## CI GitHub Actions
### Legacy push → désactivé (fix `Release.gpg testing`)
- `apt-repository.yml` `push: [main]` → `push: [__disabled__]` + `SORYOS_SUITES=stable` (était `stable testing nightly` → `FAIL: Release.gpg signature is invalid for testing` `0s`)
- `apt-publish.yml` → `(disabled)` `push: [__disabled__]`
- `build-cosmic-utils-release.yml` `push: [main]` → `push: [__disabled__]` + `schedule: */30` supprimé (restait `0 4`/`0 16`)
- `build-cosmic.yml` `push: [__disabled__]` ajouté
- Vérifié `gh api workflows` → `3` `disabled_manually`, plus de `push` sur `main` (`75cfb8e`)

### Build en cours
- `Build SoryOS Debian Release` `33128060200` `workflow_dispatch` `soryos-deb-test-2026.08.27` `cosmic-sound-theme` `cancelled 36m37s` (bloqué `Prepare cosmic sources` `soryos-urls.sh` `SORYOS_PLATFORM=gitlab` → `gitlab.com` `Could not resolve host`, fix `077da5c` → `SORYOS_PLATFORM=github`)
- `Build cosmic-utils` `33278352933` `workflow_dispatch` `22:20:44Z` `queued 1h47m+` `Waiting for a runner to pick up this job...` `labels: [ubuntu-latest]` `runner_name: ""` — pas `in_progress`, file `schedule */30` avait empilé `5` `queued` (`20:01`→`22:01`), `4` `cancelled`, reste `1` `queued` (hosted runner `free` `public` en attente)
- Ancien `soryos-urls.sh` `SORYOS_PLATFORM=gitlab` → `https://gitlab.com/sory-os.org/...` ; nouveau `github` → `https://gitlab.com/sory-os.org/...` (vendors `sory-os-org` restent sur GitHub, `APT` sur `sory-apt-os-org`)

## Cause du blocage actuel
- **CI** : `queued` pas `bloqué` sur `Cloning into .../distinst` — le `in_progress` précédent l'était (`36m` sur `xdg-shell-wrapper` → `distinst`), celui-ci attend juste le runner `ubuntu-latest` (file `schedule` vidée, plus d'empilage)
- **Import** : `clone timeout` / `description` avec `\n` (`jq -Rs` à corriger)

## Prochaines étapes
1. Laisser `33278352933` être pické (`5–10 min`) ou `gh run cancel` + relancer `build-deb-release` plus léger
2. Finir import `15` restants (`tail -f /tmp/import4.log`, corriger `libcosmic` `size=0` si besoin `git push --mirror` manuel)
3. Déclencher `publish-pages.yml` après `Release` (`gh workflow run publish-pages.yml -f release_tag=...`)
