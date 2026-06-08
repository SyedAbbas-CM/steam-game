# Quest mq03 — The Elder's Silence

## Quick facts

| Field | Value |
|-------|-------|
| ID | `mq03` |
| Title | The Elder's Silence |
| Band | B1 |
| Recommended level | 3 |
| Quest giver | **Hawkeye** (after Elder refuses) |
| Turn-in | Iola (the scholar/hermit) in the Wastes |
| Action location | The Wastes (`wastes`) |
| Prerequisite | `mq02` |
| Critical path? | yes |

## Summary
The Elder refuses to help you translate the tablet. Hawkeye points you toward **Iola**, a scholar living in the Wastes who can read the old Warden marks — but her stolen journal must be recovered first from a wagon ambush further north.

## Lore context
This is the quest where the player STOPS trusting the Elder and starts trusting the Wardens. Iola is the bridge to Warden Coran (`mq04`). She's also a former Warden cartographer who quit when her partner died at Ashheim. She *can* read the tablet but won't until you bring her journal back — because she needs to know if you're the kind of person who finishes what they start.

## NPCs involved
- **Hawkeye** — the gossiper in Ravenhollow. Has been waiting for the player to come back from `mq02` looking shaken. Hands off Iola's name.
- **Elder** — refuses outright when asked about the tablet. *"Some things stay buried. That one was."* Walks away. The player can't talk to him again until `mq04` is complete.
- **Iola the Hermit** (NEW per `02_world_map.md`) — lives in a clearing in the Wastes. Knows you by reputation already. Cool, watchful. Trades samples for consumables. Won't talk about the tablet until you recover her journal.
- **Corrupted bandits** — ambushed Iola's wagon. They took the journal. They're heading for an abandoned trapper's hut north of the road.

## Steps

1. **Talk to the Elder** — he refuses. (One short dialogue beat, then walks back into the Town Hall.) Flag `flag_elder_refused` set.
2. **Hawkeye** intercepts — tells you about Iola. Sketch map.
3. **Walk into the Wastes** — first time in zone. Long banner fade-in "The Withered Wastes." Optional encounter: a Warden patrol walks the road. If you talk to them they confirm Iola is in the clearing south.
4. **Find Iola** — she sizes you up. Says: *"You can't read the marks. I can. My journal can. The journal was stolen yesterday. Bring it back, we'll talk."*
5. **Track the bandits** — scripted ambush encounter on the way to the Hunter's Snare (NEW location per `02_world_map.md`). Two corrupted bandits, one with the journal.
6. **Recover the journal** — drops on bandit kill. Pick up.
7. **Return to Iola** — she reads two pages while you wait. Looks up. *"You really don't remember, do you?"* Hands you back the tablet with a translation noted: *"The wound that drank the noon — Embermaw."* This unlocks `mq04`.

## Rewards
- XP: 800
- Gold: 600
- Items: 3× Bandage (NEW), Iola's Coffee (consumable: +20% MP regen 5 min)
- Unlocks: `mq04`, Iola as a recurring NPC, Warden patrol dialogue tier 1

## Optional / hidden objectives
- Don't kill the bandits — interrupt the ambush, *talk* to them (requires being un-aggro'd). They drop the journal voluntarily and walk away. Flag `flag_spared_bandits` set; this affects `mq04` (the same bandits show up in the cult and recognise you).
- Find the **Sleeping Stones** clearing (NEW per `02_world_map.md`) and stand at the centre at night. Iola later mentions you "must have felt the stones move."

## Branches & reactions
- After completion:
  - Elder: locked dialogue ("I've nothing to say to you") until `mq07`.
  - Hroka: opens the stairs down (B2 hook) once the player reaches L9.
  - Coran (NEW, in the Warden's Camp): now offers `mq04` directly.

## Tied to story arc
- Act: 2 — *The Wardens know*
- Major theme: the Elder is the one keeping you in the dark, not protecting you.
- Foreshadows: `mq04` (cult heading south), `mq05` (Iola's partner died at Ashheim — relevant), `mq08` (the Wardens have a split, Coran vs Briard).

## Implementation notes

### Existing in `mq03.tres`
- summary already mentions the scholar and stolen journal.
- prereq=mq02, target_location=wastes.

### To add (deepening)
- Elder's refusal dialogue (short beat at quest accept; locks his other dialogues).
- Iola's two-step gate: first refuses, then asks for journal.
- Wagon ambush scripted scene at a specific spot in the Wastes (new `wagon_ambush.tres` script).
- Spared-bandits branch.
- Journal as a key item (not sellable, removed on turn-in).

### Codex entries unlocked
- `the_wastes` — on first Wastes entry.
- `iola_intro` — on first meeting.
- `corrupted_bandits` — on first fight with them.
- `wardens_intro` — on first Warden patrol talk.
