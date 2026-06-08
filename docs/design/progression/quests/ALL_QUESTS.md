# All Quests — Single File Reference

> **One file with every quest in the game.** Source data pulled directly from
> the `.tres` files at `resources/quests/`. If a quest also has a per-quest
> deep-dive doc in this folder, the link is in the **Doc** column.
>
> Path: `docs/design/progression/quests/ALL_QUESTS.md`
> Total: **42 quests**

## Story spine at a glance

```
q1 → mq01 → mq02 → mq03 → mq04 → mq05 → mq06 ┬─→ mq07 → mq08 ─┐
                                              │                 ├─→ mq11 → mq12 / mq13 → mq14 → mq15 → mq16 → mq17 → mq18 → mq19 → mq20 → end
                                              └─→ mq09 → mq10 ──┘
```

Side branch: `q14`, `sq1`, `sq2`, `sq3`, `q_fire_beast` (all Haven).
Pet branch: `pq_cave` → `pq_doubt` / `pq_journeys`, plus `pq_mean`.
Ashfields odd jobs: `a0`, `a1`, `a2`, `a3`, `a8`, `a15`.
Zone discovery: `z1`, `z5`, `z8`.
Misc: `p1`, `q6`.

## Canon terms

| Term | What it is | First used |
|------|------------|------------|
| The Sundering | the ancient event that cracked Hellgate | codex |
| The Tide | local name for the ongoing leak. Most NPCs say "the Tide" not "the Sundering." | `mq05`/`mq06` |
| The Hollow Shepherd | mid-rank herald of the Tide | `mq05` |
| The Woman in White | the antagonist. Not a person. | `mq06`/`mq07` |
| Three Key Fragments | 1/3 Warden of Heim → player, 2/3 cult, 3/3 Hellgate | `mq06` |
| Cult of the Open Wound | her followers, black-robed | `mq04` |
| The Wardens | Coran, Briard, Warden of Heim, Iola (ex) | `mq03`/`mq04` |
| Wound Guardians | old sealed sentinels. Bone Golem, Fire Beast, etc. They all speak. | `mq02`/`q_fire_beast` |

---

# Band B0 — Ravenhollow opening (Lv 1–3)

### `q1` — Them Bones
- **Level**: 1
- **Location** → **Target**: haven → barrows
- **Prereq**: none — opening quest
- **Doc**: [q1_them_bones.md](q1_them_bones.md)
- **Summary (from .tres)**: The Elder has asked you to cull 20 Skeletons that have risen near the graveyard outside of town.

### `mq01` — Waking in Ash
- **Level**: 2
- **Location** → **Target**: haven → duskfarm
- **Prereq**: `q1`
- **Doc**: [mq01_waking_in_ash.md](mq01_waking_in_ash.md)
- **Summary**: The Elder says the brand on your arm matches symbols found on dead livestock at the farm. Travel to Hollow Fields, cleanse 10 corrupted Scarecrows, then report back.

### `mq02` — What the Dead Left Behind
- **Level**: 2
- **Location** → **Target**: haven → barrows
- **Prereq**: `mq01`
- **Doc**: [mq02_what_the_dead_left_behind.md](mq02_what_the_dead_left_behind.md)
- **Summary**: The ichor trail leads from the farm to the crypts beneath Ravenhollow's graveyard. Slay 5 blighted undead, defeat the Bone Golem guarding the depths, and recover the carved tablet.

### `mq03` — The Elder's Silence
- **Level**: 3
- **Location** → **Target**: haven → wastes
- **Prereq**: `mq02`
- **Doc**: [mq03_the_elders_silence.md](mq03_the_elders_silence.md)
- **Summary**: The Elder refuses to help. A scholar offers to translate the tablet — but needs her stolen journal from the wilds.

### `q14` — Jimbob's Lost Pickaxe
- **Level**: 2
- **Location** → **Target**: haven → (any dungeon)
- **Prereq**: none — side
- **Doc**: [q14_jimbobs_lost_pickaxe.md](q14_jimbobs_lost_pickaxe.md)
- **Summary**: Jimbob lost his pickaxe in the dungeons. Clear 10 enemies down there to search for it.

---

# Band B1 — Wastes + Hollow Fields + Embermaw runway (Lv 4–8)

### `mq04` — Blood in the Grass
- **Level**: 5
- **Location** → **Target**: haven → wastes
- **Prereq**: `mq03`
- **Doc**: [mq04_blood_in_the_grass.md](mq04_blood_in_the_grass.md)
- **Summary**: Your mark burns in the wilds. A destroyed caravan — survivors saw black-robed figures heading south.

### `sq1` — Potion Hoarder
- **Level**: 5
- **Location**: haven (Corvus)
- **Prereq**: `q1` done (offered after)
- **Doc**: [sq1_potion_hoarder.md](sq1_potion_hoarder.md)
- **Summary**: Jimbob wants 5 Red Potions for his experiments. Find them in dungeon chests and bring them to him.
- *Note: summary attributes the potions to Jimbob, but the canon owner is Corvus — fix at deepening pass.*

### `sq2` — Arnie's Challenge
- **Level**: 6
- **Location**: haven (Arnie)
- **Prereq**: owns a weapon from Arnie
- **Doc**: [sq2_arnies_challenge.md](sq2_arnies_challenge.md)
- **Summary**: Arnie wants proof of your fighting skill. Kill 8 Ghouls to earn his respect and access to better gear.

### `sq3` — Ghost Stories
- **Level**: 7
- **Location**: haven (Corvus)
- **Prereq**: visited the Barrows
- **Doc**: [sq3_ghost_stories.md](sq3_ghost_stories.md)
- **Summary**: Corvus's inn patrons are spooked by ghost sightings near the graveyard. Kill 15 Ghosts to put their fears to rest.

### `mq05` — The Hollow Shepherd
- **Level**: 7
- **Location** → **Target**: wastes → mirage
- **Prereq**: `mq04`
- **Doc**: [mq05_the_hollow_shepherd.md](mq05_the_hollow_shepherd.md)
- **Summary**: A silent village — residents stand motionless, eyes black. The Hollow Shepherd commands them. Pursue into the dungeon.

---

# Band B2 — Mirage / Ashheim / Embermaw (Lv 8–15)

### `mq06` — The Warden's Warning
- **Level**: 8
- **Location** → **Target**: mirage → ashheim
- **Prereq**: `mq05`
- **Doc**: [mq06_the_wardens_warning.md](mq06_the_wardens_warning.md)
- **Summary**: Deliver the Shepherd's letter to the Warden in Heim. Learn the truth about the Tide and receive Key Fragment 1/3.
- **Branch point** — unlocks both `mq07` (north fork) and `mq09` (south fork).

### `q_fire_beast` — The Fire Beast
- **Level**: 10
- **Location** → **Target**: haven → embermaw
- **Prereq**: none — offered by Dafydd after `mq01`
- **Doc**: [q_fire_beast.md](q_fire_beast.md)
- **Summary**: A fearsome beast lurks in the Embermaw east of Hollow Fields. Defeat it to protect the farmlands.
- *(Per `04_quest_flow.md`, fold this into the critical path as the `mq06`-tier optional.)*

### `mq07` — Frozen Witnesses
- **Level**: 10
- **Location** → **Target**: ashheim → frostpass
- **Prereq**: `mq06`
- **Doc**: [mq07_frozen_witnesses.md](mq07_frozen_witnesses.md)
- **Summary**: A patrol frozen in black ice in the cold wastes. Their journal describes a 'woman in white.'

### `mq08` — The Witch of Nord
- **Level**: 12
- **Location** → **Target**: frostpass → frostpass
- **Prereq**: `mq07`
- **Doc**: [mq08_witch_of_nord.md](mq08_witch_of_nord.md)
- **Summary**: Confront the corrupted priestess in the frozen dungeon. **Choose: spare her or strike her down.**

### `mq09` — A Ship That Shouldn't Sail
- **Level**: 12
- **Location** → **Target**: ashheim → cliffs
- **Prereq**: `mq06`
- **Doc**: [mq09_a_ship_that_shouldnt_sail.md](mq09_a_ship_that_shouldnt_sail.md)
- **Summary**: A ghost ship at Gomb harbor. The harbor master denies it. A fisherman points to a hidden cove.

---

# Band B3 — Outlands (Lv 14–18)

### `mq10` — The Merchant's Deal
- **Level**: 14
- **Location** → **Target**: cliffs → saltmere
- **Prereq**: `mq09`
- **Doc**: [mq10_the_merchants_deal.md](mq10_the_merchants_deal.md)
- **Summary**: Follow the crates to the pirate city. The guild master spreads Tide artifacts for power. **Join or fight.**

### `mq11` — The Gathering
- **Level**: 14
- **Location** → **Target**: cenneth → cenneth
- **Prereq**: none in `.tres` — but narratively requires both forks (`mq08` AND `mq10`) merged
- **Summary**: Bring the 3 fragments to the Sage in Cennyn. She needs 3 elders to perform the binding ritual.
- *Doc pending — Key Fragments 2/3 collected by this point.*

### `mq12` — The Shattered Shrine of Thorns
- **Level**: 15
- **Location** → **Target**: cenneth → feverjungle
- **Prereq**: `mq11`
- **Summary**: Clear the corrupted shrine in Paititi's jungle dungeon. Kill the Tide-corrupted treant.

### `mq13` — The Relic of Talmita
- **Level**: 16
- **Location** → **Target**: cenneth → stormcrag
- **Prereq**: `mq11`
- **Summary**: Retrieve the Sun Disc from the Peaks dungeon. Bandits consumed by the Tide guard it.
- *Branch with `mq12` — player may do them in either order. After both, `mq14` unlocks.*

### `mq14` — The Road to Ultima Thule
- **Level**: 18
- **Location** → **Target**: cenneth → frostgrave
- **Prereq**: none in `.tres` — *probably should be `mq12` AND `mq13`. Audit.*
- **Summary**: The corruption thickens. The vale village is hollowed. The frozen ground bleeds ichor.

---

# Band B4 — Approaches (Lv 19–22)

### `mq15` — The Last Garrison
- **Level**: 19
- **Location** → **Target**: frostgrave → thule
- **Prereq**: `mq14`
- **Summary**: Ultima Thule's garrison is under siege. Kill 15 Tide creatures. The commander will open the catacomb gate.

### `mq16` — The Catacombs
- **Level**: 20
- **Location** → **Target**: thule → thule
- **Prereq**: `mq15`
- **Summary**: Descend into Ultima Thule's catacombs. Ancient lore reveals the old kingdom. Kill the Tide Guardian construct.

### `mq17` — The Broken Seal
- **Level**: 22
- **Location** → **Target**: thule → hellgate
- **Prereq**: `mq16`
- **Summary**: The seal chamber is shattered. The Hollow King awaits. Use the Seal Key to weaken him. 3-phase fight.

---

# Band B5 — Endgame (Lv 22+)

### `mq18` — The Price of Sealing
- **Level**: 22
- **Location** → **Target**: hellgate → hellgate
- **Prereq**: `mq17`
- **Summary**: The seal must be remade. Someone must bind permanently. **Choose who — or redirect the Tide elsewhere.**
- *Major moral choice. Determines who survives into the epilogue.*

### `mq19` — Echoes
- **Level**: 22
- **Location** → **Target**: hellgate → haven
- **Prereq**: `mq18`
- **Summary**: Return to Aria. The Healer sees your brand has changed. The Elder finally speaks the truth.

### `mq20` — The Tide Recedes
- **Level**: 22
- **Location** → **Target**: haven → haven
- **Prereq**: `mq19`
- **Summary**: Visit 5 zones to see the aftermath of your choices. The world remembers.

### `end` — Vanquish Evil
- **Level**: 175 (currently — drop to L90 per `00_master_progression.md`)
- **Location**: haven
- **Prereq**: none in `.tres` — likely `mq20`
- **Summary**: *(empty in `.tres` — author the final-choice text)*

---

# Ashfields side arc — `a0`, `a1`, `a2`, `a3`, `a8`, `a15`

These look like Ashfields odd-jobs (older content). Audit which are still live.

### `a0` — Behold!
- Level 15, location mirage, no target/prereq, summary empty.

### `a1` — 3 wishes
- Level 27, location ashheim, no target/prereq, summary empty.

### `a2` — The Mighty Horn
- Level 30, grimhold → ashheim, no prereq, summary empty.

### `a3` — Snakes Alive
- Level 34, haven → ashvale, no prereq, summary empty.

### `a8` — Ghoul Hunt
- Level 17, mirage → mirage, no prereq, summary empty.

### `a15` — Dragons Egg Delivery
- Level 21, grimhold → briarvale, no prereq, summary empty.

---

# Pet quests — `p1`, `pq_*`

### `p1` — Harold's Happyness
- Level 122, duskport, summary empty.
- *Pet starter — but level 122 looks wrong. Likely a placeholder.*

### `pq_cave` — Shadows Below
- Level 3, aria, no prereq.
- **Summary**: Solmund wants you to observe the creatures in the dungeon. Go below and look carefully at what you're really fighting.

### `pq_doubt` — The Burning
- Level 5, aria, prereq `pq_cave`.
- **Summary**: Heshem wants a Red Potion and a Blue Potion. He says he needs them for something important.

### `pq_journeys` — The Pilgrim's Path
- Level 7, aria, prereq `pq_cave`.
- **Summary**: Muraad asks you to walk the four journeys: visit the Graveyard, then the Farmlands, return to Aria, and finally speak to someone in town.

### `pq_mean` — The Balance
- Level 4, aria, no prereq.
- **Summary**: Telos wants you to kill exactly 5 Skeletons in the dungeon. Not 4, not 6. Five. Discipline is the foundation.

---

# Zone discovery — `z1`, `z5`, `z8`

### `z1` — Dark side of Magic
- Level 101, cenneth → cenneth, summary empty.

### `z5` — Parot Passion
- Level 120, brackwater → boghollow, summary empty.

### `z8` — End the Endermen
- Level 140, kor → stormcrag, summary empty.

*These all have very high levels and empty summaries. Likely zone-discovery codex unlocks dressed as quests. Audit and rename or cut.*

---

# Misc

### `q6` — The Treaty
- Level 28, briarvale → haven, no prereq, summary empty.
- *Orphan. May tie into B4. Audit.*

---

# Status

| Status | Count | IDs |
|--------|-------|-----|
| ✅ Detailed doc | 13 | q1, mq01, mq02, mq03, mq04, mq05, mq06, mq07, q14, sq1, sq2, sq3, q_fire_beast |
| 🟡 Spine, doc pending | 13 | mq08, mq09, mq10, mq11, mq12, mq13, mq14, mq15, mq16, mq17, mq18, mq19, mq20 |
| 🟡 End beat, doc pending | 1 | end |
| 🟢 Pet, doc pending | 5 | p1, pq_cave, pq_doubt, pq_journeys, pq_mean |
| 🔲 Audit (empty summary) | 9 | a0, a1, a2, a3, a8, a15, z1, z5, z8 |
| 🔲 Audit (orphan) | 1 | q6 |
| **Total** | **42** | |

When you want any of the 🟡 entries elevated to detailed docs, ask for the batch (e.g. "do mq08–mq10"). When you want the 🔲 audit done, ask for it.
