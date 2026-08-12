#!/usr/bin/env bash
set -euo pipefail

# Build COSMIC components for SoryOS APT repository
# This script builds all Rust components in cosmic-epoch/ and publishes .deb files

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POOL_DIR="$ROOT_DIR/pool/stable"
COSMIC_DIR="$ROOT_DIR/../cosmic-epoch"
LOG_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOG_DIR/build-cosmic-local.log"

mkdir -p "$LOG_DIR" "$POOL_DIR"
: > "$LOG_FILE"

require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'Missing required tool: %s\n' "$1" | tee -a "$LOG_FILE" >&2
        exit 1
    fi
}

require_rust_toolchain() {
    if ! command -v cargo >/dev/null 2>&1; then
        printf 'ERROR: cargo not found. Install Rust 1.93+ (rustup) and ensure ~/.cargo/bin is on PATH.\n' | tee -a "$LOG_FILE" >&2
        exit 1
    fi
    local rustc_version
    rustc_version=$(rustc --version | awk '{print $2}')
    if ! rustc --version | grep -qE '1\.(9[6-9]|[1-9][0-9]{2,})'; then
        printf 'ERROR: Rust 1.96+ required (found %s). CI should use rustup default stable.\n' "$rustc_version" | tee -a "$LOG_FILE" >&2
        exit 1
    fi
}

require_tool dpkg-buildpackage
require_tool dpkg-deb

build_component() {
    local dir="$1"
    local control_file="$dir/debian/control"

    if [ ! -f "$control_file" ]; then
        printf 'SKIP %s: no debian/control\n' "$dir" | tee -a "$LOG_FILE"
        return 0
    fi

    local source_name
    source_name=$(grep '^Source:' "$control_file" | sed 's/Source: //')

    printf 'Building %s (%s)...\n' "$dir" "$source_name" | tee -a "$LOG_FILE"

    pushd "$dir" >/dev/null
    if dpkg-buildpackage -us -uc -b -d >> "$LOG_FILE" 2>&1; then
        popd >/dev/null
        # Move .deb files to pool directory
        local found_deb=0
        while IFS= read -r deb_file; do
            if [ -f "$deb_file" ]; then
                mv "$deb_file" "$POOL_DIR/"
                printf '  -> %s\n' "$deb_file" | tee -a "$LOG_FILE"
                found_deb=1
            fi
        done < <(find . -maxdepth 1 -name "${source_name}_*.deb")

        if [ $found_deb -eq 0 ]; then
            printf 'WARNING: No .deb files found for %s\n' "$source_name" | tee -a "$LOG_FILE" >&2
        fi

        return 0
    else
        popd >/dev/null
        printf 'FAIL %s\n' "$dir" | tee -a "$LOG_FILE" >&2
        # Show the last few lines of the log for debugging
        tail -50 "$LOG_FILE" | grep -i "error\|fail\|error:" | head -10
        return 1
    fi
}

# Define COSMIC components to build (in order)
COMPONENTS=(
    cosmic-applets cosmic-applibrary cosmic-bg cosmic-comp
    cosmic-edit cosmic-files cosmic-greeter cosmic-icons
    cosmic-idle cosmic-initial-setup cosmic-launcher cosmic-monitor
    cosmic-notifications cosmic-osd cosmic-panel cosmic-player
    cosmic-randr cosmic-screenshot cosmic-session cosmic-settings
    cosmic-settings-daemon cosmic-sory-ia cosmic-store cosmic-term cosmic-wallpapers
    cosmic-workspaces-epoch soryos-launcher simple-wrapper xdg-desktop-portal-cosmic
)

BUILD_ALL=false
TARGETS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --all) BUILD_ALL=true ;;
        --list) for c in "${COMPONENTS[@]}"; do echo "$c"; done; exit 0 ;;
        --help)
            echo "Usage: $0 [--all] [--list] [--help]"
            echo "Build COSMIC components for SoryOS APT"
            echo "  --all    Build all components"
            echo "  --list   List component names"
            echo "  --help   Show this help"
            exit 0
            ;;
        *)
            TARGETS+=("$1")
            ;;
    esac
    shift
done

if [ "$BUILD_ALL" = true ] || [ ${#TARGETS[@]} -eq 0 ]; then
    TARGETS=("${COMPONENTS[@]}")
fi

if [ ! -d "$COSMIC_DIR" ]; then
    printf 'ERROR: cosmic-epoch not found at %s\n' "$COSMIC_DIR" >&2
    exit 1
fi

require_rust_toolchain

cd "$COSMIC_DIR"

FAILED=0
for target in "${TARGETS[@]}"; do
    if [ ! -d "$target" ]; then
        printf 'SKIP %s: not found\n' "$target" | tee -a "$LOG_FILE"
        continue
    fi
    build_component "$target" || FAILED=$((FAILED + 1))
done

if [ "$FAILED" -gt 0 ]; then
    printf '\n%d component(s) failed\n' "$FAILED" | tee -a "$LOG_FILE" >&2
    exit 1
else
    printf '\nAll components built successfully\n' | tee -a "$LOG_FILE" >&2
fi

exit "$FAILED"
