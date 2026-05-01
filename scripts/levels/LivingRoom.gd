
extends Node3D

@onready var decay_system: Node = $DecaySystem
@onready var corridor_door_area: Area3D = $CorridorDoor/DoorBody
@onready var drawer_area: Area3D = $Furniture/Desk/Drawer
@onready var flashlight_item_area: Area3D = $Furniture/FlashlightItem
var hollow_final: Node3D = null

var _key_taken: bool = false

var _flashlight_taken: bool = false

func _ready() -> void:
	var light_system := get_node_or_null("LightSystem")
	if is_instance_valid(light_system):
		for child in light_system.get_children():
			if child is Light3D:
				child.add_to_group("corridor_lights")

	var decay_meshes := get_node_or_null("DecayMeshes")
	if is_instance_valid(decay_meshes):
		for child in decay_meshes.get_children():
			child.add_to_group("decay_debris")

	var smoke := get_node_or_null("SmokeParticles")
	if is_instance_valid(smoke):
		smoke.add_to_group("smoke_particles")

	if is_instance_valid(decay_system):
		decay_system.initialize_scene(self)

	if is_instance_valid(drawer_area):
		drawer_area.set_meta("interactable_label", "Laci Kosong")
		drawer_area.collision_layer = 4
		drawer_area.collision_mask = 0
		drawer_area.monitoring = false
		drawer_area.monitorable = true

	if is_instance_valid(flashlight_item_area):
		flashlight_item_area.set_meta("interactable_label", "Ambil Senter")
		flashlight_item_area.set_meta("interact_callback", Callable(self, "_on_flashlight_interacted"))
		flashlight_item_area.collision_layer = 4
		flashlight_item_area.collision_mask = 0
		flashlight_item_area.monitoring = false
		flashlight_item_area.monitorable = true

	if is_instance_valid(corridor_door_area):
		corridor_door_area.body_entered.connect(_on_door_body_entered)

	hollow_final = get_node_or_null("TheHollow_Final") as Node3D

	_sync_item_states()
	_update_hollow_final()

	GameManager.game_state_changed.connect(_on_game_state_changed)
	GameManager.level_changed.connect(_on_level_changed)

	AudioManager.play_ambient(AudioManager.AmbientType.LIVING_ROOM)

	var door_mesh_node := get_node_or_null("CorridorDoor/DoorMesh") as MeshInstance3D
	if is_instance_valid(door_mesh_node):
		var dm := BoxMesh.new()
		dm.size = Vector3(1.8, 3.0, 0.2)
		var door_mat := StandardMaterial3D.new()
		door_mat.albedo_color = Color(0.18, 0.11, 0.06)
		door_mat.roughness = 0.9
		door_mesh_node.mesh = dm
		door_mesh_node.set_surface_override_material(0, door_mat)
		door_mesh_node.position = Vector3(0, 0, 0.05)

	_generate_loft_decor()
	print("[LivingRoom] Ready. Level: %d" % GameManager.current_level)

func _generate_loft_decor() -> void:
	var decor := Node3D.new()
	decor.name = "LoftDecor"
	add_child(decor)

	var mp := "res://assets/models/"
	var kk := "res://assets/models/horror_props/KayKit-Halloween-Bits-1.0-main/addons/kaykit_halloween_bits/Assets/gltf/"
	var ix := "res://assets/models/living_room/home_interior/"
	var ph := "res://assets/models/horror_room/"

	var sp := func(path: String, pos: Vector3, ry: float, sc: float) -> void:
		var pk := load(path) as PackedScene
		if not pk:
			return
		var n := pk.instantiate() as Node3D
		n.position = pos
		n.rotation_degrees.y = ry
		n.scale = Vector3.ONE * sc
		decor.add_child(n)

	var f := func(mdl: String, pos: Vector3, ry: float = 0.0, sc: float = 1.0) -> void:
		sp.call(mp + mdl + ".glb", pos, ry, sc)
	var h := func(mdl: String, pos: Vector3, ry: float = 0.0, sc: float = 1.0) -> void:
		sp.call(kk + mdl + ".gltf", pos, ry, sc)
	var p := func(mdl: String, pos: Vector3, ry: float = 0.0, sc: float = 1.0) -> void:
		sp.call(ph + mdl + "/" + mdl + "_2k.gltf", pos, ry, sc)

	for ldata: Array in [
		[Vector3(-2.0, 1.8, 0.0), Color(0.85, 0.5, 0.2), 0.8, 7.0],
		[Vector3( 3.0, 1.5, 3.0), Color(0.9, 0.6, 0.3), 1.0, 5.0],
		[Vector3( 2.5, 2.0, -2.5), Color(0.7, 0.4, 0.2), 0.6, 6.0],
	]:
		var l := OmniLight3D.new()
		l.light_color = ldata[1]; l.light_energy = ldata[2]
		l.omni_range  = ldata[3]; l.shadow_enabled = false
		l.position    = ldata[0]
		add_child(l)

	f.call("rugRectangle",  Vector3(-1.5, 0,  0.0), 90.0, 3.0)
	p.call("sofa_03",       Vector3(-0.5, 0,  0.0), -90.0, 1.0)
	f.call("cabinetTelevisionDoors", Vector3(-3.5, 0, 0.0), -90.0, 1.8)
	f.call("televisionVintage",      Vector3(-3.5, 1.1, 0.0), -90.0, 2.0)
	h.call("skull",                  Vector3(-3.5, 1.2, -1.0), 45.0, 0.3)
	p.call("CoffeeTable_01", Vector3(-2.0, 0, 0.0), 90.0, 1.0)
	f.call("books",          Vector3(-2.0, 0.5, 0.2), 15.0, 1.2)
	p.call("wooden_candlestick", Vector3(-2.0, 0.5, -0.3), 0.0, 0.7)
	h.call("candle_melted",      Vector3(-1.8, 0.5,  0.4), 0.0, 0.5)

	p.call("side_table_01", Vector3(-3.0, 0, 2.0), 0.0, 1.0)
	h.call("candle_triple", Vector3(-3.0, 0.7, 2.0), 30.0, 0.6)

	p.call("Chandelier_01", Vector3(0.0, 5.0, 0.0), 0.0, 1.2)

	_spawn_flashlight_visual(decor, Vector3(-1.8, 0.52, -0.3))
	var fl_area = get_node_or_null("Furniture/FlashlightItem")
	if fl_area:
		fl_area.position = Vector3(-1.8, 0.4, -0.3)

	f.call("desk",           Vector3(3.0, 0,  3.0), 180.0, 1.8)
	f.call("lampRoundTable", Vector3(3.5, 1.3, 3.2), 180.0, 1.5)
	f.call("books",          Vector3(2.3, 1.3, 3.0), 165.0, 1.5)
	p.call("wooden_bookshelf_worn", Vector3(3.8, 0,  1.5), -90.0, 1.0)
	p.call("wooden_bookshelf_worn", Vector3(3.8, 0,  0.0), -90.0, 1.0)

	var drawer = get_node_or_null("Furniture/Desk")
	if drawer:
		drawer.position = Vector3(3.0, 0.4, 3.0)
		drawer.rotation_degrees.y = 180
		var drawer_area = drawer.get_node_or_null("Drawer")
		if drawer_area and not drawer_area.has_node("KeyMesh"):
			var key_mesh = MeshInstance3D.new()
			key_mesh.name = "KeyMesh"
			var cy = CylinderMesh.new()
			cy.top_radius = 0.05; cy.bottom_radius = 0.05; cy.height = 0.01
			key_mesh.mesh = cy
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.8, 0.7, 0.2)
			mat.metallic = 0.8
			key_mesh.set_surface_override_material(0, mat)
			key_mesh.position = Vector3(0, 0.1, -0.2)
			drawer_area.add_child(key_mesh)

	f.call("cardboardBoxOpen",   Vector3( 2.5, 0, -3.0),  45.0, 1.5)
	f.call("books",              Vector3( 3.3, 0, -2.6), -20.0, 1.5)
	f.call("plantSmall1",        Vector3(-3.5, 0,  3.5),  0.0,  2.5)
	p.call("potted_plant_01",    Vector3(-3.5, 0, -3.5),  45.0, 1.5)
	f.call("lampRoundFloor",     Vector3(-0.5, 0, -1.8),  0.0,  2.0)
	f.call("coatRackStanding",   Vector3( 1.5, 0, -3.5),  0.0,  1.8)
	h.call("post_skull",         Vector3( 3.5, 0, -3.5), -45.0, 0.8)
	p.call("vintage_grandfather_clock_01", Vector3(1.0, 0, -3.8), 0.0, 1.0)

	_spawn_frame_on_wall(decor, ix, Vector3(-2.0, 2.2, -3.95),  0.0)
	_spawn_frame_on_wall(decor, ix, Vector3( 0.0, 2.3, -3.95), 13.0)
	_spawn_creepy_painting(decor, Vector3( 2.0, 2.2, -3.95), 0.0, 0.0)
	_spawn_creepy_painting(decor, Vector3( 3.95, 2.2, 0.0), 0.0, -90.0)

	_spawn_wall_clock(decor, Vector3(-1.0, 2.5, -3.92))

	var c_door = get_node_or_null("CorridorDoor")
	if c_door:
		c_door.position = Vector3(0, 1.5, -3.9)
		c_door.rotation_degrees.y = 0.0
func _spawn_flashlight_visual(parent: Node3D, pos: Vector3) -> void:
	var fl := Node3D.new()
	fl.name    = "FlashlightVisual"
	fl.position = pos
	fl.rotation_degrees = Vector3(0, 0, 90)

	var body := MeshInstance3D.new()
	var cyl  := CylinderMesh.new()
	cyl.top_radius    = 0.025
	cyl.bottom_radius = 0.035
	cyl.height        = 0.18
	body.mesh = cyl
	var mat_body := StandardMaterial3D.new()
	mat_body.albedo_color = Color(0.15, 0.15, 0.15)
	mat_body.roughness    = 0.3
	mat_body.metallic     = 0.7
	body.set_surface_override_material(0, mat_body)
	fl.add_child(body)

	var lens := MeshInstance3D.new()
	var sph  := SphereMesh.new()
	sph.radius = 0.028
	sph.height = 0.056
	lens.mesh  = sph
	var mat_lens := StandardMaterial3D.new()
	mat_lens.albedo_color            = Color(1.0, 0.95, 0.8)
	mat_lens.emission_enabled        = true
	mat_lens.emission                = Color(1.0, 0.9, 0.6)
	mat_lens.emission_energy_multiplier = 5.0
	lens.set_surface_override_material(0, mat_lens)
	lens.position = Vector3(0, 0.1, 0)
	fl.add_child(lens)

	parent.add_child(fl)

	var glow := OmniLight3D.new()
	glow.name         = "FlashlightGlow"
	glow.light_color  = Color(1.0, 0.9, 0.6)
	glow.light_energy = 0.6
	glow.omni_range   = 2.5
	glow.shadow_enabled = false
	glow.position     = pos + Vector3(0, 0.15, 0)
	add_child(glow)

func _spawn_frame_on_wall(parent: Node3D, interior_path: String, pos: Vector3, tilt_z: float) -> void:
	var pk := load(interior_path + "frame.glb") as PackedScene
	if pk:
		var inst := pk.instantiate() as Node3D
		inst.position = pos
		inst.rotation_degrees.z = tilt_z
		inst.scale = Vector3.ONE * 2.2
		parent.add_child(inst)
		return
	var m   := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size = Vector3(0.45, 0.6, 0.04)
	m.mesh  = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.4, 0.3)
	m.set_surface_override_material(0, mat)
	m.position        = pos
	m.rotation_degrees.z = tilt_z
	parent.add_child(m)

func _spawn_creepy_painting(parent: Node3D, pos: Vector3, tilt_z: float, rot_y: float) -> void:
	var m   := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size = Vector3(1.2, 1.8, 0.05)
	m.mesh  = bm
	var mat_frame := StandardMaterial3D.new()
	mat_frame.albedo_color = Color(0.2, 0.15, 0.05)
	mat_frame.metallic = 0.8
	mat_frame.roughness = 0.6
	m.set_surface_override_material(0, mat_frame)
	var canvas := MeshInstance3D.new()
	var cm := QuadMesh.new()
	cm.size = Vector2(1.1, 1.7)
	canvas.mesh = cm
	var mat_canvas := StandardMaterial3D.new()
	var img = Image.new()
	if img.load("res://assets/textures/creepy_painting.jpg") == OK:
		var tex = ImageTexture.create_from_image(img)
		mat_canvas.albedo_texture = tex
	else:
		mat_canvas.albedo_color = Color(0.3, 0.0, 0.0)
	mat_canvas.roughness = 0.9
	canvas.set_surface_override_material(0, mat_canvas)
	canvas.position = Vector3(0, 0, 0.03)
	m.add_child(canvas)
	m.position = pos
	m.rotation_degrees.z = tilt_z
	m.rotation_degrees.y = rot_y
	parent.add_child(m)

func _spawn_wall_clock(parent: Node3D, pos: Vector3) -> void:
	var clock := Node3D.new()
	clock.name     = "WallClock"
	clock.position = pos

	var mat_dark := StandardMaterial3D.new()
	mat_dark.albedo_color = Color(0.15, 0.12, 0.10)
	mat_dark.roughness    = 0.9

	var mat_light := StandardMaterial3D.new()
	mat_light.albedo_color = Color(0.85, 0.8, 0.65)

	var face := MeshInstance3D.new()
	var cyl  := CylinderMesh.new()
	cyl.top_radius    = 0.25
	cyl.bottom_radius = 0.25
	cyl.height        = 0.04
	face.mesh = cyl
	face.set_surface_override_material(0, mat_dark)
	face.rotation_degrees.x = 90.0
	clock.add_child(face)

	for arr: Array in [[Vector3(0, 0.10, -0.04), Vector3(0.03, 0.18, 0.03)],
					   [Vector3(0.07, 0.12, -0.04), Vector3(0.02, 0.22, 0.02)]]:
		var hand := MeshInstance3D.new()
		var hm   := BoxMesh.new()
		hm.size  = arr[1]
		hand.mesh = hm
		hand.set_surface_override_material(0, mat_light)
		hand.position = arr[0]
		clock.add_child(hand)

	parent.add_child(clock)

func _on_drawer_interacted() -> void:
	if _key_taken:
		print("[LivingRoom] Laci sudah kosong.")
		return

	_key_taken = true
	GameManager.acquire_item("key")
	var key_mesh := drawer_area.find_child("KeyMesh")
	if is_instance_valid(key_mesh):
		key_mesh.visible = false

	drawer_area.set_meta("interactable_label", "Laci Kosong")
	drawer_area.remove_meta("interact_callback")

	print("[LivingRoom] Kunci diambil dari laci!")

func _on_flashlight_interacted() -> void:
	if _flashlight_taken:
		return

	_flashlight_taken = true
	GameManager.acquire_item("flashlight")
	flashlight_item_area.visible = false
	flashlight_item_area.remove_meta("interact_callback")

	print("[LivingRoom] Senter diambil!")

func _on_door_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	if not GameManager.has_item("key"):
		print("[LivingRoom] Pintu terkunci. Cari kunci terlebih dahulu!")
		for hud in get_tree().get_nodes_in_group("game_hud"):
			if hud.has_method("show_prompt"):
				hud.show_prompt("Pintu terkunci — cari kunci di laci meja tulis")
		return

	print("[LivingRoom] Player masuk koridor!")
	GameManager.enter_corridor()

func _on_game_state_changed(_new_state: GameManager.GameState) -> void:
	_update_hollow_final()

func _on_level_changed(_level_num: int) -> void:
	pass

func _sync_item_states() -> void:
	_key_taken      = GameManager.has_item("key")
	_flashlight_taken = GameManager.has_item("flashlight")

	if _flashlight_taken and is_instance_valid(flashlight_item_area):
		flashlight_item_area.visible = false

func _update_hollow_final() -> void:
	if not is_instance_valid(hollow_final):
		return
	hollow_final.visible = (GameManager.current_state == GameManager.GameState.FINAL)

	if hollow_final.visible and hollow_final.has_method("activate"):
		hollow_final.activate()
