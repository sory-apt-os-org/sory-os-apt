# SoryOS Distribution Roadmap

Full command reference: `docs/COMMANDS.md`.

## Phase 1: Secure APT

Status: implemented locally.

- Generate `Packages.gz` from `pool/`.
- Generate `Release` with `apt-ftparchive`.
- Generate `Release.gpg` and `InRelease` with GPG.
- Publish public keyring files.
- Provide `soryos-archive-keyring` package.
- Test local APT access using `signed-by`.
- Le dépôt APT est publié sur **GitHub Pages** : https://sory-x.github.io/soryos-apt

## Phase 2: Installer

Status: started.

- `scripts/install-soryos-repo.sh` configures the signed repo on a test system.
- `soryos-system-lock` installs strict APT pinning and hold helper commands.
- Current base install uses SoryOS package names.

## Phase 3: ISO Integration

Status: active (bind mount local pool).

- Add SoryOS keyring to the ISO chroot.
- Bind mount `soryos-apt/` dans le chroot via `iso/scripts/soryos-local-repo.sh`.
- Écriture d'un fichier `.sources` DEB822 avec `Signed-By`.
- Install SoryOS packages (21 integration .deb + 30 COSMIC .deb) via APT repo.
- Métapackage `soryos-desktop` créé (dépend : soryos-archive-keyring, soryos-system-lock, soryos-identity, cosmic-session, cosmic-term, cosmic-store).
  - `cosmic-session` tire tous les composants COSMIC via ses vraies dépendances Debian.
- Install `soryos-system-lock` to enable ISO lock mode.
- Keep Ubuntu/Debian base repositories available as fallback sources.
- **Blocage** : accès réseau à `archive.ubuntu.com` intermittent.

## Phase 4: Progressive Replacement

Status: started.

Order:

1. Session COSMIC (cosmic-session).
2. Applets COSMIC (cosmic-applets).
3. Settings COSMIC (cosmic-settings).
4. System tools.
5. Store COSMIC (cosmic-store).
6. Driver, firmware and power integration payloads.

Replacement packages must exist in the SoryOS APT repository before active ISO
config points to them.

## Phase 5: CI/CD

Status: active.

- Matrix CI build de 28 composants COSMIC en parallèle via `dpkg-buildpackage`.
- Build des 21 paquets d'intégration SoryOS via `build-packages.sh`.
- Publication automatique sur GitHub Pages.
- Détection de versions modifiées (compare Cargo.toml / debian/changelog au pool).
