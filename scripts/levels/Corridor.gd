extends Node3D

@onready var exit_area: Area3D = $ExitDoor/ExitArea
@onready var entrance_area: Area3D = $EntranceDoor/EntranceArea
@onready var anomaly_manager: Node = $AnomalyManager
@onready var decay_system: Node = $DecaySystem
@onready var the_hollow: Node = $TheHollow
@onready var light_system: Node3D = $LightSystem

var _is_setup: bool = false
var _player_in_corridor: bool = false
var shtt_player: AudioStreamPlayer
var _level7_zombie_spawned := false
var _level8_zombie_spawned := false
var _crying_heads: Array = []
var _crying_head_chase_active: bool = false
var _level4_heads_spawned: bool = false

func _ready() -> void:
	var light_node := get_node_or_null("LightSystem")
	if is_instance_valid(light_node):
		for child in light_node.get_children():
			if child is OmniLight3D or child is SpotLight3D:
				if "Emergency" in child.name:
					child.add_to_group("emergency_lights")
				else:
					child.add_to_group("corridor_lights")

	var debris_node := get_node_or_null("DecayMeshes")
	if is_instance_valid(debris_node):
		for child in debris_node.get_children():
			child.add_to_group("decay_debris")

	var smoke_node := get_node_or_null("SmokeParticles")
	if is_instance_valid(smoke_node):
		smoke_node.add_to_group("smoke_particles")

	if is_instance_valid(GameManager.get_player()):
		GameManager.get_player().add_to_group("player")

	var anomaly_objects_root := get_node_or_null("Props/AnomalyObjects")
	if is_instance_valid(anomaly_objects_root):
		for child in anomaly_objects_root.get_children():
			child.add_to_group("anomaly_object")

	_setup_corridor_props()

	if is_instance_valid(decay_system):
		decay_system.initialize_scene(self)

	if is_instance_valid(anomaly_manager):
		anomaly_manager.setup(GameManager.current_level, GameManager.current_level_has_anomaly)

	if is_instance_valid(exit_area):
		exit_area.body_entered.connect(_on_exit_area_entered)

	if is_instance_valid(entrance_area):
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(entrance_area):
			entrance_area.body_entered.connect(_on_entrance_area_entered)

	_setup_hollow()

	if GameManager.current_level == 4:
		_setup_level4_shrinking_room()

	if GameManager.current_level == 5:
		_setup_level5_flesh_blob()

	if GameManager.current_level == 6:
		_setup_level6_dimming()

	if GameManager.current_level == 7:
		_setup_level7_darkness()

	if GameManager.current_level == 8:
		_setup_level8_fake_out()

	var cm := get_node_or_null("CorridorMesh")
	if is_instance_valid(cm):
		cm.scale.x = 1.3

	if GameManager.is_dark_level():
		AudioManager.play_ambient(AudioManager.AmbientType.DARK_CORRIDOR)
	else:
		AudioManager.play_ambient(AudioManager.AmbientType.CORRIDOR)

	if is_instance_valid(decay_system):
		decay_system.tween_lights_to_level(GameManager.current_level, 1.5)

	if GameManager.current_level in [7, 8]:
		shtt_player = AudioStreamPlayer.new()
		var stream = load("res://assets/audioo/zombie.mp3")
		if stream:
			shtt_player.stream = stream
			add_child(shtt_player)

	_is_setup = true
	_player_in_corridor = true

	print("[Corridor] Setup complete. Level: %d | Has Anomaly: %s" % [
		GameManager.current_level,
		str(GameManager.current_level_has_anomaly)
	])

func _setup_level7_darkness() -> void:
	for node in get_tree().get_nodes_in_group("corridor_lights"):
		if node is Light3D:
			(node as Light3D).light_energy = 0.0
	for node in get_tree().get_nodes_in_group("emergency_lights"):
		if node is Light3D:
			(node as Light3D).light_energy = 0.0
	_dim_lights_recursive(self)
	print("[Corridor] Level 7: All lights off.")

func _dim_lights_recursive(node: Node) -> void:
	if node is OmniLight3D or node is SpotLight3D:
		(node as Light3D).light_energy = 0.0
	for child in node.get_children():
		_dim_lights_recursive(child)

func _setup_level4_shrinking_room() -> void:
	if GameManager.current_level_has_anomaly:
		var cm := get_node_or_null("CorridorMesh")
		if is_instance_valid(cm):
			cm.scale.x = 0.8
			cm.scale.y = 1.0
			cm.scale.z = 1.0
			cm.position.z = 0.0

		var timer := Timer.new()
		timer.wait_time = 0.15
		timer.autostart = true
		add_child(timer)
		var is_light_on = true
		timer.timeout.connect(func():
			is_light_on = not is_light_on
			for l in get_tree().get_nodes_in_group("corridor_lights"):
				if l is Light3D:
					l.light_energy = 1.2 if is_light_on else 0.0
		)

	print("[Corridor] Level 4 setup: crying head akan muncul saat player lewat Z=-4, anomaly=%s" % str(GameManager.current_level_has_anomaly))

func _setup_level5_flesh_blob() -> void:
	if not GameManager.current_level_has_anomaly:
		return

	var exit_door := get_node_or_null("ExitDoor")
	if not is_instance_valid(exit_door):
		return

	var trigger := Area3D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = 2
	trigger.position = Vector3(0, 1.0, -4.0) 	
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5, 5, 2)
	cs.shape = box
	trigger.add_child(cs)
	add_child(trigger)
	trigger.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player"):
			var pk = load("res://assets/flesh_blob.glb")
			if pk:
				var blob = pk.instantiate() as Node3D
				blob.position = Vector3(0, 0, 10.0)
				blob.scale = Vector3.ONE * 1.5
				var mat = StandardMaterial3D.new()
				var tex = load("res://assets/flesh_blob_0.png")
				if tex:
					mat.albedo_texture = tex
				else:
					mat.albedo_color = Color(0.6, 0.1, 0.1)
				mat.roughness = 0.3
				mat.metallic = 0.1
				for child in blob.get_children():
					if child is MeshInstance3D:
						child.set_surface_override_material(0, mat)
					for c2 in child.get_children():
						if c2 is MeshInstance3D:
							c2.set_surface_override_material(0, mat)
				add_child(blob)
			if shtt_player and shtt_player.stream:
				shtt_player.play()
			trigger.queue_free()
	)
	print("[Corridor] Level 5: Flesh blob trigger ready.")

func _setup_level6_dimming() -> void:
	print("[Corridor] Level 6: Dimming lights and flickering initialized.")
	var timer := Timer.new()
	timer.wait_time = 0.15
	timer.autostart = true
	add_child(timer)
	var is_light_on = true
	timer.timeout.connect(func():
		is_light_on = not is_light_on
		for l in get_tree().get_nodes_in_group("corridor_lights"):
			if l is Light3D:
				l.light_energy = 1.2 if is_light_on else 0.0
	)
	if not GameManager.has_item("flashlight"):
		var fl := StaticBody3D.new()
		fl.collision_layer = 1
		var fl_mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.04
		cyl.bottom_radius = 0.04
		cyl.height = 0.2
		fl_mesh.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.2, 0.2)
		mat.metallic = 0.8
		fl_mesh.set_surface_override_material(0, mat)
		fl_mesh.rotation_degrees.x = 90
		fl.add_child(fl_mesh)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.5, 0.5, 0.5)
		cs.shape = box
		fl.add_child(cs)
		fl.position = Vector3(-1.5, 1.25, -10.0)
		fl.set_meta("interactable_label", "Ambil Senter")
		fl.set_meta("interact_callback", Callable(func():
			GameManager.acquire_item("flashlight")
			GameManager.flashlight_active = true
			var p = GameManager.get_player()
			if is_instance_valid(p) and p.has_method("_sync_flashlight_visibility"):
				p._sync_flashlight_visibility()
			fl.queue_free()
			print("[Corridor] Senter diambil di Level 6!")
		))
		var props_root = get_node_or_null("Props")
		if props_root:
			props_root.add_child(fl)
		else:
			add_child(fl)

func _on_exit_area_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or not _player_in_corridor:
		return
	_player_in_corridor = false
	var main = get_tree().root.get_node_or_null("Main")
	if is_instance_valid(main) and main.has_method("fade"):
		main.fade(1.0, 0.1)
	await get_tree().create_timer(0.5).timeout

	if GameManager.current_level == 0:
		GameManager._go_to_level(1)
	else:
		GameManager.player_chose_exit()

func _on_entrance_area_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or not _player_in_corridor:
		return
	if GameManager.current_level == 0:
		return
	_player_in_corridor = false
	var main = get_tree().root.get_node_or_null("Main")
	if is_instance_valid(main) and main.has_method("fade"):
		main.fade(1.0, 0.1)
	await get_tree().create_timer(0.5).timeout
	GameManager.player_chose_back()

func _setup_hollow() -> void:
	if not is_instance_valid(the_hollow):
		return

	var level := GameManager.current_level

	if level not in [7, 8]:
		the_hollow.visible = false
		the_hollow.set_process(false)
		the_hollow.set_physics_process(false)
		return

	if the_hollow.has_method("setup_for_level"):
		the_hollow.setup_for_level(level)

	if level == 7:
		the_hollow.visible = false
		the_hollow.set_process(false)
		the_hollow.set_physics_process(false)
		if the_hollow.has_method("set_detect_flashlight"):
			the_hollow.set_detect_flashlight(false)
		return

	if level == 8 and GameManager.current_level_has_anomaly:
		the_hollow.visible = true
		the_hollow.global_position = Vector3(0, 0.1, -10)
		the_hollow.rotation_degrees.y = 180.0
		if the_hollow.has_method("activate"):
			the_hollow.activate()
		return

	the_hollow.global_position = Vector3(0, 0.1, -10)
	the_hollow.rotation_degrees.y = 180.0

	if the_hollow.has_method("set_patrol_from_world_positions"):
		the_hollow.set_patrol_from_world_positions([
			Vector3(0, 0, -10),
			Vector3(0, 0, 8),
		])
	if the_hollow.has_method("activate"):
		the_hollow.activate()

func _process(delta: float) -> void:
	if GameManager.current_level == 4 and _player_in_corridor and not _level4_heads_spawned:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player := players[0] as Node3D
			if player.global_position.z < -4.0:
				_level4_heads_spawned = true
				_spawn_crying_head_horde()

	if _crying_head_chase_active and GameManager.current_level == 4 and _player_in_corridor:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player := players[0] as Node3D
			# Target entrance door (Z > 0)
			var target_pos := Vector3(0.0, 0.0, 12.0)
			for head in _crying_heads:
				if not is_instance_valid(head):
					continue
				var flat_dir := Vector3(target_pos.x - head.global_position.x, 0.0, target_pos.z - head.global_position.z)
				if flat_dir.length() > 0.5:
					flat_dir = flat_dir.normalized()
					head.global_position += flat_dir * 4.5 * delta
					head.look_at(head.global_position + flat_dir, Vector3.UP)

	if GameManager.current_level in [7, 8] and is_instance_valid(the_hollow) and _player_in_corridor:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player = players[0]
			var forward = Vector3.ZERO
			if player.has_method("get_look_direction"):
				forward = player.get_look_direction()
			else:
				var cam = player.get_node_or_null("Camera3D")
				if is_instance_valid(cam):
					forward = -cam.global_transform.basis.z
			if forward != Vector3.ZERO:
				if GameManager.current_level == 7:
					if not _level7_zombie_spawned:
						if forward.z > 0.5:
							_level7_zombie_spawned = true
							the_hollow.visible = true
							if shtt_player and shtt_player.stream:
								shtt_player.play()
					if _level7_zombie_spawned:
						var target_z = player.global_position.z + 3.5
						target_z = min(target_z, 11.0)
						var hw_pos := Vector3(player.global_position.x, player.global_position.y, target_z)
						the_hollow.global_position = hw_pos
						if hw_pos.distance_to(player.global_position) > 0.1:
							the_hollow.look_at(player.global_position, Vector3.UP)
							the_hollow.rotation.x = 0
							the_hollow.rotation.z = 0
				elif GameManager.current_level == 8:
					if not _level8_zombie_spawned:
						if forward.z > 0.5:
							_level8_zombie_spawned = true
							the_hollow.visible = true
							if shtt_player and shtt_player.stream:
								shtt_player.play()
							var dir = forward
							dir.y = 0
							dir = dir.normalized()
							the_hollow.global_position = player.global_position + dir * 1.5
							if dir.length() > 0.1:
								the_hollow.look_at(player.global_position, Vector3.UP)
								the_hollow.rotation.x = 0
								the_hollow.rotation.z = 0

func _spawn_crying_head_horde() -> void:
	var pk := load("res://assets/crying_head.glb") as PackedScene
	if not pk:
		print("[Corridor] WARN: crying_head.glb tidak ditemukan")
		return

	var tex := load("res://assets/crying_head_0.png") as Texture2D

	for i in 25:
		var head := pk.instantiate() as Node3D
		head.position = Vector3(
			-1.5 + randf_range(-1.0, 1.0),
			randf_range(0.2, 1.5),
			-10.0 + randf_range(-0.5, 0.5)
		)
		head.scale = Vector3.ONE * randf_range(0.3, 0.5)
		if tex:
			_apply_texture_recursive(head, tex)
		add_child(head)
		_crying_heads.append(head)

	_crying_head_chase_active = true

	var sound := AudioStreamPlayer.new()
	var s = load("res://assets/audioo/zombie.mp3")
	if s:
		sound.stream = s
	add_child(sound)
	sound.play()

	print("[Corridor] Level 4: %d crying heads keluar dari dumpster!" % _crying_heads.size())

func _setup_corridor_props() -> void:
	var props_root  := get_node_or_null("Props")
	var anom_root   := get_node_or_null("Props/AnomalyObjects")
	if not is_instance_valid(props_root) or not is_instance_valid(anom_root):
		return

	var mp := "res://assets/models/"
	var ph := "res://assets/models/horror_room/"

	var dd_pk := load("res://assets/double_door.glb") as PackedScene
	if dd_pk:
		for door_path in ["ExitDoor", "EntranceDoor"]:
			var door_node = get_node_or_null(door_path)
			if door_node:
				var old_mesh = door_node.get_node_or_null("DoorMesh")
				if is_instance_valid(old_mesh):
					old_mesh.visible = false
				var dd := dd_pk.instantiate() as Node3D
				dd.name = "double_door_custom"
				dd.scale = Vector3.ONE * 1.25
				dd.position = Vector3(0, -1.25, 0)
				door_node.add_child(dd)
				var tex = load("res://assets/double_door_0.png")
				if tex:
					_apply_texture_recursive(dd, tex)

	var frame_z := [8.5, 4.5, 0.5, -3.5, -7.5]
	var poster_order := [1, 2, 3, 4, 5]
	if GameManager.current_level == 2:
		poster_order = [1, 2, 4, 5, 3]
	for i in 5:
		_add_poster(anom_root, Vector3(2.40, 1.8, frame_z[i]), -90.0, poster_order[i])

	_add_carpet_section(props_root, Vector3(0.0, 0.01, -5.0))

	var dumpster_pk := load("res://assets/dumpster_-_4096px2.glb") as PackedScene
	if dumpster_pk:
		var d := dumpster_pk.instantiate() as Node3D
		d.position = Vector3(-1.5, 0.0, -10.0)
		d.rotation_degrees.y = 90.0
		d.scale = Vector3.ONE * 1.1
		props_root.add_child(d)
	var wet_pk := load("res://assets/wet_floor_sign.glb") as PackedScene
	if wet_pk:
		var wf := wet_pk.instantiate() as Node3D
		wf.position = Vector3(1.5, 0.45, -9.5)
		wf.scale = Vector3.ONE * 0.015
		wf.rotation_degrees.y = -15.0
		props_root.add_child(wf)
	var kotak_aneh = get_node_or_null("Props/AnomalyObjects/Anomaly_Chair")
	if is_instance_valid(kotak_aneh):
		kotak_aneh.queue_free()

	_add_red_carpet(props_root)

	_add_chandelier(props_root, Vector3(0, 3.1, -10.5))
	_add_chandelier(props_root, Vector3(0, 3.1, -4.5))
	_add_chandelier(props_root, Vector3(0, 3.1,  4.5))
	_add_chandelier(props_root, Vector3(0, 3.1,  10.5))

	var plant_pk := load(ph + "potted_plant_01/potted_plant_01_2k.gltf") as PackedScene
	if plant_pk:
		for pos_r: Array in [
			[Vector3( 1.5, 0, -11.0), -20.0],
			[Vector3(-1.5, 0,  11.0),  20.0],
			[Vector3( 1.5, 0,  11.0), -15.0],
		]:
			var pl := plant_pk.instantiate() as Node3D
			pl.position = pos_r[0] + Vector3(0, 0.1, 0)
			pl.rotation_degrees.y = pos_r[1]
			pl.scale = Vector3.ONE * 0.9
			props_root.add_child(pl)

	print("[Corridor] Props spawned.")

func _add_carpet_section(parent: Node3D, pos: Vector3) -> void:
	var carpet := MeshInstance3D.new()
	var cm := BoxMesh.new(); cm.size = Vector3(2.8, 0.03, 16.0)
	carpet.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.22, 0.18); mat.roughness = 1.0
	carpet.set_surface_override_material(0, mat)
	carpet.position = pos
	parent.add_child(carpet)

func _add_trash_can(parent: Node3D, pos: Vector3) -> void:
	var tc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.25
	cm.bottom_radius = 0.25
	cm.height = 0.7
	tc.mesh = cm
	var mat := StandardMaterial3D.new()
	var tex = load("res://assets/Metro/Textures/trash_can.png")
	if not tex:
		tex = load("res://assets/Metro/Models/Metro_trash_can.png")
	if tex:
		mat.albedo_texture = tex
	else:
		mat.albedo_color = Color(0.2, 0.2, 0.2)
	mat.roughness = 0.8
	tc.set_surface_override_material(0, mat)
	tc.position = pos + Vector3(0, 0.35, 0)
	parent.add_child(tc)
	tc.add_to_group("anomaly_object")

func _add_poster(parent: Node3D, pos: Vector3, rot_y: float, poster_id: int) -> void:
	var poster := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.8, 1.2)
	poster.mesh = qm
	var mat := StandardMaterial3D.new()
	var tex = load("res://assets/poster jpg/poster %d.jpg" % poster_id)
	if tex:
		mat.albedo_texture = tex
	else:
		mat.albedo_color = Color(0.8, 0.8, 0.8)
	mat.roughness = 1.0
	poster.set_surface_override_material(0, mat)
	poster.position = pos
	poster.rotation_degrees.y = rot_y
	parent.add_child(poster)
	poster.add_to_group("anomaly_object")

func _apply_texture_recursive(node: Node, tex: Texture2D) -> void:
	if node is MeshInstance3D:
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.roughness = 0.9
		node.set_surface_override_material(0, mat)
	for child in node.get_children():
		_apply_texture_recursive(child, tex)

func _add_red_carpet(parent: Node3D) -> void:
	var carpet := MeshInstance3D.new()
	var cm := BoxMesh.new(); cm.size = Vector3(1.35, 0.025, 23.0)
	carpet.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.04, 0.04); mat.roughness = 0.95
	carpet.set_surface_override_material(0, mat)
	carpet.position = Vector3(0, 0.013, 0)
	parent.add_child(carpet)

func _add_chandelier(parent: Node3D, pos: Vector3) -> void:
	var pk := load("res://assets/models/horror_room/Chandelier_01/Chandelier_01_2k.gltf") as PackedScene
	if not pk:
		pk = load("res://assets/models/horror_room/Chandelier_02/Chandelier_02_2k.gltf") as PackedScene
	if pk:
		var ch := pk.instantiate() as Node3D
		ch.position = pos; ch.scale = Vector3.ONE * 0.9
		parent.add_child(ch)

	var light := OmniLight3D.new()
	light.light_color = Color(0.9, 0.7, 0.3)
	light.light_energy = 1.2; light.omni_range = 7.0
	light.shadow_enabled = false
	light.position = pos + Vector3(0, -0.5, 0)
	parent.add_child(light)

func _setup_level8_fake_out() -> void:
	var exit_door := get_node_or_null("ExitDoor")
	if is_instance_valid(exit_door):
		for child in exit_door.get_children():
			if child.name == "DoorMesh":
				child.visible = false
			elif child.name.begins_with("double_door"):
				var l_door = child.get_node_or_null("Sketchfab_model/b497ea9de65748f2975b672baaf8991a_fbx/RootNode/OLD_DOOR/L")
				var r_door = child.get_node_or_null("Sketchfab_model/b497ea9de65748f2975b672baaf8991a_fbx/RootNode/OLD_DOOR/R")
				if is_instance_valid(l_door):
					l_door.rotation_degrees.z = -90
				if is_instance_valid(r_door):
					r_door.rotation_degrees.z = 90

	var portal := MeshInstance3D.new()
	var pm := QuadMesh.new(); pm.size = Vector2(2.5, 3.0)
	portal.mesh = pm
	var mat := StandardMaterial3D.new()
	var tex = load("res://assets/pine_forest_1.jpg")
	if tex:
		mat.albedo_texture = tex
	else:
		mat.albedo_color = Color(0.85, 0.95, 1.0)
	mat.emission_enabled = true; mat.emission = Color(0.6, 0.85, 1.0)
	mat.emission_energy_multiplier = 0.5
	if tex:
		mat.emission_texture = tex
	portal.set_surface_override_material(0, mat)
	portal.position = Vector3(0, 1.25, -12.1)
	add_child(portal)

	var light_portal := OmniLight3D.new()
	light_portal.light_color = Color(0.8, 0.95, 1.0)
	light_portal.light_energy = 4.0; light_portal.omni_range = 8.0
	light_portal.position = Vector3(0, 1.25, -11.5)
	add_child(light_portal)

	print("[Corridor] Level 8 Fake Out applied.")
