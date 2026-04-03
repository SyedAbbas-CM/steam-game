# Enemy Attack Pattern Reference

Complete guide to creating enemies with the AttackType system. Every attack is configured through EnemyDefinition .tres files — no code changes needed for new enemies.

## Quick Start: Creating an Enemy

```tres
[gd_resource type="Resource" script_class="EnemyDefinition" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/enemies/enemy_definition.gd" id="1"]

[resource]
script = ExtResource("1")
enemy_name = "My Enemy"
max_hp = 5
move_speed = 15.0
contact_damage = 1
kingdom = "demon"           # undead, orc, crawler, animal, demon, human, magical, mecha
attack_type = 2             # See attack type numbers below
attack_damage = 2
attack_speed = 2.0          # Seconds between attacks (cooldown)
bullet_speed = 70.0
bullet_count = 3
use_loy_sprite = true
loy_tile_index = 102        # LoY chars.png sprite index
sprite_color = Color(1, 1, 1, 1)
xp_value = 5
score_value = 30
```

## Core Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `attack_type` | int | 2 (RANGED) | Primary attack pattern (see table below) |
| `attack_damage` | int | 1 | Base damage per bullet/hit |
| `attack_speed` | float | 1.5 | Seconds between attacks |
| `bullet_speed` | float | 80.0 | Bullet travel speed (px/s) |
| `bullet_count` | int | 1 | Bullets per volley (many attacks use this to scale) |
| `preferred_distance` | float | 0.0 | Distance enemy tries to maintain from player (0=melee) |
| `kingdom` | String | "unknown" | Determines bullet color (see kingdoms) |
| `bullet_sprite_index` | int | -1 | Override bullet sprite (-1 = kingdom default) |

## Attack Types (by number)

### Basic Attacks (0-9)

| # | Name | Description | Key Params |
|---|------|-------------|------------|
| 0 | NONE | Fires single bullets (fallback) | bullet_speed, bullet_count |
| 1 | MELEE | Lunge + shoot. Short charge toward player | charge_speed, charge_duration |
| 2 | RANGED | Standard aimed bullets at player | bullet_speed, bullet_count |
| 3 | BURST | Ring of bullets expanding outward | bullet_count (min 4 → 8) |
| 4 | CHARGE | Dash toward player then attack | charge_speed, charge_duration |
| 5 | DASH | Short dodge movement | charge_speed |
| 6 | SUMMON | Spawn minions + ring burst | summon_count, summon_definition |
| 7 | SLAM | Ground slam AoE + ring burst | slam_radius |
| 8 | TELEPORT | Blink to new position + single shot | teleport_cooldown |
| 9 | HEAL | Restore HP to self/nearby allies | heal_amount, heal_range |

**Tips**: MELEE is great for aggressive monsters. Set `preferred_distance = 0` and high `move_speed`. BURST is the classic "bullet hell" ring — scale `bullet_count` for difficulty (8=easy, 16=hard).

### Special Status Attacks (10-15)

| # | Name | Description | Key Params |
|---|------|-------------|------------|
| 10 | SPLIT | Spawns smaller copies on death | split_count, split_definition |
| 11 | STEALTH | Turns invisible, fires from stealth | stealth_duration |
| 12 | SHIELD | Frontal barrier arc that blocks bullets | shield_hp |
| 13 | BEAM | Rotating laser beam + single shots | beam_duration, beam_sweep_speed |
| 14 | SPIRAL | 5 rapid rotating volleys | bullet_count (min 4) |
| 15 | POISON_SHOT | Bullets inflict POISONED status | poison_chance (0-1) |

**Tips**: SPLIT needs a `split_definition` pointing to a smaller enemy .tres. BEAM is devastating — set `beam_sweep_speed` to control difficulty (1.0=slow, 3.0=fast sweep). SPIRAL creates beautiful bullet curtains.

### Spread/Ring Patterns (16-22)

| # | Name | Description | Key Params |
|---|------|-------------|------------|
| 16 | VOLLEY | Lobbed bombs scattered around player | bullet_count (3-6), bomb_aoe_radius |
| 17 | CROSS_SHOT | + pattern then delayed X pattern | bullet_speed |
| 18 | WAVE_SHOT | Sine-wave spread of bullets | bullet_count (min 5) |
| 19 | GATLING | Long machine gun burst, tracks player | bullet_count (+4 extra), bullet_speed * 1.3 |
| 20 | MORTAR | High-arc bombs with bullet rings on impact | bullet_count (2-4 bombs, 8 ring bullets) |
| 21 | NOVA | Double ring: inner fast + outer slow delayed | bullet_count |
| 22 | ZIGZAG | Chaotic erratic movement pattern | move_speed, charge_speed |

**Tips**: GATLING is great for machine-gun enemies — set high `bullet_count` (8-12) and high `bullet_speed`. NOVA creates a safe-then-dangerous zone. CROSS_SHOT fires 16 total bullets in two waves.

### Complex Patterns (23-28)

| # | Name | Description | Key Params |
|---|------|-------------|------------|
| 23 | SHOTGUN_BLAST | Tight spread burst at player | bullet_count, bullet_speed |
| 24 | HELIX | Spiraling double helix pattern | bullet_count (min 4) |
| 25 | METEOR_SHOWER | High-arc falling bombs around player | bullet_count (3-5 meteors) |
| 26 | BOOMERANG_SHOT | Bullets arc out then return to enemy | bullet_count, bullet_speed |
| 27 | STRAFE_RUN | Charge perpendicular while shooting | charge_speed, charge_duration |
| 28 | MINEFIELD | Deploy stationary mines in pattern | bullet_count (3-5 mines) |

**Tips**: SHOTGUN_BLAST is deadly up close — pair with `preferred_distance = 20`. BOOMERANG_SHOT creates cool returning bullet arcs. STRAFE_RUN makes enemies feel tactical.

### Advanced Targeting (29-36)

| # | Name | Description | Key Params |
|---|------|-------------|------------|
| 29 | RETURNING_VOLLEY | Bullets that boomerang back through target | bullet_count |
| 30 | SEEKING_MINES | Very slow homing bullets toward player | bullet_count (2-3), lifetime=8s |
| 31 | DETONATOR | Bullets decelerate then explode into sub-bullets | bullet_count (min 3) |
| 32 | SPLITTER | Bullets split halfway to target (3-5 fragments) | bullet_count (min 2) |
| 33 | SINE_BARRAGE | Oscillating sine-wave bullets, hard to dodge | bullet_count (min 4) |
| 34 | HOMING_SALVO | Missiles that home toward player | bullet_count (min 3) |
| 35 | TELEGRAPH_EXPLOSION | Warning circle → delayed ring explosion | bullet_speed * 0.8 for ring |
| 36 | ORBIT_LAUNCH | Bullets orbit enemy then launch at player | bullet_count |

**Tips**: DETONATOR + SPLITTER are great for higher-level enemies — they create cascading bullet patterns. HOMING_SALVO is dangerous, keep `bullet_count` low (3-4). TELEGRAPH_EXPLOSION is fair and readable.

### Wall/Area Interactions (37-41)

| # | Name | Description | Key Params |
|---|------|-------------|------------|
| 37 | WALL_BOUNCE | Bullets reflect off walls N times | bounce_count |
| 38 | LASER_GRID | Grid of laser beams | beam_duration |
| 39 | GRAVITY_WELL | Pull player toward a center point | bullet_speed |
| 40 | CHAIN_LIGHTNING | Lightning chains between targets | bullet_count |
| 41 | DEATH_SPIRAL | Same as SPIRAL but typically used on death | (same as SPIRAL) |

**Tips**: WALL_BOUNCE is great in tight corridors. Set `bounce_count = 3-5`. GRAVITY_WELL combos well with other attacks.

### Bomb Attacks (42-46) — Lobbed over walls, AOE on landing

| # | Name | Description | Key Params |
|---|------|-------------|------------|
| 42 | BOMB_TOSS | Single bomb at player position | bomb_aoe_radius, bomb_flight_time |
| 43 | CARPET_BOMB | 3-5 bombs in line toward player | bomb_aoe_radius * 0.9 |
| 44 | FIRE_RAIN | 2-4 bombs scattered around player | bomb_aoe_radius * 0.7 |
| 45 | CLUSTER_BOMB | One big bomb → 4 sub-bombs on impact | bomb_aoe_radius |
| 46 | MINE_DROP | 2-3 short-range lobs near self with bullet rings | 6 ring bullets each |

**Bomb tuning**: `bomb_aoe_radius` (default 16) controls explosion size. `bomb_flight_time` (default 0.8) controls how slow the arc is — internally multiplied by 3x. All bombs deal 2x base `attack_damage`. Bombs have full `attack_speed` cooldown (not 0.25x like bullet attacks). **Bombs fire over walls** — no LOS needed.

### Control Attacks (47-49)

| # | Name | Description | Key Params |
|---|------|-------------|------------|
| 47 | BARRIER_WALL | Stationary barrier that blocks player bullets | shield_hp (barrier HP) |
| 48 | PULL_SHOT | Slow orb that pulls player toward it | bullet_speed * 0.1 |
| 49 | PUSH_WAVE | Slow orbs that push player away | bullet_speed * 0.1 |

### New Pattern Attacks (50-55)

| # | Name | Description | Key Params |
|---|------|-------------|------------|
| 50 | VORTEX | Swirling homing bullets spawned in a wide circle | bullet_count (min 6), bullet_speed * 0.5 |
| 51 | RING_PULSE | 3 timed expanding rings with dodge gaps | bullet_count (min 6), bullet_speed * 0.7 |
| 52 | ARTILLERY | Single massive bomb: huge AOE + 8-bullet ring | bomb_aoe_radius * 1.5, 3x damage |
| 53 | WHIP_LASH | Fast sweeping 108-degree arc of bullets | bullet_count (min 8), bullet_speed * 1.1 |
| 54 | POISON_CLOUD | Lobbed bomb → lingering poison zone (4s) | bomb_aoe_radius * 1.2, 1.5x damage |
| 55 | DASH_STRIKE | Dash at player, sprays bullets behind | bullet_count (min 4), charge_speed |

**Tips**: VORTEX looks amazing — the bullets spawn in a circle then swirl inward. RING_PULSE has gaps to dodge through, so it's fair but scary. ARTILLERY is a boss move — one huge bomb. WHIP_LASH fires bullets in a quick sweeping arc like a whip crack. POISON_CLOUD is area denial — forces player to move. DASH_STRIKE makes aggressive melee enemies that leave danger zones behind.

## Boss Phase System

Any enemy can have up to 3 phases:

```tres
boss_phases = 3
phase_2_attack = 14       # SPIRAL at <66% HP
phase_3_attack = 3        # BURST at <33% HP
phase_2_bullet_count = 12
phase_3_bullet_count = 16
```

- **Phase 1**: Uses `attack_type` normally
- **Phase 2** (<66% HP): Switches to `phase_2_attack`, gains `phase_2_bullet_count`
- **Phase 3** (<33% HP): Switches to `phase_3_attack`, gains `phase_3_bullet_count`

Bosses (size_class=2) fire **combo attacks** — multiple pool attacks simultaneously in phases 2+. Elites (size_class=1) fire 2 attacks at once in phase 2+.

## Size Classes

| Value | Name | Effects |
|-------|------|---------|
| 0 | NORMAL | Standard enemy |
| 1 | LARGE | Auto-scaled larger, elite behavior, bigger bomb arcs |
| 2 | BOSS | Largest, combo attacks in phase 2+, biggest bomb arcs |

## Kingdom Bullet Colors

| Kingdom | Sprite Index | Color |
|---------|-------------|-------|
| undead | 208 | Dark shadow |
| orc | 144 | Red fireball |
| demon | 192 | Purple/pink |
| animal | 149 | Orange |
| magical | 176 | Blue magic |
| human | 128 | White arrow |
| crawler | 161 | Green venom |
| mecha | 131 | Grey bolt |

Override with `bullet_sprite_index` for custom bullet visuals. See `ObjSpriteIndex` for all 256 sprite indices.

## Death Patterns

Set `death_bullet_pattern` to fire a pattern when the enemy dies:

```tres
death_bullet_pattern = 3   # BURST ring on death
explodes_on_death = true
explode_radius = 20.0
```

## Trail Types

```tres
leaves_trail = true
trail_type = "fire"    # "fire", "web", "poison"
```

## Combo Recipes: Example Enemies

### "Glass Cannon Mage" — High damage, fragile
```
attack_type = 14 (SPIRAL), attack_damage = 3, bullet_count = 6
max_hp = 3, move_speed = 8, preferred_distance = 60
```

### "Tank Boss" — Armored, multi-phase
```
attack_type = 12 (SHIELD), size_class = 2
boss_phases = 3, phase_2_attack = 51 (RING_PULSE), phase_3_attack = 52 (ARTILLERY)
armor = 4, shield_hp = 10, max_hp = 30
```

### "Assassin" — Stealth + dash strike
```
attack_type = 55 (DASH_STRIKE), stealth_duration = 3.0
move_speed = 25, charge_speed = 120, preferred_distance = 30
```

### "Area Denial Caster" — Poison clouds + mines
```
attack_type = 54 (POISON_CLOUD), bomb_aoe_radius = 18
boss_phases = 2, phase_2_attack = 28 (MINEFIELD)
preferred_distance = 70, move_speed = 10
```

### "Bullet Hell Boss" — Multiple cascading patterns
```
attack_type = 50 (VORTEX), size_class = 2
boss_phases = 3, phase_2_attack = 14 (SPIRAL), phase_3_attack = 21 (NOVA)
bullet_count = 12, max_hp = 30, explodes_on_death = true
death_bullet_pattern = 3
```

## File Locations

- Enemy definitions: `resources/enemies/` (organized by biome/category)
- Attack implementation: `scripts/enemy.gd` (lines 1100-2700)
- Bullet behaviors: `scripts/bullet.gd`
- Sprite indices: `scripts/data/obj_sprite_index.gd`
- LoY sprite sheets: `assets/sprites/loy/chars.png` (32x32 tiles)
