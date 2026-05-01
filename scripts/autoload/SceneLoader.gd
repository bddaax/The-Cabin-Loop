
extends Node

const YARD_PATH         := "res://scenes/Yard.tscn"
const LIVING_ROOM_PATH  := "res://scenes/LivingRoom.tscn"
const CORRIDOR_PATH     := "res://scenes/Corridor.tscn"
const ELARA_PATH        := "res://scenes/Elara.tscn"
const MEADOW_PATH       := "res://scenes/Meadow.tscn"
const INTRO_PATH        := "res://scenes/Intro.tscn"
const TITLE_SCREEN_PATH := "res://scenes/UI/TitleScreen.tscn"

@onready var scene_container: Node3D = $SceneContainer
@onready var elara_container: Node3D = $ElaraContainer
@onready var fade_rect: ColorRect = $UI/FadeRect
@onready var hud: Node = $UI/HUD

var _current_scene_instance: Node = null
var _elara_instance: Node = null
var _is_transitioning: bool = false

func _ready() -> void:
	GameManager.transition_to_yard.connect(_on_transition_to_yard)
	GameManager.transition_to_living_room.connect(_on_transition_to_living_room)
	GameManager.transition_to_corridor.connect(_on_transition_to_corridor)
	GameManager.transition_to_meadow.connect(_on_transition_to_meadow)
	GameManager.game_state_changed.connect(_on_game_state_changed)

	fade_rect.color = Color(0, 0, 0, 1.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	print("[Main/SceneLoader] Ready. Starting intro...")
	_start_intro()

func _spawn_elara() -> void:
	if is_instance_valid(_elara_instance):
		return
	var elara_scene := load(ELARA_PATH) as PackedScene
	if elara_scene == null:
		push_error("[SceneLoader] Gagal load Elara.tscn!")
		return
	_elara_instance = elara_scene.instantiate()
	_elara_instance.add_to_group("player")
	elara_container.add_child(_elara_instance)
	print("[SceneLoader] Elara spawned.")

func _start_intro() -> void:
	var packed := load(INTRO_PATH) as PackedScene
	if packed == null:
		push_warning("[SceneLoader] Intro.tscn tidak ditemukan — langsung ke title screen.")
		_show_title_screen()
		return
	_current_scene_instance = packed.instantiate()
	scene_container.add_child(_current_scene_instance)
	if _current_scene_instance.has_signal("intro_finished"):
		_current_scene_instance.intro_finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)
	await fade(0.0, 0.25)

func _on_intro_finished() -> void:
	await fade(1.0, 0.5)
	if is_instance_valid(_current_scene_instance):
		_current_scene_instance.queue_free()
		_current_scene_instance = null
	await get_tree().process_frame
	_show_title_screen()

func _show_title_screen() -> void:
	var packed := load(TITLE_SCREEN_PATH) as PackedScene
	if packed == null:
		push_warning("[SceneLoader] TitleScreen.tscn tidak ditemukan — langsung mulai game.")
		_on_title_start_game()
		return
	_current_scene_instance = packed.instantiate()
	scene_container.add_child(_current_scene_instance)
	if _current_scene_instance.has_signal("start_game_pressed"):
		_current_scene_instance.start_game_pressed.connect(_on_title_start_game, CONNECT_ONE_SHOT)
	await fade(0.0, 1.0)

func _on_title_start_game() -> void:
	await fade(1.0, 0.6)
	if is_instance_valid(_current_scene_instance):
		_current_scene_instance.queue_free()
		_current_scene_instance = null
	await get_tree().process_frame
	_spawn_elara()
	GameManager.start_new_game()

func _on_transition_to_yard() -> void:
	if _is_transitioning:
		return
	print("[SceneLoader] Loading Yard...")
	_swap_scene(YARD_PATH, Vector3(0, 0, 3))

func _on_transition_to_living_room() -> void:
	if _is_transitioning:
		return
	_swap_scene(LIVING_ROOM_PATH, Vector3(0, 0, 3))

func _on_transition_to_corridor(level_num: int) -> void:
	if _is_transitioning:
		return
	print("[SceneLoader] Loading Corridor for level %d..." % level_num)
	_swap_scene(CORRIDOR_PATH, Vector3(0, 0.5, 10))

func _on_transition_to_meadow() -> void:
	if _is_transitioning:
		return
	print("[SceneLoader] Loading Meadow ending scene...")
	_swap_scene(MEADOW_PATH, Vector3(0, 0, 5))

func _swap_scene(scene_path: String, player_spawn: Vector3) -> void:
	_is_transitioning = true

	await fade(1.0, 0.6)

	if is_instance_valid(_current_scene_instance):
		_current_scene_instance.queue_free()
		_current_scene_instance = null
	await get_tree().process_frame

	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("[SceneLoader] Gagal load scene: " + scene_path)
		_is_transitioning = false
		return

	_current_scene_instance = packed.instantiate()
	scene_container.add_child(_current_scene_instance)

	if is_instance_valid(_elara_instance) and _elara_instance is Node3D:
		var el = _elara_instance as Node3D
		el.global_position = player_spawn
		if "velocity" in el:
			el.set("velocity", Vector3.ZERO)

	print("[SceneLoader] Scene loaded: %s | Elara at %s" % [scene_path, str(player_spawn)])

	await fade(0.0, 0.8)
	_is_transitioning = false

func fade(target_alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", target_alpha, duration).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.ENDING:
			await fade(0.8, 1.5)
