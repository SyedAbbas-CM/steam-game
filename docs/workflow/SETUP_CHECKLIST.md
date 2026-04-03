# Setup Checklist

This is the practical machine setup for the AI workflow around this Godot repo.

## Priority Order

1. Workflow reliability
2. Review tooling
3. Context packing
4. Editor preview support
5. Terminal quality-of-life

## 1. Required Repo Files

These are already added in this repo:

- [`.repomixignore`](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/.repomixignore)
- [DESIGN_TEMPLATE.md](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/docs/workflow/DESIGN_TEMPLATE.md)
- [AGENT_RULES.md](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/docs/workflow/AGENT_RULES.md)
- [PROMPT_TEMPLATES.md](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/docs/workflow/PROMPT_TEMPLATES.md)
- [VERIFICATION_CHECKLIST.md](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/docs/workflow/VERIFICATION_CHECKLIST.md)

## 2. Install `repomix`

Install globally or run through `npx`.

Examples:

```bash
npx repomix
```

If you prefer a global install, use your normal Node package workflow.

## 3. Run Local Bootstrap

After cloning the repo on a machine, run:

```bash
./tools/workflow/bootstrap_local_workflow.sh
```

This generates machine-local workflow files in `docs/workflow/local/`.

Purpose:

- materialize absolute file links for Mermaid tests
- avoid hardcoding one machine's path in tracked docs
- keep local workflow artifacts out of Git

## 4. Editor Extensions / Features To Install

For Cursor / VS Code:

- primary Mermaid extension: `bierner.markdown-mermaid`
- optional fallback preview stack: `shd101wyy.markdown-preview-enhanced`
- a strong Git history / diff extension if you are not using a separate diff app
- optional file icon theme for readability
- optional Error Lens / diagnostics helper

The critical requirement is:

- Markdown preview must render Mermaid
- local links must stay clickable
- preview must refresh reliably

Cursor install example:

```bash
cursor --install-extension bierner.markdown-mermaid
```

## 5. Diff / Review Tool

Pick one:

- Sublime Merge
- GitKraken
- VS Code Git + extension stack
- any other diff-first Git UI you already trust

Requirement:

- you can review small staged changes quickly
- you can see exactly which files changed per agent phase

## 6. Mermaid Link Validation

Before using the workflow on a real feature:

1. Run the bootstrap script
2. Open `docs/workflow/local/MERMAID_LINK_TEST.local.md`
2. Render the preview
3. Click every node
4. Confirm the editor opens the target file

If this fails, do not depend on Mermaid clicks yet. Use plain markdown links until fixed.

## 7. Agent Layout

Recommended terminal/editor layout:

- Agent A: systems / save / quest work
- Agent B: gameplay / combat / dungeon work
- Agent C: UI / menus / overlays
- Integration owner: reviews diffs and handles shared files

## 8. Verification Commands

Define these for your machine and keep them consistent:

- boot the project
- open the title screen
- start a dungeon run
- return to overworld
- run a battle

If you later script these, add the exact commands to this file.

## 9. Terminal Quality Of Life

Optional but useful:

- Nerd Font
- `starship`
- `eza`
- `bat`
- softer terminal theme with better contrast

These help readability, but they are not the workflow foundation.

## 10. First Dry Run

Run this on a tiny feature:

1. write a `DESIGN.md` from the template
2. create a feature `WORKFLOW_STATE.md` from the template
3. render Mermaid and click the links
4. implement Phase 1 only
5. review the diff
6. run the matching verification checklist
7. adjust prompts only after this loop completes
