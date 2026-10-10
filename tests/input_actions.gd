extends SceneTree

## InputMap harness for VibeFPS.
## Verifies that the fire / pause / interact actions declared in
## project.godot exist and are bound to the keys Phase 1 depends on.
## Reads ProjectSettings via InputMap only and never instantiates a scene,
## so it answers "are the bindings right", not "does the scene use them".
## Run: godot --headless --path . --script res://tests/input_actions.gd
##      .\tools\run_checks.ps1 input_actions

var _failures: PackedStringArray = []
var _warnings: PackedStringArray = []
var _checks := 0


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


func _warn(label: String) -> void:
	_warnings.append(label)
	print("  [WARN] %s" % label)


func _initialize() -> void:
	print("=== input actions ===")
	for action in ["fire", "pause", "interact"]:
		_check(InputMap.has_action(action), "action %s exists" % action)
		_check(InputMap.action_get_events(action).size() > 0,
			"action %s has at least one event" % action)

	var fire := InputMap.action_get_events("fire")
	_check(fire.size() > 0
			and fire[0] is InputEventMouseButton
			and (fire[0] as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT,
		"fire is bound to left mouse button")

	# 4194305 is KEY_ESCAPE in Godot's physical (layout independent) key codes,
	# matching the encoding the other physical_keycode bindings in
	# project.godot already use.
	var pause := InputMap.action_get_events("pause")
	_check(pause.size() > 0
			and pause[0] is InputEventKey
			and (pause[0] as InputEventKey).physical_keycode == 4194305,
		"pause is bound to Escape")

	var interact := InputMap.action_get_events("interact")
	_check(interact.size() > 0
			and interact[0] is InputEventKey
			and (interact[0] as InputEventKey).physical_keycode == 69,
		"interact is bound to E")

	# 82 is KEY_R in Godot's physical (layout independent) key codes, matching
	# the encoding the other physical_keycode bindings in project.godot use.
	# Reload must be physical so it works on any OS keyboard layout.
	_check(InputMap.has_action("reload"), "action reload exists")
	var reload := InputMap.action_get_events("reload")
	_check(reload.size() > 0, "action reload has at least one event")
	_check(reload.size() > 0
			and reload[0] is InputEventKey
			and (reload[0] as InputEventKey).physical_keycode == 82,
		"reload is bound to physical R (82)")
	_check(reload.size() > 0
			and reload[0] is InputEventKey
			and (reload[0] as InputEventKey).keycode == 0,
		"reload uses the physical key code only, so it is layout independent")

	# 73 is KEY_I in Godot's physical (layout independent) key codes. The
	# inventory opens with a captured cursor, so physical is required: on a
	# non-QWERTY layout the letter's position must still summon the panel.
	_check(InputMap.has_action("inventory"), "action inventory exists")
	var inventory := InputMap.action_get_events("inventory")
	_check(inventory.size() > 0, "action inventory has at least one event")
	_check(inventory.size() > 0
			and inventory[0] is InputEventKey
			and (inventory[0] as InputEventKey).physical_keycode == 73,
		"inventory is bound to physical I (73)")
	_check(inventory.size() > 0
			and inventory[0] is InputEventKey
			and (inventory[0] as InputEventKey).keycode == 0,
		"inventory uses the physical key code only, so it is layout independent")

	print("=== RESULT: %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)
	quit(1 if _failures.size() > 0 else 0)