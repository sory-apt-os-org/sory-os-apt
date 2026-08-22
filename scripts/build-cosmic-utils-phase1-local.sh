#!/usr/bin/env bash
# Build all phase-1 cosmic-utils .deb packages locally (no GitHub Actions).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${SORYOS_COSMIC_UTILS_WORK:-/tmp/soryos-cu-local-$(id -u)}"
OUT_DIR="${1:-$ROOT/pool/stable/cosmic-utils}"
MANIFEST="$ROOT/cosmic-apps/cosmic-utils-manifest.json"
PHASE="${SORYOS_CU_PHASE:-1}"

mkdir -p "$OUT_DIR"

COMPONENTS="$(
  python3 - "$MANIFEST" "$PHASE" <<'PY'
import json, sys
manifest = json.load(open(sys.argv[1]))
phase = int(sys.argv[2])
for c in manifest["components"]:
    if c.get("phase") == phase:
        print(c["name"])
PY
)"

printf 'work dir: %s\n' "$WORK_DIR"
printf 'output:   %s\n' "$OUT_DIR"
printf 'building phase %s components...\n' "$PHASE"

"$ROOT/scripts/prepare-cosmic-utils-sources.sh" "$WORK_DIR" all

failed=()
for name in $COMPONENTS; do
  printf '\n=== %s ===\n' "$name"
  if ! "$ROOT/scripts/build-cosmic-utils-deb.sh" "$WORK_DIR" "$name" "$OUT_DIR"; then
    failed+=("$name")
  fi
done

printf '\n--- summary ---\n'
ls -la "$OUT_DIR"/*.deb 2>/dev/null || printf 'no .deb produced\n'
if ((${#failed[@]} > 0)); then
  printf 'failed: %s\n' "${failed[*]}"
  exit 1
fi
