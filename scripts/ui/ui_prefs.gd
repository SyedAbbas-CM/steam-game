class_name UIPrefs
extends RefCounted

## Static UI preferences. Lives in memory only (resets per session).
## Set from the title screen or via in-game F11 toggle.

static var use_sigil_hud: bool = true

## Toggle between Sigil HUD (orbs) and the classic GameHUD (bars).
static func toggle_hud() -> bool:
	use_sigil_hud = not use_sigil_hud
	return use_sigil_hud
