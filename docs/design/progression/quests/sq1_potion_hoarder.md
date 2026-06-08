# Quest sq1 — Potion Hoarder

## Quick facts

| Field | Value |
|-------|-------|
| ID | `sq1` |
| Title | Potion Hoarder |
| Band | B1 |
| Recommended level | 5 |
| Quest giver | **Corvus** (innkeeper) in Ravenhollow |
| Turn-in | Corvus |
| Action location | any dungeon chests |
| Prerequisite | `q1` complete (offered after) |
| Critical path? | no |

## Summary
Corvus needs 5 Red Potions for "experiments." Find them in dungeon chests and bring them to him. He pays in gold and recipe scrolls.

## Lore context
Corvus is not just an innkeeper — he was a Warden alchemist before he stopped being one (story unclear, similar reasons to Iola). His "experiments" are real. He's been trying to brew a counter-corruption tonic for years. If the player asks the right question on turn-in, he admits it.

## NPCs involved
- **Corvus** — keeps a low profile. Friendlier than the Elder. Less than honest about his past.

## Steps

1. **Take the quest** — Corvus asks.
2. **Find 5 Red Potions** — passive collection during normal play. Tag on inventory items.
3. **Bring them to Corvus** — turn-in dialogue.
4. **Optional: ask what they're for** — if you've completed `mq03` or later, you can ask. He admits the counter-corruption project and offers `sq_corvus_tonic` (NEW B2 follow-up quest).

## Rewards
- XP: 200
- Gold: 120
- Items: 3× Red Potion (yes, he gives you back potions — a brewed superior batch)
- Unlocks: Corvus's recipe-scroll inventory tier 2, `sq_corvus_tonic` (NEW, B2)

## Optional / hidden objectives
- Bring 10 Red Potions instead of 5. He gives you a special "Corvus's Cordial" (+30% MP regen 5 min) once.
- Ask about his past as a Warden. He answers obliquely. Codex entry unlocks.

## Branches & reactions
- Other NPCs don't react. This is Corvus's personal arc.

## Tied to story arc
- Act: 2 — *The Wardens know*
- Major theme: many NPCs in Ravenhollow have a past with the Wardens they don't talk about. Corvus is the first you can pry open.

## Implementation notes

### Existing in `sq1.tres`
- summary: "5 Red Potions for his experiments."
- Combat-free side quest. Inventory-check on turn-in.

### To add (deepening)
- Reward fields (currently blank — author 120g / 200 XP).
- The `ask about his past` dialogue gated by `mq03` complete.
- Codex entry hook.
- `sq_corvus_tonic` quest design (new, to draft in B2 batch).

### Codex entries unlocked
- `corvus_warden_past` — if you ask the right question.
