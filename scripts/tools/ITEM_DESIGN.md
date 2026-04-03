# Item & Weapon Design Reference

## Weapon Type Identity

Each weapon type has unique Space (power) and Shift (sustained) abilities:

| Type | Pattern | Space (Power) | Shift (Sustained) |
|------|---------|--------------|-------------------|
| sword | Spread | Dash | Sprint |
| dagger | Burst | Dash | Rapid Attack (2x speed, +30% crit) |
| axe | Shotgun | Dash + Cleave AoE | Whirlwind (ring bullets, 30 stam/s) |
| club | Spread | Ground Pound (AoE stun) | Sprint |
| hammer | Meteor | Hammer Throw (boomerang, 3x dmg) | Sprint |
| flail | Boomerang | Dash | Whip Spin (boomerang multishot, 25 stam/s) |
| spear | Trident | Lunge (2x distance dash) | Sprint |
| throwing | Scatter | Dash | Barrage (7-projectile burst, 2s CD) |
| bow | Parallel | Longshot (Ranger) / Dash (others) | Multishot (3 arrows) |
| short_bow | Spread | Dash | Sprint |
| crossbow | Railgun | Power Shot (4x dmg, pierce all) | Aimed Mode (50% speed, 2x dmg) |
| staff | Spread | Powershot (stationary channeling) | Teleport (0.5s cooldown) |

## Starter Loadouts

| Class | Weapon | Secondary | Damage |
|-------|--------|-----------|--------|
| Warrior | Sword (2 dmg) | Shield | 2 |
| Mercenary | Sword (2 dmg) | Short Bow (1 dmg) | 2/1 |
| Ranger | Long Bow (2 dmg) | Dagger (2 dmg) | 2/2 |
| Wizard | Staff (1 dmg) | — | 1 |

Ranger distance scaling: full damage at 50%+ range, half damage below 50%.

**Damage formula**: All class base_damage = 0, PlayerStats.attack_damage = 0.
Weapon flat_bonus IS the total damage. Simple, clean, no class multiplier confusion.
Composite Bow is classified as short_bow (not bow).

## Tier System (internal, not shown in-game)

| Tier | Damage Range | Drop Location | Examples |
|------|-------------|---------------|----------|
| T0 | 1-2 | Starting gear | Sword, Dagger, Bow, Staff |
| T1 | 3-5 | Graveyard OW | Longsword, Hatchet, Flail, Bone Staff |
| T2 | 7-10 | Aria Dungeon (7 floors) | Bandit Shiv, Spiked Club, Drain, Explosion |
| T3 | 14-19 | Graveyard Dungeon (3 floors) | Crusader Sword, Viking Axe, Crossbow, Dark Staff |
| T4 | 20-28 | Farm Dungeon (6 floors) | Katana, Ornate Bow, Blade of Ages, Cyania Sceptre |
| T5 | 30-45 | Wilderness/Hidden Forest | Smite, Lightning, Mechanical Bow, Titan's Trident |

## Tier Ceilings by Weapon Type

Not every weapon type reaches T5. Tier caps reflect the weapon's role:

| Type | Max Tier | Rationale |
|------|----------|-----------|
| sword | T5 | Main weapon, full progression |
| dagger | T5 | Assassin endgame viable |
| axe | T5 | Power weapon, full progression |
| club | T5 | Heavy hitter, endgame viable |
| hammer | T5 | Legendary smithing weapons |
| flail | T5 | Exotic endgame weapon |
| spear | T5 | Titan's Trident is endgame |
| throwing | T5 | Void Stars as endgame |
| bow | T5 | Ranger main weapon |
| short_bow | T4 | Utility speed weapon, caps at Farm |
| crossbow | T5 | Siege Crossbow as endgame |
| staff | T5 | Wizard main weapon |

## Weapon Inventory by Type

### Swords (48 items)
| Name | Tier | Damage | Rarity | Drop Area |
|------|------|--------|--------|-----------|
| Rusty Sword | T0 | 2 | Common | — (vendor trash) |
| Sword | T0 | 2 | Common | Starting (Warrior/Merc) |
| Flashbang | T1 | 3 | Common | Graveyard OW |
| Freeze | T1 | 4 | Common | Graveyard OW |
| Longsword | T1 | 4 | Common | Graveyard OW |
| Weaken | T1 | 4 | Common | Graveyard OW |
| Fireball | T1 | 5 | Common | Graveyard OW |
| Drain | T2 | 7 | Uncommon | Aria Dungeon |
| Frost Bolt | T2 | 9 | Common | Aria Dungeon |
| Stinger Sword | T2 | 9 | Uncommon | Aria Dungeon |
| Flinger | T3 | 17 | Rare | GY Dungeon |
| Jesters Shaker | T3 | 17 | Rare | GY Dungeon |
| Lava Sword | T3 | 17 | Rare | GY Dungeon |
| Mighty Blade | T3 | 17 | Rare | GY Dungeon |
| Sickle | T3 | 17 | Rare | GY Dungeon |
| Crusader Sword | T3 | 18 | Rare | GY Dungeon |
| Curved Sword | T3 | 18 | Rare | GY Dungeon |
| Explosion | T3 | 18 | Uncommon | GY Dungeon |
| Magic Sword | T3 | 18 | Rare | GY Dungeon |
| Assasin Blade | T3 | 19 | Rare | GY Dungeon |
| Clawn | T3 | 19 | Rare | GY Dungeon |
| Fire Sword | T3 | 19 | Rare | GY Dungeon |
| Jeweled Hook | T3 | 19 | Rare | GY Dungeon |
| Lion Blade | T3 | 19 | Rare | GY Dungeon |
| Wicket Blade | T3 | 19 | Rare | GY Dungeon |
| Corlion | T3 | 20 | Rare | Farm Dungeon |
| Double Clawn | T3 | 20 | Rare | Farm Dungeon |
| Malorian Crook | T3 | 20 | Rare | Farm Dungeon |
| Phoenix Blade | T3 | 20 | Rare | Farm Dungeon |
| Dktahg | T4 | 21 | Rare | Farm Dungeon |
| Rapier | T4 | 22 | Rare | Farm Dungeon |
| Scythe | T4 | 22 | Rare | Farm Dungeon |
| Harpe | T4 | 23 | Rare | Farm Dungeon |
| Katana | T4 | 23 | Rare | Farm Dungeon |
| Blade of Ages | T4 | 24 | Rare | Farm Dungeon |
| Dual Swords | T4 | 24 | Rare | Farm Dungeon |
| Flame Rapier | T4 | 24 | Rare | Farm Dungeon |
| Spectral Blade | T4 | 25 | Rare | Farm Dungeon |
| Cutlass | T4 | 26 | Rare | Farm Dungeon |
| Ornate Blade | T4 | 27 | Rare | Farm Dungeon |
| Poisoned Spike | T4 | 27 | Rare | Farm Dungeon |
| Blade of Virtue | T4 | 28 | Rare | Farm Dungeon |
| Blade of Honour | T4 | 30 | Rare | Farm Dungeon |
| Magic Missile | T4 | 30 | Rare | Farm Dungeon |
| Blade of Justice | T5 | 32 | Rare | Wilderness |
| Sword of Nivek | T5 | 36 | Rare | Wilderness |
| Lightning | T5 | 40 | Rare | Wilderness |
| Smite | T5 | 52 | Rare | Wilderness (Boss) |

### Daggers (12 items)
| Name | Tier | Damage | Rarity | Drop Area |
|------|------|--------|--------|-----------|
| Dagger | T0 | 2 | Common | Starting (Ranger) |
| Spire Dagger | T1 | 3 | Common | Graveyard OW |
| Ridged Dagger | T1 | 4 | Common | Graveyard OW |
| Tooth Dagger | T1 | 4 | Common | Graveyard OW |
| Bandit Shiv | T2 | 8 | Uncommon | Aria Dungeon |
| Hunter Knife | T2 | 8 | Uncommon | Aria Dungeon |
| Razor Knife | T2 | 9 | Uncommon | Aria Dungeon |
| Diamond Knife | T3 | 16 | Rare | GY Dungeon |
| Assassin Dagger | T4 | 21 | Uncommon | Farm Dungeon |
| Venom Blade | T4 | 24 | Uncommon | Farm Dungeon |
| Shadow Knife | T4 | 27 | Rare | Farm Dungeon |
| Blade of Shadows | T5 | 32 | Rare | Wilderness |

### Axes (12 items)
| Name | Tier | Damage | Rarity | Drop Area |
|------|------|--------|--------|-----------|
| Hand Axe | T0 | 2 | Common | Starting/Vendor |
| Hatchet | T1 | 3 | Common | Graveyard OW |
| Axe | T1 | 4 | Common | Graveyard OW |
| Mighty Axe | T1 | 5 | Common | Graveyard OW |
| Battle Axe | T2 | 8 | Common | Aria Dungeon |
| Broad Axe | T2 | 10 | Uncommon | Aria Dungeon |
| Viking Axe | T3 | 15 | Rare | GY Dungeon |
| Cleaver | T3 | 16 | Rare | GY Dungeon |
| Demonic Axe | T3 | 17 | Rare | GY Dungeon |
| Executioner Axe | T4 | 22 | Uncommon | Farm Dungeon |
| Infernal Axe | T4 | 26 | Rare | Farm Dungeon |
| Axe of Ruin | T5 | 35 | Rare | Wilderness |

### Clubs (8 items)
| Name | Tier | Damage | Rarity | Drop Area |
|------|------|--------|--------|-----------|
| Stick | T0 | 1 | Common | Starting/Vendor |
| Club | T1 | 3 | Common | Graveyard OW |
| Mace | T1 | 4 | Common | Graveyard OW |
| Spiked Club | T2 | 8 | Uncommon | Aria Dungeon |
| Hunters Mace | T3 | 15 | Rare | GY Dungeon |
| Troll Club | T3 | 16 | Rare | GY Dungeon |
| Magma Club | T4 | 22 | Rare | Farm Dungeon |
| Skull Crusher | T5 | 34 | Rare | Wilderness |

### Hammers (8 items)
| Name | Tier | Damage | Rarity | Drop Area |
|------|------|--------|--------|-----------|
| Wooden Mallet | T0 | 2 | Common | Starting/Vendor |
| Hammer | T1 | 3 | Common | Graveyard OW |
| Iron Hammer | T2 | 8 | Common | Aria Dungeon |
| Maul | T2 | 10 | Uncommon | Aria Dungeon |
| Warhammer | T3 | 17 | Rare | GY Dungeon |
| Thunder Hammer | T4 | 24 | Uncommon | Farm Dungeon |
| Runic Hammer | T4 | 27 | Rare | Farm Dungeon |
| Hammer of Dawn | T5 | 38 | Rare | Wilderness |

### Flails (9 items)
| Name | Tier | Damage | Rarity | Drop Area |
|------|------|--------|--------|-----------|
| Chain Whip | T0 | 1 | Common | Starting/Vendor |
| Flail | T1 | 3 | Common | Graveyard OW |
| Spiked Flail | T1 | 4 | Common | Graveyard OW |
| War Flail | T2 | 8 | Common | Aria Dungeon |
| Morning Star | T2 | 10 | Uncommon | Aria Dungeon |
| Nunchuks | T3 | 15 | Rare | GY Dungeon |
| Juggling Balls | T3 | 16 | Rare | GY Dungeon |
| Dark Nunchucks | T4 | 21 | Rare | Farm Dungeon |
| Chain of Torment | T5 | 33 | Rare | Wilderness |

### Spears (8 items)
| Name | Tier | Damage | Rarity | Drop Area |
|------|------|--------|--------|-----------|
| Wooden Spear | T0 | 2 | Common | Starting/Vendor |
| Javelin | T1 | 4 | Common | Graveyard OW |
| Pike | T1 | 5 | Uncommon | Graveyard OW |
| Halberd | T2 | 9 | Uncommon | Aria Dungeon |
| Task Spear | T3 | 15 | Rare | GY Dungeon |
| Trident | T3 | 17 | Rare | GY Dungeon |
| Chaos Spear | T4 | 22 | Rare | Farm Dungeon |
| Titan's Trident | T5 | 32 | Rare | Wilderness |

### Throwing (7 items)
| Name | Tier | Damage | Rarity | Drop Area |
|------|------|--------|--------|-----------|
| Pebbles | T0 | 1 | Common | Starting/Vendor |
| Throwing Knives | T1 | 3 | Common | Graveyard OW |
| Darts | T1 | 5 | Uncommon | Graveyard OW |
| Chakram | T2 | 9 | Uncommon | Aria Dungeon |
| Throwing Stars | T3 | 16 | Rare | GY Dungeon |
| Ronia Stone | T4 | 22 | Rare | Farm Dungeon |
| Void Stars | T5 | 32 | Rare | Wilderness |

### Bows (21 items)
| Name | Tier | Damage | Rarity | Drop Area |
|------|------|--------|--------|-----------|
| Bow | T0 | 1 | Common | — (vendor trash) |
| Grimey Bow | T0 | 1 | Common | — (vendor trash) |
| Long Bow | T0 | 2 | Common | Starting (Ranger) |
| Oak Bow | T1 | 4 | Common | Graveyard OW |
| Recurve Bow | T1 | 5 | Uncommon | Graveyard OW |
| Ash Bow | T2 | 8 | Common | Aria Dungeon |
| War Bow | T2 | 10 | Uncommon | Aria Dungeon |
| Hunters Bow | T3 | 14 | Rare | GY Dungeon |
| Magic Bow | T3 | 15 | Rare | GY Dungeon |
| Dark Bow | T3 | 16 | Rare | GY Dungeon |
| Elven Bow | T3 | 16 | Rare | GY Dungeon |
| Lava Bow | T3 | 17 | Rare | GY Dungeon |
| Golden Bow | T4 | 20 | Rare | Farm Dungeon |
| Goif Bow | T4 | 21 | Rare | Farm Dungeon |
| Harp Bow | T4 | 23 | Rare | Farm Dungeon |
| Elder Bow | T4 | 24 | Rare | Farm Dungeon |
| Ornate Bow | T4 | 26 | Rare | Farm Dungeon |
| Bow of Justice | T5 | 30 | Rare | Wilderness |
| Twin Strung Bow | T5 | 33 | Rare | Wilderness |
| Dwarf Bow | T5 | 36 | Rare | Wilderness |
| Mechanical Bow | T5 | 42 | Rare | Wilderness (Boss) |

### Crossbows (7 items)
| Name | Tier | Damage | Rarity | Drop Area |
|------|------|--------|--------|-----------|
| Light Crossbow | T0 | 2 | Common | Starting/Vendor |
| Hunting Crossbow | T1 | 4 | Common | Graveyard OW |
| Heavy Crossbow | T1 | 5 | Uncommon | Graveyard OW |
| Arbalest | T2 | 9 | Uncommon | Aria Dungeon |
| Crossbow | T3 | 15 | Rare | GY Dungeon |
| Dual Crossbow | T4 | 24 | Rare | Farm Dungeon |
| Siege Crossbow | T5 | 34 | Rare | Wilderness |

### Staves (28 items)
| Name | Tier | Damage | Rarity | Drop Area |
|------|------|--------|--------|-----------|
| Dirty Staff | T0 | 1 | Common | — (vendor trash) |
| Staff | T0 | 1 | Common | Starting (Wizard) |
| Beholder Staff | T1 | 3 | Common | Graveyard OW |
| Bone Staff | T1 | 4 | Common | Graveyard OW |
| Staff of Mord | T1 | 5 | Common | Graveyard OW |
| Crystal Staff | T2 | 7 | Common | Aria Dungeon |
| Ember Wand | T2 | 9 | Uncommon | Aria Dungeon |
| Dark Staff | T3 | 14 | Rare | GY Dungeon |
| Merlins Wand | T3 | 15 | Rare | GY Dungeon |
| Staff of Demid | T3 | 15 | Rare | GY Dungeon |
| Staff of Ra | T3 | 15 | Rare | GY Dungeon |
| Zann Wand | T3 | 15 | Rare | GY Dungeon |
| Obsidian Wand | T3 | 16 | Rare | GY Dungeon |
| Red Stone Sceptre | T3 | 16 | Rare | GY Dungeon |
| Warlock Staff | T3 | 16 | Rare | GY Dungeon |
| Gands Wand | T3 | 18 | Rare | GY Dungeon |
| Opal Wand | T3 | 18 | Rare | GY Dungeon |
| Pygmy Staff | T3 | 18 | Rare | GY Dungeon |
| Ruby Staff | T3 | 19 | Rare | GY Dungeon |
| Zidian Wand | T3 | 19 | Rare | GY Dungeon |
| Crooked Staff | T4 | 20 | Rare | Farm Dungeon |
| Wand of Ages | T4 | 20 | Rare | Farm Dungeon |
| Cyrilian Ankh | T4 | 21 | Rare | Farm Dungeon |
| Argeebe Wand | T4 | 22 | Rare | Farm Dungeon |
| Cyania Sceptre | T4 | 22 | Rare | Farm Dungeon |
| Winged Sceptre | T4 | 22 | Rare | Farm Dungeon |
| Staff of Eternity | T5 | 35 | Rare | Wilderness |
| Archmage Sceptre | T5 | 40 | Rare | Wilderness |

### Short Bows (6 items, caps at T4)
| Name | Tier | Damage | Rarity | Drop Area |
|------|------|--------|--------|-----------|
| Short Bow | T0 | 1 | Common | Starting (Mercenary) |
| Composite Bow | T1 | 3 | Common | Graveyard OW |
| Swift Bow | T2 | 7 | Common | Aria Dungeon |
| Repeater Bow | T3 | 14 | Uncommon | GY Dungeon |
| Snake Bow | T3 | 16 | Uncommon | GY Dungeon |
| Phantom Bow | T4 | 20 | Rare | Farm Dungeon |

## Consumable Fixes Applied

| Item | Fix | Effect |
|------|-----|--------|
| cure | use_effect=cure_poison | Removes POISONED |
| steel_skin, protect | use_effect=iron_skin | +5 armor for 30s |
| invisibility, stealth | use_effect=stealth_buff | Sneak + stealth for 15s |
| stun, distraction | use_effect=stun_aoe | Stun enemies in 48px for 2s |
| push | use_effect=pushback_aoe | Knockback enemies in 48px |
| bezerk | use_effect=berserk | +100% dmg, +50% speed, -50% armor for 10s |
| charge | use_effect=speed_boost | +25% speed for 30s |
| fire_fists | use_effect=damage_buff | +30% damage for 30s |
| field_dressing | heal_hp=5 | Heal 5 HP |
| first_aid | heal_hp=15 | Heal 15 HP |
| anger | heal_mp=15 | Restore 15 MP |
| focus | heal_mp=20 | Restore 20 MP |
| fire_fish | heal_mp=10 | Restore 10 MP |
| octopus | heal_mp=25 | Restore 25 MP |
| teleport | use_effect=town_portal | Return to overworld |
| fishing_pole, lava_rod, spade | slot=MATERIAL | No longer consumable |

## Deferred Items (need new systems)

- **Permanent stat elixirs**: attack_elixir, defence_elixir (need permanent stat boost system)
- **Enchant consumables**: grapes_of_wrath, ice_shards, skull, etc. (need enchantment apply system)
- **Telekinesis**: move item (need new mechanic)

## Gap Analysis — RESOLVED

All weapon types now have full tier progression (48 new items created):

| Type | T0 | T1 | T2 | T3 | T4 | T5 | Total |
|------|----|----|----|----|----|----|-------|
| sword | 2 | 6 | 3 | 14 | 17 | 6 | 48 |
| dagger | 1 | 3 | 3 | 1 | 3 | 1 | 12 |
| axe | 1 | 3 | 2 | 3 | 2 | 1 | 12 |
| club | 1 | 2 | 1 | 2 | 1 | 1 | 8 |
| hammer | 1 | 1 | 2 | 1 | 2 | 1 | 8 |
| flail | 1 | 2 | 2 | 2 | 1 | 1 | 9 |
| spear | 1 | 2 | 1 | 2 | 1 | 1 | 8 |
| throwing | 1 | 2 | 1 | 1 | 1 | 1 | 7 |
| bow | 3 | 2 | 2 | 5 | 5 | 4 | 21 |
| short_bow | 1 | 1 | 1 | 2 | 1 | — | 6 |
| crossbow | 1 | 2 | 1 | 1 | 1 | 1 | 7 |
| staff | 2 | 3 | 2 | 13 | 6 | 2 | 28 |

Short bow intentionally caps at T4 (utility speed weapon, not endgame DPS).
Total weapon count: 174 (was 126, +48 new).
