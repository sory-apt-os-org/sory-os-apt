# SoryOS ISO Integration

Le dépôt APT SoryOS est publié sur GitHub Pages :
`https://sory-x.github.io/soryos-apt`

## Configuration ISO

L'ISO SoryOS consomme le dépôt distant via HTTPS dans le chroot :

```text
Types: deb
URIs: https://sory-x.github.io/soryos-apt
Suites: stable
Components: main
Signed-By: /etc/apt/keyrings/soryos-archive-keyring.gpg
```

## Métapackage soryos-desktop

- `soryos-desktop_0.1.0_all.deb`
- Dépend de tous les composants d'intégration SoryOS
- Buildé par la CI GitHub Actions et publié sur GitHub Pages

## Build ISO

```bash
cd iso
make chroot
make iso
```
