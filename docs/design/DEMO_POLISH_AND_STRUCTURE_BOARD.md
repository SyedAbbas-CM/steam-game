# Demo Polish and Structure Board

Date: 2026-06-18

This is the concrete post-playtest plan. The tester played for roughly three hours because the core dungeon/loot/build loop works. The next phase is not "add more mechanics." The next phase is:

1. Make the writer's story structure real.
2. Stop broken/generated items from entering normal loot.
3. Stop enemies from having unreadable one-shot/multi-hit attacks.

Everything else is secondary until those three pillars are stable.

## Target Demo Shape

The demo should be a structured dungeon crawler, not the whole open-world game.

Player flow:

1. Pick a class.
2. Spawn in Ravenhollow or a tiny demo camp.
3. Talk to the Elder.
4. Choose or accept the first enemy target.
5. Enter a dungeon chain.
6. Find curated loot and build around it.
7. Fight named minibosses.
8. Die or clear the demo boss.
9. Use Hall of Ancestors to recover a limited number of items.

The public demo should answer one question: "Can this dungeon/build game carry a session?"

## Pillar 1: Story and Quest Spine

### Writer Pitch To Use

The tester/writer's pitch:

- The player has one long-term goal: choose or confront an elder evil and destroy it.
- The journey to that enemy is the campaign.
- Every dungeon on the road is a quest step.
- Every dungeon boss can be a quest or subquest.
- Side quests are optional, but they point at places the player already needs to go.
- Bosses have reputations, lieutenants, enemies, victims, and grudges.
- A fallen hero ghost can ask the player to recover his weapon and carry on the fight.

This is stronger than "the Elder tells you to do random chores."

### Demo Story Decision

Use one elder evil for the demo. Do not ask the player to choose between multiple evils yet.

Demo elder evil:

**The Archlich Veyr**

Role:

- Not the final boss of the full game.
- A first major evil under Ravenhollow.
- Controls graves, skeletons, bone knights, and memory-eating ghosts.
- Has one vampire lieutenant deeper in the full game, but the demo only teases that.

Demo location:

**The Barrows Road**

Meaning:

- A chain of grave dungeons south/east of Ravenhollow.
- Each floor is one step toward the Archlich's sealed door.
- The demo ends before the real Archlich fight, or with a weakened projection/avatar.

### Demo Quest Chain

#### MQ-D1: Ash Under Ravenhollow

Giver: The Elder.

Premise: The village dead are not rising randomly. They are marching in the same direction underground.

Player objective:

- Enter the first barrow.
- Find the black stair.
- Kill the named skeleton captain.
- Return with its grave-token.

Short Elder dialogue draft:

> "The dead are walking south."
> "Not wandering. Walking."
> "Bring me what leads them."

Implementation tasks:

- [ ] Create quest resource `mq_d1_ash_under_ravenhollow`.
- [ ] Replace the first visible Elder quest text with short human-written lines.
- [ ] Add a named skeleton captain miniboss to floor 1 or 2.
- [ ] Drop `grave_token` from that captain.
- [ ] Make quest complete on turn-in.

#### MQ-D2: The Road of Names

Giver: The Elder after MQ-D1.

Premise: The grave-token has a name scratched off. Someone is erasing identities from the dead.

Player objective:

- Descend deeper.
- Find 3 name stones.
- Survive an ambush after reading the third stone.
- Unlock the sealed stair.

Short Elder dialogue draft:

> "No name. No rest."
> "Something below is eating the dead twice."
> "Find the missing names before it finds yours."

Implementation tasks:

- [ ] Add 3 interactable name stones across floor 2 or 3.
- [ ] Add quest counter UI update for name stones.
- [ ] Trigger ambush on third stone.
- [ ] Unlock next stair after ambush.

#### MQ-D3: The Fallen Hero

Giver: Ghost of a dead hero inside the dungeon.

Premise: A previous champion failed. Their weapon is still below.

Player objective:

- Find the ghost.
- Recover the ghost's weapon from a miniboss room.
- Either keep it, return it, or bind it at the Hall of Ancestors.

Reward:

- A curated rare weapon with clear mechanics.
- This introduces item recovery and legacy gear.

Short ghost dialogue draft:

> "I made it seven floors."
> "My sword made it eight."
> "If you find it, do better than I did."

Implementation tasks:

- [ ] Create ghost NPC encounter room.
- [ ] Create weapon `oath_remnant` or use a curated existing sword/scythe.
- [ ] Add choice: keep weapon now or bind it for safer recovery after death.
- [ ] Explain Hall of Ancestors item recovery in one line.

#### MQ-D4: The First Door

Giver: automatic after MQ-D2/MQ-D3.

Premise: The player reaches the Archlich's first sealed door, guarded by a projection or lieutenant.

Player objective:

- Clear floor 5 or 6.
- Fight boss: **The Nameless Warden**.
- Demo ends on victory with a tease that the true Archlich is deeper.

Boss identity:

- Big skeletal guardian.
- Slow, readable attacks.
- Summons weak skeletons.
- Has one dangerous telegraphed line attack.

Victory text:

> "The door opens."
> "Behind it, something laughs without lungs."
> "Demo complete."

Implementation tasks:

- [ ] Create `nameless_warden` enemy/boss resource or configure an existing skeleton boss.
- [ ] Add boss room to demo dungeon chain.
- [ ] Add end-of-demo screen.

### Optional Side Quests For Demo

Keep side quests small and tied to the same dungeon.

#### SQ-D1: Three Names, One Stone

Giver: gravekeeper or ghost.

Objective:

- Find 3 grave names in the dungeon.
- Reward: gem shard bundle or socketable ring.

Why it exists:

- Reinforces the name/memory theme.
- Gives the writer a compact emotional quest.

#### SQ-D2: The Butchered Family

Giver: survivor in Ravenhollow.

Objective:

- Kill an optional vampire-touched elite, **Marel the Red-Handed**.

Why it exists:

- Uses writer's idea that bosses have victims and enemies.
- Teases the Archlich's vampire lieutenant without needing full campaign content.

#### SQ-D3: The Weapon That Came Back

Giver: Hall of Ancestors.

Objective:

- Recover any rare weapon after death.
- Teach item recovery.

Why it exists:

- Player missed this in test.
- Makes death less confusing.

## Pillar 2: Items, Loot, and Crafting

### Core Rule

No unreviewed/generated item should drop in the demo.

The tester's strongest item complaint was not "balance is off." It was "these items feel fake." That damages trust. The demo needs fewer items, but every item must feel intentional.

### Demo Loot Pool

Create an explicit curated drop table for demo mode.

Approved demo weapon families:

- Sword: simple reliable projectile pattern.
- Axe: charge/push/barrel interaction.
- Club: STR AoE stun build.
- Staff: INT spellcaster weapon.
- Wand: fast spell-synergy weapon.
- Bow/Short Bow: Ranger precision.
- Shield/Buckler: Merc parry identity.
- Scythe: rare build-around weapon, but only one curated version.

Temporarily exclude from demo drops until audited:

- Whips that behave like swords.
- Random generated weapon names.
- Weapons whose sprite/type/name disagree.
- Crafted weapons with missing skill descriptions.
- Armor with only weird multipliers like gold multiplier.
- Materials with no source.
- Rare fish/octopus/legacy oddities unless they have a mechanic.

### Required Item Audit Fields

Every demo item needs:

- `item_name`
- `item_type`
- Sprite/icon that matches the item.
- Description written by a human.
- Primary stat purpose.
- Scaling stat.
- Attack pattern or defensive effect.
- SHIFT/R/special behavior if any.
- Socket count/type if relevant.
- Drop source.
- Crafting source if craftable.
- Demo approved flag or placement in a curated table.

### Concrete Item Fix List From Tester

- [ ] Gem shards need descriptions.
- [ ] Stone Eye needs description and mechanic, or remove from demo drops.
- [ ] Fire crystals need a source, or remove recipes requiring them.
- [ ] Salvage points need explanation and blacksmith behavior.
- [ ] Barbed whip must either become a real whip or be removed.
- [ ] Crafted bone sword must list its skills.
- [ ] Crafted chainmail cannot have only gold multiplier unless renamed as a greed item.
- [ ] Staff cannot use scroll sprite unless it is intentionally a scroll/tome.
- [ ] Weapon named after grenade cannot be a staff.
- [ ] Bow sprite cannot be a mallet unless the item is intentionally a joke, and demo should avoid joke ambiguity.
- [ ] Slings cannot consume arrows.
- [ ] Bows cannot consume throwing knives.
- [ ] Multishot weapons need sane ammo consumption rules.

### Gem Mosaic Gear

Use tester's idea.

Concept:

- Low base stats.
- More sockets than normal.
- Strong socket multipliers.
- Lets gem/socketing system become a real build path.

Demo item family:

- `Mosaic Cap`
- `Mosaic Vest`
- `Mosaic Buckler`
- `Mosaic Ring`
- `Mosaic Staff` or `Mosaic Blade`

Rules:

- Base stats 30% to 50% lower than same-tier gear.
- +1 or +2 extra sockets.
- Gems socketed into mosaic gear have stronger bonuses.
- Mosaic gear should drop from name/memory/ghost quests, not random barrels.

Implementation tasks:

- [ ] Add mosaic item resources.
- [ ] Add socket multiplier field or hardcoded mosaic bonus.
- [ ] Add one SQ-D1 reward as mosaic gear.
- [ ] Add descriptions explaining the tradeoff.

### Build-Archetype Items

Curate at least four build paths.

STR Bruiser:

- Club with stun AoE.
- Axe with charge/push.
- Heavy armor with clear defense.

Wizard Spellcrafter:

- Staff with INT scaling.
- Wand with lower damage but faster cast synergy.
- Mana/flow gear.

Merc Parry/Crit:

- Buckler/shield with parry stats.
- Dagger/sword with crit/adrenaline synergy.
- Gear that rewards successful parry.

Ranger Precision:

- Bow/short bow with focus or killshot synergy.
- Ammo rules fixed.
- One clean rare bow.

### Loot Table Work

Implementation tasks:

- [ ] Create `resources/drops/demo_dungeon_drops.tres`.
- [ ] Point demo dungeon floors at the curated table.
- [ ] Keep random generation disabled or heavily filtered in demo.
- [ ] Add `demo_approved` metadata or maintain explicit allowlist.
- [ ] Ensure chest/barrel loot uses same curated pool.
- [ ] Ensure boss/miniboss drops include one memorable item, not random filler.

## Pillar 3: Enemies, Attacks, and Scaling

### Core Rule

The player can die fast, but they must know why.

The tester's biggest enemy complaint:

- "You don't know what the scariest guy in the room is until he's already killed you."
- "I still don't know what caused my last two deaths."
- "Damage scaling, especially on multi-hit attacks."

### Death Recap

Add a death recap before tuning everything blind.

Minimum fields:

- Enemy name.
- Attack name.
- Damage taken.
- Number of hits in final second.
- Dungeon name and floor.
- Player level.

Example:

`Killed by Nameless Warden: Bone Lance, 42 damage, 3 hits in 0.8s, Barrows Road F5.`

Implementation tasks:

- [ ] Track last damage source on player.
- [ ] Track attack id/name on bullets/contact hits.
- [ ] Store final 3 seconds of damage events.
- [ ] Show death recap on death screen.

### Demo Enemy Roster

Use fewer enemies with clearer roles.

Floor 1-2:

- Skeleton Grunt: slow chase, low contact damage.
- Bone Archer: slow projectile, clear line of fire.
- Grave Bat: fast but low damage.

Floor 3-4:

- Bone Knight: shield/charge, telegraphed.
- Grave Witch: summons small skeletons, low personal damage.
- Tomb Crawler: area denial puddles, not burst.

Floor 5 boss:

- Nameless Warden: slow boss, summon adds, one telegraphed line attack.

Optional elite:

- Marel the Red-Handed: vampire-touched duelist, clear red aura, lifesteal attack with windup.

Temporarily exclude from demo:

- Enemies with dense multi-hit shotguns.
- Enemies with untelegraphed instant burst.
- Hyper elites that do not have a readable warning.
- Default/unset dungeon enemy pools.

### Attack Rules

Per-hit damage:

- Small bullets: low damage, can appear in patterns.
- Big bullets: medium/high damage, must be slower or telegraphed.
- Contact damage: capped per enemy per interval so collision cannot machine-gun HP.
- Multi-hit attacks: total burst budget must be capped.

Telegraph requirements:

- Any attack that can remove more than 30% HP needs a windup.
- Any elite attack needs unique color/sound.
- Any boss attack needs an animation or ground marker.

Scaling requirements:

- Floor 1 should not kill through mystery burst.
- Floor 2 should not be a sudden difficulty cliff.
- Elite/hyper damage multipliers must be capped for multi-projectile attacks.
- Bosses should be scary by mechanics, not invisible DPS math.

Implementation tasks:

- [ ] Add or expose `attack_name` on enemy attacks/projectiles.
- [ ] Add final-second burst cap for multi-hit attacks, or reduce per-projectile damage based on projectile count.
- [ ] Add contact damage cooldown per source.
- [ ] Add elite visual marker.
- [ ] Add boss windup/telegraph helper.
- [ ] Make demo dungeon use only the curated enemy roster.
- [ ] Remove unset/default dungeon from demo routing.

### Hyper Elite Fix

Hyper elites should feel scary before combat starts.

Required:

- Nameplate.
- Aura/outline.
- Sound cue.
- Slight spawn pause or pulse.
- Attack title in death recap.

Optional:

- Short "BASS" sound is fine, but it must happen before or as the threat appears, not only when the player dies.

## Immediate Implementation Order

Do this order, not random feature work.

1. Create the demo quest chain resources: MQ-D1 to MQ-D4.
2. Write Elder/Ghost/Nameless Warden dialogue.
3. Add curated demo dungeon drop table.
4. Remove unapproved/generated items from demo drops.
5. Fix item descriptions and ammo compatibility.
6. Add death recap and damage-source tracking.
7. Curate demo enemy roster and remove cracked/default pools.
8. Add hyper elite readability.
9. Fix tutorial room 9 or bypass tutorial for demo mode.
10. Build demo candidate.

## Concrete First Commit Target

The first implementation pass should include:

- One demo quest: `mq_d1_ash_under_ravenhollow`.
- One named miniboss: Skeleton Captain or Grave-Captain.
- One curated drop table: `demo_dungeon_drops`.
- One death recap field: last enemy + last attack + damage.
- One item allowlist or `demo_approved` filter.

That gives us a real vertical slice instead of another broad system.

## Do Not Prioritize Yet

- Full RTS/summoner integration.
- Full overworld map rewrite.
- More classes.
- More procedural item generation.
- More random enemies.
- More crafting materials.
- More stealth/rock/light mechanics.
- Mobile/Quest 3 work.

These can return after the demo has a coherent quest, sane loot, and fair enemies.

## Final Summary

The tester's feedback reduces to one practical plan:

**Write the elder-evil dungeon-road story, curate the item pool, and make enemy attacks readable.**

If those three are fixed, the existing buildcraft and dungeon loop are strong enough to demo.
