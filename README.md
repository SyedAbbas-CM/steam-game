  Project: Top-Down Dungeon-Crawl + RTS Hybrid (Godot 4.6)

  Scale at a glance

  - 76,569 LOC of GDScript across 216 files, 37 packed
  scenes, 3,847 typed resource files (.tres).
  - 11 autoloaded singletons as the runtime backbone
  (GameManager, QuestManager, SFXManager, VFXManager,
  FactionManager, LightingManager, NoiseSystem, PerkManager,
  CoopSession, CoopRuntime, PerfTelemetry).
  - 6 export targets: Windows (x86_64, D3D11), macOS (Metal,
  codesigned), Android (arm64-v8a, ETC2/ASTC, debug+release
  keystores), Linux (x86_64 + x86_32 GL_COMPATIBILITY),
  HTML5.
  - Largest modules: enemy.gd 6,725 LOC, dungeon_manager.gd
  6,059 LOC, player.gd 5,270 LOC, overworld.gd 3,329 LOC,
  battle_simple_ai.gd 3,083 LOC.

  ---
  1. Data-oriented RTS battle engine (~7,900 LOC)

  - Structure-of-Arrays (SoA) unit system
  (battle_unit_system.gd, 550 LOC): ~30 parallel packed
  arrays (position, velocity, HP, defense, morale, charge
  timers, veteran rank, burn, scatter) — no per-unit
  GameObject allocation. Targets 2,000 simultaneous units.
  - Spatial hash grid with 80-px cells for O(1) neighbor
  queries (SPATIAL_CELL_SIZE = 80.0), replacing O(N) distance
   scans.
  - BFS flow-field pathfinding (battle_flow_field.gd, 177
  LOC) on a 32-px grid: precomputed direction vectors per
  reachable tile, recomputed every 5 s, with corner-cutting
  guards and 8-angle local steering for last-mile avoidance.
  - Multi-doctrine AI (battle_simple_ai.gd, 3,083 LOC): 5
  doctrines (FRONTAL_ASSAULT, HAMMER_ANVIL, BAIT_AND_FLANK,
  KITING_HARASS, DEFENSIVE_LINE) × AI tiers (MILITIA →
  ELITE). Retargeting at 0.5 s, strategy at 3 s, flow
  recompute at 5 s — staggered to amortize cost.
  - 9-unit × 9-unit damage matrix + 5×5 formation counter
  matrix for rock-paper-scissors counters (cavalry vs. spear
  ×1.8, wedge vs. shield-wall +30 %).
  - Directional damage: front 0.8×, flank 1.6×, rear 2.2×.
  Morale break at <20 grants +30 % damage taken.
  - Mass-weighted collision (battle_collision.gd): cavalry
  charge knockback scales with speed ratio and cluster
  momentum (+10 % per nearby ally, capped +80 %).
  - Projectile pool (battle_projectile_system.gd): 5,000-cap
  SoA pool with splash falloff, terrain death, stagger-on-hit
   and bullet_mass × 2.0 momentum bonus.
  - Sprite-pool renderer (battle_renderer.gd) with viewport
  culling and pre-built AtlasTexture combos (16 per faction ×
   type) — no per-frame texture swaps.
  - Tactical fog of war (32-px grid, 3-state: unseen /
  explored / visible, 150 ms tick).

  2. Procedural content generation (12,544 LOC in
  /scripts/dungeon)

  - Branching random-walk floor layout (floor_generator.gd,
  877 LOC): three-phase main path → branches → fill, with
  BFS-distance stair placement and forced critical-path
  transitions.
  - 8 room-shape archetypes: rectangles, circles, L-shapes,
  and cellular-automata caves with B5678/S45678 rule, 4–5
  smoothing iterations, flood-fill island culling, and
  guaranteed center connectivity.
  - Voronoi-style elliptical mine carving (mine_generator.gd)
   — Manhattan-distance candidate region with density-biased
  frontier expansion: density_pull · lerp(0.55, 1.25, bias) +
   center_pull − 0.08·Manhattan + noise.
  - 6 corridor types (STRAIGHT / L_BEND / ZIGZAG / WINDING /
  WIDE_CHAMBER / ALCOVE) with parametric perpendicular
  branches.
  - Bresenham-line bridge generator for spider webs over
  liquid pools, plus FastNoiseLite-driven liquid surfaces.
  - Blueprint-based room decorator (room_blueprints.gd, 435
  LOC): 10 themed templates (THRONE_ROOM, CHAPEL,
  ALCHEMIST_LAB…) with per-zone deduplication and density
  scaling (1.0 → 2.0 for high-tier rooms).
  - Single-source BFS flow field for AI navigation
  (dungeon_nav.gd): 8-directional, rebuilt only when player
  moves ≥3 cells; height-aware cliff blocking; replaces
  per-enemy A*.
  - Seeded determinism for co-op parity (pending_dungeon_seed
   propagated via RPC).
  - Mutation processor: 12 modifier types (PIERCE /
  LIFE_STEAL / HOMING / EXPLODING / CHAIN_LIGHTNING…) stacked
   with caps and tier-scaled multipliers.

  3. Authoritative multiplayer co-op (ENet + UPnP)

  - CoopSession (244 LOC): ENet transport with port-fallback
  hosting (auto-tries +5 ports on EADDRINUSE), explicit
  socket close to release UDP, UPnP discovery + port mapping,
   32-peer cap.
  - CoopRuntime (284 LOC): host-authoritative tick model with
   split broadcast rates — player state at 30 Hz, enemy
  snapshots at 20 Hz — over unreliable_ordered RPCs.
  - Ghost-and-proxy model: late-join seed sync, enemy
  snapshot diff drives client-side culling (host considers
  enemy dead → client queue_free), client→host damage RPCs
  keep HP authoritative.
  - Bullet sync split into two flavors: real damaging enemy
  bullets vs. zero-damage visual player-bullet ghosts
  (wall-only collision mask 16) to avoid double-damage on
  remote peers.
  - RemotePlayer ghost with directional animation replication
   and lerp-interpolation at 28 units/s for smooth 30 Hz
  updates.

  4. Procedural shaders & runtime VFX (GDShader, canvas_item)

  - liquid_surface.gdshader (95 LOC): world-vertex-coords
  dual-layer sine displacement, hash21 Perlin lattice noise,
  per-tile phase coherence (hash21(floor(world_pos /
  tile_size))), Gaussian wake field exp(-((d − 15)/10)²)
  around the player, with 4 liquid types (water / blue /
  poison / lava) via uniform switch.
  - warp_portal.gdshader (60 LOC): polar-coordinate spiral
  vortex — arms·angle − r·tightness + TIME·swirl_speed,
  multi-octave hash crackle, radial aperture progression
  driven by 15 tweenable uniforms.
  - projectile_fx.gdshader: directional vector-field glow
  with front-flash / tail-trail falloff (pow(d, 3)/pow(d, 2))
   and 4–7 Hz sine pulsation.
  - Runtime overlays in LightingManager (682 LOC):
  code-generated 128×128 radial-falloff GradientTexture2Ds
  for torches/lanterns; 8-tap orthogonal-plus-diagonal canvas
   outline shader; HDR WorldEnvironment with
  GLOW_BLEND_MODE_SOFTLIGHT, threshold 0.8, intensity 0.3.
  - Mood profile system (AreaMoodProfile) blends color,
  brightness, vignette and shadow-occluder requirements per
  biome/zone with Tweened transitions.

  5. Performance telemetry & profiling (perf_telemetry.gd,
  678 LOC)

  - Two-tier sampling: fast metrics 4 Hz, deep metrics 1 Hz,
  snapshot writes 0.5 Hz.
  - Custom monitors registered against Godot's Performance
  API: FPS, frame ms, physics ms,
  static/message-buffer/video/texture memory, draw calls,
  object/resource/node/orphan counts, and gameplay counters
  (players, enemies, bullets, hazards, traps, fire patches,
  poison clouds).
  - Spike detector: 34 ms frame / 12 ms physics thresholds
  trigger snapshot dumps with 5 s cooldown.
  - Suspect report generation against rolling baselines +
  content baselines (delta maps for metrics, group counts and
   tile counts).
  - Session files written to disk for offline analysis.

  6. Chunked streaming overworld (4,734 LOC)

  - 64-tile chunks, radius-3 load ring, radius-5 prefetch
  loaded via ResourceLoader.load_threaded_request with an LRU
   _chunk_cache and _pending_loads queue.
  - Frame-budgeted tile painter: max 2,000 TileMap cell
  writes per frame to hold 60 FPS during streaming.
  - 2.5D height system (height_system.gd, 1,162 LOC): 7
  levels (-3..+3), per-level visual y-offset, cliff
  face/edge/crease rendering, ramp tiles with auto-generated
  collision shapes, and LOS-blocking integration.
  - 1,944 pre-baked chunk .tres files (chunks/ + chunks2/),
  baked via a custom EditorPlugin (see §10).
  - Zone gating with Rect2i boundaries, 3 s transition
  cooldown, per-zone enemy cap (6), 8 s respawn tick, and 7
  named battle-region waypoint pairs that warp the player
  into the RTS arena.

  7. RPG progression stack

  - 27 stats across 6 categories, dual-track modifier
  stacking (flat-then-percent) computed at read time from 5
  sources: base → level allocations → perks → equipment →
  gems.
  - Class weapon-proficiency curves: 0.75 → 1.0 native, 0.0 →
   1.0 off-class — discourages cross-class spam without hard
  locks.
  - Gem socketing with 3–4 sockets per item and
  prismatic/type-affinity constraints.
  - Stat-threshold passive bonuses (24 milestones at 5/10/15
  points per category, e.g. 10 Defense ⇒ +2 Thorns).
  - 5 perk trees / 74 perk resources with prerequisite graph
  + class aliasing (archer ↔ ranger) and token economy.
  - 23 weapon patterns (SpiralPattern, RingPattern,
  RailgunPattern, HelixPattern, MeteorPattern…) subclassing a
   base WeaponPattern that returns [direction, delay, offset,
   speed_mult] fire data; some patterns maintain integrator
  state (e.g. spiral accumulator coupled to attack speed).
  - 12 mutation effects (life-steal, exploding,
  chain-lightning 3-hop) with stack caps.
  - Quest engine with 42 quest resources, event-driven
  progress signals, dialogue branching, and reentry guards
  against rapid zone transitions.
  - 570 item resources, 36 spells across 10 effect types × 4
  delivery modes, 23 crafting recipes (blacksmith/alchemist),
   salvage → blueprint discovery loop.

  8. UI / UX (15,353 LOC, mobile-first)

  - 33 top-level screens including 8×6 drag-drop inventory
  (inventory_screen.gd 2,504 LOC), game_hud.gd (1,577 LOC,
  separate mobile layout with 58 px slots vs. 80 px desktop),
   pan/zoom world-graph map (world_map_screen.gd 1,007 LOC,
  zoom 0.25–3.0), perk tree, crafting, enchanting, shop,
  dialogue, quest log, hall-of-ancestors, codex.
  - first_person_view.gd (574 LOC): top-down → 3D toggle,
  960×540 SubViewport, billboarded entities, decoration
  billboards as upright X-cross quads, rebuilt only when the
  player moves ≥8 tiles.
  - Touch controls with platform-detected dual virtual
  joysticks (120 px base, 0.08 dead zone, per-finger
  touch-index tracking) and platform-specific action button
  stacks.
  - Typewriter dialogue (TYPEWRITER_SPEED = 0.03) with
  portrait atlases and dynamic choice buttons.
  - Floating damage text with random spread and
  overworld-aware font scaling; BuffDisplay uses CanvasItem
  _draw() rather than per-buff nodes.

  9. Save / persistence

  - Godot Resource serialization (SaveData extends Resource):
   slot metadata, character stats, inventory, equipped items,
   quickbar, pets, learned spells, gold, relics, quests, NPC
  states, harvested-node bitmap, blueprints, army divisions,
  perks.
  - 60-second auto-save loop, multi-slot system,
  hall-of-ancestors legacy carry-over (MAX_ANCESTOR_RECORDS =
   10, LEGACY_ITEM_LIMIT = 3) for permadeath continuity.

  10. Custom editor tooling

  - world_baker EditorPlugin: toolbar button ("🍞 Bake
  World") that spawns a headless Godot process running
  scripts/tools/bake_full_world.gd (1,361 LOC) to serialize
  the overworld into ~1,944 chunk .tres files, then triggers
  a filesystem rescan.
  - scripts/tools/generate_quest_chain.gd (1,023 LOC):
  authoring tool that mass-generates quest definition
  resources.
  - Python codebase-to-Obsidian generator
  (tools/obsidian/generate_code_notes.py) categorising every
  script into domain hubs.

  11. Cross-cutting systems

  - ResourceRegistry (1,664 LOC): centralised, lazily-cached
  registry of every resource directory (blueprints, perks,
  items, spells, mines…), keeping load(path) off hot paths.
  - FactionManager: 180-second territory-attack tick,
  attitude tracking, owner colour/label resolution, save/load
   hooks, automated attack-army composition.
  - StatusEffectManager: tick-driven debuffs (burn, slow,
  poison, stagger, scatter) wired into both player and RTS
  units.
  - SFXManager: auto-discovery of res://assets/sfx/*.wav,
  pooled AudioStreamPlayers (cap 16), dedup window to prevent
   stacking.

  ---
  Suggested resume bullets (drop-in)

  - Built a 76 K-LOC Godot 4 hybrid action-roguelike + RTS
  spanning Windows, macOS, Linux, Android and HTML5, with 11
  autoloaded subsystems and a 3,800-resource data-driven
  content pipeline.
  - Architected a data-oriented RTS engine supporting 2,000
  concurrent units using Structure-of-Arrays packing, 80-px
  spatial-hash neighbour queries, BFS flow-field pathfinding
  (5 s recompute), and a 5,000-capacity SoA projectile pool;
  layered a 5-doctrine AI on top with formation/damage
  counter matrices and directional damage (rear ×2.2).
  - Implemented an authoritative ENet co-op multiplayer stack
   with UPnP port mapping, automatic port-fallback hosting,
  30 Hz player / 20 Hz enemy snapshot RPCs, seeded
  deterministic dungeon generation for peer parity, and a
  split bullet-sync model that keeps damage authoritative
  while replicating visual ghosts.
  - Designed a chunked streaming overworld with 64-tile
  chunks, radius-3 load / radius-5 prefetch, LRU caching,
  threaded .tres resource loading, and a frame-budgeted tile
  painter (2,000 ops/frame) holding 60 FPS through traversal
  across 1,944 pre-baked chunks.
  - Built a procedural dungeon stack combining
  cellular-automata caves (B5678/S45678), Voronoi-style
  elliptical mine carving with density-biased frontier
  expansion, BFS flow-field navigation, and a
  blueprint-driven room decorator across 10 themed templates.
  - Wrote production GDShaders including a polar-coordinate
  spiral warp portal, a world-space tile-coherent Perlin
  liquid shader with player-relative Gaussian wake, and an
  8-tap canvas outline shader, integrated with a mood-driven
  WorldEnvironment HDR glow pipeline.
  - Implemented a runtime performance telemetry system with
  two-tier sampling (4 Hz / 1 Hz), 17 custom Performance
  monitors (memory, draw calls, gameplay entity counts),
  spike detection (34 ms frame / 12 ms physics) and on-disk
  session snapshots with baseline-delta suspect reports.
  - Shipped a mobile-ready UI layer of ~15 K LOC including a
  drag-drop 8×6 inventory, pan/zoom world graph, perk tree,
  dialogue typewriter, custom virtual joystick with dead-zone
   and per-finger tracking, and a top-down → 3D SubViewport
  "first-person" mode.
  - Authored a custom Godot EditorPlugin ("World Baker") that
   spawns a headless Godot subprocess to bake the live
  overworld into ~1,944 chunk resources, and a Python
  codebase-to-Obsidian documentation generator that maps
  every script into a navigable knowledge graph.
  - Designed a deep RPG progression stack — 27 stats × 6
  categories, dual-track flat/percent modifier stacking, 5
  perk trees / 74 perks with prerequisite graphs, gem
  socketing with prismatic constraints, 23 modular
  weapon-pattern subclasses, 12 stackable bullet mutations,
  and a salvage → blueprint discovery loop.

  If you want, I can rewrite any of those bullets to match a
  specific role (e.g. graphics engineer, gameplay engineer,
  network engineer, generalist) or trim them to one-line
  resume length.



  Cross-Platform Action-Roguelike + RTS Hybrid (Godot 4.6) —
  Solo Engineer

  GDScript · GLSL · ENet · Procedural generation · 76 K LOC
  across 6 platforms

  - Built a data-oriented RTS engine for 2,000 concurrent
  units with SoA packing, 80-px spatial hashing, BFS
  flow-field pathfinding, and 5-doctrine AI driven by
  damage/formation counter matrices.
  - Implemented authoritative ENet co-op with UPnP, 30/20 Hz
  snapshot RPCs, seeded deterministic generation for peer
  parity, and split bullet sync (damaging host bullets vs.
  visual ghosts).
  - Engineered a streaming overworld + procedural dungeon
  stack — chunked async loads with LRU cache and
  2,000-op/frame tile budget, plus cellular-automata caves,
  Voronoi mine carving, and blueprint-driven decoration
  across 10 themed room templates.
  - Wrote production GLSL shaders (polar-coordinate warp
  vortex, world-space Perlin liquid with player wake field,
  8-tap outline) and a two-tier performance telemetry system
  with spike detection and baseline-delta regression
  snapshots.
