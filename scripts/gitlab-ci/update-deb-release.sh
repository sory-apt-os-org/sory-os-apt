#!/usr/bin/env bash
# GitLab CI — mirror of .github/workflows/update-deb-release.yml
set -euo pipefail

APT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../soryos-urls.sh
source "$APT_ROOT/scripts/soryos-urls.sh"
# shellcheck source=common.sh
source "$APT_ROOT/scripts/gitlab-ci/common.sh"

SORYOS_COMPONENTS="${SORYOS_COMPONENTS:?space-separated components or all}"
SORYOS_RELEASE_TAG="${SORYOS_RELEASE_TAG:?existing release tag to update in place}"

soryos_setup_git_auth
soryos_ci_install_build_deps
cd "$APT_ROOT"

mapfile -t SELECTED < <(
  python3 - "$APT_ROOT/cosmic-apps/manifest.json" "$SORYOS_COMPONENTS" <<'PY'
import json, sys
manifest = json.load(open(sys.argv[1]))
all_components = sorted({c["name"] for c in manifest["components"] if c.get("has_debian")} | {"cosmic-sound-theme"})
requested = sys.argv[2].strip()
selected = all_components if requested == "all" else requested.split()
unknown = sorted(set(selected) - set(all_components))
if unknown:
    raise SystemExit(f"Unknown component(s): {', '.join(unknown)}")
for c in selected:
    print(c)
PY
)

mkdir -p new-packages
for component in "${SELECTED[@]}"; do
  "$APT_ROOT/scripts/prepare-component-source.sh" "$SORYOS_COSMIC_WORK" "$component"
  comp_dir="$SORYOS_COSMIC_WORK/cosmic-epoch/$component"
  if [[ "$component" == "cosmic-sound-theme" ]]; then
    cd "$comp_dir"
    VERSION=$(grep "version:" meson.build | head -1 | sed "s/.*version: '*//;s/'*,//;s/[' ]//g")
    PKGDIR="/tmp/pkg/cosmic-sound-theme"
    rm -rf "$PKGDIR"
    mkdir -p "$PKGDIR/DEBIAN"
    printf '%s\n' "Package: cosmic-sound-theme" "Version: ${VERSION}" \
      'Architecture: all' 'Maintainer: SoryOS Maintainers <maintainers@soryos.local>' \
      'Description: COSMIC Sound Theme' > "$PKGDIR/DEBIAN/control"
    meson setup build --prefix=/usr
    DESTDIR="$PKGDIR" meson install -C build
    dpkg-deb --build "$PKGDIR" "$APT_ROOT/new-packages/cosmic-sound-theme_${VERSION}_all.deb"
    continue
  fi
  [[ -f "$comp_dir/debian/control" ]] || continue
  cd "$comp_dir"
  [[ "$component" == "distinst" ]] && "$APT_ROOT/scripts/patch-distinst-noble.sh" "$PWD"
  "$APT_ROOT/scripts/ensure-cargo-lock.sh" "$PWD"
  dpkg-buildpackage -us -uc -b -d
  cp ../*.deb "$APT_ROOT/new-packages/" 2>/dev/null || true
done

shopt -s nullglob
debs=(new-packages/*.deb)
if ((${#debs[@]} == 0)); then
  printf 'No packages rebuilt — nothing to publish.\n'
  exit 0
fi

soryos_ci_install_publish_deps
INDEX_URL="$(soryos_release_index_url "$SORYOS_RELEASE_TAG")"
curl -fsSL "$INDEX_URL" -o /tmp/current-index.json
curl -fsSL "${INDEX_URL%.json}.json.sig" -o /tmp/current-index.json.sig
curl -fsSL "${INDEX_URL%/index.json}/index-signing-key.pub.pem" -o /tmp/index-signing-key.pub.pem
./scripts/verify-release-index.sh \
  /tmp/current-index.json /tmp/current-index.json.sig /tmp/index-signing-key.pub.pem

python3 scripts/update-release-index.py \
  /tmp/current-index.json new-packages release-out/index.json "$SORYOS_RELEASE_TAG"

umask 077
printf '%s\n' "$SORYOS_INDEX_PRIVATE_KEY_PEM" > index-signing-key.pem
./scripts/sign-release-index.sh release-out/index.json index-signing-key.pem
openssl pkey -in index-signing-key.pem -pubout -out release-out/index-signing-key.pub.pem
openssl pkey -pubin -in release-out/index-signing-key.pub.pem \
  -outform DER | tail -c 32 | od -An -tx1 -v | tr -d ' \n' \
  > release-out/index-signing-key.pub.hex
rm -f index-signing-key.pem

soryos_ci_publish_release "$SORYOS_RELEASE_TAG" release-out \
  "SoryOS Debian update ($SORYOS_RELEASE_TAG)" \
  "Incremental update: ${SELECTED[*]}"

for deb in new-packages/*.deb; do
  soryos_ci_require_glab
  glab release upload "$SORYOS_RELEASE_TAG" "$deb" --repo "$SORYOS_APT_PROJECT_PATH" --clobber
done
