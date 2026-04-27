#!/usr/bin/env python3
from pathlib import Path
import re


ROOT = Path("/Users/developer-cloudprimero/Desktop/Godot/new-game-project")
SCRIPTS_DIR = ROOT / "scripts"
SCENES_DIR = ROOT / "scenes"
OUT_SCRIPTS = ROOT / "docs" / "obsidian" / "files" / "scripts"
OUT_SCENES = ROOT / "docs" / "obsidian" / "files" / "scenes"


SYSTEM_MAP = {
    "battle": "system_battle_rts",
    "overworld": "system_overworld",
    "dungeon": "system_dungeon",
    "quests": "system_quest_faction_save",
    "systems": "system_core_runtime",
    "stats": "system_player_runtime",
    "weapons": "system_player_runtime",
    "ui": "system_ui_runtime",
    "enemies": "system_enemy_runtime",
}


ROOT_FILE_SYSTEM_MAP = {
    "player.gd": "system_player_runtime",
    "enemy.gd": "system_enemy_runtime",
    "enemy_spawner.gd": "system_enemy_runtime",
    "bullet.gd": "system_player_runtime",
    "ui.gd": "system_ui_runtime",
}


SYSTEM_HUBS = {
    "system_core_runtime": [
        "file_game_manager.gd",
        "file_save_data.gd",
        "file_quest_manager.gd",
        "file_faction_manager.gd",
    ],
    "system_player_runtime": [
        "file_player.gd",
        "file_equipment_manager.gd",
        "file_weapon_system.gd",
        "file_level_system.gd",
        "file_status_effect_manager.gd",
        "file_spell_book.gd",
    ],
    "system_overworld": [
        "file_overworld.gd",
        "file_world_map_screen.gd",
        "file_war_table.gd",
        "file_army_management_screen.gd",
    ],
    "system_dungeon": [
        "file_dungeon_scene.gd",
        "file_dungeon_manager.gd",
        "file_floor_generator.gd",
        "file_dungeon_events.gd",
    ],
    "system_battle_rts": [
        "file_battle_arena.gd",
        "file_battle_simple_ai.gd",
        "file_battle_commander.gd",
        "file_battle_unit_system.gd",
        "file_battle_command_overlay.gd",
    ],
    "system_enemy_runtime": [
        "file_enemy.gd",
        "file_enemy_spawner.gd",
        "file_enemy_definition.gd",
    ],
    "system_ui_runtime": [
        "file_game_hud.gd",
        "file_inventory_screen.gd",
        "file_world_map_screen.gd",
        "file_title_screen.gd",
    ],
    "system_quest_faction_save": [
        "file_quest_manager.gd",
        "file_faction_manager.gd",
        "file_save_data.gd",
        "file_game_manager.gd",
    ],
}


def slugify_file_name(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]", "_", name)


def note_name_for_file(path: Path) -> str:
    return f"file_{slugify_file_name(path.name)}"


def system_for_script(rel: Path) -> str:
    if rel.parent == Path("."):
        return ROOT_FILE_SYSTEM_MAP.get(rel.name, "system_core_runtime")
    return SYSTEM_MAP.get(rel.parts[0], "system_core_runtime")


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def related_hubs(system_note: str, note_name: str) -> list[str]:
    return [n for n in SYSTEM_HUBS.get(system_note, []) if n != note_name][:6]


def folder_neighbors_for_script(rel_under_scripts: Path, note_name: str) -> list[str]:
    parent = rel_under_scripts.parent
    if parent == Path("."):
        scripts = sorted([p for p in SCRIPTS_DIR.glob("*.gd")])
    else:
        scripts = sorted([p for p in (SCRIPTS_DIR / parent).glob("*.gd")])
    names = []
    for p in scripts:
        n = note_name_for_file(p)
        if n != note_name:
            names.append(n)
    return names[:8]


def scene_related_script_alias(scene_name: str) -> str | None:
    script_candidate = f"file_{scene_name}.gd"
    return script_candidate


def write_script_note(script_path: Path) -> None:
    rel = script_path.relative_to(ROOT)
    rel_under_scripts = script_path.relative_to(SCRIPTS_DIR)
    system_note = system_for_script(rel_under_scripts)
    out_path = OUT_SCRIPTS / rel_under_scripts.with_suffix(".md")
    ensure_parent(out_path)
    note_name = note_name_for_file(script_path)
    title = rel_under_scripts.name
    hubs = related_hubs(system_note, note_name)
    neighbors = folder_neighbors_for_script(rel_under_scripts, note_name)
    hubs_text = "\n".join(f"- [[{n}]]" for n in hubs) if hubs else "- none"
    neighbors_text = "\n".join(f"- [[{n}]]" for n in neighbors) if neighbors else "- none"
    content = f"""---
aliases:
  - {note_name}
---

# {title}

Source file:

- [{rel}](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/{rel.as_posix()})

System:

- [[{system_note}]]

Category:

- `script`

Repo path:

- `{rel.as_posix()}`

Related hub files:

{hubs_text}

Same-folder neighbors:

{neighbors_text}

Use this note in Obsidian graph view as a wrapper around the real code file.

Related navigation:

- [[GRAPH_HOME]]
- [[SYSTEMS_INDEX]]
- [[FILES_INDEX]]
"""
    out_path.write_text(content)


def write_scene_note(scene_path: Path) -> None:
    rel = scene_path.relative_to(ROOT)
    rel_under_scenes = scene_path.relative_to(SCENES_DIR)
    top = rel_under_scenes.parts[0] if len(rel_under_scenes.parts) > 1 else "core"
    system_note = {
        "battle": "system_battle_rts",
        "overworld": "system_overworld",
        "dungeon": "system_dungeon",
        "ui": "system_ui_runtime",
    }.get(top, "system_core_runtime")
    out_path = OUT_SCENES / rel_under_scenes.with_suffix(".md")
    ensure_parent(out_path)
    title = rel_under_scenes.name
    note_name = note_name_for_file(scene_path)
    related_script = scene_related_script_alias(rel_under_scenes.stem)
    related_script_text = f"- [[{related_script}]]" if related_script else "- none"
    content = f"""---
aliases:
  - {note_name}
---

# {title}

Source file:

- [{rel}](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/{rel.as_posix()})

System:

- [[{system_note}]]

Category:

- `scene`

Repo path:

- `{rel.as_posix()}`

Related script note:

{related_script_text}

Use this note in Obsidian graph view as a wrapper around the real scene file.

Related navigation:

- [[GRAPH_HOME]]
- [[SYSTEMS_INDEX]]
- [[FILES_INDEX]]
"""
    out_path.write_text(content)


def main() -> None:
    OUT_SCRIPTS.mkdir(parents=True, exist_ok=True)
    OUT_SCENES.mkdir(parents=True, exist_ok=True)

    for script in sorted(SCRIPTS_DIR.rglob("*.gd")):
        write_script_note(script)

    for scene in sorted(SCENES_DIR.rglob("*.tscn")):
        write_scene_note(scene)
    for scene in sorted(SCENES_DIR.rglob("*.scn")):
        write_scene_note(scene)


if __name__ == "__main__":
    main()
