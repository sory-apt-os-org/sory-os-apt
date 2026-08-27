#!/usr/bin/env bash
# Sign and publish cosmic-utils .deb to GitHub Release (no Actions workflow_dispatch).
set -euo pipefail

if [[ $# -lt 2 ]]; then
  printf 'usage: %s <deb-dir> <release-tag>\n' "$0" >&2
  printf 'example: %s pool/stable/cosmic-utils soryos-cosmic-utils-2026.08.22\n' "$0" >&2
  exit 2
fi

DEB_DIR="$(cd "$1" && pwd)"
TAG="$2"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="${SORYOS_APT_REPO:-sory-apt-os-org/sory-os-apt}"
BASE_TAG="${SORYOS_CU_BASE_TAG:-soryos-deb-test-2026.08.13}"
RELEASE_OUT="$ROOT/release-out-cosmic-utils"

[[ -n "$(ls -A "$DEB_DIR"/*.deb 2>/dev/null)" ]] || {
  printf 'no .deb files in %s\n' "$DEB_DIR" >&2
  exit 1
}

command -v gh >/dev/null 2>&1 || { printf 'gh CLI required\n' >&2; exit 1; }

mkdir -p "$RELEASE_OUT/pool/stable" "$ROOT/pool/stable" "$ROOT/dists/stable/main/binary-amd64" "$ROOT/keyrings"
cp "$DEB_DIR"/*.deb "$ROOT/pool/stable/"

# Merge unchanged desktop packages from base release when index exists.
INDEX_URL="https://github.com/${REPO}/releases/download/${BASE_TAG}/index.json"
if curl -fsSL "$INDEX_URL" -o /tmp/soryos-base-index.json 2>/dev/null; then
  python3 - /tmp/soryos-base-index.json "$ROOT/pool/stable" <<'PY'
import json, pathlib, subprocess, sys
index = json.load(open(sys.argv[1]))
out = pathlib.Path(sys.argv[2])
for package, files in index.get("packages", {}).items():
    deb = files.get("deb")
    if not deb:
        continue
    dest = out / deb["name"]
    if dest.exists():
        continue
    print(f"copy base {deb['name']}")
    subprocess.check_call(["curl", "-fsSL", deb["url"], "-o", str(dest)])
PY
fi

export SORYOS_SUITES=stable
cd "$ROOT"
./scripts/ci-import-signing-key.sh
./scripts/generate-index.sh
./scripts/sign-repository.sh

mkdir -p "$RELEASE_OUT"
cp keyrings/soryos-archive-keyring.gpg "$RELEASE_OUT/"
cp dists/stable/Release "$RELEASE_OUT/"
cp dists/stable/Release.gpg "$RELEASE_OUT/"
cp dists/stable/InRelease "$RELEASE_OUT/"
cp dists/stable/main/binary-amd64/Packages "$RELEASE_OUT/"
cp dists/stable/main/binary-amd64/Packages.gz "$RELEASE_OUT/"
cp pool/stable/*.deb "$RELEASE_OUT/"

python3 scripts/generate-release-index.py \
  "$RELEASE_OUT" \
  "$TAG" \
  "$REPO" \
  "$RELEASE_OUT/index.json" \
  "https://github.com/${REPO}/releases/download/${TAG}" \
  "$RELEASE_OUT/soryos-archive-keyring.gpg"

if [[ -z "${SORYOS_INDEX_PRIVATE_KEY_PEM:-}" && -f .private/keys/index-signing-key.pem ]]; then
  export SORYOS_INDEX_PRIVATE_KEY_PEM="$(cat .private/keys/index-signing-key.pem)"
fi
if [[ -n "${SORYOS_INDEX_PRIVATE_KEY_PEM:-}" ]]; then
  umask 077
  printf '%s\n' "$SORYOS_INDEX_PRIVATE_KEY_PEM" > /tmp/soryos-index-sign.pem
  ./scripts/sign-release-index.sh "$RELEASE_OUT/index.json" /tmp/soryos-index-sign.pem
  openssl pkey -in /tmp/soryos-index-sign.pem -pubout -out "$RELEASE_OUT/index-signing-key.pub.pem"
  openssl pkey -pubin -in "$RELEASE_OUT/index-signing-key.pub.pem" \
    -outform DER | tail -c 32 | od -An -tx1 -v | tr -d ' \n' \
    > "$RELEASE_OUT/index-signing-key.pub.hex"
  rm -f /tmp/soryos-index-sign.pem
else
  printf 'warning: SORYOS_INDEX_PRIVATE_KEY_PEM not set — index.json not signed\n' >&2
fi

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  printf 'release %s already exists — uploading assets only\n' "$TAG"
else
  gh release create "$TAG" \
    --repo "$REPO" \
    --title "SoryOS cosmic-utils packages ($TAG)" \
    --notes "Published locally (GitHub Actions blocked on account). See scripts/publish-cosmic-utils-release-local.sh"
fi

while IFS= read -r -d '' asset; do
  gh release upload "$TAG" "$asset" --repo "$REPO" --clobber
done < <(find "$RELEASE_OUT" -maxdepth 1 -type f -print0 | sort -z)

printf 'published: https://github.com/%s/releases/tag/%s\n' "$REPO" "$TAG"
