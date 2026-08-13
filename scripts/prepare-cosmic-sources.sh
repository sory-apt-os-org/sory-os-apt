#!/usr/bin/env bash
# Clone cosmic-epoch + libcosmic exactly like redox/recipes/cosmic/*/recipe.toml:
#   git clone https://gitlab.com/sory-os/cosmic-epoch.git
#   git clone https://gitlab.com/sory-os/libcosmic.git  (sibling)
set -euo pipefail

if [[ $# -lt 1 ]]; then
  printf 'usage: %s <work-dir>\n' "$0" >&2
  exit 2
fi

mkdir -p "$1"
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

if [[ -n "${SORYOS_GITHUB_PAT:-${GITHUB_TOKEN:-}}" ]]; then
  GIT_AUTH_TOKEN="${SORYOS_GITHUB_PAT:-${GITHUB_TOKEN}}"
  git config --global url."https://x-access-token:${GIT_AUTH_TOKEN}@github.com/".insteadOf "https://github.com/"
fi

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

git -C "$WORK_DIR/cosmic-epoch" submodule update --init --recursive

# External pop-os repos referenced via path rewrites (not submodules of cosmic-epoch).
for ext_repo in cosmic-protocols dbus-settings-bindings; do
  sync_repo "https://github.com/pop-os/${ext_repo}.git" main "$WORK_DIR/cosmic-epoch/${ext_repo}"
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/rewrite-libcosmic-urls.sh" "$WORK_DIR/cosmic-epoch" "$WORK_DIR/libcosmic"
"$SCRIPT_DIR/regenerate-cargo-locks.sh" "$WORK_DIR/cosmic-epoch"

printf 'cosmic sources ready:\n'
printf '  cosmic-epoch: %s @ %s\n' "$COSMIC_EPOCH_REPO" "$COSMIC_EPOCH_REF"
printf '  libcosmic:    %s @ %s\n' "$LIBCOSMIC_REPO" "$LIBCOSMIC_REF"
printf '  work dir:     %s\n' "$WORK_DIR"
