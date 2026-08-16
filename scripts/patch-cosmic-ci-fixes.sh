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

workspaces_main="$ROOT/cosmic-workspaces-epoch/src/main.rs"
if [[ -f "$workspaces_main" ]]; then
  sed -i 's/commands::blur::blur(/commands::blur::blur::<Msg>(/g' "$workspaces_main"
fi

wifi_page="$ROOT/cosmic-initial-setup/src/page/wifi.rs"
if [[ -f "$wifi_page" ]]; then
  sed -i 's/Container::Dialog(true)/Container::Dialog/g' "$wifi_page"
fi

sw_cargo="$ROOT/simple-wrapper/simple-wrapper/Cargo.toml"
if [[ -f "$sw_cargo" ]]; then
  sed -i 's/"slog-stdlog",\?//g; s/, "slog-stdlog"//g' "$sw_cargo"
  if ! grep -q 'rev = "1ed69cb"' "$sw_cargo"; then
    sed -i 's|git = "https://github.com/smithay/smithay", default-features|git = "https://github.com/smithay/smithay", rev = "1ed69cb", default-features|' "$sw_cargo"
  fi
fi

cs_rules="$ROOT/cosmic-settings/debian/rules"
if [[ -f "$cs_rules" ]]; then
  sed -i 's/ischroot || just vendor/true # skip cargo vendor in CI/' "$cs_rules"
fi

printf 'applied CI compatibility patches under %s\n' "$ROOT"
