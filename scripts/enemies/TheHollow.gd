
extends CharacterBody3D

enum HollowState {
	IDLE,
	PATROL,
	ALERT,
	CHASE,
}

const PATROL_SPEED_PER_LEVEL: Array[float] = [
	1.5,
	1.5,
	2.0,
	2.0,
	2.2,
	2.8,
	3.5,
	4.0,
	4.5,
]

const CHASE_SPEED_PER_LEVEL: Array[float] = [
	3.0, 3.0, 3.5, 3.5, 3.8, 4.0, 4.5, 4.8, 5.0,
]

const ALERT_SPEED: float = 1.5

const CATCH_DISTANCE: float = 1.3

const VISION_HALF_ANGLE_DEG: float = 30.0

const VISION_RANGE_L1_4: float = 8.0
const VISION_RANGE_L5_6: float = 12.0
const VISION_RANGE_L7_8: float = 15.0
const VISION_RANGE_DARK: float = 3.0

const FLASHLIGHT_DETECT_RANGE: float = 18.0

const ALERT_DURATION: float = 1.5

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var vision_cone: Area3D = $VisionCone
@onready var obstacle_ray: RayCast3D = $ObstacleRay
@onready var flashlight_detect_area: Area3D = $FlashlightDetectArea
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var anim_player: AnimationPlayer

var aura_player: AudioStreamPlayer3D
var scream_player: AudioStreamPlayer3D

var _state: HollowState = HollowState.IDLE
var _is_active: bool = false
var _player_ref: Node3D = null
var _is_dark_mode: bool = false
var _detect_flashlight: bool = false
var _alert_timer: float = 0.0
var _is_spotting_player: bool = false

var _always_chase: bool = false

var _prox_warn_active: bool = false

var _level: int = 1

var _patrol_speed: float = 1.5

var _chase_speed: float = 3.0

var _vision_range: float = VISION_RANGE_L1_4

@export var patrol_waypoints: Array[NodePath] = []
var _waypoint_nodes: Array[Node3D] = []
var _patrol_positions: Array[Vector3] = []
var _current_waypoint_idx: int = 0

func _ready() -> void:
	set_physics_process(false)
	_is_active = false
	visible    = false

	_build_shadow_body()

	for path in patrol_waypoints:
		var node := get_node_or_null(path) as Node3D
		if is_instance_valid(node):
			_waypoint_nodes.append(node)

	if is_instance_valid(vision_cone):
		vision_cone.body_entered.connect(_on_vision_cone_body_entered)
		vision_cone.body_exited.connect(_on_vision_cone_body_exited)

	if is_instance_valid(flashlight_detect_area):
		flashlight_detect_area.body_entered.connect(_on_flashlight_detect_entered)

	GameManager.game_state_changed.connect(_on_game_state_changed)

	aura_player = AudioStreamPlayer3D.new()
	var aura_stream = load("res://assets/audio/hollow_aura.wav")
	if aura_stream:
		aura_player.stream = aura_stream
		aura_player.unit_size = 5.0
		aura_player.max_db = -5.0
	add_child(aura_player)

	scream_player = AudioStreamPlayer3D.new()
	var scream_stream = load("res://assets/audio/scream.wav")
	if scream_stream:
		scream_player.stream = scream_stream
		scream_player.unit_size = 15.0
		scream_player.max_db = 0.0
	add_child(scream_player)

	print("[TheHollow] Ready. D80: Vision-only AI.")

func _physics_process(delta: float) -> void:
	if not _is_active:
		return

	if not is_instance_valid(_player_ref):
		_player_ref = GameManager.get_player() as Node3D
		if not is_instance_valid(_player_ref):
			return

	match _state:
		HollowState.IDLE:        _process_idle(delta)
		HollowState.PATROL:      _process_patrol(delta)
		HollowState.ALERT:       _process_alert(delta)
		HollowState.CHASE:       _process_chase(delta)

	_check_player_caught()

	if _level in [3, 6] and _state != HollowState.CHASE:
		_check_proximity_warning()

func setup_for_level(level: int) -> void:
	_level = clampi(level, 1, 8)
	_always_chase = false
	_prox_warn_active = false
	_patrol_positions.clear()
	_current_waypoint_idx = 0
	var idx := clampi(_level, 0, PATROL_SPEED_PER_LEVEL.size() - 1)
	_patrol_speed = PATROL_SPEED_PER_LEVEL[idx]
	_chase_speed  = CHASE_SPEED_PER_LEVEL[idx]

	if _level <= 4:
		_vision_range = VISION_RANGE_L1_4
	elif _level <= 6:
		_vision_range = VISION_RANGE_L5_6
	else:
		_vision_range = VISION_RANGE_L7_8

	set_dark_mode(_level >= 7)
	set_detect_flashlight(_level >= 7)

	print("[TheHollow] Setup for Level %d | patrol=%.1f chase=%.1f vision=%.1f" % [
		_level, _patrol_speed, _chase_speed, _vision_range
	])

func activate() -> void:
	visible  = true
	_is_active = true
	set_physics_process(true)
	var initial_state = HollowState.PATROL if (_waypoint_nodes.size() > 0 or _patrol_positions.size() > 0) else HollowState.IDLE
	_state = initial_state
	_change_state(initial_state)
	if aura_player and aura_player.stream and not aura_player.playing:
		aura_player.play()
	print("[TheHollow] Activated in state: %s" % HollowState.keys()[_state])

func set_patrol_from_world_positions(positions: Array) -> void:
	_patrol_positions.clear()
	for pos in positions:
		_patrol_positions.append(pos as Vector3)
	_current_waypoint_idx = 0
	print("[TheHollow] Patrol positions set: %d points." % _patrol_positions.size())

func start_chase_immediately() -> void:
	_always_chase = true
	_is_active = true
	set_physics_process(true)
	_player_ref = GameManager.get_player() as Node3D
	_set_spotting(true)
	_change_state(HollowState.CHASE)
	print("[TheHollow] IMMEDIATE CHASE (Level 7 — no vision required).")

func deactivate() -> void:
	_is_active = false
	_always_chase = false
	set_physics_process(false)
	_set_spotting(false)
	if aura_player and aura_player.playing:
		aura_player.stop()
	if _prox_warn_active:
		_prox_warn_active = false
		GameManager.set_hollow_watching(false)
	print("[TheHollow] Deactivated.")

func set_dark_mode(is_dark: bool) -> void:
	_is_dark_mode = is_dark

func set_detect_flashlight(detect: bool) -> void:
	_detect_flashlight = detect
	if is_instance_valid(flashlight_detect_area):
		flashlight_detect_area.monitoring = detect

func _process_idle(_delta: float) -> void:
	pass

func _process_patrol(delta: float) -> void:
	var has_positions := not _patrol_positions.is_empty()
	var has_nodes     := not _waypoint_nodes.is_empty()
	if not has_positions and not has_nodes:
		_state = HollowState.IDLE
		return

	var target: Vector3
	var pool_size: int
	if has_positions:
		target    = _patrol_positions[_current_waypoint_idx]
		pool_size = _patrol_positions.size()
	else:
		target    = _waypoint_nodes[_current_waypoint_idx].global_position
		pool_size = _waypoint_nodes.size()

	var dist := global_position.distance_to(target)
	if dist < 1.5:
		_current_waypoint_idx = (_current_waypoint_idx + 1) % pool_size
		return

	_move_direct(target, _patrol_speed)

func _process_alert(delta: float) -> void:
	velocity = Vector3.ZERO
	move_and_slide()

	_alert_timer -= delta
	if _alert_timer <= 0.0:
		if _is_spotting_player:
			_change_state(HollowState.CHASE)
		else:
			_change_state(HollowState.PATROL)

func _process_chase(delta: float) -> void:
	if not is_instance_valid(_player_ref):
		_change_state(HollowState.PATROL)
		return

	if not _always_chase and not _can_see_player():
		_set_spotting(false)
		_change_state(HollowState.ALERT)
		_alert_timer = ALERT_DURATION * 2.0
		return

	_move_direct(_player_ref.global_position, _chase_speed)

func _can_see_player() -> bool:
	if not is_instance_valid(_player_ref):
		return false

	if GameManager.player_is_blinking:
		return false

	var to_player := _player_ref.global_position - global_position
	var distance := to_player.length()

	var max_range := VISION_RANGE_DARK if (_is_dark_mode and not GameManager.flashlight_active) else _vision_range
	if distance > max_range:
		return false

	var forward := -global_transform.basis.z
	var angle_to_player := rad_to_deg(forward.angle_to(to_player.normalized()))
	if angle_to_player > VISION_HALF_ANGLE_DEG:
		return false

	if is_instance_valid(obstacle_ray):
		obstacle_ray.target_position = to_player
		obstacle_ray.force_raycast_update()
		if obstacle_ray.is_colliding():
			var collider := obstacle_ray.get_collider()
			if collider != _player_ref and not collider.is_in_group("player"):
				return false

	return true

func _can_see_flashlight() -> bool:
	if not _detect_flashlight:
		return false
	if not GameManager.flashlight_active:
		return false
	if not is_instance_valid(_player_ref):
		return false

	var dist := global_position.distance_to(_player_ref.global_position)
	return dist <= FLASHLIGHT_DETECT_RANGE

func _on_vision_cone_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	if _can_see_player():
		_on_player_spotted()

func _on_vision_cone_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		if _state == HollowState.CHASE:
			pass
		elif _is_spotting_player:
			_set_spotting(false)

func _on_flashlight_detect_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if _can_see_flashlight():
		_on_player_spotted()

func _on_player_spotted() -> void:
	if _is_spotting_player:
		return

	_set_spotting(true)

	if scream_player and scream_player.stream and not scream_player.playing:
		scream_player.play()

	if _state != HollowState.CHASE:
		_change_state(HollowState.ALERT)
		_alert_timer = ALERT_DURATION

	AudioManager.set_hollow_audible(true)

	print("[TheHollow] Player SPOTTED!")

func _set_spotting(is_spotting: bool) -> void:
	if _is_spotting_player == is_spotting:
		return
	_is_spotting_player = is_spotting
	GameManager.set_hollow_watching(is_spotting)

	if not is_spotting:
		AudioManager.set_hollow_audible(false)

func _check_player_caught() -> void:
	if not is_instance_valid(_player_ref):
		return
	if _state != HollowState.CHASE:
		return

	var dist := global_position.distance_to(_player_ref.global_position)
	if dist <= CATCH_DISTANCE:
		print("[TheHollow] Player CAUGHT! Triggering bad ending...")
		deactivate()
		GameManager.evaluate_ending()

func _move_direct(target_pos: Vector3, speed: float) -> void:
	var flat_target := Vector3(target_pos.x, global_position.y, target_pos.z)
	var direction   := (flat_target - global_position).normalized()
	if direction.length() < 0.01:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	velocity = direction * speed
	move_and_slide()
	var look_target := global_position + direction
	look_at(look_target, Vector3.UP)

func _change_state(new_state: HollowState) -> void:
	print("[TheHollow] State: %s → %s" % [HollowState.keys()[_state], HollowState.keys()[new_state]])
	_state = new_state
	if anim_player:
		match _state:
			HollowState.IDLE: anim_player.play("IDLE")
			HollowState.PATROL: anim_player.play("WALK")
			HollowState.ALERT: anim_player.play("IDLE")
			HollowState.CHASE: anim_player.play("RUN")

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	if new_state != GameManager.GameState.CORRIDOR and new_state != GameManager.GameState.FINAL:
		deactivate()

func _check_proximity_warning() -> void:
	if not is_instance_valid(_player_ref):
		return
	var dist := global_position.distance_to(_player_ref.global_position)
	var is_close := dist < 5.0
	if is_close != _prox_warn_active:
		_prox_warn_active = is_close
		GameManager.set_hollow_watching(is_close)

func _build_shadow_body() -> void:
	var zombie_scene = load("res://assets/zombie_GLTF/scene.gltf")
	if zombie_scene:
		var zombie = zombie_scene.instantiate()
		zombie.name = "ShadowBody"

		zombie.scale = Vector3(1.3, 1.3, 1.3)
		zombie.rotation_degrees.y = 180.0

		add_child(zombie)
		anim_player = _find_anim_player(zombie)
		if anim_player:
			var anims = anim_player.get_animation_list()
			for anim_name in anims:
				var anim = anim_player.get_animation(anim_name)
				if anim:
					anim.loop_mode = Animation.LOOP_LINEAR
			anim_player.play("IDLE")
	else:
		print("[TheHollow] Error: Zombie glTF not found at res://assets/zombie_GLTF/scene.gltf!")

	if is_instance_valid(mesh_instance):
		mesh_instance.visible = false

	print("[TheHollow] Zombie body built.")

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = _find_anim_player(child)
		if found: return found
	return null
