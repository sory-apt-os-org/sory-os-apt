# SoryOS System Lock

`soryos-system-lock` protects SoryOS packages during the SoryOS migration.

## What It Installs

- `/etc/apt/preferences.d/soryos.pref`
- `/usr/bin/soryos-apply-holds`
- `/usr/bin/soryos-remove-holds`

## APT Pinning

SoryOS packages are protected with priority `1002`, so packages provided by the
SoryOS repository win during ISO builds and installed system upgrades. Ubuntu
remains the fallback source for packages SoryOS does not publish yet.

```text
Package: sory* soryos-*
Pin: origin sory-x.github.io
Pin-Priority: 1002
```

All packages from the SoryOS repository are preferred:

```text
Package: *
Pin: origin sory-x.github.io
Pin-Priority: 1002
```

SoryOS package names from other repositories are blocked:

```text
Package: sory* soryos-*
Pin: release *
Pin-Priority: -1
```

Ubuntu remains available as the base fallback source:

```text
Package: *
Pin: origin archive.ubuntu.com
Pin-Priority: 50
```

## Install

```bash
sudo apt update
sudo apt install soryos-system-lock
```

It is also installed by:

```bash
sudo apt install soryos-desktop
```

## Optional Holds

Apply critical package holds:

```bash
sudo soryos-apply-holds
```

Remove those holds:

```bash
sudo soryos-remove-holds
```

The hold commands are manual on purpose. Installing `soryos-system-lock` does
not silently hold packages.

## Verify

```bash
apt-cache policy soryos-system-lock soryos-desktop cosmic-session cosmic-settings cosmic-files cosmic-term cosmic-store
apt-mark showhold
```

Expected SoryOS priority:

```text
1002
```

## Rollback

Remove holds:

```bash
sudo soryos-remove-holds
```

Remove the lock package:

```bash
sudo apt remove soryos-system-lock
sudo apt update
```

Remove SoryOS APT config entirely:

```bash
sudo ./scripts/rollback-soryos-apt.sh
```
