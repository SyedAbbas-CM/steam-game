# Prompt Templates

Use these as stable starting points. Edit the feature-specific parts only.

## 1. Design Prompt

```text
You are designing a feature for this Godot project.

Before writing the design:
- read docs/workflow/OPERATING_PROCEDURE.md
- read the feature's WORKFLOW_STATE.md if it exists
- state the current workflow step you are operating in

Create a DESIGN.md using this exact structure:
1. Goal
2. Why This Exists
3. Scope
4. Touched Files
5. Architecture
6. Mermaid Flow
7. State Ownership
8. Implementation Phases
9. Risks
10. Verification
11. Approval Gate

Rules:
- Use exact local file paths from this repo.
- Keep phases small and reviewable.
- Prefer extending existing systems over creating duplicate managers.
- Call out save-data risks explicitly.
- If using Mermaid `click` links, target real local files with `vscode://file/...`.

Feature:
[PASTE FEATURE REQUEST]

Current architecture notes:
[PASTE AUDIT / PLAN / ARCHITECTURAL NOTES]
```

## 2. Phase Build Prompt

```text
The DESIGN.md is approved.
Read docs/workflow/OPERATING_PROCEDURE.md and the feature's WORKFLOW_STATE.md first.

Implement ONLY [PHASE NAME].

Rules:
- Touch only these files: [LIST FILES]
- Do not implement later phases.
- Do not make opportunistic cleanup changes.
- If you discover required scope expansion, stop and report it.
- Update the workflow state to the next correct checkpoint before stopping.
- After implementation, summarize:
  - files changed
  - APIs added/changed
  - verification performed
  - review hotspots
```

## 3. Diff Audit Prompt

```text
Review this change as a code reviewer.
Read the feature's WORKFLOW_STATE.md and confirm which checkpoint is under review.

Focus on:
- behavioral regressions
- save compatibility
- scene/tree coupling
- missing verification
- hidden cross-system side effects

List findings first, ordered by severity, with file references.
Keep summaries brief.
```

## 4. Surgical Fix Prompt

```text
Fix only the highlighted issue.

Rules:
- modify the minimum number of files
- preserve the current phase boundary
- do not refactor unrelated code
- explain the specific bug and the narrow fix

Issue:
[PASTE REVIEW COMMENT OR DIFF NOTE]
```

## 5. Parallel Agent Prompt

```text
You own only this write zone:
[ZONE]

Your allowed files:
[FILES OR FOLDERS]

You are not alone in the repo.
Do not revert or reshape files outside your zone.
If the task requires touching a shared file, stop and report it.

Task:
[PASTE SUBTASK]
```

## 6. Verification Prompt

```text
Given this completed phase, produce a verification plan for this Godot repo.
Read docs/workflow/VERIFICATION_CHECKLIST.md and the feature's WORKFLOW_STATE.md first.

Return:
- exact manual test steps
- exact scenes to boot
- save/load checks
- likely regressions
- quick diff-review checklist

Phase summary:
[PASTE SUMMARY]
```

## 7. Workflow State Update Prompt

```text
Update the feature's WORKFLOW_STATE.md.

Rules:
- preserve the existing history section
- update only current step, status, owner, and next gate
- keep it concise
- do not change approved scope unless explicitly told

Inputs:
- completed work summary
- current checkpoint result
- next intended step
```
