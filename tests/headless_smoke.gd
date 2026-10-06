extends SceneTree

## Headless smoke-test harness for VibeFPS.
## Drives the player with simulated input and reports anomalies.
## Run: godot --headless --path . --script res://tests/headless_smoke.gd

const FLOOR_EXTENT := 10.0

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


func _ensure_mouse_capture() -> bool:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	await physics_frame
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame


func _initialize() -> void:
	print("=== VibeFPS headless smoke test ===")
	var packed: PackedScene = load("res://main.tscn")
	if packed == null:
		print("FATAL: cannot load res://main.tscn")
		quit(1)
		return

	var world: Node3D = packed.instantiate()
	root.add_child(world)
	await physics_frame

	var player: CharacterBody3D = world.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		print("FATAL: Player node not found in main.tscn")
		quit(1)
		return

	_test_scene_setup(world, player)
	await _test_sky_background(world)
	await _test_idle(player)
	await _test_walk_forward(player)
	await _test_strafe(player)
	await _test_sprint(player)
	await _test_jump(player)
	await _test_jump_height(player)
	await _test_jump_action_event(player)
	await _test_fall_off_edge(player)
	await _test_fall_recovery(player)
	await _test_mouse_look(player)
	await _test_mouse_uncaptured(player)
	await _test_no_stuck_velocity(player)

	print("=== RESULT: %d checks, %d failed, %d warnings ===" % [
		_checks, _failures.size(), _warnings.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)
	quit(1 if _failures.size() > 0 else 0)


func _test_scene_setup(world: Node3D, player: CharacterBody3D) -> void:
	print("-- scene setup")
	_check(world.get_node_or_null("Floor") != null, "Floor node exists")
	_check(world.get_node_or_null("WorldEnvironment") != null, "WorldEnvironment exists")
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	_check(cam != null and cam.current, "Camera3D exists and is current")
	if cam != null and cam.current and cam.global_position.y < 1.5:
		_warn("camera sits below expected eye height (%.2f)" % cam.global_position.y)


func _test_sky_background(world: Node3D) -> void:
	print("-- sky: environment must render the sky, not a black clear color")
	var we := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null or we.environment == null:
		_failures.append("WorldEnvironment has no Environment resource")
		print("  [FAIL] WorldEnvironment has no Environment resource")
		_checks += 1
		return
	var env := we.environment
	_check(env.background_mode == Environment.BG_SKY, "background_mode is BG_SKY (2)",
		"(got %d)" % env.background_mode)
	_check(env.sky != null, "environment has a Sky resource")
	if env.sky != null:
		_check(env.sky.sky_material != null, "sky has a sky_material")


func _test_idle(player: CharacterBody3D) -> void:
	print("-- idle: should settle on floor and stop moving")
	await _physics_frames(90)
	_check(player.is_on_floor(), "player is on floor after settling")
	_check(absf(player.velocity.y) < 0.01, "vertical velocity zero while idle",
		"(vy=%.3f)" % player.velocity.y)
	var pos := player.global_position
	_check(pos.y < 1.0, "player did not fall through floor",
		"(y=%.3f)" % pos.y)


func _test_walk_forward(player: CharacterBody3D) -> void:
	print("-- walk forward (W) for 1s")
	var start := player.global_position
	Input.action_press("move_forward")
	await _physics_frames(120)
	Input.action_release("move_forward")
	await _physics_frames(5)
	var dist := Vector2(
		player.global_position.x - start.x,
		player.global_position.z - start.z).length()
	# speed 5 m/s * 1s = 5m expected
	_check(dist > 4.0 and dist < 6.0, "walk distance ~5m", "(got %.2f m)" % dist)
	_check(player.is_on_floor(), "still on floor after walking")


func _test_strafe(player: CharacterBody3D) -> void:
	print("-- strafe right (D) for 0.5s, should move on X")
	var start := player.global_position
	Input.action_press("move_right")
	await _physics_frames(60)
	Input.action_release("move_right")
	await _physics_frames(5)
	var dx := player.global_position.x - start.x
	_check(dx > 1.5, "strafing moves along X", "(dx=%.2f)" % dx)


func _test_sprint(player: CharacterBody3D) -> void:
	print("-- sprint (Shift+W) should be faster than walk")
	var walk_start := player.global_position
	Input.action_press("move_forward")
	await _physics_frames(120)
	Input.action_release("move_forward")
	await _physics_frames(5)
	var walk_dist := Vector2(
		player.global_position.x - walk_start.x,
		player.global_position.z - walk_start.z).length()

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
	var sprint_dist := Vector2(
		player.global_position.x - sprint_start.x,
		player.global_position.z - sprint_start.z).length()

	print("    walk=%.2f m, sprint=%.2f m" % [walk_dist, sprint_dist])
	_check(sprint_dist > walk_dist * 1.3, "sprint meaningfully faster than walk")


func _key_event(action: String) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE if action == "jump" else 0
	ev.keycode = KEY_SPACE
	ev.pressed = true
	return ev


func _test_jump(player: CharacterBody3D) -> void:
	print("-- jump (Space key event): leaves floor and lands again")
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
	player.global_position = Vector3(0, 0.0, 0)
	player.velocity = Vector3.ZERO
	await _physics_frames(30)
	_check(player.is_on_floor(), "on floor before action jump")
	var ev := InputEventAction.new()
	ev.action = "jump"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _physics_frames(10)
	_check(not player.is_on_floor(), "player left the floor after action jump")
	_check(player.velocity.y > 0.0, "action jump applied upward velocity",
		"(vy=%.2f)" % player.velocity.y)
	await _physics_frames(240)
	_check(player.is_on_floor(), "landed back on floor after action jump")


func _test_fall_off_edge(player: CharacterBody3D) -> void:
	print("-- fall off edge: must NOT sink through world")
	player.global_position = Vector3(1000, 50, 1000)
	player.velocity = Vector3.ZERO
	await _physics_frames(240)
	var y := player.global_position.y
	print("    y after 2s of falling = %.2f" % y)
	_check(y > -50.0, "player did not fall out of the world",
		"(y=%.2f)" % y)


func _test_fall_recovery(player: CharacterBody3D) -> void:
	print("-- fall recovery: falling past the kill plane respawns at spawn")
	var spawn := Vector3.ZERO
	player.global_position = Vector3(0, 5, 40)
	player.velocity = Vector3.ZERO
	var respawned := false
	for i in 600:
		await physics_frame
		if player.global_position.distance_to(spawn) < 2.0:
			respawned = true
			break
	print("    y after fall = %.2f, respawned=%s" % [player.global_position.y, respawned])
	_check(respawned, "player respawned near the spawn point after falling out of world")
	await _physics_frames(30)
	_check(player.is_on_floor(), "respawned player is on the floor again")
	_check(player.global_position.y > -1.0, "respawned player is at platform height",
		"(y=%.2f)" % player.global_position.y)
	_check(player.velocity.length() < 0.01, "velocity zeroed on respawn",
		"(v=%.3f, %.3f, %.3f)" % [player.velocity.x, player.velocity.y, player.velocity.z])


func _test_mouse_look(player: CharacterBody3D) -> void:
	print("-- mouse look: yaw and pitch respond and clamp")
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		_failures.append("no Camera3D for mouse look test")
		return
	print("    mouse_mode=%d (CAPTURED=%d) display=%s" % [
		Input.mouse_mode, Input.MOUSE_MODE_CAPTURED, DisplayServer.get_name()])
	# The player's _ready() capture call does not always stick under --script, and the
	# headless display server cannot capture at all. Assert the mode explicitly here so
	# the look/uncaptured tests are deterministic, and degrade to a warning instead of a
	# false failure when the display server cannot capture.
	if not await _ensure_mouse_capture():
		_warn("display server cannot capture the mouse; mouse look assertions skipped")
		return
	var yaw0 := player.rotation.y
	var pitch0 := cam.rotation.x

	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100, 0)
	Input.parse_input_event(motion)
	await physics_frame
	_check(absf(player.rotation.y - yaw0) > 0.0001, "yaw changed on horizontal mouse motion",
		"(dyaw=%.4f)" % (player.rotation.y - yaw0))

	# large downward motion should clamp pitch at -89 deg
	var big := InputEventMouseMotion.new()
	big.relative = Vector2(0, 100000)
	Input.parse_input_event(big)
	await physics_frame
	var min_pitch := deg_to_rad(-89.0)
	var max_pitch := deg_to_rad(89.0)
	_check(cam.rotation.x >= min_pitch - 0.001 and cam.rotation.x <= max_pitch + 0.001,
		"pitch clamped within +-89 deg", "(pitch=%.2f deg)" % rad_to_deg(cam.rotation.x))

	# large upward motion should clamp at +89
	var big2 := InputEventMouseMotion.new()
	big2.relative = Vector2(0, -100000)
	Input.parse_input_event(big2)
	await physics_frame
	_check(cam.rotation.x >= min_pitch - 0.001 and cam.rotation.x <= max_pitch + 0.001,
		"pitch clamped on upward motion too", "(pitch=%.2f deg)" % rad_to_deg(cam.rotation.x))
	cam.rotation.x = pitch0


func _test_mouse_uncaptured(player: CharacterBody3D) -> void:
	print("-- mouse uncaptured: mouse motion must NOT rotate the camera")
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		_failures.append("no Camera3D for mouse capture test")
		return
	var yaw0 := player.rotation.y
	var pitch0 := cam.rotation.x

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await physics_frame
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(200, 0)
	Input.parse_input_event(motion)
	await physics_frame
	_check(absf(player.rotation.y - yaw0) < 0.0001, "yaw unchanged while mouse uncaptured",
		"(dyaw=%.4f)" % (player.rotation.y - yaw0))
	_check(absf(cam.rotation.x - pitch0) < 0.0001, "pitch unchanged while mouse uncaptured",
		"(dpitch=%.4f)" % (cam.rotation.x - pitch0))

	if not await _ensure_mouse_capture():
		_warn("display server cannot recapture the mouse; recapture assertion skipped")
		return
	var yaw1 := player.rotation.y
	Input.parse_input_event(motion)
	await physics_frame
	_check(absf(player.rotation.y - yaw1) > 0.0001, "yaw rotates again once mouse is recaptured",
		"(dyaw=%.4f)" % (player.rotation.y - yaw1))
	cam.rotation.x = pitch0


func _test_no_stuck_velocity(player: CharacterBody3D) -> void:
	print("-- release check: no residual horizontal velocity after input release")
	await _physics_frames(30)
	_check(absf(player.velocity.x) < 0.01 and absf(player.velocity.z) < 0.01,
		"horizontal velocity zeroed after release",
		"(v=%.3f, %.3f)" % [player.velocity.x, player.velocity.z])
