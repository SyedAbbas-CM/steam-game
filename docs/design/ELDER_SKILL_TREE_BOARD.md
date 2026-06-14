# Elder Skill Tree Board

Date: 2026-06-11

## Goal

Create one working design board for elder or town-leader skill trees so ideas can be reviewed, accepted, rejected, or held before implementation.

This document is intentionally split into:
- `Concept Phase`
- `Implementation Phase`

Use this as the source of truth instead of scattered chat notes.

## Review Rules

For each concept, mark one:
- `[ ] Accept`
- `[ ] Reject`
- `[ ] Hold`

If accepted, move it into the implementation queue section with:
- target phase
- gameplay owner
- files likely affected

## Existing System Reality

The current codebase already supports:
- perk resources with prerequisites and class requirements in [perk_definition.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/stats/perk_definition.gd)
- perk unlock/query logic in [perk_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/stats/perk_manager.gd)
- class bars in [player.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/player.gd)
- item stat aggregation in [equipment_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/stats/equipment_manager.gd)
- item ability and spell metadata in [equipment_item.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/stats/equipment_item.gd)

The main missing long-term piece is a cleaner gameplay-modifier layer for:
- parry variables
- dash variables
- class-meter gain/decay/spend variables
- spell magnitude/radius/duration variables

## Design Direction

Elders or town leaders should not just sell flat stat bumps.

They should offer:
- class doctrine choices
- combat identity upgrades
- item-ability synergies
- class-bar shaping perks
- region-flavored schools of combat

The best model is:
1. classes have base combat identities
2. elders teach branches that mutate those identities
3. perks unlock behavior
4. stats and gear scale the unlocked behavior

## Concept Phase

### A. Structure Of Elder Trees

#### A1. One elder per town gives a regional mini-tree
- [ ] Accept
- [ ] Reject
- [ ] Hold

Concept:
- each major town elder teaches a themed branch
- these are not all class-locked
- example:
  - Ravenholme elder teaches fear, precision parry, cursed defense
  - Haven elder teaches fundamentals, survivability, utility
  - frontier elder teaches mobility, dash combat, skirmishing

Why this is strong:
- towns gain identity
- progression ties into world exploration
- you can spread build-defining choices across the map

Risk:
- if every town adds a full tree, scope explodes fast

Recommendation:
- start with one small branch per elder, not giant talent webs

#### A2. Each elder offers one branch per class
- [ ] Accept
- [ ] Reject
- [ ] Hold

Concept:
- the same elder has different teachings depending on class

Why this is strong:
- strong replay value
- class fantasy stays intact

Risk:
- content multiplication is severe

Recommendation:
- do not start here
- use class-agnostic or 2-class hybrid branches first

#### A3. Elders teach combat schools, not class trees
- [ ] Accept
- [ ] Reject
- [ ] Hold

Concept:
- examples:
  - Bulwark School
  - Duelist School
  - Hunter School
  - Blood School
  - Arcane Pressure School
- any class can dip in, but some schools synergize better with certain classes

Why this is strong:
- more build variety
- easier to scale than fully separate class trees

Risk:
- class identity can get muddy if schools overlap too much

Recommendation:
- very strong long-term model

### B. Parry Tree Concepts

#### B1. Precision Parry branch
- [ ] Accept
- [ ] Reject
- [ ] Hold

Effects:
- larger perfect-parry window
- faster shield turn speed
- better reflect crit
- stronger reflect direction control
- late-parry leniency

Good for:
- mercenary
- ranger dagger play
- technical shield players

#### B2. Momentum Parry branch
- [ ] Accept
- [ ] Reject
- [ ] Hold

Effects:
- reflected projectile speed scales harder with movement
- dash-parry gets bonus projectile speed
- successful parries grant short haste
- parry grants more class meter if moving fast

Good for:
- mercenary
- aggressive skirmish builds

#### B3. Control Parry branch
- [ ] Accept
- [ ] Reject
- [ ] Hold

Effects:
- reflected shots stun longer
- reflected shots can pierce or chain
- parrying melee/direct attacks always spawns a return projectile
- perfect parry weakens enemies briefly

Good for:
- crowd control builds
- dungeon-heavy play

#### B4. Behind-the-back deflect perk
- [ ] Accept
- [ ] Reject
- [ ] Hold

Concept:
- unlock a perk that lets parry catch attacks outside the normal front cone

Recommendation:
- keep this as a later special perk, not baseline

#### B5. Reflect damage scaling perks
- [ ] Accept
- [ ] Reject
- [ ] Hold

Variables:
- reflect damage multiplier
- reflect crit chance
- reflect crit damage
- reflect speed floor
- reflect stun duration

Recommendation:
- this is exactly the kind of thing that should be numeric perk scaling

### C. Dash Tree Concepts

#### C1. Long dash branch
- [ ] Accept
- [ ] Reject
- [ ] Hold

Effects:
- more dash duration
- more dash distance
- less dash cooldown
- more lingering i-frames

Risk:
- can break map traversal and dodge trivialization

Recommendation:
- safe only with strict caps

#### C2. Violent dash branch
- [ ] Accept
- [ ] Reject
- [ ] Hold

Effects:
- dash impact damage
- boss damage multiplier
- end-of-dash shockwave
- bleed or burn on dash hit

Good for:
- warrior
- mercenary

#### C3. Phantom dash branch
- [ ] Accept
- [ ] Reject
- [ ] Hold

Effects:
- stealth on dash
- phase through enemy bullets
- afterimage clone
- leave void or poison trail

Good for:
- rogue-adjacent mercenary
- wizard mobility builds

#### C4. Resource-efficient dash branch
- [ ] Accept
- [ ] Reject
- [ ] Hold

Effects:
- lower stamina cost
- lower MP cost
- class-bar refund on near-miss or hit
- extra cooldown refund if used precisely

Recommendation:
- strong candidate for early implementation

### D. Class Bar Concepts

#### D1. Bars should have threshold gameplay, not just full-bar payoff
- [ ] Accept
- [ ] Reject
- [ ] Hold

Concept:
- 25 / 50 / 75 / 100 thresholds alter play even before the burst move

Recommendation:
- mandatory long-term direction

#### D2. Warrior rage thresholds
- [ ] Accept
- [ ] Reject
- [ ] Hold

Examples:
- 25: stronger dash burst
- 50: heavier shield response
- 75: spell fuel discount
- 100: Blood Dream ready

#### D3. Mercenary adrenaline thresholds
- [ ] Accept
- [ ] Reject
- [ ] Hold

Examples:
- 25: crit chance bump
- 50: fire-rate bump
- 75: parry reflect pierce
- 100: Reckless Strike ready

#### D4. Archer focus thresholds
- [ ] Accept
- [ ] Reject
- [ ] Hold

Examples:
- 25: range up
- 50: projectile speed up
- 75: lock-on quality improves
- 100: Killshot ready

#### D5. Wizard mana flow thresholds
- [ ] Accept
- [ ] Reject
- [ ] Hold

Examples:
- 25: spell cooldown reduction
- 50: cheaper movement magic
- 75: empowerment discount
- 100: Overflow ready

#### D6. Perks that reshape bar gain/decay/spend
- [ ] Accept
- [ ] Reject
- [ ] Hold

Examples:
- more gain from crits
- slower decay
- longer grace before decay
- cheaper class burst activation
- leftover meter after burst ends

Recommendation:
- this is one of the highest-value progression categories in the game

### E. Item + Ability Concepts

#### E1. Gear affixes that scale parry and dash directly
- [ ] Accept
- [ ] Reject
- [ ] Hold

Examples:
- `+parry window`
- `+reflect speed`
- `-dash cooldown`
- `+dash impact damage`
- `+meter gain on parry`

Recommendation:
- strong
- requires a gameplay-modifier layer first

#### E2. Gear that modifies class bars
- [ ] Accept
- [ ] Reject
- [ ] Hold

Examples:
- `+rage gain`
- `-adrenaline decay`
- `+focus regen while stationary`
- `+mana flow from kills`

Recommendation:
- very strong for buildcraft

#### E3. Spell-granting weapons should also scale spell behavior
- [ ] Accept
- [ ] Reject
- [ ] Hold

Examples:
- tome increases AoE
- staff improves empowered version
- wand lowers mana flow threshold for special spells

Recommendation:
- strong wizard identity path

#### E4. Item active abilities become authoritative instead of mostly cosmetic data
- [ ] Accept
- [ ] Reject
- [ ] Hold

Concept:
- `ability_id` on items becomes a real dispatcher path
- items can own active behaviors cleanly

Recommendation:
- high value
- but larger systems refactor

### F. Elder/Town Progression Concepts

#### F1. Elders require questline trust before teaching advanced nodes
- [ ] Accept
- [ ] Reject
- [ ] Hold

Concept:
- do quests for town
- unlock better teachings

Why it works:
- progression tied to world
- better motivation than raw gold gates

#### F2. Elders consume special currencies, not just perk tokens
- [ ] Accept
- [ ] Reject
- [ ] Hold

Examples:
- reputation
- relic fragments
- war favors
- boss trophies

Risk:
- too many currencies can bloat the game

Recommendation:
- use very sparingly

#### F3. Some elder teachings are mutually exclusive
- [ ] Accept
- [ ] Reject
- [ ] Hold

Examples:
- long dash vs violent dash
- strict precision parry vs omnidirectional reactive parry

Why it is good:
- creates real build identity

Risk:
- respec pressure and player regret

Recommendation:
- good later, not first implementation phase

### G. Hybrid School Concepts

#### G1. Elders offer hybrid schools that bridge two classes
- [ ] Accept
- [ ] Reject
- [ ] Hold

Examples:
- Mercenary + Ranger: Skirmisher school
- Warrior + Mercenary: Duelist school
- Wizard + Ranger: Spellshot school
- Warrior + Wizard: Battlemage shield school

Why this is strong:
- supports replayability without needing full separate class trees
- lets off-class weapons and builds feel intentional instead of accidental

Risk:
- can blur class identity if hybrids are stronger than core class trees

Recommendation:
- strong mid-term idea after core class branches work

#### G2. Elders teach doctrine swaps instead of pure upgrades
- [ ] Accept
- [ ] Reject
- [ ] Hold

Examples:
- mercenary adrenaline becomes a defensive meter instead of crit/fire-rate meter
- wizard mana flow becomes an overheat-style instability meter
- ranger focus becomes marksmanship charges instead of a smooth bar

Why this is interesting:
- radically changes repeat playthrough feel

Risk:
- very high complexity
- requires alternate UI and balancing

Recommendation:
- late-game or expansion idea, not early implementation

### H. Spell And Magic Tree Concepts

#### H1. Elders offer spell-shaping schools
- [ ] Accept
- [ ] Reject
- [ ] Hold

Examples:
- larger AoE but slower cast
- faster cast but weaker empowered form
- stronger status durations
- chain-focused lightning school
- terrain-control fire school

Why this is strong:
- gives wizard progression depth beyond “more damage”

Recommendation:
- high value
- should hook into spell magnitude/radius/duration variables

#### H2. Empowerment specialization nodes
- [ ] Accept
- [ ] Reject
- [ ] Hold

Examples:
- mana flow spends less on utility spells
- empowered frost spells cause brittle/shatter setups
- empowered fire spells leave burning ground
- empowered blink creates a shockwave or decoy

Recommendation:
- strong because it makes mana flow visually and mechanically legible

#### H3. Anti-magic / disruption school
- [ ] Accept
- [ ] Reject
- [ ] Hold

Examples:
- parry can break magical projectiles into shards
- dash through spell zones reduces incoming spell damage
- reflected magical shots silence or weaken casters

Recommendation:
- very strong for bosses and mage enemies

### I. Gear Doctrine Concepts

#### I1. Item archetypes should unlock doctrine bonuses
- [ ] Accept
- [ ] Reject
- [ ] Hold

Concept:
- not just raw affixes
- whole archetype packages like:
  - buckler duelist
  - heavy shield wall
  - spellshot pistol/wand equivalent
  - longbow precision

Why it is strong:
- makes gear sets feel authored
- helps itemization reinforce perk identity

Recommendation:
- strong after the gameplay-modifier layer exists

#### I2. Named relic items that evolve with elder training
- [ ] Accept
- [ ] Reject
- [ ] Hold

Concept:
- specific items gain new passive lines if the matching elder school is learned

Examples:
- buckler gains chain reflect only if control parry school is unlocked
- staff gains cheaper empowered casts only if arcane pressure school is unlocked

Why it is strong:
- makes the world and the build system feel linked

Risk:
- content authoring overhead

Recommendation:
- very strong long-term

#### I3. Bar-linked item affixes
- [ ] Accept
- [ ] Reject
- [ ] Hold

Examples:
- `+dash length while adrenaline > 50`
- `+reflect crit while focus > 75`
- `+spell radius while mana flow > 60`
- `+block arc while rage > 40`

Recommendation:
- excellent late-stage buildcraft layer

### J. Town Identity Concepts

#### J1. Each town should teach a different combat philosophy
- [ ] Accept
- [ ] Reject
- [ ] Hold

Examples:
- Haven: fundamentals, sustain, utility
- Ravenholme/crypt town: fear, curse, parry, attrition
- frontier town: mobility, traps, skirmish
- mountain town: armor, stagger, control
- arcane town: empowerment, blink, anti-magic

Recommendation:
- this is probably the best world-facing structure

#### J2. Town leaders should have opposing teachings
- [ ] Accept
- [ ] Reject
- [ ] Hold

Examples:
- one elder teaches speed and aggression
- another teaches patience and control

Why this is good:
- creates real build decisions

Risk:
- requires respec or visible permanence rules

### K. Review Workflow Concepts

#### K1. Concepts should be promoted into approved implementation tickets inside this file
- [ ] Accept
- [ ] Reject
- [ ] Hold

Concept:
- once accepted, each idea gets:
  - owner
  - target phase
  - rough code hooks
  - balancing concerns

Recommendation:
- should be the default workflow

#### K2. Use `Concept Mode` and `Implementation Mode` labels explicitly
- [ ] Accept
- [ ] Reject
- [ ] Hold

Concept:
- when we are ideating, we only edit this doc
- when we are implementing, we only touch approved items from this doc

Why this is good:
- stops the project from mixing invention and coding every turn

Recommendation:
- strong and practical

## Recommended First Wave

These are the best early candidates.

### First-wave concepts

#### R1. Mercenary parry branch
- [ ] Accept
- [ ] Reject
- [ ] Hold

Scope:
- precision parry
- momentum parry
- control parry

Why:
- current work already exposed the right variables

#### R2. Dash modifier branch
- [ ] Accept
- [ ] Reject
- [ ] Hold

Scope:
- efficient dash
- violent dash
- phantom dash

Why:
- dash is already central to every class

#### R3. Class-bar modifier perks
- [ ] Accept
- [ ] Reject
- [ ] Hold

Scope:
- gain
- decay
- threshold enhancements

Why:
- this deepens every class at once

#### R4. Gear affixes for parry/dash/bar systems
- [ ] Accept
- [ ] Reject
- [ ] Hold

Why:
- buildcraft becomes much richer immediately

#### R5. Town identity layer for the first 2-4 towns
- [ ] Accept
- [ ] Reject
- [ ] Hold

Why:
- makes the elder progression system feel like part of the world instead of a menu stapled onto NPCs

#### R6. Spell-shaping branch for wizard
- [ ] Accept
- [ ] Reject
- [ ] Hold

Why:
- wizard progression becomes much deeper once empowered forms are altered by schools and perks

## Implementation Phase

Do not start implementation from concepts alone. Move accepted concepts here first.

### Phase 1. Gameplay Modifier Layer

Status:
- [ ] Approved
- [ ] Rejected
- [ ] Hold

Goal:
- add a proper query layer for non-basic combat variables

Target systems:
- parry
- dash
- class bars
- spell scaling

Likely files:
- [player.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/player.gd)
- [equipment_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/stats/equipment_manager.gd)
- [perk_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/stats/perk_manager.gd)
- [stat_modifier.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/stats/stat_modifier.gd)

### Phase 2. Mercenary Parry Tree

Status:
- [ ] Approved
- [ ] Rejected
- [ ] Hold

Goal:
- implement a real parry branch with baseline plus perk hooks

Possible perk families:
- Precision
- Momentum
- Control

Likely files:
- [player.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/player.gd)
- [bullet.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/bullet.gd)
- [resources/perks/mercenary](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/resources/perks/mercenary)

### Phase 3. Dash Tree

Status:
- [ ] Approved
- [ ] Rejected
- [ ] Hold

Goal:
- make dash configurable by perks and gear

Likely files:
- [player.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/player.gd)
- [resources/perks/general](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/resources/perks/general)
- [resources/perks/mercenary](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/resources/perks/mercenary)
- [resources/perks/warrior](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/resources/perks/warrior)

### Phase 4. Class-Bar Perk Layer

Status:
- [ ] Approved
- [ ] Rejected
- [ ] Hold

Goal:
- make gain, decay, thresholds, and spend behavior scalable

Likely files:
- [player.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/player.gd)
- [weapon_system.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/weapons/weapon_system.gd)
- [resources/perks/*](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/resources/perks)

### Phase 5. Item Ability/Affix Pass

Status:
- [ ] Approved
- [ ] Rejected
- [ ] Hold

Goal:
- let items and affixes reshape parry, dash, bars, and spell behavior

Likely files:
- [equipment_item.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/stats/equipment_item.gd)
- [equipment_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/stats/equipment_manager.gd)
- [player.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/player.gd)
- [spell_book.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/spell_book.gd)

### Phase 6. Elder/Town Presentation Pass

Status:
- [ ] Approved
- [ ] Rejected
- [ ] Hold

Goal:
- make elders and town leaders present these branches clearly in-world

Likely files:
- town dialogue files
- perk tree UI flow
- elder interaction screens
- quest gating / trust checks

### Phase 7. Hybrid Schools And Relic Synergy

Status:
- [ ] Approved
- [ ] Rejected
- [ ] Hold

Goal:
- add advanced doctrine combinations after the base system is stable

Likely files:
- [player.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/player.gd)
- [perk_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/stats/perk_manager.gd)
- perk resources
- key relic item resources

## Notes

- Baseline correctness is not a perk.
- Perks should enhance stable systems, not repair broken ones.
- Behavior unlocks should use `special_effect` or an equivalent future effect-dispatch model.
- Numeric tuning should move behind getters or a dedicated gameplay-modifier query layer before the tree explodes in size.

## Current Recommendation

If you want the strongest path with the least engineering mess:
1. approve Phase 1 gameplay modifier layer
2. approve the mercenary parry branch
3. approve the dash branch
4. then expand class bars and item-affix systems
