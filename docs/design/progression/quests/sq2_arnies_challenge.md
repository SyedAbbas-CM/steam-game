# Quest sq2 — Arnie's Challenge

## Quick facts

| Field | Value |
|-------|-------|
| ID | `sq2` |
| Title | Arnie's Challenge |
| Band | B1 |
| Recommended level | 6 |
| Quest giver | **Arnie** (weapons shop) in Ravenhollow |
| Turn-in | Arnie |
| Action location | any dungeon (kill 8 Ghouls) |
| Prerequisite | player owns ≥ 1 weapon from Arnie |
| Critical path? | no |

## Summary
Arnie won't sell you his best gear unless you prove you can use the basic stuff. Kill 8 Ghouls and bring back trophies.

## Lore context
Arnie is gruff, ex-soldier, lost an arm in the Sundering's first wave (rumour — he won't confirm). He distrusts anyone who buys his good weapons without knowing how to use them. This quest is his vetting process. After it, he sells the player his shop's tier-2 catalogue — including a one-of-a-kind weapon called **Arnie's Pick** that he forged himself.

## NPCs involved
- **Arnie** — direct, no-nonsense. Doesn't waste words. Will tell a brief story about his arm if asked after the quest.

## Steps

1. **Take the quest** — Arnie tells you what he wants.
2. **Kill 8 Ghouls** — combat objective. Ghouls live in Haven-Dungeons F3+ and Barrows-Crypt F1.
3. **Return** — Arnie inspects you. If you took zero damage from a Ghoul in the last 5 kills, he gives a bigger reward (use existing player damage-tracking).

## Rewards
- XP: 350
- Gold: 300
- Items: **Arnie's Pick** (tier-2 weapon) — guaranteed
- Optional bonus (no-damage run): +1 Iron Ingot

## Optional / hidden objectives
- Talk to Arnie about his arm after the quest. He tells a single-paragraph story. Codex entry.
- Don't accept Arnie's Pick (refuse politely). He nods. Sells you the rest of the catalogue at a 10% discount permanently.

## Branches & reactions
- After completion:
  - Old Man (blacksmith): nods at you next time. He's Arnie's old friend.
  - Hawkeye: "Arnie doesn't give Picks to just anyone."
  - If you refused the Pick: refugee NPCs in B3 sometimes mention "the one Arnie offered the Pick to."

## Tied to story arc
- Act: 2 — *The Wardens know*
- Major theme: the people of Ravenhollow are veterans of the Sundering's aftermath. Earn their trust by doing the work.

## Implementation notes

### Existing in `sq2.tres`
- summary: "Kill 8 Ghouls to earn his respect."
- Combat objective.

### To add (deepening)
- Reward fields (currently blank — author 300g / 350 XP / Arnie's Pick).
- No-damage-streak bonus (read player damage events during the quest's active period).
- Refuse-the-Pick branch with permanent shop discount flag.
- Arnie's arm dialogue gated by quest complete.

### Codex entries unlocked
- `arnies_arm` — if you ask after the quest.
- `arnies_pick` — on item receipt.
