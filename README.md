# SoryOS APT Repository

Dépôt APT officiel de **SoryOS** — paquets, index signés, et CI de build automatique.

## Structure

```
soryos-apt/
├── .github/workflows/       # CI GitHub Actions
│   ├── build-all.yml        #   Build complet + publication GitHub Pages
│   └── apt-repository.yml   #   Validation à chaque push
├── pool/                    # Paquets .deb (générés par la CI)
├── dists/                   # Index APT + signatures (stable, testing, nightly)
├── keyrings/                # Clés GPG du dépôt
├── templates/               # 21 templates de paquets d'intégration SoryOS
│   ├── soryos-archive-keyring/control
│   ├── soryos-system-lock/control
│   └── ...
├── sources/                 # Définitions des dépôts sources upstream
│   ├── sources.yml          #   Inventaire machine (utilisé par la CI)
│   └── ...
├── config/apt/              # Configuration APT cible
│   ├── preferences.d/       #   Pinning (SoryOS=1002, Ubuntu=50)
│   └── sources.list.d/      #   Sources APT
├── scripts/                 # Scripts de build, test, publication
│   ├── build-packages.sh        #   Build paquets d'intégration SoryOS
│   ├── build-cosmic-local.sh    #   Build composants COSMIC (dpkg-buildpackage)
│   ├── generate-index.sh        #   Génération des index APT
│   ├── sign-repository.sh       #   Signature GPG du dépôt
│   ├── init-signing-key.sh      #   Génération de la clé GPG
│   ├── test-local-repo.sh       #   Validation locale
│   ├── apt-smoke-test.sh        #   Test APT isolé
│   ├── configure-soryos-apt.sh  #   Installation système
│   └── rollback-soryos-apt.sh   #   Retrait de la config
├── docs/                    # Documentation
│   ├── COMMANDS.md
│   ├── SYSTEM-LOCK.md
│   ├── MIGRATION.md
│   ├── ISO-INTEGRATION.md
│   ├── RELEASES.md
│   ├── ROADMAP.md
│   └── SOURCES.md
├── tests/                   # Tests (APT, chroot, QEMU)
└── ci/                      # Config CI additionnelle
```

## Quick Start

```bash
# En local (test rapide)
./scripts/init-signing-key.sh
./scripts/build-packages.sh
./scripts/sign-repository.sh
./scripts/test-local-repo.sh
```

## Workflow CI (GitHub Actions)

```
Push ou Schedule (daily 03:00 UTC)
        │
Clone cosmic-epoch (submodules: 28 composants)
        │
[Matrix CI] Build chaque composant COSMIC (dpkg-buildpackage)
  ├── cosmic-files, cosmic-session, cosmic-settings...
  ├── pop-launcher, simple-wrapper, xdg-desktop-portal-cosmic
  └── cosmic-sound-theme (meson)
        │
Build paquets d'intégration SoryOS (templates/)
        │
Generate APT index (dpkg-scanpackages)
        │
Sign repository (GPG)
        │
Test repository
        │
Push pool/ + dists/ → GitHub Pages
        │
→ https://sory-x.github.io/soryos-apt
```

## Suites APT

- **stable**   : paquets testés, pour les systèmes normaux et ISO
- **testing**  : intégration avant promotion stable
- **nightly**  : builds automatiques quotidiens

## Sécurité

- Signature GPG du dépôt (`Release.gpg`, `InRelease`)
- Clé privée dans `.private/gnupg` (jamais commitée)
- Utiliser `signed-by` dans `sources.list`, jamais `[trusted=yes]`

## Licence

- **Scripts** : MIT
- **Paquets COSMIC** : GPL-3.0 / MPL-2.0 / MIT
- **Dépôt APT** : données publiques
