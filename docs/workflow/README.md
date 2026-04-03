# Workflow Pack

This folder is the baseline operating system for AI-assisted development in this repo.

Use it in this order:

1. Install and configure the local tooling from [SETUP_CHECKLIST.md](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/docs/workflow/SETUP_CHECKLIST.md).
2. Run the local bootstrap script in [tools/workflow/bootstrap_local_workflow.sh](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/tools/workflow/bootstrap_local_workflow.sh).
3. Filter context with [`.repomixignore`](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/.repomixignore).
4. Start every feature with [DESIGN_TEMPLATE.md](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/docs/workflow/DESIGN_TEMPLATE.md).
5. Track the current step in a feature-local copy of [WORKFLOW_STATE_TEMPLATE.md](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/docs/workflow/WORKFLOW_STATE_TEMPLATE.md).
6. Follow the step gates in [OPERATING_PROCEDURE.md](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/docs/workflow/OPERATING_PROCEDURE.md).
7. Run parallel agents only under [AGENT_RULES.md](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/docs/workflow/AGENT_RULES.md).
8. Use prompts from [PROMPT_TEMPLATES.md](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/docs/workflow/PROMPT_TEMPLATES.md).
9. Verify work using [VERIFICATION_CHECKLIST.md](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/docs/workflow/VERIFICATION_CHECKLIST.md).
10. Confirm local Markdown/Mermaid link behavior with the generated local file in `docs/workflow/local/`.

Suggested first dry run:

1. Run `tools/workflow/bootstrap_local_workflow.sh`.
2. Open the generated Mermaid link test from `docs/workflow/local/`.
3. Generate a repomix snapshot from `new-game-project/`.
4. Use the design prompt template on a dummy feature.
5. Create a feature-specific workflow state file from the template.
6. Implement only Phase 1.
7. Review the diff.
8. Run the matching verification checklist.

Known working Mermaid extension for Cursor:

- `bierner.markdown-mermaid`

Optional fallback if you prefer a larger Markdown workflow:

- `shd101wyy.markdown-preview-enhanced`
