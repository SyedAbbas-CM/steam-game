# Attack Types Reference

Every enemy has `attack_type` (enum int) + these shared stats that ALL attacks read:
- `bullet_speed` — base projectile speed (most attacks multiply this)
- `bullet_count` — base count (most attacks clamp with a minimum)
- `attack_damage` — damage per hit
- `attack_speed` — seconds between attacks (lower = faster)
- `preferred_distance` — how far the enemy tries to stay from player
- `aggro_range` — detection range

---

## BASIC ATTACKS (0-5)

### NONE (0) — Fallback
Fires single bullet at player. Same as RANGED.

### MELEE (1) — Lunge + Hit
Fires bullet(s) then lunges forward briefly.
| Param | Used As |
|-------|---------|
| bullet_count | Number of bullets in spread |
| bullet_speed | Bullet velocity |
| Hardcoded | spread=0.3 rad, lunge duration=0.2s |

### RANGED (2) — Basic Shooter
Fires bullet_count bullets in a tight spread at player.
| Param | Used As |
|-------|---------|
| bullet_count | 1=single shot, 2+=spread |
| bullet_speed | Bullet velocity |
| Hardcoded | spread=0.3 rad |

### BURST (3) — Ring Burst
Fires a full ring of bullets centered on player direction.
| Param | Used As |
|-------|---------|
| bullet_count | Ring bullet count (min 8) |
| bullet_speed | Bullet velocity |

### CHARGE (4) — Bull Rush
Charges at player at charge_speed for charge_duration, deals contact_damage.
| Param | Used As |
|-------|---------|
| charge_speed | Charge velocity (default 80) |
| charge_duration | Charge time (default 0.3s) |

### DASH (5) — Quick Dash
Same as RANGED but enemy dashes during attack phase.
| Param | Used As |
|-------|---------|
| bullet_count, bullet_speed | Same as RANGED |

---

## SPECIAL ABILITIES (6-15)

### SUMMON (6) — Spawn Minions
Summons minions in a circle + fires ring burst.
| Param | Used As |
|-------|---------|
| summon_count | Number of minions (default 2) |
| summon_definition | EnemyDefinition for minions (auto-creates weak melee if null) |
| bullet_count | Ring burst count |
| Hardcoded | spawn distance=16px |

### SLAM (7) — Ground Pound
AoE damage + ring burst. Direct damage in radius.
| Param | Used As |
|-------|---------|
| slam_radius | AoE radius (default 24) |
| attack_damage | Direct damage in radius |
| bullet_count | Ring burst count |

### TELEPORT (8) — Blink Strike
Teleports 20-40px from player, then shoots.
| Param | Used As |
|-------|---------|
| teleport_cooldown | Seconds between teleports (default 3.0) |
| Hardcoded | teleport range=20-40px from player |

### HEAL (9) — Support Healer
Heals nearby allies + shoots at player.
| Param | Used As |
|-------|---------|
| heal_amount | HP restored (default 2) |
| heal_range | Heal search radius (default 48) |
| bullet_count, bullet_speed | Also shoots single at player |

### SPLIT (10) — Splits on Death
Normal ranged attack while alive. On death, splits into smaller copies.
| Param | Used As |
|-------|---------|
| split_count | Number of splits (default 2) |
| split_definition | EnemyDefinition for split copies (auto-creates melee shard if null) |

### STEALTH (11) — Invisible Ambusher
Goes invisible, reappears to attack.
| Param | Used As |
|-------|---------|
| stealth_duration | Invisibility time (default 2.0s) |
| Hardcoded | alpha=0.15 while stealthed |

### SHIELD (12) — Shield Bearer
Spawns frontal barrier arc, shoots through it, then charges.
| Param | Used As |
|-------|---------|
| shield_hp | Barrier segment HP (default 3) — also absorbs damage while >0 |
| bullet_count, bullet_speed | Through-shield shots |
| Hardcoded | 3 barrier segments, spacing=7px, lifetime=3s, charge=0.25s |

### BEAM (13) — Sweeping Laser
Fires a continuous beam that sweeps across the area.
| Param | Used As |
|-------|---------|
| beam_duration | How long the beam lasts (default 1.0s) |
| beam_sweep_speed | Sweep rotation speed (default 1.5 rad/s) — NOTE: currently unused, should wire in |
| bullet_count, bullet_speed | Also fires bullets during beam |

### SPIRAL (14) — Spiral Stream
Fires 5 rapid volleys of rotating bullet rings. Continuous feel.
| Param | Used As |
|-------|---------|
| bullet_count | Bullets per ring (min 4) |
| bullet_speed | Bullet velocity |
| Hardcoded | 5 volleys, 0.12s spacing, rotation=0.35 rad/volley |

### POISON_SHOT (15) — Toxic Shooter
Same as RANGED but bullets apply POISONED status on hit.
| Param | Used As |
|-------|---------|
| poison_chance | 0.0-1.0, chance each bullet is poisonous |
| bullet_count, bullet_speed | Same as RANGED |
| Hardcoded | poison duration=4s, green sprite (161) |

---

## PROJECTILE PATTERNS (16-30)

### VOLLEY (16) — Lobbed Bomb Spread
Lobs small bombs in a ring pattern around the player.
| Param | Used As |
|-------|---------|
| bullet_count | Bomb count (clamped 3-6) |
| bomb_aoe_radius | Explosion radius per bomb (used, default 8) |
| bomb_flight_time | Flight time per bomb (used, default 0.5) |
| Hardcoded | offset=8-18px from player, delay=0.1s, ring_count=4 |

### CROSS_SHOT (17) — Double Cross
Fires + pattern (cardinal) then delayed X pattern (diagonal).
| Param | Used As |
|-------|---------|
| bullet_speed | Bullet velocity (inner at 1.0x/0.6x, outer at 0.9x/0.5x) |
| Hardcoded | 4 arms each cross, delay=0.3s between crosses |

### WAVE_SHOT (18) — Sine Wave Fan
Bullets fan out in a wave pattern, offset perpendicular to aim.
| Param | Used As |
|-------|---------|
| bullet_count | Wave count (min 5) |
| bullet_speed | Bullet velocity |
| Hardcoded | wave amplitude=8px, wave frequency=TAU |

### GATLING (19) — Machine Gun
Long burst of fast bullets that track the player between shots.
| Param | Used As |
|-------|---------|
| bullet_count | Burst length (min 8, +4 extra) |
| bullet_speed | Base speed (x1.3 multiplier) |
| Hardcoded | delay=0.05s/shot, jitter=0.08 rad, re-aims each shot |

### MORTAR (20) — Artillery Barrage
Lobs bombs toward player with staggered timing.
| Param | Used As |
|-------|---------|
| bullet_count | Bomb count (clamped 2-4) |
| bomb_aoe_radius | Explosion radius (default 12) |
| bomb_flight_time | Flight time (x1.5 multiplier) |
| Hardcoded | delay=0.3s/bomb, offset=20px, ring_count=8 |

### NOVA (21) — Double Ring
Inner fast ring + delayed outer slow ring with offset.
| Param | Used As |
|-------|---------|
| bullet_count | Total count (min 6; inner=count/2, outer=count) |
| bullet_speed | Inner=1.5x, Outer=0.6x |
| Hardcoded | outer delay=0.15s, half-step offset |

### ZIGZAG (22) — Alternating Wall
Left-right alternating shots creating a weaving bullet wall.
| Param | Used As |
|-------|---------|
| bullet_count | Shot count (min 5) |
| bullet_speed | Bullet velocity |
| Hardcoded | zigzag angle=0.35 rad, delay=0.06s/shot |

### SHOTGUN_BLAST (23) — Close-Range Spread
Very wide cone of short-lived bullets. Devastating up close.
| Param | Used As |
|-------|---------|
| bullet_count | Pellet count (min 7) |
| bullet_speed | Base speed (x1.4 multiplier) |
| Hardcoded | cone=1.2 rad, lifetime=0.6s, speed variance=0.7-1.3x |

### HELIX (24) — Double Helix Stream
Two intertwined spiraling bullet streams, 4 rapid pairs.
| Param | Used As |
|-------|---------|
| bullet_speed | Bullet velocity |
| Hardcoded | 4 volleys, 0.1s spacing, amplitude=0.7, orbit=8px, rotation=2.4 rad |

### METEOR_SHOWER (25) — Meteor Rain
Rains lobbed meteors across random spots near player.
| Param | Used As |
|-------|---------|
| bullet_count | Meteor count (clamped 3-6) |
| bomb_aoe_radius | Explosion radius (default 14) |
| bomb_flight_time | Flight time (default 0.7) |
| Hardcoded | offset=30px scatter, delay=0.25s, ring_count=6 |

### BOOMERANG_SHOT (26) — Returning Arc
Bullets arc out then curve back toward the enemy.
| Param | Used As |
|-------|---------|
| bullet_count | Bullet count (min 3) |
| bullet_speed | Base speed (x0.8 multiplier) |
| Hardcoded | spread=0.6 rad, max_travel=35-55px, lifetime=5s |

### STRAFE_RUN (27) — Hit-and-Run
Fires spread while moving perpendicular. Re-aims each shot.
| Param | Used As |
|-------|---------|
| bullet_count | Shot count (min 4) |
| bullet_speed | Base speed (x1.1 multiplier) |
| charge_speed | Strafe movement speed |
| charge_duration | How long the strafe lasts |
| Hardcoded | delay=0.08s/shot, jitter=0.1 rad |

### MINEFIELD (28) — Area Denial
Drops very slow bullets in all directions around self.
| Param | Used As |
|-------|---------|
| bullet_count | Mine count (min 8) |
| bullet_speed | Base speed (x0.3 = very slow) |
| Hardcoded | spawn offset=4-12px, angle jitter=0.3 rad |

### RETURNING_VOLLEY (29) — Curving Volley
Fires bullets that curve back toward their origin position.
| Param | Used As |
|-------|---------|
| bullet_count | Bullet count (min 4) |
| bullet_speed | Base speed (0.8-1.2x variance) |
| Hardcoded | spread=0.5 rad, max_travel=40-70px, lifetime=5s |

### SEEKING_MINES (30) — Homing Mines
Drops slow homing mines that drift toward the player.
| Param | Used As |
|-------|---------|
| bullet_count | Mine count (min 3) |
| bullet_speed | Base speed (x0.2 = very slow) |
| Hardcoded | spawn offset=6-14px, angle jitter=0.4 rad, lifetime=8s |

---

## ADVANCED PATTERNS (31-41)

### DETONATOR (31) — Exploding Bullets
Fires fast bullets that decelerate and explode into sub-bullets.
| Param | Used As |
|-------|---------|
| bullet_count | Shot count (min 3) |
| bullet_speed | Base speed (x1.2 multiplier) |
| Hardcoded | spread=0.2 rad, decel_rate=60-120, lifetime=4s |

### SPLITTER (32) — Splitting Bullets
Fires bullets aimed at player that split halfway to target.
| Param | Used As |
|-------|---------|
| bullet_count | Initial bullet count (min 2) |
| bullet_speed | Base speed (x0.6 = slower approach) |
| Hardcoded | split_count=3-5, spread=0.2 rad, lifetime=4s |

### SINE_BARRAGE (33) — Wavy Bullets
Bullets oscillate perpendicular to travel direction.
| Param | Used As |
|-------|---------|
| bullet_count | Bullet count (min 4) |
| bullet_speed | Base speed (0.8-1.1x variance) |
| Hardcoded | spread=0.3 rad, sine amplitude=4-10px, frequency=6-12Hz, lifetime=4s |

### HOMING_SALVO (34) — Missile Volley
Bullets home toward the player. Fired in wide arc, homing corrects.
| Param | Used As |
|-------|---------|
| bullet_count | Missile count (min 3) |
| bullet_speed | Base speed (x0.7 multiplier) |
| Hardcoded | spread=0.8 rad, delay=0.1s/missile, speed variance=0.9-1.3x, lifetime=5s |

### TELEGRAPH_EXPLOSION (35) — Delayed Explosion
Places a visible warning marker at player position, explodes after delay.
| Param | Used As |
|-------|---------|
| bullet_speed | Explosion ring speed (x0.8 multiplier) |
| attack_damage | Direct damage in explosion radius |
| Hardcoded | marker_radius=24px, delay=1.0s, ring_count=12, damage_radius=20px |

### ORBIT_LAUNCH (36) — Orbiting Projectiles
Bullets orbit the enemy briefly, then launch outward.
| Param | Used As |
|-------|---------|
| bullet_count | Orbiting bullet count (min 4) |
| bullet_speed | Launch speed after orbit |
| Hardcoded | orbit_radius=12px, orbit_time=0.4-0.8s, lifetime=5s |

### WALL_BOUNCE (37) — Bouncing Bullets
Bullets reflect off walls instead of dying.
| Param | Used As |
|-------|---------|
| bullet_count | Bullet count (min 3) |
| bullet_speed | Base speed (x0.9 multiplier) |
| bounce_count | Wall bounces per bullet (default 2) |
| Hardcoded | spread=0.5 rad, lifetime=4s |

### LASER_GRID (38) — Cardinal Laser Lines
4 perpendicular beams of rapid-fire tightly-packed bullets.
| Param | Used As |
|-------|---------|
| bullet_speed | Bullet speed (x1.2 multiplier) |
| Hardcoded | 4 beams, 5 bullets/beam, delay=0.08s, lifetime=1.5s |

### GRAVITY_WELL (39) — Black Hole
Slow orb that pulls player toward it, then explodes into bullet ring.
| Param | Used As |
|-------|---------|
| attack_damage | Explosion sub-bullet damage |
| Hardcoded | orb_speed=25, pull_radius=100px, pull_strength=10-30, orb_lifetime=3s, ring=12 bullets at speed 90 |

### CHAIN_LIGHTNING (40) — Lightning Bolt
Instant chain from enemy to player with visual bolt + damage zones.
| Param | Used As |
|-------|---------|
| attack_damage | Direct hit damage |
| Hardcoded | chain_segments=6, bolt_width=2px, fade=0.4s, hit_width=15px, max_range=80px |

### DEATH_SPIRAL (41) — Death Pattern
Used as `death_bullet_pattern`. Expanding spiral fired from death position.
| Param | Used As |
|-------|---------|
| attack_damage | Sub-bullet damage |
| Hardcoded | arms=3, bullets_per_arm=8, delay=0.12s, base_speed=50, speed_increment=8/step |
| Note | When used as main attack_type, fires SPIRAL (14) while alive |

---

## BOMB ATTACKS (42-46)

All use `_spawn_lob_at()` — bombs arc over walls, show landing markers, explode.

### BOMB_TOSS (42) — Single Bomb
One bomb at player position.
| Param | Used As |
|-------|---------|
| bomb_aoe_radius | Explosion radius (default 16) |
| bomb_flight_time | Arc duration (default 0.6s, x2 slow multiplier applied) |

### CARPET_BOMB (43) — Bomb Line
3-5 bombs in a line from enemy to player.
| Param | Used As |
|-------|---------|
| bullet_count | Bomb count (clamped 3-5) |
| bomb_aoe_radius | Per-bomb radius (x0.8 multiplier) |
| bomb_flight_time | Base flight (increases +0.12s per bomb) |

### FIRE_RAIN (44) — Scattered Rain
2-3 bombs scattered near player.
| Param | Used As |
|-------|---------|
| bullet_count | Bomb count (clamped 2-3) |
| bomb_aoe_radius | Per-bomb radius (x0.6 multiplier) |
| bomb_flight_time | Base flight (+0-0.3s variance) |

### CLUSTER_BOMB (45) — Splitting Bomb
One bomb that splits into 4 sub-bombs on landing.
| Param | Used As |
|-------|---------|
| bomb_aoe_radius | Main bomb radius |
| bomb_flight_time | Flight time (x1.2 multiplier) |
| Hardcoded | cluster_count=4 sub-bombs |

### MINE_DROP (46) — Short-Range Mines
2-3 quick lobs near self with bullet ring on landing.
| Param | Used As |
|-------|---------|
| bullet_count | Mine count (clamped 2-3) |
| bomb_aoe_radius | Per-mine radius (x0.6 multiplier) |
| Hardcoded | flight_time=0.3s, ring_count=6, offset=12px |

---

## BARRIER / MANIPULATION (47-49)

### BARRIER_WALL (47) — Defensive Wall
Spawns stationary barrier segments. Walls block player bullets.
| Param | Used As |
|-------|---------|
| _is_boss_or_large | Controls scaling (checked at runtime) |
| Normal | 3 segments, 3 HP each, 4s lifetime, max 3 active |
| Boss/Large | 5 segments, 5 HP each, 6s lifetime, max 6 active (2 walls) |
| Hardcoded | spacing=8/10px, center=15px ahead, cooldown via existing barrier check |

### PULL_SHOT (48) — Gravity Orbs
Slow orbs that pull the player toward them.
| Param | Used As |
|-------|---------|
| bullet_speed | Base speed (x0.1 = very slow crawl) |
| Hardcoded | force_radius=48px, force_strength=3, lifetime=6-10s random |

### PUSH_WAVE (49) — Force Orbs
Slow orbs that push the player away.
| Param | Used As |
|-------|---------|
| bullet_count | Orb count (clamped 2-3) |
| bullet_speed | Base speed (x0.1 = very slow) |
| Hardcoded | cone=0.4*PI, force_radius=45px, force_strength=4, lifetime=6-10s random |

---

## ENEMY SCALING TIERS

### Normal (size_class=0)
Base stats from .tres file. No modifications in test arena.

### Elite (size_class=1, or ELITE room type)
Applied by dungeon_manager when spawning in ELITE rooms:
- HP x4
- move_speed x1.3
- attack_speed x0.8 (faster)
- bullet_count +3
- bullet_speed x1.2
- 2 boss phases, summons 2 minions per phase change
- Phase 2 attack auto-assigned based on archetype

### Boss (size_class=2, or BOSS room type)
Applied by dungeon_manager when spawning in BOSS rooms:
- HP x10
- move_speed x0.85
- attack_speed x0.5 (much faster)
- bullet_count +6
- bullet_speed x1.3
- 3 boss phases, summons 4 minions per phase change
- Phase 2 + Phase 3 attacks auto-assigned

### Boss Phase Attack Assignment
Based on base attack archetype:
- Ranged/Single → gets BURST or SPIRAL
- Melee/Charge → gets SLAM or NOVA
- Any → phase 3 typically gets a "bigger" version of the attack

---

## SHARED ENEMY PROPERTIES (enemy_definition.gd)

### Core Stats
| Property | Type | Default | Notes |
|----------|------|---------|-------|
| enemy_name | String | "Enemy" | Display name |
| max_hp | int | 3 | Base HP before scaling |
| move_speed | float | 20.0 | Movement speed |
| contact_damage | int | 1 | Touch damage |
| level | int | 1 | For level-based systems |
| kingdom | String | "unknown" | undead/orc/crawler/animal/demon/human/magical |
| size_class | SizeClass | NORMAL | NORMAL/LARGE/BOSS |
| hostile | bool | true | Will attack player |

### Attack Stats
| Property | Type | Default | Notes |
|----------|------|---------|-------|
| attack_type | AttackType | RANGED | Main attack pattern |
| attack_damage | int | 1 | Damage per hit |
| attack_speed | float | 1.5 | Seconds between attacks |
| bullet_speed | float | 80.0 | Projectile velocity |
| bullet_count | int | 1 | Projectile count |
| bullet_sprite_index | int | -1 | -1=kingdom default |

### Behavior
| Property | Type | Default | Notes |
|----------|------|---------|-------|
| preferred_distance | float | 0.0 | Hold distance from player |
| charge_speed | float | 80.0 | For CHARGE/STRAFE |
| charge_duration | float | 0.3 | Charge time |
| aggro_range | float | 80.0 | Detection range |
| ignores_terrain | bool | false | Flying/ghost |

### Special
| Property | Type | Default | Notes |
|----------|------|---------|-------|
| summon_count | int | 2 | SUMMON minion count |
| summon_definition | EnemyDefinition | null | Minion template |
| slam_radius | float | 24.0 | SLAM AoE radius |
| teleport_cooldown | float | 3.0 | TELEPORT interval |
| heal_amount | int | 2 | HEAL HP restored |
| heal_range | float | 48.0 | HEAL search radius |
| poison_chance | float | 0.0 | POISON_SHOT proc chance |
| split_count | int | 2 | SPLIT copy count |
| split_definition | EnemyDefinition | null | SPLIT copy template |
| stealth_duration | float | 2.0 | STEALTH invisibility time |
| shield_hp | int | 0 | SHIELD barrier HP + frontal block |
| beam_duration | float | 1.0 | BEAM active time |
| beam_sweep_speed | float | 1.5 | BEAM rotation speed |
| bounce_count | int | 0 | WALL_BOUNCE reflections |
| bomb_aoe_radius | float | 16.0 | Bomb explosion radius |
| bomb_flight_time | float | 0.6 | Bomb arc duration |
| death_bullet_pattern | AttackType | NONE | Pattern fired on death |
| explodes_on_death | bool | false | AoE on death |
| explode_radius | float | 20.0 | Death explosion radius |

### Boss Phases
| Property | Type | Default | Notes |
|----------|------|---------|-------|
| boss_phases | int | 1 | 1=none, 2=two, 3=three |
| phase_2_attack | AttackType | NONE | Attack at <66% HP |
| phase_3_attack | AttackType | NONE | Attack at <33% HP |
| phase_2_bullet_count | int | 0 | 0=use base |
| phase_3_bullet_count | int | 0 | 0=use base |
| summon_on_phase_change | bool | false | Spawn minions on phase transition |
| summon_phase_count | int | 3 | Minions per phase change |

### Visuals
| Property | Type | Default | Notes |
|----------|------|---------|-------|
| use_loy_sprite | bool | false | Use LoY atlas sprite |
| loy_tile_index | int | 0 | Index in chars.png atlas |
| sprite_color | Color | white | Tint color |
| xp_value | int | 0 | XP on kill |
| score_value | int | 0 | Gold on kill |
