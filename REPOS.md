# SoryOS — Inventaire des dépôts sources

Inventaire complet basé sur l'analyse des 9 dépôts locaux et des submodules
de `cosmic-epoch` (Époch 1.4.0). Les URLs pointent vers les dépôts upstream.

---

## COSMIC Desktop — Dépôts avec debian/control (dpkg natif)

Ces composants ont un dossier `debian/` complet et peuvent être buildés
directement avec `dpkg-buildpackage`.

### [cosmic-comp](https://github.com/sory-x/cosmic-comp)
- **Version** : 0.1 (epoch-1.4.0-6-g44de3063)
- **Arch** : amd64, arm64
- **Description** : Wayland compositor for the COSMIC desktop environment
- **Dépend** : libegl1, libwayland-server0
- **Recommande** : cosmic-session, libgl1-mesa-dri
- **Chemin local** : `/home/sory/Bureau/soryos/cosmic-comp`

### [cosmic-files](https://github.com/sory-x/cosmic-files)
- **Version** : 1.4.0 (epoch-1.4.0)
- **Arch** : amd64, arm64
- **Description** : COSMIC File Manager
- **Dépend** : xdg-utils
- **Binaires** : cosmic-files, cosmic-files-applet
- **Chemin local** : `/home/sory/Bureau/soryos/cosmic-files`

### [cosmic-greeter](https://github.com/sory-x/cosmic-greeter)
- **Version** : 0.1.0 (epoch-1.4.0)
- **Arch** : amd64, arm64
- **Description** : COSMIC Greeter (login screen)
- **Pre-dépend** : greetd
- **Dépend** : adduser, cosmic-comp, cosmic-greeter-daemon, cosmic-randr, dbus
- **Binaires** : cosmic-greeter, cosmic-greeter-daemon
- **Chemin local** : `/home/sory/Bureau/soryos/cosmic-greeter`

### [cosmic-launcher](https://github.com/sory-x/cosmic-launcher)
- **Version** : 1.0.12 (epoch-1.4.0)
- **Arch** : amd64, arm64
- **Description** : COSMIC Launcher (application launcher)
- **Dépend** : pop-launcher
- **Chemin local** : `/home/sory/Bureau/soryos/cosmic-launcher`

### [cosmic-panel](https://github.com/sory-x/cosmic-panel)
- **Version** : 0.1.0 (epoch-1.4.0-3-g5df1bca)
- **Arch** : amd64, arm64
- **Description** : XDG Shell Wrapper Panel for COSMIC
- **Binaires** : cosmic-panel, cosmic-panel-bin, cosmic-panel-config
- **Chemin local** : `/home/sory/Bureau/soryos/cosmic-panel`

### [cosmic-settings](https://github.com/sory-x/cosmic-settings)
- **Version** : 1.0.12 (epoch-1.4.0-4-gca9b7aa)
- **Arch** : amd64, arm64
- **Description** : Settings application for the COSMIC desktop environment
- **Dépend** : accountsservice, cosmic-randr, cosmic-settings-daemon, gettext, iso-codes, network-manager-gnome, network-manager-openvpn, network-manager-openvpn-gnome, xkb-data
- **Recommande** : adw-gtk3
- **Chemin local** : `/home/sory/Bureau/soryos/cosmic-settings`

---

## Meta-repo et outils

### [cosmic-epoch](https://github.com/sory-x/cosmic-epoch)
- **Version** : 1.4.0 (tag: epoch-1.4.0)
- **Type** : Meta-repo (submodules)
- **Description** : COSMIC Desktop Environment — contient tous les composants COSMIC en submodules
- **Chemin local** : `/home/sory/Bureau/soryos/cosmic-epoch`
- **Submodules** (28) :
  `cosmic-applets`, `cosmic-applibrary`, `cosmic-bg`, `cosmic-comp`,
  `cosmic-edit`, `cosmic-files`, `cosmic-greeter`, `cosmic-icons`,
  `cosmic-idle`, `cosmic-initial-setup`, `cosmic-launcher`, `cosmic-monitor`,
  `cosmic-notifications`, `cosmic-osd`, `cosmic-panel`, `cosmic-player`,
  `cosmic-randr`, `cosmic-screenshot`, `cosmic-session`, `cosmic-settings`,
  `cosmic-settings-daemon`, `cosmic-sound-theme`, `cosmic-store`,
  `cosmic-term`, `cosmic-wallpapers`, `cosmic-workspaces-epoch`,
  `xdg-desktop-portal-cosmic`, `simple-wrapper`

### [iso](https://github.com/sory-x/iso)
- **Version** : 24.04
- **Type** : Makefile
- **Description** : ISO builder for Pop!\_OS / SoryOS
- **Chemin local** : `/home/sory/Bureau/soryos/iso`

### [libcosmic](https://github.com/sory-x/libcosmic)
- **Version** : 1.0.0
- **Type** : Rust (workspace)
- **Description** : COSMIC GUI toolkit
- **Chemin local** : `/home/sory/Bureau/soryos/libcosmic`
- **Sous-crates** : cosmic-config, cosmic-config-derive, cosmic-theme, cosmic-icons, iced

---

## Composants COSMIC supplémentaires (submodules, non clonés)

Ces composants font partie de `cosmic-epoch` mais ne sont pas clonés localement.
Leur build se fera via le meta-repo ou par clone individuel dans la CI.

- [cosmic-applets](https://github.com/sory-x/cosmic-applets) — Applets for cosmic-panel
- [cosmic-applibrary](https://github.com/sory-x/cosmic-applibrary) — COSMIC App Library
- [cosmic-bg](https://github.com/sory-x/cosmic-bg) — COSMIC background service
- [cosmic-edit](https://github.com/sory-x/cosmic-edit) — COSMIC Text Editor
- [cosmic-icons](https://github.com/sory-x/cosmic-icons) — COSMIC Icon Theme
- [cosmic-idle](https://github.com/sory-x/cosmic-idle) — Idle management daemon
- [cosmic-initial-setup](https://github.com/sory-x/cosmic-initial-setup) — First-run setup wizard
- [cosmic-monitor](https://github.com/sory-x/cosmic-monitor) — Display monitor service
- [cosmic-notifications](https://github.com/sory-x/cosmic-notifications) — Notification daemon
- [cosmic-osd](https://github.com/sory-x/cosmic-osd) — On-screen display
- [cosmic-player](https://github.com/sory-x/cosmic-player) — Media player
- [cosmic-randr](https://github.com/sory-x/cosmic-randr) — Display configuration library
- [cosmic-screenshot](https://github.com/sory-x/cosmic-screenshot) — Screenshot utility
- [cosmic-session](https://github.com/sory-x/cosmic-session) — Session manager
- [cosmic-settings-daemon](https://github.com/sory-x/cosmic-settings-daemon) — Settings daemon
- [cosmic-sound-theme](https://github.com/sory-x/cosmic-sound-theme) — Sound theme
- [cosmic-store](https://github.com/sory-x/cosmic-store) — App store
- [cosmic-term](https://github.com/sory-x/cosmic-term) — Terminal emulator
- [cosmic-wallpapers](https://github.com/sory-x/cosmic-wallpapers) — Wallpapers
- [cosmic-workspaces-epoch](https://github.com/sory-x/cosmic-workspaces-epoch) — Workspaces overview
- [xdg-desktop-portal-cosmic](https://github.com/sory-x/xdg-desktop-portal-cosmic) — XDG Portal backend
- [pop-launcher](https://github.com/sory-x/launcher) — IPC desktop launcher service
- [simple-wrapper](https://github.com/sory-x/simple-wrapper) — xdg-shell wrapper

---

## Paquets d'intégration SoryOS (templates/)

Ces 21 paquets sont définis dans `templates/` et buildés localement.
Ils n'ont pas de source externe — ce sont des paquets d'intégration vides.

| Paquet | Description |
|--------|-------------|
| `soryos-archive-keyring` | Clé GPG pour le dépôt APT SoryOS |
| `soryos-system-lock` | Protection système SoryOS |
| `soryos-identity` | Identité système SoryOS |
| `soryos-appstream-data` | Métadonnées AppStream |
| `soryos-icon-theme` | Thème d'icônes |
| `soryos-fonts` | Polices système |
| `soryos-sound-theme` | Thème sonore |
| `soryos-hp-vendor` | Support HP vendor |
| `soryos-hp-vendor-dkms` | Module DKMS HP |
| `soryos-hp-wallpapers` | Fonds d'écran HP |
| `soryos-wallpapers` | Fonds d'écran SoryOS |
| `soryos-acpi-dkms` | Module DKMS ACPI |
| `soryos-dkms` | Module DKMS SoryOS |
| `soryos-io-dkms` | Module DKMS IO |
| `soryos-driver` | Pilote SoryOS |
| `soryos-driver-nvidia` | Pilote NVIDIA |
| `soryos-firmware-daemon` | Daemon firmware |
| `soryos-oled` | Gestion OLED |
| `soryos-power` | Gestion d'alimentation |
| `gnome-shell-extension-soryos-power` | Extension GNOME Shell pour power |
| `soryos-desktop` | Meta-paquet desktop SoryOS |

### Paquets avec debian/ (build dpkg-buildpackage)

Ces 29 paquets sont buildés par la CI via `dpkg-buildpackage -us -uc -b`
en utilisant leur vrai `debian/` :

| Paquet | Source |
|--------|--------|
| `cosmic-session` | cosmic-epoch/cosmic-session |
| `cosmic-files` | cosmic-epoch/cosmic-files |
| `cosmic-settings` | cosmic-epoch/cosmic-settings |
| `cosmic-comp` | cosmic-epoch/cosmic-comp |
| `cosmic-panel` | cosmic-epoch/cosmic-panel |
| `cosmic-launcher` | cosmic-epoch/cosmic-launcher |
| `cosmic-greeter` | cosmic-epoch/cosmic-greeter |
| `cosmic-term` | cosmic-epoch/cosmic-term |
| `cosmic-store` | cosmic-epoch/cosmic-store |
| `cosmic-edit` | cosmic-epoch/cosmic-edit |
| `cosmic-icons` | cosmic-epoch/cosmic-icons |
| `cosmic-bg` | cosmic-epoch/cosmic-bg |
| `cosmic-applets` | cosmic-epoch/cosmic-applets |
| `cosmic-applibrary` | cosmic-epoch/cosmic-applibrary |
| `cosmic-idle` | cosmic-epoch/cosmic-idle |
| `cosmic-initial-setup` | cosmic-epoch/cosmic-initial-setup |
| `cosmic-monitor` | cosmic-epoch/cosmic-monitor |
| `cosmic-notifications` | cosmic-epoch/cosmic-notifications |
| `cosmic-osd` | cosmic-epoch/cosmic-osd |
| `cosmic-player` | cosmic-epoch/cosmic-player |
| `cosmic-randr` | cosmic-epoch/cosmic-randr |
| `cosmic-screenshot` | cosmic-epoch/cosmic-screenshot |
| `cosmic-settings-daemon` | cosmic-epoch/cosmic-settings-daemon |
| `cosmic-sory-ia` | cosmic-epoch/cosmic-sory-ia |
| `cosmic-wallpapers` | cosmic-epoch/cosmic-wallpapers |
| `cosmic-workspaces` | cosmic-epoch/cosmic-workspaces-epoch |
| `pop-launcher` | cosmic-epoch/pop-launcher |
| `simple-wrapper` | cosmic-epoch/simple-wrapper |
| `xdg-desktop-portal-cosmic` | cosmic-epoch/xdg-desktop-portal-cosmic |
| `cosmic-sound-theme` | cosmic-epoch/cosmic-sound-theme (meson) |

---

## Résumé

- **Meta-repo** : `cosmic-epoch` (28 submodules COSMIC)
- **Dépôts externes** : `libcosmic`, `iso`
- **Templates** : 21 paquets d'intégration SoryOS (`soryos-*`)
- **Composants COSMIC buildés** : 30 (29 avec debian/ + cosmic-sound-theme via meson)
- **Total pool** : ~51 paquets
