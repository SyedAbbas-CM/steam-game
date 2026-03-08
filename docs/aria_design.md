# Aria Region — Combined Geography & Quest Design

## Current State

Aria and its neighbors as they exist right now:

```
                         WILD1 (50x50, hostile)
                         Thieves + Wild Dogs
                         "Endless Caverns" 5-floor dungeon
                        /        |         \
                  FOR1       (blocked)      VLY1
                             GUARD < Lvl 6
                               |
                             ARIA (25x25)
                          4 buildings, 8 NPCs
                          /                \
                   GRAVEYARD (20x30)     FARM (25x25)
                   Skeletons 20%        Sheep/Cows
                   Crypt 3 floors       Farm dungeon 6 floors
                                        Dafydd, Blaidd, Plentyn, Mabion

        CAMP (20x20, dead end off Wild1)
        Ryu the trainer
```

**Problems:**
- Only 1 route north (through the guard) — bottleneck
- Camp is weirdly placed (off Wild1, no connection to Aria's area)
- Farm and Graveyard are dead ends with no reason to revisit
- All existing quest dialogue text is missing from .tres files (import bug — text="" everywhere)
- Quests are disconnected errands with no story thread

---

## Redesigned Geography

```
                         WILD1 (50x50, hostile)
                         Thieves + Wild Dogs
                         "Endless Caverns" dungeon
                        /    |         \          \
                  FOR1   (guard)      VLY1       MNT1
                           |
                      WATCHTOWER (new, 15x15)
                      Bandits → clearable outpost
                      /              \
                   FARM (25x25)      WILD1 (alternate south entrance)
                   Crops, animals
                   Farm dungeon
                      |
                   ARIA (25x25)
                   Home base
                   /          \
          GRAVEYARD (20x30)   RIVERSIDE (new, 20x15)
          Skeletons            Fishing, herbs
          Crypt 3 floors       Safe river path
          (underground tunnel      |
           to Endless Caverns)   CAMP (20x20)
                                 Ryu, training
```

### New Zones

**Watchtower (15x15)**
- Ruined stone tower on a hill between Farm and the Wilderness
- Currently occupied by 4-5 bandits + a Bandit Captain (mini-boss)
- One exit south to Farm, one exit north to Wild1 (southeast corner)
- After clearing: becomes an ownable outpost with garrison slot + lookout function
- Small zone — just the tower, a courtyard, and a broken wall
- Has a collapsed well that hints at underground passages (future content)

**Riverside (20x15)**
- River running east-west with a wooden bridge and a fishing dock
- South of Aria, curving west toward Camp
- One exit north to Aria, one exit west to Camp
- Peaceful zone — no hostile spawns, just river ambiance
- Has reeds along the bank and a small herb garden
- New NPC: **Brenna** the herbalist — lives in a cottage by the river
  - Sells cheap healing herbs (weaker than potions but affordable)
  - Buys fish (gives the fishing pole a purpose)
  - Quest giver for gathering ingredients

### Route Changes

**3 ways from Aria to Wild1:**
1. **North Gate (direct)** — Guard Aldric checks level ≥ 6. Fastest but gated.
2. **Farm Loop** — Aria → east to Farm → north to Watchtower → north to Wild1. Requires clearing the Watchtower bandits first. Bypasses the level gate.
3. **Underground** — Aria → south to Graveyard → Crypt floor 3 → collapsed tunnel → Endless Caverns floor 1 → surface exit in Wild1. Very dangerous. Shortcut for experienced heroes.

**2 ways from Aria to Camp:**
1. **Through Wild1** — Aria → north gate → Wild1 → southwest to Camp. Long and dangerous.
2. **Riverside** — Aria → south-ish → Riverside → west → Camp. Safe. Good for early game.

---

## Existing Quests (With Restored Dialogue)

These are the 4 LoY quests already in the game. The dialogue text was in the original XML but got lost during import. Here's what they should say:

### q1 — "Them Bones" (Level 1)
**Summary:** Kill 20 Skeletons and return to the Elder in Aria

**Start dialogue:**
> **Elder:** "We're having a real problem with the skeletons round here."
> [Oh yes?]
> **Elder:** "There's a large payment for only 20 kills! Will you take the quest?"
> [Sure] → starts quest / [Nay!] → decline

**Progress (return with < 20 kills):**
> **Elder:** "Still hunting Skeletons? Thank you hero!"

**Complete (20+ kills):**
> **Elder:** "Thank you hero, I am very impressed. Here is your reward of 500 gold."
> Reward: 500 gold, 300 XP

### q2 — "Deliver the Goods" (Level 1)
**Summary:** Deliver the package to Yoregot and return to the Elder

**Start dialogue:**
> **Elder:** "I need someone to take this parcel to Yoregot the barman in town, will you help?"
> [Ok]
> **Elder:** "Return here for your reward."
> Receive: Package

**Activate Yoregot:**
> **Yoregot:** "Thank the Elder for the parcel for me."
> Package removed from inventory

**Progress (haven't delivered):**
> **Elder:** "Have you delivered that package yet?"

**Complete:**
> **Elder:** "Thank you hero, that saved me some time!"
> Reward: 500 gold, 400 XP

### q3 — "Pelting Them" (Level 11)
**Summary:** Gather 10 pelts to create a reward

**Start dialogue:**
> **Elder:** "If you gather me 10 pelts, I can make you something special, will you?"
> [Ok]
> **Elder:** "Return here with the pelts."

**Progress (< 10 pelts):**
> **Elder:** "Bring me those pelts young hero!"

**Complete (10+ pelts):**
> **Elder:** "Ah fantastic, give me a moment, there we go, one cloak!"
> Reward: 1000 XP, Pelt Cloak

### a4 — "The Evil Beneath" (Level 8)
**Summary:** Vanquish the Fire Beast at the Farm

**Start dialogue:**
> **Elder:** "The owners of the farm are being terrorized by the Fire Beast."
> [Ok]
> **Elder:** "Will you enter the pit and slay him?"
> [Ok] → starts quest / [No way] → decline

**On first Fire Beast kill:**
> **Elder:** "Well done adventurer. Bring me a piece of wing as proof!"

**Progress (no wing yet):**
> **Elder:** "The farmers are still under threat, will you not help?"

**Complete (have wing):**
> **Elder:** "He will trouble them no more. Well done! Take this."
> Reward: 1000 XP, Head Dress, 500 gold

### Other NPC Dialogue (Existing)

**Guard Aldric (north gate):**
> Level < 6: "You may not pass until you have reached Level 6 whelp!"
> Level ≥ 6: "Good luck in your travels adventurer!" → teleports to Wild1

**Jimbob (wandering):**
> "The dungeons in Yore are crazy, always changing, it's worth visiting them over and over!"

---

## New Quests

These build on the existing 4 quests and use the new geography. Same script format (showDialog, if/set/getItem/etc).

### n1 — "Crypt Secrets" (Level 3, after q1)
**Unlocks after:** completing q1 (Them Bones)
**Summary:** Explore the Aria Crypt beneath the Graveyard and report what you find.

**Start dialogue:**
> **Elder:** "You've done well with the skeletons above ground. But they keep coming. Something in the old crypt beneath the graveyard is raising them."
> [What crypt?]
> **Elder:** "There's a burial vault under the graveyard. It was sealed long ago. The entrance has cracked open. I need someone to go down there and find out what's happening."
> [I'll check it out] → starts quest / [Not yet] → decline

**Event: Enter Aria-Crypt floor 3 (zone trigger):**
> *Player discovers a cracked wall with claw marks coming from BELOW — something dug up, not down.*

**Return to Elder:**
> **Elder:** "Claw marks from below? That's... troubling. The crypt was built over older ruins. Much older. Whatever broke through isn't from our time."
> [What do we do?]
> **Elder:** "For now, we've slowed the skeletons. But this isn't over. Something deeper is stirring. Stay sharp, hero."
> Reward: 600 gold, 500 XP, unlocks quest n3

**Purpose:** Gives the graveyard a reason to revisit. Introduces the underground mystery. Teaches the player the crypt dungeon exists.

---

### n2 — "Dafydd's Plea" (Level 5, after a4)
**Unlocks after:** completing a4 (The Evil Beneath)
**Summary:** Dafydd at the farm needs help establishing a supply line to Aria.

**Start — Talk to Dafydd at Farm:**
> **Dafydd:** "Hero! The fire beasts are gone thanks to you. But the farm's in rough shape. Half the south field is scorched, two sheep dead."
> [How can I help?]
> **Dafydd:** "We used to send supplies to Aria every week — grain, milk, wool. But the road's gotten dangerous. Wild dogs from the east, and now bandits camping near that old watchtower up north."
> [I'll clear the road]
> **Dafydd:** "If you could deal with those bandits at the watchtower, we could get supplies moving again. And take this grain sack to the Elder as proof we're still here."
> Receive: Grain Sack

**Event: Deliver Grain Sack to Elder (activate in Aria):**
> **Elder:** "Grain from Dafydd? Thank the stars, we were running low. But bandits at the watchtower... that's the old kingdom outpost. If we could reclaim it, we'd have a proper lookout for the whole valley."
> [I'll handle it]
> **Elder:** "Clear the watchtower, then report to both me and Dafydd. We'll get this supply line running properly."

**Event: Kill Bandit Captain in Watchtower zone:**
> *Bandit Captain drops "Watchtower Key"*

**Event: Return to Elder:**
> **Elder:** "The watchtower is ours? That changes everything. We can see trouble coming from leagues away now. And Dafydd can send his carts safely."
> [What about the farm?]
> **Elder:** "Go tell Dafydd the road is clear. He's been waiting for this."

**Event: Return to Dafydd:**
> **Dafydd:** "The watchtower's clear? Ha! First good news in months. I'll start sending supplies to Aria straight away. And here — you've earned this."
> Reward: 800 gold, 700 XP, farm supply line active (Aria gains passive food income)

**Purpose:** Connects Farm → Watchtower → Aria. Introduces the supply line concept. Gives the player ownership of the Watchtower as a forward outpost. Bounces between two NPCs.

---

### n3 — "The Endless Dark" (Level 6, after n1)
**Unlocks after:** completing n1 (Crypt Secrets)
**Summary:** Jimbob tells you about treasures in the Endless Caverns. The Elder wants you to investigate the tunnels.

**Start — Jimbob approaches you in Aria (scripted encounter after n1 complete):**
> **Jimbob:** "Hey! I heard you went into the crypt. Crazy stuff down there, right? Listen, I've been poking around the Wilderness and found this massive cave — the Endless Caverns they call it."
> [What about it?]
> **Jimbob:** "Nobody goes down there anymore. Too dangerous. But I saw fresh claw marks near the entrance. Same kind you described from the crypt. What if they're connected?"
> [I'll check it out] → starts quest / [Maybe later] → decline

**Event: Reach Endless Caverns floor 3 (zone trigger):**
> *Player finds a collapsed tunnel on floor 3. Rubble and bones. On the far wall, scratched into the stone: an old kingdom symbol — the same one on the memorial in the graveyard.*

**Event: Return to Elder:**
> **Elder:** "The kingdom symbol? In the caverns? That's... our founders built Aria above those tunnels on purpose. They were guarding something."
> [Guarding what?]
> **Elder:** "I don't know. The records were lost generations ago. But if whatever they sealed is breaking free... we need to be stronger than we are now. Much stronger."
> [What do you suggest?]
> **Elder:** "There's a man at the old training camp south of the wilderness. Ryu. He served in the kingdom's last army. If anyone knows what we're dealing with, he might. Take the riverside path — it's safer than going through the wild."
> Reward: 500 XP, unlocks Riverside zone, unlocks quest n4

**Purpose:** Connects the crypt mystery to the Endless Caverns. Introduces Jimbob as a useful NPC (not just flavor text). Points the player toward Camp via the Riverside route.

---

### n4 — "The Old Soldier" (Level 7, after n3)
**Unlocks after:** completing n3 (The Endless Dark)
**Summary:** Find Ryu at the Training Camp and learn what the old kingdom was guarding.

**Start — Talk to Ryu at Camp:**
> **Ryu:** "The Elder sent you? Hm. Haven't heard from Aria in years. Figured they'd forgotten about this place."
> [He said you served in the old army]
> **Ryu:** "I served. Last company, last stand. The kingdom didn't fall to any enemy — it collapsed from within. Corruption in the deep mines. Something down there twisted people. Turned them violent. The king sealed the tunnels and disbanded the army."
> [The tunnels are opening again]
> **Ryu:** "...Then it's starting over. The crypt, the fire beasts at the farm, the caverns — those are just the edges. Whatever's below is pushing things up."
> [What do we do?]
> **Ryu:** "You can't fight what's below. Not yet. Not alone. But you CAN protect what's above. Build a garrison. Train fighters. Make Aria strong enough to hold when things get worse."
> [Will you help?]
> **Ryu:** "I've been sitting here training nobody for ten years. Give me something to fight for. Yeah. I'll help."
> Reward: 600 gold, 800 XP, Ryu joins as first militia unit, unlocks troop recruitment at owned towns

**Purpose:** Gives Ryu a backstory and purpose. Explains WHY monsters are appearing (the deep corruption). Introduces the troop system. Creates the transition from "adventurer doing errands" to "lord building defenses."

---

### n5 — "River Remedy" (Level 4, standalone)
**Unlocks after:** Riverside zone accessible
**Summary:** Brenna the herbalist needs ingredients from the crypt and wild.

**Start — Talk to Brenna at Riverside:**
> **Brenna:** "Ah, a traveler! You look like you've seen some fighting. I make remedies from the herbs along this river, but I'm running low on the good stuff."
> [What do you need?]
> **Brenna:** "Ghostcap mushrooms — they only grow in dark, dead places. The crypt south of Aria would have them. Bring me 5 and I'll brew you something that'll make the undead think twice about biting you."
> [I'll find them] → starts quest / [Not now] → decline

**Event: Kill skeletons in Aria-Crypt (5 kills with quest active → auto-collect Ghostcap Mushroom):**
> Each skeleton kill has 60% chance to drop Ghostcap Mushroom (they grow near the dead)

**Event: Return to Brenna with 5 Ghostcaps:**
> **Brenna:** "Perfect! These are beauties. Right, let me work my magic... there. Undead Ward potion. Drink it before going into that crypt and the skeletons will hit you half as hard."
> [Anything else you need?]
> **Brenna:** "Actually... I've been meaning to set up a proper herb garden but I can't get fresh soil. The river mud's too silty. If you ever find good earth from the farm, bring me a sackful."
> Reward: 3x Undead Ward potion, 400 XP, Brenna's shop unlocks (cheap herbs + potions)

**Purpose:** Gives Riverside a function. Creates a reason to revisit the crypt. Introduces crafting-adjacent NPC. Hints at a follow-up involving the Farm (soil). Bounces between zones.

---

### n6 — "Dog Catcher" (Level 9, after Watchtower cleared)
**Unlocks after:** completing n2 (Dafydd's Plea / Watchtower clear)
**Summary:** Mabion wants you to capture a wild dog alive for breeding.

**Start — Talk to Mabion at Farm:**
> **Mabion:** "You're the one who cleared the watchtower? Good. I've got a job that needs someone who can handle themselves out in the wild."
> [What is it?]
> **Mabion:** "Wild dogs. They're all over the wilderness — mean as anything. But they're also fast, loyal, and smart if you raise them right. I want to breed war dogs for Aria's defense."
> [You want me to catch one?]
> **Mabion:** "Alive, yes. Buy a net from Yoregot at the inn — he's got them. Then find a wild dog in the wilderness, weaken it, and use the net. Bring it back and I'll do the rest."
> [I'll try it] → starts quest

**Mechanic: Buy "Capture Net" from Yoregot (new shop item, 100 gold)**
**Mechanic: In Wild1, get a Wild Dog below 25% HP → use Capture Net item → "Captured Wild Dog" added to inventory**

**Event: Return to Mabion with Captured Wild Dog:**
> **Mabion:** "Ha! Look at him! Snarling now, but give me a week and he'll be eating from your hand. Two weeks and he'll tear a bandit's throat out on command."
> [War dogs for Aria?]
> **Mabion:** "War dogs for Aria. These beasts are worth three militia in a fight. I'll start a breeding program — but I'll need more dogs eventually. One's just a start."
> Reward: 800 XP, 500 gold, unlocks War Dog troop type at Farm

**Purpose:** Uses an existing NPC (Mabion at Farm) and existing enemy (Wild Dog in Wild1). Creates a loop: buy net from Yoregot → hunt in Wild1 → deliver to Mabion. Introduces a new troop type tied to a specific zone.

---

### n7 — "Yoregot's Vintage" (Level 5, standalone)
**Unlocks after:** q2 complete (Deliver the Goods)
**Summary:** Yoregot wants rare fish from the Riverside for a special brew.

**Start — Talk to Yoregot at Crooked Beak:**
> **Yoregot:** "Hey hero! Glad you came back. Listen, I've been trying to brew a special ale — something that'll put the Crooked Beak on the map. But I need Silverscale fish."
> [Where do I find those?]
> **Yoregot:** "There's a river south of town. Old Brenna lives down there — she knows the fishing spots. Buy a fishing pole from me if you haven't got one, and catch me 3 Silverscale."
> [I'll go fishing] → starts quest / [Not my thing] → decline

**Mechanic: At Riverside, use Fishing Pole on river tiles → chance to catch Silverscale (30%) or Common Fish (70%)**

**Event: Return to Yoregot with 3 Silverscale:**
> **Yoregot:** "Three beauties! Right, give me a moment..."
> *Yoregot brews behind the bar*
> **Yoregot:** "Silverscale Stout! One sip and you'll fight like a bear. Here, have the first batch — on the house. And I'll keep a barrel on tap for you."
> Reward: 3x Silverscale Stout (temporary attack buff), 400 gold, 500 XP, Silverscale Stout permanently available in Yoregot's shop

**Purpose:** Gives the fishing pole a gameplay reason. Connects Yoregot → Riverside → Brenna's area. Adds a useful consumable to the shop. Light, fun quest between the heavier story ones.

---

### n8 — "Morin's Research" (Level 6, standalone)
**Unlocks after:** Crypt accessible
**Summary:** Morin at the Shrowded Orb needs arcane materials from the crypt.

**Start — Talk to Morin at Shrowded Orb:**
> **Morin:** "Hero, I sense... something. The leylines beneath Aria are shifting. The magic that flows through the earth is agitated."
> [Leylines?]
> **Morin:** "Invisible currents of power that run beneath the world. Aria was built on a nexus — a crossing point. That's why the town has thrived for so long. But something is disrupting the flow."
> [What can I do?]
> **Morin:** "I need Bone Dust from the crypt. The dead absorb leyline energy — their bones resonate with it. Bring me 8 handfuls and I can trace the disruption."
> [I'll get it] → starts quest

**Event: Kill skeletons in Aria-Crypt (each kill → 50% chance to drop Bone Dust)**

**Event: Return to Morin with 8 Bone Dust:**
> **Morin:** "Yes... yes, I can feel it. The disruption is coming from deep below — far deeper than the crypt. The same direction as those tunnels you found."
> [Can you do anything about it?]
> **Morin:** "Not stop it. But I can use this dust to enchant your equipment. The leyline energy is chaotic but powerful. Come to me when you want a weapon or armor enhanced."
> Reward: 600 XP, 300 gold, unlocks Morin's enchanting service (pay gold + materials to add stat bonuses to equipment)

**Purpose:** Gives Morin a gameplay function beyond selling potions. Connects to the underground mystery through a different angle (magical rather than physical). Creates a use for crypt farming.

---

### n9 — "Arnie's Forge" (Level 10, after q3)
**Unlocks after:** completing q3 (Pelting Them)
**Summary:** Arnie needs ore from the Farm dungeon to forge better gear.

**Start — Talk to Arnie at the weapon shop:**
> **Arnie:** "That cloak I made from the pelts — not bad, eh? But I could do much better if I had proper materials."
> [What do you need?]
> **Arnie:** "Iron ore. Real iron, not the rubbish they sell on the road. The old mine tunnels under the farm go deep — used to be a proper mining operation before the kingdom fell. Bring me 10 chunks of raw iron and I'll forge you something worth fighting with."
> [Where in the mine?]
> **Arnie:** "Floors 4 and below in the farm dungeon. The ore veins are in the walls — you'll see them glinting. Smash the deposits and collect what falls out."
> [I'll dig it up] → starts quest

**Mechanic: In Farm dungeon floors 4-6, destructible ore deposits appear in some rooms. Hit them → Iron Ore drop.**

**Event: Return to Arnie with 10 Iron Ore:**
> **Arnie:** "Now THAT'S what I'm talking about! Good quality too. Right, stand back..."
> *Hammering sounds from the forge*
> **Arnie:** "Iron Longsword. Stronger than anything I've had in stock for years. And there's more where that came from — keep bringing ore and I'll keep forging."
> Reward: Iron Longsword (better than shop weapons), 1000 XP, Arnie unlocks forging service (trade ore → custom weapons/armor)

**Purpose:** Gives the Farm dungeon a reason to revisit past floor 3. Creates a crafting loop (mine ore → Arnie forges). Upgrades Arnie from static shopkeeper to active craftsman.

---

### n10 — "Blaidd's Lost Explorer" (Level 8, standalone)
**Unlocks after:** Wild1 accessible
**Summary:** Blaidd's cartographer friend went missing in the Wilderness.

**Start — Talk to Blaidd at Farm:**
> **Blaidd:** "Hero, I need a favor. A colleague of mine — Tomas — went into the Wilderness three weeks ago to map the eastern forest. He hasn't come back."
> [You want me to find him?]
> **Blaidd:** "Find him or find his notes. Tomas always carried a leather satchel with his maps. If he's dead... at least bring back his work. He was headed toward the thief camp in the east woods."
> [I'll look for him] → starts quest

**Event: In Wild1 east side (near thief camp), find "Tomas's Satchel" on the ground (item pickup):**
> *The satchel is torn and bloodstained. Inside: detailed maps of the eastern Wilderness, notes about thief movements, and a half-finished sketch of something underground — a massive carved doorway.*

**Event: Return to Blaidd:**
> **Blaidd:** "His satchel... but not him. Damn. He was a good man."
> [His maps are incredible]
> **Blaidd:** "That's Tomas for you. Thorough to the end. Wait — what's this sketch? A carved doorway? Underground? I've never seen anything like that on any map."
> [It was near the thief camp]
> **Blaidd:** "The thieves must be using it as a hideout. Whatever that doorway leads to... it's old. Very old. Here — let me copy Tomas's maps for you. You've earned them."
> Reward: 600 XP, 400 gold, Wild1 map fully revealed, hints at deeper content beneath the thief camp

**Purpose:** Gives Blaidd a role beyond selling maps. Creates a reason to explore Wild1's east side. Plants a hook for the thief camp raid. Foreshadows underground ruins.

---

## Quest Flow Diagram

```
Level 1:
  q1 "Them Bones" (kill 20 skeletons) ←── EXISTING
  q2 "Deliver the Goods" (package to Yoregot) ←── EXISTING
    │
    └──→ n7 "Yoregot's Vintage" (catch fish at Riverside)

Level 3-5:
  n1 "Crypt Secrets" (explore crypt floor 3) ←── requires q1
    │
    └──→ n3 "The Endless Dark" (explore Endless Caverns)
           │
           └──→ n4 "The Old Soldier" (find Ryu at Camp → get first troop)

  n5 "River Remedy" (mushrooms for Brenna at Riverside) ←── standalone

Level 5-8:
  a4 "The Evil Beneath" (fire beasts at Farm) ←── EXISTING
    │
    └──→ n2 "Dafydd's Plea" (deliver grain + clear Watchtower)
           │
           └──→ n6 "Dog Catcher" (capture wild dog for Mabion)

  n8 "Morin's Research" (bone dust from crypt → unlocks enchanting)

Level 8-11:
  n10 "Blaidd's Lost Explorer" (find satchel in Wild1)

  q3 "Pelting Them" (10 dog pelts) ←── EXISTING
    │
    └──→ n9 "Arnie's Forge" (iron ore from Farm dungeon → unlocks forging)
```

### NPC Quest Assignments

| NPC | Location | Quests Given | Quests Involved In |
|-----|----------|-------------|-------------------|
| **Elder** | Aria Town Hall | q1, q2, q3, a4, n1, n3 | n2 (receives grain) |
| **Yoregot** | Crooked Beak Inn | n7 | q2 (receives package), n6 (sells nets) |
| **Arnie** | Weapons Shop | n9 | q3 (makes Pelt Cloak) |
| **Morin** | Shrowded Orb | n8 | — |
| **Dafydd** | Farm | n2 | a4 (context) |
| **Mabion** | Farm | n6 | — |
| **Blaidd** | Farm | n10 | — |
| **Jimbob** | Aria (wandering) | — | n3 (triggers quest) |
| **Ryu** | Camp | — | n4 (provides troops) |
| **Brenna** | Riverside (NEW) | n5 | n7 (mentioned) |
| **Guard Aldric** | Aria north gate | — | n2 (gate opens alternate route) |
| **Plentyn** | Farm (kid) | — | a4 (flavor dialogue) |

---

## Elder Dialogue — Full NPC Script

The Elder should have context-aware dialogue when you talk to him. Not just quest popups — he should comment on the state of the world.

### Base Dialogue (No Active Quest)

**Before any quests:**
> "Welcome to Aria, traveler. It's not much, but it's home. We've been having some troubles lately — nothing a strong arm couldn't help with."

**After q1 complete:**
> "The graveyard is quieter thanks to you. But I worry it won't last."

**After q1 + a4 complete:**
> "The skeletons calmed, the fire beasts driven off... you've done more for this town than anyone in years. But I fear these are symptoms, not the disease."

**After n1 complete (crypt explored):**
> "What you found in the crypt keeps me up at night. Claw marks from below... this town was built to guard something. I just wish I knew what."

**After n2 complete (Watchtower cleared):**
> "The watchtower flies our banner again! And Dafydd's carts are rolling. Aria hasn't been this strong since I was a boy. Maybe there's hope yet."

**After n4 complete (Ryu recruited):**
> "Ryu's with us. A real soldier for the first time in a generation. If we can build a proper garrison, we might actually survive what's coming."

**After all Aria quests complete:**
> "You've transformed this town, hero. From a forgotten hamlet to something that might — just might — endure. The road ahead is longer than the road behind, but for the first time, I believe we can walk it."

### Quest Offer Logic

When the player talks to the Elder, he should offer the **highest priority available quest** based on what's completed:

1. If no quests done → offer q1
2. If q1 done, q2 not done → offer q2
3. If q1 done → offer n1 (Crypt Secrets)
4. If a4 done → offer n2 (Dafydd's Plea)
5. If n1 done → offer n3 (The Endless Dark)
6. If q2 done, level ≥ 8 → offer a4
7. If n3 done → offer n4 (The Old Soldier) — but points to Ryu, not Elder
8. If level ≥ 11, q3 not done → offer q3

Multiple quests can be active at once. The Elder mentions the most urgent one first but can list others if asked.

---

## What Unlocks What

| Complete This | Unlocks |
|--------------|---------|
| q1 (Them Bones) | Quest n1, Graveyard skeleton spawn reduced |
| q2 (Deliver the Goods) | Quest n7, Yoregot mentions wider world |
| n1 (Crypt Secrets) | Quest n3, underground mystery begins |
| a4 (Evil Beneath) | Quest n2, Farm dungeon stays open for revisit |
| n2 (Dafydd's Plea) | Watchtower outpost, Farm supply line, quest n6 |
| n3 (Endless Dark) | Quest n4, Riverside zone revealed |
| n4 (Old Soldier) | Troop recruitment, garrison system, militia units |
| n5 (River Remedy) | Brenna's shop, Undead Ward potions |
| n6 (Dog Catcher) | War Dog troop type at Farm |
| n7 (Yoregot's Vintage) | Silverscale Stout in shop, fishing has purpose |
| n8 (Morin's Research) | Enchanting service at Shrowded Orb |
| n9 (Arnie's Forge) | Forging service, custom weapons from ore |
| n10 (Blaidd's Explorer) | Wild1 map revealed, thief camp plot hook |
| q3 (Pelting Them) | Quest n9, Pelt Cloak in Arnie's shop |
| ALL Aria quests done | Elder offers lordship of Aria, kingdom phase begins |

---

## Beyond Aria (What's Next)

When the player has:
- Cleared all Aria quests
- Owns the Watchtower
- Has 5+ troops garrisoned
- Has supply lines from Farm

The Elder offers the **transition quest:**

> "Hero — no. My Lord. That's what you are now, whether you like it or not. Aria lives because of you. The watchtower stands, the farm supplies us, the crypt is contained. But we're still one town in a hostile world."
> [What do you propose?]
> "The wilderness beyond our walls is full of threats — but also opportunities. Other towns are out there, struggling like we were. If we could reach them, trade with them, protect them..."
> [An alliance?]
> "Or more. A kingdom. The old one fell, but maybe a new one could rise. Starting here. Starting with you. But first — you need to tame the Wilderness."

**Next quest chain: Wild1 expansion** — clear the south road, raid the thief camp, build a trade post at the crossroads. Then push outward: Mountains → Dondheim → the treaty. Valley → S'thel → the desert. Forest → Gomb → the coast.

Each direction is a new region with its own Elder, its own quests, its own problems, and its own faction to ally or conquer. But that's the next document.
