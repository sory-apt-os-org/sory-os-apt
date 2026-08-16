#!/usr/bin/env bash
# Ensure Cargo.lock exists for the workspace that contains a component.
set -euo pipefail

COMPONENT="${1:-}"
if [[ -z "$COMPONENT" ]]; then
  printf 'usage: %s <component-dir>\n' "$0" >&2
  exit 2
fi

COMPONENT="$(cd "$COMPONENT" && pwd)"
export CARGO_NET_GIT_FETCH_WITH_CLI=true

root="$COMPONENT"
while [[ "$root" != "/" ]]; do
  if [[ -f "$root/Cargo.toml" ]] && grep -q '^\[workspace\]' "$root/Cargo.toml"; then
    printf 'generating lockfile in %s\n' "$root"
    (cd "$root" && cargo generate-lockfile)
    exit 0
  fi
  root="$(dirname "$root")"
done

if [[ -f "$COMPONENT/Cargo.toml" && ! -f "$COMPONENT/Cargo.lock" ]]; then
  printf 'generating lockfile in %s\n' "$COMPONENT"
  (cd "$COMPONENT" && cargo generate-lockfile)
fi
