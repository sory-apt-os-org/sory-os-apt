#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
POOL_DIR="$ROOT_DIR/pool/stable"
SORYOS_SUITE="${SORYOS_SUITE:-stable}"
PKG_DIR="$ROOT_DIR/templates"
TMP_DIR="$ROOT_DIR/tmp/build-$(id -u)"
LOG_FILE="$LOG_DIR/build-packages.log"

mkdir -p "$LOG_DIR" "$POOL_DIR" "$TMP_DIR"
: > "$LOG_FILE"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing required tool: %s\n' "$1" | tee -a "$LOG_FILE" >&2
    exit 1
  fi
}

require_tool dpkg-deb

build_package() {
  local name="$1"
  local control_file="$PKG_DIR/$name/control"
  local work_dir="$TMP_DIR/$name"
  local payload_dir="$PKG_DIR/$name/root"
  local doc_dir="$work_dir/usr/share/doc/$name"
  local marker_dir="$work_dir/usr/share/soryos/modules"
  local version
  local arch
  local deb

  if [[ ! -d "$PKG_DIR/$name" ]]; then
    printf 'skipping %s: template directory not found\n' "$name" | tee -a "$LOG_FILE" >&2
    return 0
  fi
  if [[ ! -f "$control_file" ]]; then
    printf 'missing control file: %s\n' "$control_file" | tee -a "$LOG_FILE" >&2
    exit 1
  fi

  version="$(awk '/^Version: / {print $2}' "$control_file")"
  arch="$(awk '/^Architecture: / {print $2}' "$control_file")"
  deb="$POOL_DIR/${name}_${version}_${arch}.deb"

  rm -rf "$work_dir"
  mkdir -p "$work_dir/DEBIAN" "$doc_dir" "$marker_dir"
  cp "$control_file" "$work_dir/DEBIAN/control"

  if [[ -d "$payload_dir" ]]; then
    cp -a "$payload_dir"/. "$work_dir"/
  fi

  if [[ "$name" == "soryos-archive-keyring" ]]; then
    if [[ ! -f "$ROOT_DIR/keyrings/soryos-archive-keyring.gpg" ]]; then
      printf 'missing keyring for %s: run ./scripts/init-signing-key.sh first\n' "$name" | tee -a "$LOG_FILE" >&2
      exit 1
    fi
    mkdir -p "$work_dir/usr/share/keyrings"
    cp "$ROOT_DIR/keyrings/soryos-archive-keyring.gpg" "$work_dir/usr/share/keyrings/soryos-archive-keyring.gpg"
  fi

  cat > "$doc_dir/README" <<EOF
$name is a SoryOS integration package.

It is intentionally minimal and reversible.
EOF

  printf '%s\n' "$name" > "$marker_dir/$name"
  chmod -R go-w "$work_dir"
  find "$work_dir/usr/bin" -type f -exec chmod 0755 {} + 2>/dev/null || true
  find "$work_dir/usr/lib/soryos" -type f -exec chmod 0755 {} + 2>/dev/null || true
  find "$work_dir/usr/lib/soryos/identity" -type f -exec chmod 0644 {} + 2>/dev/null || true

  dpkg-deb --build "$work_dir" "$deb" >> "$LOG_FILE" 2>&1
  printf 'built %s\n' "$deb" | tee -a "$LOG_FILE"
}

build_ia_package() {
  local src_dir="$1"
  local name="cosmic-sory-ia"
  local control_file="$PKG_DIR/$name/control"
  local work_dir="$TMP_DIR/$name"
  local version
  local arch
  local deb

  version="$(awk '/^Version: / {print $2}' "$control_file")"
  arch="$(awk '/^Architecture: / {print $2}' "$control_file")"
  deb="$POOL_DIR/${name}_${version}_${arch}.deb"

  rm -rf "$work_dir"
  mkdir -p "$work_dir/DEBIAN" "$work_dir/usr/share/doc/$name" "$work_dir/usr/share/soryos/modules"
  cp "$control_file" "$work_dir/DEBIAN/control"

  if [[ "${BUILD_IA_BINARIES:-0}" == "1" ]]; then
    mkdir -p "$work_dir/usr/bin"
    (cd "$src_dir" && cargo build --release --jobs "$(nproc)" 2>&1 | tee -a "$LOG_FILE")
    local target_dir="$src_dir/target/release"
    for bin in sory sory-desktop sory-tui sory-app-server sory-mcp-server sory-exec sory-execpolicy sory-file-search sory-linux-sandbox sory-responses-api-proxy sory-stdio-to-uds sory-execve-wrapper; do
      [[ -f "$target_dir/$bin" ]] && cp "$target_dir/$bin" "$work_dir/usr/bin/"
    done
  fi

  cat > "$work_dir/usr/share/doc/$name/README" <<EOF
cosmic-sory-ia metapackage

Contains: SoryOS AI engine binaries.
Build from: sory-x/cosmic-epoch/cosmic-sory-ia
EOF

  printf '%s\n' "$name" > "$work_dir/usr/share/soryos/modules/$name"
  chmod -R go-w "$work_dir"
  find "$work_dir/usr/bin" -type f -exec chmod 0755 {} + 2>/dev/null || true
  dpkg-deb --build "$work_dir" "$deb" >> "$LOG_FILE" 2>&1
  printf 'built %s\n' "$deb" | tee -a "$LOG_FILE"
}

rm -f "$POOL_DIR"/*.deb

echo "DEBUG: GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo 'not-git')"
echo "DEBUG: script_dir=$(cd "$(dirname "$0")" && pwd)"
echo "DEBUG: templates=$(ls -d $PKG_DIR/*/ 2>/dev/null | wc -l) dirs"
build_package soryos-archive-keyring
build_package soryos-system-lock
build_package soryos-identity
build_package soryos-appstream-data
build_package soryos-icon-theme
build_package soryos-sound-theme
build_package soryos-hp-vendor
build_package soryos-hp-vendor-dkms
build_package soryos-hp-wallpapers
build_package soryos-wallpapers
build_package soryos-acpi-dkms
build_package soryos-dkms
build_package soryos-io-dkms
build_package soryos-driver
build_package soryos-driver-nvidia
build_package soryos-firmware-daemon
build_package soryos-oled
build_package soryos-power
build_package gnome-shell-extension-soryos-power
build_package soryos-desktop
build_package libcosmic

# ── cosmic-sory-ia : construit le métapaquet des binaires AI ─────
IA_SRC_DIR="$ROOT_DIR/../cosmic-epoch/cosmic-sory-ia"
if [[ -d "$IA_SRC_DIR" ]]; then
  printf 'building cosmic-sory-ia from %s\n' "$IA_SRC_DIR" | tee -a "$LOG_FILE"
  build_ia_package "$IA_SRC_DIR"
else
  printf 'WARNING: %s not found, building empty cosmic-sory-ia\n' "$IA_SRC_DIR" | tee -a "$LOG_FILE"
  build_package cosmic-sory-ia
fi

printf 'package build complete\n' | tee -a "$LOG_FILE"
