# Recovery Guide — Full Project Diagnosis

## Root Cause

Two Claude Code sessions ran **concurrently** on April 27, editing the same files:
- `ed3689fc` — weapon overhaul, spell fixes, ammo system
- `b43cc5c4` — equipment_manager fix (26 edits, 2 writes)

Session `b43cc5c4` systematically **removed `var` declarations** from code while leaving all references to those variables intact. This broke 17 script files. Additionally, `ed3689fc`'s tracked-file changes (weapon patterns, spell fixes, player abilities) were overwritten.

## Current State (HEAD = 54f909b)

- **177 uncommitted file changes** on disk (156 scripts + resources modified, 0 untracked)
- **17 scripts fail to parse** due to missing variable declarations
- **93 script files modified** vs HEAD
- **52 resource files modified** vs HEAD
- New .tres files (31 weapons, 4 ammo) survived as they were untracked

## The 17 Broken Scripts

### Fastest Fix: Revert to HEAD

For each broken file, `git checkout HEAD -- <path>` restores the working committed version. Then the intended changes from session transcripts can be properly reapplied.

```bash
git checkout HEAD -- \
  scripts/battle/battle_arena.gd \
  scripts/battle/battle_command_overlay.gd \
  scripts/battle/battle_flow_field.gd \
  scripts/battle/battle_simple_ai.gd \
  scripts/companions/companion_ai.gd \
  scripts/drops/pickup.gd \
  scripts/dungeon/dungeon_events.gd \
  scripts/dungeon/dungeon_manager.gd \
  scripts/dungeon/dungeon_scene.gd \
  scripts/dungeon/hazard_area.gd \
  scripts/dungeon/traps/explosive_barrel.gd \
  scripts/dungeon/traps/poison_gas.gd \
  scripts/dungeon/traps/rail_trap.gd \
  scripts/enemy.gd \
  scripts/tools/sample_overworld.gd \
  scripts/tools/sample_rooms.gd \
  scripts/ui/world_map_screen.gd
```

### Error Pattern per File

| File | Errors | Issue |
|------|--------|-------|
| battle_arena.gd | ~30 | `var` declarations stripped: `t0`, `layer`, `data`, `gm`, etc. |
| battle_command_overlay.gd | ~5 | `player_groups`, `alive_count`, `btn` undeclared |
| battle_flow_field.gd | 1 | `dirs` dictionary never declared |
| battle_simple_ai.gd | ~50 | Pervasive: `t`, `blue_total`, `enemy_groups`, `spd`, etc. |
| companion_ai.gd | ~4 | `dir`, `sfx` undeclared |
| pickup.gd | 1 | `sfx` undeclared |
| dungeon_events.gd | ~40 | All event functions: `center`, `circle`, `shape`, `prompt`, etc. |
| dungeon_manager.gd | ~25 | `t0`, `res`, `prefix`, `chain`, `room_data`, etc. |
| dungeon_scene.gd | ~10 | **3x code duplication** + use-before-declare (`fpv`, `_dui`, `quest_log`) |
| hazard_area.gd | 1 | `sem` undeclared |
| explosive_barrel.gd | 1 | Truncated multi-line declaration (orphaned expression) |
| poison_gas.gd | 1 | Variable shadowing |
| rail_trap.gd | 2 | `dmg`, `vfx` undeclared |
| enemy.gd | ~20 | `spr`, `dm`, `is_boss`, `atk`, `to_player`, etc. |
| sample_overworld.gd | 1 | Use-before-declaration scope issue |
| sample_rooms.gd | ~8 | Code duplication + undeclared variables in tile loops |
| world_map_screen.gd | ~25 | `a`, `b`, `pa`, `pb`, `nd`, `zd`, `fm`, `sfx`, etc. |

## Sessions Contributing Uncommitted Changes

### Post-Commit Sessions (after 54f909b)

| Session | Date | Edits | Writes | Work Done |
|---------|------|-------|--------|-----------|
| `86c96314` | Apr 24 | 163 | 10 | Animations, balance, quests |
| `5dbee2fc` | Apr 27 01:28 | 286 | 163 | Attack mods, traps, spells, mercenary class, FPV, world map, factions |
| `2760b5ef` | Apr 27 18:34 | 164 | 0 | RTS battle AI improvements |
| `ed3689fc` | Apr 27 18:47 | 109 | 29 | Weapon overhaul, spell fixes, ammo system |
| `b43cc5c4` | Apr 27 18:47 | 26 | 2 | Equipment manager fix (CAUSED THE BREAKAGE) |

### Key Changes by Session

#### `86c96314` (Apr 24) — Animations & Balance
- Enemy animator system
- Movement patterns for enemies
- Attack modifiers / attack slots
- Quest fixes
- Class balance (warrior/archer/wizard)

#### `5dbee2fc` (Apr 27) — Major Feature Session (286 edits!)
- Dungeon traps: bell_trap, collapsing_floor, explosive_barrel, flame_jet, poison_gas, rail_trap, swinging_axe, trap_lever
- Dungeon events system overhaul
- First-person dungeon view (FPV)
- World map screen with force-directed graph layout
- Faction manager + territory panel
- Mercenary class
- Hire UI
- NPC script expansions
- War table object
- Quest chain generator
- Enchant UI improvements
- Inventory screen major overhaul
- Death screen changes
- Test arena improvements

#### `2760b5ef` (Apr 27) — Battle AI
- Battle simple AI strategic improvements
- Battle command overlay
- Battle flow field
- Battle arena wave spawning
- Battle collision, fog of war, renderer
- Battle unit system, commander

#### `ed3689fc` (Apr 27) — Weapons & Spells
- 5 new weapon patterns (greatsword, great_axe, whip, scythe, claws)
- 8 spacebar abilities + 6 shift abilities for new weapons
- Spell creation fix (straight/homing/spread behaviors)
- Stackable ammo system (throwing knives, javelins)
- 31 weapon .tres files
- 4 ammo .tres files
- Spell status effects on projectiles/touch

#### `b43cc5c4` (Apr 27) — THE BREAKER
- 26 edits that systematically removed `var` declarations
- Likely tried to "fix" or "simplify" code but broke everything

## Recovery Strategy

### Option A: Revert ALL to HEAD, then reapply from transcripts (RECOMMENDED)
```bash
git checkout HEAD -- scripts/ resources/
```
This reverts all 177 files to committed state. Then use session transcripts to reapply:
1. `86c96314` edits first (animations, balance)
2. `5dbee2fc` edits second (traps, FPV, world map, factions)
3. `2760b5ef` edits third (battle AI)
4. `ed3689fc` edits fourth (weapons, spells)
5. Skip `b43cc5c4` entirely (it only broke things)

### Option B: Fix only the 17 broken files, keep other changes
Revert only the 17 broken scripts to HEAD, leaving the ~80 other modified files as-is. Riskier because some of those changes may also be partial/conflicting.

### Where to Find Session Transcripts
```
/Users/developer-cloudprimero/.claude/projects/-Users-developer-cloudprimero-Desktop-Godot/
```
Each `.jsonl` file contains full Edit/Write tool calls with `old_string`, `new_string`, and `file_path`. All edits are fully recoverable.

## Files That Survived (Untracked New Files)

These were created by sessions and are NOT broken (new files, not modified):
- `resources/items/loy/` — 31 new weapon .tres + 4 ammo .tres
- `docs/QUESTS.md` (194 lines)
- `docs/WEAPONS.md` (471 lines)
- Various trap/system scripts created fresh

## Specific Bugs to Fix After Recovery

1. **spell_book.gd `can_cast()`** (line 55): References bare `spell` instead of `spell_slots[slot]`
2. **spell_book.gd `cast_spell()`** (line 75): Same bare `spell` bug
3. **spell_book.gd `_cast_nova()`** (lines 165-168): References `enemies`, `dist`, `radius` without declaring them
4. **spell_book.gd `_cast_self()`** (line 198): `tween` never declared
5. **Spell creation**: Straight behavior spreads, homing uses nonexistent `set_homing()`, spread angle too narrow
6. **weapon_system.gd**: Missing patterns for greatsword/great_axe/whip/scythe/claws
7. **player.gd**: Missing spacebar/shift abilities for new weapon types
8. **resource_registry.gd**: Missing entries for 31 new weapons + 4 ammo items
9. **haven-weapon.tres**: Missing ammo items in shop stock
