# Quest mq01 — Waking in Ash

> Reskinned to the Ashenfold setting. See [A0_setting_ashenfold.md](A0_setting_ashenfold.md) for the canon glossary.

## Quick facts

| Field | Value |
|-------|-------|
| ID | `mq01` |
| Title | Waking in Ash |
| Band | B0 / B1 |
| Recommended level | 2 |
| Quest giver | **Confessor Elias** in Ashenfold Hold |
| Turn-in | Confessor Elias |
| Action location | The Hollow Fields |
| Prerequisite | `q1` |
| Critical path? | yes |

## Summary
Confessor Elias presents a charcoal rubbing of a brand burned into a slaughtered ox at Custodian Dafydd's land. The shape matches **the Stigma** on your arm. Travel to the Hollow Fields, sanctify ten corrupted Strawmen, and return for an audience.

## Lore context
Your stigma is a Synod conscription glyph. It was burned into your arm when you were too young to remember and too old to forget. Elias recognised it the first time you walked into the chapel. The same glyph is appearing burned into dead livestock in the Hollow Fields — which means something out there is *remembering* the Synod's old initiation marks. Elias does not tell you any of this. **He says the brand is unfamiliar.** It is the first lie he tells you on record.

The corrupted Strawmen are leftover scarecrow husks that the Whisper has woven into. They walk at moonset. Custodian Dafydd, the last sworn farmer on the Hollow Fields, has been losing livestock for a season.

## NPCs involved
- **Confessor Elias** — opens the quest, shows the rubbing, asks if it "means anything." Pretends not to recognise it.
- **Custodian Dafydd** — last sworn farmer of the Hollow Fields. Quiet, tired. Wears a faded Synod stole he doesn't mention. Owns a worn reaping-blade.
- **Plentyn (lay-novice)** — a Hold-orphan, sent to Dafydd as labour. Sees the Strawmen at night. Says cryptic things: *"They walk when the moon does and never when it doesn't."*
- **Sister-Reaper Hroma** — appears in the field at sundown if the Penitent is alone. Doesn't introduce herself yet. Cryptic. Her own arc unlocks later.

## Steps

1. **Elias's audience** — shows the rubbing. The Penitent can *show their stigma* (flag `flag_mq01_showed_arm`) or refuse. Refusing forces Elias to lie harder in `mq03`; Spotter Hawk will mention it.
2. **Travel to the Hollow Fields** — first time in zone. Banner fade: *The Hollow Fields*. Dafydd meets you at the chapel-shed, walks you to the eastern paddock.
3. **Dafydd's audience** *(new beat)* — he shows the slaughtered ox. The brand is identical to yours. He doesn't ask. He says *"I've seen that mark before. Once. Not on a beast,"* and stops talking.
4. **Sanctify ten Strawmen** — combat objective (existing).
5. **Return to the Hold** — Elias asks how the work went. Three dialogue paths:
   - *"Ten Strawmen, sanctified."* — clean flow into `mq02`.
   - *"The brand on the ox matched mine."* — Elias stills for a half-beat, says *"You're mistaken, Penitent."* Flag `flag_elias_lied` set.
   - *"Plentyn said they walk only with the moon."* — Elias admits *"The lay-novice sees more than most his age. The Synod will remember him."* Doesn't elaborate.

## Rewards
- XP: 400
- Coin: 300 marks
- Items: 2× Sanctified Tincture (Red Potion equivalent)
- Unlocks: `mq02`, Dafydd's tier-2 stock (sells a basic reaping-blade), Hroma's introductory dialogue

## Optional / hidden objectives
- Visit **the Mill** at moonset and enter (sealed; the lock breaks if Plentyn is with you). Inside is a Synod ledger page: *"The first Strawmen wore my brother's stole."* Foreshadows `mq05`.
- Sanctify nine and **leave one Strawman intact**. Plentyn approaches you the next morning and asks *"You let one stand?"* — yes/no flag for the hidden bridge quest in `04_quest_flow.md`.

## Branches & reactions
- After completion:
  - Mabion the Sanctioned (Stables): asks if the Penitent would consider a clatter-bird for the road.
  - Spotter Hawk: drops his *"the patrol road isn't dead"* line and adds *"the Synod still walks it. Mostly."*
  - Confessor Elias: visibly colder if `flag_elias_lied` is set.

## Tied to story arc
- Act: 1 — *Ash on the boots*
- Major theme: your stigma is the first hook into the *you were already part of this* reveal.
- Foreshadows: `mq02` (the tablet bears Synod marks), `mq03` (Elias explicitly lies about the brand), `mq05` (the Hollow Fields rot is older than Dafydd knows).

## Implementation notes

### Existing in `mq01.tres`
- summary already mentions the brand matching dead livestock. Strengthen with new dialogue.
- start at Elias, target_location=duskfarm, prereq=q1.
- Combat target: 10 corrupted Scarecrows → 10 corrupted Strawmen.

### To add (deepening)
- Dafydd's farmstead audience scene before the combat objective unlocks.
- `interact` event for the Mill door (gates the ledger lore).
- `if` branches on turn-in: `flag_mq01_showed_arm`, `flag_elias_lied`, `flag_left_strawman_standing`.
- Plentyn's dialogue evolves at moonset.

### Codex entries unlocked
- `the_stigma` — on Dafydd's reveal step.
- `hollow_fields_intro` — on first zone entry.
- `dafydd_first_impression` — on first meeting.

## Sample dialogue (rewritten)

**Elias** (opens the quest):
> *"Custodian Dafydd sent a rubbing. A glyph, burned into one of his oxen. Tell me, Penitent — does it mean anything to you?"*

If the Penitent shows their stigma:
> *"...I see. The Synod's archives are deep. Older glyphs surface from time to time. Travel to the Hollow Fields. Sanctify what is walking the paddocks. Ten of them. Return to me. We'll have words."*

If the Penitent says nothing:
> *"Mm. No. Of course not. Travel to the Hollow Fields. Sanctify what is walking the paddocks. Ten of them. Return to me. We'll have words."*

**Dafydd** (at the slaughtered ox):
> *"There it is. Burned right through the hide. Don't ask me what it is, Penitent — I'm a custodian, not an archivist. I'll say this once. I've seen that mark before. Once. Not on a beast. Go do your work. Don't come back to ask."*

**Plentyn** (at moonset):
> *"They walk when the moon does. They don't walk when it doesn't. I told Dafydd. He doesn't want to hear it. You should hear it. They aren't strawmen anymore, Penitent."*

**Hroma** (sundown, alone):
> *"You're the marked one. I knew you'd come south. Don't speak. Finish your count. Come back when you're older."*

**Elias** (turn-in default):
> *"Ten sanctified. The Sealing keeps its account. Take your tincture, Penitent. There is more work."*

**Elias** (turn-in, if `flag_elias_lied` triggered):
> *"Ten sanctified. Yes. The brand. I... do not have an explanation, Penitent. Older marks. Older work. We'll speak of it when there is time."*
