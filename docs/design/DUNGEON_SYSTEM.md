# Dungeon System

## Purpose
The dungeon is the primary gameplay loop. Procedurally generated rooms with escalating difficulty. Runs last until hero death. Every run feeds the meta-progression economy.

## Core Mechanics

### Run Structure
```
ENTER DUNGEON
  ↓
FLOOR 1 (3-5 rooms, easy)
  → combat, combat, treasure
  ↓
FLOOR 2 (4-6 rooms, medium)
  → combat, shrine, combat, elite, treasure
  ↓
FLOOR 3 (5-7 rooms, hard)
  → combat, combat, shrine, combat, elite, BOSS
  ↓
FLOOR N... (infinite scaling)
  → difficulty scales per floor
  ↓
HERO DIES → resources collected → return to camp
```

### Room Types

| Room Type | Frequency | Contents |
|-----------|-----------|----------|
| Combat | 60% | Enemies, small gold drops |
| Treasure | 15% | Choose 1 of 3 rewards |
| Mutation Shrine | 10% | Choose 1 of 3 mutations |
| Elite | 10% | Tough enemy, guaranteed rare drop |
| Boss | 1 per floor | Floor guardian, blueprint chance |
| Shop | 5% | Buy items with run gold |

### Room Generation Algorithm

```
func generate_floor(floor_number: int) -> Array[RoomData]:
    var room_count = 3 + floor_number + randi() % 3
    var rooms: Array[RoomData] = []

    # Always start with combat
    rooms.append(create_room(RoomType.COMBAT))

    # Fill middle with weighted random
    for i in range(room_count - 2):
        rooms.append(create_room(roll_room_type(floor_number)))

    # Floor ends with elite or boss
    if floor_number % 3 == 0:
        rooms.append(create_room(RoomType.BOSS))
    else:
        rooms.append(create_room(RoomType.ELITE))

    return rooms
```

### Difficulty Scaling

```
enemy_hp_mult    = 1.0 + (floor * 0.15)
enemy_damage_mult = 1.0 + (floor * 0.10)
enemy_speed_mult  = 1.0 + (floor * 0.05)
enemy_count_base  = 3 + floor
gold_mult        = 1.0 + (floor * 0.20)
```

## Data Models

### RunState
```
class_name RunState extends Resource

var current_floor: int = 1
var current_room_index: int = 0
var rooms_on_floor: Array[RoomData] = []
var hero_hp: int
var hero_max_hp: int
var run_gold: int = 0
var run_relics: int = 0
var run_troop_tokens: int = 0
var active_mutations: Array[Mutation] = []
var equipped_items: Dictionary = {}  # slot -> EquipmentItem
var companions: Array[CompanionData] = []
var run_time_seconds: float = 0.0
var enemies_killed: int = 0
var floors_cleared: int = 0
```

### RoomData
```
class_name RoomData extends Resource

enum RoomType { COMBAT, TREASURE, SHRINE, ELITE, BOSS, SHOP }

var type: RoomType
var enemies: Array[EnemySpawnEntry] = []
var rewards: Array[RewardOption] = []
var cleared: bool = false
var difficulty_tier: int = 1
```

### EnemySpawnEntry
```
class_name EnemySpawnEntry extends Resource

var enemy_type: EnemyDefinition
var count: int = 1
var spawn_delay: float = 0.0
var spawn_position_mode: int = 0  # 0=edges, 1=random, 2=circle
```

### RewardOption
```
class_name RewardOption extends Resource

enum RewardType { WEAPON, ARTIFACT, COMPANION, MUTATION, GOLD, TROOP_TOKENS, RELIC }

var type: RewardType
var item: Resource  # polymorphic: EquipmentItem, Mutation, CompanionData, etc.
var quantity: int = 1
var rarity: int = 0
```

## Reward Selection System

After clearing a room, player chooses 1 of 3 rewards.

```
func generate_reward_choices(floor: int, room_type: RoomType) -> Array[RewardOption]:
    var pool = get_reward_pool(room_type)
    var choices: Array[RewardOption] = []

    # Weight by rarity (rarer items more likely on higher floors)
    var rarity_weights = calculate_rarity_weights(floor)

    for i in range(3):
        var reward = weighted_random_pick(pool, rarity_weights)
        pool.erase(reward)  # no duplicates
        choices.append(reward)

    return choices
```

## Room Clearing Conditions

| Room Type | Clear Condition |
|-----------|----------------|
| Combat | All enemies dead |
| Treasure | Player picks reward |
| Shrine | Player picks mutation |
| Elite | Elite enemy dead |
| Boss | Boss dead |
| Shop | Player exits shop |

## Interactions With Other Systems

| System | Interaction |
|--------|-------------|
| Equipment | Items drop from enemies and reward chests |
| Mutations | Shrines offer mutation choices, mutations modify combat |
| Companions | Can be gained as rewards, fight alongside hero |
| Economy | Gold/relics/tokens accumulate during run, persist on death |
| Analytics | Run data (time, kills, build, floor reached) logged on death |

## MVP Implementation Strategy

### MVP-1: Static Rooms
- 3 hardcoded room layouts per type
- Random enemy placement within rooms
- Basic reward selection UI (3 cards)
- Floor counter, room transitions via door/portal

### MVP-2: Procedural Rooms
- Room templates with modular sections
- Enemy wave spawning system
- Scaling difficulty
- Multiple floor progression

### MVP-3: Full Dungeon
- Room graph with branching paths
- Secret rooms
- Trap mechanics
- Environmental hazards
- Mini-map
