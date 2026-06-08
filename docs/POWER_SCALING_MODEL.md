# Power Scaling Model

Reference for tuning dungeon `recommended_level`, item drop tiers, and enemy stats. Built from the current code state.

## 1. Sixteen Variables That Affect Player Power

Every player's effective combat power is the product of these. Treat them as **multiplicative groups** for sanity:

### Base layer (class identity)
1. **Class base stats** — HP, MP, move speed, base damage, weight, acceleration, tenacity, thorns
2. **Starter spells** — class-specific abilities (warrior shield_bash, wizard minor_heal/bullet_shield/frost_nova, archer arrow_rain/evasion_surge/heal, merc battle_cry/berserk)

### Growth layer (per-character)
3. **Level (1-100)** — small per-level auto-gains (+1 HP, +0.06 attack, etc.)
4. **Stat allocation (1 pt/lvl → up to 99)** — 8 stats × per-point bonus (e.g. STR +0.4 attack/pt)
5. **Threshold passives** — auto-unlock at 5/10/15 in each stat (24 total)
6. **Perks** — gated by stat reqs + perk token cost (40 class + 19 general = 59)
7. **Weapon scaling** — `final_damage = (base + alloc) × (1 + scaling_pts × 0.08)`

### Gear layer (drops + shops)
8. **Weapon flat damage** — rarity 0: +1-2, rarity 1: +3-4, rarity 2: +6-10, rarity 3: +5 (with special effects)
9. **Weapon modifiers** — bullet_count, attack_speed, crit, pierce
10. **Armor flat + percent** — leather, chain, plate tiers
11. **Rings / amulets** — flat stat bonuses (luck, HP, etc.)
12. **Ammo** — bonus damage per shot (arrows, bolts)
13. **Shield charges** — block tier, parry window
14. **Item enchantments** — 11 types (FIRE/ICE/POISON/LIGHTNING/HOLY/DARK/VAMPIRIC/EXPLOSIVE/BULWARK/MYSTIC/WRAITH)
15. **Sockets** — additional embedded modifiers

### Meta layer (cross-run)
16. **Hall of Souls upgrades** — 12 permanent upgrades (Heroic Vigor, Heroic Might, Heart of Embers, Avarice/Wisdom mult, Soul Anchor starting lvl, Perk Token Carryover, Free Stat Points, etc.)

## 2. Stat Formula Recap

```
final_stat = (base + level_bonus + alloc_bonus + perk_flat + equip_flat + threshold_flat)
             × (1 + threshold_percent + perk_percent + equip_percent)

final_damage_per_hit = final_attack_damage × (1 + scaling_pts × 0.08)

DPS = final_damage_per_hit × bullet_count / attack_interval
       × (1 + crit_chance × (crit_damage - 1))
       × (1 + status_buff_multipliers)
       + on_hit_proc_damage_average
```

## 3. Player DPS Curve (modeled, sword-type build, full STR spec)

| Lvl | STR pts | Threshold | Weapon | Attack | Per-hit | Bullets | Int | DPS |
|---|---|---|---|---|---|---|---|---|
| 1  | 0  | — | Starter sword +3 | 3 | 3.0 | 3 | 0.35s | **25.7** |
| 5  | 4  | — | Same | 3+1.6=4.6 → 5.5×(1.32)=7.3 | 7 | 3 | 0.35s | **60** |
| 10 | 9  | 5 STR Heavy Hitter | Steel Axe +2 | 2+3.6=5.6×1.72 = 9.6 +crit | 11 | 3 | 0.35s | **94** |
| 15 | 14 | 10 STR Strong Arm +10% | Warblade +4 | 4+5.6=9.6×2.12 = 20.4×1.10 = 22 | 22 | 3 | 0.32s | **206** |
| 25 | 24 | 15 STR Crusher +20% | Ravager +4 | 4+9.6=13.6×3.0 = 40.8×1.30 = 53 | 53 | 3 | 0.30s | **530** |
| 50 | 49 | All caps + 5 perks | Sword of Nivek +6 | 6+19.6=25.6×4.9 = 125×1.5 = 188 | 188 | 4 | 0.27s | **2,785** |
| 75 | 74 | + Glass Cannon +50% | Worldsplitter +5 (legendary) | 5+29.6=34.6×6.9 = 239×2.0 = 478 | 478 | 4 | 0.25s | **7,648** |
| 100 | 99 | Capstone stacks | Top legendary +5 | 5+39.6=44.6×8.9 = 397×2.5 = 993 | 993 | 5 | 0.22s | **22,568** |

DPS roughly **doubles every 10 levels** through the curve thanks to the multiplicative stacks (alloc + weapon scaling + threshold + perks).

## 4. Enemy HP Curve at Intended rec_level

Boss HP = `base × 3.5 (boss_mult) × level_scale`, where `level_scale = 1 + (rec_lvl + player_lvl) × 0.10`. Assume player_lvl = rec_lvl.

| rec_lvl | level_scale | Risen Corpse (32) | Boss (220 base) | Boss/player DPS | TTK |
|---|---|---|---|---|---|
| 1  | 1.20 | 38   | **924**   | 26 | 36s |
| 5  | 2.00 | 64   | 1,540    | 60 | 26s |
| 10 | 3.00 | 96   | 2,310    | 94 | 25s |
| 15 | 4.00 | 128  | 3,080    | 206 | 15s |
| 25 | 6.00 | 192  | 4,620    | 530 | 9s |
| 50 | 11.00 | 352  | 8,470    | 2,785 | 3s |

**The curve shape**: dungeons feel **hardest at the start** (Haven-Dungeons rec_1 with 26 DPS vs 924 HP = 36s boss). As the player progresses, threshold passives + perks + weapon scaling multiply faster than enemy HP scales. By rec_50, a fully-built character is one-shotting trash and dropping bosses in seconds.

## 5. Where the Curve Breaks

### Early underpower (lvl 1–5)
- 1 stat point/level, no thresholds yet, base weapons cap at +2-3 damage
- Wizard particularly weak (1 bullet, no melee)
- **Mitigations active**: Hall of Souls Heroic Vigor (+HP), Heroic Might (+dmg), Apothecary's Gift (potions), Soul Anchor (start at lvl 2-4 instead of 1), Free Stat Points (jumpstart allocations)

### Mid-game gear gap (lvl 15–30)
- The jump from rarity-0 weapons (+1-2 dmg) to rarity-1 (+3-4) doubles your damage curve, but those weapons are quest-locked (sold in shops with `required_quest` flags)
- If quest progress stalls, player DPS plateaus while dungeon HP keeps growing
- **Suggested fix** (not yet applied): scatter a few rarity-1 weapons into mid-tier dungeon drop tables so progression isn't 100% quest-gated

### Late-game runaway (lvl 50+)
- Multiplicative stacks let DPS grow exponentially while enemy HP grows linearly
- By lvl 75 with capstone perks, a fully-built warrior is at ~7,648 DPS vs a rec_50 boss at ~8,470 HP — kills in 1.1s
- **Hyper Elite system** (already in place) partially compensates by promoting elites in over-leveled content
- **Suggested**: add prestige/Nightmare modes that multiply enemy HP × 3-5 for endgame replay

## 6. Recommended Dungeon Tiering

What the player should have at each `recommended_level` for the dungeon to feel right:

| rec_lvl range | Player level | Expected gear | Expected perks | Threshold passives |
|---|---|---|---|---|
| 1-3 (Haven 1-2) | 1-3 | Starter | 0-1 | None |
| 4-7 (Haven 3, Plains, Dusk) | 4-7 | Rarity 0 (+2 dmg) | 1-2 | 5 STR/HP tier |
| 8-12 (Wastes, Shroud, Ashvale) | 8-12 | Rarity 0-1 mix | 2-4 | 10 STR/HP tier |
| 13-18 | 13-18 | Rarity 1 (+3-4 dmg) | 4-6 | 15 STR + one secondary |
| 19-25 | 19-25 | Rarity 1-2 mix | 6-8 | 15 in 2 stats |
| 26-35 | 26-35 | Rarity 2 (+6-10 dmg) | 8-12 | 15 in 3 stats |
| 36-50 | 36-50 | Rarity 2-3 mix | 12-18 | All caps in 2-3 stats |

Dungeons should drop loot 1 tier higher than rec_level on average (so finishing a rec_5 dungeon gives gear suitable for rec_6-8).

## 7. Variables To Tune If Balance Feels Off

Listed in **order of blast radius** (smallest first):

1. **Specific dungeon `recommended_level`** — moves one dungeon's difficulty band
2. **Boss base HP** in a specific `enemy.tres` — affects that enemy in all contexts
3. **Boss `enemy_hp_mult`** in `floor_generator.gd` — affects all boss rooms globally (currently 3.5)
4. **`level_scale` coefficient** in `dungeon_manager.gd` — affects ALL enemies (currently 0.10)
5. **`overlevel` formula** — affects scaling when player out-levels content (currently kicks in at +5 levels)
6. **Stat allocation per-point** in `LevelSystem.ALLOCATION_CATEGORIES` — affects player power across all levels
7. **Weapon flat damage in .tres** — affects gear curve
8. **Hall of Souls upgrade magnitudes** — affects starting power across runs

## 8. Open Questions for Playtesting

- Is mid-tier (lvl 15-25) gear progression too quest-locked? Need more dungeon drops.
- Does Wizard get enough power scaling without spec-into-STR? Staff scales with INT — currently INT only gives +2.5 MP per pt, no damage. May need INT to scale staff damage too.
- Does the Hall of Souls Soul Anchor (1 retained level/rank) feel meaningful, or too small?
- Are the new BULWARK/MYSTIC/WRAITH enchants generating on dropped items? (Currently no — need to add to loot pool.)
