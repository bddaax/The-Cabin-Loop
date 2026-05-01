extends Node3D

@onready var front_door_area: Area3D = $Geometry/House/FrontDoor/DoorBody

var _key_taken: bool = false

func _ready() -> void:
	if is_instance_valid(front_door_area):
		front_door_area.body_entered.connect(_on_door_body_entered)

	if AudioManager.has_method("play_ambient"):
		AudioManager.play_ambient(AudioManager.AmbientType.DARK_CORRIDOR)

	_generate_spooky_trees()
	_spawn_car()
	print("[Yard] Ready.")

func _generate_spooky_trees() -> void:
	var detail_container := Node3D.new()
	detail_container.name = "Trees"
	add_child(detail_container)

	var pine_forest := load("res://assets/pine_forest.glb") as PackedScene
	if pine_forest:
		var forest := pine_forest.instantiate()
		forest.position = Vector3(0.0, 0.0, 0.0)
		detail_container.add_child(forest)

func _spawn_car() -> void:
	var car_scene := load("res://assets/old_rusty_car.glb") as PackedScene
	if not car_scene:
		push_error("[Yard] old_rusty_car.glb tidak ditemukan!")
		return

	var car := car_scene.instantiate() as Node3D
	car.name = "OldCar"
	var s := 0.01
	car.scale = Vector3(s, s, s)
	car.position = Vector3(-6.0, 0.0, 8.0)
	car.rotation_degrees.y = -30.0
	add_child(car)

	var key_area := Area3D.new()
	key_area.name = "CarKeyArea"
	key_area.position = Vector3(-6.0, 1.0, 8.0)
	key_area.collision_layer = 4
	key_area.collision_mask  = 0
	key_area.monitoring  = false
	key_area.monitorable = true

	var col := CollisionShape3D.new()
	var sp  := SphereShape3D.new()
	sp.radius = 1.5
	col.shape = sp
	key_area.add_child(col)
	add_child(key_area)

	if GameManager.has_item("key"):
		_key_taken = true
		key_area.set_meta("interactable_label", "")
	else:
		key_area.set_meta("interactable_label", "Ambil Kunci")
		key_area.set_meta("interact_callback", Callable(self, "_on_key_interacted"))

func _on_key_interacted() -> void:
	if _key_taken:
		return
	_key_taken = true
	GameManager.acquire_item("key")

	var key_area := get_node_or_null("CarKeyArea")
	if key_area:
		key_area.set_meta("interactable_label", "")
		key_area.remove_meta("interact_callback")

	print("[Yard] Kunci diambil dari mobil!")

func _on_door_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if not GameManager.has_item("key"):
		for hud in get_tree().get_nodes_in_group("game_hud"):
			if hud.has_method("show_prompt"):
				hud.show_prompt("Pintu terkunci")
		return
	print("[Yard] Player masuk rumah!")
	GameManager.enter_living_room_from_yard()
