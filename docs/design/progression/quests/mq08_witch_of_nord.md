# Quest mq08 — The Witch of Nord

## Quick facts

| Field | Value |
|-------|-------|
| ID | `mq08` |
| Title | The Witch of Nord |
| Band | B2 / B3 boundary |
| Recommended level | 12 |
| Quest giver | trigger inside Frostpass dungeon (no NPC) |
| Turn-in | choice resolved in-fight; report to **Warden of Heim** |
| Action location | Frostpass dungeon |
| Prerequisite | `mq07` |
| Critical path? | yes — first major **player choice** of the spine |

## Summary
A corrupted priestess — the **Witch of Nord** — has hollowed out the deepest chamber of the Frostpass dungeon. She's the one whose footprint you traced in `mq07`. Confront her in the frozen sanctum. **Choose: spare her or strike her down.** The choice carries forward.

## Lore context
The Witch is not the Woman in White. She *was* a priestess of the Wardens, the one who buried Frostgrave's army (yes — *she* did it, generations ago, to keep the corruption locked in their bodies). The Tide eventually reached her and reshaped what she was already willing to do. She's the first NPC the player meets who is **both villain and victim** — the previous one (Hollow Shepherd) was a mouth without a person behind it; the Witch is a person who agreed.

She lights the same kind of black candle the Hollow Shepherd left at the village well — the candle is a Warden sacrament that the cult inverted. Same wax, same prayer, different ending.

The player can either:
- **Strike her down** — clean. She dies. Frostgrave's army stirs (you see it next time you walk through Frostgrave: a few of the frozen soldiers are *gone*). The Wardens of Heim agree this was the only way.
- **Spare her** — she escapes south. Briard treats this as proof you're a liability in `mq10` and `mq11`. Coran defends you in private. The Witch later writes to you (a letter found at Cenneth in `mq13`) — *"I knew you would."*

Both endings are valid. Neither is the "right" answer. This quest's job is to teach the player that *choice has consequences and the game won't tell them which is better*.

## NPCs involved
- **Witch of Nord** — boss, 3 phases. Phase 3 she stops attacking and asks: *"You can finish me, or you can let me finish them. Pick."*
- **Frozen priests of her order** — ambient NPCs in the sanctum. Five of them, mid-prayer, frozen mid-word. Reading their inscriptions tells you what she was before.
- **Iola** (via courier) — sends a sealed note at the dungeon entrance: *"If she speaks, listen first."*
- **Warden of Heim** — on return.

## Steps

1. **Frostpass dungeon entry** — gated open by `mq07` complete. Banner fade-in "The Sanctum of Nord."
2. **Antechamber: 5 frozen priests** — interact-readable inscriptions, each one tells a piece of her past.
3. **Optional: read all 5 before the fight** — unlocks a quiet dialogue option with her in phase 3 ("They told me what you were.")
4. **Witch boss — phase 1** — combat. She fights with ice magic and the same black-candle motif as the Shepherd.
5. **Witch boss — phase 2** — she stops at half HP, says one line. Then resumes.
6. **Witch boss — phase 3** — at 20% HP she stops again, says the choice line, kneels. Player gets a 2-button prompt: **STRIKE** / **SPARE**.
7. **STRIKE branch** — she dies. Frostgrave stirs (next entry shows missing soldiers). Codex entry *"She agreed to it."*
8. **SPARE branch** — she escapes through a side passage. Cult network knows. Codex entry *"She agreed to leave."*
9. **Return to Warden of Heim** — he reads what you did from your face. Either response gets a short, weighted dialogue.

## Rewards
- XP: 5000
- Gold: 4000
- Items:
  - **Witch's Candle** (key item, lights → reveals hidden inscriptions in B3 dungeons)
  - **Frozen Sigil** (B3-tier accessory, +6 ARMOR, +10% MP regen)
- Unlocks: `mq11` (when paired with `mq10` complete from the south fork)

## Optional / hidden objectives
- **Read all 5 priests** for the in-fight dialogue option above.
- **Take the black candle stub** from her altar BEFORE the fight. She notices and refuses to kneel in phase 3 — fight goes to the bitter end (no choice). Marks the player as someone who wouldn't have listened anyway. Codex.
- **Listen to Iola's note before entering** — she gives you a one-time slow-time pendant for the fight.

## Branches & reactions
- After completion:
  - **Strike** path:
    - Coran: solemn approval. *"Hard call, well made."*
    - Briard (introduced later in `mq10`): respects the kill. Treats you as a fellow pragmatist.
    - Frostgrave: a few frozen soldiers are missing on later visits. Codex entry tracks count.
    - Iola: silent.
  - **Spare** path:
    - Coran: *"I hope you were right."*
    - Briard (later, `mq10`): hostile. Treats you as compromised.
    - Iola: relieved. Gives you a permanent +5 LUCK trinket.
    - Witch's letter at Cenneth (`mq13`).

## Tied to story arc
- Act: 3 — *Following the cracks*
- Major theme: the Tide doesn't *take* people — it asks them, and they say yes. The Witch is the first example you fight.
- Foreshadows: `mq10` (Briard splits the Wardens around your choice), `mq11`–`mq13` (Cenneth cult sees you as either threat or potential convert), `mq18` (the final "who binds" choice mirrors this one).

## Implementation notes

### Existing in `mq08.tres`
- summary: "Confront the corrupted priestess in the frozen dungeon. Choose: spare her or strike her down."
- prereq=mq07, target_location=frostpass.

### To add (deepening)
- 3-phase boss (use existing boss_phases hook).
- Phase 3 STRIKE/SPARE prompt (new UI element — 2-button modal that pauses combat).
- Save `flag_witch_strike` or `flag_witch_spare` on save data.
- Frostgrave revisit logic: read flag, despawn N frozen soldier props.
- 5 antechamber inscription interactables.
- Black candle stub interact (alters phase 3 behaviour).
- Iola's slow-time pendant as a one-time consumable.
- Witch's letter delivery in `mq13` gated by `flag_witch_spare`.

### Codex entries unlocked
- `sanctum_of_nord` — on dungeon entry.
- `the_five_priests` — read all 5 inscriptions.
- `witch_phase_3_choice` — at the choice prompt.
- `witch_strike` OR `witch_spare` — branch resolution.
- `frostgrave_stirs` — first revisit after STRIKE.
- `witch_writes_back` — when her letter shows up at Cenneth.
