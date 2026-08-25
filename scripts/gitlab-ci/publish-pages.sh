#!/usr/bin/env bash
# GitLab CI — mirror of .github/workflows/publish-pages.yml (GitLab Pages)
set -euo pipefail

APT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../soryos-urls.sh
source "$APT_ROOT/scripts/soryos-urls.sh"
# shellcheck source=common.sh
source "$APT_ROOT/scripts/gitlab-ci/common.sh"

SORYOS_RELEASE_TAG="${SORYOS_RELEASE_TAG:?set SORYOS_RELEASE_TAG to the Release tag to publish}"

soryos_ci_install_publish_deps
cd "$APT_ROOT"

BASE="$(soryos_release_asset_base_url "$SORYOS_RELEASE_TAG")"
mkdir -p pages-out/dists/stable/main/binary-amd64 pages-out/keyrings public

for file in \
  index.json index.json.sig \
  index-signing-key.pub.pem index-signing-key.pub.hex \
  soryos-archive-keyring.gpg \
  Release Release.gpg InRelease \
  Packages Packages.gz
do
  curl -fsSL "${BASE}/${file}" -o "pages-out/${file}" 2>/dev/null || true
done

mv pages-out/Release pages-out/dists/stable/Release 2>/dev/null || true
mv pages-out/Release.gpg pages-out/dists/stable/Release.gpg 2>/dev/null || true
mv pages-out/InRelease pages-out/dists/stable/InRelease 2>/dev/null || true
mv pages-out/Packages pages-out/dists/stable/main/binary-amd64/Packages 2>/dev/null || true
mv pages-out/Packages.gz pages-out/dists/stable/main/binary-amd64/Packages.gz 2>/dev/null || true
mv pages-out/soryos-archive-keyring.gpg pages-out/keyrings/ 2>/dev/null || true

SORYOS_RELEASE_TAG="$SORYOS_RELEASE_TAG" SORYOS_APT_REPO="$SORYOS_APT_REPO" \
  ./scripts/publish-pages-catalog.sh pages-out

rsync -a --delete pages-publish/ public/
printf 'GitLab Pages artifact ready in public/ — URL: %s\n' "$SORYOS_PAGES_BASE_URL"
