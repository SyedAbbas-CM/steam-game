# Quest Index

> One `.md` per quest. Each file documents location, NPCs, story, lore, steps,
> rewards, hidden objectives, and what to add for the "deepening" pass.
>
> **Setting: Ashenfold.** Grimdark gothic-militarist reskin of the original
> story. Same structure, same beats, same NPCs at the same locations — new
> tone and names. See [A0_setting_ashenfold.md](A0_setting_ashenfold.md) for
> the canon glossary (Wardens → Iron Synod, the Tide → the Whisper, Hellgate
> → the Breach, etc.).
>
> Editing rules: change the `.md` first, then the corresponding `.tres` under
> `resources/quests/`. The `.tres` is the source of truth at runtime; the `.md`
> is the source of truth for design intent.

## All 42 quests

### Band B0 — Ravenhollow / Barrows opening (Lv 1–3)
- [q1](q1_them_bones.md) — **Them Bones** — Elder, kill 20 Skeletons in the Barrows
- [mq01](mq01_waking_in_ash.md) — **Waking in Ash** — Elder → Dafydd, cleanse 10 corrupted Scarecrows
- [mq02](mq02_what_the_dead_left_behind.md) — **What the Dead Left Behind** — Bone Golem, recover the tablet
- [q14](q14_jimbobs_lost_pickaxe.md) — **Jimbob's Lost Pickaxe** — kill 10 dungeon enemies

### Band B1 — Wastes + Hollow Fields (Lv 3–8)
- [mq03](mq03_the_elders_silence.md) — **The Elder's Silence** — find the scholar's journal in the Wastes
- [mq04](mq04_blood_in_the_grass.md) — **Blood in the Grass** — destroyed caravan, black-robed cult
- [sq1](sq1_potion_hoarder.md) — **Potion Hoarder** — 5 Red Potions for Jimbob
- [sq2](sq2_arnies_challenge.md) — **Arnie's Challenge** — kill 8 Ghouls for Arnie's respect
- [sq3](sq3_ghost_stories.md) — **Ghost Stories** — kill 15 Ghosts for Corvus's patrons

### Band B2 — Embermaw + Crypts + Heim (Lv 7–15)
- [q_fire_beast](q_fire_beast.md) — **The Fire Beast** — Dafydd's quest, Embermaw
- [mq05](mq05_the_hollow_shepherd.md) — **The Hollow Shepherd** — silent village, Mirage dungeon
- [mq06](mq06_the_wardens_warning.md) — **The Warden's Warning** — Ashheim, Key Fragment 1/3, forks the path
- [mq07](mq07_frozen_witnesses.md) — **Frozen Witnesses** — Frostpass, woman in white

### Band B3 — Outlands (Lv 16–25)
- mq08 — Frostpass
- mq09 — Ashheim revisit
- mq10 — Cliffs
- mq11, mq12, mq13, mq14 — Cenneth cluster

### Band B4 — Approaches (Lv 26–45)
- mq15 — Frostgrave
- mq16, mq17 — Thule
- a3 — Snakes Alive (Ashvale)

### Band B5 — Endgame (Lv 46–100)
- mq18, mq19 — Hellgate descent
- mq20 — return to Haven, final beat
- end — Vanquish Evil

### Pet & extras
- pq_cave, pq_doubt, pq_journeys, pq_mean — pet quests
- p1 — pet starter
- a0, a1, a2, a3, a8, a15 — Ashfields side-arc
- z1, z5, z8 — zone discovery
- q6 — TBD

## What this docs pass adds

For each quest:
1. **Steps** — break the existing single-objective into 2–3 beats (talk → act → return).
2. **Lore drop** — at least one optional readable item (journal page, slab, broken note).
3. **NPC reactions** — what other NPCs say once this quest is done.
4. **Foreshadowing** — what later quests this hints at.

Sample template at [01_template.md](01_template.md).

## Status

- ✅ Detailed: q1, mq01, mq02, mq03, mq04, mq05, mq06, mq07, mq08, mq09, mq10, q14, sq1, sq2, sq3, q_fire_beast (16)
- 🟡 Roadmap stubs: mq11–mq20, end (11)
- 🔲 TBD: a*, p1, pq_*, z*, q6 (15)

When a quest moves from stub → detailed, tick it in this index.

## Key story terms (Ashenfold canon, use these in dialogue)

| Term | What it is | First used in |
|------|------------|---------------|
| **The First Cracking** | the ancient catastrophe that opened the Breach | codex, `mq05` |
| **The Whisper** | the ongoing corruption leak from the Breach. NPCs hesitate before saying the word. | `mq05`/`mq06` |
| **The Hollow Speaker** | mid-rank herald of the Whisper | `mq05` |
| **The Pale Voice** | the voice. Antagonist. Not a person. (Sometimes "the Silent Saint.") | `mq06`/`mq07` |
| **The Three Reliquary Shards** | 1/3 with the Lord-Synodist of Forge-City Ashen → Penitent, 2/3 with the Choir, 3/3 at the Breach floor | `mq06` |
| **The Choir of Wounds** | followers of the Pale Voice. Black stoles. | `mq04` |
| **The Iron Synod** | the militant theocracy holding the Whisper back. Coran, Briard, Lord-Synodist Vehl, Scholiast Iola (exiled). | `mq03`/`mq04` |
| **Bound Sentinels** | old sealed sentinels at lesser wounds. Tombyard Sentinel, Cinder Wyrm. All speak. | `mq02`/`q_fire_beast` |
| **The Stigma** | the conscription glyph burned into the Penitent's arm. They don't remember earning it. | `mq01` |
| **The Penitent** | what the Synod calls the player. Never their name. | universal |
