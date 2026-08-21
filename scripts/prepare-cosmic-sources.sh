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

# Migrated repos may lack Git LFS blobs on sory-os-org; screenshots are not needed to build.
GIT_LFS_SKIP_SMUDGE=1 git -C "$WORK_DIR/cosmic-epoch" submodule update --init --recursive

# network-manager subscription is required by cosmic-initial-setup but not yet on pop-os master.
NM_DEST="$WORK_DIR/cosmic-epoch/cosmic-settings/subscriptions/network-manager"
if [[ ! -f "$NM_DEST/Cargo.toml" ]]; then
  mkdir -p "$(dirname "$NM_DEST")"
  NM_VENDOR="$WORK_DIR/.cosmic-settings-nm-vendor"
  rm -rf "$NM_VENDOR"
  git clone --depth 1 --filter=blob:none --sparse \
    https://github.com/xiaoyu-work/claw-os.git "$NM_VENDOR"
  git -C "$NM_VENDOR" sparse-checkout set desktop/settings/subscriptions/network-manager
  cp -a "$NM_VENDOR/desktop/settings/subscriptions/network-manager" "$NM_DEST"
  rm -rf "$NM_VENDOR"
fi

# External vendor repos on sory-os-org referenced via path rewrites (not submodules of cosmic-epoch).
declare -A EXT_REPO_REFS=(
  [cosmic-protocols]=main
  [dbus-settings-bindings]=main
  [freedesktop-icons]=main
  [launch-pad]=master
  [xdg-shell-wrapper]=master
  [cosmic-mime-apps]=main
)
for ext_repo in cosmic-protocols dbus-settings-bindings freedesktop-icons launch-pad xdg-shell-wrapper cosmic-mime-apps; do
  sync_repo "https://github.com/sory-os-org/${ext_repo}.git" "${EXT_REPO_REFS[$ext_repo]}" "$WORK_DIR/cosmic-epoch/${ext_repo}"
done

# simple-wrapper is listed in .gitmodules but not yet registered in cosmic-epoch's git index.
if [[ ! -f "$WORK_DIR/cosmic-epoch/simple-wrapper/Cargo.toml" ]]; then
  sync_repo "https://github.com/sory-os-org/simple-wrapper.git" master_jammy "$WORK_DIR/cosmic-epoch/simple-wrapper"
fi

# GTK theme required by cosmic-settings-daemon (not in cosmic-epoch submodules).
if [[ ! -f "$WORK_DIR/cosmic-epoch/adw-gtk3/debian/control" ]]; then
  ADW_GTK3_REPO="${SORYOS_ADW_GTK3_REPO:-https://github.com/sory-os-org/adw-gtk3.git}"
  ADW_GTK3_REF="${SORYOS_ADW_GTK3_REF:-master}"
  sync_repo "$ADW_GTK3_REPO" "$ADW_GTK3_REF" "$WORK_DIR/cosmic-epoch/adw-gtk3"
fi

# Live ISO installer (distinst + libdistinst); sources only, published via SoryOS Release.
if [[ ! -f "$WORK_DIR/cosmic-epoch/distinst/debian/control" ]]; then
  DISTINST_REPO="${SORYOS_DISTINST_REPO:-https://github.com/sory-os-org/distinst.git}"
  DISTINST_REF="${SORYOS_DISTINST_REF:-master}"
  sync_repo "$DISTINST_REPO" "$DISTINST_REF" "$WORK_DIR/cosmic-epoch/distinst"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/rewrite-libcosmic-urls.sh" "$WORK_DIR/cosmic-epoch" "$WORK_DIR/libcosmic"
"$SCRIPT_DIR/patch-cosmic-ci-fixes.sh" "$WORK_DIR/cosmic-epoch"

printf 'cosmic sources ready:\n'
printf '  cosmic-epoch: %s @ %s\n' "$COSMIC_EPOCH_REPO" "$COSMIC_EPOCH_REF"
printf '  libcosmic:    %s @ %s\n' "$LIBCOSMIC_REPO" "$LIBCOSMIC_REF"
printf '  work dir:     %s\n' "$WORK_DIR"
