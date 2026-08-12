#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/cache.sh"

SOURCES_YML="$ROOT_DIR/sources/sources.yml"
POOL_DIR="$ROOT_DIR/pool"
TMP_DIR="$ROOT_DIR/tmp/build-src-$(id -u)"
LOG_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOG_DIR/build-from-source.log"

CACHE_DIR="$ROOT_DIR/_build/ci"

mkdir -p "$POOL_DIR" "$TMP_DIR" "$LOG_DIR" "$CACHE_DIR"
: > "$LOG_FILE"

cache_init "$CACHE_DIR"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing required tool: %s\n' "$1" | tee -a "$LOG_FILE" >&2
    exit 1
  fi
}

require_tool git
require_tool cargo
require_tool dpkg-deb
require_tool dpkg-scanpackages
require_tool gzip

build_rust_component() {
  local repo_url="$1"
  local repo_name="$2"
  local component="$3"
  local work_dir="$TMP_DIR/$repo_name"
  local version arch deb

  cache_clean_stale "$repo_name"

  local cache_key="$repo_name/$component"
  if cache_exists "$cache_key" && [[ -z "${FORCE_REBUILD:-}" ]]; then
    printf 'cache hit: %s\n' "$cache_key" | tee -a "$LOG_FILE"
    local deb_path
    deb_path=$(find "$POOL_DIR" -name "${component}_*.deb" 2>/dev/null | head -1)
    if [[ -n "$deb_path" ]]; then
      printf 'using cached %s\n' "$deb_path" | tee -a "$LOG_FILE"
      return 0
    fi
  fi

  local build_dir
  build_dir=$(cache_build "$cache_key" "${FORCE_REBUILD:-false}")

  if [[ ! -d "$work_dir" ]]; then
    printf 'cloning %s...\n' "$repo_url" | tee -a "$LOG_FILE"
    git clone --recursive "$repo_url" "$work_dir" >> "$LOG_FILE" 2>&1
  else
    printf 'updating %s...\n' "$repo_name" | tee -a "$LOG_FILE"
    git -C "$work_dir" pull >> "$LOG_FILE" 2>&1
  fi

  cd "$work_dir"

  if [[ -f "$component/Cargo.toml" ]]; then
    version=$(grep '^version' "$component/Cargo.toml" | head -1 | sed 's/version = "//;s/"//')
    arch="amd64"

    printf 'building %s v%s...\n' "$component" "$version" | tee -a "$LOG_FILE"
    cd "$component"
    cargo build --release >> "$LOG_FILE" 2>&1 || {
      printf 'FAIL: cargo build for %s\n' "$component" | tee -a "$LOG_FILE" >&2
      cache_finalize "$cache_key"
      return 1
    }
    cd "$work_dir"
  elif [[ -f "$component/debian/changelog" ]]; then
    version=$(head -1 "$component/debian/changelog" | sed 's/.*(\(.*\)).*/\1/')
    arch="amd64"
    printf 'building %s v%s (debian)...\n' "$component" "$version" | tee -a "$LOG_FILE"
    cd "$component"
    dpkg-buildpackage -b -uc -us >> "$LOG_FILE" 2>&1 || {
      printf 'FAIL: dpkg-buildpackage for %s\n' "$component" | tee -a "$LOG_FILE" >&2
      cd "$work_dir"
      cache_finalize "$cache_key"
      return 1
    }
    cd "$work_dir"
    cp "$work_dir/${component}_"*.deb "$POOL_DIR/" 2>/dev/null || true
    cache_finalize "$cache_key"
    return 0
  else
    version="1.0.0"
    arch="all"
  fi

  local pkg_dir="$TMP_DIR/pkg/$component"
  rm -rf "$pkg_dir"
  mkdir -p "$pkg_dir/DEBIAN" "$pkg_dir/usr/bin"

  cat > "$pkg_dir/DEBIAN/control" <<CTRL
Package: $component
Version: $version
Section: admin
Priority: optional
Architecture: $arch
Maintainer: SoryOS Maintainers <maintainers@soryos.local>
Description: SoryOS $component
 SoryOS $component for the COSMIC desktop environment.
CTRL

  for b in "$component/target/release/$component" \
           "$component/target/release/$component-applet" \
           "$component/build/$component"; do
    if [[ -f "$b" ]]; then
      install -Dm0755 "$b" "$pkg_dir/usr/bin/$(basename "$b")"
    fi
  done

  deb="$POOL_DIR/${component}_${version}_${arch}.deb"
  dpkg-deb --build "$pkg_dir" "$deb" >> "$LOG_FILE" 2>&1
  printf 'built %s\n' "$deb" | tee -a "$LOG_FILE"

  cache_finalize "$cache_key"
}

build_local_package() {
  local name="$1"
  local control_file="$ROOT_DIR/templates/$name/control"

  if [[ ! -f "$control_file" ]]; then
    printf 'missing control file: %s\n' "$control_file" | tee -a "$LOG_FILE" >&2
    return 1
  fi

  local cache_key="local/$name"
  if cache_exists "$cache_key" && [[ -z "${FORCE_REBUILD:-}" ]]; then
    if ls "$POOL_DIR/${name}_"*.deb >/dev/null 2>&1; then
      printf 'cache hit: %s\n' "$cache_key" | tee -a "$LOG_FILE"
      return 0
    fi
  fi

  local build_dir
  build_dir=$(cache_build "$cache_key" "${FORCE_REBUILD:-false}")

  local work_dir="$TMP_DIR/local/$name"
  local version arch deb

  version="$(awk '/^Version: / {print $2}' "$control_file")"
  arch="$(awk '/^Architecture: / {print $2}' "$control_file")"
  deb="$POOL_DIR/${name}_${version}_${arch}.deb"

  rm -rf "$work_dir"
  mkdir -p "$work_dir/DEBIAN" "$work_dir/usr/share/doc/$name" \
           "$work_dir/usr/share/soryos/modules"
  cp "$control_file" "$work_dir/DEBIAN/control"

  printf '%s\n' "$name" > "$work_dir/usr/share/soryos/modules/$name"
  cat > "$work_dir/usr/share/doc/$name/README" <<EOF
$name is a SoryOS integration package.
It is intentionally minimal and reversible.
EOF

  dpkg-deb --build "$work_dir" "$deb" >> "$LOG_FILE" 2>&1
  printf 'built %s\n' "$deb" | tee -a "$LOG_FILE"

  cache_finalize "$cache_key"
}

printf '=== SoryOS Build from Source ===\n' | tee -a "$LOG_FILE"
printf 'Pool: %s | Cache: %s\n' "$POOL_DIR" "$CACHE_DIR" | tee -a "$LOG_FILE"

if [[ -z "${SORYOS_SKIP_CLONE:-}" ]]; then
  # NOTE: les sources sont nos forks sory-x (depuis pop-os upstream)
  build_rust_component "https://github.com/sory-x/cosmic-epoch" "cosmic-epoch" "cosmic-files" || true
  build_rust_component "https://github.com/sory-x/cosmic-epoch" "cosmic-epoch" "cosmic-settings" || true
  build_rust_component "https://github.com/sory-x/cosmic-epoch" "cosmic-epoch" "cosmic-launcher" || true
fi

for template in "$ROOT_DIR/templates"/*/; do
  name="$(basename "$template")"
  build_local_package "$name" || true
done

printf '\n=== Build complete ===\n' | tee -a "$LOG_FILE"
printf 'Total .deb: %d\n' "$(ls "$POOL_DIR"/*.deb 2>/dev/null | wc -l)" | tee -a "$LOG_FILE"
