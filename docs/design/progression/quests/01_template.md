# Template

> Copy this when adding a new quest doc. Replace `[id]`, `[Title]`, etc.

# Quest [id] — [Title]

## Quick facts

| Field | Value |
|-------|-------|
| ID | `[id]` |
| Title | [Title] |
| Band | B[0–5] |
| Recommended level | [n] |
| Quest giver | [NPC] in [zone] |
| Turn-in | [NPC] in [zone] |
| Action location | [zone] |
| Prerequisite | `[quest_id]` or none |
| Critical path? | yes / no |

## Summary
One paragraph — what does the player do, in one breath.

## Lore context
What's happening in the world *during* this quest. Why now? Why this NPC?

## NPCs involved
- **[Name]** — role, mood, what they want, key dialogue beats.

## Steps (multi-beat)
1. **Talk** — the NPC asks for help, gives initial hook.
2. **Act** — player goes to the action location and does the thing.
3. **Return** — turn-in dialogue. Sometimes a twist.

(More than 3 only if narratively necessary.)

## Rewards
- XP: [n]
- Gold: [n]
- Items: ...
- Unlocks: next quest, NPC dialogue, codex entry, etc.

## Optional / hidden objectives
- Find [readable] in [location]
- Talk to [NPC] before [trigger] for bonus dialogue
- Spare / kill [NPC] choice

## Branches & reactions
- After this quest, [NPC1] says: "..."
- If you did `[sq_X]` first, the dialogue acknowledges it.

## Tied to story arc
- Act / band: B[n]
- Major theme: refugee → Warden initiate → cracks → wounds → gates → close
- Foreshadows: [later quest IDs]

## Implementation notes

### Existing in `[id].tres`
- `level`, `location`, `target_location`, `prerequisite` values.
- start_script: showDialog → spawnEnemies → startQuest.
- events: kill X, quest turn-in.

### To add (deepening)
- New step between talk and act (e.g. "showDialog ... investigate the trail").
- New `interact` event for a lore-drop item.
- New `if` branch reacting to a prior choice.

### Codex entries unlocked
- [Codex entry ID] when quest accepted
- [Codex entry ID] when complete
