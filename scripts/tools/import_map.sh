#!/bin/bash
# One-command editor map import pipeline
# Usage: ./scripts/tools/import_map.sh [path-to-latestmap.json]
#
# If no path given, defaults to ~/Downloads/latestmap.json
#
# Steps:
#   1. Import editor tiles into chunk .tres files (Python)
#   2. Rebuild overworld.tscn + .scn from chunks (Godot headless)
#      This makes changes visible in both game AND Godot editor

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="/Users/developer-cloudprimero/Downloads/Godot.app/Contents/MacOS/Godot"
MAP_FILE="${1:-$HOME/Downloads/latestmap.json}"

if [ ! -f "$MAP_FILE" ]; then
    echo "ERROR: Map file not found: $MAP_FILE"
    exit 1
fi

echo "=== Editor Map Import Pipeline ==="
echo "Map file: $MAP_FILE"
echo ""

# Step 1: Import editor tiles into chunk .tres files
echo "--- Step 1: Importing editor tiles into chunks ---"
python3 "$PROJECT_DIR/scripts/tools/import_editor_map.py" "$MAP_FILE"
echo ""

# Step 2: Rebuild .tscn and .scn from chunks
echo "--- Step 2: Rebuilding overworld.tscn + .scn from chunks ---"
"$GODOT" --headless --path "$PROJECT_DIR" --script scripts/tools/chunks_to_tscn.gd 2>&1
echo ""

echo "=== Done! Changes visible in game AND Godot editor. ==="
