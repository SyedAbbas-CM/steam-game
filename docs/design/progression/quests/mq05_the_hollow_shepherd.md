# Quest mq05 — The Hollow Shepherd

## Quick facts

| Field | Value |
|-------|-------|
| ID | `mq05` |
| Title | The Hollow Shepherd |
| Band | B2 |
| Recommended level | 7 |
| Quest giver | **Warden Coran** at the Warden's Camp |
| Turn-in | trigger inside the Mirage dungeon (no NPC) |
| Action location | The Wastes → Mirage |
| Prerequisite | `mq04` |
| Critical path? | yes |

## Summary
A village in the Wastes has gone silent. The residents stand motionless, eyes turned black. A figure called **the Hollow Shepherd** is heard speaking to them. Pursue it into the Mirage dungeon and recover what it left behind.

## Lore context
This is the player's first encounter with **the Tide** — what the locals call the corruption from Hellgate. Iola explained it in `mq04`; now you see it. The Hollow Shepherd is not a name, it's a *role*: someone the Tide has hollowed out and is using as a herald. The villagers aren't dead — they're listening. If you watch them, they all turn their heads at the same time. They're a single audience for a single voice.

The Shepherd flees into the Mirage when you arrive. The Mirage is a dungeon that **doesn't exist on any map** — it shimmers into being south of the silent village and disappears after you leave. It's a leak the Tide opened that won't be there next week. You're chasing something that's evaporating.

## NPCs involved
- **Coran** — gives the briefing. Calm but tight. Warns: *"You'll want to talk to them. Don't. They're not there."*
- **Silent village residents** — stand motionless. The player can interact with them — they won't respond, but Codex entries unlock if you read their nameplates.
- **The Hollow Shepherd** — robed figure, face shadowed. Speaks once, when you enter the village square: *"You weren't supposed to find us yet."* Then runs.
- **Letter from the Shepherd** (NEW key item) — left behind in the Mirage dungeon. Addressed to "the Warden of Heim." Sets up `mq06`.

## Steps

1. **Coran's briefing** — short. He warns about the residents. Gives sketch directions.
2. **Walk into the silent village** — ambient set piece. Six villagers visible, all facing the well at the centre. They turn their heads in unison when you approach.
3. **Optional: read the nameplates** — at each home. Each has a name and a small story. Codex entries.
4. **Square confrontation** — the Hollow Shepherd appears at the well. Speaks one line. Runs south. The villagers all turn to watch *you*, not the Shepherd.
5. **Mirage dungeon entrance opens** in the southern field — a heat-shimmer doorway. Player walks through.
6. **Pursue through the Mirage** — first-time-in-zone banner. The Mirage layout reuses dungeon assets but with washed-out colours and a constant low hum.
7. **Catch the Shepherd?** — at the end of the dungeon, the Shepherd is gone. Left behind: a **sealed letter** addressed *To the Warden of Heim*. Pick it up. Quest completes on pickup.

## Rewards
- XP: 2500
- Gold: 2200
- Items: **Shepherd's Letter** (key item, unlocks `mq06`)
- Unlocks: `mq06`, ambient "silent village" remains visitable, Mirage dungeon entry collapses after pickup (becomes unreachable)

## Optional / hidden objectives
- Speak the Shepherd's last word back at one of the villagers. They blink. One word changes on their nameplate. (Permanent in the world; codex entry.)
- Don't read the letter. The Warden of Heim is more willing to talk in `mq06` if you came in with the seal intact.
- Find the **black candle** at the well's base. Sets up the Witch of Nord (`mq08`) — same candle motif.

## Branches & reactions
- After completion:
  - Coran: somber. Confirms the village won't recover. Promises to send someone to "tend it."
  - Iola: asks if you read the letter. Won't tell you what she'd do.
  - Hawkeye: starts saying "The Tide" instead of "the trouble."

## Tied to story arc
- Act: 3 — *Following the cracks*
- Major theme: the Tide makes people listen. The Wardens are the only ones still talking back.
- Foreshadows: `mq06` (Heim is Ashheim, the next stop), `mq08` (the witch lights the same kind of black candle), `mq19` (the Speaker uses the Shepherd's voice).

## Implementation notes

### Existing in `mq05.tres`
- summary: "A silent village — residents stand motionless, eyes black. The Hollow Shepherd commands them. Pursue into the dungeon."
- prereq=mq04, target_location=mirage.

### To add (deepening)
- Silent village as a hand-authored set piece inside the Wastes (new sub-zone or scripted spawn cluster).
- Six villager NPCs with nameplates that are interact-only (no dialogue). New NPC type "silent."
- Hollow Shepherd: scripted boss-style spawn + flee sequence.
- Mirage dungeon entry opens on Shepherd flee, closes after letter pickup.
- Shepherd's Letter as a sealed/unsealed key item with branching state for `mq06`.
- Hidden black candle interact.

### Codex entries unlocked
- `the_tide` — first time the word is used by a Warden or villager.
- `silent_village` — on first entry.
- `the_hollow_shepherd` — on square confrontation.
- `the_mirage` — on entering the Mirage.
- `shepherds_letter` — on pickup.
