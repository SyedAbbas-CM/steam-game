# Quest mq06 — The Warden's Warning

## Quick facts

| Field | Value |
|-------|-------|
| ID | `mq06` |
| Title | The Warden's Warning |
| Band | B2 |
| Recommended level | 8 |
| Quest giver | trigger on entering Ashheim with the Shepherd's letter |
| Turn-in | **Warden of Heim** in Ashheim |
| Action location | Ashheim |
| Prerequisite | `mq05` |
| Critical path? | yes — branch point (leads to both `mq07` and `mq09`) |

## Summary
Deliver the Shepherd's letter to the **Warden of Heim**. Learn what the Tide actually is — and receive **Key Fragment 1 / 3**, the first piece of something that can close a lesser wound.

## Lore context
Ashheim is a volcanic city — soot on everything, sulfur in the air. The Warden of Heim was Iola's old partner. He's the one who lived; she's the one who quit. He didn't quit. He just stopped writing to her.

The letter the Shepherd left is a *warning*. It's a polite letter, addressed by name, written in clean hand. It tells the Warden the Tide is *organising*. There's a hierarchy now. The Shepherd is mid-rank. The voice the villagers were listening to is higher. The letter ends: *"You have the first key. I have the second. The third is asleep. Come find us. Or don't."* 

The Warden hands you the first key fragment. He doesn't know who has the second. He believes the third is at the bottom of Hellgate. After this quest, the player knows there are **3 Key Fragments**, and that someone in the cult is collecting them too.

This is also where the path forks: the Warden tells you to choose. Go north to Frostpass to chase the "woman in white" the Shepherd referenced (→ `mq07`), or follow the harbour rumours about a ghost ship at Gomb (→ `mq09`). Both eventually merge at `mq10`.

## NPCs involved
- **Warden of Heim** (NEW Warden NPC) — older than Coran, more tired. Speaks like someone who's been waiting for this exact letter. Wears a Warden cloak but no insignia.
- **Ashheim soot-children** (NEW ambient NPCs) — chase coal-rats through the soot. Will sell you a piece of folded cloth (one-time vendor) for 50g. The cloth is a Tide artifact. Codex entry.
- **The Hollow Shepherd** (offscreen) — referenced in the letter only. Doesn't appear in this quest.

## Steps

1. **Travel from the Mirage exit to Ashheim** — long journey via the Wastes road. Banner fades for the first Ashheim view.
2. **Find the Warden's house** — uphill from the smelter quarter. He's expecting you.
3. **Hand him the letter**:
   - If you read it (broken seal): he frowns but reads anyway. Trust −1.
   - If sealed: he reads, hands you a folded copy of his own translation notes. Trust +1.
4. **The conversation** — long dialogue, the most lore-dense in the early game. He explains the Tide, the hierarchy, the Key Fragments, the woman in white. The player can ask any of five questions in any order.
5. **He gives you Key Fragment 1/3** — physical item, weight 0, can't drop.
6. **The fork** — he asks where you want to go next:
   - **North** — the woman in white, Frostpass (→ `mq07`).
   - **Coast** — ghost ship rumours, Gomb harbor (→ `mq09`).
   - **Wait** — return to Coran first (delays both; Coran adds a third dialogue option to the choice).

## Rewards
- XP: 3000
- Gold: 2500
- Items: **Key Fragment 1/3**, **Warden's Translation Notes** (codex item)
- Unlocks: `mq07` AND `mq09` (both available — fork), Warden of Heim's recurring dialogue, Ashheim's soot-children vendor

## Optional / hidden objectives
- Ask the Warden if Iola is alive. He says yes, then asks how she is. Codex entry: *"He still cares."*
- Ask about the woman in white. He says only one line: *"She isn't a person."* — codex entry.
- Don't ask for the Key Fragment. He notices. Hands it to you anyway. Says *"Smart not to want it. Take it."*
- Find the broken shrine in the upper smelter (hidden room). Read the inscription. Codex entry naming the **Witch of Nord** for the first time.

## Branches & reactions
- After completion:
  - Iola: ask if she wants to know how the Warden is. She says no. Then yes. Then no. Codex entry.
  - Coran: visibly relieved when you return with the Fragment.
  - Hawkeye: now references the Key Fragments by name.
  - Soot-children: will hide if you sided with the cult (later in `mq10`).

## Tied to story arc
- Act: 3 — *Following the cracks*
- Major theme: the world has structure. The Tide is a faction. The Wardens know its shape but not its name.
- Foreshadows: `mq07` and `mq09` (the fork), `mq08` (Witch of Nord), `mq11`–`mq13` (Cenneth's cult stronghold), `mq18`–`mq19` (the third key fragment at Hellgate).

## Implementation notes

### Existing in `mq06.tres`
- summary: "Deliver the Shepherd's letter to the Warden in Heim. Learn the truth about the Tide and receive Key Fragment 1/3."
- prereq=mq05, target_location=ashheim.

### To add (deepening)
- Warden of Heim NPC + Ashheim NPC roster (currently zone is empty per world map).
- Sealed/unsealed letter state matters at turn-in.
- 5-question dialogue tree (any order, all five contribute to codex).
- Key Fragment 1/3 as unique inventory item, weight 0, undroppable.
- Soot-children ambient NPC + one-time vendor.
- Branch unlock: `mq07` AND `mq09` both available after completion.

### Codex entries unlocked
- `ashheim_intro` — first entry.
- `the_warden_of_heim` — first meeting.
- `the_tide_explained` — when you ask about it.
- `key_fragment_1` — on receipt.
- `the_woman_in_white` — when you ask.
- `the_three_keys` — when you ask about the keys.
- `iola_and_the_warden` — on the optional question.
- `witch_of_nord` — on hidden shrine inscription.
