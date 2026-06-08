# Quest mq10 — The Merchant's Deal

## Quick facts

| Field | Value |
|-------|-------|
| ID | `mq10` |
| Title | The Merchant's Deal |
| Band | B3 |
| Recommended level | 14 |
| Quest giver | trigger on arrival at the cliffs (auto from `mq09`) |
| Turn-in | **Captain Briard** at the pirate guild hall |
| Action location | Cliffs → Saltmere (pirate city) |
| Prerequisite | `mq09` |
| Critical path? | yes — second major **player choice** (Join or fight Briard) |

## Summary
The ship's manifest leads to **Saltmere**, a pirate city built on the cliffs. The guild master is **Captain Briard** — yes, the Warden Captain Coran mentioned. He's been spreading Tide artifacts to gain power. He greets you by name. **Join him, or fight him.**

## Lore context
Briard is the player's first proper antagonist who's *one of the good guys*. He runs Saltmere openly. The Wardens of Heim know. Coran knows. Iola knows. Nobody has the political authority to stop him because the Wardens *need* his network to track the cult.

Briard's pitch is honest:
- He's collecting Tide artifacts (black candles, Wound Guardian fragments, salt-sealed relics) because he believes the *centralised* corruption is less dangerous than the distributed kind. *"Better one rotten ship than a hundred."*
- He's not aligned with the cult. He's competing with them for the same artifacts.
- He says Coran is a coward and Iola is a quitter, and his face when he says it suggests he believes it.

Briard is *partly right*. The artifacts in his hands aren't being weaponised by the Tide. But every player who joins him bends the world ever so slightly toward concentration of power — and at `mq19`, that becomes the difference between the Speaker having a recognisable face (Briard's) or a faceless voice.

## NPCs involved
- **Captain Briard** — Warden Captain turned pirate king. Charisma-heavy NPC. Speaks in clean, short sentences. Wears the Warden cloak with the insignia removed.
- **Briard's lieutenants** — three of them, named: **Vex** (former Warden), **Salt-Tongue Mira** (sea cultist deserter), **Old Gehn** (engineer, makes the salt seals).
- **The Captain** (if you jumped in `mq09`) — appears at the guild's bottom dock, recognises you. Briard introduces him as *"my consultant."*
- **Coran (via courier)** — sends a sealed note partway through: *"Whatever he offers, hear it. Then decide."* Surprisingly hands-off.

## Steps

1. **Arrive in Saltmere** — banner. Atmosphere set piece. The city smells of salt and cordite.
2. **Walk the docks** — three small encounters: a vendor selling salt-sealed crates, a brawler who challenges you, a beggar who recognises Iola's pendant if you wear it.
3. **Guild hall entry** — Briard waiting. Long dialogue (the most NPC text in the game so far). Player can ask any of seven things in any order.
4. **The pitch** — Briard makes his offer:
   - Join: he gives you Key Fragment 2/3 directly, asks you to bring him the third. In return he'll back Ravenhollow when the Tide reaches it.
   - Fight: he doesn't want to. Says *"Coran's brand is on you — go back to him. Don't come back."*
5. **JOIN branch**:
   - Receive Key Fragment 2/3.
   - The Captain (if jumped) is now a hostile boss because you sided with Briard against his crew.
   - You return to the Warden of Heim, who freezes when you tell him.
6. **FIGHT branch**:
   - Boss fight against Briard, two phases. He doesn't go all-out; phase 2 he yields rather than die. *"You're more like Coran than I thought. Take the key."*
   - You take Key Fragment 2/3 from him.
   - Briard limps off. Reappears in `mq11`/`mq12` as a worse problem.
7. **Either way: Key Fragment 2/3 acquired.** Quest resolves.

## Rewards
- XP: 7000
- Gold: 6000
- Items: **Key Fragment 2/3** (guaranteed), **Briard's Lieutenant Cloak** (FIGHT path) or **Salt-Tongue's Counter** (JOIN path — bigger MP pool)
- Unlocks: `mq11`

## Optional / hidden objectives
- **Brawler on the docks** — beat them in a non-lethal duel. They join you for the boss fight on FIGHT path (deals 30% extra damage to Briard).
- **Beggar with Iola's pendant** — if you're wearing the pendant from `mq07`, the beggar reveals they're a Warden deep-cover agent. Sends a coded ping to Iola; Iola later tells you *"I knew."*
- **Old Gehn's workshop** — if you spared the witch in `mq08`, Gehn says *"She passed through. Said you'd come."* (Witch foreshadow payoff.)
- **Refuse both options** — leave Saltmere without a key. Briard sends the key in the mail two days later with no note. The game continues. Codex entry *"He let you walk."*

## Branches & reactions
- After completion (JOIN):
  - Coran: long silence on next meeting. *"You knew what you were doing. I hope."*
  - Iola: cold. Won't sell. Will still talk.
  - Warden of Heim: visibly worried. Codex entry.
  - Briard: opens his network to you. Repeatable patrol quests in B3.
  - Speaker (B5): wears Briard's voice in `mq19`.
- After completion (FIGHT):
  - Coran: respect. *"Cleaner. I should've done it myself years ago."*
  - Iola: relieved.
  - Briard: gone from Saltmere. Reappears as a wounded antagonist in `mq11`/`mq12` allied with the cult out of spite.
  - Speaker (B5): faceless voice.
- After completion (REFUSE):
  - Briard: silent. Saltmere unchanged.
  - The game's later events are unaffected by the network, neutral.

## Tied to story arc
- Act: 4 — *Older wounds*
- Major theme: the player has to pick a faction split that the world has been carrying for a generation. Neither faction is wrong. Both have consequences.
- Foreshadows: `mq11`/`mq12` (Cenneth cult either treats you as a Briard ally or a Coran loyalist), `mq19` (the Speaker's face depends on which Warden's voice you fed it).

## Implementation notes

### Existing in `mq10.tres`
- summary: "Follow the crates to the pirate city. The guild master spreads Tide artifacts for power. Join or fight."
- prereq=mq09, target_location=saltmere.

### To add (deepening)
- Saltmere zone as a small overworld with three named NPC encounters.
- Briard NPC + 7-question dialogue.
- Two-phase fight with phase 2 yield.
- Three save flags: `flag_briard_join`, `flag_briard_fight`, `flag_briard_refuse`.
- The Captain reappearance gated by `flag_captain_jumped` from `mq09`.
- Witch foreshadow gated by `flag_witch_spare` from `mq08`.
- Briard's mailed-key fallback for REFUSE path.

### Codex entries unlocked
- `saltmere_intro` — first arrival.
- `captain_briard` — first meeting.
- `briards_pitch` — after the long dialogue.
- `key_fragment_2` — on receipt.
- `briard_join`, `briard_fight`, or `briard_refused` — branch resolution.
- `gehn_says_she_came` — witch-spare callback.
- `the_beggar_is_a_warden` — pendant callback.
