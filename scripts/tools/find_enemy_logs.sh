#!/usr/bin/env bash
set -euo pipefail

query="${*:-}"
log_dir="${ENEMY_OBS_DIR:-$HOME/Library/Application Support/Godot/app_userdata/DungeonCrawl/enemy_observability}"

if [[ ! -d "$log_dir" ]]; then
  echo "No enemy observability logs found at: $log_dir" >&2
  exit 1
fi

if [[ -z "$query" ]]; then
  find "$log_dir" -type f \( -name '*_summary.txt' -o -name '*_spawns.jsonl' \) -print | sort
  exit 0
fi

rg -i -- "$query" "$log_dir"
