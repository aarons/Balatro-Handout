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
DEST="$MODS_DIR/NeowBlessings"
if [[ -L "$DEST" || "$SRC" == "$DEST" || "$SRC" == "$DEST/"* ]]; then
    echo "Refusing to modify a symlink or the source checkout: $DEST" >&2
    exit 1
fi
if [[ -e "$DEST" ]] && { [[ ! -f "$DEST/NeowBlessings.json" ]] ||
    ! grep -Eq '"id"[[:space:]]*:[[:space:]]*"NeowBlessings"' "$DEST/NeowBlessings.json"; }; then
    echo "Refusing to modify an unrecognized installation: $DEST" >&2
    exit 1
fi

if [[ "$ACTION" == uninstall ]]; then
    if [[ -d "$DEST" ]]; then
        rm -rf -- "$DEST"
        echo "Uninstalled from $DEST — restart Balatro to pick up changes."
    else
        echo "Not installed: $DEST"
    fi
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

echo "Installed to $DEST — restart Balatro to pick up changes."
