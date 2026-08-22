#!/usr/bin/env bash
set -euo pipefail

UTILS_DIR="${1:-}"
LIBCOSMIC_DIR="${2:-}"

if [[ -z "$UTILS_DIR" || -z "$LIBCOSMIC_DIR" ]]; then
  printf 'usage: %s <cosmic-utils-dir> <libcosmic-dir>\n' "$0" >&2
  exit 2
fi

UTILS_DIR="$(cd "$UTILS_DIR" && pwd)"
LIBCOSMIC_DIR="$(cd "$LIBCOSMIC_DIR" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 "$SCRIPT_DIR/rewrite-libcosmic-paths.py" "$UTILS_DIR" "$LIBCOSMIC_DIR"
python3 "$SCRIPT_DIR/rewrite-cosmic-utils-deps.py" "$UTILS_DIR"
