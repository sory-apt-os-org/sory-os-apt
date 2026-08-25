#!/usr/bin/env bash
# Clone libcosmic + cosmic-utils community apps from sory-os-org for CI builds.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  printf 'usage: %s <work-dir> [component ...]\n' "$0" >&2
  exit 2
fi

mkdir -p "$1"
WORK_DIR="$(cd "$1" && pwd)"
shift || true
REQUESTED=("$@")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=soryos-urls.sh
source "$SCRIPT_DIR/soryos-urls.sh"

MANIFEST="$APT_ROOT/cosmic-apps/cosmic-utils-manifest.json"

LIBCOSMIC_REPO="${SORYOS_LIBCOSMIC_REPO}"
LIBCOSMIC_REF="${SORYOS_LIBCOSMIC_REF}"
UTILS_GIT_BASE="${SORYOS_COSMIC_UTILS_GIT_BASE}"
UTILS_REF="${SORYOS_COSMIC_UTILS_REF}"

require_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing required tool: %s\n' "$1" >&2
    exit 1
  }
}

require_tool git
require_tool python3

soryos_setup_git_auth
if [[ "$SORYOS_PLATFORM" != "gitlab" && -n "${SORYOS_GITHUB_PAT:-${GITHUB_TOKEN:-}}" ]]; then
  GIT_AUTH_TOKEN="${SORYOS_GITHUB_PAT:-${GITHUB_TOKEN}}"
  git config --global url."https://x-access-token:${GIT_AUTH_TOKEN}@github.com/".insteadOf "https://github.com/"
fi

sync_repo() {
  local url="$1"
  local ref="$2"
  local dest="$3"
  mkdir -p "$(dirname "$dest")"
  if [[ -d "$dest/.git" ]]; then
    git -C "$dest" fetch --depth 1 origin "$ref"
    git -C "$dest" checkout -f "$ref"
    git -C "$dest" reset --hard "origin/$ref" 2>/dev/null || git -C "$dest" reset --hard "$ref"
  else
    git clone --depth 1 --branch "$ref" "$url" "$dest"
  fi
}

COMPONENTS_JSON="$(
  python3 - "$MANIFEST" "${REQUESTED[@]}" <<'PY'
import json
import sys

manifest = json.load(open(sys.argv[1]))
all_names = [c["name"] for c in manifest["components"]]
requested = sys.argv[2:]
if not requested or requested == ["all"]:
    selected = all_names
else:
    selected = requested
    unknown = sorted(set(selected) - set(all_names))
    if unknown:
        raise SystemExit(f"unknown cosmic-utils component(s): {', '.join(unknown)}")
print(json.dumps(selected))
PY
)"

VENDOR_JSON="$(
  python3 - "$MANIFEST" "$COMPONENTS_JSON" <<'PY'
import json
import sys

manifest = json.load(open(sys.argv[1]))
selected = set(json.loads(sys.argv[2]))
by_name = {c["name"]: c for c in manifest["components"]}
vendor = manifest.get("vendor_repos", {})
needed = set()
for name in selected:
    for dep in by_name[name].get("vendor", []):
        needed.add(dep)
out = []
for dep in sorted(needed):
    spec = vendor[dep]
    out.append({"name": dep, "git": spec["git"], "ref": spec.get("branch", "main")})
print(json.dumps(out))
PY
)"

UTILS_DIR="$WORK_DIR/cosmic-utils"
mkdir -p "$UTILS_DIR"

sync_repo "$LIBCOSMIC_REPO" "$LIBCOSMIC_REF" "$WORK_DIR/libcosmic"

while IFS= read -r name; do
  sync_repo "${UTILS_GIT_BASE}/${name}.git" "$UTILS_REF" "$UTILS_DIR/$name"
done < <(python3 -c 'import json,sys; print("\n".join(json.loads(sys.argv[1])))' "$COMPONENTS_JSON")

while IFS= read -r line; do
  name="$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(d["name"])' "$line")"
  url="$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(d["git"])' "$line")"
  ref="$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(d["ref"])' "$line")"
  sync_repo "$url" "$ref" "$UTILS_DIR/$name"
done < <(python3 -c 'import json,sys; [print(json.dumps(x)) for x in json.loads(sys.argv[1])]' "$VENDOR_JSON")

"$SCRIPT_DIR/rewrite-cosmic-utils-deps.sh" "$UTILS_DIR" "$WORK_DIR/libcosmic"

printf 'cosmic-utils sources ready:\n'
printf '  libcosmic: %s @ %s\n' "$LIBCOSMIC_REPO" "$LIBCOSMIC_REF"
printf '  apps dir:  %s\n' "$UTILS_DIR"
printf '  selected:  %s\n' "$COMPONENTS_JSON"
