class_name AreaMoodProfile
extends Resource

@export var ambient_color: Color = Color(0.9, 0.9, 0.9)

@export_group("Darkness")
@export var is_dark: bool = false
@export var darkness_color: Color = Color(0.03, 0.03, 0.05)

@export_group("Torch Lights")
@export var torch_color: Color = Color(1.0, 0.85, 0.5)
@export var torch_intensity: float = 0.7
@export var torch_radius: float = 80.0
@export var torch_flicker: bool = true
@export var torch_shadows: bool = false

@export_group("Player Lantern")
@export var player_light_radius: float = 100.0
@export var player_light_color: Color = Color(0.95, 0.9, 0.75)
@export var player_light_energy: float = 0.8
@export var player_light_shadows: bool = true

@export_group("Post Processing")
@export var glow_enabled: bool = false
@export var glow_intensity: float = 0.3
@export var glow_bloom: float = 0.1
@export var vignette_strength: float = 0.0
@export var vignette_softness: float = 0.72
@export var vignette_color: Color = Color(0.0, 0.0, 0.0, 0.72)

@export_group("Depth & Atmosphere")
## Tint and alpha used by spawn_fake_shadow() blobs (under props, cliff bases).
@export var fake_shadow_color: Color = Color(0.0, 0.0, 0.0, 0.35)
## Multiplier applied to torch placement counts in level generation. <1 = fewer.
@export var torch_density: float = 1.0
## Multiplier for crystal/ember/etc. ambient prop lights.
@export var emissive_density: float = 1.0
## Default light kind picked by generators when not explicitly set (LightingManager.LightKind enum index).
@export var preferred_light_kind: int = 0
## Fraction of corridors/rooms allowed to stay dark. Higher = more contrast pockets.
@export var darkness_pockets: float = 0.25
