# Build Commands

## Workflow

For feature work in this repo, follow the workflow pack in `docs/workflow/`.

Required baseline:

1. Read `docs/workflow/OPERATING_PROCEDURE.md`
2. Read `docs/workflow/AGENT_RULES.md`
3. Use `docs/workflow/DESIGN_TEMPLATE.md` for feature design
4. Track progress in a feature-local copy of `docs/workflow/WORKFLOW_STATE_TEMPLATE.md`
5. Use `docs/workflow/VERIFICATION_CHECKLIST.md` before declaring a phase complete

Behavior rules for Claude Code in this repo:

- Always state the current workflow step before substantial feature work.
- Do not skip from design to full implementation.
- Implement only the approved phase.
- Stop at the review gate.
- If multiple agents are active, respect file ownership and shared-file restrictions.

## Android
```
/Users/developer-cloudprimero/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/developer-cloudprimero/Desktop/Godot/new-game-project --export-release "Android"
```
Output: `builds/android/DungeonCrawl.apk`

## Windows
```
/Users/developer-cloudprimero/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/developer-cloudprimero/Desktop/Godot/new-game-project --export-release "Windows Desktop"
```
Output: `builds/windows/DungeonCrawl.exe`

## macOS
```
/Users/developer-cloudprimero/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/developer-cloudprimero/Desktop/Godot/new-game-project --export-release "macOS"
```
Output: `builds/macos/DungeonCrawl.app`

## All Platforms
```
GODOT=/Users/developer-cloudprimero/Downloads/Godot.app/Contents/MacOS/Godot PROJECT=/Users/developer-cloudprimero/Desktop/Godot/new-game-project && $GODOT --headless --path $PROJECT --export-release "Android" && $GODOT --headless --path $PROJECT --export-release "Windows Desktop" && $GODOT --headless --path $PROJECT --export-release "macOS"
```
