# Quest mq07 — Frozen Witnesses

## Quick facts

| Field | Value |
|-------|-------|
| ID | `mq07` |
| Title | Frozen Witnesses |
| Band | B2 |
| Recommended level | 10 |
| Quest giver | **Warden of Heim** (auto on Ashheim → Frostpass departure) |
| Turn-in | first frozen patrol's journal — no NPC |
| Action location | Frostpass |
| Prerequisite | `mq06` |
| Critical path? | yes — north fork (parallel to `mq09` south fork) |

## Summary
A Warden patrol left for the cold wastes weeks ago. Their bodies are upright, frozen in black ice. Their journal mentions a *woman in white*. Find the journal, read the last entry, return what you learn to Heim.

## Lore context
This is the player's first encounter with the **woman in white** — not in person, but in the patrol's account of her. She passes through Frostpass at night. The patrol watched her for three nights before they froze. The journal's last entry is in a different hand than the first — it's *her* writing. Her message:

> *"You will hear my voice in the cold. You will hear it again at the bottom of the world. Don't follow me. Or do. It changes nothing."*

This is the first time the player sees the antagonist's actual voice on the page. She isn't a person. The Warden of Heim said so. What she is, exactly, is held back until B4.

The "frozen witnesses" pose isn't decorative — each patrol member's last act was turning toward her. You can read the angles. Five of them facing one point.

## NPCs involved
- **Warden of Heim** — short send-off. Hands you a wax-sealed pack of provisions; the seal is the same as the Shepherd's letter (Tide motif).
- **Frozen patrol leader** (named NPC; dead) — body holds the journal. Inscribed armour.
- **Iola** (via voice / message arrives at Heim mid-quest) — sends a coded note saying *"come back if she speaks to you."*
- **The woman in white** — never appears. Only her handwriting.

## Steps

1. **Departure from Heim** — Warden gives provisions, sketch map.
2. **Cross Frostpass** — first Frostpass entry. Banner fade. Travel set piece — wind audio, snow that obscures distance.
3. **Find the patrol** — five frozen Wardens in a clearing. All facing the same direction.
4. **Optional: stand at their focal point** — trace the angles, walk to where they were looking. There's a single black footprint. Codex entry.
5. **Take the journal** — held by the patrol leader. Reading is required on turn-in.
6. **Last entry** — a screen-fading dialogue card with her message. The player can't skip the first read. Subsequent reads are skippable.
7. **Optional: leave the patrol with respect** — interact with each frozen body individually. They cannot be looted; only this respectful interact counts. Five interacts → codex entry *"The Patrol Saluted."*
8. **Return through Frostpass to Heim** — Warden takes the journal, copies the last entry into his notes. Hands you a reward and a question.
9. **Choice**: he asks if you want to chase her. *"No"* — he goes himself, off-screen, and dies between B2 and B3 (his absence is felt). *"Yes"* — he stays in Ashheim and you take the lead. Flag `flag_player_leads_chase`.

## Rewards
- XP: 4000
- Gold: 3200
- Items: **Patrol Captain's Cloak** (B3-tier defensive cloak — high armor, no flair)
- Unlocks: `mq08` (the next step regardless of choice), flag that affects `mq11` (Coran or Briard leadership).

## Optional / hidden objectives
- Don't read the last entry yourself. Bring the journal sealed to Heim. He reads it aloud. Different codex framing. Iola later says *"smart."*
- Walk past the footprint without stepping in it. Iola can read the impression remotely (codex entry).
- Take the patrol leader's broken sword. It can be reforged later by the Coffin Smith (B2 NPC); becomes a unique B3 weapon.

## Branches & reactions
- After completion:
  - Warden of Heim: changes greeting depending on the choice in step 9.
  - Iola: comments on whether you read the entry yourself.
  - Coran: hears about the patrol. Sends his condolences north.

## Tied to story arc
- Act: 3 — *Following the cracks*
- Major theme: the antagonist's *voice* arrives before she does. Words on a page that shouldn't exist.
- Foreshadows: `mq08` (the Witch of Nord lights the same kind of candle as the Shepherd), `mq11`–`mq14` (the Cenneth cult is shaped by her writing), `mq19` (you hear her again at Hellgate).

## Implementation notes

### Existing in `mq07.tres`
- summary: "A patrol frozen in black ice in the cold wastes. Their journal describes a 'woman in white.'"
- prereq=mq06, target_location=frostpass.

### To add (deepening)
- Frostpass clearing set piece with 5 named frozen NPC bodies.
- Patrol journal as a key item with first/last entry pages, sealed/unsealed state.
- Choice in step 9 sets a flag affecting `mq11` (Coran or Briard leads the player).
- Optional black footprint interact.
- Optional respectful-salute mini-objective.

### Codex entries unlocked
- `frostpass_intro` — first entry.
- `the_frozen_patrol` — finding the bodies.
- `the_woman_in_white_writing` — reading the last entry.
- `the_patrol_saluted` — if all five are saluted.
- `the_black_footprint` — at the focal point.
