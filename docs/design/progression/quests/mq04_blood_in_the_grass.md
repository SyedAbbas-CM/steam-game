# Quest mq04 — Blood in the Grass

## Quick facts

| Field | Value |
|-------|-------|
| ID | `mq04` |
| Title | Blood in the Grass |
| Band | B1 |
| Recommended level | 5 |
| Quest giver | **Warden Captain Coran** in the Warden's Camp |
| Turn-in | Coran |
| Action location | The Wastes (caravan site → cult camp) |
| Prerequisite | `mq03` |
| Critical path? | yes |

## Summary
The tablet says *Embermaw*. Iola sends you to Coran. Coran sends you to the destroyed caravan north of the road — survivors saw **black-robed figures heading south**. Find them. Find what they took.

## Lore context
First actual Warden encounter. Coran sizes you up the same way Iola did — by giving you something hard and watching how you handle it. The black-robed figures are the **Cult of the Open Wound**, a small faction that *wants* the Hellgate to keep leaking because they think the corruption is a blessing. They're the recurring antagonist faction through B2 and B3. This is their introduction.

## NPCs involved
- **Coran** (NEW Warden Captain) — your future mentor. Pragmatic. Doesn't trust you yet but is willing to use you. Speaks in short sentences.
- **Cult acolytes** — generic combat. New enemy archetype.
- **Survivor of the caravan** — wounded, hiding in a wagon. Tells you what they saw, asks for water. Optional bandage.
- **Bandits from `mq03`** (if spared) — appear as cult lookouts. Recognise you. Walk away rather than fight if you spared them.

## Steps

1. **Coran's briefing** — short dialogue. Sketch map of the caravan site.
2. **Travel to the caravan wreck** — a new scripted location in the northern Wastes.
3. **Talk to the survivor** — they describe the figures, point south.
4. **Optional: bandage them** — if you have one, they survive (codex entry). If you don't, they die offscreen by the time you return.
5. **Follow the trail** — short scripted route. If `flag_spared_bandits` is set, two lookouts recognise you and walk away (no fight).
6. **Cult camp** — 4 acolyte fight + 1 named cult lieutenant. The lieutenant has a folded map showing **Embermaw circled**.
7. **Recover the map** — turn-in trigger.
8. **Return to Coran** — he reads the map, gives a long-by-his-standards speech: *"Embermaw was the first lesser wound. Iola says you can find it. Then you find it."* Unlocks `mq05` / B2 transition.

## Rewards
- XP: 1200
- Gold: 1500
- Items: **Warden's Cord** (NEW) — accessory, +5 stamina regen, "+15% damage vs `cult`" archetype
- Unlocks: `mq05`, Coran's dialogue tier 2, Warden patrol greets you by name

## Optional / hidden objectives
- Save the caravan survivor (have a bandage on you).
- Spare the cult lieutenant — they say *"you don't know what you'll become."* Flag `flag_spared_lieutenant` — they reappear in `mq10` as a more senior cultist.
- Find the cult shrine in the camp (small detour). Reading the inscription unlocks codex entry *"Cult of the Open Wound."*

## Branches & reactions
- After completion:
  - Iola: offers a permanent +1 MP regen passive *"for paying attention."*
  - Coran: introduces Captain Briard's name for the first time — *"You'll meet Briard at the Ironspine. He won't like you."*
  - Survivor (if saved): appears in Ravenhollow as a refugee NPC in B3.
  - Warden patrols: now offer small repeatable bounty quests in the Wastes (radiant content hook).

## Tied to story arc
- Act: 2 — *The Wardens know*
- Major theme: there's an active enemy faction. They have a name.
- Foreshadows: `mq06` (cult portal to Mirage), `mq10` (Briard vs Coran split), `mq11–mq13` (Cenneth as cult stronghold).

## Implementation notes

### Existing in `mq04.tres`
- summary already mentions caravan and black-robed figures.
- prereq=mq03, target_location=wastes.

### To add (deepening)
- Caravan wreck as a scripted set piece in the northern Wastes (new spawn location).
- Cult acolyte enemy definitions (new `cult_acolyte.tres`, `cult_lieutenant.tres`).
- Spared-lieutenant branch carries to `mq10`.
- Optional bandage interaction.

### Codex entries unlocked
- `coran_intro` — on first meeting.
- `cult_of_the_open_wound` — on first acolyte encounter.
- `embermaw_named` — on map pickup.
- `the_warden_cord` — on item pickup.
