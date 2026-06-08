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

echo
echo "Exports completed."
