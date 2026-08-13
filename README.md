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

Les binaires `.deb` sont publiés sur des **GitHub Releases immuables**, pas sur
GitHub Pages. Voir `redox/docs-plans/PLAN-INDEX-PAGES-RELEASES-SIGNE.md`.

| Canal | Rôle | Contenu |
|-------|------|---------|
| **GitHub Release** | stockage binaire | `*.deb` + copie immuable de l'index pour le tag |
| **GitHub Pages** | catalogue léger | `index.json` signé, clés, `dists/stable/` (sans `pool/`) |

```
workflow_dispatch (tag immuable)
        │
Clone sory-os/cosmic-epoch → dpkg-buildpackage
        │
generate-release-index.py + signature Ed25519
        │
Upload *.deb + index → GitHub Release
        │
publish-pages.yml → index + dists/ → GitHub Pages
        │
ISO : Pages (catalogue) + Release (.deb) → pool local file://
```

Workflows principaux :

- `.github/workflows/build-deb-release.yml` — Release complète/incrémentale
- `.github/workflows/update-deb-release.yml` — mise à jour en place
- `.github/workflows/build-all.yml` — build matrix + publish si `release_tag` fourni

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
