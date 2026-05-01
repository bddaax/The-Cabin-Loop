extends Node3D

signal start_game_pressed

var _page_story:    Control
var _page_controls: Control
var _page_start:    Control
var _ui_layer: CanvasLayer

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_background()
	_build_ui()
	_show_page(0)

func _process(_delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _build_background() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 2.8, 9.0)
	cam.look_at(Vector3(0, 2.2, 0), Vector3.UP)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode  = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.04, 0.04, 0.06)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled     = true
	env.fog_density     = 0.018
	env.fog_light_color = Color(0.02, 0.02, 0.04)
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.light_color  = Color(0.60, 0.68, 0.88)
	moon.light_energy = 0.6
	moon.shadow_enabled = true
	moon.shadow_opacity = 0.7
	moon.transform = Transform3D(Vector3(0.866, -0.433, 0.25), Vector3(0, 0.5, 0.866), Vector3(-0.5, -0.75, 0.433), Vector3(0, 12, 0))
	add_child(moon)

	var gmesh := MeshInstance3D.new()
	var gbm   := BoxMesh.new()
	gbm.size  = Vector3(80, 0.4, 80)
	gmesh.mesh = gbm
	var gmat  := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.05, 0.06, 0.03)
	gmat.roughness = 1.0
	gmesh.set_surface_override_material(0, gmat)
	gmesh.position = Vector3(0, -0.2, 0)
	add_child(gmesh)

	_build_house()
	_build_hollow_near_door()

func _build_house() -> void:
	var house := Node3D.new()
	house.name = "HouseFront"
	add_child(house)

	var mat_wall := StandardMaterial3D.new()
	mat_wall.albedo_color = Color(0.06, 0.06, 0.07)
	mat_wall.roughness = 0.85

	var mat_roof := StandardMaterial3D.new()
	mat_roof.albedo_color = Color(0.03, 0.03, 0.03)
	mat_roof.roughness = 0.9

	var mat_door := StandardMaterial3D.new()
	mat_door.albedo_color = Color(0.09, 0.05, 0.02)
	mat_door.roughness = 0.85

	var mat_porch_light := StandardMaterial3D.new()
	mat_porch_light.albedo_color = Color(1.0, 0.9, 0.7)
	mat_porch_light.emission_enabled = true
	mat_porch_light.emission = Color(0.6, 0.4, 0.2)
	mat_porch_light.emission_energy_multiplier = 1.5

	var wall := MeshInstance3D.new()
	var wbm  := BoxMesh.new()
	wbm.size = Vector3(14.0, 6.0, 0.6)
	wall.mesh = wbm
	wall.set_surface_override_material(0, mat_wall)
	wall.position = Vector3(0, 3.0, 0)
	house.add_child(wall)

	var roof := MeshInstance3D.new()
	var rbm  := PrismMesh.new()
	rbm.size = Vector3(15.0, 4.0, 7.0)
	roof.mesh = rbm
	roof.set_surface_override_material(0, mat_roof)
	roof.position = Vector3(0, 7.8, 0)
	house.add_child(roof)

	var door := MeshInstance3D.new()
	var dbm  := BoxMesh.new()
	dbm.size = Vector3(1.5, 3.0, 0.15)
	door.mesh = dbm
	door.set_surface_override_material(0, mat_door)
	door.position = Vector3(0, 1.5, 0.22)
	house.add_child(door)

	var step := MeshInstance3D.new()
	var sbm  := BoxMesh.new()
	sbm.size = Vector3(3.5, 0.22, 1.2)
	step.mesh = sbm
	step.set_surface_override_material(0, mat_wall)
	step.position = Vector3(0, 0.11, 1.2)
	house.add_child(step)

	var pl_mesh := MeshInstance3D.new()
	var plbm    := BoxMesh.new()
	plbm.size = Vector3(0.3, 0.12, 0.3)
	pl_mesh.mesh = plbm
	pl_mesh.set_surface_override_material(0, mat_porch_light)
	pl_mesh.position = Vector3(1.0, 4.0, 0.5)
	house.add_child(pl_mesh)

	var pl_light := SpotLight3D.new()
	pl_light.light_color  = Color(1.0, 0.7, 0.35)
	pl_light.light_energy = 2.0
	pl_light.spot_range   = 8.0
	pl_light.spot_angle   = 45.0
	pl_light.shadow_enabled = true
	pl_light.transform = Transform3D(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0), Vector3(1.0, 3.9, 0.5))
	house.add_child(pl_light)

func _build_hollow_near_door() -> void:
	var hollow := Node3D.new()
	hollow.name = "TitleHollow"
	hollow.position = Vector3(2.4, 0, 0.6)
	add_child(hollow)

	var zombie_scene = load("res://assets/zombie_GLTF/scene.gltf")
	if zombie_scene:
		var zombie = zombie_scene.instantiate()
		zombie.scale = Vector3(1.3, 1.3, 1.3)
		zombie.rotation_degrees.y = 180.0
		hollow.add_child(zombie)
		var to_check = [zombie]
		var anim_player = null
		while to_check.size() > 0:
			var node = to_check.pop_back()
			if node is AnimationPlayer:
				anim_player = node
				break
			to_check.append_array(node.get_children())
		if anim_player:
			if anim_player.has_animation("IDLE"):
				anim_player.get_animation("IDLE").loop_mode = Animation.LOOP_LINEAR
				anim_player.play("IDLE")

	var glow := OmniLight3D.new()
	glow.light_color  = Color(1.0, 0.0, 0.0)
	glow.light_energy = 2.0
	glow.omni_range   = 4.0
	glow.shadow_enabled = false
	glow.position = Vector3(0, 1.9, -0.2)
	hollow.add_child(glow)

	hollow.rotation_degrees.y = 180.0

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 20
	add_child(_ui_layer)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.52)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(bg)

	_page_story    = _build_page_story()
	_page_controls = _build_page_controls()
	_page_start    = _build_page_start()

	_ui_layer.add_child(_page_story)
	_ui_layer.add_child(_page_controls)
	_ui_layer.add_child(_page_start)

func _show_page(idx: int) -> void:
	_page_story.visible    = (idx == 0)
	_page_controls.visible = (idx == 1)
	_page_start.visible    = (idx == 2)

func _build_page_story() -> Control:
	var page := CenterContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(700, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 28)
	page.add_child(box)

	var title := Label.new()
	title.text = "THE CABIN LOOP"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.82))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sep1 := Label.new()
	sep1.text = "──────────────────────────────"
	sep1.add_theme_color_override("font_color", Color(0.5, 0.4, 0.3, 0.6))
	sep1.add_theme_font_size_override("font_size", 14)
	sep1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sep1)

	var story := Label.new()
	story.text = (
		"One blink took the meadows away; now, only these walls remain.\n\n" +
		"Two doors, one choice, and a thousand eyes in the wood.\n\n" +
		"If the room feels wrong, turn back.\n" +
		"If it feels right, move deeper into the dark.\n\n" +
		"But remember: It doesn't need to hear you to know you're there."
	)
	story.add_theme_font_size_override("font_size", 20)
	story.add_theme_color_override("font_color", Color(0.88, 0.85, 0.80))
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(story)

	var btn := _make_button("LANJUT  →")
	btn.pressed.connect(func(): _show_page(1))
	box.add_child(btn)

	return page

func _build_page_controls() -> Control:
	var page := CenterContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(600, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	page.add_child(box)

	var title := Label.new()
	title.text = "PANDUAN"
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.82))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var controls_text: Array[String] = [
		"W / A / S / D       —   Bergerak",
		"MOUSE               —   Lihat sekitar",
		"E                   —   Interaksi / Ambil item",
		"F                   —   Nyalakan / matikan senter",
		"ESC                 —   Pause",
	]

	for line in controls_text:
		var lbl := Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color(0.88, 0.85, 0.80))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(lbl)

	var tip := Label.new()
	tip.text = "\nTIP: Perhatikan sekitar, jika ada yang aneh, segera berbalik."
	tip.add_theme_font_size_override("font_size", 16)
	tip.add_theme_color_override("font_color", Color(0.70, 0.65, 0.55))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tip)

	var btn := _make_button("SIAP  →")
	btn.pressed.connect(func(): _show_page(2))
	box.add_child(btn)

	return page

func _build_page_start() -> Control:
	var page := CenterContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(500, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 32)
	page.add_child(box)

	var title := Label.new()
	title.text = "THE CABIN LOOP"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.80))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Individual Game Jam CSUI 2026"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.58, 0.50))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	box.add_child(spacer)

	var btn := _make_button("MULAI GAME")
	btn.add_theme_font_size_override("font_size", 26)
	btn.custom_minimum_size = Vector2(260, 60)
	btn.pressed.connect(func(): emit_signal("start_game_pressed"))
	box.add_child(btn)

	var credit := Label.new()
	credit.text = "Tekan SPACE atau klik untuk mulai"
	credit.add_theme_font_size_override("font_size", 14)
	credit.add_theme_color_override("font_color", Color(0.5, 0.48, 0.44, 0.7))
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(credit)

	return page

func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 48)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.80))
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.12, 0.10, 0.08, 0.85)
	normal_style.border_width_bottom = 2
	normal_style.border_width_top    = 2
	normal_style.border_width_left   = 2
	normal_style.border_width_right  = 2
	normal_style.border_color = Color(0.5, 0.40, 0.28)
	normal_style.corner_radius_top_left     = 6
	normal_style.corner_radius_top_right    = 6
	normal_style.corner_radius_bottom_left  = 6
	normal_style.corner_radius_bottom_right = 6
	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.22, 0.18, 0.13, 0.95)
	hover_style.border_color = Color(0.75, 0.60, 0.40)
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover",  hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)
	return btn

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if _page_story.visible:
			_show_page(1)
		elif _page_controls.visible:
			_show_page(2)
		elif _page_start.visible:
			emit_signal("start_game_pressed")
