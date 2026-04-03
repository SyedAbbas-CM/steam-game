extends Node

## Autoload that auto-discovers .wav files from assets/sfx/ and plays them by name.
## Usage: SFXManager.play("hit") or SFXManager.play("coin", -5.0, 0.1)
## Toggle: SFXManager.enabled = false to mute all SFX

var enabled: bool = true
var master_volume_db: float = 0.0

const MAX_PLAYERS = 16  # concurrent sounds
const SFX_ROOT = "res://assets/sfx/"

# sound_name → AudioStream
var _sounds: Dictionary = {}
# Pool of AudioStreamPlayer nodes
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0

# Dedup: prevent same sound from stacking excessively
# sound_name → {last_time_msec: int, count_in_window: int}
var _recent_plays: Dictionary = {}
const DEDUP_WINDOW_MSEC: int = 120  # ms window to detect stacking
const MAX_STACKED: int = 2  # max concurrent plays of same sound in window

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_scan_sounds()
	_create_pool()

func _scan_sounds() -> void:
	# Recursively scan assets/sfx/ for .wav files
	_scan_dir(SFX_ROOT)

func _scan_dir(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_scan_dir(path + file_name + "/")
		elif file_name.ends_with(".wav") or file_name.ends_with(".ogg"):
			# Strip extension for the key name
			var key = file_name.get_basename()
			var full_path = path + file_name
			var stream = load(full_path) as AudioStream
			if stream:
				_sounds[key] = stream
		elif file_name.ends_with(".wav.import") or file_name.ends_with(".ogg.import"):
			# Godot imported version — try loading the original path
			var original = file_name.replace(".import", "")
			var key = original.get_basename()
			if not _sounds.has(key):
				var full_path = path + original
				var stream = load(full_path) as AudioStream
				if stream:
					_sounds[key] = stream
		file_name = dir.get_next()

func _create_pool() -> void:
	for i in range(MAX_PLAYERS):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

## Play a sound by name. Optional volume offset (dB) and pitch randomization.
func play(sound_name: String, volume_offset_db: float = 0.0, pitch_variance: float = 0.05) -> void:
	if not enabled:
		return
	if not _sounds.has(sound_name):
		return

	# Dedup: limit stacking of the same sound in a short window
	var now = Time.get_ticks_msec()
	if _recent_plays.has(sound_name):
		var info = _recent_plays[sound_name]
		var elapsed = now - info["last_time"]
		if elapsed < DEDUP_WINDOW_MSEC:
			info["count"] += 1
			if info["count"] > MAX_STACKED:
				return  # skip — too many of same sound at once
		else:
			info["last_time"] = now
			info["count"] = 1
	else:
		_recent_plays[sound_name] = {"last_time": now, "count": 1}

	var player = _get_free_player()
	if not player:
		return
	player.stream = _sounds[sound_name]
	player.volume_db = master_volume_db + volume_offset_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	player.play()

## Play with positional awareness (louder when closer to listener).
## For 2D games, pass the distance from the sound source to the player.
func play_at(sound_name: String, distance: float, max_distance: float = 200.0, volume_offset_db: float = 0.0) -> void:
	if not enabled or distance > max_distance:
		return
	# Linear falloff
	var falloff = clampf(1.0 - distance / max_distance, 0.0, 1.0)
	var db_offset = volume_offset_db + linear_to_db(falloff)
	play(sound_name, db_offset, 0.05)

func _get_free_player() -> AudioStreamPlayer:
	# Round-robin through pool
	for i in range(MAX_PLAYERS):
		var idx = (_next_player + i) % MAX_PLAYERS
		if not _players[idx].playing:
			_next_player = (idx + 1) % MAX_PLAYERS
			return _players[idx]
	# All busy — steal the oldest
	var p = _players[_next_player]
	_next_player = (_next_player + 1) % MAX_PLAYERS
	return p

## Check if a sound exists
func has_sound(sound_name: String) -> bool:
	return _sounds.has(sound_name)

## Get all loaded sound names (for debugging)
func get_sound_list() -> Array:
	return _sounds.keys()
