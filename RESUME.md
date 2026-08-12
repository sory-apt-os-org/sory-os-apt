# Résumé — soryos-apt

Dépôt APT pour le système **SoryOS**, publié sur GitHub Pages.

## Structure

```
soryos-apt/
├── .github/workflows/       # CI : validation du dépôt + build automatique
├── .private/gnupg/          # Clé GPG privée (ignorée par git)
├── config/apt/              # sources.list + preferences (pinning APT)
├── dists/                   # Métadonnées signées (stable, testing, nightly)
├── docs/                    # Documentation
├── keyrings/                # Clé publique du dépôt
├── scripts/                 # Scripts (build, sign, test, publish)
├── sources/                 # Inventaire des sources
├── templates/               # 27 templates de paquets (fichiers control)
├── tests/                   # Tests APT, chroot, QEMU
├── pool/stable/             # Paquets prêts à publier
├── pool/testing/            # Pour pré-version
└── pool/nightly/            # Pour builds nightly
```

## Suites APT

- **stable**, **testing**, **nightly** — chacune signée (`Release`, `Release.gpg`, `InRelease`)
- Index `Packages` + `Packages.gz` générés par `dpkg-scanpackages`

## Paquets (29 templates)

- **Paquets d'intégration** : Petits paquets `all` qui réservent des noms
- **Métapaquets** : `soryos-desktop`, `cosmic-sory-ia`
- **Bibliothèque** : `libcosmic`

## Sécurité

- Signature GPG du dépôt (`Release.gpg`, `InRelease`)
- Pinning APT avec priorité **1002** pour SoryOS
- Clé privée dans `.private/gnupg/`, jamais commitée

## CI/CD

- **build-and-publish.yml** : Build → sign → index → publish sur GitHub Pages

## Source

```
https://sory-x.github.io/soryos-apt
```
