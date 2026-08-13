#!/usr/bin/env bash
# Small upstream compatibility fixes applied during CI source preparation.
set -euo pipefail

ROOT="${1:-}"
if [[ -z "$ROOT" ]]; then
  printf 'usage: %s <cosmic-epoch-dir>\n' "$0" >&2
  exit 2
fi

ROOT="$(cd "$ROOT" && pwd)"

player_main="$ROOT/cosmic-player/src/main.rs"
if [[ -f "$player_main" ]]; then
  sed -i 's/border_padding = Some(0)/border_padding = Some(0.0)/' "$player_main"
fi

portal_justfile="$ROOT/xdg-desktop-portal-cosmic/justfile"
if [[ -f "$portal_justfile" ]]; then
  sed -i 's/\${SOURCE_GIT_HASH}/\${SOURCE_GIT_HASH:-}/g' "$portal_justfile"
fi

greeter_common="$ROOT/cosmic-greeter/src/common.rs"
if [[ -f "$greeter_common" ]]; then
  sed -i 's/return blur(id, Some(rects))\.discard();/return blur::<M>(id, Some(rects)).discard();/' "$greeter_common"
fi

printf 'applied CI compatibility patches under %s\n' "$ROOT"
