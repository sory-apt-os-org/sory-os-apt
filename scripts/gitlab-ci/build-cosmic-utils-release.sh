#!/usr/bin/env bash
# GitLab CI — mirror of .github/workflows/build-cosmic-utils-release.yml
set -euo pipefail

APT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../soryos-urls.sh
source "$APT_ROOT/scripts/soryos-urls.sh"
# shellcheck source=common.sh
source "$APT_ROOT/scripts/gitlab-ci/common.sh"

SORYOS_CU_COMPONENTS="${SORYOS_CU_COMPONENTS:-phase1}"
SORYOS_CU_FORCE_REBUILD="${SORYOS_CU_FORCE_REBUILD:-false}"
SORYOS_CU_TAG="${SORYOS_CU_TAG:-soryos-cosmic-utils-2026.08.22}"
SORYOS_CU_RELEASE_BINARY="${SORYOS_CU_RELEASE_BINARY:-1}"
SORYOS_CU_BASE_TAG="${SORYOS_CU_BASE_TAG:-soryos-deb-test-2026.08.13}"
SORYOS_CU_MERGE_DESKTOP="${SORYOS_CU_MERGE_DESKTOP:-true}"

soryos_setup_git_auth
soryos_ci_install_build_deps
cd "$APT_ROOT"

mapfile -t CHANGED < <(
  SORYOS_CU_COMPONENTS="$SORYOS_CU_COMPONENTS" \
  SORYOS_CU_FORCE_REBUILD="$SORYOS_CU_FORCE_REBUILD" \
  SORYOS_CU_RELEASE_BINARY="$SORYOS_CU_RELEASE_BINARY" \
  SORYOS_CU_BASE_TAG="$SORYOS_CU_BASE_TAG" \
  python3 - "$APT_ROOT/cosmic-apps/cosmic-utils-manifest.json" <<PY
import json, os, re, urllib.request

manifest = json.load(open("$APT_ROOT/cosmic-apps/cosmic-utils-manifest.json"))
all_components = [c["name"] for c in manifest["components"]]
phase1 = [c["name"] for c in manifest["components"] if c.get("phase") == 1]
requested = os.environ.get("SORYOS_CU_COMPONENTS", "phase1").strip()
if requested in ("", "all"):
    selected = all_components
elif requested == "phase1":
    selected = phase1
else:
    selected = requested.split()

base_tag = os.environ.get("SORYOS_CU_BASE_TAG", "soryos-deb-test-2026.08.13")
index_url = """$(soryos_release_index_url "${SORYOS_CU_BASE_TAG}")"""
release_index = {}
try:
    with urllib.request.urlopen(index_url, timeout=60) as resp:
        release_index = json.load(resp)
except Exception:
    pass

def package_name(entry):
    return entry.get("package", entry["name"])

def indexed_version(pkg):
    indexed = release_index.get("packages", {}).get(pkg, {}).get("deb")
    if not indexed:
        return None
    m = re.match(rf"^{re.escape(pkg)}_(.+)_(?:amd64|all)\\.deb$", indexed["name"])
    return m.group(1) if m else None

changed = []
for entry in manifest["components"]:
    name = entry["name"]
    if name not in selected:
        continue
    pkg = package_name(entry)
    if os.environ.get("SORYOS_CU_FORCE_REBUILD", "false") == "true":
        changed.append(name); continue
    if os.environ.get("SORYOS_CU_RELEASE_BINARY", "1") != "1":
        changed.append(name); continue
    if indexed_version(pkg) is None:
        changed.append(name)

for c in changed:
    print(c)
PY
)

if ((${#CHANGED[@]} == 0)); then
  printf 'No cosmic-utils components to rebuild.\n'
  exit 0
fi

printf 'Building cosmic-utils: %s\n' "${CHANGED[*]}"
mkdir -p release-out/pool/stable
"$APT_ROOT/scripts/prepare-cosmic-utils-sources.sh" "$SORYOS_COSMIC_UTILS_WORK" all

failed=()
for name in "${CHANGED[@]}"; do
  printf '\n=== %s ===\n' "$name"
  if ! "$APT_ROOT/scripts/build-cosmic-utils-deb.sh" \
      "$SORYOS_COSMIC_UTILS_WORK" "$name" "$APT_ROOT/release-out/pool/stable"; then
    failed+=("$name")
  fi
done

if [[ "$SORYOS_CU_RELEASE_BINARY" == "1" ]]; then
  INDEX_URL="$(soryos_release_index_url "$SORYOS_CU_BASE_TAG")"
  curl -fsSL "$INDEX_URL" -o /tmp/cu-base-index.json || true
  python3 - /tmp/cu-base-index.json "$APT_ROOT/release-out/pool/stable" "${CHANGED[*]}" "$SORYOS_CU_MERGE_DESKTOP" "$APT_ROOT/cosmic-apps/cosmic-utils-manifest.json" <<'PY'
import json, pathlib, subprocess, sys
manifest = json.load(open(sys.argv[5]))
index = json.load(open(sys.argv[1]))
out = pathlib.Path(sys.argv[2])
changed = set(sys.argv[3].split())
merge_desktop = sys.argv[4] == "true"
pkg_by_component = {c["name"]: c.get("package", c["name"]) for c in manifest["components"]}
changed_pkgs = {pkg_by_component.get(n, n) for n in changed}
for package, files in index.get("packages", {}).items():
    deb = files.get("deb")
    if not deb or package in changed_pkgs:
        continue
    if not merge_desktop and package not in pkg_by_component.values():
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
soryos_ci_install_publish_deps
soryos_ci_sign_release_out "$SORYOS_CU_TAG" "$RELEASE_OUT"
soryos_ci_publish_release "$SORYOS_CU_TAG" "$RELEASE_OUT" \
  "SoryOS cosmic-utils ($SORYOS_CU_TAG)" \
  "Community cosmic-utils phase 1. Built: ${CHANGED[*]}"
