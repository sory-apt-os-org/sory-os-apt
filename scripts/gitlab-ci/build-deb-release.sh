#!/usr/bin/env bash
# GitLab CI — mirror of .github/workflows/build-deb-release.yml
set -euo pipefail

APT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../soryos-urls.sh
source "$APT_ROOT/scripts/soryos-urls.sh"
# shellcheck source=common.sh
source "$APT_ROOT/scripts/gitlab-ci/common.sh"

SORYOS_COMPONENTS="${SORYOS_COMPONENTS:-all}"
SORYOS_FORCE_REBUILD="${SORYOS_FORCE_REBUILD:-false}"
SORYOS_RELEASE_TAG="${SORYOS_RELEASE_TAG:-soryos-deb-test-2026.08.13}"
SORYOS_RELEASE_BINARY="${SORYOS_RELEASE_BINARY:-1}"
SORYOS_BASE_RELEASE_TAG="${SORYOS_BASE_RELEASE_TAG:-soryos-deb-test-2026.08.13}"

soryos_setup_git_auth
soryos_ci_install_build_deps
cd "$APT_ROOT"

mkdir -p release-out/pool/stable
"$APT_ROOT/scripts/prepare-cosmic-sources.sh" "$SORYOS_COSMIC_WORK"

mapfile -t CHANGED < <(
  python3 - "$APT_ROOT/cosmic-apps/manifest.json" <<PY
import json, os, re, urllib.request

manifest = json.load(open("$APT_ROOT/cosmic-apps/manifest.json"))
all_components = sorted({c["name"] for c in manifest["components"] if c.get("has_debian")} | {"cosmic-sound-theme"})
requested = os.environ.get("SORYOS_COMPONENTS", "all").strip()
selected = all_components if requested == "all" else requested.split()
unknown = sorted(set(selected) - set(all_components))
if unknown:
    raise SystemExit(f"Unknown component(s): {', '.join(unknown)}")

base_tag = os.environ.get("SORYOS_BASE_RELEASE_TAG", "soryos-deb-test-2026.08.13")
index_url = """$(soryos_release_index_url "${SORYOS_BASE_RELEASE_TAG}")"""
release_index = {}
try:
    with urllib.request.urlopen(index_url, timeout=60) as resp:
        release_index = json.load(resp)
except Exception:
    pass

work = os.environ["SORYOS_COSMIC_WORK"] + "/cosmic-epoch"

def pool_version(component):
    control = f"{work}/{component}/debian/control"
    cargo = f"{work}/{component}/Cargo.toml"
    if os.path.isfile(cargo):
        for line in open(cargo, encoding="utf-8"):
            if line.startswith("version"):
                return line.split("=", 1)[1].strip().strip('"')
    source = component
    if os.path.isfile(control):
        for line in open(control, encoding="utf-8"):
            if line.startswith("Source:"):
                source = line.split(":", 1)[1].strip()
    for asset in release_index.get("assets", []):
        m = re.match(rf"^{re.escape(source)}_(.+)_(?:amd64|all)\\.deb$", asset.get("name", ""))
        if m:
            return m.group(1)
    return "none"

changed = []
for component in selected:
    if os.environ.get("SORYOS_FORCE_REBUILD", "false") == "true":
        changed.append(component); continue
    if os.environ.get("SORYOS_RELEASE_BINARY", "1") != "1":
        changed.append(component); continue
    control = f"{work}/{component}/debian/control"
    pkg = component
    if os.path.isfile(control):
        for line in open(control, encoding="utf-8"):
            if line.startswith("Source:"):
                pkg = line.split(":", 1)[1].strip(); break
    indexed = release_index.get("packages", {}).get(pkg, {}).get("deb")
    if not indexed:
        changed.append(component); continue
    src_ver = pool_version(component)
    indexed_ver = re.sub(rf"^{re.escape(pkg)}_(.+)_(?:amd64|all)\\.deb$", r"\\1", indexed["name"])
    if src_ver == "none" or src_ver != indexed_ver:
        changed.append(component)

for c in changed:
    print(c)
PY
)

if ((${#CHANGED[@]} == 0)); then
  printf 'No components to rebuild.\n'
  exit 0
fi

printf 'Building: %s\n' "${CHANGED[*]}"

export SORYOS_COSMIC_EPOCH_DIR="$SORYOS_COSMIC_WORK/cosmic-epoch"
./scripts/build-packages.sh
cp pool/stable/*.deb release-out/pool/stable/ 2>/dev/null || true

failed=()
for component in "${CHANGED[@]}"; do
  printf '\n=== %s ===\n' "$component"
  if [[ "$component" == "cosmic-sound-theme" ]]; then
    cd "$SORYOS_COSMIC_WORK/cosmic-epoch/cosmic-sound-theme"
    VERSION=$(grep "version:" meson.build | head -1 | sed "s/.*version: '*//;s/'*,//;s/[' ]//g")
    PKGDIR="/tmp/pkg/cosmic-sound-theme"
    rm -rf "$PKGDIR"
    mkdir -p "$PKGDIR/DEBIAN"
    printf '%s\n' "Package: cosmic-sound-theme" "Version: ${VERSION}" \
      'Section: sound' 'Priority: optional' 'Architecture: all' \
      'Maintainer: SoryOS Maintainers <maintainers@soryos.local>' \
      'Description: COSMIC Sound Theme' > "$PKGDIR/DEBIAN/control"
    meson setup build --prefix=/usr
    DESTDIR="$PKGDIR" meson install -C build
    dpkg-deb --build "$PKGDIR" "$APT_ROOT/release-out/pool/stable/cosmic-sound-theme_${VERSION}_all.deb"
    continue
  fi
  comp_dir="$SORYOS_COSMIC_WORK/cosmic-epoch/$component"
  if [[ ! -f "$comp_dir/debian/control" ]]; then
    printf 'skip (no debian/): %s\n' "$component"
    continue
  fi
  cd "$comp_dir"
  "$APT_ROOT/scripts/ensure-cargo-lock.sh" "$PWD"
  if ! dpkg-buildpackage -us -uc -b -d; then
    failed+=("$component")
    continue
  fi
  cp ../*.deb "$APT_ROOT/release-out/pool/stable/" 2>/dev/null || true
done

if [[ "$SORYOS_RELEASE_BINARY" == "1" ]]; then
  INDEX_URL="$(soryos_release_index_url "$SORYOS_BASE_RELEASE_TAG")"
  curl -fsSL "$INDEX_URL" -o /tmp/base-index.json || true
  python3 - /tmp/base-index.json "$APT_ROOT/release-out/pool/stable" "${CHANGED[*]}" <<'PY'
import json, pathlib, subprocess, sys
index = json.load(open(sys.argv[1]))
out = pathlib.Path(sys.argv[2])
changed = set(sys.argv[3].split())
for package, files in index.get("packages", {}).items():
    deb = files.get("deb")
    if not deb or package in changed:
        continue
    dest = out / deb["name"]
    if dest.exists():
        continue
    print("copy unchanged", deb["name"])
    subprocess.check_call(["curl", "-fsSL", deb["url"], "-o", str(dest)])
PY
fi

if ((${#failed[@]} > 0)); then
  printf 'Build failed: %s\n' "${failed[*]}" >&2
  exit 1
fi

RELEASE_OUT="$APT_ROOT/release-out"
mkdir -p "$RELEASE_OUT/pool/stable"
soryos_ci_install_publish_deps
soryos_ci_sign_release_out "$SORYOS_RELEASE_TAG" "$RELEASE_OUT"
soryos_ci_publish_release "$SORYOS_RELEASE_TAG" "$RELEASE_OUT" \
  "SoryOS Debian packages ($SORYOS_RELEASE_TAG)" \
  "Desktop cosmic-epoch stack built on GitLab CI."
