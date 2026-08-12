#!/usr/bin/env bash
set -euo pipefail

POOL_DIR="${1:-$(dirname "$0")/../pool}"
OUT_DIR="${2:-$POOL_DIR}"
PATCHED_SUFFIX="-testpatch"

patched=0
skipped=0

for deb in "$POOL_DIR"/*_amd64.deb "$POOL_DIR"/*_all.deb; do
    [ -f "$deb" ] || continue
    name=$(basename "$deb")

    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT

    dpkg-deb -R "$deb" "$tmpdir" 2>/dev/null || { rm -rf "$tmpdir"; continue; }

    desktop_files=$(find "$tmpdir/usr/share/applications" -name "*.desktop" 2>/dev/null || true)

    if [ -z "$desktop_files" ]; then
        rm -rf "$tmpdir"
        skipped=$((skipped + 1))
        continue
    fi

    changed=false
    for f in $desktop_files; do
        if grep -q "OnlyShowIn=COSMIC" "$f" 2>/dev/null; then
            sed -i 's/OnlyShowIn=COSMIC/OnlyShowIn=COSMIC;X-Cinnamon;/' "$f"
            changed=true
        fi
        if grep -q "^Categories=COSMIC$" "$f" 2>/dev/null; then
            sed -i 's/^Categories=COSMIC$/Categories=Settings;System;/' "$f"
            changed=true
        fi
        sed -i '/^NoDisplay=true/d' "$f" 2>/dev/null || true
    done

    if [ "$changed" = true ]; then
        outname="${name%.deb}${PATCHED_SUFFIX}.deb"
        dpkg-deb -b "$tmpdir" "$OUT_DIR/$outname" 2>/dev/null
        echo "PATCHED: $name -> $outname"
        patched=$((patched + 1))
    else
        skipped=$((skipped + 1))
    fi

    rm -rf "$tmpdir"
done

echo "---"
echo "Patchés: $patched | Ignorés (pas de .desktop): $skipped"
echo "Utilise: sudo dpkg -i $OUT_DIR/*${PATCHED_SUFFIX}.deb"
