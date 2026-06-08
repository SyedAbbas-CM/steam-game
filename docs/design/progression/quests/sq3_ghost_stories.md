# Quest sq3 — Ghost Stories

## Quick facts

| Field | Value |
|-------|-------|
| ID | `sq3` |
| Title | Ghost Stories |
| Band | B1/B2 |
| Recommended level | 7 |
| Quest giver | **Corvus** in the Crooked Beak inn |
| Turn-in | Corvus |
| Action location | the Barrows (above-ground, at night) |
| Prerequisite | player has visited the Barrows at least once |
| Critical path? | no |

## Summary
Inn patrons are spooked by ghost sightings near the graveyard. Cull 15 Ghosts at night to put the rumours to rest.

## Lore context
Ghosts aren't supposed to walk this side of the Hellgate, but they've been seen near the Barrows on moonless nights. The patrons are not wrong. This is the *first* visible sign that whatever's leaking out of Hellgate is now strong enough to reach Ravenhollow's doorstep. The Elder knows this. He won't talk about it. Corvus is sponsoring the work to keep his customers calm — but he also gives you a coded note for Iola at the end.

## NPCs involved
- **Corvus** — quest giver. Pretends it's about patron comfort. It isn't.
- **Drunk patron at the inn** — gives you the initial sighting tip *"my brother saw one. Then my brother died."* Lore drop on first chat.
- **Ghosts in the Barrows** — combat. Talk only if the player has done `mq02` (one of them whispers a name — Briard's name. First mention.)

## Steps

1. **Talk to Corvus** — he asks for help.
2. **Talk to the drunk patron** (NEW optional) — sketchy tip about the night the Ghosts started. Lore bait.
3. **Go to the Barrows at night** — Ghosts only spawn after sundown. If the player goes during the day, they get a hint "the dead don't walk in daylight" and have to wait or sleep.
4. **15 Ghost kills** — combat objective.
5. **Optional: a Ghost speaks** — random low-chance event during the kills. If it happens, you hear *"Briard."* — flag `flag_ghost_named_briard` set (referenced in `mq04` and `mq10`).
6. **Return to Corvus** — he pays you. He hands you a sealed envelope addressed to Iola. *"Don't read it."*

## Rewards
- XP: 1000
- Gold: 800
- Items: recipe scroll (random tier-1 alchemy recipe)
- Sealed envelope to Iola (unlocks a small follow-up dialogue with her)

## Optional / hidden objectives
- Open Corvus's envelope. Inside is one line: *"He's the brand."* Iola will refuse the letter next time. Permanent trust drop with both NPCs. (Codex entry.)
- Spend an entire in-game night in the Barrows without leaving. Hroka the Stairgirl appears and says *"You're closer than they think."*

## Branches & reactions
- After completion:
  - Iola: if you delivered the envelope intact, says "thank you" and offers a one-time +5 LUCK trinket.
  - Iola: if you opened the envelope, says nothing. Permanent dialogue downgrade.
  - Corvus: thanks you. Drunk patron stops drinking for a day.

## Tied to story arc
- Act: 3 — *Following the cracks*
- Major theme: the corruption is now close enough to be ambient. People are scared.
- Foreshadows: Briard's role as antagonist in `mq10`, the Hellgate seepage that drives B3.

## Implementation notes

### Existing in `sq3.tres`
- summary: "Kill 15 Ghosts."
- Combat objective.

### To add (deepening)
- Day/night spawn gate (Ghosts only appear after sundown — use existing day/night cycle).
- Random low-probability "Briard" dialogue on Ghost kill.
- Sealed envelope as a key item with open/sealed states.
- Branching Iola dialogue based on `flag_envelope_opened`.

### Codex entries unlocked
- `the_drunk_patron` — on first inn chat.
- `night_ghosts_in_barrows` — on first ghost sighting.
- `corvus_envelope` — on receipt.
- `corvus_envelope_opened` — if opened.
