#!/usr/bin/env bash
# Clone only the source tree needed to build one Release component.
# Standalone packages (adw-gtk3, distinst, …) skip cosmic-epoch + submodules.
set -euo pipefail

if [[ $# -lt 2 ]]; then
  printf 'usage: %s <work-dir> <component>\n' "$0" >&2
  exit 2
fi

WORK_DIR="$(cd "$1" && pwd)"
COMPONENT="$2"
EPOCH_DIR="$WORK_DIR/cosmic-epoch"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

require_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing required tool: %s\n' "$1" >&2
    exit 1
  }
}

require_tool git

if [[ -n "${SORYOS_GITHUB_PAT:-${GITHUB_TOKEN:-}}" ]]; then
  GIT_AUTH_TOKEN="${SORYOS_GITHUB_PAT:-${GITHUB_TOKEN}}"
  git config --global url."https://x-access-token:${GIT_AUTH_TOKEN}@github.com/".insteadOf "https://github.com/"
fi

sync_repo() {
  local url="$1"
  local ref="$2"
  local dest="$3"
  mkdir -p "$(dirname "$dest")"
  if [[ -d "$dest/.git" ]]; then
    git -C "$dest" fetch --depth 1 origin "$ref"
    git -C "$dest" checkout -f "$ref"
    git -C "$dest" reset --hard "origin/$ref" 2>/dev/null || git -C "$dest" reset --hard "$ref"
  else
    git clone --depth 1 --branch "$ref" "$url" "$dest"
  fi
}

# Components that live outside cosmic-epoch submodules (no libcosmic / submodule tree).
declare -A STANDALONE_URL=(
  [adw-gtk3]="https://github.com/sory-os-org/adw-gtk3.git"
  [distinst]="https://github.com/sory-os-org/distinst.git"
  [cosmic-sound-theme]="https://github.com/sory-os-org/cosmic-sound-theme.git"
)
declare -A STANDALONE_REF=(
  [adw-gtk3]="${SORYOS_ADW_GTK3_REF:-master}"
  [distinst]="${SORYOS_DISTINST_REF:-master}"
  [cosmic-sound-theme]=master
)

if [[ -n "${STANDALONE_URL[$COMPONENT]+x}" ]]; then
  mkdir -p "$EPOCH_DIR"
  sync_repo "${STANDALONE_URL[$COMPONENT]}" "${STANDALONE_REF[$COMPONENT]}" "$EPOCH_DIR/$COMPONENT"
  printf 'standalone source ready: %s -> %s/%s\n' "$COMPONENT" "$EPOCH_DIR" "$COMPONENT"
  exit 0
fi

printf 'component %s requires full cosmic-epoch tree; running prepare-cosmic-sources.sh\n' "$COMPONENT"
"$SCRIPT_DIR/prepare-cosmic-sources.sh" "$WORK_DIR"
