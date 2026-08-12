# SoryOS — Guide des sources

Ce document détaille la gestion des sources de paquets pour SoryOS.
L'inventaire machine se trouve dans `sources/sources.yml`.

## Types de sources

### 1. COSMIC Desktop (Rust, dépôts upstream)

Chaque composant COSMIC est un dépôt Rust individuel forké chez `sory-x/` (depuis pop-os upstream).
Le meta-repo `cosmic-epoch` les agrège
en submodules.

**Composants avec debian/control** (6) — build dpkg natif :
- cosmic-comp, cosmic-files, cosmic-greeter, cosmic-launcher, cosmic-panel, cosmic-settings

**Composants sans debian/control** (22) — build cargo + deb manuel :
- cosmic-applets, cosmic-applibrary, cosmic-bg, cosmic-edit, cosmic-icons,
  cosmic-idle, cosmic-initial-setup, cosmic-monitor, cosmic-notifications,
  cosmic-osd, cosmic-player, cosmic-randr, cosmic-screenshot, cosmic-session,
  cosmic-settings-daemon, cosmic-sound-theme, cosmic-store, cosmic-term,
  cosmic-wallpapers, cosmic-workspaces-epoch, xdg-desktop-portal-cosmic,
  pop-launcher, simple-wrapper

**Meta-repo** (1) :
- cosmic-epoch (submodules des 28 composants)

### 2. Outils système

- iso — constructeur ISO (Makefile, forké de pop-os/iso)
- libcosmic — toolkit GUI Rust (forké de pop-os/libcosmic)
- launcher — service lanceur IPC (forké de pop-os/launcher)

### 3. Paquets d'intégration SoryOS (27 templates)

Ces paquets n'ont pas de code externe. Ils sont définis dans `templates/` :
marqueurs d'intégration, clés, dépendances, pinning APT.

## Versions

Tous les composants sont à l'Époch 1.4.0 (sauf indication contraire).
Les versions individuelles suivent les tags des dépôts upstream.

## CI

Le workflow `.github/workflows/build-all.yml` :
1. Clone les sources selon `sources/sources.yml`
2. Build chaque composant (dpkg ou cargo)
3. Empaquette en .deb
4. Génère les index APT
5. Signe le dépôt
6. Publie sur GitHub Pages
