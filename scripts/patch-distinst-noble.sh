#!/usr/bin/env bash
# distinst vendor loopdev 0.4 + bindgen 0.59 fails on noble loop.h (GitHub Actions).
set -euo pipefail

ROOT="${1:-}"
if [[ -z "$ROOT" || ! -f "$ROOT/Cargo.toml" ]]; then
  printf 'usage: %s <distinst-dir>\n' "$0" >&2
  exit 2
fi

ROOT="$(cd "$ROOT" && pwd)"
if grep -q '^\[patch.crates-io\]' "$ROOT/Cargo.toml" && grep -q 'loopdev' "$ROOT/Cargo.toml"; then
  printf 'distinst already patched for loopdev\n'
  exit 0
fi

cat >> "$ROOT/Cargo.toml" <<'EOF'

# SoryOS CI: loopdev 0.4 bindgen breaks on Ubuntu 24.04 linux/loop.h
[patch.crates-io]
loopdev = { version = "0.5.1" }
EOF

printf 'patched distinst Cargo.toml: loopdev -> 0.5.1\n'
