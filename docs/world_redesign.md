# World Redesign — Making It Our Game

## What LoY Is vs What We Are

**LoY:** Walk to zone, kill stuff, walk to next zone. Every zone is interchangeable. No reason to care about geography.

**Our game:** Geography IS gameplay. Where a town is determines who can attack it. Where a chokepoint is determines who controls trade. A mountain pass isn't flavor — it's a strategic asset. Owning a bridge means controlling who crosses it.

The LoY zones give us a foundation — tile data, NPCs, shops, dungeons. But we need to reshape HOW they connect and WHY they matter.

---

## The Core Geographic Idea

Instead of LoY's web of random connections, the world has **3 concentric rings** around Aria:

```
RING 3 (OUTER) — Faction Capitals, Endgame
  Toronega, Cennyn, Thule, End1
  Hard to reach, heavily defended, rich

RING 2 (MIDDLE) — Contested Territory
  Heim, S'thel, Gomb, Kor, Naleg
  Towns caught between factions
  Can be allied, conquered, or lost

RING 1 (INNER) — Aria's Neighborhood
  Farm, Graveyard, Watchtower, Wild1, Camp, Riverside
  Your starting territory
  Safe-ish, tutorial zone

ARIA (CENTER)
  Home base, always yours
```

The world expands outward. You don't wander randomly — you push your borders. Each ring is harder than the last, but also richer.

---

## Reshaping the Map

### The LoY Problem

LoY's zones connect like this (simplified):
```
aria → wild1 → mnt1 → cold1 → nord1
                    → heim
             → vly1 → sthel
             → for1 → gomb → ...
             → camp
```

Everything goes through Wild1. One hub, spokes outward. No loops, no alternate routes, no strategic depth.

### Our Version

The world should have **regions** separated by natural barriers (mountains, rivers, forests, swamps). Each region has:
- A town (the prize)
- 2-3 wilderness zones (the approach)
- At least 2 entry routes (so there's strategic choice)
- A unique resource
- A local threat

```
                    ┌─── FROZEN WASTES ───── THULE ───── END1
                    │                         (endgame)
              TUNDRA PASS
                    │
     NORD ─── MOUNTAIN PASS ─── HEIM ─── TOWER COURTYARD
      │              │
      │         HIGH PEAKS ─── KOR
      │              │          (mountain fortress)
      │         MOUNTAIN
      │              │
      │         ┌── WILD1 ──┐
      │         │   (hub)   │
      │      FOREST     VALLEY ─── S'THEL ─── SHRINE
      │         │              (desert oasis)
      │      GOMB
      │     (coast)    WATCHTOWER
      │         │         │
      │      BRIDGE   ── FARM ── ARIA ── GRAVEYARD
      │         │                 │
      │      BLUFFS           RIVERSIDE ── CAMP
      │         │
      │      PASSAGE (underground)
      │         │
      │      BEACH ── TOR GATE ── TORONEGA
      │                            (pirate capital)
      │
      └─── PLAINS ── CENNYN ── VALE
                │      (ancient capital)
             SWAMP ── TALMITA
                │
             JUNGLE ── PAITITI
```

### Key Geographic Changes from LoY

**1. Mountain Barrier (North)**

LoY has mnt1 as just another zone. In our game, the **Mountains** are a wall separating Aria's region from the northern territories. You can't just walk through — there are only 2 passes:

- **Mountain Pass** (cold1 reskinned) — The main route north. Narrow, exposed, dangerous. Polar Bears and bandits. Whoever controls this pass controls access between south and north. This is a zone worth fighting over.
- **Underground Passage** (und1 reskinned) — A secret tunnel through the mountains. Dangerous (dark, cave enemies) but bypasses the pass entirely. Only discovered through quests. Not usable for armies — too narrow for troops. Hero-only shortcut.

This means: if the Ironhide Warband holds the Mountain Pass, your armies can't reach Nordolk or Heim. You'd need to either assault the pass or find the underground route for solo hero runs.

**2. The River (West to East)**

LoY has no rivers on the overworld. We add one — a major river running from the mountains in the north, past Aria (Riverside zone), through the forest, to the coast near Gomb. The river:

- Creates a natural border between regions
- Has bridges that become strategic chokepoints (Varn Bridge = brg1)
- The Riverside zone is where it passes near Aria
- Gomb becomes a **river port** as well as a coastal town
- Troop movement across the river requires a bridge or boats

**3. The Desert (South)**

S'thel and the Valley become part of a **desert region** that's fundamentally different from the green north. Different tiles, different enemies, different resources. The desert has:

- Limited water (armies need supply lines — can't just march through)
- Oasis towns (S'thel) are incredibly valuable because they control water
- Shrine is hidden deep in the desert — pilgrimage destination, not a random zone
- Sandstorms (random events that slow overworld travel)

**4. The Coast and Pirates (Southeast)**

Toronega isn't just a pirate town — it controls **sea access**. The entire Tor chain (tor1-6) becomes a **coastal region**:

- Beach → Tor Gate → Toronega is the land approach (heavily defended)
- The river mouth near Gomb is the river approach (need boats)
- Island (the isolated zone) is only reachable by ship from Toronega's port
- Sea trade is massively profitable but requires port access

This gives the pirates real power — they control something you need (sea routes, Island loot, trade income).

**5. The Jungle (Far South)**

The jungle zones become a **deep wilderness** that can't really be "owned" in the traditional sense:

- Too dense for armies
- Paititi is a hidden village, not a conquerable town — they're allies or nothing
- Talmita in the swamp is similar — the tribal people know the terrain, you don't
- These zones require diplomacy, not force
- Unique resources (exotic herbs, rare pets, ancient relics) only available here

**6. The Endgame Zone (Far North/Deep)**

Thule → Frozen Wastes → End1 is the **endgame corridor**. It's:

- Beyond the mountains, past everything
- Controlled by the Arcane Circle (undead/magical faction)
- The environment itself is hostile (frozen damage over time without cold resistance)
- End1 (Gates of Hell) requires both a strong hero AND a supply line from your empire
- Nobody can just wander there — you need infrastructure

---

## New Zones (Original Content)

These zones don't exist in LoY. They fill geographic gaps and create strategic depth.

### Crossroads (20x20) — Wild1 Sub-zone
Where the old kingdom's trade roads intersected. Now overgrown and abandoned. Stone markers point in four directions. A ruined fountain in the center.

**Function:** Buildable trade post. Whoever owns the Crossroads controls overland trade through the wilderness. Generates passive gold when trade routes are active. Also serves as a fast-travel waypoint.

**Look:** Crumbling cobblestone plaza surrounded by forest. Four roads (faded) leading north/south/east/west. The fountain is dry and cracked. Vines on everything.

### Millford (25x20) — River Crossing Town
A small settlement at the main river ford. Has a wooden bridge (upgradeable to stone), a mill, and a few houses. Currently abandoned — the miller fled when bandits took over.

**Function:** Controls the river crossing for armies. Without Millford, troops can't cross the river (hero can swim but armies can't). Also produces grain from the mill.

**NPCs:**
- **Old Torrin** (miller) — returns after you clear the bandits. Runs the mill. Sells bread (healing item). Quest: repair the mill mechanism (needs iron from farm dungeon).
- **Fern** (ferryman) — operates a small ferry upstream. For a fee, moves your hero across the river at other points. Quest: build him a bigger boat (need lumber + rope) → can transport small troop groups.

**Quests:**
- "The Miller's Return" — clear 6 bandits from Millford. Torrin moves back. Bridge becomes usable. Reward: Millford as ownable settlement + grain production.
- "Bridge Repair" — the wooden bridge is rotting. Bring 15 lumber from Farm to repair it. Reward: armies can cross, increased trade income.

### The Quarry (15x20) — Mountain Resource Zone
An old stone quarry carved into the mountainside. Abandoned when the kingdom fell. Rich in building stone.

**Function:** Source of stone for construction. Stone walls, stone towers, upgraded buildings all need quarried stone. Without the Quarry, you're limited to wooden structures (palisades, basic buildings).

**Enemies:** Rock Trolls (tough but slow), Cave Bats (annoying, weak). A Rock Golem mini-boss guards the deep quarry.

**Quests:**
- "Reopen the Quarry" — clear the Rock Golem. Reward: stone production begins (X stone per cycle).
- "Stonecutter's Tools" — Arnie can make quarrying tools if you bring him 5 iron ore. Doubles stone output.

### Thornfield (25x25) — Contested Farmland
A wide, flat zone between Aria's territory and the Ironhide Warband's range. Rich soil, but exposed — no natural defenses. Used to be the kingdom's breadbasket.

**Function:** Major food production zone. Worth 3x what Farm produces. But it's in contested territory — the Ironhide Warband wants it too. Owning Thornfield means constant raids unless you secure the Mountain Pass.

**This creates a strategic dilemma:** Thornfield is incredibly valuable but expensive to defend. Do you take it early and drain your garrison? Or secure the pass first and take Thornfield safely later?

**NPCs:**
- **Edda** (farmer's widow) — her husband was killed by orcs. She stayed. Tough, practical. Sells surplus food at good prices. Quest: build a watchtower on her land → she provides scout intel about incoming raids.

**Quests:**
- "Thornfield Reclaimed" — drive off the orc raiding party (8 orcs + Orc Captain). Reward: claim Thornfield, massive food bonus.
- "The Scarecrow Line" — Edda's idea: build scarecrow decoys along the northern border. Costs 500 gold + 10 lumber. Delays raids by 1 cycle (raiders investigate the decoys first).
- "Edda's Revenge" — she asks you to kill the specific Orc Warchief who killed her husband. He's at Kor. This quest can't be completed until you push into Ring 2. It sits in your quest log as a long-term goal.

### Harbormouth (20x15) — River Delta
Where the river meets the sea, near Gomb. Marshy, flat, reedy. A few fishing shacks.

**Function:** The junction between river trade and sea trade. If you control both Gomb and Harbormouth, you can trade by river all the way from Millford to the sea. Massive income.

**Strategic value:** The pirates want Harbormouth because it gives them river access to inland towns. If they take it, pirate raiders can sail upriver and attack Millford or even threaten Aria's supply lines.

**Quests:**
- "River Mouth" — build a dock at Harbormouth. Costs 2000 gold + 20 lumber. Connects river and sea trade routes.
- "Pirate Probes" — a pirate scout ship is spotted. Defeat the crew (5 corsairs). This is the first hint that Toronega is watching your growth.

### The Old Capital (30x30) — Ruins Zone
Deep in the wilderness, off the main roads. The crumbling remains of the old kingdom's capital city. Overgrown with trees, half-sunken into the earth. Nobody goes here.

**Function:** Lore zone + endgame unlock. Exploring the ruins reveals the history of the old kingdom — who they were, what they sealed underground, and why they fell. Also contains the entrance to the deepest dungeon in the game.

**This is NOT a LoY zone.** This is original. It's our game's central mystery location.

**What you find here (across multiple hero visits):**
- **First visit:** Ruined walls, collapsed buildings. A throne room with a shattered crown on the floor. Inscription: "We who guard the deep, so the world may sleep."
- **Second visit (with Morin's leyline knowledge):** Hidden chamber beneath the throne. Magical seals — most broken. One remains. Morin (if brought here via quest) explains: the kingdom was built specifically to maintain these seals.
- **Third visit (endgame):** The last seal breaks. The deep dungeon opens. What's below is what destroyed the old kingdom and what your dynasty must finally face.

**Quests:**
- "Ruins of the Past" — Blaidd's maps mention an old capital. Find it. Just reaching it is the challenge — it's in dense wilderness with no paths.
- "The Shattered Crown" — bring the crown fragment to the Elder. He recognizes it. His family were minor nobility in the old kingdom. This unlocks his full backstory.
- "The Last Seal" — endgame quest. Requires: control of 5+ towns, alliance with Cennyn (whose lord remembers the old kingdom), a hero of level 50+, and Morin's help. Break the seal and descend. The final dungeon.

---

## How Our Quests Differ from LoY

LoY quests: "Kill X. Collect Y. Deliver Z. Get reward."

Our quests should always DO something to the world:

| LoY Style | Our Style |
|-----------|-----------|
| Kill 20 skeletons → 500 gold | Kill 20 skeletons → graveyard spawn rate drops, crypt access opens |
| Deliver package → 400 gold | Deliver grain → supply line established, Aria gains food income |
| Collect 10 pelts → cloak | Collect 10 pelts + 10 ore → Arnie opens forge, custom weapons available |
| Kill Fire Beast → hat | Kill Fire Beast + explore tunnels → discover underground threat, story progresses |

Every quest should change something:
- A zone becomes safer (reduced spawns)
- A resource becomes available (ore, stone, food)
- An NPC unlocks a service (forging, enchanting, training)
- A route opens (bridge repaired, pass cleared)
- Territory changes hands (outpost claimed, town allied)
- Story progresses (mystery deepens, faction reacts)

---

## Regional Quest Chains (Beyond Aria)

### The Northern Campaign (Ring 2 North)

After securing Aria's neighborhood (Ring 1), the player pushes north through the Mountain Pass toward Heim and Nordolk. This is primarily a military campaign against the Ironhide Warband.

**"The Pass" (Level 12)**
Ryu tells you the Mountain Pass is the key to the north. It's currently held by bandits allied with the Ironhide Warband. Clear the pass → establish a fortified camp → your armies can move north.

The pass is narrow (cold1 is 60x24 — long and thin). Perfect for a chokepoint defense. Once you hold it, the Ironhide can't raid south easily.

**"First Contact: Nordolk" (Level 15)**
Beyond the pass, Nordolk (nord1, 45x25) is a struggling settlement. Eski the elder is old and tired. The Ironhide Warband extorts them for "protection money."

Two approaches:
- **Military:** Station troops at Nordolk. The Ironhide sends a raiding party. Defend Nordolk → they join you out of gratitude.
- **Diplomatic:** Complete Eski's quests (a2 "The Mighty Horn" — kill a Minotaur; a11 "Smashing Ice Cubes" — kill Frosties; a15 dragon egg delivery). Earning his trust → he asks YOU to deal with the Ironhide, then joins willingly.

**"Dondheim's Choice" (Level 20)**
Heim (20x20) is a proper fortress city. Odin is its warlord — strong, proud, independent. He doesn't want to join anyone. But the Ironhide Warband is massing at Cyclops Valley (cycl) for a major assault.

The quest: convince Odin to ally with you BEFORE the assault hits. This requires completing his quest chain (q11 fish pie, q5 stingers, q8 love letter, q10 medicine man — these are all existing LoY quests!). Each quest earns a fragment of trust. Complete enough → Odin agrees to a military alliance.

If you're too slow, the Ironhide assault happens. Odin fights alone. If he wins, he's weakened and more receptive. If he loses... Heim falls and you have to liberate it.

**"Siege of Kor" (Level 25)**
The climax of the northern campaign. Kor (30x20) is the Ironhide Warband's fortress in the mountains. To assault it:
- Need 30+ troops
- Need the Mountain Pass secured (supply line)
- Need at least one northern ally (Nordolk or Heim) providing flanking support
- Complete z8 "End the Endermen" and z9 "Deadly Disease" to weaken Kor's defenses

The siege is an auto-battle with your choices affecting the outcome. Which troops you bring, which route you take (frontal through Peaks or flanking through a mountain trail), whether you poisoned their supplies (z9 connection). Win → Kor is yours. The Ironhide Warband scatters. Northern region secured.

### The Western Trade Route (Ring 2 West)

This campaign is about economics, not war. You're trying to establish a trade network from Aria to the coast.

**"Road Through the Forest" (Level 10)**
For1 (Hallows, 50x30) is a huge forest zone between Wild1 and Gomb. Creepers infest it. The old trade road is overgrown. Clear sections of the forest to reopen the road.

This isn't a single quest — it's a **project**. Each section you clear stays clear. The road grows longer. Eventually it connects Wild1 to Gomb. This takes multiple hero lives potentially.

**"Gomb the Merchant" (Level 15)**
Gomb (52x20) is a coastal trading hub. Zeng the elder is a diplomat — he wants trade, not war. He's the one who offers the Treaty quest (q6).

But Gomb has its own problems. The forest Creepers are threatening their eastern border (a10 "Creepers Peepers"). The pirates occasionally raid their docks. And there's a dragon in the area (a23 "Dragon Bashing").

Helping Gomb → they become a trade partner → massive gold income from coastal trade. Plus Zeng's treaty opens diplomatic doors to S'thel and Heim.

**"The River Route" (Level 18)**
Once you control Millford and Gomb, propose a river trade route. Requires:
- Millford bridge repaired
- Harbormouth dock built
- Gomb allied or owned
- No hostile zones blocking the river

Establishing the river route = enormous passive income. But it's vulnerable — any hostile zone along the river can raid traders. This gives you a reason to patrol and defend territory, not just conquer and forget.

### The Southern Mystery (Ring 2 South)

S'thel and the desert zones are about the underground mystery — the deeper story.

**"The Desert Road" (Level 12)**
Valley (vly1, 60x24) is the approach to S'thel. Scorpions and Dingos. Long and exposed. The old trade road has sand drifts covering it.

S'thel itself (25x25) is an oasis town. K'atel the priestess knows things about the old kingdom that the Elder doesn't. She's a descendant of the kingdom's magical council.

**"Secrets of the Priestess" (Level 18)**
K'atel won't share what she knows until you prove trustworthy. Complete her quests:
- q4 "Tooth Ache" — collect teeth from the mountains
- q7 "Lost Child" — rescue a child from goblins
- a0 "Behold" — kill the Beholder
- a8 "Ghoul Hunt" — thin the ghouls

After all four: K'atel reveals that the old kingdom didn't just guard something — they **imprisoned** something. The tunnels beneath the world are a prison network. The crypt under Aria's graveyard, the Endless Caverns, the deep mines under the farm — they're all cells. And the prisoners are waking up.

**"The Shrine" (Level 22)**
K'atel sends you to the Shrine (17x17) — a sacred place deeper in the desert. The priestess there guards one of the prison seals. But the seal is cracking.

At the Shrine, you learn what the prisoners are: not monsters, but the old kingdom's enemies from a war fought underground. An entire civilization that lived beneath the surface. The old kingdom drove them down and sealed the exits. Centuries later, they're digging back up.

This reframes EVERYTHING. The skeletons in the graveyard, the fire beasts at the farm, the creatures in every dungeon — they're all being pushed upward by the real threat below. The monsters are refugees, in a sense. Fleeing something worse.

### The Pirate Negotiations (Ring 2 Southeast)

**"Sea Dogs" (Level 20)**
You can't ignore the pirates forever. Toronega controls sea trade, and as your kingdom grows, you need that trade.

Approach via the coast: Beach → Tor Gate → Toronega. The Tor chain is essentially one long fortified corridor (47x21 each — long narrow zones). The pirates have checkpoints, guards, and the terrain favors defense.

**Two paths:**

**Path A — Force:**
Fight through Tor3 (gate guards), then Tor1 (port garrison), then siege Tor2 (the capital itself). Requires 50+ troops and multiple hero lives. Expensive. Destructive. But you get everything.

**Path B — The King's Deal:**
Tor4's king (the elder there) is more pragmatic than the pirate captains. He'll deal. Complete his quests:
- a5 "Nasty Sting" — kill Giant Scorpion (proves you're strong)
- a12 "Making a Stand" — kill 25 Orc Witches (proves you fight their enemies too)
- a17 "Jar of Wisps" — delivery to Paititi (proves you have reach)
- a19 "Light the Way" — delivery to Gomb (proves you have trade connections)

After all four, the King proposes a deal: Toronega becomes a trade partner (not a vassal). You get port access. They get military protection. Neither side owns the other. It's a genuine alliance of equals.

The trade-off: Path A gives total control but costs massively and makes enemies. Path B is cheaper but you don't own Toronega — they can renegotiate later.

---

## Resource Geography

Each region produces something unique. This creates trade interdependency — you can't be self-sufficient with just Aria.

| Region | Unique Resource | Used For |
|--------|----------------|----------|
| **Aria/Farm** | Food, Lumber | Feeding troops, wooden buildings |
| **Quarry (new)** | Stone | Stone buildings, walls, towers |
| **Wild1/Forest** | Pelts, Herbs | Light armor, potions, trade goods |
| **Mountains/Kor** | Iron Ore | Weapons, heavy armor, tools |
| **S'thel/Desert** | Crystals, Magic Sand | Enchanting, magical items |
| **Gomb/Coast** | Fish, Salt | Preserved food (longer supply lines) |
| **Toronega/Sea** | Exotic Goods, Ship Parts | Luxury trade, navy, island access |
| **Jungle/Paititi** | Rare Herbs, Ancient Relics | Best potions, unique enchants |
| **Talmita/Swamp** | Venom, Swamp Reeds | Poison weapons, special troop gear |
| **Nordolk/Tundra** | Furs, Ice Crystals | Cold resistance gear, frost enchants |
| **Cennyn/Vale** | Ancient Knowledge, Runestones | Advanced enchanting, building blueprints |
| **Thule/Frozen** | Dark Essence | Endgame crafting, seal magic |

**This means:** To build a fully upgraded kingdom, you need resources from at least 4-5 different regions. You can't just conquer everything — you need trade with regions you can't or won't conquer (jungle, desert). Geography forces diplomacy.

---

## What Makes This NOT LoY

| LoY | Our Game |
|-----|----------|
| Zones are interchangeable | Zones have unique strategic value |
| Walk anywhere from the start | Geography gates progression (mountains, rivers, desert) |
| Quests are errands | Quests change the world permanently |
| NPCs are shops | NPCs have relationships, react to world state |
| No death consequence | Death is the core loop — dynasty persists, hero doesn't |
| Static world | World changes: zones conquered, routes opened, factions react |
| Single hero story | Multi-generational saga — the kingdom remembers |
| Kill stuff, get loot | Kill stuff, gain territory, build infrastructure, command armies |
| One solution per quest | Multiple approaches (military, diplomatic, economic) |
| The map is the game | The map is the battlefield, the game is what you build on it |

### Original Story Elements (Not From LoY)

1. **The Underground Prison** — the old kingdom imprisoned an underground civilization. The seals are breaking. Every dungeon is connected to this.
2. **The Dynasty System** — heroes die, kingdoms persist. Each generation pushes further.
3. **Faction AI** — the Ironhide Warband raids, pirates blockade, the Arcane Circle is inscrutable. They ACT, not just wait.
4. **The Old Capital** — an entirely new zone. The mystery hub. Multiple visits across multiple heroes to uncover the truth.
5. **Economic Warfare** — choking trade routes, controlling river crossings, starving garrisons. Not just sword fights.
6. **The Choice** — when you finally descend to the prison and meet the underground civilization... do you destroy them or negotiate? They're not evil — they're trapped. The old kingdom wasn't heroic — it was imperial. Your dynasty can repeat history or break the cycle.

---

## Zone Summary Table

### Ring 1 (Starting Territory)
| Zone | Size | Type | Original? | Key Feature |
|------|------|------|-----------|-------------|
| Aria | 25x25 | Town | LoY | Home base, 4 buildings, 8 NPCs |
| Farm | 25x25 | Resource | LoY | Food + lumber + ore (dungeon) |
| Graveyard | 20x30 | Dungeon Access | LoY | Crypt, underground shortcut |
| Watchtower | 15x15 | Outpost | **NEW** | Forward defense, lookout |
| Riverside | 20x15 | Resource | **NEW** | Fishing, herbs, safe route to Camp |
| Camp | 20x20 | Military | LoY | Training, troop upgrades |
| Wild1 | 50x50 | Wilderness Hub | LoY | Crossroads, thief camp, Endless Caverns |

### Ring 2 (Contested Territory)
| Zone | Size | Type | Original? | Key Feature |
|------|------|------|-----------|-------------|
| Millford | 25x20 | Town | **NEW** | River crossing, grain mill, bridge |
| Quarry | 15x20 | Resource | **NEW** | Stone production for building |
| Thornfield | 25x25 | Resource | **NEW** | Rich farmland, contested by Ironhide |
| Harbormouth | 20x15 | Port | **NEW** | River-to-sea junction, trade hub |
| Old Capital | 30x30 | Ruins | **NEW** | Lore, mystery, endgame dungeon entrance |
| Mountain Pass | 60x24 | Chokepoint | LoY (cold1) | Controls north-south access |
| Heim | 20x20 | Town | LoY | Northern fortress, Odin |
| Nordolk | 45x25 | Town | LoY | Northern settlement, Eski |
| S'thel | 25x25 | Town | LoY | Desert oasis, K'atel, lore |
| Gomb | 52x20 | Town | LoY | Coastal trade hub, treaty |
| Kor | 30x20 | Fortress | LoY | Ironhide capital, siege target |
| For1 (Hallows) | 50x30 | Wilderness | LoY | Forest road project, creepers |
| Vly1 (Valley) | 60x24 | Wilderness | LoY | Desert approach, scorpions |
| Peaks | 40x40 | Wilderness | LoY | Mountain wilderness, endermen |
| Moors | 30x25 | Wilderness | LoY | Eastern frontier, ninjas |
| Plains | 50x25 | Wilderness | LoY | Southern grassland, trade route |

### Ring 3 (Endgame)
| Zone | Size | Type | Original? | Key Feature |
|------|------|------|-----------|-------------|
| Toronega | 47x21 | City | LoY | Pirate capital, sea access |
| Cennyn | 50x50 | City | LoY | Ancient capital, largest city, arcane knowledge |
| Thule | 30x25 | Ruins | LoY | Cursed city, endgame crafting |
| End1 | 15x15 | Final Zone | LoY | Gates of Hell, final dungeon |
| Island | 25x35 | Special | LoY | Ship-only access, Ifrits, legendary loot |
| Paititi | 20x20 | Hidden | LoY | Jungle village, diplomatic only |
| Talmita | 25x25 | Tribal | LoY | Swamp warriors, unique troops |
| Talnivek | 25x25 | Town | LoY | Coastal town, late-game quests |

**Total: ~35 active zones** (7 new + 28 LoY zones repurposed), down from LoY's 54. We cut the filler zones and made every remaining one matter.
