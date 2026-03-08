# Dynasty of Yore — Game Design Document

## Core Concept

A roguelite kingdom-builder where mortal heroes explore a handcrafted world, conquer settlements, and build a dynasty that persists across generations. Every hero dies — but the kingdom endures.

---

## The World (Using LoY Geography)

The world is divided into **5 regions**, each controlled by a faction. The player starts in Aria with nothing and must grow from wanderer to lord to emperor across multiple hero lives.

### Region Map

```
                    NORD1 (Nordolk)
                      |
           HEIM ---- COLD1 ---- MNT1 ---- CYCL
            |                     |
           CRT1               WILD1 (Central Hub)
                              / | \
                         FOR1  CAMP  VLY1
                        / | \        |
                    GOMB FOR2 FOR3  STHEL --- SHRINE
                          |    |
                         BRG1 FOR4
                          |    |
                         BLF1 CEL1
                          |
                         UND1
                        /    \
                     BCH1   (underground)
                      |
                    TOR3 --- TOR1 --- TOR5
                              |
                    TOR6 --- TOR2 (Pirate Capital)
                              |
                    TOR4 --- TUNDRA --- JUNGLE1 --- PAITITI
                                         |
                              VALE --- JUNGLE2
                             / |
                      FROZEN  CENNYN --- PLAINS
                        |                /  |  \
                      THULE           SWAMP PEAKS NALEG
                        |               |     |
                      END1          TALMITA  KOR
```

### The Five Factions

**1. The Free Towns (Human)** — Starting Allied
- **Aria** (25x25) — Your starting town. Weapon shop, magic shop, inn. 8 NPCs.
- **Farm / Caws Mawr** (25x25) — Pastoral farmland east of Aria. Livestock, crops.
- **Camp** (20x20) — Military training ground. Ryu the trainer lives here.
- Personality: Peaceful, defensive. Will trade and offer quests but won't expand on their own.

**2. The Ironhide Warband (Orc/Bandit)** — Aggressive
- **Kor** (30x20) — Mountain fortress. 3 shops, elder Bal Die.
- **Peaks** (40x40) — Wild Boar and Enderman territory. Tileset: mountain.
- **Cycl** (30x30) — Cyclops Valley. Rock Trolls. The warband's monster pens.
- **Mnt1** (50x50) — Mountain passes. Bears, Bandits patrol.
- **Cold1** (60x24) — Frozen mountain pass. Polar Bears.
- Personality: Raids player towns every few hero-cycles. Must be conquered militarily.

**3. The Pirate Lords (Human/Demon)** — Expansionist
- **Tor2 / Toronega** (47x21) — Pirate capital. 10 NPCs, 5 shops, pet breeders. Richest city.
- **Tor1** (47x21) — Port district. 3 NPCs.
- **Tor3** (47x21) — South gate. Cycarrior patrols.
- **Tor4** (47x21) — Badlands gate. 4 NPCs, elder. Links to tundra.
- **Tor5** (47x8) — Hidden cove. Secret smuggling den.
- **Tor6** (47x15) — West port. Pugwash the sailor.
- Personality: Controls sea trade. Will blockade your ports. Demands tribute. Can be allied through quests OR conquered.

**4. The Arcane Circle (Magical/Undead)** — Mysterious
- **Cennyn** (50x50) — Ancient capital. Largest city. 15 NPCs, 5 shops, crafters. Lord Cennyn rules.
- **Vale** (50x35) — Green vale. Wolf Riders roam.
- **Frozen** (30x30) — Frost Skull territory. Frozen wastes.
- **Thule** (30x25) — Cursed ruins. 6 NPCs, 3 shops, crafters. Was once a great city.
- **End1** (15x15) — Gates of Hell. The final dungeon entrance.
- Personality: Ancient, powerful, reclusive. Will only interact through quest chains. Controls the endgame zones.

**5. The Wild Tribes (Animal/Crawler/Mixed)** — Territorial
- **Sthel** (25x25) — Desert oasis. 7 NPCs, 5 shops. K'atel the priestess.
- **Gomb** (52x20) — Coastal trading hub. 8 NPCs, 4 shops. Zeng the diplomat.
- **Heim/Dondheim** (20x20) — Northern fortress. 9 NPCs, 3 shops. Odin the warlord.
- **Nord1/Nordolk** (45x25) — Northern settlement. 4 NPCs, Eski the elder.
- Personality: Neutral but defensive. Each town acts independently. Can be allied or conquered one by one.

### Unclaimed Wilderness (Contestable Territory)

These zones start unowned and can be claimed by the player OR factions:

| Zone | Size | Danger | Resources | Notes |
|------|------|--------|-----------|-------|
| Wild1 | 50x50 | Medium | Central crossroads | Controls access to everything |
| For1 (Hallows) | 50x30 | Medium | Timber | Gateway to eastern forest chain |
| Vly1 (Valley) | 60x24 | Medium | Hunting | Scorpions, Dingos |
| Plains (Milain) | 50x25 | Medium | Farming | Central southern grassland |
| Swamp | 50x40 | High | Rare herbs | Zomboid territory |
| Jungle1 | 30x30 | High | Exotic goods | Lion territory |
| Jungle2 (Outback) | 30x30 | Very High | Ancient relics | Cannibal territory |
| Moors | 30x25 | High | Stone quarry | Ninja territory |
| Tundra | 30x30 | High | Furs, ice crystals | Rhino territory |
| Thicket | 25x25 | Medium | Wood, mushrooms | Squib/Night Goblin |

### Isolated Zones (Special)

- **Pst1 / Holy Pasture** (30x30) — Portal-only. Kayla the priestess. Sacred ground — cannot be conquered, provides blessings.
- **Island** (25x35) — Accessible by ship (need Tor port). Ifrit territory. Legendary loot.
- **Shrine** (17x17) — Ancient shrine near Sthel. Quest-only access to deep dungeon.

---

## The Hero Lifecycle

### Phase 1: The Wanderer (Heroes 1-3)

Your first few heroes are fragile. They explore near Aria, clear the graveyard, run the Aria Dungeons (7 floors), and die. Each death deposits gold and discovered map data into the dynasty treasury.

**Aria Starting Quests (Already Exist):**

1. **"Them Bones" (q1)** — Kill 20 Skeletons in the Graveyard. Your first combat quest. Teaches dungeon-diving basics. Reward: 500 gold for the treasury.

2. **"Deliver the Goods" (q2)** — Walk a package from the Elder to Yoregot at the Crooked Beak Inn. Teaches NPC interaction and town navigation. Reward: 500 gold.

3. **"Pelting Them" (q3)** — Collect 10 Dog Pelts from Valley (vly1). First time leaving Aria's safe zone. Teaches overworld danger. Reward: Pelt Cloak (first real armor).

4. **"The Evil Beneath" (a4, Lvl 8)** — Kill the Fire Beast in Farm's dungeon. First boss encounter. If you die, you know what to prepare for next hero. Reward: Head Dress + 500 gold.

**NEW Quest — "The Abandoned Homestead":**
After completing q1 and q2, the Elder tells you about Caws Mawr (Farm). The farmer Dafydd's land is overrun. Clear the farm zone of hostile spawns → **claim Farm as your first settlement.** This is the tutorial for town ownership.

**NEW Quest — "Walls of Aria":**
Once you own Farm, the Elder asks you to build a palisade around Aria using timber from Farm. Costs 500 gold from treasury. Once built, Aria gains a garrison slot (can station 5 militia). This teaches base-building.

### Phase 2: The Lord (Heroes 4-10)

You own Aria + Farm. You have a small income. Now you need to expand.

**The Treaty Arc (q6 — Already Exists, Reimagined):**

The original q6 has Zeng (Gomb) asking you to get a treaty signed by three elders: Aria, S'thel, and Dondheim. In the new version, this becomes a **diplomatic expansion** quest chain:

1. **"The Treaty" (q6, Lvl 28)** — Zeng proposes a Free Towns Alliance. Travel to Aria Elder (auto-sign, he's your ally), then to K'atel in S'thel, then to Odin in Dondheim.

2. **Problem:** K'atel won't sign unless you deal with the Beholder terrorizing her people. Complete **"Behold!" (a0, Lvl 15)** — kill the Beholder, bring back 5 tentacles. Now S'thel signs.

3. **Problem:** Odin won't sign unless you prove your strength. Complete **"Fish Pie" (q11)** to show you can provide for his people (10 fish from Gomb area), then **"It Stings!" (q5)** to show combat prowess (12 stingers). Now Dondheim signs.

4. **Treaty Complete:** The three towns join your alliance. You don't own them outright, but they provide trade income, share shops, and won't resist if you later "absorb" them peacefully (by completing their full quest chains).

**The Ironhide Threat:**

While you're building alliances, the Ironhide Warband starts raiding.

- **Turn 10:** Bandits appear on roads near Aria. Random overworld encounters increase.
- **Turn 20:** Kor sends raiders to attack Farm. If ungarrisoned, Farm is damaged (income halved until repaired).
- **Turn 30:** Full assault on a player-owned town. Must defend or lose it.

**NEW Quest — "Scout the Mountains":**
After the first raid, the Elder asks you to scout Mnt1. Travel through wild1 → mnt1, discover the Ironhide camp. Report back. Unlocks the ability to recruit better troops (Spearmen) from Aria.

**NEW Quest — "The Mountain Pass":**
Clear cold1 of Polar Bears and Bandits. Establish a watch tower (costs 1000 gold + 10 troops). This prevents Ironhide raids from the north, protecting Nordolk if you've allied with them.

**The Push to Kor:**

Eventually you're strong enough to assault Kor itself:

1. **"End the Endermen" (z8, Lvl 140)** — Already exists. Kill 5 Endermen in the Peaks. Weakens Kor's outer defenses.
2. **"Deadly Disease" (z9, Lvl 145)** — Already exists. Kill the Plaguemaster. Removes the plague debuff that weakens your troops near Kor.
3. **Siege of Kor** — Bring an army of 30+ troops. Auto-battle against Kor's garrison. Win → Kor is yours. Bal Die the elder becomes your vassal or is exiled.

### Phase 3: The Conqueror (Heroes 10-20)

You control the northern region. Now the world opens up.

**Southern Expansion — The Plains War:**

Milain Plains (plains) sits at a crossroads connecting Cennyn, Swamp, Peaks, and Naleg. Whoever controls the Plains controls southern trade.

- **Naleg (z5-z7):** Par Tak's port town. The quest chain (Parrot delivery, boat collection, snake slaughter) builds trust. Complete all three → Naleg joins peacefully.
- **Talmita (z10-z12):** Chief Komba's tribal village in the swamp. Fierce warriors. The "Lost Crown" quest (z10) asks you to recover their king's crown from a Skaven Lord. Return it → they become loyal vassals with unique swamp troops (Zomboid Riders — strong but slow).
- **Cennyn:** Lord Cennyn's ancient capital. The most powerful neutral city. 15 NPCs, 5 shops. Cannot be conquered by force — too strong. Must complete the full z1-z4 quest chain ("Dark Side of Magic" → "Squash Squeerg") to earn Lord Cennyn's respect and form an alliance.

**The Pirate Problem:**

Toronega controls the sea. Without a port, you can't reach the Island (legendary loot) or trade overseas.

- **Option A — Conquer:** Fight through Tor3 (Cycarrior guards), then siege Tor2. Very expensive in troops. Pirates fight dirty — they'll raid your coastal towns during the siege.
- **Option B — Diplomacy:** Complete the Tor4 quest chain (a5 "Nasty Sting", a12 "Making a Stand", a17 "Jar of Wisps", a19 "Light the Way"). The King at Tor4 respects strength and generosity. Complete all four → Toronega becomes a trade partner. You get port access but don't own the city. Later, you can absorb them through a marriage alliance quest.

**NEW Quest — "The Pirate King's Daughter":**
After completing the Tor4 quests, the King offers his daughter's hand in marriage to your current hero. If your hero dies before the wedding (3 dungeon runs must be survived), the deal is off and you start over with the next hero. Succeed → Toronega joins your dynasty permanently. This creates real stakes around keeping your hero alive.

### Phase 4: The Dynasty (Heroes 20+)

**The Frozen South:**

The endgame zones — Vale, Frozen, Thule, End1 — are controlled by the Arcane Circle. They don't raid or trade. They just... exist, ancient and patient.

- **Thule** is a ruined city with 6 NPCs and 3 shops. It was once the greatest city in the world. The quest chain (a7 "The Labyrinth", a14 "Cull the Magic", a21 "Portrait of Purity") reveals that Lord Cennyn was once Thule's king before a magical catastrophe.
- **End1 / Gates of Hell** — The final zone. "Evil below, no portals function here!" The dungeon beneath (End-Base, 10 levels) contains Smorag and Deathbringer.

**"Vanquish Evil" (end, Lvl 175):**
The existing endgame quest. Kill Smorag and Deathbringer in the depths beneath End1. But in our version, this isn't just a hero quest — it's a **dynasty achievement**. You need:
- Control of a path from Aria to End1 (every zone along the route must be owned or allied)
- A supply line of garrisons to prevent the Arcane Circle from cutting you off
- A hero strong enough to survive the 10-level dungeon
- An army strong enough to hold Thule while your hero is underground

If your hero dies in End1, the dynasty doesn't lose Thule — but you need to rebuild, recruit, and send another hero in. The dungeon resets. This is the ultimate roguelite moment: each attempt costs resources, but the kingdom supports each new attempt.

---

## Town Ownership System

### Capture Methods

| Method | Cost | Time | Result |
|--------|------|------|--------|
| **Military Conquest** | Army + troops lost | Immediate | Full control, hostile NPCs |
| **Quest Alliance** | Complete quest chain | 3-8 quests | Trade partner, friendly NPCs |
| **Peaceful Absorption** | Alliance + gold tribute | After alliance | Full control, loyal NPCs |
| **Marriage** | Quest chain + hero survival | Special | Permanent dynasty merger |

### Town Buildings (Upgrade Slots)

Each owned town has 3-5 building slots based on size:

| Building | Cost | Effect |
|----------|------|--------|
| **Palisade** | 500g, 10 timber | +5 garrison cap |
| **Stone Wall** | 2000g, 30 stone | +15 garrison cap, raid resistance |
| **Barracks** | 1000g | Recruit militia (5/cycle) |
| **Training Ground** | 3000g | Recruit soldiers (3/cycle), upgrades militia |
| **Smithy** | 1500g | Repair equipment, craft basic gear |
| **Market** | 2000g | +50% trade income from this town |
| **Temple** | 2500g | New heroes start with +1 blessing (stat buff) |
| **Library** | 3000g | Unlocked blueprints carry across heroes |
| **Stables** | 2000g | Cavalry troops, faster overworld travel |
| **Port** | 5000g | Sea trade, access to Island zone |

### Troop Types

| Troop | Recruited From | Strength | Counter | Cost |
|-------|---------------|----------|---------|------|
| **Militia** | Any owned town | 1 | — | 50g |
| **Spearman** | Towns with Barracks | 2 | Beats Cavalry | 100g |
| **Archer** | Towns with Training | 3 | Beats Infantry | 150g |
| **Cavalry** | Towns with Stables | 4 | Beats Archers | 300g |
| **War Mage** | Alliance with Cennyn | 5 | Beats everything, fragile | 500g |
| **Zomboid Rider** | Alliance with Talmita | 4 | Swamp bonus, immune to poison | 250g |
| **Pirate Corsair** | Alliance with Toronega | 3 | Naval battles, raids | 200g |

### Auto-Battle Resolution

When armies clash:
1. Each side totals their **strength** (sum of all troop strengths)
2. Apply **counter bonuses** (+50% against countered type)
3. Apply **terrain bonus** (defender gets +20% in towns, +30% behind walls)
4. Apply **hero bonus** (if hero is present: +hero_level% strength)
5. Higher total wins. Loser loses troops proportional to the difference. Winner loses some troops too.

---

## Death & Succession

### What Persists (Dynasty)
- Owned towns and their buildings
- Gold in the dynasty treasury
- Discovered map (fog of war stays revealed)
- Completed alliance quest chains
- Troop garrisons
- Unlocked blueprints and recipes
- Pet kennel (owned pets wait at capital)

### What's Lost (Hero)
- Equipped gear (dropped where hero died — recoverable if you reach the spot)
- Active mutations
- Hero level and stats
- Companion bonds (companions scatter)
- In-progress dungeon floor (resets)

### Succession Mechanics
- New hero spawns at your **capital** (first owned town — Aria by default)
- Starts at Level 1 with a basic weapon from the capital's shop
- If you built a **Temple**, new hero gets a stat blessing
- If you built a **Library**, new hero knows all discovered recipes
- If you built a **Training Ground**, new hero starts at Level 3

### The Heir System (Future Feature)

Between dungeon runs, your hero can train an **heir** at any owned town:
- Heir gains XP passively based on town's Training Ground level
- When hero dies, you can choose the heir as your next hero
- Heirs inherit ONE piece of the previous hero's equipment
- This rewards staying alive longer — more time training = stronger heir

---

## Quest Progression Flow

### Act 1: Survival (Lvl 1-15)
```
q1 (Them Bones) ──→ q2 (Deliver Goods) ──→ NEW: Claim Farm
                                               │
q3 (Pelting Them) ──→ a4 (Evil Beneath) ──→ NEW: Walls of Aria
                                               │
                                         First Garrison ──→ Defend against raids
```

### Act 2: Alliance (Lvl 15-35)
```
a0 (Behold) ──→ S'thel Signs Treaty
                    │
q11 (Fish) + q5 (Stingers) ──→ Dondheim Signs Treaty
                                    │
q6 (The Treaty) ──────────────→ FREE TOWNS ALLIANCE
                                    │
a1 (3 Wishes) + a8 (Ghoul Hunt) ──→ Military Strength
                                    │
NEW: Scout Mountains ──→ NEW: Mountain Pass ──→ Northern Defense
```

### Act 3: Conquest (Lvl 35-80)
```
z8 (Endermen) + z9 (Plaguemaster) ──→ SIEGE OF KOR ──→ Northern Empire
                                                            │
a3 (Snakes Alive) ──→ Valley Secured                       │
                                                            │
z5-z7 (Naleg chain) ──→ Naleg Allied ──────────────────→ Southern Expansion
z10-z12 (Talmita chain) ──→ Talmita Allied (Zomboid Riders!)
                                                            │
a5/a12/a17/a19 (Tor4 chain) ──→ Pirate Alliance ──→ Sea Access
                                 OR                     │
                         Military Conquest ──→ Toronega Owned
```

### Act 4: Empire (Lvl 80-175)
```
z1-z4 (Cennyn chain) ──→ Arcane Alliance (War Mages!)
                              │
p1-p4 (Ynys chain) ──→ Far East secured
p5-p7 (Airlon chain) ──→ Eastern frontier
p8-p10 (Talnivek chain) ──→ Coastal control
                              │
a7/a14/a21 (Thule chain) ──→ Frozen South explored
                              │
                         SIEGE OF THULE ──→ Path to End1
                              │
                    end (Vanquish Evil) ──→ DYNASTY VICTORY
```

---

## MVP Scope (What to Build First)

### Minimum Playable Version
1. **Aria + Farm + Graveyard** — Three zones, fully functional
2. **Town ownership** — Claim Farm after clearing it, basic building menu
3. **Troop recruitment** — Militia from owned towns, simple garrison system
4. **One enemy faction** — Ironhide Warband raids from the mountains
5. **Auto-battle** — Simple strength comparison when attacking/defending
6. **Death/succession** — Hero dies, new one spawns at Aria, treasury persists
7. **3 existing quests** — q1, q2, a4 as the starter chain
8. **1 new quest** — "Claim the Farm" as tutorial for ownership

### Second Pass
- Treaty quest chain (q6) with S'thel and Dondheim
- Kor conquest arc
- Building upgrades
- Troop variety (spearmen, archers)
- Pirate faction interactions

### Third Pass
- Full southern expansion
- Cennyn alliance
- Heir system
- Endgame (Thule → End1)
- Island access via port
