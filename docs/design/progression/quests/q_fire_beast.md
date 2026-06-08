# Quest q_fire_beast — The Fire Beast

## Quick facts

| Field | Value |
|-------|-------|
| ID | `q_fire_beast` |
| Title | The Fire Beast |
| Band | B2 |
| Recommended level | 10 |
| Quest giver | **Dafydd** at his Hollow Fields farm |
| Turn-in | Dafydd |
| Action location | The Embermaw (south of Hollow Fields) |
| Prerequisite | none — Dafydd offers it after `mq01` |
| Critical path? | folded into critical path in `04_quest_flow.md` (becomes `mq06` proxy) |

## Summary
A fire-corrupted beast in the Embermaw is killing Dafydd's livestock and threatening the farm. It also has something of his father's that it took from the grave.

## Lore context
Embermaw is the **first lesser wound** named in the tablet from `mq02`. Iola translated it. Dafydd doesn't know any of that — to him, it's just a monster that's been stealing cattle. The "thing of his father's" is a Warden medallion that his father wore. Dafydd's father was a Warden. Dafydd doesn't know.

When the Fire Beast dies, it speaks. Same trick as the Bone Golem — these "wound guardians" are all conscious and old. It says: *"Coran sent you. Tell him: it's worse below."* That's the first time the player learns Coran has been here before.

## NPCs involved
- **Dafydd** — desperate, scared. Gives you his father's old coat as down-payment.
- **Fire Beast** — boss. 3 phases. Phase 3 it speaks.
- **Embermaw whispers** — ambient, no source.

## Steps

1. **Talk to Dafydd** — accept the quest. He gives you **Dafydd's Old Coat** (named unique per `05_unique_items.md`) immediately as down payment.
2. **Travel to Embermaw** — first time in zone. Banner fade-in. Heat shimmer effect on the screen.
3. **Cross the lava chambers** — pacing rooms with hazards. Test the new lava tuning.
4. **Fire Beast boss** — 3 phases. Phase 3 it speaks. After the fight, the Warden medallion drops.
5. **Optional: read the medallion's engraving** — Dafydd's father's name. Codex entry. Foreshadows `mq07`.
6. **Return to Dafydd** — give him the medallion. He recognises the name. He breaks. Two responses:
   - *"It was your father's."* — Dafydd asks you to keep it. Trust unlocked.
   - *"It belongs to you now."* — Dafydd accepts it silently. Locks Dafydd's B3 arc.

## Rewards
- XP: 1500
- Gold: 2000
- Items: **Embered Heart** (NEW unique consumable per `05_unique_items.md`) — 30s fireproof active
- Optional: **Warden Medallion** key item if Dafydd asks you to keep it (unlocks Coran dialogue tier 3)

## Optional / hidden objectives
- Don't kill the Fire Beast — escape with the medallion only. (Skip the 3 phases somehow.) Coran says *"You should've finished it. We'll come back for it together."* — sets up an `mq06b` future quest.
- Bring the medallion to Coran instead of Dafydd. Coran tells the player about Dafydd's father. Then sends you back to Dafydd. Locks the "*Coran knew first*" subplot.
- Talk to Plentyn after defeat — child says *"the fields don't whisper anymore."* Codex entry.

## Branches & reactions
- After completion:
  - Coran: refers to the Fire Beast as "settled." Promotes you to a working Warden initiate.
  - Iola: confirms Embermaw is *one* of the lesser wounds. There are more. Hints at Mirage (`mq06`).
  - Dafydd: changes greeting permanently — *"It's good you came back."*
  - Fire Beast's name appears in the codex's "Old Guardians" list, alongside Bone Golem.

## Tied to story arc
- Act: 3 — *Following the cracks*
- Major theme: the Wardens were here before you. You're walking in their shadow.
- Foreshadows: `mq07` (Dafydd's father at Ashheim), `mq08` (the wound guardians are *fading*), the Speaker's introduction in `mq10`.

## Implementation notes

### Existing in `q_fire_beast.tres`
- summary: "A fearsome beast lurks in the Embermaw east of Hollow Fields."
- (note: summary says "east"; per zones it's south — fix the .tres summary text)
- Combat boss objective.
- 2000 gold / 1500 XP reward.

### To add (deepening)
- Dafydd's Old Coat handed out at quest accept (per `05_unique_items.md`).
- Phase 3 Fire Beast dialogue.
- Warden Medallion as a guaranteed drop with branching turn-in.
- Bring-to-Coran-instead branch.
- Skip-the-fight branch.
- Fix the summary direction text.

### Codex entries unlocked
- `embermaw_intro` — on first Embermaw entry.
- `fire_beast` — on encounter.
- `warden_medallion` — on pickup.
- `dafydds_father` — on engraving read.
- `coran_was_here_first` — on the optional Coran path.
