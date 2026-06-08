# Quest q1 — Them Bones

> Reskinned to the Ashenfold setting. See [A0_setting_ashenfold.md](A0_setting_ashenfold.md) for the canon glossary.

## Quick facts

| Field | Value |
|-------|-------|
| ID | `q1` |
| Title | Them Bones |
| Band | B0 |
| Recommended level | 1 |
| Quest giver | **Confessor Elias** in Ashenfold Hold (Synod chapel) |
| Turn-in | Confessor Elias |
| Action location | The Tombyards |
| Prerequisite | none — opening quest |
| Critical path? | yes — gates `mq01` |

## Summary
The Tombyards have started exhuming themselves. Confessor Elias offers 500 marks of consecrated coin to any Penitent willing to put 20 of the un-shriven dead back in the ground.

## Lore context
The dead don't sleep in the Tombyards anymore. The Synod blames soot in the wind, ash-fog, anything but the Breach. Elias knows better but won't say. He's burned six Penitents in three months — three returned, two were buried with honours, one walked east and never came back. **You're the seventh.** This is tutorial work. It is also a test, and Elias is watching your face the whole time.

## NPCs involved
- **Confessor Elias** — old, careful, friendly on the mouth and watchful in the eyes. He'll say "very good, very good" while studying your stigma. He hooks the Penitent in without explaining the work's real shape.
- **Censer-guard at the south gate** — comments on the sweet smell from the Tombyards as you walk past. *"That's not honest decay, Penitent. Move quick."*
- **Sister-Custodian Skuld** — at the Tombyard gates. Mourning. *"They never rose in my grandmother's tenure. They never rose in my father's. Something's calling them out."*

## Steps

1. **Audience with Elias** — formal. He offers the contract. Two responses: accept ("very good, Penitent") or decline ("then you've nothing for us"). Declining locks the Penitent out of `mq01` until they return and submit.
2. **Walk past Skuld** *(new optional beat)* — she stands at the iron gate, censer trembling. If the Penitent stops to listen, she gives the line above. Lore drop. Flag `flag_skuld_heard`.
3. **Put down 20 of the un-shriven** — combat objective (existing).
4. **Return** — Elias accepts the count. Three dialogue paths:
   - *"Twenty marked, twenty buried."* (Synod-formal closing) — clean flow into `mq01`.
   - *"Skuld said something is calling them."* — Elias's face stills. Flag `flag_elias_caught` set; referenced later when he refuses to speak about the Stigma.
   - *"The Breach is closer than you said."* (only if you've already heard the word "Breach" from another NPC) — Elias touches his own stigma absently. Says *"We don't say that name in the chapel."*

## Rewards
- XP: 300
- Coin: 500 marks
- Items: none
- Unlocks: `mq01` available from Confessor Elias, Skuld's tier-2 dialogue

## Optional / hidden objectives
- Read all three named gravestones during this quest (Hellig, Milda, Corvel) → unlocks `sq_grave` (Sister-Custodian Skuld's quest).
- If you raised the Skuld line at the audience, **Sister-Sealkeeper Hroka** begins appearing in the locked vault chamber behind the chapel. (B2 hook.)

## Branches & reactions
- After completion:
  - Confessor Elias: greets you differently every visit. Tone goes from *Penitent* (formal) to *the one I conscripted* (still formal, less distant).
  - Spotter Hawk: starts dropping hints about the Cinder Wastes. *"The patrol roads aren't safe. They aren't quiet either."*
  - Apothecarion Corvus: offers `sq1` once the Penitent reaches L5.

## Tied to story arc
- Act: 1 — *Ash on the boots*
- Major theme: Confessor Elias is hiding what he knows. The Synod is hiding what it knows. The work is real either way.
- Foreshadows: `mq02` (the Tombyard Sentinel isn't *new*, it's *old* — and it was sealed for a reason), `mq03` (Elias lies on the record).

## Implementation notes

### Existing in `q1.tres`
- `start_script` — Elder dialogue → spawnEnemies(Skeleton x20) → startQuest.
- `events` — `kill Skeleton` increments index 0; `quest` turn-in checks `session-q1-0 > 19`.

### To add (deepening)
- New `interact` events for the three named gravestones (Hellig, Milda, Corvel).
- New `if` branches on turn-in keyed to `flag_skuld_heard` and prior dialogue.
- New `zone_enter` event for the Tombyards that triggers Skuld's first line on the first visit.
- Codex entry "The Tombyards" unlocks on first entry.

### Codex entries unlocked
- `tombyards_intro` — on first Tombyard entry.
- `elias_first_impression` — on quest accept.
- `skuld_intro` — on first conversation with Skuld.

## Sample dialogue (rewritten, drop into `.tres` start_script)

**Confessor Elias** (on first meeting):
> *"You're the marked one. The new conscript. Good. I'll keep this short, Penitent — the Tombyards south of the wall have begun exhuming themselves. The un-shriven dead are clawing through the soil. Twenty of them, returned to honest stillness. The Synod will pay 500 marks of consecrated coin. Accept the work?"*

**Player option 1**: *"I accept the work."*
> *"Very good. Walk the south road. Put them down with what you have. Return when the count is twenty. The Sealing will know."*

**Player option 2**: *"I don't accept."*
> *"Then you've nothing for us. The Synod doesn't keep idle hands. Reconsider when you are tired enough."*

**Skuld at the gate** (first visit):
> *"Twenty? He said twenty? Penitent — they never rose in my grandmother's tenure. They never rose in my father's. Something is calling them. He won't say what. I won't say what. But you should know."*

**Elias on turn-in** (default):
> *"Twenty marked, twenty buried. The Sealing keeps its account. Five hundred marks, as agreed. Walk careful, Penitent. The work is not done."*

**Elias on turn-in** (if `flag_skuld_heard`):
> *"...Sister-Custodian Skuld speaks too freely. She mourns. It excuses much. Take your marks, Penitent. We'll have other work for you — soon."*
