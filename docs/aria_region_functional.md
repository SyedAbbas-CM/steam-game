# Aria Region — Functional Design

## Current Problem

Aria has one exit north (blocked til level 6), one east to farm, one south to graveyard. Wild1 is the only hub and it connects to everything. There's no reason to go back to anywhere once you've been there. The NPCs sell stuff and that's it.

## Redesigned Node Map

```
                    MNT1
                     |
          FOR1 ---- WILD1 ---- VLY1
                   /     \
              CAMP         WATCHTOWER (new, small)
               |               |
               |           FARM ---- ARIA ---- GRAVEYARD
               |                       |
               +----------- RIVERSIDE (new, small)
```

### What Changed

1. **Farm connects to Aria AND to a new Watchtower** — this creates a loop. You can go Aria → Farm → Watchtower → Wild1, OR Aria → (through the graveyard passage) → eventually Wild1. Two routes north.

2. **New zone: Watchtower** (15x15, tiny) — a ruined watchtower on a hill between Farm and Wild1. It was an old kingdom outpost. Currently overrun by bandits. Clear it → it becomes a garrison point. Functionally: an ownable outpost that provides early warning of raids and a shortcut between farm and wilderness.

3. **New zone: Riverside** (20x15, small) — a riverbank south of Aria, past the graveyard and curving west toward Camp. Has fishing spots (Yoregot sells fishing poles). Connects Camp to Aria's area without going through Wild1. Functionally: a safe-ish resource zone (fish for food/trade) and an alternate route to Camp.

4. **Graveyard gets a hidden passage** — deep in the crypt, a collapsed tunnel connects to the Endless Caverns (Wild1's dungeon). This is a dangerous shortcut for experienced players: skip the entire Wild1 overworld by going underground. But the passage is dark, has tougher enemies, and requires clearing the crypt first.

### Route Options After Redesign

**Getting from Aria to Wild1 (3 routes):**
- **North Gate** — Aria → Guard check → Wild1 south entrance. Direct but level-gated.
- **Farm Loop** — Aria → Farm → Watchtower → Wild1 southeast. Longer but avoids the guard. Requires clearing the watchtower first.
- **Underground** — Aria → Graveyard → Crypt → tunnel → Endless Caverns → Wild1 cavern exit. Dangerous shortcut. High risk, skips overworld entirely.

**Getting from Aria to Camp (2 routes):**
- **Through Wild1** — Aria → north gate → Wild1 → south to Camp. Long, dangerous.
- **Riverside** — Aria → south → Riverside → west → Camp. Safer but slower. Good for early game before you can survive Wild1.

---

## Zone Functions (What Each Zone DOES)

### Aria (25x25) — Home Base

**Buildings & Their Functions:**

| Building | NPC | Current | New Function |
|----------|-----|---------|-------------|
| Arnie's Weapons | Arnie | Shop (23 items) | Shop + **Repair** (gear degrades) + **Upgrade** (pay gold to improve a weapon tier) |
| Crooked Beak Inn | Yoregot | Shop (8 consumables) | Shop + **Rumors** (random hints about nearby zones) + **Hire Mercenaries** (temporary combat companion, 1 dungeon run) |
| Shrowded Orb | Morin | Shop (8 magic items) | Shop + **Identify** (unknown items from chests) + **Enchant** (add a buff to gear, costs gold + materials) |
| Town Hall | Elder | Quest giver | Quests + **Town Management** (build/upgrade when you're lord) + **Notice Board** (active threats, requests from other zones) |

**New Functional Additions:**
- **Militia Barracks** (buildable) — recruit militia. Requires lumber from Farm.
- **Market Stall** (buildable) — trade surplus resources. Requires trade route to another town.
- **Walls** (buildable) — palisade first (cheap), stone later (expensive). Determines garrison capacity and raid resistance.
- **Notice Board** — shows: active quests, current threats ("Bandits spotted near Watchtower"), trade opportunities ("Gomb trader wants 20 fish, paying 800 gold"), and garrison status.

### Farm / Caws Mawr (25x25) — Resource Production

**Current NPCs → New Roles:**

| NPC | Current Role | New Function |
|-----|-------------|-------------|
| Dafydd | Message ("try digging and fishing") | **Farm Manager** — shows farm output (food/cycle), lets you assign workers, reports problems |
| Blaidd | Maps vendor | **Cartographer** — sells maps that reveal fog of war for specific zones. Pay 200g to reveal Wild1 layout. Pay 500g for Mnt1. |
| Plentyn | Message (kid) | **Runner** — sends messages between Aria and Farm. Later: delivers supplies automatically (no manual carrying) |
| Mabion | Pet vendor | **Animal Handler** — breeds animals. Sheep produce wool (trade good). Cows produce milk. Later: war dogs (troop type). |

**Farm Functions:**
- **Food production** — generates food passively when owned. Food feeds troops. No food = troops desert.
- **Lumber** — trees around the farm can be harvested. Lumber builds structures in Aria.
- **Animal breeding** — Mabion's pens. Start with sheep/cows. Later: war dogs, carrier pigeons (fast messaging between towns).
- **Storage pit dungeon** — 6 floors. Theme: something dug up from below. Deeper floors have ore deposits (mine for metal → Arnie uses metal to forge better gear).

### Graveyard (20x30) — Danger Zone / Shortcut

**Functions:**
- **Skeleton farming** — respawning enemies for XP grinding. 20% spawn rate means it's not overwhelming.
- **Crypt dungeon** — 3 floors. Undead themed. Good loot: gold (10-30 per chest), green potions.
- **Underground passage** — unlocked after clearing the crypt. Connects to Endless Caverns. Dangerous shortcut to Wild1.
- **Gravedigger NPC** (new) — an old man who tends the graves. Sells shovels, buys grave goods. Gives lore about who's buried here. Quest: "Find my daughter's locket in the crypt."

### Wild1 / Wilderness (50x50) — Contested Territory

This is the big one. 50x50 is huge. It should have **sub-areas** with distinct purposes:

**Sub-areas within Wild1:**

| Area | Location | Enemies | Function |
|------|----------|---------|----------|
| **South Road** | Bottom center | Light (dogs) | Main path from Aria. Road tiles visible. Safest route. |
| **Thief Woods** | East side | Thieves (heavy) | Dense trees. Thief camp visible. Clearing it = quest + reduced spawns. |
| **Dog Plains** | West side | Wild dogs (heavy) | Open grassland. Good pelt farming. |
| **Rocky Highlands** | North center | Mixed | Elevated terrain toward mountains. Harder enemies. |
| **Endless Caverns** | Northeast (40,19) | Cave enemies | Dungeon entrance. 5 floors. Connects underground to crypt passage. |
| **Crossroads** | Center (25,25) | Light | Where all paths meet. Old stone marker. Future: trade post location. |

**Quests in Wild1:**

1. **"Clear the South Road"** — Remove obstacles and kill enemies along the Aria→Wild1 path. Reward: safer travel (reduced spawns on the road). NPCs start using this road for trade.
2. **"The Thief Camp"** — Assault the bandit camp in the east woods. Mini-boss: Thief Captain. Reward: stolen goods (gold + random equipment), and thieves stop respawning so heavily.
3. **"Dog Catcher"** — Mabion (Farm) wants you to capture a wild dog alive (special item: net, bought from Yoregot). Bring it back → Mabion tames it → unlocks War Dog troop type.
4. **"The Endless Caverns"** — Jimbob tells you about a treasure deep in the caverns. 5-floor dungeon. Floor 5 has a mini-boss + connects to the underground network.

**Ownership:** Wild1 can't be "owned" like a town — it's too big and wild. But you can **establish a presence**: build a Trade Post at the crossroads (costs gold + lumber). The Trade Post generates income when trade routes pass through it and serves as a fast-travel waypoint.

### Camp (20x20) — Military Training

**Ryu's Functions:**
- **Train hero** — pay gold to gain XP. Expensive but safe. Good for new heroes who inherit a rich dynasty.
- **Train troops** — militia stationed here upgrade to soldiers after 3 cycles. Soldiers upgrade to veterans after 5.
- **Sparring** — practice combat against Ryu. He's tough. Beating him grants a permanent small buff to the current hero. This gives a reason to come back each hero life.
- **War Room** (buildable) — a planning table. Shows the region map with faction movements. Lets you issue orders to garrisons (move troops between owned zones).

### Watchtower (15x15, new) — Forward Outpost

Small zone. A crumbling stone tower on a rocky hilltop. Currently occupied by 3-4 bandits.

**Quest: "Take the Tower"**
The Elder (or Ryu) suggests securing the old watchtower between Farm and the Wilderness. It's small — only a few bandits. But it overlooks the roads.

Clear the bandits → claim the tower. It becomes your first **outpost** (smaller than a town, limited building slots).

**Outpost Functions:**
- **Lookout** — warns you 1 cycle in advance of raids. Without it, raids are surprise attacks.
- **Garrison** (5 troops max) — small force that can delay raiders, buying time for reinforcements.
- **Signal fire** — if the watchtower is attacked, it alerts Aria and Farm to send help.
- **Shortcut** — the watchtower sits between Farm and Wild1, creating the alternate northern route.

### Riverside (20x15, new) — Resource Zone

A gentle riverbank with reeds, a fishing dock, and a small bridge crossing.

**Functions:**
- **Fishing** — use fishing pole (bought at Crooked Beak) to catch fish. Fish = food resource + trade good. Specific fish types for specific quests.
- **River crossing** — the bridge connects Aria's south region to Camp's area without going through Wild1. Safe travel for early game.
- **Herbalist NPC** (new) — an old woman who lives by the river. Sells healing herbs cheaper than Morin's potions. Gives a quest: "Bring me 5 green mushrooms from the crypt" → she brews a special potion that resists undead damage.
- **Reed gathering** — reeds + animal hides → Arnie can craft light armor. Gives Farm animals economic value beyond food.

---

## NPC Quest Web (Who Sends You Where)

The quests should bounce you between NPCs and zones, not just "Elder says go kill stuff."

```
ELDER (Town Hall)
 ├── "The Bones Beneath" → GRAVEYARD → discover crypt
 ├── "Secure the Roads" → ask YOREGOT about trade → go to WILD1
 └── "Take the Tower" → talk to RYU first → WATCHTOWER

YOREGOT (Crooked Beak Inn)
 ├── "Rumors of the Road" → hints about WILD1 thief camp
 ├── "Liquid Courage" → needs rare fish from RIVERSIDE for a special brew
 └── delivers letter to ELDER about outside traders

ARNIE (Weapons Shop)
 ├── "Pelts and Steel" → needs pelts from WILD1 + ore from FARM dungeon
 ├── "The Old Forge" → his forge needs repair → lumber from FARM
 └── unlocks better gear as you bring materials

DAFYDD (Farm)
 ├── "Fire Below" → FARM DUNGEON → clear fire beasts
 ├── "Feed the Town" → establish supply line to ARIA
 └── "The Tunnels" → reports new creatures → deep dungeon floors

RYU (Camp)
 ├── "The Trial" → combat training → recruits first militia
 ├── "Old Soldier's Regret" → asks you to find his old commander's sword in ENDLESS CAVERNS
 └── "Ready for War" → when you have 10 troops → unlocks army movement

MORIN (Magic Shop)
 ├── "Shrowded Knowledge" → needs a book from GRAVEYARD crypt floor 2
 ├── "The Leyline" → strange magic readings → investigate WATCHTOWER ruins
 └── can enchant gear after you bring her crypt materials

MABION (Farm - Pet Handler)
 ├── "Dog Catcher" → capture wild dog in WILD1 → war dog troop type
 ├── "Breeding Program" → bring specific animals from other zones
 └── "Guard Dogs" → assigns trained dogs to garrison for defense bonus

BLAIDD (Farm - Cartographer)
 ├── sells zone maps (reveals layout before you visit)
 ├── "Map the Caverns" → offers bonus gold if you fully explore ENDLESS CAVERNS
 └── "Lost Explorer" → a cartographer went missing in WILD1 → find his notes
```

---

## Route Strategy (Why Multiple Paths Matter)

Right now: Aria → Wild1 → everywhere. One chokepoint. Boring.

After redesign, the player has **decisions**:

**Early game (Level 1-5):**
"I need to get to Camp to train with Ryu. I can't survive Wild1. But I can take the Riverside path — it's safe and I can fish along the way."

**Mid game (Level 6-10):**
"The Elder wants me to clear the Watchtower. I could go through Farm → Watchtower directly. Or I could enter Wild1 first, clear the south road for the trade bonus, THEN loop back to the Watchtower from the wilderness side and catch the bandits from behind."

**Late game (Level 10+):**
"I need to get to the Mountains fast. The overworld route through Wild1 takes forever and I keep getting jumped by thieves. But I cleared the crypt and the underground passage connects to the Endless Caverns. I can go Graveyard → Crypt → tunnel → Caverns → exit into Wild1 right near the north road. Risky but fast."

**When raids happen:**
"Ironhide raiders are hitting Farm from the Watchtower direction! If I garrisoned the Watchtower, my troops there buy me time. If I didn't, the raiders hit Farm directly and I need to rush from Aria to defend."

The routes create **meaningful choices**, not just different colored hallways to the same destination.

---

## Economy Flow

```
FARM ──(food/lumber/wool)──→ ARIA ──(gold/gear)──→ troops
  │                            │
  │                         MARKET ──(trade goods)──→ other towns
  │                            │
  └──(ore from dungeon)──→ ARNIE ──(crafted gear)──→ hero / troops

RIVERSIDE ──(fish/reeds)──→ ARIA
                              │
GRAVEYARD ──(crypt loot)──→ MORIN ──(enchanted items)──→ hero

WILD1 ──(pelts/stolen goods)──→ trade value
  │
  └── Trade Post ──(passive income when trade routes active)
```

**Key resources:**
- **Food** — Farm + Riverside. Feeds troops. No food = desertion.
- **Lumber** — Farm trees. Builds structures.
- **Ore** — Farm dungeon deep floors. Arnie forges gear.
- **Pelts/Hides** — Wild1 dogs. Arnie crafts light armor. Trade good.
- **Fish** — Riverside. Food + Yoregot's special brews + trade good.
- **Crypt Materials** — Graveyard. Morin uses for enchantments.
- **Gold** — everything. Shops, building, troops, trade.

---

## Quest Progression (Functional Order)

### Tier 1: Tutorial (Level 1-4)
1. **"The Bones Beneath"** — Elder → Graveyard. Kill skeletons, discover crypt. Teaches: combat, zones.
2. **"Fire Below"** — Elder → Farm. Clear dungeon. Teaches: dungeons, deeper exploration.
3. **"Deliver the Letter"** — Elder → Yoregot. World-building. Teaches: NPC relationships.

### Tier 2: Expansion (Level 5-8)
4. **"Ryu's Trial"** — Ryu at Camp. Train + recruit first troop. Teaches: troops, garrison.
5. **"Take the Tower"** — Elder/Ryu → Watchtower. Clear bandits, claim outpost. Teaches: territory control.
6. **"Feed the Town"** — Dafydd → Aria. Establish food supply line. Teaches: economy/supply.

### Tier 3: Wilderness (Level 8-12)
7. **"Clear the South Road"** — Elder → Wild1. Make the road safe. Teaches: zone control, spawn management.
8. **"Pelts and Steel"** — Arnie → Wild1 + Farm dungeon. Gather materials. Teaches: crafting loop.
9. **"The Thief Camp"** — Yoregot's rumor → Wild1 east. Raid the camp. Teaches: mini-boss, zone clearing.
10. **"Dog Catcher"** — Mabion → Wild1. Capture dog with net. Teaches: special items, new troop type.

### Tier 4: Preparation (Level 12+)
11. **"The Endless Caverns"** — Jimbob's hint. 5-floor dungeon in Wild1. Teaches: harder content.
12. **"Old Soldier's Regret"** — Ryu → Caverns floor 3. Find the sword. Teaches: deep dungeon objectives.
13. **"The Leyline"** — Morin → Watchtower. Investigate magic. Connects to broader world mystery.

**After Tier 4:** The player is ready to push beyond Wild1 into the wider world — Mountains, Valley, Forest. Each direction leads to a new town and a new set of quests with the same density of NPC interconnections.
