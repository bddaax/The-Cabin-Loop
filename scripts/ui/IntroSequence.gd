extends Node3D

signal intro_finished

const BLINK_CLOSE := 0.22
const BLINK_HOLD  := 0.10
const BLINK_OPEN  := 0.52

var _cam: Camera3D
var _blink_rect: ColorRect
var _meadow_env: Node3D
var _forest_env: Node3D
var _hollow: Node3D
var _horde: Node3D
var _skip_requested: bool = false
var _world_env: WorldEnvironment
var _env_meadow: Environment
var _env_forest: Environment

func _ready() -> void:
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 1.7, 0)
	_cam.rotation_degrees = Vector3(-4, 0, 0)
	add_child(_cam)

	var cl := CanvasLayer.new()
	cl.layer = 50
	add_child(cl)
	_blink_rect = ColorRect.new()
	_blink_rect.color = Color(0, 0, 0, 1.0)
	_blink_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blink_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cl.add_child(_blink_rect)

	var skip_label := Label.new()
	skip_label.text = "[SPACE / ESC] Lewati"
	skip_label.add_theme_font_size_override("font_size", 14)
	skip_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_label.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
	skip_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skip_label.offset_right  = -20
	skip_label.offset_bottom = -20
	cl.add_child(skip_label)

	_world_env = WorldEnvironment.new()
	add_child(_world_env)

	_build_meadow_env()
	_build_forest_env()
	_build_hollow()
	_build_horde()

	_run.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_skip_requested = true

func _run() -> void:
	_set_env(false)
	await _open_eyes()
	if _skip_requested: _finish_immediately(); return
	await _wait(1.0)
	await _look_around_360(6.5)
	await _wait(0.5)

	await _blink_switch(true)
	if _skip_requested: _finish_immediately(); return
	_play_gasp_sound()
	_shake_camera(3.0, 0.5)
	await _wait(0.6)
	await _look_around(25.0, 1.2)
	await _look_around(15.0, 0.8)
	await _wait(0.4)

	await _fast_blink(false)
	if _skip_requested: _finish_immediately(); return
	await _wait(0.3)
	await _fast_blink(true)
	if _skip_requested: _finish_immediately(); return
	await _wait(0.2)
	await _fast_blink(false)
	if _skip_requested: _finish_immediately(); return
	await _wait(0.15)
	await _fast_blink(true)
	if _skip_requested: _finish_immediately(); return
	await _wait(1.2)

	AudioManager.play_hint(AudioManager.HintType.CREAK)
	await _wait(0.9)

	var turn := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	turn.tween_property(_cam, "rotation_degrees:y", 180.0, 1.9)
	await turn.finished
	if _skip_requested: _finish_immediately(); return

	_hollow.visible = true
	_play_scare_sound(-2.0)
	_shake_camera(2.5, 0.35)
	await _wait(1.3)
	if _skip_requested: _finish_immediately(); return

	# --- Backing away from the creature, too afraid to look away from it ---
	var retreat := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	retreat.tween_property(_cam, "position:z", _cam.position.z - 3.0, 2.6)
	var sway := create_tween().set_loops(7)
	sway.tween_property(_cam, "rotation_degrees:x", -6.0, 0.18)
	sway.tween_property(_cam, "rotation_degrees:x", -2.0, 0.18)
	await retreat.finished
	sway.kill()
	_cam.rotation_degrees.x = -4.0
	if _skip_requested: _finish_immediately(); return

	# --- Backs straight into something solid — a jolt of pure fear ---
	_shake_camera(8.0, 0.4)
	await _wait(0.7)
	if _skip_requested: _finish_immediately(); return

	# --- Slowly, cautiously turns to look behind — afraid of what it'll see ---
	await _wait(0.5)
	var look_back_a := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	look_back_a.tween_property(_cam, "rotation_degrees:y", 100.0, 1.2)
	await look_back_a.finished
	if _skip_requested: _finish_immediately(); return
	await _wait(0.6)
	var look_back_b := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	look_back_b.tween_property(_cam, "rotation_degrees:y", 0.0, 1.4)
	await look_back_b.finished
	if _skip_requested: _finish_immediately(); return

	# --- They were never alone — a horde closes in from every side ---
	_horde.visible = true
	_play_scare_sound(-1.0)
	_shake_camera(5.0, 0.45)
	await _wait(0.6)
	if _skip_requested: _finish_immediately(); return

	# --- Frantic scan left, then right — taking in just how many there are ---
	var scan_l := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	scan_l.tween_property(_cam, "rotation_degrees:y", -30.0, 0.85)
	await scan_l.finished
	if _skip_requested: _finish_immediately(); return
	await _wait(0.2)
	var scan_r := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	scan_r.tween_property(_cam, "rotation_degrees:y", 30.0, 1.3)
	await scan_r.finished
	if _skip_requested: _finish_immediately(); return
	await _wait(0.2)
	var scan_c := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	scan_c.tween_property(_cam, "rotation_degrees:y", 0.0, 0.6)
	await scan_c.finished
	if _skip_requested: _finish_immediately(); return

	var run_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	run_tween.tween_property(_cam, "position:z", _cam.position.z - 18.0, 2.4)

	var bob := create_tween().set_loops(11)
	bob.tween_property(_cam, "rotation_degrees:z",  3.5, 0.11)
	bob.tween_property(_cam, "rotation_degrees:z", -3.5, 0.11)

	await run_tween.finished
	bob.kill()
	_cam.rotation_degrees.z = 0.0

	var crash := create_tween().set_parallel(true).set_trans(Tween.TRANS_BOUNCE)
	crash.tween_property(_cam, "position:y", 0.2, 0.4)
	crash.tween_property(_cam, "rotation_degrees:z", 75.0, 0.4)
	crash.tween_property(_cam, "rotation_degrees:x", -20.0, 0.4)
	await get_tree().create_timer(0.4).timeout

	await _close_eyes()
	await _wait(0.5)
	emit_signal("intro_finished")

func _finish_immediately() -> void:
	var t := create_tween()
	t.tween_property(_blink_rect, "color:a", 1.0, 0.3)
	await t.finished
	emit_signal("intro_finished")

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _open_eyes() -> void:
	var t := create_tween().set_ease(Tween.EASE_OUT)
	t.tween_property(_blink_rect, "color:a", 0.0, BLINK_OPEN)
	await t.finished

func _close_eyes() -> void:
	var t := create_tween().set_ease(Tween.EASE_IN)
	t.tween_property(_blink_rect, "color:a", 1.0, BLINK_CLOSE)
	await t.finished

func _blink_switch(to_forest: bool) -> void:
	await _close_eyes()
	await get_tree().create_timer(BLINK_HOLD).timeout
	_set_env(to_forest)
	await _open_eyes()

func _set_env(forest: bool) -> void:
	_meadow_env.visible = not forest
	_forest_env.visible = forest
	_world_env.environment = _env_forest if forest else _env_meadow
	if forest:
		_cam.rotation_degrees.y = 0.0

func _look_around(angle_deg: float, duration: float) -> void:
	var orig := _cam.rotation_degrees.y
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_cam, "rotation_degrees:y", orig + angle_deg * 0.55, duration * 0.28)
	t.tween_property(_cam, "rotation_degrees:y", orig - angle_deg * 0.45, duration * 0.44)
	t.tween_property(_cam, "rotation_degrees:y", orig, duration * 0.28)
	await t.finished

func _look_around_360(duration: float) -> void:
	var orig := _cam.rotation_degrees.y
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_cam, "rotation_degrees:y", orig + 230.0, duration)
	await t.finished
	await get_tree().create_timer(0.8).timeout

func _fast_blink(to_forest: bool) -> void:
	var t1 := create_tween().set_ease(Tween.EASE_IN)
	t1.tween_property(_blink_rect, "color:a", 1.0, 0.08)
	await t1.finished
	_set_env(to_forest)
	var t2 := create_tween().set_ease(Tween.EASE_OUT)
	t2.tween_property(_blink_rect, "color:a", 0.0, 0.08)
	await t2.finished

func _shake_camera(intensity: float, duration: float) -> void:
	var orig_rot := _cam.rotation_degrees
	var t := create_tween()
	var steps := int(duration / 0.05)
	for i in steps:
		var offset_x := randf_range(-intensity, intensity)
		var offset_y := randf_range(-intensity, intensity)
		var offset_z := randf_range(-intensity, intensity)
		t.tween_property(_cam, "rotation_degrees", orig_rot + Vector3(offset_x, offset_y, offset_z), 0.05)
	t.tween_property(_cam, "rotation_degrees", orig_rot, 0.05)

func _play_gasp_sound() -> void:
	var gasp := AudioStreamPlayer.new()
	add_child(gasp)
	gasp.play()
	get_tree().create_timer(3.0).timeout.connect(gasp.queue_free)

func _build_meadow_env() -> void:
	_meadow_env = Node3D.new()
	_meadow_env.name = "MeadowEnv"
	add_child(_meadow_env)

	_env_meadow = Environment.new()
	var env := _env_meadow
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
	env.glow_hdr_threshold        = 0.9
	env.fog_enabled               = true
	env.fog_light_color           = Color(0.72, 0.82, 1.00, 1)
	env.fog_density               = 0.003
	env.fog_aerial_perspective    = 0.5
	_world_env.environment = _env_meadow

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 55.0, 0.0)
	sun.light_color  = Color(1.0, 0.92, 0.75, 1)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	_meadow_env.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-60.0, -120.0, 0.0)
	fill.light_color  = Color(0.55, 0.70, 1.00, 1)
	fill.light_energy = 0.3
	fill.shadow_enabled = false
	_meadow_env.add_child(fill)

	var tree_scene := load("res://assets/low_poly_tree_scene_free.glb") as PackedScene
	if tree_scene:
		var trees := tree_scene.instantiate()
		_meadow_env.add_child(trees)

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
		_meadow_env.add_child(ff)

func _build_forest_env() -> void:
	_forest_env = Node3D.new()
	_forest_env.name = "ForestEnv"
	_forest_env.visible = false
	add_child(_forest_env)

	_env_forest = Environment.new()
	var env := _env_forest
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color        = Color(0.00, 0.00, 0.02, 1)
	sky_mat.sky_horizon_color    = Color(0.04, 0.02, 0.06, 1)
	sky_mat.ground_bottom_color  = Color(0.00, 0.00, 0.00, 1)
	sky_mat.ground_horizon_color = Color(0.02, 0.01, 0.03, 1)
	sky_mat.sun_angle_max = 2.0
	sky_mat.sun_curve     = 0.05
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source      = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color       = Color(0.20, 0.25, 0.40, 1)
	env.ambient_light_energy      = 1.0
	env.tonemap_mode              = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled              = true
	env.glow_normalized           = true
	env.glow_intensity            = 1.0
	env.glow_bloom                = 0.12
	env.glow_hdr_threshold        = 0.5
	env.fog_enabled               = true
	env.fog_density               = 0.04
	env.fog_light_color           = Color(0.05, 0.04, 0.10, 1)
	env.fog_aerial_perspective    = 0.8

	var moon := DirectionalLight3D.new()
	moon.light_color    = Color(0.55, 0.68, 1.00, 1)
	moon.light_energy   = 0.8
	moon.shadow_enabled = true
	moon.shadow_opacity = 0.75
	moon.transform = Transform3D(Vector3(0.866, -0.433, 0.25), Vector3(0, 0.5, 0.866), Vector3(-0.5, -0.75, 0.433), Vector3(0, 8, 0))
	_forest_env.add_child(moon)

	var gmesh := MeshInstance3D.new()
	var gbm   := BoxMesh.new()
	gbm.size  = Vector3(200, 0.5, 200)
	gmesh.mesh = gbm
	var gmat  := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.03, 0.04, 0.02, 1)
	gmat.roughness    = 1.0
	gmesh.set_surface_override_material(0, gmat)
	gmesh.position = Vector3(0, -0.25, 0)
	_forest_env.add_child(gmesh)

	var fog_plane := MeshInstance3D.new()
	var fpm := PlaneMesh.new()
	fpm.size = Vector2(200, 200)
	fog_plane.mesh = fpm
	var fog_mat := StandardMaterial3D.new()
	fog_mat.albedo_color     = Color(0.05, 0.04, 0.08, 0.45)
	fog_mat.transparency     = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog_mat.shading_mode     = BaseMaterial3D.SHADING_MODE_UNSHADED
	fog_mat.no_depth_test    = false
	fog_plane.set_surface_override_material(0, fog_mat)
	fog_plane.position = Vector3(0, 0.08, 0)
	_forest_env.add_child(fog_plane)

	var grass_mm := MultiMesh.new()
	grass_mm.transform_format = MultiMesh.TRANSFORM_3D
	grass_mm.instance_count   = 3000
	var blade := CylinderMesh.new()
	blade.top_radius    = 0.0
	blade.bottom_radius = 0.04
	blade.height        = 0.45
	grass_mm.mesh = blade
	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_color            = Color(0.06, 0.14, 0.05, 1)
	grass_mat.roughness               = 1.0
	grass_mat.emission_enabled        = true
	grass_mat.emission                = Color(0.02, 0.06, 0.01, 1)
	grass_mat.emission_energy_multiplier = 0.4
	var grass_mmi := MultiMeshInstance3D.new()
	grass_mmi.multimesh        = grass_mm
	grass_mmi.material_override = grass_mat
	_forest_env.add_child(grass_mmi)
	for i in 3000:
		var gx := randf_range(-28.0, 28.0)
		var gz := randf_range(-38.0, 22.0)
		var gy := randf_range(0.0, 0.22)
		var t := Transform3D()
		t = t.rotated(Vector3.UP, randf_range(0.0, TAU))
		t.origin = Vector3(gx, gy, gz)
		grass_mm.set_instance_transform(i, t)

	var pine_forest := load("res://assets/pine_forest.glb") as PackedScene
	if pine_forest:
		var positions := [
			Vector3(0.0,   0.0,  0.0),
			Vector3(-20.0, 0.0, -10.0),
			Vector3( 20.0, 0.0, -10.0),
			Vector3(-18.0, 0.0, -30.0),
			Vector3( 18.0, 0.0, -30.0),
			Vector3(-22.0, 0.0,  12.0),
			Vector3( 22.0, 0.0,  12.0),
		]
		for pos in positions:
			var t := pine_forest.instantiate()
			t.position = pos
			t.rotation_degrees.y = randf_range(0.0, 360.0)
			_forest_env.add_child(t)

func _build_hollow() -> void:
	_hollow = Node3D.new()
	_hollow.name  = "HollowSilhouette"
	_hollow.visible = false
	_forest_env.add_child(_hollow)
	_hollow.position = Vector3(0, 0, 3.2)

	var zombie_scene = load("res://assets/zombie_GLTF/scene.gltf")
	if zombie_scene:
		var zombie = zombie_scene.instantiate()
		zombie.scale = Vector3(1.3, 1.3, 1.3)
		zombie.rotation_degrees.y = 180.0
		_hollow.add_child(zombie)
		_play_first_animation(zombie)

	var glow := OmniLight3D.new()
	glow.light_color  = Color(1.0, 0.0, 0.0)
	glow.light_energy = 3.5
	glow.omni_range   = 5.0
	glow.shadow_enabled = false
	glow.position = Vector3(0, 1.9, -0.2)
	_hollow.add_child(glow)

func _build_horde() -> void:
	_horde = Node3D.new()
	_horde.name = "ZombieHorde"
	_horde.visible = false
	_forest_env.add_child(_horde)

	var hollow_pk    = load("res://assets/zombie_GLTF/scene.gltf")
	var zombie_pk    := load("res://assets/monster/zombie.glb") as PackedScene
	var crawler_pk   := load("res://assets/monster/animated_injured_zombie_crawling_loop.glb") as PackedScene

	# [packed scene, position, rotation_y, uniform scale]
	var spawns: Array = [
		[hollow_pk,  Vector3(-2.6, 0,  -5.0),   40.0, 1.3],
		[zombie_pk,  Vector3( 2.2, 0,  -6.5),  -30.0, 1.8],
		[crawler_pk, Vector3(-0.6, 0,  -9.0),   70.0, 0.5],
		[hollow_pk,  Vector3( 2.8, 0, -11.0), -150.0, 1.3],
		[zombie_pk,  Vector3(-2.8, 0, -13.5),  110.0, 1.8],
	]

	for spawn in spawns:
		var pk = spawn[0]
		if not pk:
			continue
		var inst = pk.instantiate()
		_horde.add_child(inst)
		inst.position = spawn[1]
		inst.rotation_degrees.y = spawn[2]
		inst.scale = Vector3.ONE * float(spawn[3])
		_play_first_animation(inst)

func _play_first_animation(node: Node) -> void:
	var to_check = [node]
	while to_check.size() > 0:
		var n = to_check.pop_back()
		if n is AnimationPlayer:
			var anims: PackedStringArray = n.get_animation_list()
			if anims.size() > 0:
				n.get_animation(anims[0]).loop_mode = Animation.LOOP_LINEAR
				n.play(anims[0])
			return
		to_check.append_array(n.get_children())

func _play_scare_sound(volume_db: float) -> void:
	var p := AudioStreamPlayer.new()
	add_child(p)
	var stream = load("res://assets/audioo/zombie.mp3")
	if stream:
		p.stream = stream
		p.volume_db = volume_db
		p.play()
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)
