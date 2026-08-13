#!/usr/bin/env bash
# Consume the SoryOS split catalog model:
#   GitHub Pages  -> index.json (signed) + APT dists/ + keyrings (no .deb)
#   GitHub Release -> .deb binaries referenced by the index
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-${SORYOS_APT_ROOT:-$ROOT_DIR/release-pool}}"
PAGES_BASE="${SORYOS_PAGES_BASE_URL:-}"
INDEX_URL="${SORYOS_RELEASE_INDEX_URL:-}"
SUITE="${SORYOS_SUITE:-stable}"
PACKAGE_FILTER="${SORYOS_RELEASE_PACKAGES:-}"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

require_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing required tool: %s\n' "$1" >&2
    exit 1
  }
}

download() {
  local url="$1"
  local dest="$2"
  curl -fsSL --retry 5 --retry-delay 5 "$url" -o "$dest"
}

verify_blake3() {
  local file="$1"
  local expected="$2"
  local actual
  actual="$(b3sum --no-names "$file")"
  [[ "$actual" == "$expected" ]] || {
    printf 'BLAKE3 mismatch for %s\n' "$file" >&2
    exit 1
  }
}

if [[ -z "$INDEX_URL" && -z "$PAGES_BASE" ]]; then
  printf 'set SORYOS_PAGES_BASE_URL or SORYOS_RELEASE_INDEX_URL\n' >&2
  exit 2
fi

if [[ -z "$INDEX_URL" ]]; then
  PAGES_BASE="${PAGES_BASE%/}"
  INDEX_URL="${PAGES_BASE}/index.json"
fi

require_tool curl
require_tool jq
require_tool b3sum
require_tool openssl
require_tool dpkg-scanpackages
require_tool gzip

mkdir -p "$OUTPUT_DIR/pool/$SUITE" "$OUTPUT_DIR/dists/$SUITE/main/binary-amd64" "$OUTPUT_DIR/keyrings"

INDEX_JSON="$WORK_DIR/index.json"
SIG_URL="${INDEX_URL%.json}.json.sig"
PUB_PEM_URL="${INDEX_URL%/index.json}/index-signing-key.pub.pem"

printf 'catalog (Pages): %s\n' "$INDEX_URL"
download "$INDEX_URL" "$INDEX_JSON"
download "$SIG_URL" "$WORK_DIR/index.json.sig"
download "$PUB_PEM_URL" "$WORK_DIR/index-signing-key.pub.pem"

"$ROOT_DIR/scripts/verify-release-index.sh" \
  "$INDEX_JSON" \
  "$WORK_DIR/index.json.sig" \
  "$WORK_DIR/index-signing-key.pub.pem"

# APT metadata from Pages (no binaries on Pages)
if [[ -n "$PAGES_BASE" ]]; then
  PAGES_BASE="${PAGES_BASE%/}"
  for rel in \
    "dists/$SUITE/Release" \
    "dists/$SUITE/Release.gpg" \
    "dists/$SUITE/InRelease" \
    "dists/$SUITE/main/binary-amd64/Packages" \
    "dists/$SUITE/main/binary-amd64/Packages.gz" \
    "keyrings/soryos-archive-keyring.gpg"
  do
    dest="$OUTPUT_DIR/$rel"
    mkdir -p "$(dirname "$dest")"
    if curl -fsSL "${PAGES_BASE}/${rel}" -o "$dest"; then
      printf 'fetched Pages metadata: %s\n' "$rel"
    fi
  done
fi

if [[ -n "$PACKAGE_FILTER" ]]; then
  mapfile -t WANTED < <(printf '%s\n' $PACKAGE_FILTER)
else
  mapfile -t WANTED < <(jq -r '.packages | keys[]' "$INDEX_JSON" | sort)
fi

printf 'binaries (Release): downloading %d package(s)\n' "${#WANTED[@]}"
for package in "${WANTED[@]}"; do
  asset="$(jq -r --arg pkg "$package" '.packages[$pkg].deb // empty' "$INDEX_JSON")"
  if [[ -z "$asset" || "$asset" == "null" ]]; then
    printf 'package missing from index: %s\n' "$package" >&2
    exit 1
  fi
  name="$(jq -r '.name' <<<"$asset")"
  url="$(jq -r '.url' <<<"$asset")"
  size="$(jq -r '.size' <<<"$asset")"
  blake3="$(jq -r '.blake3' <<<"$asset")"
  case "$url" in
    https://github.com/*/releases/download/*) ;;
    *)
      printf 'refusing non-Release URL for %s: %s\n' "$name" "$url" >&2
      exit 1
      ;;
  esac
  dest="$OUTPUT_DIR/pool/$SUITE/$name"
  if [[ -f "$dest" ]]; then
    verify_blake3 "$dest" "$blake3"
    printf 'reuse %s\n' "$name"
    continue
  fi
  download "$url" "$WORK_DIR/$name"
  [[ "$(stat -c %s "$WORK_DIR/$name")" -eq "$size" ]] || {
    printf 'size mismatch for %s\n' "$name" >&2
    exit 1
  }
  verify_blake3 "$WORK_DIR/$name" "$blake3"
  mv "$WORK_DIR/$name" "$dest"
  printf 'downloaded %s\n' "$name"
done

apt_key_asset="$(jq -r '.apt_public_key // empty' "$INDEX_JSON")"
if [[ ! -f "$OUTPUT_DIR/keyrings/soryos-archive-keyring.gpg" ]] \
  && [[ -n "$apt_key_asset" && "$apt_key_asset" != "null" ]]; then
  key_name="$(jq -r '.name' <<<"$apt_key_asset")"
  key_url="$(jq -r '.url' <<<"$apt_key_asset")"
  key_blake3="$(jq -r '.blake3' <<<"$apt_key_asset")"
  download "$key_url" "$OUTPUT_DIR/keyrings/$key_name"
  verify_blake3 "$OUTPUT_DIR/keyrings/$key_name" "$key_blake3"
fi

if [[ ! -f "$OUTPUT_DIR/dists/$SUITE/main/binary-amd64/Packages.gz" ]]; then
  (
    cd "$OUTPUT_DIR"
    dpkg-scanpackages -a amd64 "pool/$SUITE" /dev/null \
      > "dists/$SUITE/main/binary-amd64/Packages"
    gzip -9cn "dists/$SUITE/main/binary-amd64/Packages" \
      > "dists/$SUITE/main/binary-amd64/Packages.gz"
  )
fi

printf 'local APT mirror ready at %s (Pages catalog + Release binaries)\n' "$OUTPUT_DIR"
