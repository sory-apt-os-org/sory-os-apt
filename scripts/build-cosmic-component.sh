#!/usr/bin/env bash
# Build one COSMIC component as .deb from GitLab sources (CI or explicit local use).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPONENT="${1:-}"
WORK_DIR="${SORYOS_COSMIC_WORK:-$ROOT_DIR/tmp/cosmic-work-$(id -u)}"

if [[ -z "$COMPONENT" ]]; then
  printf 'usage: %s <component-name>\n' "$0" >&2
  exit 2
fi

"$ROOT_DIR/scripts/prepare-cosmic-sources.sh" "$WORK_DIR"

COMPONENT_DIR="$WORK_DIR/cosmic-epoch/$COMPONENT"
if [[ ! -d "$COMPONENT_DIR" ]]; then
  printf 'component not found in cosmic-epoch: %s\n' "$COMPONENT" >&2
  exit 1
fi
if [[ ! -f "$COMPONENT_DIR/debian/control" ]]; then
  printf 'no debian/control for %s — skipping dpkg-buildpackage\n' "$COMPONENT" >&2
  exit 0
fi

cd "$COMPONENT_DIR"
dpkg-buildpackage -us -uc -b
printf 'built %s in %s\n' "$COMPONENT" "$WORK_DIR/cosmic-epoch"
