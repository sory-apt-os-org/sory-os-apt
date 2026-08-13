#!/usr/bin/env bash
# Clone cosmic-epoch + libcosmic exactly like redox/recipes/cosmic/*/recipe.toml:
#   git clone https://gitlab.com/sory-os/cosmic-epoch.git
#   git clone https://gitlab.com/sory-os/libcosmic.git  (sibling)
set -euo pipefail

if [[ $# -lt 1 ]]; then
  printf 'usage: %s <work-dir>\n' "$0" >&2
  exit 2
fi

WORK_DIR="$(cd "$1" && pwd)"
COSMIC_EPOCH_REPO="${SORYOS_COSMIC_EPOCH_REPO:-https://github.com/sory-os-org/cosmic-epoch.git}"
COSMIC_EPOCH_REF="${SORYOS_COSMIC_EPOCH_REF:-main}"
LIBCOSMIC_REPO="${SORYOS_LIBCOSMIC_REPO:-https://github.com/sory-os-org/libcosmic.git}"
LIBCOSMIC_REF="${SORYOS_LIBCOSMIC_REF:-main}"

require_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing required tool: %s\n' "$1" >&2
    exit 1
  }
}

require_tool git

mkdir -p "$WORK_DIR"

sync_repo() {
  local url="$1"
  local ref="$2"
  local dest="$3"
  if [[ -d "$dest/.git" ]]; then
    git -C "$dest" fetch --depth 1 origin "$ref"
    git -C "$dest" checkout -f "$ref"
    git -C "$dest" reset --hard "origin/$ref" 2>/dev/null || git -C "$dest" reset --hard "$ref"
  else
    git clone --depth 1 --branch "$ref" "$url" "$dest"
  fi
}

sync_repo "$COSMIC_EPOCH_REPO" "$COSMIC_EPOCH_REF" "$WORK_DIR/cosmic-epoch"
sync_repo "$LIBCOSMIC_REPO" "$LIBCOSMIC_REF" "$WORK_DIR/libcosmic"

git -C "$WORK_DIR/cosmic-epoch" submodule update --init --recursive cosmic-sory-ia 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/install-libcosmic-patch.sh" \
  "$WORK_DIR/cosmic-epoch" \
  "$WORK_DIR/libcosmic"

printf 'cosmic sources ready:\n'
printf '  cosmic-epoch: %s @ %s\n' "$COSMIC_EPOCH_REPO" "$COSMIC_EPOCH_REF"
printf '  libcosmic:    %s @ %s\n' "$LIBCOSMIC_REPO" "$LIBCOSMIC_REF"
printf '  work dir:     %s\n' "$WORK_DIR"
