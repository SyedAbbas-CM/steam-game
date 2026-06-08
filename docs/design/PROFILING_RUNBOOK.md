# Profiling Runbook

This project now has two profiling layers:

1. Godot built-in profiling
2. Game-specific telemetry under `game/*`
3. Saved profiling sessions on disk

Important:

- this profiling stack is `DEBUG ONLY`
- it is intended for editor/debug/dev builds
- release/full builds should not rely on it being active

Use both. The built-in tools tell you where time and memory are going. The custom telemetry tells you what the game was doing when that happened.

## Quick Toggle

- In dungeons and mines, press `9` to toggle the in-game perf overlay.
- `F9` is kept as a fallback, but `9` is the intended key.

Overlay fields:

- `FPS`: current frames per second
- `Frame`: process frame time in milliseconds
- `Mem`: static engine memory in MB
- `VRAM`: render video memory in MB
- `Players`, `Enemies`, `Bullets`, `Hazards`, `Traps`
- `Fire`, `Gas`, `Particles`, `Timers`, `Rooms`
- `Objects`, `Resources`, `Nodes`, `Orphans`

## Saved Sessions

Perf sessions are now written automatically for dungeon and mine scenes.

Location:

- `user://profiling/<timestamp_scene>/`

On macOS in editor/dev builds, `user://` resolves under Godot app data for this project.

Each session folder contains:

- `session.json`
- `snapshots.jsonl`
- `summary.json`

`summary.json` now also contains:

- `suspect_report`
- `baseline_metrics`
- `content_baseline_metrics`
- `delta_metrics`
- `content_delta_metrics`
- `peak_metric_deltas`
- `tracked_script_counts`

What is saved:

- periodic interval snapshots
- scene attach checkpoint
- floor change checkpoints
- elite/super-elite/boss room checkpoints in dungeons
- scene detach summary

Saved data includes:

- live metrics
- metric deltas from session baseline
- metric deltas from first floor-generated content baseline
- tile layer used-cell counts
- breakable cell counts for mines
- group counts
- node class counts
- top script instance counts
- tracked high-signal script counts for traps, enemies, bullets, and pickups
- automatic `spike` snapshots when frame/physics/orphan growth crosses thresholds

Helper script:

```bash
python3 scripts/tools/summarize_profile.py \
  "/Users/developer-cloudprimero/Library/Application Support/Godot/app_userdata/New Game Project/profiling/<session>"
```

## What The Numbers Mean

### Counts that usually indicate gameplay scaling problems

- `Bullets`
- `Hazards`
- `Traps`
- `Fire`
- `Gas`
- `Particles`
- `Timers`

If these climb floor after floor and never settle back down, you likely have accumulation or runaway spawning.

### Counts that usually indicate memory / lifecycle problems

- `Objects`
- `Resources`
- `Nodes`
- `Orphans`

Interpretation:

- `Objects` rising forever: general object accumulation
- `Resources` rising forever: resources being loaded or retained and not released
- `Nodes` rising forever: scene-tree growth or leaked gameplay nodes
- `Orphans` above zero in debug is not enough by itself
- `Orphans` rising materially above baseline is the real leak signal

### Render-side signals

- `VRAM`
- Godot `Video RAM` tab
- Godot built-in draw-call monitors

If `VRAM` climbs or draw calls spike badly after several floors, the issue may be render-side rather than pure script CPU.

## The Correct Run

Do not just open the game, look once, and guess.

Use this exact run:

1. Run the game from the Godot editor in debug.
2. Open:
   - `Debugger -> Monitors`
   - `Debugger -> Profiler`
   - optionally `Debugger -> ObjectDB Profiler`
3. Start a dungeon run.
4. At floor 1 start:
   - press `9`
   - write down the overlay values
5. Play normally for 1 to 3 floors until the lag starts.
6. When the slowdown is visible:
   - press `9` if the overlay is hidden
   - write down the overlay values again
7. Finish the run or leave the scene so the summary is written.
8. Stop and inspect:
   - `Profiler` for hot functions/scripts
   - `Monitors` graphs for `game/*`
   - `ObjectDB Profiler` if object growth is suspected
   - saved files in the latest `user://profiling/...` session folder

## What To Compare

Compare floor 1 start vs slowdown point:

- `Frame`
- `Bullets`
- `Hazards`
- `Particles`
- `Timers`
- `Fire`
- `Gas`
- `Objects`
- `Resources`
- `Nodes`
- `Orphans`
- `VRAM`

This tells you which dimension is actually growing.

Then compare the saved JSON session:

- `baseline_metrics`
- `content_baseline_metrics`
- `delta_metrics`
- `content_delta_metrics`
- `peak_metrics` in `summary.json`
- `tracked_script_counts`
- `final_script_counts`
- `final_node_class_counts`
- `tile_counts` across `snapshots.jsonl`

## When To Use Each Tool

### In-game overlay

Use for:

- fast spot checks
- “does floor 3 have way more bullets/hazards than floor 1?”

### Godot Monitors

Use for:

- graphing `game/*` values over time
- correlating FPS drops with bullet/hazard/particle growth

Important custom monitors:

- `game/frame_time_ms`
- `game/physics_time_ms`
- `game/memory_static_mb`
- `game/video_mem_mb`
- `game/draw_calls`
- `game/enemies_active`
- `game/bullets_active`
- `game/hazards_active`
- `game/particles_active`
- `game/timers_active`
- `game/fire_patches_active`
- `game/poison_clouds_active`
- `game/resource_count`
- `game/object_count`
- `game/orphan_nodes`

### Godot Profiler

Use for:

- identifying hot GDScript functions
- determining whether frame time is dominated by:
  - enemy logic
  - bullet logic
  - traps/hazards
  - dungeon manager work

### ObjectDB Profiler

Use for:

- “what memory is not being freed?”
- “what kinds of objects keep accumulating after floor transitions?”

Recommended snapshot points:

1. start of floor 1
2. end of floor 1
3. start of floor 2
4. slowdown point

Compare diffs across snapshots.

Look for classes that keep climbing:

- `Node2D`
- `Area2D`
- `Timer`
- `Sprite2D`
- `CPUParticles2D`
- custom trap nodes
- bullets
- hazard helpers

## Practical Interpretation

### If `Bullets` spikes hard

Look at:

- bullet lifetime
- bullet cleanup
- boss pattern spam
- enemy projectile count scaling

### If `Hazards`, `Fire`, or `Gas` spikes hard

Look at:

- fire patch spread
- poison cloud duration/count
- barrel aftermath
- trap cleanup

### If `Particles` spikes hard

Look at:

- poison gas visuals
- fire patches
- projectile impact effects
- always-on environment particles

### If `Timers` spikes hard

Look at:

- per-hazard timer creation
- per-projectile timer usage
- repeated deferred work

### If `Nodes` or `Objects` keep climbing

Look at:

- room cleanup
- floor transitions
- leftover helper nodes
- unfreed bullets or hazard aftermath nodes

### If `Orphans` climbs above zero

That is a lifecycle bug. Fix it first.

## Important Constraint

Static memory monitors are debug-oriented engine values. They are useful, but they are not a perfect “real RAM” truth.

For full system-level truth on macOS, use:

- Activity Monitor
- Xcode Instruments

But first use the in-engine tools above. They are cheaper and usually enough to isolate the bad subsystem.

## Current Goal

For the current dungeon slowdown issue, the first useful report is:

- floor 1 overlay values
- slowdown overlay values
- top `Profiler` hotspots
- whether `Objects`, `Resources`, `Nodes`, or `Orphans` are climbing

That is enough to move from guessing to actual diagnosis.
