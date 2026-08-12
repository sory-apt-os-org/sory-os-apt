# SoryOS Progressive Migration

The migration uses the signed SoryOS APT repository as the preferred source for
SoryOS-owned packages while Ubuntu/Debian repositories remain fallback sources.

Full command reference: `docs/COMMANDS.md`.

## Stage 0: Configure APT

```bash
sudo ./scripts/configure-soryos-apt.sh
```

This installs:

- `/usr/share/keyrings/soryos-archive-keyring.gpg`
- `/etc/apt/sources.list.d/soryos-stable.list` (prod)
- `/etc/apt/sources.list.d/soryos-testing.list` (testing)
- `/etc/apt/sources.list.d/soryos-nightly.list` (nightly)
- `/etc/apt/preferences.d/soryos.pref`

It then runs `apt-get update`.

## APT Priority

SoryOS repository packages get priority `1002`.

Ubuntu origins are pinned at priority `50`, so they remain available as fallback
sources for packages not yet published by SoryOS.

SoryOS package names from non-SoryOS repositories are pinned at `-1` to prevent
accidental replacement.

Detailed lock documentation: `docs/SYSTEM-LOCK.md`.

## Stage 1: Desktop Modules

```bash
sudo ./scripts/migrate-stage1-desktop.sh
```

Installs:

- `soryos-archive-keyring`
- `soryos-system-lock`
- `cosmic-session`
- `cosmic-settings`
- `cosmic-files`
- `cosmic-term`
- `cosmic-store`
- `soryos-desktop`

## Rollback

Remove the SoryOS APT source and keyring:

```bash
sudo ./scripts/rollback-soryos-apt.sh
```

Optional package rollback:

```bash
sudo apt remove soryos-desktop soryos-system-lock
```

Optional critical package holds:

```bash
sudo soryos-apply-holds
```

Rollback holds:

```bash
sudo soryos-remove-holds
```

Check status after rollback:

```bash
sudo apt update
apt-cache policy soryos-desktop soryos-system-lock cosmic-session cosmic-settings cosmic-files cosmic-term cosmic-store
```
