# World Editor Audit

## Current Architecture

The project currently has three overlapping world-editor paths:

1. `scripts/tools/world_editor.html`
   - A large standalone HTML editor.
   - Appears to be the original browser-based editing surface.

2. `scripts/tools/electron-editor`
   - Electron shell around `app/index.html`.
   - This is the newer desktop editor packaging path.
   - `main.js` is thin; most logic is embedded directly in the HTML app.

3. `scripts/tools/world_editor_server.py`
   - Flask backend serving zone, quest, shop, and NPC-script data from `.tres` files.
   - Provides light CRUD-style JSON APIs and serves the editor frontend.

The runtime game does not directly use the Electron app. The editor writes staging data, and import scripts then merge that into Godot world assets.

## Import Pipeline

The main import path is:

- `scripts/tools/import_editor_map.py`

This pipeline currently:

1. Copies `resources/world/chunks` to `resources/world/chunks2` if needed.
2. Applies editor tile diffs into `chunks2`.
3. Applies zone overrides.
4. Applies NPC position edits.
5. Applies player spawn edits.
6. Applies enemy spawn regions.
7. Applies waypoints.
8. Rebuilds `scenes/overworld/overworld2.tscn` and `scenes/overworld/overworld2.scn`.

This means:

- `chunks` / `overworld` = main runtime world
- `chunks2` / `overworld2` = editor staging world

That split is useful, but it duplicates a large amount of data and contributes significant repo size.

## What The Editor Already Supports

From `scripts/tools/electron-editor/app/index.html`, the current editor already exposes a surprising amount of authoring functionality:

- tile paint
- pan
- notes
- undo / redo
- labels toggle
- NPC toggle
- quest toggle
- spawn placement
- region placement
- waypoint placement
- find / replace
- tabs for:
  - palette
  - info
  - NPCs
  - exits
  - notes
  - quests
  - selection
  - ideas

Region types currently visible in the UI:

- `area`
- `enemy_spawn`
- `safe_zone`
- `boss_arena`
- `trigger`
- `npc_patrol`

Local save data currently includes:

- `layer_paints`
- `terrain_paints`
- `custom_areas`
- `npc_moves`
- `zone_overrides`
- `npc_dialogue`
- `player_spawn`
- `waypoints`

## Current Problems

### 1. The editor is too monolithic

The Electron frontend is shipping a massive embedded `WORLD_DATA = {...}` blob directly inside `app/index.html`.

That causes:

- poor maintainability
- hard-to-review editor changes
- unnecessary duplication of content
- larger editor artifacts than necessary

The editor should load world data externally from JSON or backend APIs, not bake the whole thing into the HTML source.

### 2. The frontend has visible duplication / drift

The current HTML app contains duplicated controls and likely duplicated event wiring. For example:

- repeated `Region` button
- repeated `Waypoint` button
- repeated waypoint popup blocks

That suggests the UI evolved by copy-paste instead of component cleanup. It increases fragility and makes non-technical editor UX worse.

### 3. The staging-world model is expensive

Current world sizes:

- `resources/world/chunks`: about `80M`
- `resources/world/chunks2`: about `80M`
- `scenes/overworld`: about `216M`

So the editor workflow keeps a second full chunk tree plus alternate overworld scenes. That is convenient, but expensive.

### 4. The editor is inside the game project root

Current tooling sizes:

- `scripts/tools`: about `1.6G`
- `scripts/tools/electron-editor`: about `1.6G`

This includes:

- Electron build outputs
- packaged editor apps
- `node_modules`

This is repo bloat, and it also increases the risk of export leakage if exclude filters are imperfect.

### 5. The current editor is still technical in the wrong places

It has raw capability, but it is not yet structured around non-technical workflows like:

- "place quest giver"
- "define patrol"
- "make a town boundary"
- "set region as safe"
- "connect NPC to quest chain"
- "validate missing references"

It feels like a flexible paint-and-metadata editor, not yet a proper content authoring tool.

## Is The World Editor Causing Game Bloat?

Yes, but there are two separate kinds of bloat:

### Repo bloat: definitely yes

The Electron editor inside `scripts/tools` is a major source of repository size. It is over `1.6G` by itself.

### Runtime build bloat: partially yes

The editor is not the only reason the runtime build was large. The bigger runtime issue was duplicated world/staging data:

- `chunks2`
- `overworld2`
- `overworld_loy_original`

Those were accidentally being exported and were already stripped from the shipping builds.

The remaining risk is that keeping the editor under `res://scripts/tools` makes it easier for Godot exports to accidentally pull in editor assets if filters are wrong or if imported resources remain reachable.

So the correct answer is:

- the editor is a major repo bloat source
- the staging world is a real build bloat source
- both should be addressed

## What The Editor Needs Next

To make worldbuilding easier for non-technical people, the editor should move from "generic paint + metadata" to "authored gameplay tools."

### 1. Boundary / region authoring

Needed:

- town boundaries
- quest regions
- RTS territory regions
- danger / safe zones
- event trigger regions
- boss arena bounds
- encounter leash regions

This should become first-class editor data, not just generic custom areas.

### 2. NPC authoring tools

Needed:

- place NPC by clicking world
- assign role:
  - quest giver
  - vendor
  - trainer
  - patrol
  - RTS unit
- patrol path editing
- dialogue script linking
- schedule / state hooks later

### 3. Quest authoring tools

Needed:

- visual quest chain graph
- link giver and turn-in NPCs
- region/objective linking
- click-to-assign target area
- validation for missing NPCs, locations, or prerequisites

### 4. Spawn and encounter tools

Needed:

- spawn-region painting with weights
- pack composition
- elite / boss tags
- biome validation
- dungeon entrance metadata
- mine / RTS event hook regions

### 5. Validation layer

Needed:

- orphan waypoint detection
- invalid exits
- overlapping region warnings
- missing quest references
- invalid NPC script references
- unreachable content markers

### 6. Better data separation

Needed:

- editor state files outside HTML
- backend-driven loading
- smaller exportable JSON bundles
- runtime world data clearly separated from editor-only data

## Recommended Structural Changes

### Short term

1. Keep the current editor working.
2. Clean the duplicated UI blocks in `electron-editor/app/index.html`.
3. Stop embedding giant `WORLD_DATA` directly into the HTML app.
4. Add missing non-technical authoring workflows on top of current data model.

### Mid term

1. Move the editor out of the Godot runtime project tree.
   - Best option: sibling repo or sibling folder outside `res://`.
2. Replace `chunks2` with a lighter staging diff model if possible.
3. Make `custom_areas` evolve into formal gameplay-region resources.

### Long term

Build a content-authoring layer around:

- towns
- quest hubs
- NPC graphs
- region semantics
- RTS territories
- encounter / spawn authoring

That is the path from "powerful internal map editor" to "usable worldbuilding tool."

## Recommended Next Actions

1. Search for any live runtime references into `scripts/tools` and remove them.
2. Move or isolate the Electron editor from the runtime project tree.
3. Refactor the frontend so it loads data externally instead of embedding `WORLD_DATA`.
4. Add first-class region/boundary tools for:
   - towns
   - quest zones
   - RTS zones
   - safe zones
   - boss arenas
5. Add quest/NPC validation and click-based assignment tools.

## Bottom Line

The editor is real and useful, but it is currently:

- too heavy
- too duplicated
- too staging-oriented
- not yet ergonomic enough for non-technical content creation

It is also absolutely part of the project's bloat story, especially at the repo/tooling level. The right fix is not deleting it. The right fix is separating runtime assets from editor assets and turning the editor into a cleaner authoring pipeline.
