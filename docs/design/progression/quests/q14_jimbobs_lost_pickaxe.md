# Quest q14 — Brother Jimbo's Lost Cuttergrade

> Reskinned to the Ashenfold setting. See [A0_setting_ashenfold.md](A0_setting_ashenfold.md) for the canon glossary.

## Quick facts

| Field | Value |
|-------|-------|
| ID | `q14` |
| Title | Brother Jimbo's Lost Cuttergrade |
| Band | B0 |
| Recommended level | 2 |
| Quest giver | **Brother Jimbo** in Ashenfold Hold (Apothecarion floor) |
| Turn-in | Brother Jimbo |
| Action location | any Synod-sanctioned shaft (Hold-Dungeons) |
| Prerequisite | none — available alongside `q1` |
| Critical path? | no — side quest |

## Summary
Brother Jimbo — failed lay-brother, lapsed shaft-cutter — lost his consecrated Cuttergrade-blade in the under-shafts last winter. He'll tip you 400 marks if you clear ten unsanctioned things down there while you search for it.

## Lore context
Jimbo isn't a fighter. He used to cut the deep ore-seams beneath Ashenfold Hold for the Synod's smelting work, but the shafts went sour after the First Cracking and he gave up. The Cuttergrade was his father's, marked with the same Synod sigil his father wore as a Captain-Synodist. The reward isn't about the blade. It's about Jimbo *finally* asking for help with the part of his life he abandoned.

If the Penitent completes this quest with Jimbo present (escort variant), Jimbo's arc pivots. He goes to Arms-Master Arnak the next morning and asks to be taken on as a junior workman.

## NPCs involved
- **Brother Jimbo** — currently sits in the Apothecarion floor with a thin cup and watches the censer-smoke. After this quest, his arc continues.
- **The Cuttergrade** itself — placed in a Hold-Dungeons sub-vault, hand-marked.

## Steps

1. **Audience with Jimbo** — he asks for help. Two options: accept the work, or decline ("not your work, Penitent"). Accepting drops a marker to the nearest sanctified shaft entrance.
2. **Sanctify ten unsanctioned in the shafts** — combat objective (existing).
3. **Find the Cuttergrade** *(new step)* — guaranteed drop after the tenth kill. Key item.
4. **Return to Jimbo** — he holds the blade like it's still warm. Pays you. Says *"I'll go down again. Soon. I will."*

## Rewards
- XP: 80 (currently unauthored — see `04_quest_flow.md`)
- Coin: 400 marks (per existing `.tres`)
- Items: Cuttergrade-blade (lore-only, weight 0; Jimbo keeps it)
- Unlocks: Jimbo's B2 arc (junior workman under Arms-Master Arnak), `sq1` "Tincture Hoarder" offered immediately

## Optional / hidden objectives
- **Escort variant**: agree to bring Jimbo with you instead of going alone. He's slow, gets in the way, but contributes a few cuts. If he survives, his arc accelerates — he becomes a small Hold vendor in B3, selling one shaft-themed tool.
- **Don't tell him you found the blade** (keep it). He stays in the Apothecarion. Arnak never takes him on. Bleak path.

## Branches & reactions
- After completion:
  - Apothecarion Corvus: *"Brother Jimbo hasn't ordered a tincture today. That's new."*
  - Spotter Hawk: notes Jimbo *"is looking up at the rafters again. That's something."*
  - If escort variant: Arms-Master Arnak nods at Jimbo the next time you pass them in the same corridor.

## Tied to story arc
- Act: 1 — *Ash on the boots*
- Major theme: the Hold is full of people who gave up after the First Cracking. The Penitent is starting to lift them off the floor.
- Foreshadows: Arnak takes Jimbo on (B2). The broader *"refugees returning to the work"* theme that culminates in `mq20`.

## Implementation notes

### Existing in `q14.tres`
- `kill *` event (any enemy) increments index 0.
- Turn-in at haven checks `session-q14-0 > 9`.

### To add (deepening)
- Cuttergrade pickup step (interact on placed item).
- Escort variant: branch at quest accept where Jimbo joins as a companion (use existing companion system).
- Three turn-in dialogue branches keyed to `flag_jimbo_escorted`, `flag_jimbo_kept_cuttergrade`.
- Author rewards (100 marks / 80 XP minimum per `04_quest_flow.md`).

### Codex entries unlocked
- `jimbo_intro` — on quest accept.
- `jimbos_father` — if you escort him; he tells the story.
- `the_under_shafts` — on first Hold-Dungeons entry.

## Sample dialogue (rewritten)

**Brother Jimbo** (sitting in the Apothecarion):
> *"You're the marked one. Heard about you. Listen — my father's Cuttergrade. Down in the under-shafts. Lost it. Winter before last. I... I don't go down there anymore. You will. Find ten of the unsanctioned. Put them down. Bring it back. Four hundred marks. That's all I have. That's all of it."*

Player option (decline):
> *"...Right. Right, of course. Of course you won't. That's fine. Walk on, Penitent."*

Player option (accept):
> *"You will? You will. Thank you. The Sealing keep your hands. Just — bring it back, Penitent. It was his."*

Player option (offer to escort):
> *"You'd — you'd bring me along? Penitent, I haven't been below in two winters. My legs aren't — yes. Yes. I'll come."*

**Jimbo on return** (default):
> *"That's it. That's it. He carved his name in the grip. You can feel it. Thank you, Penitent. Four hundred marks. I'll — I'll go down again. Soon. I will."*

**Jimbo on return** (escort variant):
> *"We went down, Penitent. We went down and we came back. I haven't said that sentence in two years. I'll speak to Arms-Master Arnak in the morning. About the work. About maybe — going back to it."*

**Jimbo on return** (you kept the blade — bleak):
> *"Nothing? Not even a fragment? Then it's gone. That's how it is. Thank you for trying, Penitent."*
