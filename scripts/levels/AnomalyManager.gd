
extends Node

enum AnomalyType {
	WRONG_ROTATION,
	DIFFERENT_TEXTURE,
	EXTRA_MESH,
	WRONG_ANIMATION,
	EXTRA_SHADOW,
	MIRROR_DIFF,
}

const LEVEL_ANOMALY_DATA: Dictionary = {
	1: { "type": "NONE",           "hint": "" },
	2: { "type": "NONE", "hint": "Urutan poster ada yang salah!" },
	3: { "type": "NONE",           "hint": "" },
	4: { "type": "NONE",           "hint": "Ruangan terasa lebih pendek..." },
	5: { "type": "NONE",           "hint": "Ada daging aneh di dekat pintu keluar!" },
	6: { "type": "NONE",           "hint": "Lampu meredup hampir gelap..." },
	7: { "type": "NONE",           "hint": "Zombi di kegelapan!" },
	8: { "type": "NONE",           "hint": "Ilusi pintu terbuka ke hutan" },
}

const LEVEL_TARGET_HINT: Dictionary = {
	2: "Frame",
}

var _has_anomaly: bool = false

var _current_level: int = 0

var _active_anomaly_node: Node = null

var _active_anomaly_type: AnomalyType = AnomalyType.WRONG_ROTATION

var _all_anomaly_nodes: Array[Node] = []

func setup(level: int, has_anomaly: bool) -> void:
	_current_level = level
	_has_anomaly = has_anomaly

	_all_anomaly_nodes.clear()
	for node in get_tree().get_nodes_in_group("anomaly_object"):
		_all_anomaly_nodes.append(node)
		if node.has_method("deactivate_anomaly"):
			node.deactivate_anomaly()
		else:
			_reset_node_default(node)

	print("[AnomalyManager] Found %d potential anomaly objects." % _all_anomaly_nodes.size())

	if _has_anomaly:
		if level == 5:
			print("[AnomalyManager] Level 5 — anomaly handled by Corridor.gd (shrinking door).")
		else:
			_activate_one_anomaly(level)
	else:
		print("[AnomalyManager] No-anomaly run for level %d." % level)

	if _has_anomaly and level <= 3:
		_schedule_audio_hint()

func has_active_anomaly() -> bool:
	return _has_anomaly and is_instance_valid(_active_anomaly_node)

func get_active_anomaly_type() -> AnomalyType:
	return _active_anomaly_type

func _activate_one_anomaly(level: int) -> void:
	if _all_anomaly_nodes.is_empty():
		push_warning("[AnomalyManager] Tidak ada anomaly_object di scene!")
		return

	_active_anomaly_type = _pick_anomaly_type_for_level(level)

	var chosen_node: Node = null
	if LEVEL_TARGET_HINT.has(level):
		var hint_name: String = LEVEL_TARGET_HINT[level]
		for node in _all_anomaly_nodes:
			if hint_name.to_lower() in node.name.to_lower():
				chosen_node = node
				break

	if not is_instance_valid(chosen_node):
		chosen_node = _all_anomaly_nodes[randi() % _all_anomaly_nodes.size()]

	_active_anomaly_node = chosen_node

	var hint := ""
	if LEVEL_ANOMALY_DATA.has(level):
		hint = LEVEL_ANOMALY_DATA[level]["hint"]

	if chosen_node.has_method("activate_anomaly"):
		chosen_node.activate_anomaly(_active_anomaly_type)
	else:
		_apply_anomaly_directly(chosen_node, _active_anomaly_type)

	print("[AnomalyManager] Anomaly: %s | '%s' | Level %d | %s" % [
		AnomalyType.keys()[_active_anomaly_type],
		chosen_node.name, level, hint
	])

func _pick_anomaly_type_for_level(level: int) -> AnomalyType:
	if LEVEL_ANOMALY_DATA.has(level):
		var type_name: String = LEVEL_ANOMALY_DATA[level]["type"]
		for i in AnomalyType.values().size():
			if AnomalyType.keys()[i] == type_name:
				return i as AnomalyType
	return AnomalyType.values()[randi() % AnomalyType.values().size()] as AnomalyType

func _apply_anomaly_directly(node: Node, anomaly_type: AnomalyType) -> void:
	if not node is Node3D:
		return

	var node3d := node as Node3D

	match anomaly_type:
		AnomalyType.WRONG_ROTATION:
			node3d.rotate_object_local(Vector3.FORWARD, deg_to_rad(25.0))

		AnomalyType.EXTRA_MESH:
			var ghost := MeshInstance3D.new()
			var cyl   := CylinderMesh.new()
			cyl.top_radius    = 0.15
			cyl.bottom_radius = 0.20
			cyl.height        = 1.6
			ghost.mesh = cyl
			var gm := StandardMaterial3D.new()
			gm.albedo_color = Color(0.03, 0.01, 0.01, 0.85)
			gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			gm.emission_enabled = true
			gm.emission = Color(0.3, 0.0, 0.0)
			gm.emission_energy_multiplier = 1.0
			ghost.set_surface_override_material(0, gm)
			ghost.position = node3d.position + Vector3(0.5, 0.8, 0)
			node3d.get_parent().add_child(ghost)

		AnomalyType.DIFFERENT_TEXTURE:
			if node3d is MeshInstance3D:
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.5, 0.12, 0.08)
				mat.roughness    = 0.95
				(node3d as MeshInstance3D).set_surface_override_material(0, mat)

		AnomalyType.WRONG_ANIMATION:
			var anim_player := node3d.find_child("AnimationPlayer") as AnimationPlayer
			if is_instance_valid(anim_player) and anim_player.current_animation != "":
				anim_player.speed_scale = -1.0

		AnomalyType.EXTRA_SHADOW:
			var shadow_mesh := MeshInstance3D.new()
			shadow_mesh.mesh = BoxMesh.new()
			(shadow_mesh.mesh as BoxMesh).size = Vector3(0.8, 1.8, 0.02)
			shadow_mesh.position = node3d.position + Vector3(0.6, 0.9, -0.01)
			var dark_mat := StandardMaterial3D.new()
			dark_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.65)
			dark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			shadow_mesh.set_surface_override_material(0, dark_mat)
			node3d.get_parent().add_child(shadow_mesh)

		AnomalyType.MIRROR_DIFF:
			var glass_node := node3d.get_child(1) as MeshInstance3D
			var shadow_in_mirror := MeshInstance3D.new()
			var sm              := CylinderMesh.new()
			sm.top_radius       = 0.06
			sm.bottom_radius    = 0.08
			sm.height           = 0.55
			shadow_in_mirror.mesh = sm
			var sm_mat := StandardMaterial3D.new()
			sm_mat.albedo_color = Color(0.02, 0.01, 0.01, 0.9)
			sm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			shadow_in_mirror.set_surface_override_material(0, sm_mat)
			shadow_in_mirror.position = node3d.position + (node3d.basis.z * 0.15) + Vector3(0, -0.05, 0)
			node3d.get_parent().add_child(shadow_in_mirror)

			if is_instance_valid(glass_node):
				var tint := StandardMaterial3D.new()
				tint.metallic = 0.9
				tint.roughness = 0.05
				if _current_level <= 4:
					tint.albedo_color = Color(0.55, 0.65, 0.60, 1.0)
				else:
					tint.albedo_color = Color(0.5, 0.12, 0.10, 1.0)
				glass_node.set_surface_override_material(0, tint)

func _reset_node_default(node: Node) -> void:
	if not node is Node3D:
		return
	var anim_player := node.find_child("AnimationPlayer") as AnimationPlayer
	if is_instance_valid(anim_player):
		anim_player.speed_scale = 1.0

func _schedule_audio_hint() -> void:
	var delay := randf_range(10.0, 30.0)
	await get_tree().create_timer(delay).timeout

	if GameManager.current_state != GameManager.GameState.CORRIDOR:
		return

	var hint_type := AudioManager.HintType.CREAK
	match _active_anomaly_type:
		AnomalyType.WRONG_ANIMATION:
			hint_type = AudioManager.HintType.CLOCK_WRONG
		_:
			hint_type = AudioManager.HintType.CREAK

	AudioManager.play_hint(hint_type)
	print("[AnomalyManager] Audio hint played (level %d)." % _current_level)
