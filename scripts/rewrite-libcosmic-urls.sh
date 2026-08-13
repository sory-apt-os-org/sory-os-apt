#!/usr/bin/env bash
# Point libcosmic git dependencies at the sibling libcosmic checkout used in CI.
set -euo pipefail

ROOT="${1:-}"
LIBCOSMIC_DIR="${2:-}"
if [[ -z "$ROOT" ]]; then
  printf 'usage: %s <cosmic-epoch-dir> [libcosmic-dir]\n' "$0" >&2
  exit 2
fi

ROOT="$(cd "$ROOT" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "$LIBCOSMIC_DIR" ]]; then
  LIBCOSMIC_DIR="$(cd "$ROOT/.." && pwd)/libcosmic"
fi
LIBCOSMIC_DIR="$(cd "$LIBCOSMIC_DIR" && pwd)"

exec python3 "$SCRIPT_DIR/rewrite-libcosmic-paths.py" "$ROOT" "$LIBCOSMIC_DIR"
