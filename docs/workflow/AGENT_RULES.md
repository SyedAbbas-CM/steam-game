# Agent Rules

These rules exist because parallel AI work will corrupt the repo if ownership is fuzzy.

## Core Rules

- One integration owner per feature.
- One agent per write zone.
- No two agents may edit the same file in the same phase.
- If a shared file must change, only the integration owner edits it.
- Every agent works from an approved `DESIGN.md`.
- Every agent stops at the agreed phase boundary.

## Write Zones

Suggested default ownership split for this repo:

- `systems/`, `quests/`, `stats/`, `data/`: systems agent
- `player/`, `enemy/`, `battle/`, `dungeon/`: gameplay agent
- `ui/`, `scenes/ui/`, menu flow: UI agent
- `overworld/`, world streaming, map state: world agent
- `tools/`, import/export pipelines: tooling agent

## Shared Files

Treat these as integration-owner-only unless explicitly assigned:

- [project.godot](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/project.godot)
- [scripts/systems/game_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/game_manager.gd)
- [scripts/systems/save_data.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/save_data.gd)
- [scripts/systems/resource_registry.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/resource_registry.gd)
- Any shared `.tscn` scene used by multiple systems

## Handoff Format

Every agent handoff should include:

- Goal completed
- Files changed
- Public APIs added or changed
- Follow-up work blocked on integration
- Known risks
- Verification performed

## Merge Discipline

- Review diffs before any merge.
- Integrate the smallest complete phase first.
- Rebase or reread changed shared files before starting the next phase.
- Do not let a second agent read stale context from a file that just changed.

## Stop Conditions

An agent must stop and hand back control if:

- It needs to touch a file outside its zone.
- The approved file list changes materially.
- It finds hidden coupling to another in-flight agent's work.
- The feature requires save-format changes not in the original design.
