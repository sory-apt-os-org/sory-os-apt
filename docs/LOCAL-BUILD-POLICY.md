# Politique de build local vs CI

Ce document liste **tout ce qui doit être compilé sur les runners GitHub Actions**
et **ce qui peut (ou doit) être fait sur un PC de développement** avec RAM limitée.

Sources COSMIC : dépendances `git = "https://github.com/sory-os-org/libcosmic.git"` dans chaque
app (même modèle que Pop!_OS avec `pop-os/libcosmic`, org remplacée par `sory-os-org`).
(via `scripts/prepare-cosmic-sources.sh`, modèle recettes Redox).

---

## Règle d'or

| Où | Quoi |
|----|------|
| **CI GitHub Actions** | Tous les `.deb` SoryOS / COSMIC |
| **PC local** | ISO, téléchargement du pool Release, validation, dev léger |
| **Jamais en local** | `dpkg-buildpackage`, `cargo build --release` pour empaquetage, `build-packages.sh` complet |

---

## Inventaire complet — build **CI uniquement** (51 paquets)

### A. Composants COSMIC — `dpkg-buildpackage` (28)

Sources : `cosmic-epoch/<composant>/` sur GitLab.

| # | Composant | Méthode CI |
|---|-----------|------------|
| 1 | cosmic-applets | dpkg-buildpackage |
| 2 | cosmic-applibrary | dpkg-buildpackage |
| 3 | cosmic-bg | dpkg-buildpackage |
| 4 | cosmic-comp | dpkg-buildpackage |
| 5 | cosmic-edit | dpkg-buildpackage |
| 6 | cosmic-files | dpkg-buildpackage |
| 7 | cosmic-greeter | dpkg-buildpackage |
| 8 | cosmic-icons | dpkg-buildpackage |
| 9 | cosmic-idle | dpkg-buildpackage |
| 10 | cosmic-initial-setup | dpkg-buildpackage |
| 11 | cosmic-launcher | dpkg-buildpackage |
| 12 | cosmic-monitor | dpkg-buildpackage |
| 13 | cosmic-notifications | dpkg-buildpackage |
| 14 | cosmic-osd | dpkg-buildpackage |
| 15 | cosmic-panel | dpkg-buildpackage |
| 16 | cosmic-player | dpkg-buildpackage |
| 17 | cosmic-randr | dpkg-buildpackage |
| 18 | cosmic-screenshot | dpkg-buildpackage |
| 19 | cosmic-session | dpkg-buildpackage |
| 20 | cosmic-settings | dpkg-buildpackage |
| 21 | cosmic-settings-daemon | dpkg-buildpackage |
| 22 | cosmic-store | dpkg-buildpackage |
| 23 | cosmic-term | dpkg-buildpackage |
| 24 | cosmic-wallpapers | dpkg-buildpackage |
| 25 | cosmic-workspaces-epoch | dpkg-buildpackage |
| 26 | soryos-launcher | dpkg-buildpackage |
| 27 | simple-wrapper | dpkg-buildpackage |
| 28 | xdg-desktop-portal-cosmic | dpkg-buildpackage |

Workflows : `build-deb-release.yml`, `build-all.yml` (job `build-cosmic`), `build-cosmic.yml`, `update-deb-release.yml`.

### B. COSMIC hors dpkg — meson (1)

| # | Paquet | Méthode CI |
|---|--------|------------|
| 29 | cosmic-sound-theme | meson + dpkg-deb manuel |

### C. Intégration SoryOS — templates `scripts/build-packages.sh` (21)

Sources : `sory-os-apt/templates/<nom>/` (pas de compilation Rust lourde sauf option IA).

| # | Paquet | Rôle |
|---|--------|------|
| 30 | soryos-archive-keyring | Clé APT du dépôt |
| 31 | soryos-system-lock | Verrou système |
| 32 | soryos-identity | Identité SoryOS |
| 33 | soryos-appstream-data | Métadonnées AppStream |
| 34 | soryos-icon-theme | Thème d'icônes |
| 35 | soryos-sound-theme | Thème sonore SoryOS |
| 36 | soryos-hp-vendor | Outils HP vendor |
| 37 | soryos-hp-vendor-dkms | Module DKMS HP |
| 38 | soryos-hp-wallpapers | Fonds d'écran HP |
| 39 | soryos-wallpapers | Fonds d'écran SoryOS |
| 40 | soryos-acpi-dkms | DKMS ACPI |
| 41 | soryos-dkms | DKMS générique |
| 42 | soryos-io-dkms | DKMS I/O |
| 43 | soryos-driver | Pilotes SoryOS |
| 44 | soryos-driver-nvidia | Pilote NVIDIA |
| 45 | soryos-firmware-daemon | Démon firmware |
| 46 | soryos-oled | Support OLED |
| 47 | soryos-power | Gestion d'énergie |
| 48 | gnome-shell-extension-soryos-power | Extension GNOME |
| 49 | soryos-desktop | Métapaquet bureau |
| 50 | libcosmic | Métapaquet libcosmic |
| 51 | cosmic-sory-ia | Métapaquet IA (binaires optionnels via `BUILD_IA_BINARIES=1` en CI) |

Workflow : job `build-integration` dans `build-deb-release.yml` / `build-all.yml`.

### D. Métadonnées publiées avec la Release (générées en CI, pas des paquets)

- `index.json` + `index.json.sig` (index Release signé BLAKE3)
- `index-signing-key.pub.pem` / `.pub.hex`
- `dists/stable/Release`, `InRelease`, `Packages`, `Packages.gz`
- `soryos-archive-keyring.gpg`

Workflows : `publish` dans `build-deb-release.yml`, `publish-pages.yml` (catalogue léger).

---

## Ce qui **peut / doit** être fait en **local** sur le PC

### 1. Assemblage ISO (recommandé)

```bash
cd sory-os/iso
make DISTRO_CODE=soryos DISTRO_VERSION=24.04 SORYOS_RELEASE_TAG='<tag-release>'
```

- Télécharge le catalogue depuis **GitHub Pages**
- Télécharge les `.deb` depuis **GitHub Release** (vérif BLAKE3)
- Installe via `apt` dans le chroot — **aucune compilation COSMIC**

### 2. Téléchargement / vérification du pool

```bash
cd sory-os/sory-os-apt
./scripts/download-release-pool.sh <tag> ./pool/stable
./scripts/verify-release-index.sh index.json index.json.sig index-signing-key.pub.pem
```

### 3. Développement applicatif léger (hors empaquetage)

- `cargo check -j1` ou `cargo build` **sans** `dpkg-buildpackage` / sans publier de `.deb`
- Édition des templates d'intégration (`templates/`) — le build du `.deb` reste en CI
- Tests QEMU de l'ISO déjà construite

### 4. Scripts de maintenance du dépôt (légers)

- `scripts/init-signing-key.sh` (une fois, clés locales de dev)
- Lecture / revue de `cosmic-apps/manifest.json`, `config/cosmic.toml`

---

## Ce qu'il ne faut **pas** lancer en local (RAM / temps)

| Commande / action | Pourquoi |
|-------------------|----------|
| `./scripts/build-cosmic-local.sh --all` | Compile toute la stack COSMIC |
| `./scripts/build-packages.sh` (complet) | 21+ métapaquets + cosmic-sory-ia |
| `dpkg-buildpackage` dans `cosmic-epoch/*` | Rust lourd, lié à libcosmic |
| `BUILD_IA_BINARIES=1 ./scripts/build-packages.sh` | Compile tous les binaires IA |
| `cargo build --release` pour empaquetage | Réservé à la CI |
| `make repo` / build monorepo `sory-os` entier | Obsolète pour ce modèle Debian |

---

## Workflows CI (référence)

| Workflow | Rôle |
|----------|------|
| `build-deb-release.yml` | Release complète ou incrémentale (principal) |
| `build-all.yml` | Build planifié + publish Release si `release_tag` |
| `build-cosmic.yml` | Rebuild COSMIC incrémental |
| `update-deb-release.yml` | Mise à jour in-place d'une Release existante |
| `publish-pages.yml` | Catalogue Pages (sans `.deb`) |

### Lancer une Release depuis le PC (déclenche la CI, ne compile pas localement)

```bash
gh workflow run build-deb-release.yml --repo sory-os-org/sory-os-apt \
  -f tag='soryos-deb-2026.08.12' \
  -f components='all' \
  -f release_binary='1' \
  -f base_release_tag='soryos-deb-2026.08.07-desktop-full'
```

Secrets requis sur le dépôt : `SORYOS_GPG_PRIVATE_KEY`, `SORYOS_INDEX_PRIVATE_KEY_PEM`.

---

## Résumé en une phrase

**51 paquets `.deb` + métadonnées signées = CI uniquement ; le PC ne fait que télécharger, vérifier et assembler l'ISO.**
