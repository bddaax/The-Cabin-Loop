
extends Node

const LIGHT_ENERGY_MULTIPLIER: Array[float] = [
	1.0,
	0.30,
	0.30,
	0.30,
	0.30,
	0.30,
	0.15,
	0.05,
	0.0,
]

const DECAL_OPACITY_PER_LEVEL: Array[float] = [
	0.0, 0.0, 0.1, 0.25, 0.45, 0.60, 0.75, 0.90, 1.0
]

const DEBRIS_COUNT_PER_LEVEL: Array[int] = [
	0, 0, 0, 0, 0, 0, 0, 0, 0
]

const FOG_DENSITY_PER_LEVEL: Array[float] = [
	0.0, 0.0, 0.01, 0.03, 0.05, 0.08, 0.12, 0.25, 0.35
]

const SMOKE_ACTIVE_FROM_LEVEL: int = 5

const EMERGENCY_LIGHT_FROM_LEVEL: int = 99

const TOTAL_DARK_FROM_LEVEL: int = 7

var _base_light_energies: Dictionary = {}

var _corridor_lights: Array[Node] = []
var _decay_debris: Array[Node] = []
var _decay_decals: Array[Node] = []
var _smoke_particles: Array[Node] = []
var _emergency_lights: Array[Node] = []
var _world_env: WorldEnvironment = null

func _ready() -> void:
	GameManager.level_changed.connect(_on_level_changed)
	print("[DecaySystem] Ready.")

func initialize_scene(scene_root: Node) -> void:
	_corridor_lights.clear()
	_decay_debris.clear()
	_decay_decals.clear()
	_smoke_particles.clear()
	_emergency_lights.clear()
	_base_light_energies.clear()
	_world_env = scene_root.get_node_or_null("WorldEnvironment") as WorldEnvironment

	for node in get_tree().get_nodes_in_group("corridor_lights"):
		_corridor_lights.append(node)
		if node is Light3D:
			_base_light_energies[node.get_instance_id()] = node.light_energy

	for node in get_tree().get_nodes_in_group("decay_debris"):
		_decay_debris.append(node)
		node.visible = false

	for node in get_tree().get_nodes_in_group("decay_decals"):
		_decay_decals.append(node)

	for node in get_tree().get_nodes_in_group("smoke_particles"):
		_smoke_particles.append(node)
		node.emitting = false

	for node in get_tree().get_nodes_in_group("emergency_lights"):
		_emergency_lights.append(node)
		node.visible = false

	_apply_decay_for_level(GameManager.current_level)

	print("[DecaySystem] Initialized scene '%s' for level %d." % [
		scene_root.name, GameManager.current_level
	])

func _on_level_changed(level_num: int) -> void:
	_apply_decay_for_level(level_num)

func _apply_decay_for_level(level: int) -> void:
	var idx := clampi(level, 0, LIGHT_ENERGY_MULTIPLIER.size() - 1)

	_apply_light_decay(idx)
	_apply_decal_decay(idx)
	_apply_debris_decay(idx)
	_apply_smoke_decay(idx)
	_apply_emergency_lights(idx)
	_apply_fog_decay(idx)

	print("[DecaySystem] Applied decay for level %d." % level)

func _apply_light_decay(level_idx: int) -> void:
	var multiplier := LIGHT_ENERGY_MULTIPLIER[level_idx]

	for light in _corridor_lights:
		if not is_instance_valid(light):
			continue
		if light is Light3D:
			var base_energy: float = _base_light_energies.get(light.get_instance_id(), 1.0)
			light.light_energy = base_energy * multiplier

			if level_idx >= TOTAL_DARK_FROM_LEVEL:
				light.visible = false

func _apply_decal_decay(level_idx: int) -> void:
	var opacity := DECAL_OPACITY_PER_LEVEL[level_idx]

	for decal in _decay_decals:
		if not is_instance_valid(decal):
			continue
		if decal is Decal:
			decal.albedo_mix = opacity

func _apply_debris_decay(level_idx: int) -> void:
	var count := DEBRIS_COUNT_PER_LEVEL[level_idx]

	for debris in _decay_debris:
		if is_instance_valid(debris):
			debris.visible = false

	var shown := 0
	for debris in _decay_debris:
		if shown >= count:
			break
		if is_instance_valid(debris):
			debris.visible = true
			shown += 1

func _apply_smoke_decay(level_idx: int) -> void:
	var should_emit := level_idx >= SMOKE_ACTIVE_FROM_LEVEL

	for particles in _smoke_particles:
		if not is_instance_valid(particles):
			continue
		if particles is GPUParticles3D:
			particles.emitting = should_emit

func _apply_emergency_lights(level_idx: int) -> void:
	var should_show := level_idx >= EMERGENCY_LIGHT_FROM_LEVEL

	for light in _emergency_lights:
		if is_instance_valid(light):
			light.visible = should_show

func _apply_fog_decay(level_idx: int) -> void:
	if not is_instance_valid(_world_env) or not is_instance_valid(_world_env.environment):
		return
	var fog_density := FOG_DENSITY_PER_LEVEL[level_idx]
	_world_env.environment.volumetric_fog_enabled = fog_density > 0.0
	if fog_density > 0.0:
		_world_env.environment.volumetric_fog_density = fog_density

func tween_lights_to_level(level: int, duration: float = 2.0) -> void:
	var idx := clampi(level, 0, LIGHT_ENERGY_MULTIPLIER.size() - 1)
	var multiplier := LIGHT_ENERGY_MULTIPLIER[idx]

	for light in _corridor_lights:
		if not is_instance_valid(light) or not light is Light3D:
			continue
		var base_energy: float = _base_light_energies.get(light.get_instance_id(), 1.0)
		var target := base_energy * multiplier

		var tween := create_tween()
		tween.tween_property(light, "light_energy", target, duration).set_ease(Tween.EASE_OUT)
