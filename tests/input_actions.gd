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

	print("=== RESULT: %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)
	quit(1 if _failures.size() > 0 else 0)