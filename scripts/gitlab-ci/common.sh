#!/usr/bin/env bash
set -euo pipefail

APT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../soryos-urls.sh
source "$APT_ROOT/scripts/soryos-urls.sh"

export DEBIAN_FRONTEND=noninteractive
export CARGO_TERM_COLOR=always
export SORYOS_COSMIC_WORK="${SORYOS_COSMIC_WORK:-/tmp/soryos-sources}"
export SORYOS_COSMIC_UTILS_WORK="${SORYOS_COSMIC_UTILS_WORK:-/tmp/soryos-cosmic-utils}"

soryos_ci_install_build_deps() {
  apt-get update
  apt-get install -y \
    build-essential devscripts debhelper dpkg-dev \
    rustup pkg-config cmake just curl jq openssl gnupg gzip b3sum \
    libwayland-dev libxkbcommon-dev libglib2.0-dev \
    libclang-dev libpipewire-0.3-dev libudev-dev \
    libinput-dev libgbm-dev libseat-dev libsystemd-dev \
    libdbus-1-dev libpam0g-dev libssl-dev libzstd-dev \
    libpixman-1-dev libfontconfig-dev libfreetype-dev \
    libegl1-mesa-dev libxcb1-dev libdisplay-info-dev \
    libdav1d-dev libexpat1-dev \
    libflatpak-dev libpolkit-agent-1-dev \
    libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    libsqlite3-dev libqalculate-dev libheif-dev libturbojpeg0-dev \
    mold nasm imagemagick fonts-open-sans meson patchelf \
    sassc ninja-build libparted-dev apt-utils rsync git git-lfs
  rustup default stable
  rustup toolchain install 1.93 --profile minimal
  if ! command -v just >/dev/null; then
    cargo install just --locked
  fi
  export PATH="$HOME/.cargo/bin:$PATH"
}

soryos_ci_install_publish_deps() {
  apt-get update
  apt-get install -y apt-utils dpkg-dev gnupg gzip b3sum jq openssl curl rsync git
}

soryos_ci_require_glab() {
  if ! command -v glab >/dev/null; then
    curl -fsSL "https://gitlab.com/gitlab-org/cli/-/releases/v1.53.0/downloads/glab_1.53.0_linux_amd64.deb" \
      -o /tmp/glab.deb
    apt-get install -y /tmp/glab.deb
  fi
  if [[ -n "${GITLAB_TOKEN:-}" ]]; then
    export GLAB_TOKEN="$GITLAB_TOKEN"
  elif [[ -n "${CI_JOB_TOKEN:-}" ]]; then
    export GLAB_TOKEN="$CI_JOB_TOKEN"
  fi
}

soryos_ci_sign_release_out() {
  local tag="$1"
  local release_out="$2"
  cd "$APT_ROOT"
  mkdir -p pool/stable dists/stable/main/binary-amd64 keyrings
  cp "$release_out"/pool/stable/*.deb pool/stable/ 2>/dev/null || cp "$release_out"/*.deb pool/stable/
  export SORYOS_SUITES=stable
  ./scripts/ci-import-signing-key.sh
  ./scripts/generate-index.sh
  ./scripts/sign-repository.sh
  cp keyrings/soryos-archive-keyring.gpg "$release_out/"
  cp dists/stable/Release "$release_out/"
  cp dists/stable/Release.gpg "$release_out/"
  cp dists/stable/InRelease "$release_out/"
  cp dists/stable/main/binary-amd64/Packages "$release_out/"
  cp dists/stable/main/binary-amd64/Packages.gz "$release_out/"
  cp pool/stable/*.deb "$release_out/"
  local base_url
  base_url="$(soryos_release_asset_base_url "$tag")"
  python3 scripts/generate-release-index.py \
    "$release_out" \
    "$tag" \
    "$SORYOS_APT_REPO" \
    "$release_out/index.json" \
    "$base_url" \
    "$release_out/soryos-archive-keyring.gpg"
  test -n "${SORYOS_INDEX_PRIVATE_KEY_PEM:-}" || {
    printf 'Missing SORYOS_INDEX_PRIVATE_KEY_PEM CI variable\n' >&2
    exit 1
  }
  umask 077
  printf '%s\n' "$SORYOS_INDEX_PRIVATE_KEY_PEM" > index-signing-key.pem
  ./scripts/sign-release-index.sh "$release_out/index.json" index-signing-key.pem
  openssl pkey -in index-signing-key.pem -pubout -out "$release_out/index-signing-key.pub.pem"
  openssl pkey -pubin -in "$release_out/index-signing-key.pub.pem" \
    -outform DER | tail -c 32 | od -An -tx1 -v | tr -d ' \n' \
    > "$release_out/index-signing-key.pub.hex"
  rm -f index-signing-key.pem
}

soryos_ci_publish_release() {
  local tag="$1"
  local release_out="$2"
  local title="${3:-SoryOS Debian packages ($tag)}"
  local notes="${4:-Immutable SoryOS .deb Release on GitLab. Catalog on GitLab Pages.}"
  soryos_ci_require_glab
  if glab release view "$tag" --repo "$SORYOS_APT_PROJECT_PATH" >/dev/null 2>&1; then
    printf 'Release %s exists — uploading assets\n' "$tag"
  else
    glab release create "$tag" \
      --repo "$SORYOS_APT_PROJECT_PATH" \
      --name "$title" \
      --notes "$notes"
  fi
  while IFS= read -r -d '' asset; do
    glab release upload "$tag" "$asset" --repo "$SORYOS_APT_PROJECT_PATH" || \
      glab release upload "$tag" "$asset" --repo "$SORYOS_APT_PROJECT_PATH" --clobber
    sleep 1
  done < <(find "$release_out" -maxdepth 1 -type f -print0 | sort -z)
  printf 'Release: %s/%s/-/releases/%s\n' "$SORYOS_GIT_HOST" "$SORYOS_APT_PROJECT_PATH" "$tag"
}
