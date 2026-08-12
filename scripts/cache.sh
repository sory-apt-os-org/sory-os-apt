#!/usr/bin/env bash
# cache.sh — Cache incrémental pour builds (pattern extrait de pop-ci/src/cache.rs)
# Usage:
#   source scripts/cache.sh
#   cache_init "_build/ci"          # Initialise le cache dans _build/ci
#   cache_build "mon-composant" false || cache_build "mon-composant" true  # (re)build

CACHE_ROOT=""
CACHE_CLEANED=false

cache_init() {
  CACHE_ROOT="$1"
  CACHE_CLEANED=false
  mkdir -p "$CACHE_ROOT"
}

cache_path() {
  echo "$CACHE_ROOT/$1"
}

cache_exists() {
  [[ -d "$CACHE_ROOT/$1" ]]
}

cache_build() {
  local name="$1"
  local force="${2:-false}"
  local partial="$CACHE_ROOT/partial.$name"
  local target="$CACHE_ROOT/$name"

  if ! $force && [[ -d "$target" ]]; then
    return 0
  fi

  if [[ -d "$partial" ]]; then
    echo "cache: partial build exists for $name, cleaning" >&2
    rm -rf "$partial"
  fi

  mkdir -p "$partial"
  echo "$partial"
}

cache_finalize() {
  local name="$1"
  local partial="$CACHE_ROOT/partial.$name"
  local target="$CACHE_ROOT/$name"

  rm -rf "$target"
  mv "$partial" "$target"
  CACHE_CLEANED=true
}

cache_clean_stale() {
  local retain_pattern="$1"
  for entry in "$CACHE_ROOT"/*/; do
    local base
    base=$(basename "$entry")
    if [[ "$base" == partial.* ]]; then
      echo "cache: removing stale partial $base" >&2
      rm -rf "$entry"
      CACHE_CLEANED=true
    elif ! echo "$base" | grep -qE "$retain_pattern"; then
      echo "cache: removing stale entry $base" >&2
      rm -rf "$entry"
      CACHE_CLEANED=true
    fi
  done
}

# rsync publish (pattern extrait de pop-ci/src/main.rs:168-198)
rsync_publish() {
  local src="$1"
  local dst="$2"
  local rsh="${3:-}"

  local args=(--archive --compress --delay-updates --delete --mkpath)
  if [[ -n "$rsh" ]]; then
    args+=(--rsh="$rsh")
  fi

  rsync "${args[@]}" "$src/" "$dst/"
}
