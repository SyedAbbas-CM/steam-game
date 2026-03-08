# Companion AI System

## Purpose
Companions are AI-controlled units that follow and support the hero during dungeon runs. They add tactical depth without requiring micromanagement. Max 3 active companions.

## Companion Types

| Type | Role | Behavior | Attack |
|------|------|----------|--------|
| Archer | Ranged DPS | Stay behind hero, attack nearest | Arrows toward nearest enemy |
| Shield Guard | Tank | Stay in front of hero, absorb hits | Melee bash, aggro enemies |
| Healer Drone | Support | Orbit hero, heal periodically | Heal pulse every N seconds |
| Bomb Goblin | Burst DPS | Rush toward enemy clusters | Explode on contact, respawn after delay |

## Data Model

### CompanionDefinition
```
class_name CompanionDefinition extends Resource

enum CompanionType { ARCHER, SHIELD_GUARD, HEALER_DRONE, BOMB_GOBLIN }
enum BehaviorMode { FOLLOW_BEHIND, FOLLOW_FRONT, ORBIT, RUSH_ENEMIES }

var companion_id: String
var companion_name: String
var type: CompanionType
var icon: Texture2D
var sprite_frame: int          # frame in lofi_char.png

# Stats
var hp: int = 10
var damage: int = 1
var attack_speed: float = 1.0
var move_speed: float = 50.0
var attack_range: float = 60.0

# Behavior
var behavior: BehaviorMode
var follow_distance: float = 20.0
var follow_offset: Vector2 = Vector2.ZERO

# Special
var special_cooldown: float = 5.0
var special_description: String = ""
```

## AI Behavior System

### State Machine Per Companion

```
IDLE
  → enemy in range? → ATTACKING
  → hero moving? → FOLLOWING

FOLLOWING
  → enemy in range? → ATTACKING
  → close to hero? → IDLE

ATTACKING
  → target dead? → FOLLOWING
  → target out of range? → FOLLOWING
  → hp < 20%? → RETREATING

RETREATING
  → near hero? → FOLLOWING
  → hp > 50%? → FOLLOWING
```

### Formation Following

Companions follow in formation relative to hero:

```
func get_follow_position(companion_index: int, hero_pos: Vector2, hero_dir: Vector2) -> Vector2:
    var perpendicular = hero_dir.rotated(PI / 2.0)
    var offset_behind = -hero_dir * follow_distance

    match companion_index:
        0: return hero_pos + offset_behind + perpendicular * -15
        1: return hero_pos + offset_behind
        2: return hero_pos + offset_behind + perpendicular * 15

    return hero_pos + offset_behind
```

### Target Selection

```
func select_target(companion_pos: Vector2, attack_range: float) -> Node2D:
    var enemies = get_tree().get_nodes_in_group("enemy")
    var best: Node2D = null
    var best_dist: float = attack_range * attack_range

    for enemy in enemies:
        var dist = companion_pos.distance_squared_to(enemy.global_position)
        if dist < best_dist:
            best_dist = dist
            best = enemy

    return best
```

## Companion Acquisition

- **Dungeon rewards**: choose companion as room reward
- **Base camp**: recruit with troop tokens
- **Blueprints**: unlock special companion variants

## Companion Death & Revival

- Companions can die during runs (HP reaches 0)
- Dead companions revive at start of next floor (50% HP)
- Core module equipment can modify revival behavior

## Interactions With Other Systems

| System | Interaction |
|--------|-------------|
| Combat | Companions attack enemies, can be damaged |
| Equipment | Core module slot can boost companion stats |
| Mutations | Some mutations affect companions (e.g., heal aura heals companions too) |
| Dungeon | Companions persist across rooms, revive per floor |
| Economy | Troop tokens used to unlock companions at camp |

## MVP Implementation Strategy

### MVP-1: Single Companion
- Archer companion only
- Simple follow + shoot nearest behavior
- Basic HP, dies and revives next floor

### MVP-2: All Types
- All 4 companion types
- State machine AI
- Formation following
- Companion selection in reward screen

### MVP-3: Advanced
- Companion equipment/upgrades
- Special abilities
- Synergies with hero mutations
- Leveling during runs
