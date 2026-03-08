# Army & Battle System

## Purpose
The army system converts dungeon-earned resources into military power for overworld conquest. Tactical battles use formations and equipped divisions to resolve territory control.

## Unit Types

| Unit | Role | Strengths | Weaknesses |
|------|------|-----------|------------|
| Infantry | Frontline | High HP, cheap | Low damage, slow |
| Archers | Ranged DPS | High damage at range | Low HP, weak to cavalry |
| Cavalry | Flanker | Fast, high charge damage | Expensive, weak to spears |
| Siege | Anti-structure | Massive structural damage | Very slow, fragile |

### Unit Stats
```
class_name UnitDefinition extends Resource

enum UnitType { INFANTRY, ARCHER, CAVALRY, SIEGE }

var unit_id: String
var unit_name: String
var type: UnitType
var icon: Texture2D
var sprite_frame: int  # frame in Mixed_Units.png

# Base stats
var hp: int = 100
var attack: int = 10
var defense: int = 5
var speed: int = 3
var range_tiles: int = 1  # 1 = melee, 3+ = ranged
var cost_gold: int = 50
var cost_troop_tokens: int = 1
```

## Division System

Units are grouped into divisions (max 20 units per division).

```
class_name Division extends Resource

var division_name: String
var units: Array[UnitInstance] = []   # max 20
var formation: FormationDefinition
var equipment: Array[DivisionEquipment] = []
var morale: float = 100.0
var experience: int = 0

func get_total_attack() -> float:
    var base = 0.0
    for unit in units:
        base += unit.definition.attack
    return base * formation.attack_mult * _equipment_attack_mult()

func get_total_defense() -> float:
    var base = 0.0
    for unit in units:
        base += unit.definition.defense
    return base * formation.defense_mult * _equipment_defense_mult()

func get_total_hp() -> int:
    var total = 0
    for unit in units:
        total += unit.current_hp
    return total
```

### UnitInstance
```
class_name UnitInstance extends Resource

var definition: UnitDefinition
var current_hp: int
var veteran: bool = false  # survived 3+ battles
```

## Formation System

```
class_name FormationDefinition extends Resource

enum FormationType { LINE, WEDGE, SPREAD, SHIELD_WALL }

var formation_id: String
var formation_name: String
var type: FormationType
var description: String

# Multipliers
var attack_mult: float = 1.0
var defense_mult: float = 1.0
var speed_mult: float = 1.0
var ranged_resist: float = 0.0    # % reduction to incoming ranged
var charge_bonus: float = 0.0     # bonus damage on first contact
var aoe_resist: float = 0.0       # % reduction to AoE damage
```

### Formation Stats

| Formation | ATK | DEF | SPD | Special |
|-----------|-----|-----|-----|---------|
| Line | 1.0x | 1.2x | 0.9x | +20% ranged resist |
| Wedge | 1.3x | 0.8x | 1.1x | +50% charge bonus |
| Spread | 0.9x | 1.0x | 1.0x | +40% AoE resist |
| Shield Wall | 0.7x | 1.5x | 0.6x | +50% ranged resist |

## Division Equipment

Army equipment is separate from hero equipment. Found in dungeon runs.

```
class_name DivisionEquipment extends Resource

var equipment_id: String
var equipment_name: String
var description: String
var icon: Texture2D

# Stat modifiers for the whole division
var attack_mult: float = 1.0
var defense_mult: float = 1.0
var speed_mult: float = 1.0
var hp_mult: float = 1.0
var special_effect: String = ""  # "fire_arrows", "poison_blades", etc.
```

| Equipment | Effect |
|-----------|--------|
| Banner of Speed | +15% division speed |
| Shield Plate | +20% division defense |
| Rune Arrows | +25% archer damage |
| War Drums | +10% morale recovery |
| Siege Ladders | +50% siege unit structure damage |

## Battle Resolution

### Battle Types by Territory

| Territory | Player Divisions | Enemy Divisions | Resolution |
|-----------|-----------------|-----------------|------------|
| Outpost | 1 | 1 | Auto-resolve |
| Stronghold | 1-2 | 1-2 | Tactical (choose formation) |
| Fortress | 2-4 | 3-5 | Full tactical (multi-phase) |

### Auto-Resolve Algorithm (Outposts)

```
func auto_resolve(player_div: Division, enemy_div: Division) -> BattleResult:
    var player_power = player_div.get_total_attack() + player_div.get_total_defense()
    var enemy_power = enemy_div.get_total_attack() + enemy_div.get_total_defense()

    # Type advantage multiplier
    player_power *= get_type_advantage(player_div, enemy_div)

    var win_chance = player_power / (player_power + enemy_power)
    var roll = randf()

    var result = BattleResult.new()
    result.victory = roll < win_chance

    # Casualties based on power ratio
    var casualty_rate = 0.1 + (1.0 - win_chance) * 0.4
    if not result.victory:
        casualty_rate = 0.3 + win_chance * 0.3

    result.units_lost = int(player_div.units.size() * casualty_rate)
    result.gold_reward = 50 if result.victory else 0
    result.xp_gained = 10

    return result
```

### Tactical Battle (Strongholds/Fortresses)

```
Phase 1: DEPLOY
  → Player chooses formation for each division
  → Position divisions on deployment zone

Phase 2: ENGAGE
  → Divisions move toward each other
  → Ranged units fire first
  → Melee units engage on contact

Phase 3: RESOLVE
  → Per-round damage calculation
  → Morale checks (division routs at 0 morale)
  → Battle ends when one side eliminated or routed

Round damage:
  attacker_damage = division.get_total_attack() * random(0.8, 1.2)
  effective_damage = max(1, attacker_damage - defender.get_total_defense() * 0.5)
  distribute damage across defender units
```

### Type Advantage Matrix

```
              vs Infantry  vs Archer  vs Cavalry  vs Siege
Infantry      1.0          1.2        0.8         1.0
Archer        0.8          1.0        0.7         1.3
Cavalry       1.3          1.5        1.0         0.8
Siege         1.0          0.8        1.2         1.0
```

## BattleResult
```
class_name BattleResult extends Resource

var victory: bool
var units_lost: int
var gold_reward: int
var relic_reward: int
var xp_gained: int
var territory_conquered: String = ""
var blueprints_found: Array[String] = []
```

## Interactions With Other Systems

| System | Interaction |
|--------|-------------|
| Economy | Gold + troop tokens to recruit; gold reward from victories |
| Dungeon | Troop tokens and division equipment found in runs |
| Overworld | Battles triggered by attacking territory nodes |
| Blueprints | Fortress rewards unlock new unit types/equipment |
| Analytics | Track formation usage, win rates, army compositions |

## MVP Implementation Strategy

### MVP-1: Auto-Battle
- 2 unit types (Infantry, Archer)
- 1 division
- Auto-resolve battles for outposts
- Simple power comparison

### MVP-2: Tactical
- All 4 unit types
- Formation selection
- 2-division battles
- Type advantage matrix
- Casualty/morale system

### MVP-3: Full System
- Division equipment
- Veteran units
- Multi-phase fortress battles
- Siege mechanics
- Battle replay/visualization
