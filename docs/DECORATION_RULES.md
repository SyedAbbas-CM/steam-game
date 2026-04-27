# Dungeon Decoration Rules

Source: `lofi_dungeon_features.png` (source 1 in tileset), 20 cols x ~10 rows.
Tile names from `dungeon_features_32_tileset.tres` custom_data_0.

## Complete Sprite Catalog (Source 1)

### Row 0 — Barrels, Blocks, Weapon Racks, Arrow Traps
| Coord | Name | Notes |
|-------|------|-------|
| (0,0) | barrel | |
| (1,0) | barrel_open | |
| (2,0) | barrel_cluster_3 | 3-barrel group |
| (3,0) | barrel_cluster_2 | 2-barrel group |
| (4,0) | barrel_cluster_2_alt | 2-barrel variant |
| (5,0) | small_barrel | |
| (6,0) | Block | Solid block |
| (7,0) | weapon_rack | Front-facing |
| (8,0) | weapon_rack_left | Faces left |
| (9,0) | weapon_rack_right | Faces right |
| (10,0) | arrow_trap_front | Trap |
| (11,0) | arrow_trap_left | Trap |

### Row 1 — Grate, Altar, Lamps, Stools, Tables, Gold
| Coord | Name | Notes |
|-------|------|-------|
| (0,1) | Iron_Grate | Prison bars |
| (1,1) | altar | Ritual altar |
| (2,1) | lamp_off | |
| (3,1) | lamp_on | |
| (4,1) | lamp_flicker | Animated |
| (5,1) | stool | |
| (6,1) | stool_flipped | |
| (7,1) | stool_flipped_alt | |
| (8,1) | table_glasses_right | Table with drinks |
| (9,1) | table_glasses_left | Table with drinks |
| (10,1) | table_glasses | Table with drinks |
| (11,1) | gold | Small gold pile |
| (12,1) | gold_large | Medium gold pile |
| (13,1) | gold_very_large | Big gold pile |

### Row 2 — Chairs, Tables, Bookshelves, Wardrobes, Beds, Carpets
| Coord | Name | Notes |
|-------|------|-------|
| (0,2) | chair_right | Faces right |
| (1,2) | chair_left | Faces left |
| (2,2) | chair_front | Faces front/down |
| (3,2) | table | Standard table |
| (4,2) | bookshelf | Front-facing |
| (5,2) | bookshelf_left | |
| (6,2) | bookshelf_right | |
| (7,2) | wardrobe | Closed |
| (8,2) | wardrobe_open | Open |
| (10,2) | bed_right_red | Red bed facing right |
| (11,2) | bed_left_red | Red bed facing left |
| (12,2) | bed_blue_left | Blue bed facing left |
| (13,2) | bed_blue_right | Blue bed facing right |
| (14,2) | bed_green_left | Green bed facing left |
| (15,2) | bed_green_right | Green bed facing right |
| (16,2) | carpet_red_vertical | |
| (17,2) | carpet_blue_vertical | |
| (18,2) | carpet_green_vertical | |
| (19,2) | table_round | |

### Row 3 — Cauldrons, Stone Tables, Fence, Carpets, Bench
| Coord | Name | Notes |
|-------|------|-------|
| (0,3) | cauldron | Open |
| (1,3) | cauldron_closed | Lidded |
| (2,3) | cauldron_cracked | Damaged |
| (3,3) | cauldron_broken | |
| (4,3) | cauldron_broken_alt | |
| (5,3) | stone_table | |
| (6,3) | stone_table_Cracked | |
| (7,3) | stone_table_broken | |
| (9,3) | fence_vertical | |
| (11,3) | stone_plate | |
| (12,3) | carpet_red_horizontal | |
| (13,3) | carpet_blue_horizontal | |
| (14,3) | carpet_green_horizontal | |
| (15,3) | carpet_red_connector | |
| (16,3) | carpet_blue_connector | |
| (17,3) | carpet_green_connector | |
| (18,3) | bench | |

### Row 4 — Debris
| Coord | Name |
|-------|------|
| (0,4)-(11,4) | debris1-8, pebbles, debris_small |

### Row 5 — Moss, Cage, Bucket
| Coord | Name |
|-------|------|
| (0,5)-(11,5) | moss1-12 |
| (12,5) | cage |
| (13,5) | bucket |

### Row 6 — Skulls, Bones, Blood, Furnace, Water Trough, Throne, Chopping Block
| Coord | Name | Notes |
|-------|------|-------|
| (0,6) | skull_2 | |
| (1,6) | skull_1 | |
| (2,6)-(8,6) | bones_7 to bones_1 | |
| (9,6) | skull_3 | |
| (10,6) | blood_small2 | |
| (11,6) | blood_drops2 | |
| (12,6) | blood_small | |
| (13,6) | blood_drops | |
| (14,6) | blood_medium | |
| (15,6) | blood_large | |
| (16,6) | **furnace** | Industrial — blacksmith |
| (17,6) | **water_trough** | Industrial — blacksmith |
| (18,6) | **throne** | Royal seat |
| (19,6) | **head_Chopping_block** | Execution — torture |

### Row 7 — Displays, Chests, Crafting, Traps
| Coord | Name | Notes |
|-------|------|-------|
| (0,7) | candle_stand | Tall candle |
| (1,7) | **potion_cabinet** | Potion rack/shelf |
| (2,7) | ladder | Against wall |
| (3,7) | **armor_display** | Armor stand |
| (4,7) | **weapon_display** | Weapon wall mount |
| (5,7) | chest_open_gold | Treasure |
| (6,7) | chest_open_silver | Treasure |
| (7,7) | chest_open_bronze | Treasure |
| (8,7) | enclosed_bug_enviroment | Terrarium/jar |
| (9,7) | book_stand | Lectern |
| (10,7) | large_chest_closed | Big chest |
| (11,7) | **advanced_weapon_rack** | Fancy rack |
| (12,7) | floor_candle | |
| (13,7) | floor_candle_flicker | Animated |
| (14,7) | **anvil** | Blacksmith |
| (15,7) | lever_right | Mechanism |
| (16,7) | lever_left | Mechanism |
| (17,7) | **training_dummy** | Practice target |
| (18,7) | **blood_altar** | Ritual sacrifice |
| (19,7) | closed_chest | |

### Row 8 — Traps, Explosives, Braziers, Portals
| Coord | Name | Notes |
|-------|------|-------|
| (0,8) | trap_base_horizontal | Track piece |
| (1,8) | trap_base_vertical | Track piece |
| (2,8) | trap_base_connector | Corner/junction |
| (3,8) | saw_blade_trap | Moves on tracks |
| (4,8) | electric_trap_pulse | Moves on tracks |
| (5,8) | electric_trap | Static |
| (6,8) | explosive_barrel | Shootable, chain-explodes |
| (7,8) | acid_trap | |
| (8,8) | flame_trap | |
| (9,8) | bell | |
| (10,8) | brazier | |
| (11,8) | brazier_flicker | Animated |
| (12,8) | repeating_chain_fence | |
| (13,8) | blue_portal | |
| (14,8) | green_portal | |
| (15,8) | blue_power_generator | |
| (17,8) | golden_statue | |

---

## Design Philosophy

**Every cluster tells a story.** A blacksmith has a furnace, anvil, water trough. A chapel has pews facing an altar. A prison has iron grates, benches as cots, cages. Don't scatter items randomly — think about what this area IS.

---

## Carpet Rules

1. **Sections, not full coverage.** 3-5 bounded rectangles, ~40% floor. Bare stone between (2+ rows).
2. **Match orientation to shape:** Wide → horizontal, Tall → vertical, Junction → connector.
3. **Any color.** Mix colors between sections for variety.
4. **Carpet on FLOOR LAYER (source 1).** Furniture on DECO LAYER (source 1).

---

## Themed Blueprint Catalog

### THRONE ROOM
- throne (18,6) centered, 1-2 from north wall
- candle_stands (0,7) flanking
- gold (11,1)(12,1)(13,1) scattered in front
- armor_display (3,7) + weapon_display (4,7) on north wall
- golden_statue (17,8) flanking throne

### CHAPEL
- Pew rows: chair_left (1,2) + table (3,2) + chair_right (0,2) repeated
- altar (1,1) as focal point
- bookshelf (4,2) nearby, book_stand (9,7) as lectern
- candle_stands (0,7), braziers at corners

### BLACKSMITH
- furnace (16,6) + anvil (14,7) + water_trough (17,6) grouped
- barrel (0,0) + barrel_cluster (2,0)(3,0) for materials
- weapon_rack (7,0) / weapon_rack_left (8,0) / weapon_rack_right (9,0) for output
- training_dummy (17,7) nearby

### PRISON BLOCK
- Iron_Grate (0,1) as cell dividers
- bench (18,3) as cots
- beds (10-15, 2) — red/blue/green, left/right facing
- cage (12,5) in corners
- bucket (13,5) for prisoners
- blood + skull scatter

### ALCHEMIST LAB
- cauldron (0,3) + cauldron_closed (1,3) as brewing stations
- potion_cabinet (1,7) as potion shelves
- book_stand (9,7) for recipes
- bookshelf (4,2)(5,2)(6,2) for reference
- explosive_barrel (6,8) for volatile materials

### EXECUTION / TORTURE
- head_Chopping_block (19,6) with blood around it
- blood_altar (18,7) for ritual sacrifice
- flame_trap (8,8) as heating
- cage (12,5) for prisoners
- skull/bones scatter heavy

### WAR ROOM
- table (3,2) or table_round (19,2) as war table, chairs around
- weapon_display (4,7) + armor_display (3,7) on walls
- advanced_weapon_rack (11,7) for armory
- lever_right/left (15,7)(16,7) for mechanisms
- training_dummy (17,7)

### TREASURE VAULT
- gold (11,1), gold_large (12,1), gold_very_large (13,1)
- chest_open_gold/silver/bronze (5,7)(6,7)(7,7)
- large_chest_closed (10,7), closed_chest (19,7)
- stone_table (5,3) as display pedestals

---

## Collideable vs Non-Collideable

`SOLID_DECO_ROWS = [0, 1, 2, 3]` — rows 0-3 generate collision.
Exception: `WALKABLE_DECO_OVERRIDES` (carpets, trap tracks) skip collision.

---

## What NOT to Do

- Don't scatter items without a theme reason
- Don't use wrong sprite names — ALWAYS check the tileset .tres
- Don't cover entire floor with carpet
- Don't put industrial items on carpet — bare stone for workshops
- Don't block entrance corridor
