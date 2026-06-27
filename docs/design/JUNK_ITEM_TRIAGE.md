# Junk Item Triage (Phase 3)

Date: 2026-06-27. Branch: `polish-pass`.

Audit of LoY-origin items the tester / playtest doc flagged as "random as hell"
plus a structured scan of MATERIAL / CONSUMABLE / weapon-type-mismatch items.
Verdict column is my recommendation; you override on the right-hand column.

## How to use this file

Three columns matter: **Triage** is my suggestion; **Decision** is yours; **Notes**
is anything you want to say to me before I batch-apply.

After you've gone through:
- `keep`        — item stays demo-approved as-is.
- `flag`        — `demo_approved = false` so it doesn't drop in the demo loot pool
                  but stays in the codebase. Easiest reversible move.
- `fix-desc`    — keep but I should write a real description / set a sprite.
- `fix-stat`    — keep but stats look wrong; I'll tune.
- `delete`      — wipe the .tres file entirely. Only choose this for items you
                  are sure are dead.
- `rename`      — keep mechanically but rename to match its actual behaviour.

---

## Group A: Tester's specific call-outs

| Triage | Decision | Item | Slot / Type | Tile | Description | Notes |
|---|---|---|---|---|---|---|
| flag | | **Stone Eye** | CONSUMABLE | 247 | "Piece of a statue (enchant +1 ATK crawler)" | One-line cryptic description, mechanic unclear, drops randomly. Doc says "needs description and mechanic, or remove from demo drops." Flag for now, decide later. |
| keep | | **Fire Crystal** | MATERIAL | 122 | "A crystal burning with inner flame. Rare and powerful." | Real recipe ingredient (used by 2 recipes), description fine. Keep. |
| fix-desc | | **Barbed Whip** | MELEE / whip | 291 | "A lashing whip; Strikes where shields cannot guard." | Now correctly `weapon_type=whip` after Phase 2 rename. Description is fine. Keep. |
| fix-stat | | **Bone Sword** (crafted) | MELEE | 87 | "A blade forged from bones of the undead." | Tester says "must list its skills." It has no special on-hit (no abilities, no enchant). Either add a passive (chip armor? lifesteal?) or accept as a vanilla crafted sword. |
| flag | | **Chainmail** | BODY | 169 | "A fine sturdy armour; Stops what a tunic only suggests." | Tester said "cannot have only gold multiplier." Check stat block — needs HP/ARMOR not just gold. (If it actually has armor, keep.) |
| flag | | **Elven Chainmail** | BODY | 17 | (long desc) | Same audit needed as Chainmail. |
| flag | | **Reinforced Chainmail** (crafted) | BODY | 144 | "Heavy reinforced armor." | Description too thin; verify stats. |
| keep | | **Wooden Mallet** | MELEE / hammer | 284 | "A thunderous warhammer…" | weapon_type already matches "hammer." Name says mallet, behaves like hammer — actually fine. |
| keep | | **Ronia Stone** | MELEE / throwing | 504 | "An exceptional lightweight throwing weapon…" | weapon_type=throwing matches. Tester might've mistaken for "Stone Disk" — different item. |
| keep | | **Stone Fury Sling** | RANGED / sling | 25 | Solid description, real weapon. | Phase 2 ammo fix already addresses sling ammo. Keep. |

## Group B: Fish + edible-meta (CONSUMABLE)

These are all fish you "find" but no fishing system has been implemented.

| Triage | Decision | Item | Notes |
|---|---|---|---|
| flag | | **Fish** | Heals 3 HP. Generic. |
| flag | | **Gold Fish** | Heals 100 HP. Could be a rare farm-target if we keep a fishing minigame. |
| flag | | **Lava Fish** | Heals 30 HP. Same. |
| flag | | **Fire Fish** | Heals 10 MP. |
| flag | | **Octopus** | Heals 25 MP. |

**Recommendation:** flag all 5. They're a thematically interesting sub-pool but the supporting fishing system isn't wired. Bring back once we have a way to obtain them deliberately.

## Group C: Tools without functions

| Triage | Decision | Item | Slot | Notes |
|---|---|---|---|---|
| flag | | **Spade** | MATERIAL | LoY had a "dig" verb tied to spades. Not implemented here. |
| flag | | **Fishing Pole** | MATERIAL | Same as fish: no fishing system. |
| flag | | **Lava Rod** | MATERIAL | Same. |

## Group D: Scroll spells (CONSUMABLE)

13 scrolls, all `loy_tile_index = 94` (scroll-of-paper sprite), all "Teaches the X spell permanently." These are real and the spell system supports them.

| Triage | Decision | Notes |
|---|---|---|
| keep | | All 13 scrolls are mechanically correct; they teach real spells via `arrow_effect`/use logic. Keep them all. |

**Spells taught:** Blood Pact, Borrowed Time, Bulwark, Consecration, Evasion Surge, Gravity Well, Heal, Mana Shield, Mirror Image, Phase Shift, Reflect Barrier, Soul Drain, Time Warp.

## Group E: Genuine unused MATERIAL

Materials with no recipe ingredient match, no quest, no chest_loot, no shop.

| Triage | Decision | Item | Notes |
|---|---|---|---|
| flag | | **Spade** | Already above. |
| flag | | **Fishing Pole** | Already above. |
| flag | | **Lava Rod** | Already above. |

That's it. 13 of the 18 MATERIAL items map to recipe ingredients used by the 23 crafting recipes. Only the three tools are orphaned.

## Group F: Recipe-result audit

There are **23 recipes** with outputs in `resources/items/crafted/`. Quick verdict:

| Path | Item | Looks OK? |
|---|---|---|
| crafted/bone_sword.tres | Bone Sword | needs skill / stat audit (Group A) |
| crafted/reinforced_chainmail.tres | Reinforced Chainmail | needs stat audit (Group A) |
| crafted/* (others) | venom_bow, bark_shield, crystal_wand, demon_blade, antidote, fire_flask, frost_flask, gh_potion, gm_potion, etc. | not visually audited yet — can sweep in Group A's audit pass |

## What I'll do once you mark Decisions

For each row where **Decision** column is set, I apply:

- `flag` → patch `demo_approved = false` (or insert it if missing) in the .tres
- `fix-desc` → write a 1-line description targeting the actual mechanic
- `fix-stat` → adjust the StatModifier flat values to match what the item should do
- `delete` → `git rm` the .tres
- `rename` → tell me the new name; I'll write it
- `keep` → no-op

## Defaults if you say nothing

If you just say "go with your Triage column" I will:
- Flag Stone Eye + all 5 fish + Spade/Fishing Pole/Lava Rod (8 items moved out of the demo drop pool, kept in code)
- Audit Chainmail / Elven Chainmail / Reinforced Chainmail stat blocks and fix-stat if they only carry gold_mult
- Add a real description / on-hit passive to crafted Bone Sword (needs your call — I can give it lifesteal 5% or chip-armor 10%)
- Leave the 13 scrolls + all 23 recipe materials + all weapons in Group A alone

Total touched: ~12 items. Reversible. No deletions.

## Not covered here (deferred)

- Cloak / boot / ring / glove stat tuning per tier (Phase 4 will surface sprite issues; values can be a separate pass)
- Sprite mismatches (Phase 4)
- Per-enemy drop_tables (Phase 5)
