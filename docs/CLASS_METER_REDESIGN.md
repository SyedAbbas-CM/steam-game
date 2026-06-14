# Class Meter Redesign

Date: 2026-06-10

## Problem

Rage / Mana Flow / Focus / Adrenaline currently all do the same thing (small passive % damage scaling) with the same build pattern (kills + a class-specific event). They don't translate into class identity — the bar fills, the damage ticks up a tiny amount, and the player can't tell what changed. The bar feels like decoration.

The full-meter X-key signature moves help, but the *uptime ramp* is empty filler.

## New design — one identity per meter

### Warrior — Rage (defensive → offensive)

**Build**: Gained on **damage taken** (not kills).
- +0.25% rage per HP of damage taken, with a 0.5s grace so each hit only counts once.
- Killing tougher enemies = some bonus (+2%).
- No build on basic kills — Rage is about absorbing punishment.

**Active effects (passive ramps)**:
- Per-rage scaling: dash + warrior dash-burst AoE deals `+0.4% damage per stack`.
- Per-rage scaling: weapon damage `+0.3% per stack` (current — kept).
- Spell rage-fuel: when casting **Iron Skin** or **Shield Bash**, MP cost reduced 1:1 by current rage. At 100 rage, those spells cost 0 MP.

**X (Full meter)**: **Blood Dream** — 30s vampiric trance.
- On cast: snapshot current HP ("banked HP").
- Set live HP to max (full bar for the duration).
- All damage you deal heals you (1:1 lifesteal on weapons + spells), capped at ~30% max HP per second so AoE can't insta-refill.
- **You can die during Blood Dream.** No safety net. Temp HP hits 0 → dead.
- After 30s (if you survive): live HP is overwritten back to banked HP (regardless of where the temp bar ended up).
- **End-of-trance backlash**: on expiry you are **paralyzed for 3s** and **slowed for 6s**. Plan an exit route before the timer runs out — the trance ends in a dangerous spot if you don't.
- Rage drops to ~20% (not zero — a small head start).

> **Design notes**
> - The risk is real: die during the trance OR get caught in the open at expiry. The reward is 30s of effective invulnerability + huge lifesteal.
> - Lifesteal cap at 30%/sec prevents a single Shield Bash from refilling the bar entirely.
> - Live HP during the trance can't exceed max (no overheal stacking).

### Mercenary — Adrenaline (combo flow)

**Build**: Crits + parries + kills.
- +1 per critical hit landed
- +5 per successful parry (any type)
- +2 per kill

**Active effects (passive ramps)**:
- Per-stack passive **fire rate** boost. Target: **+50% fire rate at 100 stacks** (so `+0.5% per stack`). Empty bar = baseline weapon speed; full bar = 1.5× rate of fire. Replaces the old damage scaling.
- Small passive crit chance: `+0.15% per stack` (max +15% — feeds into more crits and more meter).

> **Design note**: do NOT nerf the merc's baseline weapon fire rate to "make room" for the +50%. Empty bar must still feel responsive; the meter is a *ramp on top*, not a *recovery to normal*.

**X (Full meter)**: **Reckless Strike** — 30s coin-flip mode. Consumes meter.
- +50% fire rate (additive on top of the meter's own ramp).
- +50% evasion (dodge chance).
- **+100% damage taken** (landed hits do 2× damage — the real cost).
- 5% chance per hit to stun the target for 0.5s.
- Refills stamina on cast (keeps dash/parry economy alive).

> **Design notes**
> - **Defensive math is break-even, variance is huge**: 50% evade × 2× landed = 1.0× expected damage = no net safety. Per-hit it's 50/50 you eat 2× or shrug. You'll feel like a god some runs, die some runs. That's the design.
> - **Stun chance**: at high fire rate (~6 shots/sec), 5% stun = ~1 stun every 3 seconds. 10% would chain-CC enemies and feel cheap. Stay at 5%.
> - **30s duration is justified** because there's zero average defensive bonus — the variance can absolutely kill you. The offensive ramps are the reason to press X.

### Archer — Focus (build by staying clean, spend on Killshot)

**Revised direction** — *not* the inverted-drain model. Focus is a **resource you build by surviving combat untouched**, then **spend** on Killshot.

**Build**:
- Starts at 0 each combat.
- **In combat, no damage taken for 1s** → +6/sec passive regen.
- **Standing still + not shooting** in combat → +12/sec (the "aim down sights" feel).
- Kills: +5 each (rewards quick eliminations).
- Out of combat: drains back to 0 over ~10s (Focus is a *combat* resource, not a hoard).

**Penalty for taking damage** (the punishment):
- Each damage instance: lose **15% of max focus** immediately.
- **3-second lockout** on all regen after taking damage. Kills during the lockout still grant their +5 (so you can punch through aggressors).

**Passive bonuses while focus is high**:
- **At focus ≥ 75%**: +20% bullet range, +20% bullet speed (faster, longer shots — the "long shot" feel).
- **At focus 50–74%**: +10% bullet range, +10% bullet speed.
- **At focus < 50%**: no passive bonus, no penalty (baseline).

> **Design note**: dropped the move-speed and miss-chance penalties from the earlier draft — move speed felt wrong as the gating stat and a miss-chance penalty punishes the player twice (already lost focus). The new model is purely *rewards on the upside, no debuffs on the downside*.

**X (Full meter)**: **Killshot** — consumes focus, fires one **medium-speed guaranteed crit** shot that pierces 3 enemies.
- Damage scales with focus spent: `damage_mult = 3× + (focus_spent / 100) × 2×`.
  - At 60 focus: 4.2× damage (the minimum viable shot).
  - At 100 focus: 5× damage (the full payoff).
- Costs **all current focus** to fire — empties the bar.
- Available at focus ≥ 60.

> **Design notes**
> - Scaling damage makes "when do I fire?" a real choice: rush a 4.2× to clear a wave, or hold for the 5× boss-deleter.
> - "In combat" for the regen check = any enemy aggro'd within 600px.
> - 12/sec stationary regen sounds fast, but archers can't move-shoot anyway. Rewards positioning over kiting.

### Wizard — Mana Flow (spell upgrade resource)

The old "ramp on cost reduction + spell damage" is invisible to the player. New direction: Mana Flow is a **resource you spend to upgrade individual spells** at cast time. Every spell has a base form and an empowered form, and the meter decides which fires.

**Build**:
- +4 per spell cast (any spell).
- +2 per enemy killed by spell damage.
- +1/sec passive while MP > 50% (rewards conservative casting).

**Mechanic — empowered cast**:
- When you cast a spell with Mana Flow ≥ the spell's empowerment cost, the spell consumes that cost from the meter *in addition to* its MP cost and fires its **empowered form**.
- If the meter is below the empowerment threshold, the spell fires its base form normally.
- The player sees both versions in the spellbook UI ("Fireball: 20 MP / Empowered: 20 MP + 40 Mana Flow → +AoE + Burn").

**Per-spell empowerment examples** (existing spells — final list designed alongside Phase 1 work):
- **Fireball**: base AoE 50px → empowered 90px AoE + leaves a burn patch for 3s.
- **Frost Nova**: base 120px radius freeze → empowered 200px + chills surviving enemies for 4s after thaw.
- **Heal**: base self-heal → empowered AoE around the caster + small overheal shield.
- **Chain Lightning**: base 3 jumps → empowered 6 jumps + each jump triggers a small stun.
- **Iron Skin** (warrior, but if we extend the pattern): base damage reduction → empowered also reflects 20% of blocked damage.

**X (Full meter)**: **Overflow** — 6s "free empowerment" mode.
- All spells cast during Overflow fire empowered for free (no MP, no Mana Flow drain).
- Spell cooldowns tick at 3× speed during Overflow.
- Consumes the full meter on activation.

**New spells designed for this system** (to be specced in Phase 1.5 — separate doc):
- Spells whose *base form is weak but useful for cycling* (low MP, builds Mana Flow), so the wizard's playstyle is "thread the bar up to power the big empowered cast."
- At least 2 new spells where empowered form is a *fundamentally different effect*, not just "bigger numbers" (e.g. base = single-target nuke, empowered = chain reaction across the room).

> **Design notes**
> - This makes Mana Flow *visible*: cast → see number drop → spell looks different. No invisible buff stacks.
> - We design new spells with this binary (base / empowered) in mind from the start — the playbook is "what does this spell become when it's hungry for meter?"
> - Overflow lets the wizard dump the whole bar for ~6s of all-empowered everything. Existing Arcane Surge gets renamed/repurposed into this.
> - Empowerment cost per spell will need a balance pass — cheaper for utility (~25), more for damage (~40), highest for game-changers (~60).

## UI revamp (Phase 2, next pass)

Currently HP orb (left) + MP orb (right), class meter bar at bottom. New idea:

- **Left**: HP orb with stamina ring around it (current — keep).
- **Right**: **Class meter orb** with MP ring around it.
  - The orb fill = class meter % (red / blue / green / amber depending on class).
  - The ring around it = MP (current value vs max).

This visually elevates the class meter to a primary HUD element. MP becomes a secondary stat displayed as a ring — appropriate since MP is just a spell budget, while the class meter actively shapes how you play.

The 540px-wide horizontal bar above the quickbar gets removed in Phase 2.

## Implementation plan

**Phase 1 (this pass)**: rewire mechanics per class
- Replace `on_enemy_killed_for_massacre` meter rules per class
- Add damage-taken hook for Warrior Rage
- Add critical-hit signal hook for Mercenary
- Archer focus build loop in `_physics_process` (regen-when-clean + stationary bonus + damage penalty + lockout timer)
- Add fire-rate buff path for Mercenary stack scaling
- Add bullet-range / bullet-speed bonus path for Archer high focus
- Rage spell-fuel hooks in `_ability_iron_skin` and `_ability_shield_bash`
- Blood Dream: HP-bank state, lifesteal flag, 30s timer + restore, rage reset to ~20%
- Reckless Strike rewrite: fire rate / evasion / damage-taken / stun-chance buffs + duration timer
- Killshot rewrite: 60-focus minimum, damage scales with focus spent, drains bar on fire
- Mana Flow: damage/cost/cooldown ramps + Overflow X-key + on-screen cost preview

**Phase 2 (next pass)**: UI rework
- Swap MP orb → class meter orb
- Add MP as a ring around the new orb
- Remove the bottom horizontal class meter bar
- Animate class meter orb fill changes
- Spell-cost preview text near spell icons (Mana Flow legibility)

## Open questions (consolidated)

- **Mana Flow build rate**: +4/cast + 2/kill + 1/sec — needs tuning so a 100 bar takes ~30s of active casting, not 10s and not 60s.
- **Empowerment costs per spell**: balance pass needed (utility ~25, damage ~40, game-changers ~60).
