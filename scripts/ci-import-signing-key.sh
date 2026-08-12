#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GNUPGHOME_DIR="${SORYOS_GNUPGHOME:-$ROOT_DIR/.private/gnupg}"
KEY_EMAIL="${SORYOS_APT_KEY_EMAIL:-apt@soryos.local}"
KEYRING_DIR="$ROOT_DIR/keyrings"

mkdir -p "$GNUPGHOME_DIR" "$KEYRING_DIR"
chmod 700 "$GNUPGHOME_DIR"
export GNUPGHOME="$GNUPGHOME_DIR"

if [[ -n "${SORYOS_GPG_PRIVATE_KEY:-}" ]]; then
  echo "$SORYOS_GPG_PRIVATE_KEY" | gpg --batch --import 2>&1
  echo "Imported GPG key from SORYOS_GPG_PRIVATE_KEY"
else
  echo "SORYOS_GPG_PRIVATE_KEY not set, generating ephemeral key"
  cat > "$ROOT_DIR/tmp-gpg-key.conf" <<EOF
Key-Type: RSA
Key-Length: 4096
Name-Real: SoryOS APT Repository
Name-Email: $KEY_EMAIL
Expire-Date: 0
%no-protection
%commit
EOF
  gpg --batch --generate-key "$ROOT_DIR/tmp-gpg-key.conf"
  rm -f "$ROOT_DIR/tmp-gpg-key.conf"
fi

KEY_FPR="$(gpg --batch --with-colons --list-secret-keys "$KEY_EMAIL" | awk -F: '/^fpr:/ {print $10; exit}')"
if [[ -z "$KEY_FPR" ]]; then
  printf 'failed to determine signing key fingerprint\n' >&2
  exit 1
fi

gpg --batch --armor --export "$KEY_FPR" > "$KEYRING_DIR/soryos-archive-keyring.asc"
gpg --batch --export "$KEY_FPR" > "$KEYRING_DIR/soryos-archive-keyring.gpg"
echo "$KEY_FPR" > "$KEYRING_DIR/FINGERPRINT"

printf 'SoryOS APT signing key ready: %s\n' "$KEY_FPR"
