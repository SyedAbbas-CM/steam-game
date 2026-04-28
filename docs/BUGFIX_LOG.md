# Bugfix Log

## 2026-04-22

### 1. T1 Weapon Damage Regression — FIXED
**Problem:** Longsword and Composite Bow did 1 damage (same as T0 starter weapons). They were misclassified as rarity=0 instead of rarity=1, so the rebalance script set them to T0 damage.

**Fix:** `resources/items/loy/longsword.tres` and `composite_bow.tres` — changed rarity 0→1, flat_bonus 1→3.

**Note:** There may be other items with wrong rarity. High-price T0 weapons flagged for future review.

---

### 2. Merchant Double-Interaction — FIXED
**Problem:** Pressing E while shop UI was open re-triggered NPC dialogue and could stack another shop menu. ShopUI didn't consume the interact input, so it bubbled through to NPC._unhandled_input().

**Fix:** `scripts/ui/shop_ui.gd` _input() — added `interact` action handler that closes shop and calls `set_input_as_handled()`, matching how DialogueUI blocks E input.

---

### 3. Ravenholme Skeleton Spawning — FIXED
**Problem:** Three issues with quest enemy respawning:
- `alive < 3` threshold caused respawns even when skeletons were still alive
- Batch cap of 10 per zone entry caused repeated 10-skeleton waves
- No guard against missing spawn commands (defaulted to 10)

**Fix:** `scripts/overworld/overworld.gd` check_quest_enemy_spawns():
- Changed `alive < 3` → `alive > 0: continue` — only respawn when ALL are dead
- Removed batch cap of 10 — spawns all remaining at once
- Added `spawn_cmd.size() == 0: continue` — skips if spawn command not found instead of defaulting to 10
- Result: skeletons spawn once when quest starts, respawn all remaining only if every last one is killed

---

### 4. Skeleton Quest Spawning in Wrong Area — FIXED
**Problem:** Q1 "Them Bones" spawned skeletons in haven zone (Aria town area) instead of the Barrows graveyard.

**Fix:** `resources/quests/q1.tres` — changed spawn zone from "haven" to "barrows", updated spawn area to cover the Barrows zone (2,3,16,22), added `target_location = "barrows"` for quest marker.

---

### 5. Quest Kill Counter Not Counting All Enemies — FIXED
**Problem:** Q14 "Jimbob's Pickaxe" only counted kills of 5 specific undead types (Skeleton, Ghost, Ghoul, Skeleton Archer, Zombie), but haven dungeons spawn different enemies (Risen Corpse, Bone Charger, Shield Skeleton, etc.). Killed 3 enemies but only matching types counted.

**Fix:**
- `scripts/quests/quest_manager.gd` — added wildcard `"*"` support in `on_enemy_killed()` kill event matching
- `resources/quests/q14.tres` — replaced 5 specific kill events with single `param: "*"` wildcard that counts any enemy kill

---

### 6. Explosive Barrel take_damage Type Error — FIXED
**Problem:** Barrel explosion called `enemy.take_damage(dmg, Vector2.ZERO)` but signature expects `(int, bool)`. Error: "Cannot convert argument 2 from Vector2 to bool."

**Fix:** `scripts/dungeon/traps/explosive_barrel.gd` — changed `Vector2.ZERO` to `false` (environmental damage, not from player).

---

### 7. Scarecrow Quest Spawn Area + Strength — FIXED
**Problem:** Scarecrows from mq01 could spawn in haven (Ravenholme) instead of duskfarm because `check_quest_enemy_spawns` matched quests by location OR target_location but spawned in the current zone.

**Fix:**
- `scripts/overworld/overworld.gd` — respawn logic now reads the spawn zone from the quest's `spawnEnemies` command and only spawns if it matches the current zone
- `resources/enemies/basic/scarecrow.tres` — buffed: HP 18→40, attack_damage 3→5, attack_type STEALTH→MELEE, bullet_count 1→3, attack_speed 2.0→1.2, move_speed 22→28, added charge ability

---

### 8. Quest Marker Disappearing/Pointing Wrong — FIXED
**Problem:** Quest arrow disappeared or pointed elsewhere when entering target zone. Two issues:
- Kill events for quest-spawned enemies (not in natural zone spawns) returned Vector2.ZERO
- `zone_enter` event type wasn't checked for position resolution (only `quest` type was)

**Fix:** `scripts/quests/quest_manager.gd` `get_quest_objective_position()`:
- Added fallback: searches quest's `spawnEnemies` command for the spawn zone when enemy isn't in `_enemy_zone_map`
- Added `zone_enter` to the event type check alongside `quest` for zone-based arrow targeting
- Added `_find_spawn_zone()` helper to recursively find spawn zone from quest script tree

---

### 9. Scarecrow Quest Count + Mini-Boss Upgrade — FIXED
**Problem:** mq01 only spawned 5 scarecrows with kill target of 3. Scarecrows were too easy (NORMAL size_class).

**Fix:**
- `resources/quests/mq01.tres` — spawn count 5→10, kill target 3→10, updated all dialogue text
- `resources/enemies/basic/scarecrow.tres` — size_class NORMAL→LARGE (mini-boss), HP 40→60, attack_damage 5→6, bullet_count 3→4, attack_speed 1.2→1.0, boss_phases=2, phase_2 = SLAM, xp 10→25

---

### 10. Boss Kill Event Never Firing (Tablet Quest) — FIXED
**Problem:** mq02 "What the Dead Left Behind" used `boss_killed` event type for the Bone Golem, but `enemy.gd _die()` never called `qm.on_boss_killed()`. The tablet could never drop.

**Fix:**
- `scripts/enemy.gd` `_die()` — added `qm.on_boss_killed(kill_name)` call for BOSS size_class enemies
- `scripts/quests/quest_manager.gd` — implemented `get_quest_boss_override(biome_name)` so mq02 forces a Bone Golem as the dungeon boss
- `resources/quests/mq02.tres` — added `boss_dungeon = "aria"`, `boss_enemy_path = "res://resources/enemies/basic/bone_golem.tres"`, replaced 3 specific kill events with wildcard `"*"`
- `resources/enemies/basic/bone_golem.tres` — buffed to proper boss: HP 60→180, attack_damage 3→5, armor 1→3, bullet_count 1→3, boss_phases=2, summons minions on phase change

---

### 11. HP Regen Too Strong on Bosses — FIXED
**Problem:** Both LARGE (elites) and BOSS enemies had identical HP regen: 1% max HP per second after 3s without damage. Bosses with high HP (130+ Ghast) were nearly unkillable for early players.

**Fix:** `scripts/enemy.gd` — differentiated regen by size class:
- LARGE (elites): 1% max HP per 2s, 4s no-damage delay (slight nerf from 3s)
- BOSS: 1% max HP per 3s, 5s no-damage delay (significant nerf — 3x slower regen)

---

### 4. Skeleton Quest Spawning in Wrong Area — FIXED
**Problem:** Q1 "Them Bones" spawned skeletons in haven zone (Aria town area) instead of the Barrows graveyard.

**Fix:** `resources/quests/q1.tres` — changed spawn zone from "haven" to "barrows", updated spawn area to cover the Barrows zone (2,3,16,22), added `target_location = "barrows"` for quest marker.

---

### 5. Quest Kill Counter Not Counting All Enemies — FIXED
**Problem:** Q14 "Jimbob's Pickaxe" only counted kills of 5 specific undead types (Skeleton, Ghost, Ghoul, Skeleton Archer, Zombie), but haven dungeons spawn different enemies (Risen Corpse, Bone Charger, Shield Skeleton, etc.). Killed 3 enemies but only matching types counted.

**Fix:**
- `scripts/quests/quest_manager.gd` — added wildcard `"*"` support in `on_enemy_killed()` kill event matching
- `resources/quests/q14.tres` — replaced 5 specific kill events with single `param: "*"` wildcard that counts any enemy kill

---

### 6. Explosive Barrel take_damage Type Error — FIXED
**Problem:** Barrel explosion called `enemy.take_damage(dmg, Vector2.ZERO)` but signature expects `(int, bool)`. Error: "Cannot convert argument 2 from Vector2 to bool."

**Fix:** `scripts/dungeon/traps/explosive_barrel.gd` — changed `Vector2.ZERO` to `false` (environmental damage, not from player).

---

### 7. Scarecrow Quest Spawn Area + Strength — FIXED
**Problem:** Scarecrows from mq01 could spawn in haven (Ravenholme) instead of duskfarm because `check_quest_enemy_spawns` matched quests by location OR target_location but spawned in the current zone.

**Fix:**
- `scripts/overworld/overworld.gd` — respawn logic now reads the spawn zone from the quest's `spawnEnemies` command and only spawns if it matches the current zone
- `resources/enemies/basic/scarecrow.tres` — buffed: HP 18→40, attack_damage 3→5, attack_type STEALTH→MELEE, bullet_count 1→3, attack_speed 2.0→1.2, move_speed 22→28, added charge ability

---

### 8. Quest Marker Disappearing/Pointing Wrong — FIXED
**Problem:** Quest arrow disappeared or pointed elsewhere when entering target zone. Two issues:
- Kill events for quest-spawned enemies (not in natural zone spawns) returned Vector2.ZERO
- `zone_enter` event type wasn't checked for position resolution (only `quest` type was)

**Fix:** `scripts/quests/quest_manager.gd` `get_quest_objective_position()`:
- Added fallback: searches quest's `spawnEnemies` command for the spawn zone when enemy isn't in `_enemy_zone_map`
- Added `zone_enter` to the event type check alongside `quest` for zone-based arrow targeting
- Added `_find_spawn_zone()` helper to recursively find spawn zone from quest script tree

---

### 9. Scarecrow Quest Count + Mini-Boss Upgrade — FIXED
**Problem:** mq01 only spawned 5 scarecrows with kill target of 3. Scarecrows were too easy (NORMAL size_class).

**Fix:**
- `resources/quests/mq01.tres` — spawn count 5→10, kill target 3→10, updated all dialogue text
- `resources/enemies/basic/scarecrow.tres` — size_class NORMAL→LARGE (mini-boss), HP 40→60, attack_damage 5→6, bullet_count 3→4, attack_speed 1.2→1.0, boss_phases=2, phase_2 = SLAM, xp 10→25

---

### 10. Boss Kill Event Never Firing (Tablet Quest) — FIXED
**Problem:** mq02 "What the Dead Left Behind" used `boss_killed` event type for the Bone Golem, but `enemy.gd _die()` never called `qm.on_boss_killed()`. The tablet could never drop.

**Fix:**
- `scripts/enemy.gd` `_die()` — added `qm.on_boss_killed(kill_name)` call for BOSS size_class enemies
- `scripts/quests/quest_manager.gd` — implemented `get_quest_boss_override(biome_name)` so mq02 forces a Bone Golem as the dungeon boss
- `resources/quests/mq02.tres` — added `boss_dungeon = "aria"`, `boss_enemy_path = "res://resources/enemies/basic/bone_golem.tres"`, replaced 3 specific kill events with wildcard `"*"`
- `resources/enemies/basic/bone_golem.tres` — buffed to proper boss: HP 60→180, attack_damage 3→5, armor 1→3, bullet_count 1→3, boss_phases=2, summons minions on phase change

---

### 11. HP Regen Too Strong on Bosses — FIXED
**Problem:** Both LARGE (elites) and BOSS enemies had identical HP regen: 1% max HP per second after 3s without damage. Bosses with high HP (130+ Ghast) were nearly unkillable for early players.

**Fix:** `scripts/enemy.gd` — differentiated regen by size class:
- LARGE (elites): 1% max HP per 2s, 4s no-damage delay (slight nerf from 3s)
- BOSS: 1% max HP per 3s, 5s no-damage delay (significant nerf — 3x slower regen)
