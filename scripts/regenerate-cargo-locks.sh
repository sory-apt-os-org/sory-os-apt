#!/usr/bin/env bash
# Regenerate Cargo.lock files removed during libcosmic path rewrites.
# Debian packaging often runs `cargo vendor --locked` during clean.
set -euo pipefail

ROOT="${1:-}"
if [[ -z "$ROOT" ]]; then
  printf 'usage: %s <cosmic-epoch-dir>\n' "$0" >&2
  exit 2
fi

ROOT="$(cd "$ROOT" && pwd)"
export CARGO_NET_GIT_FETCH_WITH_CLI=true

regenerated=0
while IFS= read -r cargo_toml; do
  dir="$(dirname "$cargo_toml")"
  if grep -q '^\[workspace\]' "$cargo_toml"; then
    printf 'regenerating lockfile in %s\n' "$dir"
    (cd "$dir" && cargo generate-lockfile)
    regenerated=$((regenerated + 1))
  fi
done < <(find "$ROOT" -name Cargo.toml -not -path '*/target/*' | sort)

printf 'regenerated %s workspace lockfiles under %s\n' "$regenerated" "$ROOT"
