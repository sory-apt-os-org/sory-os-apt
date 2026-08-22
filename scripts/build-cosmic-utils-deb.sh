#!/usr/bin/env bash
# Build one cosmic-utils community component as a .deb package.
set -euo pipefail

if [[ $# -lt 2 ]]; then
  printf 'usage: %s <work-dir> <component> [output-dir]\n' "$0" >&2
  exit 2
fi

mkdir -p "$1"
WORK_DIR="$(cd "$1" && pwd)"
COMPONENT="$2"
OUT_DIR="${3:-$WORK_DIR/debs}"
UTILS_DIR="$WORK_DIR/cosmic-utils"
COMPONENT_DIR="$UTILS_DIR/$COMPONENT"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$APT_ROOT/cosmic-apps/cosmic-utils-manifest.json"

require_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing required tool: %s\n' "$1" >&2
    exit 1
  }
}

require_tool python3
require_tool dpkg-deb

mkdir -p "$OUT_DIR"

read -r BUILD_KIND PACKAGE_NAME VERSION ARCH DESCRIPTION BINARY_NAME <<META
$(python3 - "$MANIFEST" "$COMPONENT" "$COMPONENT_DIR" <<'PY'
import json
import re
import sys
from pathlib import Path

manifest = json.load(open(sys.argv[1]))
name = sys.argv[2]
component_dir = Path(sys.argv[3])
entry = next(c for c in manifest["components"] if c["name"] == name)
cargo = component_dir / "Cargo.toml"
version = "0.0.1"
package = entry.get("package", name)
if cargo.is_file():
    text = cargo.read_text()
    if "[workspace.package]" in text:
        m = re.search(r'^\s*version\s*=\s*"([^"]+)"', text, re.M)
        if m:
            version = m.group(1)
    else:
        m = re.search(r'^\s*version\s*=\s*"([^"]+)"', text, re.M)
        if m:
            version = m.group(1)
arch = entry.get("architecture", "amd64")
binary = entry.get("binary", package)
print(
    entry["build"],
    package,
    version,
    arch,
    entry.get("description", entry["name"]),
    binary,
    sep="\n",
)
PY
)
META

if [[ ! -d "$COMPONENT_DIR" ]]; then
  printf 'component directory not found: %s\n' "$COMPONENT_DIR" >&2
  exit 1
fi

PKG_ROOT="$(mktemp -d)"
trap 'rm -rf "$PKG_ROOT"' EXIT
CONTROL_DIR="$PKG_ROOT/DEBIAN"
mkdir -p "$CONTROL_DIR"

write_control() {
  cat >"$CONTROL_DIR/control" <<EOF
Package: $PACKAGE_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Maintainer: SoryOS Maintainers <maintainers@soryos.local>
Depends: \${misc:Depends}
Description: $DESCRIPTION
 Community COSMIC application packaged for SoryOS.
EOF
}

build_data_themes() {
  write_control
  install -d "$PKG_ROOT/usr/share/cosmic/themes/community"
  shopt -s nullglob
  for theme in "$COMPONENT_DIR"/*.ron; do
    install -Dm0644 "$theme" "$PKG_ROOT/usr/share/cosmic/themes/community/$(basename "$theme")"
  done
}

build_data_wallpapers() {
  write_control
  install -d "$PKG_ROOT/usr/share/backgrounds/cosmic-ext-brand"
  if [[ -d "$COMPONENT_DIR/3840x2160" ]]; then
    install -Dm0644 "$COMPONENT_DIR/3840x2160"/*.png "$PKG_ROOT/usr/share/backgrounds/cosmic-ext-brand/" 2>/dev/null || true
  fi
  if [[ -d "$COMPONENT_DIR/5120x1440" ]]; then
    install -d "$PKG_ROOT/usr/share/backgrounds/cosmic-ext-brand/5120x1440"
    install -Dm0644 "$COMPONENT_DIR/5120x1440"/*.png "$PKG_ROOT/usr/share/backgrounds/cosmic-ext-brand/5120x1440/" 2>/dev/null || true
  fi
}

build_cargo_workspace() {
  write_control
  cd "$COMPONENT_DIR"
  "$SCRIPT_DIR/ensure-cargo-lock.sh" "$PWD"
  cargo build --release -p "$BINARY_NAME"
  install -Dm0755 "target/release/$BINARY_NAME" "$PKG_ROOT/usr/bin/$BINARY_NAME"
  shopt -s nullglob
  for desktop in "$COMPONENT_DIR"/data/*.desktop; do
    install -Dm0644 "$desktop" "$PKG_ROOT/usr/share/applications/$(basename "$desktop")"
  done
  for icon in "$COMPONENT_DIR"/data/*.svg; do
    install -Dm0644 "$icon" "$PKG_ROOT/usr/share/icons/hicolor/scalable/apps/$(basename "$icon")"
  done
}

build_cargo_just() {
  write_control
  cd "$COMPONENT_DIR"
  "$SCRIPT_DIR/ensure-cargo-lock.sh" "$PWD"
  if command -v just >/dev/null 2>&1 && grep -q '^install:' justfile 2>/dev/null; then
    just build-release
    just rootdir="$PKG_ROOT" install
    if grep -q '^install-schema:' justfile 2>/dev/null; then
      just rootdir="$PKG_ROOT" install-schema || true
    fi
  else
    cargo build --release
    bin="$BINARY_NAME"
    if [[ ! -f "target/release/$bin" ]]; then
      bin="$(python3 - <<'PY'
import re
from pathlib import Path
text = Path("Cargo.toml").read_text()
m = re.search(r'^\s*name\s*=\s*"([^"]+)"', text, re.M)
print(m.group(1) if m else "app")
PY
)"
    fi
    install -Dm0755 "target/release/$bin" "$PKG_ROOT/usr/bin/$bin"
    shopt -s nullglob
    for desktop in res/*.desktop res/app.desktop res/desktop_entry.desktop; do
      [[ -f "$desktop" ]] || continue
      appid="$(basename "$desktop")"
      install -Dm0644 "$desktop" "$PKG_ROOT/usr/share/applications/$appid"
    done
    for metainfo in res/metainfo.xml res/*.metainfo.xml; do
      [[ -f "$metainfo" ]] || continue
      install -Dm0644 "$metainfo" "$PKG_ROOT/usr/share/metainfo/$(basename "$metainfo")"
    done
  fi
}

case "$BUILD_KIND" in
  data-themes) build_data_themes ;;
  data-wallpapers) build_data_wallpapers ;;
  cargo-workspace) build_cargo_workspace ;;
  cargo-just) build_cargo_just ;;
  *)
    printf 'unsupported build kind: %s\n' "$BUILD_KIND" >&2
    exit 1
    ;;
esac

DEB_FILE="$OUT_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
dpkg-deb --build --root-owner-group "$PKG_ROOT" "$DEB_FILE"
printf 'built %s\n' "$DEB_FILE"
