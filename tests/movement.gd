extends SceneTree

## Movement harness for VibeFPS: locomotion, jumping, mouse look and input
## gating. Drives the real player node with simulated input and reports
## anomalies.
##
## Capture: the headless display server cannot capture the cursor at all --
## Input.set_mouse_mode(MOUSE_MODE_CAPTURED) is a silent no-op there and
## Input.mouse_mode stays VISIBLE for the whole run. So this harness never asks
## the OS for a cursor and never skips a check because of it. Instead the Player
## node is handed a script that answers the gate with an explicit mode
## (gate_mouse_mode) and counts capture toggles (capture_toggles). Everything
## under test -- InputGate.is_play_input_allowed and all of player.gd -- is the
## real code; only the mouse mode value, which the headless display server
## cannot produce, comes from the harness. Every check states the mode it needs
## up front, so no check depends on the order the checks run in.
##
## Run: godot --headless --path . --script res://tests/movement.gd
##      .\tools\run_checks.ps1 movement


## Stand-in for player.gd, used only by this harness.
class _PlayerProbe extends "res://player.gd":
	## Mouse mode the gate is evaluated against instead of Input.mouse_mode.
	var gate_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
	## How many times player.gd asked to toggle the cursor capture.
	var capture_toggles: int = 0

	func _mouse_mode_for_play_input() -> int:
		return gate_mouse_mode

	func _toggle_mouse_capture() -> void:
		capture_toggles += 1
		super()


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


func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame


func _gate_mode(player: CharacterBody3D) -> int:
	return int(player.get("gate_mouse_mode"))


func _set_gate_mode(player: CharacterBody3D, mode: int) -> void:
	player.set("gate_mouse_mode", mode)


func _capture_toggles(player: CharacterBody3D) -> int:
	return int(player.get("capture_toggles"))


func _jump_queued(player: CharacterBody3D) -> bool:
	return bool(player.get("_jump_queued"))


func _xz_distance(player: CharacterBody3D, from: Vector3) -> float:
	return Vector2(
		player.global_position.x - from.x,
		player.global_position.z - from.z).length()


func _key_event(action: String) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE if action == "jump" else 0
	ev.keycode = KEY_SPACE
	ev.pressed = true
	return ev


func _action_event(action: String) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


func _mouse_button_event(index: MouseButton, pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = index
	ev.pressed = pressed
	return ev


## A fresh event for every dispatch on purpose: Godot accumulates parsed input,
## and accumulate() folds the new values into the queued event in place, so one
## mouse motion object reused across two sends is not reproducible.
func _mouse_motion_event(relative: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.relative = relative
	return ev


func _initialize() -> void:
	print("=== VibeFPS movement test ===")
	var packed: PackedScene = load("res://main.tscn")
	if packed == null:
		print("FATAL: cannot load res://main.tscn")
		quit(1)
		return

	var world: Node3D = packed.instantiate()
	var player: CharacterBody3D = world.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		print("FATAL: Player node not found in main.tscn")
		quit(1)
		return

	# Swapped before the node enters the tree, so @onready and _ready run on the
	# probe script. The node under test is still the scene's Player, with the
	# real exports, collision shape and children: only the mouse mode the gate
	# reads is answered by the harness.
	player.set_script(_PlayerProbe)
	root.add_child(world)
	await physics_frame

	print("    display=%s  Input.mouse_mode=%d (CAPTURED=%d)" % [
		DisplayServer.get_name(), Input.mouse_mode, Input.MOUSE_MODE_CAPTURED])

	await _test_gate_harness(player)
	await _test_idle(player)
	await _test_walk_forward(player)
	await _test_strafe(player)
	await _test_sprint(player)
	await _test_jump(player)
	await _test_jump_height(player)
	await _test_jump_action_event(player)
	await _test_mouse_look(player)
	await _test_mouse_uncaptured(player)
	await _test_play_input_denied_while_uncaptured(player)
	await _test_queued_jump_not_fired_after_release(player)
	await _test_capture_toggle_binding(player)
	await _test_player_source_contract()
	await _test_no_stuck_velocity(player)

	print("=== RESULT: %d checks, %d failed, %d warnings ===" % [
		_checks, _failures.size(), _warnings.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)
	quit(1 if _failures.size() > 0 else 0)


## The gate can only be trusted if the harness is really driving it: the probe
## has to be installed, it has to be what the gate reads, and the untouched
## player.gd implementation has to answer with the engine's own mouse mode.
func _test_gate_harness(player: CharacterBody3D) -> void:
	print("-- gate harness: the probe is live and player.gd gates on Input.mouse_mode")
	_check(player.get_script() == _PlayerProbe, "scene Player runs the harness probe script")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	_check(_gate_mode(player) == Input.MOUSE_MODE_CAPTURED, "harness can drive the gate mode")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"precondition: headless really cannot capture the cursor",
		"(mouse_mode=%d)" % Input.mouse_mode)

	var stock: Node = (load("res://player.tscn") as PackedScene).instantiate()
	_check(int(stock.call("_mouse_mode_for_play_input")) == Input.mouse_mode,
		"player.gd gates on the engine's own Input.mouse_mode")
	stock.free()

	_check(InputGate.is_play_input_allowed(Input.MOUSE_MODE_CAPTURED),
		"gate allows play input while the cursor is captured")
	_check(not InputGate.is_play_input_allowed(Input.MOUSE_MODE_VISIBLE),
		"gate denies play input while the cursor is free")


func _test_idle(player: CharacterBody3D) -> void:
	print("-- idle (captured): should settle on floor and stop moving")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	await _physics_frames(90)
	_check(player.is_on_floor(), "player is on floor after settling")
	_check(absf(player.velocity.y) < 0.01, "vertical velocity zero while idle",
		"(vy=%.3f)" % player.velocity.y)
	var pos := player.global_position
	_check(pos.y < 1.0, "player did not fall through floor",
		"(y=%.3f)" % pos.y)


func _test_walk_forward(player: CharacterBody3D) -> void:
	print("-- walk forward (W) for 1s")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	var start := player.global_position
	Input.action_press("move_forward")
	await _physics_frames(120)
	Input.action_release("move_forward")
	await _physics_frames(5)
	var dist := _xz_distance(player, start)
	# speed 5 m/s * 1s = 5m expected
	_check(dist > 4.0 and dist < 6.0, "walk distance ~5m", "(got %.2f m)" % dist)
	_check(player.is_on_floor(), "still on floor after walking")


func _test_strafe(player: CharacterBody3D) -> void:
	print("-- strafe right (D) for 0.5s, should move on X")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	var start := player.global_position
	Input.action_press("move_right")
	await _physics_frames(60)
	Input.action_release("move_right")
	await _physics_frames(5)
	var dx := player.global_position.x - start.x
	_check(dx > 1.5, "strafing moves along X", "(dx=%.2f)" % dx)


func _test_sprint(player: CharacterBody3D) -> void:
	print("-- sprint (Shift+W) should be faster than walk")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	var walk_start := player.global_position
	Input.action_press("move_forward")
	await _physics_frames(120)
	Input.action_release("move_forward")
	await _physics_frames(5)
	var walk_dist := _xz_distance(player, walk_start)

	# move back to start-ish so we have room
	player.global_position = Vector3(0, player.global_position.y, 0)
	player.velocity = Vector3.ZERO
	await _physics_frames(10)

	var sprint_start := player.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _physics_frames(120)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _physics_frames(5)
	var sprint_dist := _xz_distance(player, sprint_start)

	print("    walk=%.2f m, sprint=%.2f m" % [walk_dist, sprint_dist])
	_check(sprint_dist > walk_dist * 1.3, "sprint meaningfully faster than walk")


func _test_jump(player: CharacterBody3D) -> void:
	print("-- jump (Space key event): leaves floor and lands again")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	_check(player.is_on_floor(), "on floor before jump")
	Input.parse_input_event(_key_event("jump"))
	await _physics_frames(10)
	var airborne := not player.is_on_floor()
	_check(airborne, "player left the floor after jump")
	_check(player.velocity.y > 0.0, "upward velocity applied",
		"(vy=%.2f)" % player.velocity.y)
	await _physics_frames(240)
	_check(player.is_on_floor(), "player landed back on floor")


func _test_jump_height(player: CharacterBody3D) -> void:
	print("-- jump apex height measurement")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	player.global_position = Vector3(0, 1.0, 0)
	player.velocity = Vector3.ZERO
	await _physics_frames(60)
	var ground_y := player.global_position.y
	var apex := ground_y
	Input.parse_input_event(_key_event("jump"))
	for i in 400:
		await physics_frame
		apex = maxf(apex, player.global_position.y)
		if i > 5 and player.is_on_floor():
			break
	print("    apex=%.3f m above ground" % (apex - ground_y))
	_check(apex - ground_y > 0.2, "jump produced measurable height")
	_check(player.is_on_floor(), "returned to floor after apex test")


func _test_jump_action_event(player: CharacterBody3D) -> void:
	print("-- jump (non-key InputEventAction): gamepad/virtual input must also jump")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	player.global_position = Vector3(0, 0.0, 0)
	player.velocity = Vector3.ZERO
	await _physics_frames(30)
	_check(player.is_on_floor(), "on floor before action jump")
	Input.parse_input_event(_action_event("jump"))
	await _physics_frames(10)
	_check(not player.is_on_floor(), "player left the floor after action jump")
	_check(player.velocity.y > 0.0, "action jump applied upward velocity",
		"(vy=%.2f)" % player.velocity.y)
	await _physics_frames(240)
	_check(player.is_on_floor(), "landed back on floor after action jump")


func _test_mouse_look(player: CharacterBody3D) -> void:
	print("-- mouse look (captured): yaw and pitch respond and clamp")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		_failures.append("no Camera3D for mouse look test")
		_checks += 1
		print("  [FAIL] no Camera3D for mouse look test")
		return
	var yaw0 := player.rotation.y
	var pitch0 := cam.rotation.x

	Input.parse_input_event(_mouse_motion_event(Vector2(100, 0)))
	await physics_frame
	_check(absf(player.rotation.y - yaw0) > 0.0001, "yaw changed on horizontal mouse motion",
		"(dyaw=%.4f)" % (player.rotation.y - yaw0))

	# large downward motion should clamp pitch at -89 deg
	Input.parse_input_event(_mouse_motion_event(Vector2(0, 100000)))
	await physics_frame
	var min_pitch := deg_to_rad(-89.0)
	var max_pitch := deg_to_rad(89.0)
	_check(cam.rotation.x >= min_pitch - 0.001 and cam.rotation.x <= max_pitch + 0.001,
		"pitch clamped within +-89 deg", "(pitch=%.2f deg)" % rad_to_deg(cam.rotation.x))

	# large upward motion should clamp at +89
	Input.parse_input_event(_mouse_motion_event(Vector2(0, -100000)))
	await physics_frame
	_check(cam.rotation.x >= min_pitch - 0.001 and cam.rotation.x <= max_pitch + 0.001,
		"pitch clamped on upward motion too", "(pitch=%.2f deg)" % rad_to_deg(cam.rotation.x))
	cam.rotation.x = pitch0


func _test_mouse_uncaptured(player: CharacterBody3D) -> void:
	print("-- mouse uncaptured: mouse motion must NOT rotate the camera")
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		_failures.append("no Camera3D for mouse capture test")
		_checks += 1
		print("  [FAIL] no Camera3D for mouse capture test")
		return
	var yaw0 := player.rotation.y
	var pitch0 := cam.rotation.x

	_set_gate_mode(player, Input.MOUSE_MODE_VISIBLE)
	# Both axes at once: a horizontal-only motion cannot change the pitch even
	# with the gate open, so the pitch assertion below would be vacuous.
	Input.parse_input_event(_mouse_motion_event(Vector2(200, 50)))
	await physics_frame
	_check(absf(player.rotation.y - yaw0) < 0.0001, "yaw unchanged while mouse uncaptured",
		"(dyaw=%.4f)" % (player.rotation.y - yaw0))
	_check(absf(cam.rotation.x - pitch0) < 0.0001, "pitch unchanged while mouse uncaptured",
		"(dpitch=%.4f)" % (cam.rotation.x - pitch0))

	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	var yaw1 := player.rotation.y
	Input.parse_input_event(_mouse_motion_event(Vector2(200, 50)))
	await physics_frame
	_check(absf(player.rotation.y - yaw1) > 0.0001, "yaw rotates again once mouse is recaptured",
		"(dyaw=%.4f)" % (player.rotation.y - yaw1))
	_check(absf(cam.rotation.x - pitch0) > 0.0001, "pitch rotates again once mouse is recaptured",
		"(dpitch=%.4f)" % (cam.rotation.x - pitch0))
	cam.rotation.x = pitch0


## Movement, sprint and jump must all be denied while the cursor is free.
## The captured half runs first and has to move the player: without that the
## denied half would pass even if the harness could not drive the input at all.
func _test_play_input_denied_while_uncaptured(player: CharacterBody3D) -> void:
	print("-- input gating: a free cursor denies move, sprint and jump")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	player.global_position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await _physics_frames(60)
	_check(player.is_on_floor(), "on floor before the gating check")

	var start := player.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _physics_frames(60)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var allowed := _xz_distance(player, start)
	print("    captured: moved %.2f m" % allowed)
	_check(allowed > 3.0, "captured cursor moves the player with the same input",
		"(moved %.2f m)" % allowed)

	player.global_position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await _physics_frames(60)
	_check(player.is_on_floor(), "back on floor before the denied half")
	start = player.global_position

	# The jump part has to be a real event, not Input.action_press: the player
	# reads jump in _unhandled_input, and action_press alone never reaches it.
	_set_gate_mode(player, Input.MOUSE_MODE_VISIBLE)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	Input.parse_input_event(_key_event("jump"))
	await _physics_frames(60)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var denied := _xz_distance(player, start)
	print("    uncaptured: moved %.4f m" % denied)
	_check(denied <= 0.01, "free cursor does not move the player",
		"(moved %.4f m)" % denied)
	_check(absf(player.velocity.x) < 0.01 and absf(player.velocity.z) < 0.01,
		"horizontal velocity zeroed while input is denied, no coasting",
		"(v=%.4f, %.4f)" % [player.velocity.x, player.velocity.z])
	_check(player.is_on_floor(), "free cursor does not jump the player")
	_check(absf(player.velocity.y) < 0.01, "vertical velocity zeroed while input is denied",
		"(vy=%.4f)" % player.velocity.y)
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)


## The jump queue has two halves and both must be gated: a jump queued while the
## cursor was captured must not fire once the cursor is released.
func _test_queued_jump_not_fired_after_release(player: CharacterBody3D) -> void:
	print("-- queued jump: allowed before release, must not fire after it")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	player.global_position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await _physics_frames(60)
	_check(player.is_on_floor(), "on floor before the queued jump")

	Input.parse_input_event(_key_event("jump"))
	# Godot accumulates parsed events and flushes them at the start of the next
	# main loop iteration, i.e. before the next physics step. Flushing here puts
	# the jump in the queue synchronously, so the cursor can be released before
	# any _physics_process has had the chance to consume it.
	Input.flush_buffered_events()
	# Assert the jump really reached the queue while the cursor was still
	# captured: otherwise every check below would pass for the wrong reason,
	# with a jump that was never queued in the first place.
	_check(_jump_queued(player), "jump was queued while the cursor was captured")

	_set_gate_mode(player, Input.MOUSE_MODE_VISIBLE)
	await _physics_frames(60)
	_check(not _jump_queued(player), "the queued jump is consumed, not left hanging")
	_check(player.is_on_floor(), "the queued jump does not fire after the cursor is released")
	_check(player.velocity.y <= 0.01, "no upward velocity after the cursor is released",
		"(vy=%.3f)" % player.velocity.y)
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)


## Capture is toggled by the pause action and by nothing else. LMB is bound to
## fire and must reach that action instead of grabbing the cursor.
func _test_capture_toggle_binding(player: CharacterBody3D) -> void:
	print("-- capture toggle: pause toggles it, left mouse button must not")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	var before := _capture_toggles(player)
	Input.parse_input_event(_action_event("pause"))
	await physics_frame
	_check(_capture_toggles(player) == before + 1,
		"pause action toggles mouse capture",
		"(toggles=%d)" % (_capture_toggles(player) - before))

	var lmb_before := _capture_toggles(player)
	Input.parse_input_event(_mouse_button_event(MOUSE_BUTTON_LEFT, true))
	await physics_frame
	_check(Input.is_action_pressed("fire"),
		"left mouse button reaches the fire action")
	_check(_capture_toggles(player) == lmb_before,
		"left mouse button does NOT toggle mouse capture",
		"(toggles=%d)" % (_capture_toggles(player) - lmb_before))
	Input.parse_input_event(_mouse_button_event(MOUSE_BUTTON_LEFT, false))
	await physics_frame
	_check(not Input.is_action_pressed("fire"),
		"releasing left mouse button clears the fire action")


## The wiring above is unobservable under headless for the parts that depend on
## a real cursor, so the two removals the design demands are locked on the
## source: game code must not use the built-in ui_cancel action, and must not
## have any InputEventMouseButton branch left to toggle capture.
func _test_player_source_contract() -> void:
	print("-- source contract: old capture wiring must stay out of player.gd")
	var src := FileAccess.get_file_as_string("res://player.gd")
	_check(src != "", "player.gd is readable", "(%d bytes)" % src.length())
	_check(not src.contains("ui_cancel"),
		"player.gd does not use the built-in ui_cancel action")
	_check(not src.contains("InputEventMouseButton"),
		"player.gd has no InputEventMouseButton branch")
	_check(src.count("InputGate.is_play_input_allowed(") >= 2,
		"player.gd asks InputGate for permission in both input paths",
		"(call sites=%d)" % src.count("InputGate.is_play_input_allowed("))
	_check(src.count("_mouse_mode_for_play_input() -> int") == 1,
		"player.gd reads Input.mouse_mode for the gate in exactly one method")


func _test_no_stuck_velocity(player: CharacterBody3D) -> void:
	print("-- release check: no residual horizontal velocity after input release")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	await _physics_frames(30)
	_check(absf(player.velocity.x) < 0.01 and absf(player.velocity.z) < 0.01,
		"horizontal velocity zeroed after release",
		"(v=%.3f, %.3f)" % [player.velocity.x, player.velocity.z])