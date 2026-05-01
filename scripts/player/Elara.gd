
extends CharacterBody3D

const WALK_SPEED: float = 3.5

const SLOW_SPEED: float = 1.8

const CAUTIOUS_SPEED: float = 2.5

const MOUSE_SENSITIVITY: float = 0.002

const CAMERA_PITCH_MIN: float = -1.4
const CAMERA_PITCH_MAX: float = 1.4

const INTERACT_DISTANCE: float = 2.2

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight_node: SpotLight3D = $Head/Camera3D/Flashlight
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay

var input_enabled: bool = true

var _is_slow_walking: bool = false

var _is_moving: bool = false

var _bob_time: float = 0.0
var _bob_intensity: float = 0.0
const BOB_FREQUENCY: float = 2.0
const BOB_AMPLITUDE: float = 0.03

var _last_hovered: Object = null

var _is_blinking: bool = false
var _blink_overlay: ColorRect = null

var footstep_player: AudioStreamPlayer
var breath_player: AudioStreamPlayer
var _last_footstep_bob: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	add_to_group("player")

	GameManager.register_player(self)

	GameManager.item_acquired.connect(_on_item_acquired)
	GameManager.game_state_changed.connect(_on_game_state_changed)
	GameManager.hollow_spotted_player.connect(_on_hollow_spotted)

	camera.add_to_group("player_camera")

	_sync_flashlight_visibility()

	_create_blink_overlay()

	footstep_player = AudioStreamPlayer.new()
	var fs_stream = load("res://assets/audio/footstep.ogg")
	if fs_stream: footstep_player.stream = fs_stream
	footstep_player.volume_db = -10.0
	add_child(footstep_player)

	breath_player = AudioStreamPlayer.new()
	var br_stream = load("res://assets/audio/breath.wav")
	if br_stream: breath_player.stream = br_stream
	breath_player.volume_db = -5.0
	add_child(breath_player)

	print("[Elara] Player ready at position: ", global_position)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and input_enabled:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
			head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
			head.rotation.x = clampf(head.rotation.x, CAMERA_PITCH_MIN, CAMERA_PITCH_MAX)

	if event.is_action_pressed("flashlight_toggle") and input_enabled:
		GameManager.toggle_flashlight()
		_sync_flashlight_visibility()

	if event.is_action_pressed("close_eyes") and input_enabled:
		_set_blink(true)
	if event.is_action_released("close_eyes"):
		_set_blink(false)

	if event.is_action_pressed("pause_game"):
		_toggle_pause()

	if OS.is_debug_build() and event.is_action_pressed("ui_accept"):
		GameManager.debug_print_state()

func _physics_process(delta: float) -> void:
	if not input_enabled:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	_is_slow_walking = Input.is_action_pressed("slow_walk")
	var speed := _get_current_speed()

	var input_dir := Input.get_vector(
		"movement_left", "movement_right",
		"movement_forward", "movement_backward"
	)
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	_is_moving = direction.length() > 0.1

	if _is_moving:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	GameManager.notify_player_moving(_is_moving)

	_update_head_bob(delta, _is_moving)

	if _is_moving and is_on_floor() and not _is_slow_walking:
		if _bob_time - _last_footstep_bob > 0.5:
			_last_footstep_bob = _bob_time
			if footstep_player and footstep_player.stream:
				footstep_player.pitch_scale = randf_range(0.85, 1.15)
				footstep_player.play()

	move_and_slide()

	_check_for_interaction()

func _get_current_speed() -> float:
	if _is_slow_walking:
		return SLOW_SPEED
	if GameManager.is_dark_level():
		return CAUTIOUS_SPEED
	return WALK_SPEED

func _update_head_bob(delta: float, is_moving: bool) -> void:
	if is_moving:
		var speed_ratio := _get_current_speed() / WALK_SPEED
		_bob_time += delta * BOB_FREQUENCY * speed_ratio
		var target_amp := BOB_AMPLITUDE * (0.4 if _is_slow_walking else 1.0)
		_bob_intensity = move_toward(_bob_intensity, target_amp, delta * 2.0)
	else:
		_bob_time = 0.0
		_bob_intensity = move_toward(_bob_intensity, 0.0, delta * 4.0)

	camera.position.y = sin(_bob_time * TAU) * _bob_intensity
	camera.position.x = sin(_bob_time * PI) * _bob_intensity * 0.5

func _check_for_interaction() -> void:
	if not is_instance_valid(interact_ray):
		return

	interact_ray.force_raycast_update()

	if not interact_ray.is_colliding():
		_last_hovered = null
		return

	var collider := interact_ray.get_collider()
	if collider == null:
		return

	if collider != _last_hovered:
		_last_hovered = collider
		var label: String = collider.get_meta("interactable_label", "")
		if label != "" and is_instance_valid(get_tree()):
			for hud in get_tree().get_nodes_in_group("game_hud"):
				if hud.has_method("show_prompt"):
					hud.show_prompt("[E] " + label)

	if Input.is_action_just_pressed("interact"):
		if collider.has_method("interact"):
			collider.interact(self)
			return
		if collider.has_meta("interact_callback"):
			var cb: Callable = collider.get_meta("interact_callback")
			if cb.is_valid():
				cb.call()
				return
		if collider.is_in_group("interactable"):
			collider.emit_signal("interacted", self)

func _sync_flashlight_visibility() -> void:
	if not is_instance_valid(flashlight_node):
		return
	flashlight_node.visible = GameManager.flashlight_active and GameManager.has_item("flashlight")

func _on_item_acquired(item_name: String) -> void:
	if item_name == "flashlight":
		_sync_flashlight_visibility()

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.ENDING, GameManager.GameState.FINAL:
			input_enabled = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		GameManager.GameState.PAUSED:
			input_enabled = false
		GameManager.GameState.YARD, GameManager.GameState.CORRIDOR, GameManager.GameState.LIVING_ROOM:
			input_enabled = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_hollow_spotted(is_spotted: bool) -> void:
	if is_spotted:
		print("[Elara] THE HOLLOW IS WATCHING!")

func _toggle_pause() -> void:
	if GameManager.current_state == GameManager.GameState.CORRIDOR or \
	   GameManager.current_state == GameManager.GameState.LIVING_ROOM:
		var is_paused := get_tree().paused
		get_tree().paused = not is_paused
		Input.set_mouse_mode(
			Input.MOUSE_MODE_VISIBLE if not is_paused else Input.MOUSE_MODE_CAPTURED
		)

func get_eye_position() -> Vector3:
	return camera.global_position

func get_look_direction() -> Vector3:
	return -camera.global_transform.basis.z

func disable_input_briefly(duration: float) -> void:
	input_enabled = false
	await get_tree().create_timer(duration).timeout
	input_enabled = true

func _create_blink_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 50
	canvas.name  = "BlinkCanvas"

	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color    = Color(0, 0, 0, 0)
	rect.name     = "BlinkRect"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(rect)
	add_child(canvas)
	_blink_overlay = rect

func _set_blink(is_blinking: bool) -> void:
	if _is_blinking == is_blinking:
		return
	_is_blinking = is_blinking
	GameManager.set_player_blinking(is_blinking)

	if is_blinking and breath_player and breath_player.stream:
		if not breath_player.playing:
			breath_player.play()
	elif breath_player and breath_player.playing:
		breath_player.stop()

	if not is_instance_valid(_blink_overlay):
		return

	var target_alpha := 0.9 if is_blinking else 0.0
	var tween := create_tween()
	tween.tween_property(_blink_overlay, "color:a", target_alpha, 0.12).set_ease(Tween.EASE_IN_OUT)
