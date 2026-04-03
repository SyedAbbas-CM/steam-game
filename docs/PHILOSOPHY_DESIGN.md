# Philosophy-as-Gameplay Design Document

## Core Principle
Philosophy is **embedded in gameplay mechanics, choices, and consequences** — not discovered by talking to NPCs who lecture. Dialogue supports but doesn't carry the teaching. NPCs have fantasy names that subtly hint at their inspiration. The player should absorb philosophical ideas through *playing*, not reading.

---

## Design Rules

1. **Never lecture.** NPCs are characters shaped by philosophy, not professors. Solmund doesn't say "I'm teaching Plato's Cave" — he's a cryptic hermit who talks about shadows.
2. **The mechanic IS the lesson.** If a quest teaches restraint (Aristotle's Golden Mean), the player must literally restrain themselves in gameplay — kill exactly 5, not more.
3. **Real consequences.** Philosophical choices must cost something real: items, XP, gold, stats. Not just flavor text.
4. **No right answers.** Both paths in a philosophical dilemma should be valid. The game doesn't judge — it reflects.
5. **Subtle naming.** NPC names hint at their inspiration without being obvious (Solmund ← Plato, Heshem ← Al-Ghazali, Aldric ← Kant).

---

## Implemented (Phase 1 — Aria Town)

### Seven Philosopher NPCs
| NPC | Inspired By | Role | Core Idea |
|-----|-----------|------|-----------|
| Solmund | Plato | Reclusive hermit | Allegory of the Cave — things aren't what they seem |
| Muraad | Mullah Sadra | Wandering pilgrim | Four Journeys — transformation through travel |
| Heshem | Al-Ghazali | Former scholar | Doubt as path to truth — the crisis of certainty |
| Wahid | Ibn Arabi | Mystic | Unity of Being — connections in everything |
| Aldric | Kant | Rigid lawkeeper | Categorical imperative — universal rules |
| Navid | Rumi | Joyful singer | Love as driving force |
| Telos | Aristotle | Naturalist | Golden mean — virtue through balance |

### Four Quest Chains
1. **"Shadows Below"** (pq_cave) — Plato's Cave. Kill 10 undead but quest says "observe." Turn-in asks "What did you see?" Both answers valid.
2. **"The Burning"** (pq_doubt) — Al-Ghazali's Crisis. Collect potions, then choose: destroy them (lose items, gain XP) or keep them (practical, less XP). The loss IS the teaching.
3. **"The Pilgrim's Path"** (pq_journeys) — Sadra's Four Journeys. Visit zones representing stages of spiritual growth. Fourth journey: return to serve others (talk to any NPC).
4. **"The Balance"** (pq_mean) — Aristotle's Golden Mean. Kill exactly 5 skeletons. More = reduced reward. Restraint as gameplay.

### Dungeon Quotes
30% chance dungeon elder says a thematic quote attributed to "old words carved on the wall."

---

## Future Plans (Phase 2+)

### More Philosophers to Add

#### Existentialists
| Philosopher | Mechanic Idea |
|-------------|---------------|
| **Kierkegaard** | A quest with a genuine leap of faith — jump off a cliff into darkness. Either you find a hidden area (reward), or you die and respawn. The game doesn't tell you which. You must choose to jump or not. |
| **Nietzsche** | Eternal recurrence mechanic — a dungeon floor that loops. Each loop the enemies are stronger but so is the player. The question: would you choose to live this floor forever? A room that asks "Again?" and you can leave or repeat for escalating rewards. |
| **Sartre** | Freedom/responsibility — an NPC gives you absolute freedom: "Do whatever you want in this dungeon." No quest marker, no objective. What you choose to do (or not do) IS the quest completion. Reward based on actions taken. |
| **Camus** | Absurdist — a quest to push a boulder to the top of a hill. It rolls back down. NPC asks you to do it again. And again. Third time, the quest completes whether you push or refuse. "The struggle itself is enough to fill one's heart." |

#### Islamic Philosophy (Expanded)
| Philosopher | Mechanic Idea |
|-------------|---------------|
| **Ibn Sina (Avicenna)** | The Floating Man — a dungeon room where all UI is stripped. No HP bar, no minimap, no damage numbers. You fight blind. When you exit, everything returns. "What did you know about yourself when you had nothing to see?" |
| **Al-Farabi** | The Virtuous City — a zone-building quest where your choices shape an NPC settlement. Help the blacksmith or the healer? Guard the gate or explore? The settlement's outcome reflects your values. |
| **Ibn Rushd (Averroes)** | Reason vs. tradition — two NPCs give contradictory advice about a dungeon. One uses logic ("the path north has fewer enemies based on patrol patterns"), one uses faith ("the ancestors say go south"). Both are right in different ways. |
| **Ibn Khaldun** | Rise and fall of civilizations — a multi-floor dungeon where each floor represents a stage: nomadic strength → civilization → decadence → collapse. Enemy types and room aesthetics shift to match. |

#### Eastern Philosophy
| Philosopher | Mechanic Idea |
|-------------|---------------|
| **Confucius** | Filial piety / social harmony — quests that reward you for helping lower-level players (if multiplayer) or NPC villagers. The more you serve others, the stronger your "Harmony" buff becomes. |
| **Lao Tzu** | Wu wei (non-action) — a boss fight where attacking makes the boss stronger. The solution is to dodge and wait. The boss defeats itself. "The soft overcomes the hard." |
| **Sun Tzu** | Art of War — a battle encounter where you're outnumbered 10:1 but given terrain advantages. Victory requires using the environment, not brute force. |
| **Buddha** | Attachment — an incredibly powerful weapon drops early. Mid-dungeon, an NPC asks you to give it up. If you do: permanent stat boost. If you keep it: the weapon slowly loses power each floor. |

#### Western Classics
| Philosopher | Mechanic Idea |
|-------------|---------------|
| **Socrates** | The Socratic method — an NPC who only asks questions. Each answer leads to another question. The quest completes when you say "I don't know." Reward: Wisdom stat boost. |
| **Epicurus** | Pleasure vs. pain — a room with two doors. One promises treasure (but has traps). One promises nothing (but is safe with a hidden reward). Moderate pleasure > excessive pursuit. |
| **Marcus Aurelius** | Stoicism — a gauntlet where the game actively tries to frustrate you: reversed controls, screen shake, fake death screens. If you persevere without quitting, massive reward. |
| **Descartes** | Systematic doubt — a dungeon where some walls are illusions, some enemies are fake (deal no damage), some items are mirages. You must doubt everything you see. |

### Mechanical Themes to Explore

#### Philosophy as Status Effects
- **Doubt** (Al-Ghazali): Temporarily reduces damage but increases crit chance — uncertainty opens new possibilities
- **Harmony** (Confucius): Buff that grows when near allies, fades when alone
- **Attachment** (Buddha): Carrying more items reduces speed — letting go makes you faster
- **Will to Power** (Nietzsche): Killing streak increases all stats, but stopping the streak causes a crash

#### Philosophy as Room Encounters
- **The Cave** (Plato): Dark room, enemies are shadows that deal no damage. Real enemy hides behind a light source.
- **The Trolley** (Philippa Foot): Two rooms connected — saving one group of NPCs dooms the other. Timer-based.
- **Ship of Theseus**: A companion NPC that slowly changes parts. At the end, is it the same companion?
- **Zeno's Paradox**: A hallway that seems to get longer the more you walk. Solution: stop walking and teleport.

#### Philosophy as Dungeon Biomes
A dedicated "Philosopher's Dungeon" with themed floors:
- Floor 1: **The Cave** (Plato) — darkness, shadows, illusions
- Floor 2: **The Garden** (Epicurus) — seemingly peaceful, hidden dangers of excess
- Floor 3: **The Agora** (Socrates) — NPC debates, puzzle rooms, no combat
- Floor 4: **The Void** (Nietzsche) — stripped UI, escalating difficulty, "what doesn't kill you"
- Floor 5: **The Mountain** (Camus) — Sisyphean boss fight, boulder mechanics
- Boss: **The Mirror** — fights using your own attack patterns

### Quest Chain Ideas

#### "The Examined Life" (Multi-zone epic quest)
A philosopher NPC sends you to experience each school of thought through gameplay:
1. Live as a Stoic (complete a dungeon without using potions)
2. Live as an Epicurean (collect all pleasure items in a zone without dying)
3. Live as an Existentialist (complete a dungeon with no quest markers or minimap)
4. Return and choose which philosophy to follow — permanent passive ability based on choice

#### "Unity of Being" (Ibn Arabi questline)
Wahid sends you to fight the same enemy type in 5 different biomes. Each biome's version looks completely different. Final turn-in: "They were all the same creature. You are all the same soul."

#### "The Incoherence" (Al-Ghazali vs Ibn Rushd)
Two NPCs give you contradictory quests for the same dungeon. Completing one fails the other. Or find a third path that reconciles both.

---

## Implementation Priority
1. More Aria quests for existing 7 NPCs (deepen their storylines)
2. Philosopher's Dungeon biome (dedicated themed dungeon)
3. Philosophy status effects / buffs
4. NPCs in other towns (spread philosophers across the world)
5. The Examined Life epic questline
