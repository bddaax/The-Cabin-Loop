
extends Node

const THRESHOLD_VIGNETTE: float = 60.0

const THRESHOLD_CHROMA: float = 40.0

const THRESHOLD_HEAVY: float = 20.0

const THRESHOLD_BLACKOUT: float = 5.0

@export var sanity_overlay: ColorRect

@export var world_environment: WorldEnvironment

var _current_sanity: float = 100.0

var _shake_intensity: float = 0.0

var _shake_timer: float = 0.0

var _camera: Camera3D = null

func _ready() -> void:
	GameManager.sanity_changed.connect(_on_sanity_changed)
	GameManager.hollow_spotted_player.connect(_on_hollow_spotted)
	GameManager.game_state_changed.connect(_on_game_state_changed)

	_current_sanity = GameManager.sanity
	_update_visual_effects(_current_sanity)

	print("[SanitySystem] Ready. Listening to GameManager signals.")

func _process(delta: float) -> void:
	if _shake_intensity > 0.0:
		_process_screen_shake(delta)

func _on_sanity_changed(value: float) -> void:
	_current_sanity = value
	_update_visual_effects(value)

	if value < THRESHOLD_HEAVY:
		var intensity := 0.05 + 0.15 * (1.0 - (value / THRESHOLD_HEAVY))
		_start_screen_shake(intensity, 0.4)

	if value <= THRESHOLD_BLACKOUT:
		_set_blackout(true)
	else:
		_set_blackout(false)

func _on_hollow_spotted(is_spotted: bool) -> void:
	if is_spotted:
		_start_screen_shake(0.2, 0.5)

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.LIVING_ROOM:
		_update_visual_effects(_current_sanity * 1.2)
	elif new_state == GameManager.GameState.CORRIDOR:
		_update_visual_effects(_current_sanity)

func _update_visual_effects(sanity: float) -> void:
	if not is_instance_valid(sanity_overlay):
		_find_overlay()
		if not is_instance_valid(sanity_overlay):
			return

	var material := sanity_overlay.material as ShaderMaterial
	if material == null:
		return

	var t := clampf(sanity / 100.0, 0.0, 1.0)

	var vignette_strength := _calculate_vignette(sanity)
	material.set_shader_parameter("vignette_intensity", vignette_strength)

	var chroma_strength := _calculate_chroma(sanity)
	material.set_shader_parameter("chroma_intensity", chroma_strength)

	var pulse_speed := 0.0 if sanity > THRESHOLD_HEAVY else (3.0 * (1.0 - t))
	material.set_shader_parameter("pulse_speed", pulse_speed)

	if is_instance_valid(world_environment):
		_update_world_environment(sanity)

func _calculate_vignette(sanity: float) -> float:
	if sanity >= THRESHOLD_VIGNETTE:
		return 0.0
	elif sanity >= THRESHOLD_CHROMA:
		var t := 1.0 - ((sanity - THRESHOLD_CHROMA) / (THRESHOLD_VIGNETTE - THRESHOLD_CHROMA))
		return lerpf(0.0, 0.5, t)
	elif sanity >= THRESHOLD_HEAVY:
		var t := 1.0 - ((sanity - THRESHOLD_HEAVY) / (THRESHOLD_CHROMA - THRESHOLD_HEAVY))
		return lerpf(0.5, 0.85, t)
	else:
		var t := 1.0 - (sanity / THRESHOLD_HEAVY)
		return lerpf(0.85, 1.0, t)

func _calculate_chroma(sanity: float) -> float:
	if sanity >= THRESHOLD_CHROMA:
		return 0.0
	elif sanity >= THRESHOLD_HEAVY:
		var t := 1.0 - ((sanity - THRESHOLD_HEAVY) / (THRESHOLD_CHROMA - THRESHOLD_HEAVY))
		return lerpf(0.0, 0.04, t)
	else:
		var t := 1.0 - (sanity / THRESHOLD_HEAVY)
		return lerpf(0.04, 0.12, t)

func _update_world_environment(sanity: float) -> void:
	var env := world_environment.environment
	if env == null:
		return

	var ambient_factor := clampf(sanity / 100.0, 0.2, 1.0)
	env.ambient_light_energy = ambient_factor * 0.3

	if sanity < THRESHOLD_HEAVY:
		env.glow_enabled = true
		env.glow_intensity = lerpf(0.0, 0.8, 1.0 - (sanity / THRESHOLD_HEAVY))
	else:
		env.glow_enabled = false

func _start_screen_shake(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_timer = duration

	if not is_instance_valid(_camera):
		_find_camera()

func _process_screen_shake(delta: float) -> void:
	_shake_timer -= delta

	if _shake_timer <= 0.0:
		_shake_intensity = 0.0
		_shake_timer = 0.0
		if is_instance_valid(_camera):
			_camera.h_offset = 0.0
			_camera.v_offset = 0.0
		return

	var decay := _shake_timer / (_shake_timer + delta)
	if is_instance_valid(_camera):
		_camera.h_offset = randf_range(-_shake_intensity, _shake_intensity) * decay
		_camera.v_offset = randf_range(-_shake_intensity, _shake_intensity) * decay * 0.5
	_shake_intensity *= 0.95

func _find_camera() -> void:
	var cameras := get_tree().get_nodes_in_group("player_camera")
	if cameras.size() > 0:
		_camera = cameras[0] as Camera3D

func _find_overlay() -> void:
	var overlays := get_tree().get_nodes_in_group("sanity_overlay")
	if overlays.size() > 0:
		sanity_overlay = overlays[0] as ColorRect

func _set_blackout(enabled: bool) -> void:
	if not is_instance_valid(sanity_overlay):
		_find_overlay()
	if not is_instance_valid(sanity_overlay):
		return
	var material := sanity_overlay.material as ShaderMaterial
	if material == null:
		return
	if enabled:
		material.set_shader_parameter("vignette_intensity", 1.0)
		material.set_shader_parameter("pulse_speed", 8.0)
