#!/usr/bin/env bash
# Publish the lightweight SoryOS catalog to GitHub Pages.
# Pages role (per PLAN-INDEX-PAGES-RELEASES-SIGNE.md):
#   - signed index.json + signature + public keys
#   - APT metadata (dists/) without pool/*.deb
# Binary .deb files stay on GitHub Releases only.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${1:-$ROOT_DIR/pages-out}"
PAGES_DIR="${PAGES_DIR:-$ROOT_DIR/pages-publish}"
REPO="${SORYOS_APT_REPO:-sory-os-org/sory-os-apt}"
TAG="${SORYOS_RELEASE_TAG:-}"

if [[ ! -d "$SOURCE_DIR" ]]; then
  printf 'missing catalog source directory: %s\n' "$SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$PAGES_DIR"
rsync -a --delete \
  --exclude='*.deb' \
  --exclude='pool/' \
  "$SOURCE_DIR"/ "$PAGES_DIR"/

if [[ -n "$TAG" ]]; then
  cat > "$PAGES_DIR/release-tag.json" <<EOF
{
  "schema": 1,
  "repository": "${REPO}",
  "tag": "${TAG}",
  "index_url": "https://${REPO%%/*}.github.io/${REPO#*/}/index.json",
  "pages_base_url": "https://${REPO%%/*}.github.io/${REPO#*/}"
}
EOF
fi

printf 'pages catalog ready under %s\n' "$PAGES_DIR"
find "$PAGES_DIR" -type f | sort
