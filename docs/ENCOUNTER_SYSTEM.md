# Encounter Variety System

## Overview
Combat rooms are assigned an EncounterType that controls room shape, enemy count, HP scaling, and spawn formation.

## Encounter Types

| Encounter | Shape | Enemy Count | HP Mult | Spawn Formation | Feel |
|-----------|-------|-------------|---------|-----------------|------|
| STANDARD (40%) | Any | Normal | 1.0x | Random scatter | Classic dungeon room |
| AMBUSH (15%) | TINY | 2x normal | 1.0x | Perimeter (along walls) | Packed, claustrophobic |
| HORDE (15%) | RECTANGLE/CIRCLE | 3x normal | 0.5x | Wave: half now, half after 5s | Swarm of glass cannons |
| GAUNTLET (10%) | WIDE_RECT | 1.5x normal | 1.0x | Rows/columns formation | Organized resistance |
| REST (10%) | TINY | 0 | — | Empty | Breather room |
| ARENA (10%) | ARENA (23-25w) | 2x normal | 1.5x | Ring around center | Boss-lite arena fight |

## Room Shapes
- **TINY**: 7-9 x 7-9 tiles (ambush/rest rooms)
- **ARENA**: 23-25 x 19-23 tiles (biggest rooms, arena encounters)
- Grid cell size: 29x27 tiles to fit ARENA + corridor gap

## Formation Details

### Perimeter (AMBUSH)
Enemies spawn on floor tiles exactly 1-2 tiles from walls — surrounding the player from the edges.

### Rows (GAUNTLET)
Enemies arranged in evenly-spaced columns/rows across the room width. Feels like facing a firing squad.

### Ring (ARENA)
Enemies placed on a circle at ~35% of room radius from center. Player enters surrounded.

### Waves (HORDE)
- Wave 1: half the enemies spawn immediately (random scatter)
- Wave 2: remaining enemies spawn after 5 seconds with a white flash effect
- All horde enemies have 0.5x HP — individually weak but overwhelming in numbers

## Elite HP
- Elite `hp_mult = 4.0` (was 2.5)
- Example: Skeleton (18 base HP) as elite on floor 1 = `18 * 4.0 * 1.3 level_scale ≈ 94 HP`

## Void Safety Net
- `_floor_tile_set` dictionary tracks all walkable tile positions (rooms + corridors + exits)
- Every 0.2s, checks if player tile position is in the set
- If player is in void (knocked through walls), teleports back to last safe position
- Cleared and rebuilt each floor

## Future Ideas
- Encounter-specific music/ambience
- Visual cues before entering (skull icon for ambush, wave icon for horde)
- Encounter-specific loot bonuses (horde = more gold, arena = better drops)
- Trap-heavy encounter type (few enemies, lots of hazards)
- Puzzle rooms (levers, pressure plates to unlock exit)
- Survival timer rooms (survive X seconds, enemies keep spawning)
- Dark rooms (limited visibility radius)
