# Modèle Releases + Pages (aligné sur modules-sory-os/sory-os-apt)

Ce dépôt suit le même principe que `modules-sory-os/sory-os-apt` (format
`.pkgar` Redox), adapté aux paquets **`.deb`** SoryOS.

## Pourquoi deux canaux ?

| Canal | Limite | Rôle |
|-------|--------|------|
| **GitHub Pages** | ~1 Go / site | Catalogue léger : `index.json` signé, clés, `dists/stable/` — **jamais les `.deb`** |
| **GitHub Release** | 1000 assets, < 2 Go / fichier | **Dépôt binaire** : tous les `.deb` immuables par tag |

## Qui build quoi ?

| Machine | Action |
|---------|--------|
| **CI GitHub Actions** | Clone sources → `dpkg-buildpackage` → publie Release + Pages |
| **PC dev (RAM limitée)** | **Ne compile pas** les apps COSMIC / SoryOS |
| **`make iso` (soryos)** | Télécharge catalogue (Pages) + `.deb` (Release) → `apt install` dans chroot |

## Chaîne CI (équivalent `build-cosmic.yml` pkgar)

1. `cosmic-apps/manifest.json` — liste des composants (comme `redox-apps/manifest.json`)
2. `config/cosmic.toml` — règles `source` / cache Release (`release_binary=1`)
3. `build-deb-release.yml` — build matrix sur runners GitHub, publish Release
4. `publish-pages.yml` — copie index + dists sur Pages (sans `pool/`)
5. `update-deb-release.yml` — mise à jour incrémentale (comme `update-release.yml`)

## Chaîne ISO

```bash
cd sory-os/iso
make DISTRO_CODE=soryos DISTRO_VERSION=24.04 SORYOS_RELEASE_TAG='<tag>'
```

1. `scripts/soryos-release-pool.sh` → `download-release-pool.sh`
2. Pages : vérifie `index.json` + signature + métadonnées APT
3. Release : télécharge chaque `.deb` (BLAKE3 + taille)
4. Chroot : `apt-get install` depuis `file://$(BUILD)/soryos-apt`

## Écart restant vs modules-sory-os (pkgar)

| Élément | modules-sory-os | sory-os/sory-os-apt |
|---------|-----------------|---------------------|
| Format binaire | `.pkgar` | `.deb` |
| Sources CI | `gitlab.com/sory-os/cosmic-epoch` via recettes Redox | `github.com/sory-os-org/cosmic-epoch` via `prepare-cosmic-sources.sh` |
| Consommateur ISO | `redox` + `REPO_BINARY=1` | `iso` + `download-release-pool.sh` |

Voir `docs/LOCAL-BUILD-POLICY.md` pour la liste complète local vs CI.
