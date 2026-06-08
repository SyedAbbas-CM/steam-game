# Quest mq02 — What the Dead Left Behind

## Quick facts

| Field | Value |
|-------|-------|
| ID | `mq02` |
| Title | What the Dead Left Behind |
| Band | B0 |
| Recommended level | 2 |
| Quest giver | **Elder** in Ravenhollow |
| Turn-in | Elder |
| Action location | The Barrows mausoleum |
| Prerequisite | `mq01` |
| Critical path? | yes — boss gate |

## Summary
The ichor trail from the Hollow Fields leads to the crypts beneath the Barrows. Slay 5 blighted undead, defeat the **Bone Golem** guarding the depths, and recover the carved tablet it was protecting.

## Lore context
The Bone Golem isn't a random monster. It's a Warden guardian — a sealed sentinel built generations ago to keep a single tablet hidden. **The founders of Ravenhollow buried it on purpose.** They knew what it was. The Elder is one of them. The tablet, when translated (`mq03`), names what the Sundering actually broke and points to the first lesser wound, Embermaw.

## NPCs involved
- **Elder** — tells you "follow the trail." Doesn't mention the Golem. Doesn't mention the tablet.
- **The Voice in the Mausoleum** (NEW) — a whisper when you enter the inner chamber. No source. Says one of three things at random: *"You shouldn't be here."* / *"He didn't tell you, did he?"* / *"Welcome home."*
- **Bone Golem** — boss. Two phases. After phase 1, it speaks (the only enemy in B0 that talks): *"I knew your face when you were small."*
- **Hroka the Stairgirl** (NEW) — meets the player at the Barrows iron gate on return. First time she's seen above ground.

## Steps

1. **Find the trail** — ichor splotches lead south from Hollow Fields to the Barrows. Pure exploration step (existing zone exit is enough — gate is the "trail" visually).
2. **Open the Mausoleum** — sealed since `mq01`. Now unlocked. Walk in. *Voice* speaks.
3. **5 blighted undead** — combat objective in the antechamber.
4. **Bone Golem boss** — phase 1 normal, phase 2 it speaks. After phase 2 it shatters and drops the tablet.
5. **Return** — Elder. Show him the tablet. Three branches:
   - *"What is this?"* — Elder lies. "I don't know." Flag `flag_elder_lied` (stacking).
   - *"The Golem knew me."* — Elder freezes. Then: "Old stones say strange things." Flag `flag_elder_caught` set.
   - *"You knew it was here."* (only if `flag_elder_lied` from `mq01` is set) — Elder doesn't deny it. Says "I'll tell you when you're ready." Unlocks Hroka's stairs dialogue.

## Rewards
- XP: 600
- Gold: 800
- Items: **Mourner's Shawl** (named unique cloak per `05_unique_items.md`) — guaranteed
- Unlocks: `mq03`, Barrows-Crypt entry teaser (Old Hellig's Grave starts cracking — opens in B2), Hroka dialogue tier 1

## Optional / hidden objectives
- Listen to all three Voice lines (requires entering the mausoleum more than once) — unlocks codex entry "The Voice."
- Don't kill the Bone Golem — instead survive 60 seconds without dealing damage. He stops attacking and says *"You really don't know."* The fight ends. The tablet drops anyway. Flag `flag_golem_spared` set.
- Read Old Hellig's gravestone before entering the mausoleum (links to `sq_grave`).

## Branches & reactions
- After completion:
  - Skuld: asks if the mausoleum is safe to clean now. Yes/no opens a small sub-arc with her in B1.
  - Hawkeye: "The Wardens want a word with you. North."
  - Hroka: now speaks. Says "the stairs need you ready before they open." (B2 hook.)
  - Elder: every following greeting is shorter, more guarded.

## Tied to story arc
- Act: 1 — *Ash on your boots*
- Major theme: the world *knows you* before you know the world.
- Foreshadows: `mq03` (scholar translates the tablet), `mq07` (the tablet names the place — Ashheim), the Bone Hermit reveal in `mq08`.

## Implementation notes

### Existing in `mq02.tres`
- summary mentions the carved tablet and Bone Golem.
- prereq=mq01, target_location=barrows.

### To add (deepening)
- Voice in the Mausoleum: short timed `showDialog` triggered by zone_enter for the inner room.
- Phase 2 dialogue on Bone Golem (use existing boss-phase hook in `enemy.gd`).
- Tablet as a guaranteed drop item (new `tablet_warden_1.tres` resource, slot_type MATERIAL, not droppable).
- Branching turn-in dialogue with stacking flags.
- Hidden objective: spare-the-Golem path.

### Codex entries unlocked
- `bone_golem` — on first encounter.
- `the_voice` — on hearing all three lines.
- `warden_tablet` — on pickup.
- `hroka_intro` — on first speaking with Hroka.
