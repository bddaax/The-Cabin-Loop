
extends Node

enum GameState {
	TITLE,
	INTRO,
	YARD,
	LIVING_ROOM,
	CORRIDOR,
	FINAL,
	MEADOW,
	ENDING,
	PAUSED,
}

enum EndingType {
	GOOD,
	BAD,
	SECRET,
}

signal game_state_changed(new_state: GameState)

signal level_changed(level_num: int)

signal sanity_changed(value: float)

signal item_acquired(item_name: String)

signal flashlight_battery_changed(percentage: float)

signal hollow_spotted_player(is_spotted: bool)

signal ending_triggered(type: EndingType)

signal corridor_reset_triggered()

signal show_notification(message: String, is_bad: bool)

signal transition_to_yard()

signal transition_to_living_room()

signal transition_to_corridor(level_num: int)

signal transition_to_meadow()

const MAX_LEVELS: int = 11

const SANITY_MAX: float = 100.0

const SANITY_GOOD_ENDING_MIN: float = 20.0

const FLASHLIGHT_BATTERY_MAX: float = 100.0

const FLASHLIGHT_DRAIN_NORMAL: float = 3.0

const FLASHLIGHT_DRAIN_DARK: float = 6.0

const LEVEL_ANOMALY_MAP: Dictionary = {
	0: false,
	1: false,
	2: true,
	3: false,
	4: true,
	5: true,
	6: false,
	7: false,
	8: true,
	9: false,
	10: true,
	11: true,
}

const NO_ANOMALY_CHANCE: float = 0.30

const SANITY_DRAIN_RATES: Array[float] = [
	0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
]

const SANITY_WRONG_DECISION_PENALTY: float = 10.0

const SANITY_HOLLOW_DRAIN_L1_4: float = 20.0
const SANITY_HOLLOW_DRAIN_L5_6: float = 25.0
const SANITY_HOLLOW_DRAIN_L7_8: float = 35.0

const SANITY_IDLE_DRAIN: float = 1.0
const SANITY_IDLE_INTERVAL: float = 5.0
const SANITY_IDLE_START_LEVEL: int = 5

const DARK_LEVEL_THRESHOLD: int = 7

const RAYA_PHOTO_UNLOCK_LEVEL: int = 4

var current_state: GameState = GameState.TITLE

var current_level: int = 0

var sanity: float = SANITY_MAX

var inventory: Dictionary = {
	"key": false,
	"flashlight": false,
}

var current_level_has_anomaly: bool = false

var flashlight_active: bool = false

var flashlight_battery: float = FLASHLIGHT_BATTERY_MAX

var hollow_is_watching: bool = false

var ever_made_mistake: bool = false

var correct_streak: int = 0

var wrong_count: int = 0

const MAX_WRONG_BEFORE_RESET: int = 3

var _reset_pending: bool = false

var _player_ref: Node = null

var _idle_drain_timer: float = 0.0

var _player_is_moving: bool = true

var is_final_phase: bool = false

var player_is_blinking: bool = false

var _sanity_drain_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[GameManager] Initialized. Whispering Rooms ready.")

func _process(delta: float) -> void:
	if current_state == GameState.CORRIDOR or current_state == GameState.FINAL:
		_process_sanity_drain(delta)
		_process_flashlight_drain(delta)

		if current_level >= SANITY_IDLE_START_LEVEL and not _player_is_moving:
			_idle_drain_timer += delta
			if _idle_drain_timer >= SANITY_IDLE_INTERVAL:
				_idle_drain_timer = 0.0
				_apply_sanity_delta(-SANITY_IDLE_DRAIN)
		else:
			_idle_drain_timer = 0.0

	if _reset_pending:
		_reset_pending = false
		_execute_reset_to_level_one()

func start_new_game() -> void:
	print("[GameManager] Starting new game...")
	_reset_all_state()
	_change_state(GameState.YARD)
	current_level = 0
	emit_signal("level_changed", current_level)
	emit_signal("transition_to_yard")

func enter_living_room_from_yard() -> void:
	print("[GameManager] Player masuk rumah. Level 0 (intro).")
	_go_to_level(0)

func _go_to_level(level_num: int) -> void:
	current_level = level_num

	if current_level > MAX_LEVELS:
		_trigger_final_phase()
		return

	current_level_has_anomaly = _determine_anomaly()
	_change_state(GameState.CORRIDOR)
	emit_signal("level_changed", current_level)
	emit_signal("transition_to_corridor", current_level)
	_update_flashlight_battery_cap()
	print("[GameManager] Entering Corridor Level %d | Anomaly: %s" % [current_level, str(current_level_has_anomaly)])

func enter_corridor() -> void:
	_go_to_level(current_level + 1)

func player_chose_back() -> void:
	if current_state != GameState.CORRIDOR:
		return

	print("[GameManager] Player chose BACK (claiming anomaly exists).")

	if current_level_has_anomaly:
		_on_level_correct()
	else:
		_on_level_wrong(false)

func player_chose_exit() -> void:
	if current_state != GameState.CORRIDOR:
		return

	print("[GameManager] Player chose EXIT (claiming no anomaly).")

	if not current_level_has_anomaly:
		_on_level_correct()
	else:
		_on_level_wrong(true)

func return_to_living_room() -> void:
	_go_to_level(current_level + 1)

func set_hollow_watching(is_watching: bool) -> void:
	if hollow_is_watching == is_watching:
		return
	hollow_is_watching = is_watching
	emit_signal("hollow_spotted_player", is_watching)
	if is_watching:
		var drain := _get_hollow_spot_drain()
		_apply_sanity_delta(-drain)
		print("[GameManager] Hollow spotted player! Sanity drain: -%.0f" % drain)
	else:
		print("[GameManager] Hollow lost sight of player.")

func _get_hollow_spot_drain() -> float:
	if current_level <= 4:
		return SANITY_HOLLOW_DRAIN_L1_4
	elif current_level <= 6:
		return SANITY_HOLLOW_DRAIN_L5_6
	else:
		return SANITY_HOLLOW_DRAIN_L7_8

func notify_player_moving(is_moving: bool) -> void:
	_player_is_moving = is_moving

func set_player_blinking(is_blinking: bool) -> void:
	player_is_blinking = is_blinking

func toggle_flashlight() -> void:
	if not inventory["flashlight"]:
		return
	if flashlight_battery <= 0.0:
		flashlight_active = false
		return

	flashlight_active = not flashlight_active
	print("[GameManager] Flashlight: %s (Battery: %.1f%%)" % [
		"ON" if flashlight_active else "OFF",
		get_flashlight_battery_percent()
	])

func acquire_item(item_name: String) -> void:
	if not inventory.has(item_name):
		push_error("[GameManager] Item tidak dikenal: " + item_name)
		return

	if inventory[item_name]:
		print("[GameManager] Item '%s' sudah dimiliki." % item_name)
		return

	inventory[item_name] = true
	print("[GameManager] Item acquired: " + item_name)

	match item_name:
		"flashlight":
			flashlight_battery = FLASHLIGHT_BATTERY_MAX
		"key":
			pass

	emit_signal("item_acquired", item_name)

func has_item(item_name: String) -> bool:
	return inventory.get(item_name, false)

func is_dark_level() -> bool:
	return current_level >= DARK_LEVEL_THRESHOLD

func get_flashlight_battery_percent() -> float:
	return clampf(flashlight_battery, 0.0, 100.0)

func get_current_drain_rate() -> float:
	var idx := clampi(current_level, 0, SANITY_DRAIN_RATES.size() - 1)
	var base_rate := SANITY_DRAIN_RATES[idx]
	return base_rate

func register_player(player_node: Node) -> void:
	_player_ref = player_node

func get_player() -> Node:
	return _player_ref

func _on_level_correct() -> void:
	correct_streak += 1
	wrong_count     = 0
	print("[GameManager] Level %d: CORRECT! Streak: %d" % [current_level, correct_streak])

	if current_level >= MAX_LEVELS:
		emit_signal("show_notification", "Kamu bebas...", false)
		await get_tree().create_timer(1.5).timeout
		_change_state(GameState.MEADOW)
		emit_signal("transition_to_meadow")
		return

	emit_signal("show_notification", "✓ Level %d selesai!" % current_level, false)
	await get_tree().create_timer(1.2).timeout
	_go_to_level(current_level + 1)

func _on_level_wrong(_force_reset: bool) -> void:
	ever_made_mistake = true
	correct_streak    = 0
	wrong_count       = 0
	print("[GameManager] Level %d: WRONG! Restart from Level 1." % current_level)
	emit_signal("show_notification", "✗ Salah! Mulai dari Level 1...", true)
	await get_tree().create_timer(1.8).timeout
	_go_to_level(1)

func _determine_anomaly() -> bool:
	if LEVEL_ANOMALY_MAP.has(current_level):
		var has_anomaly: bool = LEVEL_ANOMALY_MAP[current_level]
		print("[GameManager] Level %d: FIXED → %s" % [
			current_level, "MUNDUR (anomali)" if has_anomaly else "MAJU (aman)"
		])
		return has_anomaly
	return randf() >= NO_ANOMALY_CHANCE

func _execute_reset_to_level_one() -> void:
	print("[GameManager] !! RESET TO LEVEL 1 !!")
	_go_to_level(1)

func _trigger_final_phase() -> void:
	print("[GameManager] Entering FINAL phase...")
	is_final_phase = true
	_change_state(GameState.FINAL)
	emit_signal("transition_to_intro")

func evaluate_ending() -> void:
	if ever_made_mistake:
		_trigger_bad_ending()
		return

	if not ever_made_mistake:
		_trigger_ending(EndingType.SECRET)
		return

	_trigger_ending(EndingType.GOOD)

func _trigger_bad_ending() -> void:
	_trigger_ending(EndingType.BAD)

func _trigger_ending(type: EndingType) -> void:
	var ending_names := {
		EndingType.GOOD: "GOOD ENDING",
		EndingType.BAD: "BAD ENDING",
		EndingType.SECRET: "SECRET ENDING",
	}
	print("[GameManager] ★ %s triggered! No mistakes: %s" % [
		ending_names[type],
		str(not ever_made_mistake),
	])
	_change_state(GameState.ENDING)
	emit_signal("ending_triggered", type)

func _process_sanity_drain(delta: float) -> void:
	if not hollow_is_watching: return
	_sanity_drain_timer += delta
	if _sanity_drain_timer >= 1.0:
		_sanity_drain_timer -= 1.0
		_apply_sanity_delta(-get_current_drain_rate())

func _process_flashlight_drain(delta: float) -> void:
	if not flashlight_active: return
	var drain = FLASHLIGHT_DRAIN_DARK if is_dark_level() else FLASHLIGHT_DRAIN_NORMAL
	flashlight_battery -= drain * delta
	flashlight_battery = max(0.0, flashlight_battery)
	emit_signal("flashlight_battery_changed", get_flashlight_battery_percent())
	if flashlight_battery <= 0:
		flashlight_active = false

func _apply_sanity_delta(delta: float) -> void:
	sanity += delta
	sanity = clamp(sanity, 0.0, SANITY_MAX)
	emit_signal("sanity_changed", sanity)

func _update_flashlight_battery_cap() -> void:
	pass

func _change_state(new_state: GameState) -> void:
	if current_state == new_state:
		return
	print("[GameManager] State: %s → %s" % [GameState.keys()[current_state], GameState.keys()[new_state]])
	current_state = new_state
	emit_signal("game_state_changed", new_state)

func _reset_all_state() -> void:
	current_level = 0
	current_level_has_anomaly = false
	ever_made_mistake = false
	correct_streak    = 0
	wrong_count       = 0
	_reset_pending = false
	_player_ref = null
	is_final_phase = false
	print("[GameManager] All state reset.")

func debug_set_level(level: int) -> void:
	if not OS.is_debug_build():
		return
	current_level = clampi(level, 0, MAX_LEVELS)
	current_level_has_anomaly = _determine_anomaly()
	emit_signal("level_changed", current_level)
	print("[DEBUG] Level set to: %d | Has anomaly: %s" % [current_level, str(current_level_has_anomaly)])

func debug_print_state() -> void:
	if not OS.is_debug_build():
		return
	print("=== GAME STATE DEBUG ===")
	print("  State:         ", GameState.keys()[current_state])
	print("  Level:         ", current_level)
	print("  Has Anomaly:   ", current_level_has_anomaly)
	print("  Ever Mistaken: ", ever_made_mistake)
	print("  Correct Streak:", correct_streak)
	print("  Dark Level:    ", is_dark_level())
	print("========================")
