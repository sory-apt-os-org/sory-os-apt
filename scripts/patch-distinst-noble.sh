#!/usr/bin/env bash
# distinst: loopdev 0.4 vendors bindgen 0.59, which breaks on Ubuntu 24.04 loop.h.
set -euo pipefail

ROOT="${1:-}"
PATCH_VENDOR="${2:-${GITHUB_WORKSPACE}/soryos-apt/scripts/patch-loopdev-vendor.sh}"

if [[ -z "$ROOT" || ! -f "$ROOT/Cargo.toml" ]]; then
  printf 'usage: %s <distinst-dir> [patch-loopdev-vendor.sh]\n' "$0" >&2
  exit 2
fi

ROOT="$(cd "$ROOT" && pwd)"
RULES="$ROOT/debian/rules"

if [[ ! -x "$PATCH_VENDOR" ]]; then
  printf 'missing patch script: %s\n' "$PATCH_VENDOR" >&2
  exit 2
fi

# Drop the invalid loopdev 0.5.1 patch from earlier CI attempts.
if grep -q 'loopdev = { version = "0.5.1" }' "$ROOT/Cargo.toml"; then
  awk '
    /^\[patch\.crates-io\]/ { skip=1; next }
    skip && /^loopdev = / { next }
    skip && /^$/ { skip=0; next }
    skip && /^\[/ { skip=0 }
    !skip { print }
  ' "$ROOT/Cargo.toml" > "$ROOT/Cargo.toml.tmp"
  mv "$ROOT/Cargo.toml.tmp" "$ROOT/Cargo.toml"
fi

if grep -q 'SORYOS_PATCH_LOOPDEV_VENDOR' "$RULES" || grep -q 'patch-loopdev-vendor.sh' "$RULES"; then
  printf 'distinst debian/rules already patched for loopdev vendor bindgen\n'
  exit 0
fi

python3 - "$RULES" "$PATCH_VENDOR" <<'PY'
from pathlib import Path
import sys

rules = Path(sys.argv[1])
patch_script = sys.argv[2]
text = rules.read_text()
needle = '\t\ttar pcfJ vendor.tar.xz vendor; \\\n'
insert = (
    f'\t\t"{patch_script}" "$$(pwd)/vendor"; \\\n'
    '\t\t: SORYOS_PATCH_LOOPDEV_VENDOR; \\\n'
)
if needle not in text:
    sys.exit('could not locate cargo vendor stanza in debian/rules')
rules.write_text(text.replace(needle, insert + needle, 1))
PY

printf 'patched distinst debian/rules: loopdev vendor bindgen 0.59 -> 0.65\n'
