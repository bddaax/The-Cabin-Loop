
extends Node

enum HintType {
	CLOCK_WRONG,
	HOLLOW_STEPS,
	CREAK,
}

enum AmbientType {
	MENU,
	FOREST,
	LIVING_ROOM,
	CORRIDOR,
	DARK_CORRIDOR,
	FINAL,
}

const HINT_CUTOFF_LEVEL: int = 3

@export var ambient_player: AudioStreamPlayer

@export var hint_player: AudioStreamPlayer

@export var hollow_steps_player: AudioStreamPlayer

var _audio_streams: Dictionary = {
	"hint_clock":         null,
	"hint_creak":         null,
	"hint_hollow_steps":  null,
	"ambient_menu":       null,
	"ambient_forest":     null,
	"ambient_living":     null,
	"ambient_corridor":   null,
	"ambient_dark":       null,
	"ambient_final":      null,
}

var _current_level: int = 0
var _hints_enabled: bool = true
var _hollow_audible: bool = false

func _ready() -> void:
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.game_state_changed.connect(_on_game_state_changed)

	if not is_instance_valid(ambient_player):
		ambient_player = AudioStreamPlayer.new()
		ambient_player.bus = "Master"
		ambient_player.volume_db = -6.0
		add_child(ambient_player)

	if not is_instance_valid(hint_player):
		hint_player = AudioStreamPlayer.new()
		hint_player.bus = "Master"
		hint_player.volume_db = -8.0
		add_child(hint_player)

	if not is_instance_valid(hollow_steps_player):
		hollow_steps_player = AudioStreamPlayer.new()
		hollow_steps_player.bus = "Master"
		hollow_steps_player.volume_db = -6.0
		add_child(hollow_steps_player)

	_try_load_audio_streams()

	print("[AudioManager] Ready. Hint audio active up to level %d." % HINT_CUTOFF_LEVEL)

func play_hint(hint_type: HintType) -> void:
	if not _hints_enabled:
		return
	if _current_level > HINT_CUTOFF_LEVEL:
		return

	if not is_instance_valid(hint_player):
		return

	var stream: AudioStream = null
	match hint_type:
		HintType.CLOCK_WRONG:
			stream = _audio_streams.get("hint_clock")
		HintType.HOLLOW_STEPS:
			stream = _audio_streams.get("hint_hollow_steps")
		HintType.CREAK:
			stream = _audio_streams.get("hint_creak")

	if stream == null:
		print("[AudioManager] HINT (no audio file): %s at level %d" % [HintType.keys()[hint_type], _current_level])
		return

	hint_player.stream = stream
	hint_player.play()
	print("[AudioManager] Played hint: %s" % HintType.keys()[hint_type])

func play_ambient(ambient_type: AmbientType) -> void:
	if not is_instance_valid(ambient_player):
		return

	var key := ""
	match ambient_type:
		AmbientType.MENU:          key = "ambient_menu"
		AmbientType.FOREST:        key = "ambient_forest"
		AmbientType.LIVING_ROOM:   key = "ambient_living"
		AmbientType.CORRIDOR:      key = "ambient_corridor"
		AmbientType.DARK_CORRIDOR: key = "ambient_dark"
		AmbientType.FINAL:         key = "ambient_final"

	var stream: AudioStream = _audio_streams.get(key)
	if stream == null:
		print("[AudioManager] Ambient placeholder: %s" % AmbientType.keys()[ambient_type])
		return

	if ambient_player.stream == stream and ambient_player.playing:
		return

	ambient_player.stream = stream
	ambient_player.play()

func set_hollow_audible(is_audible: bool) -> void:
	_hollow_audible = is_audible and (_current_level <= HINT_CUTOFF_LEVEL)

	if not is_instance_valid(hollow_steps_player):
		return

	if _hollow_audible:
		var stream = _audio_streams.get("hint_hollow_steps")
		if stream:
			hollow_steps_player.stream = stream
			if not hollow_steps_player.playing:
				hollow_steps_player.play()
	else:
		if hollow_steps_player.playing:
			hollow_steps_player.stop()

func stop_all() -> void:
	if is_instance_valid(ambient_player) and ambient_player.playing:
		ambient_player.stop()
	if is_instance_valid(hint_player) and hint_player.playing:
		hint_player.stop()
	if is_instance_valid(hollow_steps_player) and hollow_steps_player.playing:
		hollow_steps_player.stop()

func _on_level_changed(level_num: int) -> void:
	_current_level = level_num
	_hints_enabled = level_num <= HINT_CUTOFF_LEVEL

	if level_num == 0:
		play_ambient(AmbientType.LIVING_ROOM)
	else:
		play_ambient(AmbientType.CORRIDOR)

	print("[AudioManager] Level %d: hints %s" % [
		level_num, "ENABLED" if _hints_enabled else "DISABLED"
	])

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.TITLE:
			play_ambient(AmbientType.MENU)
		GameManager.GameState.YARD:
			play_ambient(AmbientType.FOREST)
		GameManager.GameState.LIVING_ROOM:
			play_ambient(AmbientType.LIVING_ROOM)
		GameManager.GameState.CORRIDOR:
			play_ambient(AmbientType.CORRIDOR)
		GameManager.GameState.FINAL:
			play_ambient(AmbientType.FINAL)
		GameManager.GameState.ENDING:
			stop_all()

func _try_load_audio_streams() -> void:
	var audio_paths: Dictionary = {
		"hint_clock":         "res://assets/audio/hint_clock_wrong.ogg",
		"hint_creak":         "res://assets/audio/hint_creak.ogg",
		"hint_hollow_steps":  "res://assets/audio/hollow_footsteps.ogg",
		"ambient_menu":       "res://assets/audioo/menu.mp3",
		"ambient_forest":     "res://assets/audioo/forest.mp3",
		"ambient_living":     "res://assets/audio/ambient_living_room.ogg",
		"ambient_corridor":   "res://assets/audioo/corridor.mp3",
		"ambient_dark":       "res://assets/audio/ambient_dark_corridor.ogg",
		"ambient_final":      "res://assets/audio/ambient_final.ogg",
	}

	for key in audio_paths:
		var path: String = audio_paths[key]
		var res = load(path)
		if res:
			_audio_streams[key] = res
			print("[AudioManager] Loaded: %s" % path)
		else:
			print("[AudioManager] Failed to load: %s" % path)
