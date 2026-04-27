# Obsidian Code Graph

This folder is the Obsidian-facing architecture layer for the repo.

Purpose:

- give Obsidian graph view clean nodes
- wrap important code files in note pages
- connect code files to system notes and Mermaid docs

Start here:

- [[START_HERE]]
- [[GRAPH_HOME]]
- [[SYSTEMS_INDEX]]
- [[FILES_INDEX]]

Generated code note wrappers live under:

- `docs/obsidian/files/scripts/...`
- `docs/obsidian/files/scenes/...`

System notes live under:

- `docs/obsidian/systems/...`

Regenerate wrappers with:

```bash
cd /Users/developer-cloudprimero/Desktop/Godot/new-game-project
python3 tools/obsidian/generate_code_notes.py
```
