#!/usr/bin/env bash
# Copy the mod into the local Balatro mods folder for playtesting.
# Usage: ./install.sh
set -euo pipefail

MODS_DIR="${BALATRO_MODS_DIR:-$HOME/Library/Application Support/Balatro/Mods}"
DEST="$MODS_DIR/NeowBlessings"
SRC="$(cd "$(dirname "$0")" && pwd)"

if [[ ! -d "$MODS_DIR" ]]; then
    echo "Mods folder not found: $MODS_DIR" >&2
    echo "Is Steamodded installed? (Override with BALATRO_MODS_DIR=...)" >&2
    exit 1
fi

rsync -a --delete \
    --exclude '.git' \
    --exclude 'screenshots' \
    --exclude 'install.sh' \
    "$SRC/" "$DEST/"

echo "Installed to $DEST — restart Balatro to pick up changes."
