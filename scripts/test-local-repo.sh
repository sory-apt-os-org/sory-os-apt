#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
INDEX_DIR="$ROOT_DIR/dists/stable/main/binary-amd64"
LOG_FILE="$LOG_DIR/test-local-repo.log"

mkdir -p "$LOG_DIR"
: > "$LOG_FILE"

fail() {
  printf 'FAIL: %s\n' "$1" | tee -a "$LOG_FILE" >&2
  exit 1
}

# Vérifie les fichiers d'index
[[ -f "$INDEX_DIR/Packages" ]] || fail "missing Packages index"
[[ -f "$INDEX_DIR/Packages.gz" ]] || fail "missing Packages.gz index"
SUITES="${SORYOS_SUITES:-stable testing nightly}"
for suite in $SUITES; do
  [[ -f "$ROOT_DIR/dists/$suite/Release" ]] || fail "missing Release file for $suite"
  [[ -f "$ROOT_DIR/dists/$suite/Release.gpg" ]] || fail "missing Release.gpg for $suite"
  [[ -f "$ROOT_DIR/dists/$suite/InRelease" ]] || fail "missing InRelease for $suite"

  KEYRING="$ROOT_DIR/keyrings/soryos-archive-keyring.gpg"
  if [[ -f "$KEYRING" ]]; then
    gpgv --keyring "$KEYRING" \
      "$ROOT_DIR/dists/$suite/Release.gpg" "$ROOT_DIR/dists/$suite/Release" >/dev/null 2>&1 \
      || fail "Release.gpg signature is invalid for $suite"
    gpgv --keyring "$KEYRING" \
      "$ROOT_DIR/dists/$suite/InRelease" >/dev/null 2>&1 \
      || fail "InRelease signature is invalid for $suite"
  fi
done

# Vérifie l'intégrité gzip
gzip -t "$INDEX_DIR/Packages.gz" || fail "Packages.gz is not valid gzip"



# Vérifie que le pool contient des .deb
shopt -s nullglob
for suite in $SUITES; do
  debs=("$ROOT_DIR/pool/$suite"/*.deb)
  [[ ${#debs[@]} -gt 0 ]] || fail "missing deb files in pool/$suite/"

  for deb in "${debs[@]}"; do
    dpkg-deb --info "$deb" >/dev/null || fail "invalid deb in $suite: $deb"
  done
  printf '%s: %d .deb files\n' "$suite" "${#debs[@]}" | tee -a "$LOG_FILE"
done

# Vérifie que chaque paquet dans l'index a un fichier .deb correspondant
for suite in $SUITES; do
  INDEX_DIR="$ROOT_DIR/dists/$suite/main/binary-amd64"
  while IFS= read -r line; do
    if [[ "$line" == Filename:* ]]; then
      filename="${line#Filename: }"
      if [[ ! -f "$ROOT_DIR/$filename" ]]; then
        fail "index $suite references missing file: $filename"
      fi
    fi
  done < "$INDEX_DIR/Packages"
done

# Compte les paquets par suite
for suite in $SUITES; do
  INDEX_DIR="$ROOT_DIR/dists/$suite/main/binary-amd64"
  pkg_count=$(grep -c "^Package:" "$INDEX_DIR/Packages" || true)
  deb_count=$(ls "$ROOT_DIR/pool/$suite"/*.deb 2>/dev/null | wc -l)
  printf '%s: %d packages, %d .deb files\n' "$suite" "$pkg_count" "$deb_count" | tee -a "$LOG_FILE"
done

printf 'local repository test complete\n' | tee -a "$LOG_FILE"
