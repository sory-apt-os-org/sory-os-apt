#!/usr/bin/env bash
# After cargo vendor: loopdev pins bindgen 0.59, broken on Ubuntu 24.04 loop.h.
set -euo pipefail

VENDOR_DIR="${1:-}"
if [[ -z "$VENDOR_DIR" || ! -d "$VENDOR_DIR" ]]; then
  printf 'usage: %s <vendor-dir>\n' "$0" >&2
  exit 2
fi

VENDOR_DIR="$(cd "$VENDOR_DIR" && pwd)"

patch_loopdev() {
  local cargo="$1"
  [[ -f "$cargo" ]] || return 0
  if ! grep -q 'version = "0.59' "$cargo"; then
    return 0
  fi
  sed -i 's/version = "0.59/version = "0.65/g' "$cargo"
  python3 - "$cargo" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

cargo = Path(sys.argv[1])
checksum = cargo.parent / ".cargo-checksum.json"
if not checksum.exists():
    sys.exit(0)
data = json.loads(checksum.read_text())
data["files"]["Cargo.toml"] = hashlib.sha256(cargo.read_bytes()).hexdigest()
checksum.write_text(json.dumps(data))
PY
  printf 'patched %s: bindgen 0.59 -> 0.65\n' "$cargo"
}

shopt -s nullglob
for cargo in "$VENDOR_DIR"/loopdev/Cargo.toml "$VENDOR_DIR"/loopdev-*/Cargo.toml; do
  patch_loopdev "$cargo"
done
