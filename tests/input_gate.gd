extends SceneTree

## Input permission harness for VibeFPS.
## The headless display server cannot capture the mouse, so this check never
## touches Input.mouse_mode and never captures a cursor. It passes a mouse
## mode value into InputGate.is_play_input_allowed and asks what it answers,
## which is the whole point of keeping that function pure.
## Run: godot --headless --path . --script res://tests/input_gate.gd
##      .\tools\run_checks.ps1 input_gate

var _failures: PackedStringArray = []
var _checks := 0


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


func _initialize() -> void:
	print("=== input gate ===")
	_check(InputGate.is_play_input_allowed(Input.MOUSE_MODE_CAPTURED),
		"input allowed when mouse captured", "(mode=%d)" % Input.MOUSE_MODE_CAPTURED)
	# All four non-captured modes, not just VISIBLE. MOUSE_MODE_HIDDEN is the
	# nasty one: the cursor is invisible but not captured, so play input has to
	# be denied there too or the player runs around with no visible cursor.
	for mode in [Input.MOUSE_MODE_VISIBLE, Input.MOUSE_MODE_CONFINED,
			Input.MOUSE_MODE_CONFINED_HIDDEN, Input.MOUSE_MODE_HIDDEN]:
		_check(not InputGate.is_play_input_allowed(mode),
			"input denied when mouse mode is %d" % mode)

	print("=== RESULT: %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)
	quit(1 if _failures.size() > 0 else 0)