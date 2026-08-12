# Chroot Tests

This directory is reserved for future chroot installation tests.

Required before ISO build release work:

- install SoryOS packages into a clean chroot
- run `soryos-install --dry-run`
- verify `soryos-diagnose`
- verify rollback behavior
- prove Ubuntu/Debian fallback repositories remain available

Commands:

```bash
sudo ./scripts/test-chroot-bootstrap.sh
sudo ./scripts/test-chroot-install.sh
sudo ./scripts/test-chroot-upgrade.sh
sudo ./scripts/test-chroot-rollback.sh
sudo ./scripts/test-chroot-recovery.sh
```

The recovery test removes the temporary rootfs at the end. If any step fails,
logs remain under `logs/chroot/` and the scripts preserve enough state for
debugging unless cleanup was already safe.
