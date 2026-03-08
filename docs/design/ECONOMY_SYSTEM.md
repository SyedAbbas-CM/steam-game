# Economy & Resource Flow

## Purpose
The economy connects all gameplay layers. Dungeon runs produce resources, base camp consumes them, and the overworld generates passive income. The flow must feel rewarding without being exploitable.

## Currencies

| Currency | Source | Sinks | Persistence |
|----------|--------|-------|-------------|
| **Gold** | Dungeon drops, battle rewards, territory income | Recruit units, buy shop items, craft blueprints | Persists on death |
| **Relics** | Dungeon elites/bosses, territory income, fortress rewards | Craft blueprints, permanent upgrades | Persists on death |
| **Troop Tokens** | Dungeon rewards, territory income | Recruit army units | Persists on death |
| **Run Gold** | Dungeon combat drops | Shop purchases during run | Lost on death |

## Resource Flow Diagram

```
┌─────────── DUNGEON RUN ───────────┐
│                                    │
│  Combat drops → Run Gold           │
│  Room rewards → Equipment          │
│  Elite kills  → Relics, Blueprints │
│  All rooms    → Troop Tokens       │
│                                    │
│  Run Gold → Dungeon Shop (items)   │
│                                    │
└──────── HERO DIES ─────────────────┘
              │
              ▼
    Gold, Relics, Troop Tokens
    Blueprints, Equipment → SAVED
              │
              ▼
┌─────────── BASE CAMP ─────────────┐
│                                    │
│  Gold + Tokens → Recruit Units     │
│  Gold + Relics → Craft Blueprints  │
│  Relics → Permanent Upgrades       │
│  Equipment → Equip Hero/Army       │
│                                    │
└────────────────────────────────────┘
              │
              ▼
┌─────────── OVERWORLD ─────────────┐
│                                    │
│  Attack territory → Battle         │
│  Win → Gold, Relics, Tokens        │
│  Lose → Unit casualties            │
│                                    │
│  Owned territories → Passive Income│
│  (per turn / per dungeon death)    │
│                                    │
└────────────────────────────────────┘
```

## Data Model

### PlayerEconomy
```
class_name PlayerEconomy extends Resource

var gold: int = 0
var relics: int = 0
var troop_tokens: int = 0

# Lifetime tracking
var total_gold_earned: int = 0
var total_gold_spent: int = 0
var total_relics_earned: int = 0
var total_relics_spent: int = 0
var total_tokens_earned: int = 0
var total_tokens_spent: int = 0
var runs_completed: int = 0
```

## Dungeon Reward Budget Per Floor

| Floor | Gold (total) | Relic Chance | Token Chance | Equipment Drops |
|-------|-------------|-------------|-------------|----------------|
| 1 | 50-80 | 10% per elite | 1-2 per floor | Common only |
| 2 | 80-120 | 15% per elite | 2-3 per floor | Common/Uncommon |
| 3 | 120-180 | 20% per elite | 3-4 per floor | Uncommon/Rare |
| 5+ | 200+ | 30%+ per elite | 5+ per floor | Rare/Epic |
| 10+ | 400+ | 50%+ per elite | 8+ per floor | Epic/Legendary |

## Recruitment Costs

| Unit | Gold | Troop Tokens |
|------|------|-------------|
| Infantry | 30 | 1 |
| Archer | 50 | 1 |
| Cavalry | 100 | 2 |
| Siege | 150 | 3 |

## Blueprint Crafting Costs

| Rarity | Gold | Relics |
|--------|------|--------|
| Common | 100 | 1 |
| Uncommon | 250 | 3 |
| Rare | 500 | 5 |
| Epic | 1000 | 10 |
| Legendary | 2500 | 25 |

## Permanent Upgrades (Relic Sink)

```
class_name PermanentUpgrade extends Resource

var upgrade_id: String
var upgrade_name: String
var description: String
var relic_cost: int
var max_level: int = 5
var current_level: int = 0
var effect_per_level: float
```

| Upgrade | Cost/Level | Effect |
|---------|-----------|--------|
| Stronger Starts | 2 relics | +5% starting HP per level |
| Gold Magnet | 3 relics | +10% gold drops per level |
| Army Training | 5 relics | +5% army stats per level |
| Lucky Finds | 4 relics | +5% rare drop chance per level |
| Deep Pockets | 3 relics | +10% passive territory income per level |

## Balance Targets

```
Average dungeon run (floor 3 death): ~150 gold, 0-1 relics, 3-5 tokens
  → Can recruit 3-5 infantry per run
  → Need ~10 runs to build a full division
  → Need ~3 full divisions to tackle a fortress

First fortress conquest: ~30 runs in
First legendary blueprint: ~50 runs in

Passive income from 5 outposts: ~125 gold + 5 tokens per turn
  → Roughly equals 1 average dungeon run
  → Territory ownership doubles effective income
```

## Anti-Exploitation Rules

- Run gold is separate from persistent gold (can't farm shops)
- Minimum run time before gold counts (prevents instant-death farming)
- Diminishing returns on same-floor farming (floor gold scales with new floors reached)
- Enemy counter-attacks drain territory if player never advances

## Interactions With Other Systems

| System | Interaction |
|--------|-------------|
| Dungeon | Primary resource generator |
| Army | Primary resource sink (recruitment) |
| Blueprints | Relic + gold sink (crafting) |
| Overworld | Passive income source, battle rewards |
| Analytics | Track income/spend rates, identify inflation/deflation |

## MVP Implementation Strategy

### MVP-1: Basic Economy
- Gold only (persistent)
- Gold drops from dungeon enemies
- Gold spent to recruit units at camp
- Simple display in UI

### MVP-2: Full Currencies
- Add relics and troop tokens
- Passive territory income
- Blueprint crafting costs
- Balance tuning pass

### MVP-3: Complete Economy
- Permanent upgrades
- Economy analytics dashboard
- Dynamic pricing based on player progression
- Anti-farming measures
