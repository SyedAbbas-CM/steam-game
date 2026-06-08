# Quest mq09 — A Ship That Shouldn't Sail

## Quick facts

| Field | Value |
|-------|-------|
| ID | `mq09` |
| Title | A Ship That Shouldn't Sail |
| Band | B2 / B3 boundary |
| Recommended level | 12 |
| Quest giver | **Warden of Heim** (when player takes the south fork at `mq06`) |
| Turn-in | trigger when the ghost ship is boarded |
| Action location | Ashheim docks → Gomb harbor → hidden cove |
| Prerequisite | `mq06` |
| Critical path? | yes — south fork parallel to `mq07`/`mq08` |

## Summary
A ship that should be at the bottom of the harbour sails out of Gomb at every tide turn, carrying crates of something nobody on the docks will name. The harbour master denies it exists. A fisherman points to a hidden cove. Find the ship, board it, learn what's being smuggled — and to whom.

## Lore context
The **Cult of the Open Wound** uses an old shipwreck as a smuggling vessel — it sinks during the day and surfaces at sundown. The cargo is **black candles** (the same Warden sacrament from `mq05` / `mq08`), sealed in salt to keep them dormant. The destination is the cliffs (→ `mq10`, the pirate guild). The captain isn't a person — it's a Wound Guardian like the Bone Golem or Fire Beast, **reused** by the cult as a vessel pilot. This is the first sign that the cult is *recycling* the Wardens' own old guardians.

The ship's hold has a manifest. The manifest names **Captain Briard** as the buyer. (Briard is a Warden Captain.) This is the player's first concrete proof that the Wardens have an internal split. Briard's defence comes in `mq10` — he says the candles in cult hands are worse than the candles in his hands, and he's trying to acquire them all to destroy them. Either he's lying or he isn't. The game doesn't tell you.

## NPCs involved
- **Warden of Heim** — sends you. Mentions the rumour, points to Gomb.
- **Harbour master Gomb** — short, defensive, lies. *"There is no such ship."* Will not look at you.
- **Old fisherman** (NEW NPC, one-time) — at the southern dockside, mending nets. Points to the cove for 5 gold. Will give the location for free if the player asks softly.
- **Ghost-ship crew** — silent. Faces wrapped in salt cloth. Combat-passive unless the player attacks the captain.
- **The Captain** — a recycled Wound Guardian. Older than the Bone Golem. Says one line when revealed: *"You're the one Coran sent. I knew Coran when he was nothing."*

## Steps

1. **Travel from Ashheim to Gomb harbour** — short land journey. New zone entry banner.
2. **Talk to the harbour master** — he denies the ship. Three options:
   - Bribe him (50g) — he denies it but lets slip the tide schedule.
   - Threaten him — he denies it and calls guards. You can de-escalate; he tells you nothing more.
   - Walk away and ask the fisherman.
3. **Fisherman** — gives you the cove location either free or for 5g.
4. **Cove at low tide** — the ship doesn't exist. You see the broken keel.
5. **Cove at sundown** — the ship surfaces. You can board the deck.
6. **Deck infiltration** — six wrapped-faced crew. They don't attack. They watch.
7. **Below deck — the manifest** — find the ledger. Read it. Briard's name is on it.
8. **The Captain reveals himself** — when you take the ledger. Speaks one line, then the ship begins to dive.
9. **Choice**: stay on the ship and fight the Captain (boss) OR jump overboard with the manifest.
   - **Fight** path — boss fight, ship continues toward the cliffs while you fight. After the kill you wash up on the cliffs (auto-teleport, unlocks `mq10`). Captain drops **Captain's Salt-Seal** (key item).
   - **Jump** path — you keep the manifest, lose the chance to confront the Captain here (he reappears in `mq10`). Quest resolves the same; less unique loot.

## Rewards
- XP: 5000
- Gold: 4000
- Items: **Ledger of Black Salt** (key item — names Briard), **Captain's Salt-Seal** (only on Fight path)
- Unlocks: `mq10`

## Optional / hidden objectives
- **Be nice to the fisherman** (refuse to pay) — he reappears in `mq20` as a refugee in Ravenhollow. Codex entry.
- **Don't read the manifest immediately** — bring it sealed to the Warden of Heim. He reads it, hands you a sealed second copy. Briard never finds out the Warden of Heim knows. Quiet long-game leverage.
- **Open the salt-sealed crates** in the hold (interact). One contains a Warden insignia with Coran's name etched. Codex hook.

## Branches & reactions
- After completion:
  - Warden of Heim: depends on how you delivered the manifest (sealed vs. opened).
  - Coran: defends Briard reflexively until you show him the insignia (if found). Then silent.
  - Iola: warns *"Briard knows your face now."*
  - Captain (if jumped): reappears in `mq10` as a second boss layer.

## Tied to story arc
- Act: 3 — *Following the cracks*
- Major theme: the enemy has been recycling the Wardens' own tools. And one of the Wardens may be helping them — accidentally or not.
- Foreshadows: `mq10` (Briard in person, the join/fight choice), `mq18` (Captain's recycling pattern repeats at Hellgate), `mq19` (the Speaker uses Coran's voice, mirror of the Captain using Coran's history).

## Implementation notes

### Existing in `mq09.tres`
- summary: "A ghost ship at Gomb harbor. The harbor master denies it. A fisherman points to a hidden cove."
- prereq=mq06, target_location=cliffs.

### To add (deepening)
- Day/night cycle gate for the ship surfacing.
- Harbour master + fisherman dialogue trees.
- Ship as a small scripted set piece (deck → hold).
- Ledger as a key item with sealed/unsealed state.
- Captain boss with Fight/Jump branch.
- Auto-teleport to cliffs on Fight resolution; manual travel on Jump.
- Hidden Coran-insignia interact in the hold.

### Codex entries unlocked
- `gomb_harbor` — first entry.
- `the_silent_crew` — first deck step.
- `ledger_of_black_salt` — manifest pickup.
- `the_captain_recycled` — Captain reveal.
- `coran_insignia` — hidden crate.
- `harbor_master_lies` — for free if you threaten or bribe.
