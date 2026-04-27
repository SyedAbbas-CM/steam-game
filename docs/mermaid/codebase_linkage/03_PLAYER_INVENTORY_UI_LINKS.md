# Player Inventory UI Links

## Player-Centered Connection Map

```mermaid
flowchart TD
    P["player.gd"] --> LS["level_system"]
    P --> EQ["equipment_manager.gd"]
    P --> WS["weapon_system"]
    P --> SE["status_effect_manager"]
    P --> SB["spell_book"]

    EQ --> INV["inventory data"]
    EQ --> GM["GameManager save hooks"]
    EQ --> SFX["SFXManager"]
    EQ --> VFX["VFXManager"]

    HUD["game_hud.gd"] --> P
    HUD --> EQ

    INVUI["inventory_screen.gd"] --> EQ
    INVUI --> P

    OW["overworld.gd"] --> HUD
    OW --> INVUI
    DG["dungeon_scene.gd"] --> HUD
    DG --> INVUI
```

Core files:

- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/player.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/player.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/stats/equipment_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/stats/equipment_manager.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/ui/game_hud.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/ui/game_hud.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/ui/inventory_screen.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/ui/inventory_screen.gd)

## Data And Signal Flow

```mermaid
flowchart LR
    GM["GameManager"] --> P["Player load/setup"]
    P --> Sig["hp/mp/stamina/xp/shield signals"]
    P --> EQ["EquipmentManager"]
    EQ --> UISig["inventory_changed
    stats_changed"]
    Sig --> HUD["GameHUD"]
    UISig --> HUD
    UISig --> INV["InventoryScreen"]
```

## Why This Cluster Matters

- `player.gd` is not just movement/combat; it is also a local integration root
- `EquipmentManager` is the real inventory/equipment persistence bridge
- `GameHUD` and `InventoryScreen` are consumers of player and equipment state, not owners

## Good Future Branch Boundary

This cluster can later be separated into:

- `player-runtime`
- `inventory-equipment`
- `player-ui`

