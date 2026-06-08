# Remaining Quest Roadmap

> The 32 quests not yet detailed. One-line summary + the band + the next pass goal.
> When a quest moves into its own file, delete its line here.

## Main spine (mq08 – end)

> **mq05, mq06, mq07 now have their own docs** — see `00_index.md`.

| ID | Title (from .tres) | Band | Zone | Notes for the doc pass |
|----|--------------------|------|------|------------------------|
| mq08 | The Witch of Nord | B2/B3 | frostpass | Choice quest: spare or strike the corrupted priestess. North fork's payoff. |
| mq09 | A Ship That Shouldn't Sail | B2/B3 | ashheim → cliffs | South fork from `mq06`. Ghost ship at Gomb harbor. |
| mq10 | The Merchant's Deal | B3 | cliffs → saltmere | Pirate guild. Tide artifacts. **Join or fight** choice. Briard introduced. |
| mq11 | TBD (Cenneth opening) | B4 | cenneth | Cult stronghold. Key Fragment 2/3 should appear here. |
| mq12 | TBD (Cenneth — sept) | B4 | cenneth | |
| mq13 | TBD (Cenneth — relic) | B4 | cenneth | |
| mq14 | TBD (Cenneth standalone) | B4 | cenneth | No prereq in `.tres` — orphan, may be a standalone arc. |
| mq15 | TBD (Frostgrave entry) | B4 | frostgrave | The slab is here — names whoever opened the Sundering. |
| mq16 | TBD (Thule descent) | B4 | thule | |
| mq17 | TBD (Thule cleared) | B4 | thule | |
| mq18 | TBD (Hellgate gate-keeper) | B5 | hellgate | Moloch boss; first major demonic. |
| mq19 | TBD (Hellgate inner) | B5 | hellgate | Speaker confrontation. Key Fragment 3/3. Woman in White heard again. |
| mq20 | TBD (Return to Haven) | B5 | haven | Final domestic beat. Elder confrontation. |
| end | Vanquish Evil | B5 | haven | Currently L175 — drop to L90 per `00_master_progression.md`. Final choice. |

## Ashfields side arc (a*)

| ID | Title | Band | Zone | Notes |
|----|-------|------|------|-------|
| a0 | TBD | ? | ? | unused or stub |
| a1 | TBD | ? | ? | |
| a2 | TBD | ? | ? | |
| a3 | Snakes Alive | B3/B4 | ashvale | listed in older docs as Lv 34 |
| a8 | TBD | ? | ? | |
| a15 | TBD | ? | ? | |

→ Read each `a*.tres` first. They may be old / unused. Mark for keep / merge / cut.

## Pet quests (p*, pq_*)

| ID | Title | Band | Notes |
|----|-------|------|-------|
| p1 | Pet starter | B0 | gives you a chicken |
| pq_cave | Pet — cave | ? | |
| pq_doubt | Pet — doubt | ? | |
| pq_journeys | Pet — journeys | ? | |
| pq_mean | Pet — mean | ? | |

→ Each ties into Mabion's pet system. Document with the pet they unlock.

## Zone discovery (z*)

| ID | Title | Notes |
|----|-------|-------|
| z1 | TBD | likely a zone-enter codex unlock disguised as a quest |
| z5 | TBD | |
| z8 | TBD | |

→ These may be auto-trigger zone-discovery quests, not narrative ones. Document as such.

## Misc

| ID | Title | Notes |
|----|-------|-------|
| q6 | TBD | orphan — check if started anywhere |

## Pass order (recommended)

1. **mq05–mq07** — B2 backbone, the player just hit the Wardens stride.
2. **mq08–mq10** — B3 Outlands, the Briard split is here.
3. **mq11–mq14** — Cenneth cluster + the cult stronghold reveal.
4. **mq15–mq17** — Frostgrave/Thule descent.
5. **mq18–mq20 + end** — endgame.
6. **a* / pq_* / z* / q6** — audit pass; many may be cuttable.

Each batch can fit in a single chat turn with the same per-quest depth as `q1`.

## Authoring shortcuts

- Use [01_template.md](01_template.md) as the boilerplate.
- Cross-reference NPCs against [02_world_map.md](../02_world_map.md) so we don't invent NPCs in zones that have rosters.
- When a quest needs a new NPC, propose them in the doc, then add to the relevant zone's `.tres`.
