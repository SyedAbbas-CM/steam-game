# Overworld Conquest System

## Purpose
The overworld is the strategic metagame. A Risk-style territory map that gives long-term goals, unlocks new content, and makes dungeon runs feel purposeful. Conquest is persistent across deaths.

## Map Structure

```
┌─────────────────────────────────────────────┐
│                OVERWORLD MAP                │
│                                             │
│   [Start] ── [Outpost] ── [Outpost]        │
│       │           │            │            │
│   [Outpost] ── [Stronghold] ── [Outpost]   │
│       │           │            │            │
│   [Outpost] ── [Outpost] ── [Stronghold]   │
│                   │            │            │
│            [Stronghold] ── [Outpost]        │
│                   │                         │
│            ★ [FORTRESS] ★                   │
│                                             │
└─────────────────────────────────────────────┘
```

## Territory Types

### Outpost
- **Difficulty**: Easy
- **Battle**: Auto-resolve (1 division)
- **Reward**: Small gold + troop tokens
- **Purpose**: Territory expansion, resource generation

### Stronghold
- **Difficulty**: Medium
- **Battle**: Tactical (1-2 divisions, choose formation)
- **Reward**: Moderate gold/relics + equipment blueprints
- **Purpose**: Gatekeeper to fortress zones

### Fortress
- **Difficulty**: Hard
- **Battle**: Multi-phase tactical (2-4 divisions)
- **Reward**: Major system unlocks
- **Purpose**: Primary progression milestones

## Data Models

### TerritoryDefinition
```
class_name TerritoryDefinition extends Resource

enum TerritoryType { OUTPOST, STRONGHOLD, FORTRESS }
enum Biome { PLAINS, FOREST, MOUNTAIN, DESERT, ICE, ANCIENT }
enum OwnerFaction { NEUTRAL, PLAYER, ENEMY_RED, ENEMY_BLUE, ENEMY_GREEN }

var territory_id: String
var territory_name: String
var type: TerritoryType
var biome: Biome
var map_position: Vector2     # position on overworld map

# Connections
var connected_territories: Array[String] = []  # territory_ids

# Combat
var garrison_divisions: Array[DivisionTemplate] = []
var difficulty_rating: int = 1  # 1-10

# Rewards
var gold_reward: int = 100
var relic_reward: int = 0
var troop_token_reward: int = 2
var blueprint_rewards: Array[String] = []
var system_unlock: String = ""  # "frost_mutations", "poison_items", etc.

# State
var owner: OwnerFaction = OwnerFaction.NEUTRAL
var conquered: bool = false
var turns_since_conquered: int = 0
```

### OverworldState
```
class_name OverworldState extends Resource

var territories: Dictionary = {}  # territory_id -> TerritoryState
var player_army: Array[Division] = []
var current_territory: String = "start"
var turn_number: int = 0
var territories_conquered: int = 0
```

### DivisionTemplate (for garrison enemies)
```
class_name DivisionTemplate extends Resource

var unit_composition: Dictionary = {}  # UnitType -> count
var formation: FormationDefinition
var power_rating: int = 100
```

## Map Traversal

```
Player can only attack territories connected to owned territories.

func get_attackable_territories() -> Array[String]:
    var attackable: Array[String] = []
    for tid in owned_territories:
        var territory = territories[tid]
        for connected in territory.connected_territories:
            if not is_owned(connected) and connected not in attackable:
                attackable.append(connected)
    return attackable
```

## Fortress Unlock Rewards

| Fortress | Biome | Unlocks |
|----------|-------|---------|
| Frostpeak Citadel | Ice | Frost mutations, ice weapons, Snow Archer unit |
| Venomspire Keep | Desert | Poison mutations, venom equipment, Scorpion Cavalry |
| Ancient Sanctum | Ancient | Legendary blueprints, Ancient Golem unit, relic doubler |
| Stormwall Bastion | Mountain | Lightning mutations, storm weapons, Thunder Siege |
| Shadowmere Fortress | Forest | Stealth mutations, shadow equipment, Assassin Infantry |

## Territory Passive Income

Owned territories generate resources per "turn" (after each dungeon run):

```
func calculate_passive_income() -> Dictionary:
    var income = {"gold": 0, "relics": 0, "troop_tokens": 0}
    for tid in owned_territories:
        var t = territories[tid]
        match t.type:
            TerritoryType.OUTPOST:
                income["gold"] += 25
                income["troop_tokens"] += 1
            TerritoryType.STRONGHOLD:
                income["gold"] += 75
                income["relics"] += 1
                income["troop_tokens"] += 2
            TerritoryType.FORTRESS:
                income["gold"] += 150
                income["relics"] += 3
                income["troop_tokens"] += 5
    return income
```

## Enemy Faction Counter-Attacks

After conquering N territories, enemy factions can counter-attack:

```
func check_counter_attack(turn: int) -> TerritoryDefinition:
    if turn % 5 != 0:  # every 5 turns
        return null

    var vulnerable = get_border_territories()  # player territories adjacent to enemy
    if vulnerable.is_empty():
        return null

    var target = vulnerable[randi() % vulnerable.size()]
    # Spawn counter-attack garrison
    target.garrison_divisions = generate_counter_army(turn)
    return target
```

## Interactions With Other Systems

| System | Interaction |
|--------|-------------|
| Army | Divisions deployed for territory battles |
| Economy | Territories generate passive income; battles cost/reward resources |
| Dungeon | Each death completes a "turn"; fortress unlocks expand dungeon content |
| Blueprints | Fortresses unlock biome-specific blueprints |
| Analytics | Track territory difficulty ratings, conquest order, counter-attack survival |

## MVP Implementation Strategy

### MVP-1: Linear Map
- 5 territories in a line (3 outposts, 1 stronghold, 1 fortress)
- Auto-resolve all battles
- Territory conquering unlocks next node
- Passive income after each run

### MVP-2: Branching Map
- 12-15 territories with branching paths
- Tactical battles for strongholds/fortresses
- Fortress unlock rewards
- Enemy counter-attacks

### MVP-3: Full Map
- 20+ territories across 5 biomes
- Multiple fortresses with unique unlocks
- Faction AI with expansion behavior
- Dynamic difficulty based on player progression
- Map visual with fog of war
