# Item & Mutation System

## Purpose
Equipment defines hero capability. Mutations modify behavior in stackable, combinatorial ways. Together they create emergent build diversity — the core of replayability.

## Equipment Slots

```
┌──────────────┐
│   WEAPON     │  Primary attack pattern (projectile type, rate, damage)
├──────────────┤
│   ARMOR      │  Defense, HP, resistance modifiers
├──────────────┤
│   ARTIFACT   │  Active ability (cooldown-based)
├──────────────┤
│  CORE MODULE │  Passive system modifier (economy, companion, mutation boost)
└──────────────┘
```

## Data Models

### EquipmentDefinition
```
class_name EquipmentDefinition extends Resource

enum Slot { WEAPON, ARMOR, ARTIFACT, CORE_MODULE }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

var item_id: String              # unique key
var item_name: String
var description: String
var slot: Slot
var rarity: Rarity
var icon: Texture2D
var stat_modifiers: Array[StatModifier] = []
var innate_mutations: Array[MutationDefinition] = []
var weapon_pattern: WeaponPattern  # only for weapons
var active_ability: AbilityDefinition  # only for artifacts
var blueprint_required: String = ""  # empty = no blueprint needed
```

### StatModifier (existing, extended)
```
enum StatType {
    MAX_HP, MOVE_SPEED, ATTACK_DAMAGE, ATTACK_SPEED,
    BULLET_SPEED, BULLET_COUNT, SPREAD_ANGLE, PIERCE_COUNT,
    BULLET_LIFETIME, DEFENSE, CRIT_CHANCE, CRIT_DAMAGE,
    GOLD_MULT, RELIC_MULT, DODGE_CHANCE, LIFE_STEAL
}
```

### MutationDefinition
```
class_name MutationDefinition extends Resource

enum MutationType {
    PROJECTILE_SPLIT,    # bullets split on hit
    BULLET_PIERCE,       # bullets pass through enemies
    LIFE_STEAL,          # heal on damage dealt
    DASH_SHOCKWAVE,      # damage on dash
    FIRE_TRAIL,          # leave fire behind while moving
    CHAIN_LIGHTNING,     # damage chains to nearby enemies
    EXPLODING_BULLETS,   # AoE on bullet impact
    FREEZE_AURA,         # slow nearby enemies
    RICOCHET,            # bullets bounce off walls
    VAMPIRIC_BURST,      # heal burst on kill
    HOMING_SHOTS,        # bullets seek enemies
    SHIELD_ON_KILL,      # temp shield per kill
}

var mutation_id: String
var mutation_name: String
var description: String
var type: MutationType
var icon: Texture2D
var tier: int = 1            # 1-3, higher = stronger
var strength: float = 1.0    # multiplier for effect
var max_stacks: int = 3      # how many times this can be picked
var tags: Array[String] = [] # for synergy detection
```

## Mutation Stacking

Mutations stack additively up to max_stacks.

```
# Example: picking LIFE_STEAL 3 times
# tier 1 = 3% heal per hit
# stacked x3 = 9% heal per hit

func get_mutation_strength(type: MutationType) -> float:
    var total: float = 0.0
    for m in active_mutations:
        if m.type == type:
            total += m.strength * m.tier
    return total
```

## Mutation Execution Pipeline

Mutations hook into combat events:

```
ON_BULLET_FIRE:
    → HOMING_SHOTS: set bullet.homing_strength
    → PROJECTILE_SPLIT: register split callback

ON_BULLET_HIT:
    → LIFE_STEAL: heal player
    → EXPLODING_BULLETS: spawn AoE
    → CHAIN_LIGHTNING: damage nearby enemies
    → PROJECTILE_SPLIT: spawn child bullets

ON_ENEMY_KILL:
    → VAMPIRIC_BURST: heal burst
    → SHIELD_ON_KILL: add temp shield

ON_PLAYER_DASH:
    → DASH_SHOCKWAVE: spawn damage wave

ON_PLAYER_MOVE:
    → FIRE_TRAIL: spawn fire hazard

ON_PLAYER_HIT:
    → DODGE_CHANCE: roll to negate
    → FREEZE_AURA: slow attacker
```

### MutationProcessor
```
class_name MutationProcessor extends Node

signal on_bullet_fire(bullet: Node2D)
signal on_bullet_hit(bullet: Node2D, target: Node2D)
signal on_enemy_kill(enemy: Node2D)
signal on_player_dash(position: Vector2)
signal on_player_move(position: Vector2, delta: float)
signal on_player_hit(damage: int, source: Node2D)

var active_mutations: Array[MutationDefinition] = []

func process_event(event: String, context: Dictionary) -> Dictionary:
    var result = context.duplicate()
    for mutation in active_mutations:
        result = _apply_mutation(mutation, event, result)
    return result
```

## Weapon-Pattern Relationship

Each weapon has an associated WeaponPattern:

| Weapon | Pattern | Base Stats |
|--------|---------|------------|
| Short Bow | Single Shot | fast rate, low damage |
| War Bow | Spread (3) | medium rate, medium damage |
| Staff of Storms | Ring (8) | slow rate, high damage |
| Twin Daggers | Burst (3) | very fast, very low damage |
| Cannon | Shotgun (5) | very slow, very high damage |
| Spirit Orb | Spiral | continuous, low damage |
| Crossbow | Parallel (2) | medium rate, medium damage |

Mutations modify the pattern output:
- PROJECTILE_SPLIT doubles bullet count on hit
- RICOCHET changes bullet behavior post-bounce
- HOMING adds tracking to all pattern bullets

## Blueprint System

```
class_name BlueprintDefinition extends Resource

var blueprint_id: String
var blueprint_name: String
var result_item: EquipmentDefinition
var relic_cost: int
var gold_cost: int
var discovered: bool = false
var crafted_count: int = 0

# Discovery sources
var drop_source: String  # "elite", "boss", "fortress_ice", etc.
var drop_chance: float = 0.1
```

### Blueprint Discovery Flow
```
Kill elite/boss OR conquer fortress
    ↓
Roll drop_chance against blueprint pool
    ↓
Blueprint added to player's collection (discovered = true)
    ↓
At base camp: craft item using relic_cost + gold_cost
    ↓
Item added to equipment pool (can now drop in dungeon runs)
```

## Synergy Tags

Items and mutations have tags that create synergies:

```
Tags: "fire", "ice", "lightning", "poison", "speed", "defense", "heal", "crit"

# Synergy detection
func get_active_synergies() -> Array[String]:
    var tag_counts: Dictionary = {}
    for m in active_mutations:
        for tag in m.tags:
            tag_counts[tag] = tag_counts.get(tag, 0) + 1

    var synergies: Array[String] = []
    for tag in tag_counts:
        if tag_counts[tag] >= 3:
            synergies.append(tag)
    return synergies

# 3+ fire tags = "Inferno" synergy → +30% fire damage
# 3+ speed tags = "Velocity" synergy → +20% move/attack speed
```

## Interactions With Other Systems

| System | Interaction |
|--------|-------------|
| Dungeon | Items drop from enemies, rewards, shops |
| Combat | Weapons define attack pattern, mutations hook into combat events |
| Companions | Core module can boost companion stats |
| Army | Equipment can be assigned to army divisions (different pool) |
| Economy | Blueprints cost relics + gold to craft |
| Overworld | Fortress conquests unlock biome-specific mutations |
| Analytics | Track mutation pick rates, synergy effectiveness, build archetypes |

## MVP Implementation Strategy

### MVP-1: Basic Equipment
- 3 weapons with distinct WeaponPatterns (single, spread, burst)
- Stat modifiers only (no mutations yet)
- Equipment drops from enemies and rewards
- 4 equipment slots functional

### MVP-2: Mutations
- 4 mutation types (pierce, life_steal, homing, exploding_bullets)
- Mutation shrines in dungeon
- Stacking system
- Visual feedback per mutation

### MVP-3: Full System
- All 12+ mutations
- Blueprint discovery and crafting
- Synergy detection
- Rarity tiers with visual distinction
- Weapon-specific mutation interactions
