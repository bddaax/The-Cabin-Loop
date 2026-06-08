extends Node3D

var _blink_rect: ColorRect
var _scream_player: AudioStreamPlayer
var _cam: Camera3D
var _finish_canvas: CanvasLayer

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_lake_environment()
	_build_finish_overlay()
	_setup_jumpscare_assets()

func _build_lake_environment() -> void:
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 1.7, 0)
	_cam.rotation_degrees = Vector3(-4, 0, 0)
	add_child(_cam)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color        = Color(0.22, 0.38, 0.78, 1)
	sky_mat.sky_horizon_color    = Color(0.90, 0.65, 0.85, 1)
	sky_mat.ground_bottom_color  = Color(0.12, 0.22, 0.10, 1)
	sky_mat.ground_horizon_color = Color(0.55, 0.72, 0.45, 1)
	sky_mat.sun_angle_max = 8.0
	sky_mat.sun_curve     = 0.12
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source      = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy      = 1.0
	env.tonemap_mode              = Environment.TONE_MAPPER_ACES
	env.glow_enabled              = true
	env.glow_normalized           = true
	env.glow_intensity            = 0.6
	env.glow_bloom                = 0.08
	env.fog_enabled               = true
	env.fog_light_color           = Color(0.72, 0.82, 1.00, 1)
	env.fog_density               = 0.003
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 55.0, 0.0)
	sun.light_color  = Color(1.0, 0.92, 0.75, 1)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)

	var tree_scene := load("res://assets/low_poly_tree_scene_free.glb") as PackedScene
	if tree_scene:
		var trees := tree_scene.instantiate()
		add_child(trees)

	var ff_mat := StandardMaterial3D.new()
	ff_mat.albedo_color             = Color(0.9, 1.0, 0.5, 1)
	ff_mat.emission_enabled         = true
	ff_mat.emission                 = Color(0.7, 1.0, 0.3, 1)
	ff_mat.emission_energy_multiplier = 6.0
	ff_mat.transparency             = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 120:
		var ff := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = randf_range(0.025, 0.055)
		sm.height = sm.radius * 2.0
		ff.mesh = sm
		ff.set_surface_override_material(0, ff_mat)
		ff.position = Vector3(
			randf_range(-18.0, 18.0),
			randf_range(0.2, 2.8),
			randf_range(-18.0, 18.0)
		)
		add_child(ff)

func _setup_jumpscare_assets() -> void:
	_scream_player = AudioStreamPlayer.new()
	var sc = load("res://assets/audioo/zombie.mp3")
	if sc:
		_scream_player.stream = sc
	add_child(_scream_player)
	var cl := CanvasLayer.new()
	cl.layer = 100
	_blink_rect = ColorRect.new()
	_blink_rect.color = Color(0,0,0,0)
	_blink_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blink_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_blink_rect)
	add_child(cl)

func _build_finish_overlay() -> void:
	_finish_canvas = CanvasLayer.new()
	_finish_canvas.layer = 20
	add_child(_finish_canvas)

	var vbox := VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.5
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 28)
	_finish_canvas.add_child(vbox)

	var label := Label.new()
	label.text = "FINISH?"
	label.add_theme_font_size_override("font_size", 72)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.88, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(label)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(hbox)

	var btn_menu := Button.new()
	btn_menu.text = "Main Menu"
	btn_menu.add_theme_font_size_override("font_size", 24)
	btn_menu.custom_minimum_size = Vector2(220, 52)
	btn_menu.pressed.connect(_on_main_menu_pressed)
	hbox.add_child(btn_menu)

	var btn_exit := Button.new()
	btn_exit.text = "Exit"
	btn_exit.add_theme_font_size_override("font_size", 24)
	btn_exit.custom_minimum_size = Vector2(160, 52)
	btn_exit.pressed.connect(func(): get_tree().quit())
	hbox.add_child(btn_exit)

func _on_main_menu_pressed() -> void:
	if is_instance_valid(_finish_canvas):
		_finish_canvas.visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Snap to black first — the jumpscare reveal happens out of the darkness.
	var t_out := create_tween()
	t_out.tween_property(_blink_rect, "color", Color(0, 0, 0, 1.0), 0.25)
	await t_out.finished

	var hollow: Node3D = null
	var h_pk = load("res://scenes/TheHollow.tscn") as PackedScene
	if h_pk:
		hollow = h_pk.instantiate() as Node3D
		hollow.position = _cam.global_position + (-_cam.global_transform.basis.z * 1.3)
		hollow.position.y -= 0.4
		add_child(hollow)
		hollow.look_at(_cam.global_position, Vector3.UP)
		hollow.rotation.x = deg_to_rad(-16.0)
		hollow.rotation.z = 0.0
		hollow.visible = true

	if _scream_player and _scream_player.stream:
		_scream_player.play()

	var t_reveal := create_tween()
	t_reveal.tween_property(_blink_rect, "color:a", 0.0, 0.05)

	var orig_rot = _cam.rotation_degrees
	var t_shake := create_tween()
	for i in 14:
		t_shake.tween_property(_cam, "rotation_degrees", orig_rot + Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6)), 0.05)
	t_shake.tween_property(_cam, "rotation_degrees", orig_rot, 0.05)

	await get_tree().create_timer(1.6).timeout

	var t_final := create_tween()
	t_final.tween_property(_blink_rect, "color:a", 1.0, 0.35)
	await t_final.finished
	await get_tree().create_timer(0.4).timeout

	GameManager.current_level = 0
	GameManager.correct_streak = 0
	get_tree().change_scene_to_file("res://scenes/UI/TitleScreen.tscn")
