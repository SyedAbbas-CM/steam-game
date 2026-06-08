# Class × Weapon Ability Matrix

How each player class wields each weapon's SHIFT special.

## Weapon Proficiency (CLASS_NATIVE_WEAPONS)

Each class has a list of **native weapons** it can wield effectively. Off-class weapons require **stat investment in the weapon's scaling stat** before they do meaningful damage.

| Class | Native weapon types |
|---|---|
| **Warrior** | sword, axe, hammer, club, flail, halberd, spear, greatsword, great_axe, mace, scythe |
| **Mercenary** | sword, dagger, short_bow, throwing, club, claws, axe |
| **Archer / Ranger** | bow, short_bow, crossbow, dagger, throwing, sling, whip, javelin |
| **Wizard** | staff, wand, tome |

**Proficiency multiplier** (`EquipmentManager.get_proficiency_mult()`):

- **Native weapon**: clamp(0.75 + alloc_points × 0.025, 0.75, 1.0). 0 points = **75% damage**, 10 points = full damage.
- **Off-class weapon**: clamp(alloc_points × 0.10, 0.0, 1.0). 0 points = **0 damage** (the swing/shot plays the error sound). 10 points in the weapon's scaling stat = full damage.

Examples:
- Archer with 0 SPD using a Bow → 75% damage (native, always usable)
- Warrior with 0 SPD using a Bow → 0 damage + error sound (off-class, no proficiency)
- Warrior with 8 SPD using a Bow → 80% damage (off-class, partial proficiency)
- Wizard with 5 INT using a Staff → 87.5% damage (native, mostly there)
- Wizard with 0 STR using a Sword → 0 damage + error sound

The inventory's Combat Stats line now shows `Attack: N (proficiency X%)` when proficiency is below 100% so you know why your damage is low.

The error chime plays at every swing/shot that has 0 proficiency, so the player feels the mismatch immediately.

## Identity Pillars

- **Warrior**: heavy, aggressive. Trades speed and i-frames for raw damage and AoE bursts at the end of motion.
- **Mercenary**: versatile, mobile baseline. Quick recovery, weapon-swap synergy.
- **Archer (Ranger)**: ranged precision, evasion, headshots.
- **Wizard**: MP-fueled, crit-scaling, magical infusion of physical weapons.

These pillars are already true for the **dash** (Warrior end-of-dash AoE + vulnerable, Merc full i-frames) and now extended to each weapon below.

## Weapon × Class Behavior Table

### Sword — SHIFT = Blade Dance (sword type)

| Class | Fire rate × | Crit bonus | Dmg × | Feel |
|---|---|---|---|---|
| **Warrior** | 0.75 | +5% | 1.8 | Power swings: slow, heavy, knockback-ish |
| **Mercenary** (native) | 2.0 | +15% | 0.7 | Fast flurry, low per-hit |
| **Archer** | 2.0 | +15% | 0.7 | Same as merc — flurry |
| **Wizard** | 1.4 | +25% | 1.0 | Arcane infusion: moderate speed, crit |

### Dagger — SHIFT = Rapid Attack

| Class | Fire rate × | Crit bonus | Dmg × | Feel |
|---|---|---|---|---|
| **Warrior** | 0.7× base | half | 1.5 | Stab over stab — weighty |
| **Mercenary / Archer** | base | base | 1.0 | Rapid attack (native) |
| **Wizard** | base | base+15% | 0.9 | Rune dagger: same speed, crit |

### Bow — SHIFT = Multishot

| Class | Extra bullets | Spread | Per-bullet dmg | Tint |
|---|---|---|---|---|
| **Warrior** | 1 | 0° (straight) | 110% | — | Power draw: single heavy extra arrow |
| **Mercenary** | 3 | wide (~24°) | 45% | — | Scattergun feel |
| **Archer** (native) | 2 | narrow | 60% | — | Precise multishot |
| **Wizard** | 2 | medium | 50% | purple | Arcane shot |

### Crossbow — SHIFT = Aimed Mode

| Class | Fire rate × | Crit bonus | Dmg × |
|---|---|---|---|
| **Warrior** | 0.5 | +10% | 2.6 |
| **Mercenary** | 0.7 | +20% | 2.0 |
| **Archer** (native) | 0.7 | +30% | 2.2 |
| **Wizard** | 0.7 | +20% | 2.0 |

### Currently uniform (no class differentiation yet)

These weapons still use one profile for all classes. Targets for the next pass:

- Hammer (Earthquake), Axe (Whirlwind), Club (Berserk Swing), Spear (Phalanx), Flail (Whip Spin), Throwing (Barrage), Wand (Magic Barrage), Tome (Arcane Shield), Staff (Teleport), Whip (Crack Whip), Scythe (Soul Harvest), Claws (Pounce), Halberd (-), Greatsword (-), Great Axe (-).

When extending, the pattern is consistent: read `_pc_class = _get_player_class()` in the ability's value-application block (around `player.gd:1158+`) and branch on `"warrior" / "mercenary" / "archer"|"ranger" / "wizard"`.

## Dash (for reference)

| Class | Behavior |
|---|---|
| **Warrior** | Vulnerable; on dash end or enemy collision → 32px AoE (2× weapon dmg + lvl×0.5), knockback, 0.8s stun, shockwave. Walls don't end dash. |
| **Mercenary / Archer / Wizard** | Full invuln through dash + linger window. Phases through enemies (so heavy elites can't pin you). |

## Suggested Future Extensions

- **Hammer**: Warrior earthquake (current), Mercenary "Power Slam" (faster cd, smaller AoE), Wizard "Storm Stomp" (chain lightning around the slam).
- **Spear**: Warrior phalanx (current), Mercenary "Lance Charge" (forward dash strike), Archer "Spear-Throw" (auto-throws when activated).
- **Whip**: Warrior "Drag" (pulls heavy enemies toward you), Mercenary crack whip (current), Archer "Lash Shot" (whip strikes from range).

The point is to give every weapon × class combination a distinct verb so you feel different in your hands as a warrior holding a bow vs an archer holding one.
