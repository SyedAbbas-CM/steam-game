# Master Progression

> Six level bands, one act per band.
> Siblings: `01_story.md`, `02_world_map.md`, `03_quests.md`.

## Bands

| Band | Levels | Tagline | Primary zones | Time |
|------|--------|------|----------------|------|
| B0 | 1–3   | Ash on your boots | Ravenhollow, Barrows | ~45min |
| B1 | 4–8   | The Wardens know | Wastes, Hollow Fields | ~90min |
| B2 | 9–15  | Following the cracks | Embermaw, Barrows-Crypt | ~90min |
| B3 | 16–25 | Older wounds | Ironspine, Ashheim, Frostgrave | ~3h |
| B4 | 26–45 | The gates open | Ashglade, Moloch, Gehinnom | ~4h |
| B5 | 46–100 | Closing the wound | Hellgate + endgame loop | open-ended |

## Band flow

```mermaid
flowchart LR
  B0[B0: Ravenhollow + Barrows] --> B1[B1: Wastes + Hollow Fields]
  B1 --> B2[B2: Embermaw + Crypts]
  B2 --> B3[B3: Ironspine + Frostgrave + Ashheim]
  B3 --> B4[B4: Ashglade + Moloch + Gehinnom]
  B4 --> B5[B5: Hellgate]
```

## Per-band budget

- Enemy HP doubles each band.
- Critical-path XP gives ~one level per band.
- Rare drop rate: 2% → 6% → 12% → 20% → 30% → 40% across B0–B5.

## Open questions

1. Final-quest level: L175, L90, or move endgame to prestige? Default: L90 + prestige.
2. B3 zones (Ironspine, Ashheim, Frostgrave): open or gated? Default: open, sign-warn the harder ones.
