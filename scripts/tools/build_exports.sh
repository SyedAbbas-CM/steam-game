#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Users/developer-cloudprimero/Downloads/Godot.app/Contents/MacOS/Godot}"

PRESETS=(
  "Windows Desktop"
  "Windows Desktop (Compat x86_32)"
  "macOS"
  "Linux"
  "Linux (Compat x86_32)"
  "Android"
  "Web"
)

if [[ ! -x "$GODOT_BIN" ]]; then
  echo "Godot binary not found or not executable: $GODOT_BIN" >&2
  exit 1
fi

echo "Using Godot: $GODOT_BIN"
echo "Project: $ROOT_DIR"

for preset in "${PRESETS[@]}"; do
  echo
  echo "==> Exporting: $preset"
  "$GODOT_BIN" --headless --path "$ROOT_DIR" --export-release "$preset"
done

MAC_APP="$ROOT_DIR/builds/macos/DungeonCrawl.app"
if [[ -d "$MAC_APP" ]]; then
  echo
  echo "==> Normalizing macOS bundle names"
  python3 "$ROOT_DIR/scripts/tools/fix_macos_bundle_names.py" "$MAC_APP" "DungeonCrawl"
  echo "==> Re-signing macOS bundle"
  codesign --force --deep --sign - "$MAC_APP"
fi

echo
echo "Exports completed."
