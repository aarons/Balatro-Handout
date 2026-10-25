#!/usr/bin/env bash
# Copy the mod into the local Balatro mods folder for playtesting.
# Usage: ./install.sh [--uninstall]
set -euo pipefail

ACTION=install
case "${1:-}" in
    '') ;;
    --uninstall) ACTION=uninstall ;;
    -h|--help)
        echo "Usage: $0 [--uninstall]"
        echo "Set BALATRO_MODS_DIR to override the local Balatro Mods directory."
        exit 0 ;;
    *) echo "Unknown option: $1 (use --help)" >&2; exit 2 ;;
esac
if (( $# > 1 )); then
    echo "Expected at most one option (use --help)." >&2
    exit 2
fi

MODS_DIR="${BALATRO_MODS_DIR:-$HOME/Library/Application Support/Balatro/Mods}"
SRC="$(cd "$(dirname "$0")" && pwd -P)"

if [[ ! -d "$MODS_DIR" ]]; then
    echo "Mods folder not found: $MODS_DIR" >&2
    echo "Is Steamodded installed? (Override with BALATRO_MODS_DIR=...)" >&2
    exit 1
fi

MODS_DIR="$(cd "$MODS_DIR" && pwd -P)"
DEST="$MODS_DIR/handout"
LEGACY_DEST="$MODS_DIR/NeowBlessings"
# Check both locations before making changes. The old ID is retained for saved
# settings, but the name distinguishes Handout from the original Neow mod.
for target in "$DEST" "$LEGACY_DEST"; do
    if [[ -L "$target" || "$SRC" == "$target" || "$SRC" == "$target/"* ]]; then
        echo "Refusing to modify a symlink or the source checkout: $target" >&2
        exit 1
    fi
    if [[ -e "$target" ]] && { [[ ! -f "$target/NeowBlessings.json" ]] ||
        ! grep -Eq '"id"[[:space:]]*:[[:space:]]*"NeowBlessings"' "$target/NeowBlessings.json" ||
        ! grep -Eq '"name"[[:space:]]*:[[:space:]]*"Handout"' "$target/NeowBlessings.json"; }; then
        echo "Refusing to modify an unrecognized installation: $target" >&2
        exit 1
    fi
done

if [[ "$ACTION" == uninstall ]]; then
    for target in "$DEST" "$LEGACY_DEST"; do
        if [[ -d "$target" ]]; then
            rm -rf -- "$target"
            echo "Uninstalled from $target — restart Balatro to pick up changes."
        else
            echo "Not installed: $target"
        fi
    done
    exit 0
fi

# Copy only runtime files. Steamodded saves player settings outside this folder.
rsync -a --delete \
    --include '/assets/***' \
    --include '/localization/***' \
    --include '/NeowBlessings.json' \
    --include '/manifest.json' \
    --include '/neow_blessings.lua' \
    --include '/config.lua' \
    --include '/icon.png' \
    --exclude '*' \
    "$SRC/" "$DEST/"

# Remove the previous Handout copy only after the new installation succeeds.
if [[ -d "$LEGACY_DEST" ]]; then
    rm -rf -- "$LEGACY_DEST"
    echo "Migrated previous installation from $LEGACY_DEST."
fi

echo "Installed to $DEST — restart Balatro to pick up changes."
