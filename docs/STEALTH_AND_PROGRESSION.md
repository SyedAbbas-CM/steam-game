# Stealth, Perks & Progression

Quick reference for what was built across these sessions.

## 1. Stealth System

Replaces the old "press C = transparent" sneak with a real stealth system.

**What it adds:**
- **Vision cones** on every enemy. Front (dot > 0.5) = full detection rate. Side (-0.25 to 0.5) = 30%. Behind (< -0.25) = 5%.
- **Noise system** (`NoiseSystem` autoload). Running, firing, and dashing emit noise to nearby enemies. Sneaking dampens it.
- **Stealth kills**. Press **E** behind an unaware enemy within 28px. Instant kill on NORMAL, 4× weapon damage on LARGE, 2× on BOSS.
- **Ambush damage**. First shot from stealth deals 2.5× damage.
- **HUD indicator** showing HIDDEN / DETECTED / ALERT and an `[E] KILL` prompt when a stealth kill is available.

**Files:**
- `scripts/systems/noise_system.gd` (autoload)
- `scripts/enemy.gd` — `_facing_dir`, `is_back_exposed()`, `get_awareness()`
- `scripts/player.gd` — `_try_stealth_kill()`, noise emission on action
- `scripts/ui/game_hud.gd` — stealth indicator + kill prompt

## 2. Stealth Test Arena

A dedicated standalone scene to actually see the stealth system work.

**How to access:**
1. Start the game → spawn in Aria.
2. Walk to the row of colored test-arena entrances near the player spawn.
3. The new **light-blue** entrance labeled **"Stealth Arena"** is the one. Press **E** to enter.

**What's inside:**
- 640×480 room with walls forming corridors and cover.
- 3 patrolling guards with **visible vision cones** (white = unaware, yellow = suspicious, red = alert).
- `?` and `!` indicators above guards as awareness ramps.

**Controls in the arena:**
- **C** — toggle sneak
- **E** — stealth kill from behind an unaware guard
- **R** — reset
- **ESC / Q** — back to overworld

**Files:**
- `scenes/test/stealth_test_arena.tscn`
- `scripts/test/stealth_test_arena.gd`
- `scripts/test/stealth_guard.gd` (standalone patrol guard with vision cone drawn in `_draw()`)

## 3. Perk Tree System

Class-locked perks with stat-gated unlocks. Currency = **perk tokens** dropped by bosses.

**Token drops:**
- First kill of any boss: **guaranteed** 1 token.
- Repeat kills of the same boss: **5% chance** of 1 token.
- Persisted via `save_data.world_flags["boss_killed_<name>"]`.

**40 perks total** (10 per class × 4 classes: Warrior / Archer / Wizard / Mercenary).

**Tier structure:**
- T1: entry-level, no requirements
- T2: needs ~5 stat points in a relevant attribute
- T3: needs ~8–10 stat points
- T4 (capstone): needs ~15 stat points + prerequisite perks

**Examples:**
- `Undying` (Warrior T4) — needs 15 VIT + Berserker + Fortified. Survive lethal hit once per dungeon at 1 HP.
- `Hawkeye` (Archer T3) — needs 10 DEX. Bullets seek nearest enemy.
- `Archmage` (Wizard T4) — needs 15 INT. Big spell power boost.
- `Bounty Hunter` (Mercenary T3) — needs 10 LCK. Extra gold from kills.

**How to access the perk tree:**
- **P key** anywhere — opens the full-screen perk tree UI.
- Talk to the **Elder NPC** in Aria → option **"Train (Perks)"** → opens the same UI in-dialogue.

**Button colors in the tree:**
- Green = unlocked
- Yellow = can unlock now (have token + meet reqs)
- Purple = stat requirement not met
- Grey = prerequisite perk not unlocked yet

**Files:**
- `scripts/stats/perk_definition.gd` (Resource definition)
- `scripts/stats/perk_manager.gd` (autoload — owns tokens, unlocked list, `unlock_blocker()`)
- `scripts/ui/perk_tree_screen.gd` (UI)
- `resources/perks/{warrior,archer,wizard,mercenary}/*.tres` (40 perks)

## 4. Stat & Level System (8 pure stats)

Level cap raised to **100**. Each level grants 1 stat point.

**8 stats, each governs one or two closely related things** (no more bundles):

| Internal | Display | Per-point |
|---|---|---|
| `health` | **HP** | +4 max HP, +0.12 HP regen |
| `defense` | **DEF** | +0.7 armor, +0.8 tenacity |
| `strength` | **STR** | +0.4 attack damage, +0.03 crit damage |
| `speed` | **SPD** | -0.002s attack interval, +2 bullet speed |
| `movement` | **MOV** | +1.2 move speed, +0.4 dodge |
| `intellect` | **INT** | +2.5 max MP, +0.12 MP regen, +0.7% CDR |
| `luck` | **LCK** | +0.8 luck, +2.5% gold, +2.5% XP |
| `endurance` | **END** | +2.5 max stamina, +0.25 stam regen, +1 pickup |

Tuned for the 100-cap: at lvl 100 with 99 points fully into STR, you get +40 damage — meaningful but not godlike vs a Wastes elite. Specialize 3 stats heavily, or spread across all 8 for a balanced build.

Old saves with the previous 6 categories (vitality/power/agility/spirit/fortune/bulk) get their points **refunded** to unspent on first load — re-allocate as you wish.

**XP curve:**
- `xp_to_next_level() = 150 + 80·(lvl-1) + 2.4·(lvl-1)²`
- Lvl 1→2: 150 XP
- Lvl 30→31: ~2500 XP
- Lvl 100 cap: ~30k XP for the final level
- Cumulative to 100: ~1M XP

**Threshold passives** (in `stat_thresholds.gd`) — passive bonuses at 5/10/15 points in a stat:
- 5 HP → Vigorous (+10% Max HP) · 10 → Hardy (+1 HP regen) · 15 → Undying (+20% Max HP)
- 5 DEF → Thick Skin (+15% armor) · 10 → Spiked (+2 thorns) · 15 → Unyielding (+15 tenacity)
- 5 STR → Heavy Hitter (+0.15 crit dmg) · 10 → Strong Arm (+10% dmg) · 15 → Crusher (+20% dmg)
- 5 SPD → Whip Crack (+10% bullet speed) · 10 → Rapid Fire (-8% atk interval) · 15 → Penetrator (+1 pierce)
- 5 MOV → Fleet Foot (+8% move) · 10 → Evasion Master (+8 dodge) · 15 → Shadow Step (+15 stealth)
- 5 INT → Mana Font (+15% Max MP) · 10 → Spell Weaver (+10% CDR) · 15 → Archmage (+1.5 MP regen)
- 5 LCK → Lucky (+15% gold) · 10 → Treasure Sense (+25 pickup) · 15 → Fortune's Child (+20% XP)
- 5 END → Stout (+25 max stamina) · 10 → Tireless (+1 stam regen) · 15 → Stalwart (+10% HP & armor)

**Files:**
- `scripts/stats/level_system.gd` (LEVEL_BONUSES, ALLOCATION_CATEGORIES, XP curve)
- `scripts/stats/stat_thresholds.gd` (5/10/15 milestone passives)
- `scripts/ui/inventory_screen.gd` (stat allocation UI with `+` buttons)

## 5. Where to Allocate Stat Points

Open the **inventory** (default I key). The attributes panel shows current points per stat with `+` buttons next to each, plus active threshold passives and a "Next: ..." line teasing the next milestone.

## 6. General (Cross-Class) Perks

15 perks any class can take if stat reqs are met. Live in `resources/perks/general/`.

| Perk | Tier | Stat Req | Effect |
|---|---|---|---|
| Regenerator | 1 | 8 VIT | +1.0 HP regen/sec |
| Treasure Hunter | 1 | 8 LCK | +25% gold |
| Marksman | 1 | 8 DEX | +25% bullet speed |
| Iron Will | 1 | 8 END | +20 tenacity |
| Spell Power | 1 | 8 INT | +10% damage, +5 max MP |
| Quickfoot | 2 | 12 DEX | +15% move speed, +10 dodge |
| Lifesteal | 2 | 12 STR | Heal 5% of damage dealt (special) |
| Magnetic | 2 | 10 LCK + 5 END | +50 pickup radius |
| Hemorrhage | 2 | 10 STR + 5 LCK | Chance to bleed on hit (special) |
| Mystic Shield | 2 | 10 INT + 5 VIT | Absorb 20% damage as MP loss (special) |
| Glass Cannon | 3 | 15 STR | +50% damage, -25% max HP |
| Wraithwalk | 3 | 15 DEX | Dash leaves shadow trail (special) |
| Pyromancer | 3 | 15 INT + 10 STR | 30% chance to ignite on hit (special) |
| Lucky Strike | 3 | 15 LCK | Crits deal 2× damage |
| Bastion | 3 | 15 END + 10 VIT | -30% damage when HP < 30% (special) |

Note: perks marked `(special)` need a player.gd hook to fully take effect (`special_effect` string is set on the perk, but the gameplay handler isn't wired yet — they appear in the UI and grant stat bonuses if any). Stat-bonus-only perks (Regenerator, Glass Cannon, Lucky Strike, etc.) work immediately.

## What happens every level-up

1. `level_system.gain_xp()` rolls level up → +1 to `unspent_stat_points`, `leveled_up` signal fires
2. `player._on_level_up()`: HP / MP / stamina all restored to max, sprite flash, level-up SFX + VFX burst
3. Floating text above the player: `LEVEL N!` and `+1 stat point (open I or P)`
4. HUD level label updates

You can spend the stat point **anywhere** — open inventory (I) or character screen (P). No NPC needed for stats.

**Perks are different.** Perks only unlock at a trainer NPC (the Aria Elder right now via the "Train (Perks)" dialog option). Opening the perk tree with **P** anywhere still shows you the tree, your tokens, requirements, and lets you allocate stat points — but the UNLOCK button is hidden, and a note reads "Visit a trainer NPC to unlock perks". Open via the Elder dialog and the unlock button appears.

The title at the top of the screen tells you which mode you're in: `CHARACTER` (stats only) or `TRAINING` (unlocks enabled).

## 7. Unified Progression UI

The perk tree screen now hosts **all** progression: stat allocation, threshold passives, and perks.

**Layout:**
- **Left panel** — ATTRIBUTES: 6 stats with `+` buttons, unspent-points counter, active threshold passives list, "Next →" preview.
- **Center** — Two tabs: `CLASS PERKS` (your class's 10 perks) / `GENERAL PERKS` (the 15 cross-class).
- **Bottom-center** — Description panel showing the selected perk's effect, stat requirements, prerequisites, and (if locked) the specific blocker reason.

You can spend stat points and unlock perks from the same screen. Allocating a stat may unlock perks gated on that stat.

## Over-Level Penalty & Hyper Elites

When the player out-levels a dungeon's `recommended_level` by more than 5, enemy scaling gets an extra boost on top of the base `effective_level` scaling:
- `+8% HP per overlevel point past 5`
- `+5% damage per overlevel point past 5`

Additionally, ELITE rooms have a chance to promote their enemy to a **Hyper Elite** (named "Hyper X") with super_elite stats: BOSS size, 3 phases, more bullets, more armor, +50% extra HP, triple XP. The promotion chance is `min(overlevel × 5%, 50%)`.

Example: player lvl 20 in Haven-Dungeons (rec_level 1) → overlevel = 14, every elite has a 50% chance to be a Hyper Elite.

## 8. Buying Perk Tokens

Every shop now stocks a **"Perk Token"** entry at the bottom of the buy list. Costs **500 gold** per token. Buying it directly increments `PerkManager.perk_tokens` (no inventory slot taken). This is a testing convenience that lets you try perks without grinding bosses.

## 9. Special-Effect Handlers (now wired)

All 6 previously-pending perk specials now have gameplay handlers + visuals. **Each can also be obtained as an item enchantment** — equipped gear with the matching enchantment grants the same effect even without the perk.

| Effect | Trigger | Visual | Item enchant |
|---|---|---|---|
| **lifesteal** | On enemy hit, heal 5% of damage | Crimson blood splatter at enemy | `VAMPIRIC` |
| **hemorrhage** | 30% chance on hit → POISONED 4s | Bright-red blood splatter | (use `POISON`) |
| **pyromancer** | 30% chance on hit → BURNING 3s | Fire status puff | (use `FIRE`) |
| **mystic_shield** | Divert 20% incoming dmg to MP | Blue shockwave + "−N MP" text | `MYSTIC` (new) |
| **bastion** | −30% dmg when HP < 30% | Gold shockwave on hit | `BULWARK` (new) |
| **wraithwalk** | Dash spawns 22px damaging trail (1.5s) | Purple shadow puff | `WRAITH` (new) |

**Unified accessor** in `player.gd`: `_has_effect(name)` returns true if either `PerkManager.has_special(name)` OR any equipped item has the matching enchantment. All 6 handlers route through this check, so a player wearing a Mystic helm gets mystic_shield even without the perk — and stacking perk + enchant works the same way (the effect just fires once per hit, no double-dipping).

**New enchant types** added to `ItemEnchantment.EnchantType`: `BULWARK`, `MYSTIC`, `WRAITH`. Prefix names: "Bulwark Helm of Bone", "Mystic Robe of Light", "Wraith Boots of the Hunt". Colors: gold/blue/purple.

## Hall of Souls — Permanent Upgrades (new)

Shrine of Souls now offers **12** permanent upgrades (was 2). Bought with Soul Points earned on death:

| Upgrade | Caps | Effect |
|---|---|---|
| Gold Retention | 5 | Keep more gold from dead hero |
| Legacy Vault | 3 | +2 vault capacity / rank |
| Soul Anchor | 3 | New heir starts +1 level / rank |
| Heroic Vigor | 10 | New heir +5 max HP / rank |
| Heroic Might | 10 | New heir +1 attack damage / rank |
| Veteran's Stipend | 5 | New heir +50 gold / rank |
| Heart of Embers | 5 | Permanent +0.1 HP regen / rank |
| Apothecary's Gift | 3 | New heir +1 Red Potion / rank |
| Free Stat Points | 5 | New heir +2 unspent stat points / rank |
| Perk Token Carryover | 3 | New heir +1 perk token / rank |
| Avarice | 5 | Permanent +5% gold gain / rank |
| Ancestral Wisdom | 5 | Permanent +5% XP gain / rank |

Bonuses apply on first heir spawn via `_give_starting_items()` and `_apply_class_stats()`.

## Class Combat Updates

**Wizard** (was glass cannon, too short-ranged):
- Base HP 25 → **32**
- Base speed 85 → **95**
- Bullet speed 90 → **140** (much longer effective range)
- Attack interval 0.40 → **0.35**
- Preferred range 50 → **90**
- Starters: `frost_nova` → **`frost_nova + heal + mana_shield`**

**Archer** (needed more range/power):
- Bullet speed 120 → **160**
- Attack interval 0.25 → **0.22**
- Preferred range 60 → **120**
- Starters: `arrow_rain` → **`arrow_rain + evasion_surge + heal`**

**Warrior** starters: `shield_bash` → **`shield_bash + iron_skin`**
**Mercenary** starters: `battle_cry` → **`battle_cry + berserk`**

**Class-id alias** fixed: `class_required = "archer"` perks now correctly recognize the `selected_class = "ranger"` player (long-standing bug).

## New Perks — 19 added

**General (7 new):** Berserker Frenzy, Soul Siphon, Adrenaline, Vengeful, Phoenix, Lightning Reflexes, Static Charge.

**Warrior (3):** Cleaving Strikes, Last Stand, Battle Hardened.
**Archer (3):** Trick Shot, Hunter's Mark, Volley Master.
**Wizard (3):** Arcane Echo, Frostfire, Mind Burn.
**Mercenary (3):** Gun and Run, Dual Specialist, Bountiful Catch.

**Wired to gameplay this pass:** soul_siphon, frenzy, adrenaline, vengeful, last_stand, phoenix (+ all 6 from prior pass).

**Pending wiring (UI works, stat bonuses apply, special effect dormant):** cleave, trick_shot, hunters_mark, arcane_echo, frostfire, mind_burn, gun_run, dual_spec, lightning_reflex, static_charge.

## Balance Pass — Less Spongey + Class Combat Fixes

**Enemy scaling cut globally:**
- `level_scale` coefficient: `0.15 → 0.10` (33% lower HP scaling)
- `dmg_scale` coefficient: `0.08 → 0.05`
- Boss `enemy_hp_mult`: 5.0 → 3.5
- Super-elite `enemy_hp_mult`: 6.0 → 4.5
- Elite `enemy_hp_mult`: 4.0 → 3.0

Example: Bone Golem at lvl 1 was 1430 HP scaled. Now `220 × 3.5 × 1.2 = 924` HP. Wizard with `minor_heal` and new starter spread will actually clear it without an 8-minute fight.

**Warrior dash** now trades invuln for offensive impact:
- Vulnerable while dashing
- Collision with enemy or wall ends dash early
- On end: 32px AoE around player — `2× weapon damage + level*0.5`, knockback, 0.8s stun, shockwave VFX, screen shake
- Mercenary dash unchanged (still full invuln)

**Warrior shield (R)** = TOGGLE now (was hold). Press to raise, press again to lower.

**Shield Bash** spell: mp_cost `15 → 6`, cooldown `5s → 4s`. Still 2.5× weapon damage cone + knockback + 1.5s stun.

**Wizard kit overhaul:**
- New starter spells: **`minor_heal + bullet_shield + frost_nova`**
- **Minor Heal**: +8 HP + level, 5 MP, 2.5s cooldown — quick top-up
- **Bullet Shield**: absorbs next 4 incoming bullets, 12s window, 14 MP, 14s cooldown
- Heal scroll: new `Scroll of Heal` item (120g, sold at Haven magic shop) teaches the full Heal spell

## 10. Status of Everything

**Built:**
- Stealth + test arena (light-blue entrance near Aria spawn)
- 40 class perks + 15 general perks, all stat-gated
- 8-stat system tuned for lvl 100 cap with save migration
- Threshold passives at 5/10/15 in each stat (24 total)
- XP curve to 1M cumulative at lvl 100
- Unified perk-tree UI (P key for stats / Elder for perk unlocks)
- Boss tokens (1st kill guaranteed, 5% on repeats) + 500g shop token
- Hyper Elites on overlevel + extra stat scaling
- Level-up floating text ("+1 stat point (open I or P)")
- All 6 special perks wired with visuals + item-enchant equivalents

**Pending (small):**
- `hall_of_ancestors.gd:274` references undefined `CLASS_COLORS` (pre-existing, unrelated)
- More trainer NPCs (currently only Aria Elder)
- Playtest pass on per-stat values

## Quick Test Recipe

1. New game → spawn in Aria.
2. Walk to test arenas → enter **Stealth Arena** (light blue tile).
3. Sneak around guards, try a stealth kill from behind.
4. Exit back to Aria.
5. Talk to the Elder → "Train (Perks)" to see the perk tree.
6. Open inventory (I) to allocate stat points and see threshold passives.
