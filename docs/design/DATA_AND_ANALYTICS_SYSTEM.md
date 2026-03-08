# Data & Analytics System

## Purpose
Track gameplay metrics to feed future AI balancing, identify fun/pain points, and guide content design. Every system emits events; the analytics pipeline stores and aggregates them.

## Event Architecture

```
┌──────────┐    ┌──────────────┐    ┌─────────────┐
│  SYSTEMS │───→│ AnalyticsHub │───→│  DataStore  │
│ (signals)│    │  (singleton) │    │ (JSON/file) │
└──────────┘    └──────────────┘    └─────────────┘
                       │
                       ▼
                ┌──────────────┐
                │  Aggregator  │
                │  (summaries) │
                └──────────────┘
```

### AnalyticsHub (Autoload Singleton)
```
class_name AnalyticsHub extends Node

var current_run: RunAnalytics
var lifetime_stats: LifetimeAnalytics

signal event_logged(event_name: String, data: Dictionary)

func log_event(event_name: String, data: Dictionary = {}) -> void:
    data["timestamp"] = Time.get_ticks_msec()
    data["run_id"] = current_run.run_id if current_run else ""
    event_logged.emit(event_name, data)
    _append_to_store(event_name, data)
```

## Tracked Events

### Dungeon Events

| Event | Data Fields | Purpose |
|-------|------------|---------|
| `run_started` | run_id, hero_build | Track run frequency |
| `run_ended` | run_id, floor_reached, time_seconds, cause_of_death, gold_earned, relics_earned | Core performance metric |
| `room_entered` | room_type, floor, room_index | Room progression analysis |
| `room_cleared` | room_type, time_seconds, damage_taken | Difficulty assessment |
| `enemy_killed` | enemy_type, weapon_used, mutations_active | Build effectiveness |
| `reward_chosen` | reward_type, reward_id, alternatives_offered | Player preference |
| `mutation_picked` | mutation_id, alternatives_offered, current_mutations | Build meta tracking |
| `item_equipped` | item_id, slot, replaced_item_id | Equipment preference |
| `player_damaged` | amount, source_type, current_hp | Difficulty/balance |
| `companion_died` | companion_type, floor, room | Companion balance |

### Economy Events

| Event | Data Fields | Purpose |
|-------|------------|---------|
| `gold_earned` | amount, source | Income tracking |
| `gold_spent` | amount, sink, item_id | Spend tracking |
| `relic_earned` | amount, source | Rarity tracking |
| `unit_recruited` | unit_type, cost | Army building pace |
| `blueprint_crafted` | blueprint_id, cost | Crafting engagement |

### Battle Events

| Event | Data Fields | Purpose |
|-------|------------|---------|
| `battle_started` | territory_id, player_divisions, enemy_divisions | Army composition |
| `battle_ended` | territory_id, victory, casualties, formations_used | Formation effectiveness |
| `territory_conquered` | territory_id, total_owned, turn_number | Conquest pace |
| `territory_lost` | territory_id, counter_attack | Difficulty spike detection |

## Data Models

### RunAnalytics
```
class_name RunAnalytics extends Resource

var run_id: String
var start_time: int
var end_time: int
var duration_seconds: float

# Performance
var floors_cleared: int = 0
var rooms_cleared: int = 0
var enemies_killed: int = 0
var damage_dealt: int = 0
var damage_taken: int = 0
var deaths: int = 0  # companion deaths

# Build
var weapon_used: String = ""
var armor_used: String = ""
var artifact_used: String = ""
var core_module_used: String = ""
var mutations_acquired: Array[String] = []
var companions_used: Array[String] = []

# Economy
var gold_earned: int = 0
var relics_earned: int = 0
var troop_tokens_earned: int = 0

# Death
var cause_of_death: String = ""
var death_floor: int = 0
var death_room_type: String = ""
```

### LifetimeAnalytics
```
class_name LifetimeAnalytics extends Resource

var total_runs: int = 0
var total_play_time_seconds: float = 0.0
var best_floor_reached: int = 0
var total_enemies_killed: int = 0
var total_gold_earned: int = 0
var total_relics_earned: int = 0
var territories_conquered: int = 0
var fortresses_conquered: int = 0
var blueprints_discovered: int = 0

# Frequency maps
var weapon_usage: Dictionary = {}       # weapon_id -> times_used
var mutation_pick_rates: Dictionary = {} # mutation_id -> times_picked
var companion_usage: Dictionary = {}    # companion_type -> times_used
var formation_usage: Dictionary = {}    # formation_id -> times_used
var cause_of_death_freq: Dictionary = {} # cause -> count
var enemy_kill_counts: Dictionary = {}  # enemy_type -> count
```

## Aggregation Queries

### Build Archetype Detection
```
func detect_build_archetype(run: RunAnalytics) -> String:
    var tags: Array[String] = []
    for mutation_id in run.mutations_acquired:
        var mutation = MutationRegistry.get(mutation_id)
        tags.append_array(mutation.tags)

    var tag_counts = count_tags(tags)
    var dominant = get_max_key(tag_counts)

    match dominant:
        "fire": return "pyromancer"
        "ice": return "frost_mage"
        "speed": return "speedster"
        "heal": return "sustain_tank"
        "crit": return "glass_cannon"
        _: return "generalist"
```

### Difficulty Assessment
```
func assess_floor_difficulty(floor: int) -> Dictionary:
    var runs_reaching_floor = get_runs_reaching_floor(floor)
    var runs_dying_on_floor = get_runs_dying_on_floor(floor)

    return {
        "floor": floor,
        "reach_rate": float(runs_reaching_floor) / total_runs,
        "death_rate": float(runs_dying_on_floor) / max(1, runs_reaching_floor),
        "avg_time_on_floor": get_avg_time_on_floor(floor),
        "avg_damage_taken": get_avg_damage_taken_on_floor(floor)
    }
```

### Equipment Popularity
```
func get_equipment_rankings() -> Array[Dictionary]:
    var rankings: Array[Dictionary] = []
    for item_id in weapon_usage:
        rankings.append({
            "item_id": item_id,
            "pick_rate": weapon_usage[item_id] / total_runs,
            "avg_floor_reached": get_avg_floor_with_item(item_id),
            "win_rate_with": get_win_rate_with_item(item_id)
        })
    rankings.sort_custom(func(a, b): return a["pick_rate"] > b["pick_rate"])
    return rankings
```

### Formation Effectiveness
```
func get_formation_stats() -> Dictionary:
    var stats: Dictionary = {}
    for fid in formation_usage:
        stats[fid] = {
            "times_used": formation_usage[fid],
            "win_rate": get_formation_win_rate(fid),
            "avg_casualties": get_formation_avg_casualties(fid)
        }
    return stats
```

## Storage Strategy

### MVP: Local JSON
```
Save path: user://analytics/
Files:
  lifetime_stats.json     # Aggregated lifetime data
  runs/run_{id}.json      # Per-run detailed data (keep last 50)
  events.jsonl            # Append-only event log (rotate at 10MB)
```

### Future: Remote
- Firebase Analytics or custom backend
- Batch upload on WiFi
- Anonymized aggregate dashboards
- A/B testing framework

## Future AI Balancing Hooks

The analytics data is structured to feed automated balancing:

```
# Input to balance AI:
- Floor death distribution → adjust difficulty curve
- Mutation pick rates → buff underpicked, nerf overpicked
- Weapon win rates → rebalance weapon stats
- Formation effectiveness → adjust formation multipliers
- Territory conquest pace → tune garrison difficulty
- Economy inflation rate → adjust reward amounts
```

## Interactions With Other Systems

| System | Events Emitted |
|--------|---------------|
| Dungeon | run_started/ended, room events, enemy kills |
| Equipment | item_equipped, reward_chosen |
| Mutations | mutation_picked |
| Companions | companion usage, companion deaths |
| Economy | all currency transactions |
| Army | battle events, recruitment |
| Overworld | territory conquest/loss |

## MVP Implementation Strategy

### MVP-1: Run Summary
- Log run_started, run_ended
- Track floors_cleared, enemies_killed, gold_earned
- Display "run summary" screen on death
- Save lifetime best stats

### MVP-2: Full Tracking
- All event types logged
- Per-run detailed analytics saved
- Lifetime frequency maps
- Death analysis screen

### MVP-3: Aggregation
- Build archetype detection
- Difficulty assessment per floor
- Equipment/mutation rankings
- Export functionality for external analysis
