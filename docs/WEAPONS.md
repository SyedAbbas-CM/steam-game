# Weapons Reference

Complete reference for all 22 weapon types in the game. Each weapon type has a unique firing pattern (Spacebar auto-fire), a Spacebar ability (tap Space), and a Shift ability (hold Shift).

## Controls

- **Auto-fire**: Hold aim direction (right stick / mouse) to shoot with the weapon's pattern
- **Spacebar ability**: Tap Space for an instant ability (costs stamina, has cooldown)
- **Shift ability**: Hold Shift to activate a sustained mode (drains stamina/MP per second)
- **Shield**: R key (requires shield item + melee weapon equipped)

## Class Restrictions

Uncommon+ weapons enforce class restrictions:
- **Warrior / Mercenary**: sword, axe, hammer, club, flail, spear, halberd
- **Archer / Mercenary**: bow, crossbow, short_bow, dagger, javelin, sling, throwing
- **Wizard**: staff, wand, tome

Custom weapons (greatsword, great_axe, whip, scythe, claws) have no default class restriction.

## Overview Table

| # | Type | Slot | Pattern | Spacebar Ability | Shift Ability | Scaling Stat |
|---|------|------|---------|------------------|---------------|--------------|
| 1 | sword | Melee | SpreadPattern | Dash (25 stam, 0.3s cd) | Blade Dance (30/s stam) | power |
| 2 | dagger | Melee | BurstPattern | Dash (25 stam, 0.3s cd) | Shadow Step (45/s stam + 4/s MP) | power |
| 3 | axe | Melee | ShotgunPattern | Dash + Cleave (25 stam, 0.3s cd) | Whirlwind (45/s stam) | power |
| 4 | hammer | Melee | MeteorPattern | Hammer Throw (20 stam, 2.0s cd) | Earthquake (35/s stam) | power |
| 5 | club | Melee | SpreadPattern | Ground Pound (25 stam, 1.0s cd) | Berserk Swing (25/s stam) | power |
| 6 | flail | Melee | BoomerangPattern | Chain Lash (20 stam, 1.2s cd) | Whip Spin (25/s stam) | power |
| 7 | spear | Melee | TridentPattern | Lunge (25 stam, 0.7s cd) | Phalanx Stance (20/s stam) | power |
| 8 | javelin | Melee | TridentPattern | Javelin Throw (20 stam, 1.2s cd) | Rain of Javelins (30/s stam) | agility |
| 9 | halberd | Melee | TridentPattern | Halberd Sweep (25 stam, 1.0s cd) | Guard Stance (15/s stam) | power |
| 10 | throwing | Melee | ScatterPattern | Fan of Knives (15 stam, 1.0s cd) | Barrage (20 stam, 2.0s cd) | agility |
| 11 | short_bow | Ranged | SpreadPattern | Evasive Shot (15 stam, 0.8s cd) | Rapid Fire (20/s stam) | agility |
| 12 | bow | Ranged | ParallelPattern | Dash / Longshot* (25/15 stam) | Multishot (25/s stam + 5/s MP) | agility |
| 13 | crossbow | Ranged | RailgunPattern | Power Shot (20 stam, 1.5s cd) | Aimed Mode (15/s stam) | agility |
| 14 | sling | Ranged | ScatterPattern | Scatter Volley (20 stam, 1.0s cd) | Rapid Sling (25/s stam) | agility |
| 15 | staff | Magic | SpreadPattern | Charged Blast (hold; drains stam) | Teleport (8 MP, 0.5s cd) | spirit |
| 16 | wand | Magic | BurstPattern | Blink (15 stam, 0.8s cd) | Magic Barrage (20/s stam + 5/s MP) | spirit |
| 17 | tome | Magic | NovaPattern (4+4) | Nova Burst (30 stam, 1.5s cd) | Arcane Shield (8/s MP) | spirit |
| 18 | greatsword | Melee | SpreadPattern (cd=0.8) | Overhead Slam (30 stam, 1.5s cd) | Berserker Rage (40/s stam) | power |
| 19 | great_axe | Melee | ShotgunPattern (cd=0.7) | Whirlwind Cleave (25 stam, 1.2s cd) | Executioner (35/s stam) | power |
| 20 | whip | Melee | WavePattern | Lasso Pull (15 stam, 1.0s cd) | Crack Whip (20/s stam) | agility |
| 21 | scythe | Melee | CrossPattern | Reap (25 stam, 1.3s cd) | Soul Harvest (30/s stam) | power |
| 22 | claws | Melee | GatlingPattern (cd=0.3) | Pounce (20 stam, 0.8s cd) | Frenzy (25/s stam) | agility |

*Bow Spacebar: Rangers get Longshot (15 stam + 5 MP, 1.5s cd); other classes get Dash.

---

## Weapon Types

### 1. Sword
- **Slot**: WEAPON_MELEE
- **Pattern**: SpreadPattern (default)
- **Scaling**: power
- **Class**: Warrior, Mercenary

**Spacebar -- Dash**
- Cost: 25 stamina | Cooldown: 0.3s
- Quick directional dash with i-frames. Deals contact damage to enemies in path (melee weapons only). Standard mobility tool.

**Shift -- Blade Dance**
- Drain: 30 stamina/s
- Fast attacks with short dashes between strikes. Increased attack speed while active.

**Items**: Rusty Sword, Short Sword, Sword, Broadsword, Stinger Sword, Longsword, Mighty Blade, Steel Sword, Curved Sword, Magic Sword, Rapier, Cutlass, Harpe, Katana, Flame Rapier, Fire Sword, Poisoned Spike, Ornate Blade, Wicket Blade, Crusader Sword, Lion Blade, Dual Swords, Lava Sword, Blood Blade, Blade of Honour, Blade of Justice, Blade of Virtue, Spectral Blade, Assasin Blade, Phoenix Blade, Blade of Ages, Sword of Nivek

### 2. Dagger
- **Slot**: WEAPON_MELEE
- **Pattern**: BurstPattern
- **Scaling**: power
- **Class**: Archer, Mercenary

**Spacebar -- Dash**
- Cost: 25 stamina | Cooldown: 0.3s
- Same as sword dash: quick directional dash with i-frames and contact damage.

**Shift -- Shadow Step (Rapid Mode)**
- Drain: 45 stamina/s + 4 MP/s
- 1.5x faster attack speed, +30% crit chance. Very heavy stamina drain for burst DPS.

**Items**: Rusty Knife, Razor Knife, Hunter Knife, Tooth Dagger, Ridged Dagger, Spire Dagger, Sickle, Bandit Shiv, Clawn, Dagger, Shadow Knife, Diamond Knife, Jeweled Hook, Double Clawn, Venom Blade, Assassin Dagger, DKTahg, Blade of Shadows

### 3. Axe
- **Slot**: WEAPON_MELEE
- **Pattern**: ShotgunPattern
- **Scaling**: power
- **Class**: Warrior, Mercenary

**Spacebar -- Dash + Cleave**
- Cost: 25 stamina | Cooldown: 0.3s
- Dash forward, then unleash a cleave AoE at the landing point.

**Shift -- Whirlwind**
- Drain: 45 stamina/s
- Switches to ring-pattern bullets, firing projectiles in all directions. Very heavy stamina drain.

**Items**: Hatchet, Hand Axe, Axe, Cleaver, Broad Axe, Viking Axe, Mighty Axe, Steel Axe, Battle Axe, Executioner Axe, Demonic Axe, Infernal Axe, War Axe, Doom Axe, Axe of Ruin

### 4. Hammer
- **Slot**: WEAPON_MELEE
- **Pattern**: MeteorPattern
- **Scaling**: power
- **Class**: Warrior, Mercenary

**Spacebar -- Hammer Throw**
- Cost: 20 stamina | Cooldown: 2.0s
- Throws a boomerang projectile dealing 3x weapon damage, pierces all enemies. Also pushes nearby enemies away with AoE knockback (48px radius).

**Shift -- Earthquake**
- Drain: 35 stamina/s
- Repeatedly slams the ground dealing 1.5x damage in a 28px AoE radius, stunning hit enemies for 0.4s.

**Items**: Wooden Mallet, Hammer, Stone Hammer, Iron Hammer, Maul, Battle Hammer, Thunder Hammer, Warhammer, Obsidian Hammer, Runic Hammer, Titans Hammer, Hammer of Dawn

### 5. Club
- **Slot**: WEAPON_MELEE
- **Pattern**: SpreadPattern
- **Scaling**: power
- **Class**: Warrior, Mercenary

**Spacebar -- Ground Pound**
- Cost: 25 stamina | Cooldown: 1.0s
- 360-degree AoE dealing 2.5x damage + level bonus. Stuns all enemies for 1.5s and applies strong knockback. Can crit based on luck.

**Shift -- Berserk Swing**
- Drain: 25 stamina/s
- Wide spread attacks with +50% damage, -50% movement speed.

**Items**: Stick, Club, Spiked Club, Iron Club, Mace, War Club, Troll Club, Skull Crusher, Hunters Mace, Giant Club, Magma Club, Consecrated Mace

### 6. Flail
- **Slot**: WEAPON_MELEE
- **Pattern**: BoomerangPattern
- **Scaling**: power
- **Class**: Warrior, Mercenary

**Spacebar -- Chain Lash**
- Cost: 20 stamina | Cooldown: 1.2s
- 90-degree cone AoE dealing 2x damage. Pulls hit enemies 40% closer to the player. Also fires a boomerang bullet for visual feedback.

**Shift -- Whip Spin**
- Drain: 25 stamina/s
- Fires 3 boomerang bullets in a spread every 0.3s, dealing 1.5x damage each with 2 pierce. Extended range sustained assault.

**Items**: Flail, Iron Flail, Spiked Flail, Morning Star, Juggling Balls, War Flail, Jesters Shaker, Nunchuks, Dark Nunchucks, Demon Flail, War Flail Heavy, Chain of Torment

### 7. Spear
- **Slot**: WEAPON_MELEE
- **Pattern**: TridentPattern
- **Scaling**: power
- **Class**: Warrior, Mercenary

**Spacebar -- Lunge**
- Cost: 25 stamina | Cooldown: 0.7s
- 2.5x distance charge with line damage. Grants i-frames during the lunge. Escalating pierce damage (more damage per additional enemy hit).

**Shift -- Phalanx Stance**
- Drain: 20 stamina/s
- Brace in place, auto-fires piercing shots forward. Immobile but powerful sustained damage in a line.

**Items**: Wooden Spear, Iron Spear, Pike, Javelin, Task Spear, War Spear, Trident, Scythe (spear-typed), Chaos Spear, Dragon Spear, Titans Trident

### 8. Javelin
- **Slot**: WEAPON_MELEE
- **Pattern**: TridentPattern
- **Scaling**: agility
- **Class**: Archer, Mercenary

**Spacebar -- Javelin Throw**
- Cost: 20 stamina | Cooldown: 1.2s
- Long-range piercing projectile dealing 3.5x damage at 2x bullet speed with 5 pierce. Excellent for sniping priority targets.

**Shift -- Rain of Javelins**
- Drain: 30 stamina/s
- Rapid throws with pierce. Sustained high-damage ranged assault.

**Items**: Wooden Javelin, Iron Javelin, Steel Javelin, Barbed Javelin, Lightning Javelin, Dragon Javelin, Javelin of Storms, Godslayer Javelin

### 9. Halberd
- **Slot**: WEAPON_MELEE
- **Pattern**: TridentPattern
- **Scaling**: power
- **Class**: Warrior, Mercenary

**Spacebar -- Halberd Sweep**
- Cost: 25 stamina | Cooldown: 1.0s
- Wide 108-degree frontal arc dealing 2x melee damage with knockback. Also fires 3 piercing bullets in a spread for ranged hits.

**Shift -- Guard Stance**
- Drain: 15 stamina/s
- Block incoming attacks and auto-counter nearby enemies. Reduces movement speed while active.

**Items**: Halberd

### 10. Throwing
- **Slot**: WEAPON_MELEE
- **Pattern**: ScatterPattern
- **Scaling**: agility
- **Class**: Archer, Mercenary

**Spacebar -- Fan of Knives**
- Cost: 15 stamina | Cooldown: 1.0s
- Fires 5 projectiles in a ~140-degree arc, each dealing 0.8x damage. Good for clearing groups at close range.

**Shift -- Barrage**
- Cost: 20 stamina | Cooldown: 2.0s (one-shot, not held)
- Fires 7 projectiles in a focused scatter with random spread. Full weapon damage per projectile.

**Items**: Pebbles, Darts, Iron Stars, Chakram, Throwing Stars, Flinger, Ronia Stone, War Darts, Void Stars, Storm Stars

### 11. Short Bow
- **Slot**: WEAPON_RANGED
- **Pattern**: SpreadPattern
- **Scaling**: agility
- **Class**: Archer, Mercenary

**Spacebar -- Evasive Shot**
- Cost: 15 stamina | Cooldown: 0.8s
- Backflip away from aim direction (0.6x dash distance) while firing 3 shots forward. Grants i-frames during backflip.

**Shift -- Rapid Fire**
- Drain: 20 stamina/s
- Increased fire rate, reduced damage. Good for sustained pressure.

**Items**: Crude Short Bow, Short Bow, Hunters Short Bow, Swift Bow, Snake Bow, Composite Bow, Repeater Bow, Rapid Short Bow, Shadow Short Bow, Phantom Bow

### 12. Bow
- **Slot**: WEAPON_RANGED
- **Pattern**: ParallelPattern
- **Scaling**: agility
- **Class**: Archer, Mercenary

**Spacebar -- Dash (non-Ranger) / Longshot (Ranger)**
- Dash: 25 stamina, 0.3s cd -- Standard dash.
- Longshot (Ranger only): 15 stamina + 5 MP, 1.5s cd -- Fires a special long-range shot (5 base damage) that pierces 3 enemies and stuns for 1.0-1.5s.

**Shift -- Multishot**
- Drain: 25 stamina/s + 5 MP/s
- Fires multiple arrows per shot while held. Drains both stamina and MP.

**Items**: Grimey Bow, Bow, Oak Bow, Elm Bow, Ash Bow, Iron Bow, Dwarf Bow, Long Bow, Recurve Bow, Yew Bow, Hunters Bow, Harp Bow, Twin Strung Bow, Mechanical Bow, Ornate Bow, Snake Bow, Elven Bow, War Bow, Composite Bow, Golden Bow, Magic Bow, Dark Bow, Lava Bow, Goif Bow, Elder Bow, Bow of Justice, Phantom Bow

### 13. Crossbow
- **Slot**: WEAPON_RANGED
- **Pattern**: RailgunPattern
- **Scaling**: agility
- **Class**: Archer, Mercenary

**Spacebar -- Power Shot**
- Cost: 20 stamina | Cooldown: 1.5s
- Fires a single devastating shot at 1.5x speed dealing 4x damage that pierces all enemies. Excellent burst.

**Shift -- Aimed Mode**
- Drain: 15 stamina/s
- 50% movement speed, 2x damage multiplier applied to all shots. Precision over mobility.

**Items**: Crossbow, Light Crossbow, Hunting Crossbow, Steel Crossbow, Heavy Crossbow, Dual Crossbow, Repeating Crossbow, War Crossbow, Siege Crossbow, Dragon Crossbow, Arbalest

### 14. Sling
- **Slot**: WEAPON_RANGED
- **Pattern**: ScatterPattern
- **Scaling**: agility
- **Class**: Archer, Mercenary

**Spacebar -- Scatter Volley**
- Cost: 20 stamina | Cooldown: 1.0s
- Burst of 6 projectiles in a wide arc dealing 1.2x damage each. Random spread for area saturation.

**Shift -- Rapid Sling**
- Drain: 25 stamina/s
- Much faster fire rate while held.

**Items**: Leather Sling, Hunters Sling, Wind Sling, War Sling, Void Sling, Stone Fury Sling, Titan Sling

### 15. Staff
- **Slot**: WEAPON_MAGIC
- **Pattern**: SpreadPattern
- **Scaling**: spirit
- **Class**: Wizard

**Spacebar -- Charged Blast (hold)**
- Cost: Drains all stamina over 2s charge, then 15 MP on release
- Hold Space to charge. Charges over 2s. Power scales with charge time. Fires automatically if stamina runs out. 50%+ charge = fully powered piercing blast. Always fires on release regardless of MP (uses what is available).

**Shift -- Teleport**
- Cost: 8 MP per use | Cooldown: 0.5s
- Instant short-range teleport in movement direction (60px). Grants brief i-frames. Very low cooldown for frequent repositioning.

**Special Staff Effects**: Certain named staffs apply unique on-hit effects:
- Frost Bolt: 2s slow
- Freeze: 1.5s freeze
- Flashbang: 1s stun
- Weaken: 3s slow
- Explosion: AoE burst on hit (24px, 80% damage)
- Magic Missile: +2 pierce
- Smite: 0.5s stun
- Corlion: 2s confuse
- Malorian Crook: 2s fear

**Items**: Dirty Staff, Bone Staff, Dark Staff, Staff, Pygmy Staff, Frost Bolt, Freeze, Flashbang, Weaken, Explosion, Magic Missile, Smite, Crooked Staff, Crystal Staff, Staff of Time, Beholder Staff, Staff of Ra, Lava Rod, Warlock Staff, Malorian Crook, Corlion, Cyrilian Ankh, Cyania Sceptre, Red Stone Sceptre, Winged Sceptre, Archmage Sceptre, Staff of Demid, Staff of Mord, Ruby Staff, Staff of Eternity

### 16. Wand
- **Slot**: WEAPON_MAGIC
- **Pattern**: BurstPattern
- **Scaling**: spirit
- **Class**: Wizard

**Spacebar -- Blink**
- Cost: 15 stamina | Cooldown: 0.8s
- Instant teleport in movement direction (60px). Grants i-frames with brief linger (0.2s). Visual afterimage at origin, spark at destination.

**Shift -- Magic Barrage**
- Drain: 20 stamina/s + 5 MP/s
- Rapid fire magic bolts while held. Dual resource drain for sustained magical DPS.

**Items**: Mirror Wand, Obsidian Wand, Ember Wand, Merlins Wand, Opal Wand, Argeebe Wand, Zann Wand, Gands Wand, Zidian Wand, Wand of Ages

### 17. Tome
- **Slot**: WEAPON_MAGIC
- **Pattern**: NovaPattern (4 inner + 4 outer)
- **Scaling**: spirit
- **Class**: Wizard

**Spacebar -- Nova Burst**
- Cost: 30 stamina | Cooldown: 1.5s
- Large AoE burst (40px radius) dealing 3x damage + level bonus. Also fires 8 bullets outward in a ring (1.5x damage, 2 pierce each). Slows hit enemies for 1.5s.

**Shift -- Arcane Shield**
- Drain: 8 MP/s
- Creates a damage barrier that absorbs incoming hits. Drains MP only (no stamina cost). Active as long as MP remains.

**Items**: Mustard Tome, Book of Chevron, Book of Ohm, Tome of Souls, Book of Ka, Dark Bible, Book of Majesty, Prong Tome, Diary of the Damned, Goomba Grimoire, Tome of Doom

### 18. Greatsword
- **Slot**: WEAPON_MELEE
- **Pattern**: SpreadPattern (cooldown override: 0.8s)
- **Scaling**: power
- **Class**: No default restriction

**Spacebar -- Overhead Slam**
- Cost: 30 stamina | Cooldown: 1.5s
- Massive 90-degree frontal cone dealing 3.5x damage. Stuns enemies for 0.5s and applies knockback. Heavy screen shake.

**Shift -- Berserker Rage**
- Drain: 40 stamina/s
- +100% damage, -50% movement speed. Extremely heavy stamina drain for maximum burst.

**Items**: Crude Greatsword, Iron Greatsword, Steel Greatsword, Warblade, Flamberge, Titan Blade, Runic Greatsword, Executioners Blade, Doom Edge, Blade of Annihilation

### 19. Great Axe
- **Slot**: WEAPON_MELEE
- **Pattern**: ShotgunPattern (cooldown override: 0.7s)
- **Scaling**: power
- **Class**: No default restriction

**Spacebar -- Whirlwind Cleave**
- Cost: 25 stamina | Cooldown: 1.2s
- 360-degree AoE (30px radius) dealing 2.5x damage with strong knockback. Hits all surrounding enemies.

**Shift -- Executioner**
- Drain: 35 stamina/s
- +75% damage while held. Heavy stamina cost for sustained damage boost.

**Items**: Crude Great Axe, Iron Great Axe, Ravager, Steel Great Axe, Berserker Axe, Titan Cleaver, Doomcleaver, Worldsplitter

### 20. Whip
- **Slot**: WEAPON_MELEE
- **Pattern**: WavePattern
- **Scaling**: agility
- **Class**: No default restriction

**Spacebar -- Lasso Pull**
- Cost: 15 stamina | Cooldown: 1.0s
- Pulls the nearest enemy (within 48px) to melee range (8px from player). Deals 1.5x damage and stuns for 0.3s. Excellent for repositioning dangerous enemies.

**Shift -- Crack Whip**
- Drain: 20 stamina/s
- Rapid wave shots with extended range. Increased fire rate and reach while active.

**Items**: Leather Whip, Barbed Whip, Chain Whip, Viper Lash, Thunder Whip, Soul Whip, Void Lash, Scorpion Tail, Soul Lash

### 21. Scythe
- **Slot**: WEAPON_MELEE
- **Pattern**: CrossPattern
- **Scaling**: power
- **Class**: No default restriction

**Spacebar -- Reap**
- Cost: 25 stamina | Cooldown: 1.3s
- 180-degree frontal arc (28px range) dealing 2.5x damage. Heals the player for 10% of total damage dealt. Sustain through offense.

**Shift -- Soul Harvest**
- Drain: 30 stamina/s
- Kills heal 15% of max HP, +50% damage. Synergizes with Reap for a life-steal playstyle.

**Items**: Rusty Scythe, Iron Scythe, Death Scythe, War Scythe, Void Scythe, Soul Reaper

### 22. Claws
- **Slot**: WEAPON_MELEE
- **Pattern**: GatlingPattern (cooldown override: 0.3s)
- **Scaling**: agility
- **Class**: No default restriction

**Spacebar -- Pounce**
- Cost: 20 stamina | Cooldown: 0.8s
- Teleports to nearest enemy (within 40px) dealing 3x damage and stunning for 0.3s. If no enemy in range, performs a short forward dash instead.

**Shift -- Frenzy**
- Drain: 25 stamina/s
- 3x fire rate, +25% damage. Turns the already-fast GatlingPattern into a bullet storm.

**Items**: Bone Claws, Iron Claws, Steel Claws, Tiger Claws, Shadow Claws, Dragon Claws, Void Claws

---

## Firing Patterns Reference

| Pattern | Description |
|---------|-------------|
| SpreadPattern | Default single-shot forward with slight spread |
| BurstPattern | Quick burst of 2-3 shots in rapid succession |
| ShotgunPattern | Multiple pellets in a wide cone (damage split) |
| MeteorPattern | Arcing projectile with area impact |
| BoomerangPattern | Projectile returns to player after reaching max range |
| TridentPattern | 3 parallel projectiles (center has bonus pierce) |
| ScatterPattern | Random spread of projectiles in forward direction |
| ParallelPattern | Multiple straight shots in parallel lines |
| RailgunPattern | Single high-speed piercing shot |
| NovaPattern | Fires in a ring around the player (inner + outer rings) |
| WavePattern | Sinusoidal wave-motion projectiles |
| CrossPattern | Fires in 4 cardinal directions simultaneously |
| GatlingPattern | Very fast single shots with minimal cooldown |

## Damage Formula

Base weapon damage is calculated as: `(base_stat + flat_bonuses) * (1 + percent_bonuses)`

Scaling stat determines which attribute boosts damage:
- **power**: Melee weapons (sword, axe, hammer, club, flail, spear, halberd, greatsword, great_axe, scythe, dagger)
- **agility**: Ranged/fast weapons (bow, short_bow, crossbow, throwing, javelin, sling, whip, claws)
- **spirit**: Magic weapons (staff, wand, tome)

Critical hits: `luck / 2 = crit_chance%`, damage = `base_damage * crit_multiplier`

## Ammo System

Ranged weapons and throwing/javelin types can use special ammo for bonus effects:
- **Fire Arrow**: +50% damage, 5s burn, fire spread
- **Freeze Arrow**: +50% damage, 3s full freeze
- **Explosion Arrow**: +50% damage, 48px AoE (120% weapon damage)
- **Poison Arrow**: +50% damage, 6s stackable poison
- **Lightning Arrow**: +50% damage, chain lightning effect
- **Slow Arrow**: +50% damage, 5s heavy slow
- **Throwing Knife**: +30% total damage, +1 pierce
- **Javelin Ammo**: +80% total damage, +3 pierce
- **Poison Knife**: stackable poison
- **Explosive Javelin**: 40px AoE (100% weapon damage)

All arrow types grant a base +50% damage bonus on top of weapon damage.

## Enchantment System

Weapons can have enchantments that add proc effects to bullets. Enchantments are defined by `ItemEnchantment` with:
- `type`: The enchantment type
- `proc_chance`: Probability per hit (0.0-1.0)
- `bonus_damage`: Extra damage on proc

Enchanted weapons display with a prefix (e.g., "Blazing Steel Sword").
