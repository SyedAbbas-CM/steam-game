# Workflow State

## Feature

Feature name: Coop Dungeon (Boss Arena)

Owner: Claude (sole agent)

Integration owner: Claude (sole agent)

## Current State

Current step: Phase 2 + 2.5 verification

Current phase: post-Phase-2.5, awaiting two-Mac test before Phase 3

Status: built 2026-05-24 10:56; user testing

Branch: (working in main checkout, no branch yet)

## Approved Scope

- (pending) Phase 1 — visibility MVP: shared dungeon seed, peer-aware player spawning, position broadcast at 20 Hz via @rpc.

## Approved Files

- (pending — see "Touched Files / Phase 1" in `docs/design/coop_dungeon.md`)

## Active Agents

- Agent name: Claude
  zone: systems + gameplay (sole owner)
  files: see design doc
  status: design drafted, awaiting approval

## Current Gate

User reviews `docs/design/coop_dungeon.md`, approves or amends Phase 1 scope and file list, and explicitly authorizes implementation start.

## Last Completed Checkpoint

- Code audit confirming current multiplayer is transport-only (no @rpc, no sync, no seed, no peer-player spawn). Documented in design doc "Why This Exists" section.

## Next Action

Await design approval. On approval, implement Phase 1 only and stop at the Phase 1 review gate.

## Risks / Notes

- `game_manager.gd` is on the shared-file list — Phase 1 touches it with a small additive change (one param + one branch). Flagged in design "Risks" section.
- `dungeon_manager.gd` uses raw `randi()` ~50 times. Phase 1 uses global `seed()` rather than refactoring to a local `RandomNumberGenerator`. Refactor deferred to Phase 4.

## History

- 2026-05-24 — initialized workflow state; design doc drafted at `docs/design/coop_dungeon.md`.
- 2026-05-24 — Phase 1 (visibility MVP) shipped and verified on two Macs.
- 2026-05-24 — Phase 2 (host-authoritative enemies, deterministic network IDs from room+index, 10Hz snapshot, missing-id = cull) + Phase 2.5 (player anim/dir broadcast + ghost-side PlayerAnimator) shipped. Awaiting user verification.
