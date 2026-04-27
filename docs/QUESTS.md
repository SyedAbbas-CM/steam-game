# Quest Reference

Total: 42 quests across 5 categories.

Resource script: `scripts/quests/quest_definition.gd`
Quest files: `resources/quests/*.tres`

---

## Main Quest Chain (mq01-mq20)

The Hollow Tide storyline. Linear chain with two branch points (mq08/mq10 converge at mq11; mq12/mq13 converge at mq14).

| ID | Title | Lv | Location | Target | Prerequisites | Events | Summary |
|----|-------|----|----------|--------|---------------|--------|---------|
| mq01 | Waking in Ash | 2 | haven | duskfarm | q1 | kill(Scarecrow), zone_enter(duskfarm), quest(haven) | Cleanse 10 corrupted Scarecrows at Hollow Fields, report to Elder. |
| mq02 | What the Dead Left Behind | 2 | haven | barrows | mq01 | kill(*), boss_killed(Bone Golem), quest(haven) | Slay 5 blighted undead, defeat the Bone Golem, recover the carved tablet. Boss dungeon: Barrows. |
| mq03 | The Elder's Silence | 3 | haven | wastes | mq02 | kill(Bandit), quest(haven) | Elder refuses help. Scholar Vela will translate the tablet if you recover her stolen journal from bandits. |
| mq04 | Blood in the Grass | 5 | haven | wastes | mq03 | zone_enter(wastes) | Destroyed caravan in the wilds. Survivors saw black-robed figures heading south to the valley. |
| mq05 | The Hollow Shepherd | 7 | wastes | mirage | mq04 | boss_killed(Hollow Shepherd) | Silent village with hollowed residents. Pursue the Hollow Shepherd into the dungeon. Boss dungeon: sthel. |
| mq06 | The Warden's Warning | 8 | mirage | ashheim | mq05 | zone_enter(ashheim) | Deliver the Shepherd's letter to Warden Aldric in Heim. Learn about the Tide. Receive Key Fragment 1/3. |
| mq07 | Frozen Witnesses | 10 | ashheim | frostpass | mq06 | zone_enter(frostpass) | Frozen patrol in the cold wastes. Their journal describes a corrupted priestess. |
| mq08 | The Witch of Nord | 12 | frostpass | frostpass | mq07 | boss_killed(Corrupted Priestess) | Confront the corrupted priestess. Choice: spare or strike her down. Key Fragment 2/3. Boss dungeon: nord. |
| mq09 | A Ship That Shouldn't Sail | 12 | ashheim | cliffs | mq06 | zone_enter(briarvale), zone_enter(cliffs) | Ghost ship at Gomb harbor. Fisherman reveals hidden cove with branded crates. |
| mq10 | The Merchant's Deal | 14 | cliffs | saltmere | mq09 | activate(Dock Worker/Tavern Keeper/Smuggler), quest(saltmere) | Follow crates to pirate city. Guild Master Renzo offers a deal. Choice: refuse (fight) or accept (gold). Key Fragment 3/3. |
| mq11 | The Gathering | 14 | cenneth | cenneth | mq08 AND mq10 | activate(Elder The Fortress of Kor), quest(cenneth) | Bring 3 fragments to Sage Elowen. Gather 3 elders for the binding ritual. |
| mq12 | The Shattered Shrine of Thorns | 15 | cenneth | feverjungle | mq11 | boss_killed(feverjungle) | Clear corrupted shrine in Paititi's jungle. Kill the Tide-corrupted treant. |
| mq13 | The Relic of Talmita | 16 | cenneth | stormcrag | mq11 | boss_killed(stormcrag), quest(cenneth) | Retrieve the Sun Disc from the Peaks dungeon. Bandits consumed by the Tide guard it. |
| mq14 | The Road to Ultima Thule | 18 | cenneth | frostgrave | mq12 AND mq13 | zone_enter(frostgrave) | Corruption thickens. Hollowed villages along the road north. |
| mq15 | The Last Garrison | 19 | frostgrave | thule | mq14 | kill(Zombie/Skeleton/Spectre), quest(thule) | Ultima Thule under siege. Kill 15 Tide creatures to open the catacomb gate. |
| mq16 | The Catacombs | 20 | thule | thule | mq15 | boss_killed(thule) | Descend into catacombs. Kill the Tide Guardian construct. Ancient murals reveal the old kingdom. |
| mq17 | The Broken Seal | 22 | thule | hellgate | mq16 | boss_killed(The Hollow King) | Final boss: The Hollow King. 3-phase fight in the seal chamber. Boss dungeon: end. |
| mq18 | The Price of Sealing | 22 | hellgate | hellgate | mq17 | (immediate) | Choice: bind yourself, let Yara bind (if spared in mq08), or redirect the Tide. |
| mq19 | Echoes | 22 | hellgate | haven | mq18 | zone_enter(haven) | Return to Aria. Brand has changed to silver. Elder reveals your origin from the old kingdom. |
| mq20 | The Tide Recedes | 22 | haven | haven | mq19 | zone_enter(wastes/frostpass/ashheim/cenneth/thule), quest(haven) | Epilogue. Visit 5 zones to see aftermath of your choices. |

### Main Quest Choices

- **mq08**: Spare or kill Priestess Yara (affects mq18 options)
- **mq10**: Refuse Renzo (fight, get fragment) or accept deal (gold + fragment, forget what you saw)
- **mq18**: Three endings based on prior choices:
  - Bind yourself (always available) - 3000 XP
  - Let Yara bind (only if spared in mq08) - 3000 XP
  - Redirect the Tide (temporary fix) - 2000 XP

---

## Starter / Side Quests

| ID | Title | Lv | Location | Target | Prerequisites | Events | Summary |
|----|-------|----|----------|--------|---------------|--------|---------|
| q1 | Them Bones | 1 | haven | barrows | -- | kill(Skeleton), quest(haven) | Kill 20 Skeletons near the graveyard. Reward: 500 gold, 300 XP. |
| q14 | Jimbob's Lost Pickaxe | 2 | haven | -- | -- | kill(*), quest(haven) | Clear 10 dungeon monsters so Jimbob can retrieve his pickaxe. Reward: 400 gold, 300 XP. |
| sq1 | Potion Hoarder | 5 | haven | -- | -- | (none) | Jimbob wants 5 Red Potions for experiments. (Stub quest, no events.) |
| sq2 | Arnie's Challenge | 6 | haven | -- | -- | kill(Ghoul) | Kill 8 Ghouls to earn Arnie's respect. (No turn-in events.) |
| sq3 | Ghost Stories | 7 | haven | -- | -- | kill(Ghost) | Kill 15 Ghosts near the graveyard for Corvus's spooked inn patrons. (No turn-in events.) |
| q_fire_beast | The Fire Beast | 10 | haven | embermaw | -- | kill(Fire Beast), quest(duskfarm) | Slay the Fire Beast in the Embermaw caves. Reward: 2000 gold, 1500 XP. |

---

## LoY Area Quests

Imported from Legends of Yore. Fetch/kill quests with NPC dialogue and item rewards.

| ID | Title | Lv | Location | Target | Prerequisites | Events | Summary |
|----|-------|----|----------|--------|---------------|--------|---------|
| a0 | Behold! | 15 | mirage | -- | -- | kill(Beholder), quest(mirage) | K'atel needs a Beholder Tentacle for the priestess. Reward: 1000 XP, 1000 gold, Sandals of Hoff. |
| a1 | 3 Wishes | 27 | ashheim | -- | -- | kill(Genie), quest(ashheim) | Odin needs a stolen Genie Lamp returned. Reward: 2223 XP, 3000 gold, Lined Cap. |
| a2 | The Mighty Horn | 30 | grimhold | ashheim | -- | kill(Minotaur), quest(grimhold) | Eski's son is ill; needs a Minotaur Horn. Reward: 4000 XP, 8000 gold, Lined Boots. |
| a3 | Snakes Alive | 34 | haven | ashvale | -- | kill(Medusa), quest(haven) | Elder needs Medusa Hair for a cure potion. Reward: 4000 XP, 8000 gold, Cowled Robes. |
| a8 | Ghoul Hunt | 17 | mirage | mirage | -- | kill(Ghoul), quest(mirage) | K'atel offers bounty for killing 15 Ghouls. Reward: 500 XP, 1000 gold, Flinger. |
| a15 | Dragons Egg Delivery | 21 | grimhold | briarvale | -- | activate(Tyan), quest(grimhold) | Deliver a Dragon Egg from Eski to Tyan in Gombard. Reward: 1000 XP, 2000 gold, Prong Tome. |
| q6 | The Treaty | 28 | briarvale | haven | -- | activate(Elder/K'atel/Odin), quest(briarvale) | Get 3 town elders to sign a treaty. Class-specific reward + 8700 XP, 5000 gold. |

---

## LoY Zone Quests

High-level quests from specific zones. Originally from Legends of Yore endgame content.

| ID | Title | Lv | Location | Target | Prerequisites | Events | Summary |
|----|-------|----|----------|--------|---------------|--------|---------|
| z1 | Dark Side of Magic | 101 | cenneth | cenneth | -- | kill(Necromantic, 50% drop), quest(cenneth) | Lord Cennyn's Elven Horn stolen by a Necromantic. Reward: 5000 XP, 5000 gold, Corlion. |
| z5 | Parot Passion | 120 | brackwater | boghollow | -- | activate(Goodman Durnik), quest(brackwater) | Deliver Marty the parrot to Goodman Durnik. Reward: 2000 XP, 5000 gold, Moonstone. |
| z8 | End the Endermen | 140 | kor | stormcrag | -- | kill(Enderman), quest(kor) | Kill 5 Endermen north of Kor. Reward: 3000 XP, 1000 gold, Magical Gauntlets. |
| p1 | Harold's Happyness | 122 | duskport | -- | -- | activate(Flow), quest(duskport) | Deliver Harold the parrot to Flow in Naleg. Reward: 2000 XP, 3000 gold, Medal. |
| end | Vanquish Evil | 175 | haven | -- | -- | kill(Smorag), kill(Deathbringer), quest(haven) | Final LoY quest. Slay Deathbringer, become a Legend of Ashenmoor. Reward: 30000 XP. |

---

## Paragon Quests

Philosophical quests from the mentors in Aria (haven). These explore themes of perception, discipline, sacrifice, and pilgrimage.

| ID | Title | Lv | Location | Target | Prerequisites | Events | Summary |
|----|-------|----|----------|--------|---------------|--------|---------|
| pq_cave | Shadows Below | 3 | haven | -- | -- | kill(Skeleton/Zombie/Ghost/Mummy/Vampire), quest(haven) | Solmund asks you to observe 10 dungeon creatures. Dialogue choice affects XP (200 or 300). |
| pq_mean | The Balance | 4 | haven | -- | -- | kill(Skeleton), quest(haven) | Telos tests restraint: kill exactly 5 Skeletons. Perfect=400 XP+250 gold, over=200 XP, under=keep trying. |
| pq_doubt | The Burning | 5 | haven | -- | pq_cave | quest(haven) | Heshem wants Red+Blue Potions. Choice: let him destroy them (500 XP) or keep them (250 XP). |
| pq_journeys | The Pilgrim's Path | 7 | haven | -- | pq_cave | zone_enter(barrows/duskfarm), quest(haven), activate(any NPC) | Walk four journeys: visit Barrows, Farmlands, return to Aria, speak to a townsperson. Reward: 600 XP, 300 gold. |

---

## Quest Flow

### Main Story Prerequisite Chain

```
q1 (Them Bones)
  |
mq01 (Waking in Ash)
  |
mq02 (What the Dead Left Behind)
  |
mq03 (The Elder's Silence)
  |
mq04 (Blood in the Grass)
  |
mq05 (The Hollow Shepherd)
  |
mq06 (The Warden's Warning)
  |                  \
mq07                mq09
  |                    |
mq08 (choice)      mq10 (choice)
  \                  /
   mq11 (The Gathering)  [requires BOTH mq08 AND mq10]
   /                \
mq12              mq13
   \                /
   mq14 (Road to Ultima Thule)  [requires BOTH mq12 AND mq13]
     |
   mq15 (The Last Garrison)
     |
   mq16 (The Catacombs)
     |
   mq17 (The Broken Seal - FINAL BOSS)
     |
   mq18 (The Price of Sealing - ENDING CHOICE)
     |
   mq19 (Echoes)
     |
   mq20 (The Tide Recedes - EPILOGUE)
```

### Paragon Quest Chain

```
pq_cave (Shadows Below)
  |          \
pq_doubt    pq_journeys
```

### Standalone Quest Chains

```
q1 (Them Bones) --> mq01 (main story entry point)

q14, sq1, sq2, sq3, q_fire_beast  (independent side quests)

a0, a1, a2, a3, a8, a15, q6       (independent LoY area quests)

z1, z5, z8, p1, end               (independent LoY zone/endgame quests)

pq_mean                            (independent paragon quest)
```

---

## Event Types Reference

| Type | Description |
|------|-------------|
| `kill` | Triggered when a specific enemy type is killed. `param` = enemy name, or `*` for any. |
| `boss_killed` | Triggered when a dungeon boss is killed. `param` = boss enemy name. |
| `zone_enter` | Triggered when entering a zone. `param` = zone ID. |
| `quest` | Periodic check when entering a zone. `param` = zone ID for turn-in location. |
| `activate` | Triggered when interacting with a specific NPC. `param` = NPC name. |

## Boss Dungeons

| Quest | Dungeon Prefix | Boss Enemy |
|-------|---------------|------------|
| mq02 | Barrows | Bone Golem |
| mq05 | sthel | Hollow Shepherd |
| mq08 | nord | Corrupted Priestess |
| mq17 | end | The Hollow King |

## Level Distribution

- **Lv 1-10**: q1, mq01-mq04, q14, sq1-sq3, pq_cave, pq_mean, pq_doubt, pq_journeys, q_fire_beast
- **Lv 10-20**: mq05-mq16, a0, a8, a15
- **Lv 20-35**: mq17-mq20, a1, a2, a3, q6
- **Lv 100+**: z1, z5, z8, p1, end
