# Build Size Notes

## Root cause

The Windows export was large because the export preset used `export_filter="all_resources"` and the project still contained multiple heavyweight overworld variants:

- `res://resources/world/chunks/`
- `res://resources/world/chunks2/`
- `res://scenes/overworld/overworld.tscn`
- `res://scenes/overworld/overworld2.tscn`
- `res://scenes/overworld/overworld_loy_original.tscn`

The tile art was not the problem. The heavyweight part was serialized world data:

- giant text `.tscn` overworld editor scenes
- giant text `.tres` chunk files storing packed tile arrays
- a duplicated chunk tree in `chunks2/`

## What runtime actually needs

Current runtime world path is:

- `res://scenes/overworld/overworld.scn`
- `res://resources/world/chunks/`

The `overworld2*`, `overworld_loy_original*`, and `chunks2/` assets are editor/tooling variants and should not ship in the normal runtime build.

## Fix applied

### Runtime cleanup

`scripts/battle/battle_arena.gd`

- removed fallback reference to `overworld2_light.tscn`
- changed overworld return fallback to prefer `overworld.scn`

### Export cleanup

`export_presets.cfg`

Excluded:

- `resources/world/chunks2/*`
- `scenes/overworld/overworld2.tscn`
- `scenes/overworld/overworld2.scn`
- `scenes/overworld/overworld2_light.tscn`
- `scenes/overworld/overworld_loy_original.tscn`
- `scenes/overworld/overworld_loy_original.scn`
- `scenes/overworld/overworld.tscn`

## Result

Windows export dropped from roughly:

- `~424M` after generic junk cleanup

to:

- `~185M` file size
- `~196M` reported by `du`

## Remaining options

If smaller exports are needed later:

1. Turn off embedded PCK for distribution.
   - Smaller `.exe`
   - Similar total shipped size

2. Create a lightweight playtest preset.
   - dungeon/boss-arena only
   - no overworld world data

3. Replace text chunk `.tres` resources with a denser runtime format.
   - likely largest long-term win if world size keeps growing
