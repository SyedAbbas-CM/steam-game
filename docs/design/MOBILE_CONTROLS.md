## Mobile Controls

Current mobile control plan is built on the existing gameplay actions, not a separate ruleset.

### Core movement
- Left stick: movement
- Right stick: aim
- Right stick held off-center: shoot

### Action buttons
- `Interact`: one-tap `interact`
- Free tap in the gameplay area while an interact prompt is visible: also triggers `interact`
- `Sprint`: hold `sprint`
- `Shield`: tap `shield_raise`
- `Power`: hold or tap `dash`

### Bottom bars
- Bottom row: quickbar items `1-6`
- Row above: spell slots `1-6`
- Extra spell-row slot: `stone_toss`

### Supporting buttons
- `BAG`: inventory
- `LOG`: quest log

### Mobile HUD policy
- Mobile forces `GameHUD` instead of `SigilHUD`
- Desktop vertical quickbar/spell columns are replaced by compact bottom bars
- Interact button is lifted above the bottom bars so the rows remain tappable
