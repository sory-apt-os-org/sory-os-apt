#!/usr/bin/env bash
# Swap pop-os/libcosmic git URLs to sory-os-org/libcosmic in a cosmic-epoch tree.
# Keeps the same URL shape Pop!_OS uses (.git, trailing slash, etc.).
set -euo pipefail

ROOT="${1:-}"
if [[ -z "$ROOT" ]]; then
  printf 'usage: %s <cosmic-epoch-dir>\n' "$0" >&2
  exit 2
fi

ROOT="$(cd "$ROOT" && pwd)"

rewrite_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  perl -pi -e 's|https://github.com/pop-os/libcosmic|https://github.com/sory-os-org/libcosmic|g' "$file"
}

while IFS= read -r -d '' file; do
  rewrite_file "$file"
done < <(find "$ROOT" -name Cargo.toml -not -path '*/target/*' -print0)

while IFS= read -r -d '' file; do
  rewrite_file "$file"
done < <(find "$ROOT" -name Cargo.lock -not -path '*/target/*' -print0)

printf 'rewrote libcosmic git URLs under %s\n' "$ROOT"
