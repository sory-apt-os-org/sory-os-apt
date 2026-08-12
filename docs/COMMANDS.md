# SoryOS APT Commands

This file is the single command reference for the SoryOS APT repository.

Run commands from the repository root unless stated otherwise:

```bash
cd /home/sory/Bureau/soryos/soryos-apt
```

## Full Local Build And Test

Use this before every push:

```bash
./scripts/init-signing-key.sh
./scripts/build-packages.sh
./scripts/sign-repository.sh
./scripts/test-local-repo.sh
./scripts/apt-smoke-test.sh
./scripts/apt-signed-smoke-test.sh
```

Test the published GitHub Pages repository:

```bash
./scripts/apt-pages-smoke-test.sh https://sory-x.github.io/soryos-apt
```

## Build Packages Only

```bash
./scripts/build-packages.sh
```

Generated packages are placed in:

```text
pool/*.deb
```

## Generate APT Index Only

```bash
./scripts/generate-index.sh
```

Equivalent raw command:

```bash
dpkg-scanpackages pool /dev/null | gzip -9cn > dists/stable/main/binary-amd64/Packages.gz
```

## Sign Repository Only

```bash
./scripts/sign-repository.sh
```

Generated signed metadata:

```text
dists/stable/Release
dists/stable/Release.gpg
dists/stable/InRelease
```

## Local Tests

Validate files and signatures:

```bash
./scripts/test-local-repo.sh
```

Test unsigned compatibility in an isolated APT root:

```bash
./scripts/apt-smoke-test.sh
```

Test signed APT in an isolated APT root:

```bash
./scripts/apt-signed-smoke-test.sh
```

These tests do not modify `/etc/apt`.

## Publish To GitHub (obsolète)

> Le dépôt APT est publié sur GitHub Pages : https://sory-x.github.io/soryos-apt

After local tests pass:

```bash
git status --short
git add .
git commit -m "Update SoryOS APT repository"
git push origin main
```

Then test GitHub Pages:

```bash
./scripts/apt-pages-smoke-test.sh https://sory-x.github.io/soryos-apt
```

## Configure SoryOS APT On A Test Machine

This adds SoryOS as the signed preferred repository. Ubuntu/Debian base
repositories remain available as fallback sources.

```bash
sudo ./scripts/configure-soryos-apt.sh
```

It installs:

```text
/usr/share/keyrings/soryos-archive-keyring.gpg
/etc/apt/sources.list.d/soryos-stable.list
/etc/apt/preferences.d/soryos.pref
```

Manual equivalent:

```bash
sudo install -d -m 0755 /usr/share/keyrings /etc/apt/sources.list.d /etc/apt/preferences.d
curl -fsSL https://sory-x.github.io/soryos-apt/keyrings/soryos-archive-keyring.gpg | sudo tee /usr/share/keyrings/soryos-archive-keyring.gpg >/dev/null
sudo chmod 0644 /usr/share/keyrings/soryos-archive-keyring.gpg
printf '%s\n' 'deb [signed-by=/usr/share/keyrings/soryos-archive-keyring.gpg] https://sory-x.github.io/soryos-apt stable main' | sudo tee /etc/apt/sources.list.d/soryos-stable.list >/dev/null
sudo cp config/apt/preferences.d/soryos.pref /etc/apt/preferences.d/soryos.pref
sudo apt update
```

## Install Stage 1 Desktop Modules

```bash
sudo ./scripts/migrate-stage1-desktop.sh
```

Manual equivalent:

```bash
sudo apt update
apt-cache policy soryos-desktop soryos-system-lock cosmic-session cosmic-settings cosmic-files cosmic-term cosmic-store
sudo apt install soryos-desktop
```

Expected behavior:

```text
0 removed
SoryOS packages installed module by module
Ubuntu/Debian fallback repositories remain available
```

Safe build and rollback-protected validation:

```bash
./scripts/build-and-validate.sh
```

Local CI without privileged chroot tests:

```bash
SORYOS_SKIP_CHROOT_TESTS=1 ./scripts/ci-local.sh
```

Full local CI with chroot tests:

```bash
sudo ./scripts/ci-local.sh
```

Individual chroot validation steps:

```bash
sudo ./scripts/test-chroot-bootstrap.sh
sudo ./scripts/test-chroot-install.sh
sudo ./scripts/test-chroot-upgrade.sh
sudo ./scripts/test-chroot-rollback.sh
sudo ./scripts/test-chroot-recovery.sh
```

## Apply Or Remove Critical Holds

After `soryos-system-lock` is installed, optional critical holds can be applied:

```bash
sudo soryos-apply-holds
```

Remove those holds:

```bash
sudo soryos-remove-holds
```

These commands target installed critical packages such as `soryos-desktop`,
`ubuntu-desktop`, `gnome-shell`, and installed `soryos-*` packages.

Verify pinning and holds:

```bash
apt-cache policy soryos-desktop soryos-system-lock cosmic-session cosmic-settings cosmic-files cosmic-term cosmic-store
apt-mark showhold
```

## Rollback

Remove only SoryOS APT configuration:

```bash
sudo ./scripts/rollback-soryos-apt.sh
```

Manual equivalent:

```bash
sudo rm -f /etc/apt/sources.list.d/soryos-stable.list
sudo rm -f /etc/apt/preferences.d/soryos.pref
sudo rm -f /usr/share/keyrings/soryos-archive-keyring.gpg
sudo apt update
```

Optionally remove SoryOS packages:

```bash
sudo apt remove soryos-desktop soryos-system-lock
```

Keep Ubuntu/Debian base packages installed during migration.

## Local Cleanup

Remove generated local packages and indexes:

```bash
./scripts/rollback-local.sh
```

This does not touch the system APT configuration.

## Important Safety Rules

- Do not remove Ubuntu/Debian fallback repositories during migration.
- Do not use `[trusted=yes]` for final systems.
- Always run `apt update` before migration installs.
- Always test locally before pushing.
- Keep the private GPG key under `.private/gnupg` backed up and out of Git.
