
extends CanvasLayer

@onready var sanity_bar: ProgressBar = $HUDContainer/SanitySection/SanityBar
@onready var sanity_label: Label = $HUDContainer/SanitySection/SanityLabel
@onready var battery_container: Control = $HUDContainer/BatteryContainer
@onready var battery_bar: ProgressBar = $HUDContainer/BatteryContainer/BatteryBar
@onready var key_icon: Control = $HUDContainer/ItemsPanel/ItemsContainer/KeyIcon
@onready var flashlight_icon: Control = $HUDContainer/ItemsPanel/ItemsContainer/FlashlightIcon
@onready var prompt_label: Label = $HUDContainer/PromptLabel
@onready var sanity_overlay: ColorRect = $SanityOverlay
@onready var level_label: Label = $HUDContainer/LevelLabel

var _current_sanity: float = 100.0

func _ready() -> void:
	GameManager.sanity_changed.connect(_on_sanity_changed)
	GameManager.flashlight_battery_changed.connect(_on_battery_changed)
	GameManager.item_acquired.connect(_on_item_acquired)
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.game_state_changed.connect(_on_game_state_changed)
	GameManager.show_notification.connect(_on_notification)

	if is_instance_valid(sanity_overlay):
		sanity_overlay.add_to_group("sanity_overlay")

	add_to_group("game_hud")

	_create_notification_label()

	var sanity_section := get_node_or_null("HUDContainer/SanitySection")
	if sanity_section:
		sanity_section.visible = false
	if is_instance_valid(sanity_overlay):
		sanity_overlay.visible = false

	_update_all_item_icons()
	_update_battery_display(100.0)
	battery_container.visible = false

	if is_instance_valid(prompt_label):
		prompt_label.visible = false

	if is_instance_valid(level_label):
		level_label.visible = OS.is_debug_build()

	print("[HUD] Ready.")

func _on_sanity_changed(value: float) -> void:
	_current_sanity = value
	_update_sanity_display(value)

func _on_battery_changed(percentage: float) -> void:
	_update_battery_display(percentage)

func _on_item_acquired(item_name: String) -> void:
	_update_all_item_icons()

	if item_name == "flashlight":
		if is_instance_valid(battery_container):
			battery_container.visible = true

	_flash_new_item(item_name)

func _on_level_changed(level_num: int) -> void:
	if is_instance_valid(level_label):
		level_label.text = "Level: %d / %d" % [level_num, GameManager.MAX_LEVELS]

	if is_instance_valid(battery_container):
		battery_container.visible = GameManager.has_item("flashlight")

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.TITLE, GameManager.GameState.ENDING, GameManager.GameState.MEADOW:
			visible = false
		GameManager.GameState.YARD, GameManager.GameState.LIVING_ROOM, GameManager.GameState.CORRIDOR, GameManager.GameState.FINAL:
			visible = true
		GameManager.GameState.PAUSED:
			pass

func _update_sanity_display(value: float) -> void:
	if is_instance_valid(sanity_bar):
		sanity_bar.value = value

		var bar_style := sanity_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if bar_style:
			if value > 60.0:
				bar_style.bg_color = Color(0.2, 0.8, 0.4)
			elif value > 30.0:
				bar_style.bg_color = Color(0.9, 0.7, 0.1)
			else:
				bar_style.bg_color = Color(0.9, 0.2, 0.1)

	if is_instance_valid(sanity_label):
		sanity_label.text = "SANITY: %d%%" % int(value)

		if value < 20.0 and not _is_label_shaking():
			_start_label_shake()

func _update_battery_display(percentage: float) -> void:
	if is_instance_valid(battery_bar):
		battery_bar.value = percentage

		var bar_style := battery_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if bar_style:
			if percentage > 50.0:
				bar_style.bg_color = Color(0.3, 0.9, 0.5)
			elif percentage > 20.0:
				bar_style.bg_color = Color(0.9, 0.6, 0.1)
			else:
				bar_style.bg_color = Color(0.9, 0.1, 0.1)

		if percentage <= 10.0 and percentage > 0.0:
			_flash_battery_warning()

func _update_all_item_icons() -> void:
	if is_instance_valid(key_icon):
		key_icon.visible = GameManager.has_item("key")
	if is_instance_valid(flashlight_icon):
		flashlight_icon.visible = GameManager.has_item("flashlight")

func show_prompt(text: String) -> void:
	if not is_instance_valid(prompt_label):
		return
	prompt_label.text = text
	prompt_label.visible = true
	prompt_label.modulate.a = 1.0

func hide_prompt() -> void:
	if not is_instance_valid(prompt_label):
		return
	var tween := create_tween()
	tween.tween_property(prompt_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): prompt_label.visible = false)

func _flash_new_item(item_name: String) -> void:
	var icon: Control = null
	match item_name:
		"key":        icon = key_icon
		"flashlight": icon = flashlight_icon

	if not is_instance_valid(icon):
		return

	var tween := create_tween()
	tween.tween_property(icon, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.1)
	tween.tween_property(icon, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4)

func _flash_battery_warning() -> void:
	if not is_instance_valid(battery_bar):
		return
	var tween := create_tween()
	tween.set_loops(3)
	tween.tween_property(battery_bar, "modulate:a", 0.3, 0.2)
	tween.tween_property(battery_bar, "modulate:a", 1.0, 0.2)

var _label_shake_active: bool = false

func _is_label_shaking() -> bool:
	return _label_shake_active

func _start_label_shake() -> void:
	_label_shake_active = true
	var original_pos := sanity_label.position

	var tween := create_tween()
	tween.set_loops(5)
	tween.tween_property(sanity_label, "position", original_pos + Vector2(2, 0), 0.05)
	tween.tween_property(sanity_label, "position", original_pos - Vector2(2, 0), 0.05)
	tween.finished.connect(func():
		sanity_label.position = original_pos
		_label_shake_active = false
	)

var _notif_label: Label = null

func _create_notification_label() -> void:
	_notif_label = Label.new()
	_notif_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notif_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_notif_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_notif_label.position = Vector2(-300, -60)
	_notif_label.size     = Vector2(600, 120)
	_notif_label.add_theme_font_size_override("font_size", 22)
	_notif_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_notif_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_notif_label.add_theme_constant_override("shadow_offset_x", 2)
	_notif_label.add_theme_constant_override("shadow_offset_y", 2)
	_notif_label.modulate.a = 0.0
	_notif_label.name = "NotifLabel"
	add_child(_notif_label)

func _on_notification(message: String, is_bad: bool) -> void:
	if not is_instance_valid(_notif_label):
		return
	_notif_label.text = message
	_notif_label.add_theme_color_override("font_color",
		Color(1.0, 0.3, 0.3) if is_bad else Color(0.8, 1.0, 0.6))
	var tween := create_tween()
	tween.tween_property(_notif_label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.0)
	tween.tween_property(_notif_label, "modulate:a", 0.0, 0.5)
