extends SceneTree

## Weapon harness for VibeFPS: the pistol's magazine, its rate limit, its
## reload and the input gate around all three.
##
## The pistol is built here, in code, with a plain Node3D standing in for the
## fire source and no player anywhere in the scene: what is under test is
## magazine bookkeeping, the fire interval and the gate, and none of that needs
## a character or a level. Building it the way Task 5's pistol.tscn will is the
## point -- the pistol is handed a PackedScene for the projectile and is asked
## to instantiate it, so "decrement the magazine only after the projectile
## exists" is exercised for real rather than assumed.
##
## Headless cannot capture the cursor at all: Input.set_mouse_mode() is a silent
## no-op there, so Input.mouse_mode stays VISIBLE for the whole run and a gate
## reading it would deny everything. Exactly as in tests/movement.gd, the pistol
## is handed a subclass that answers the gate with an explicit mode; every other
## line under test is the real pistol.gd, and the harness asserts that the seam
## is live and that the untouched pistol.gd reads the engine's own mouse mode.
##
## Waits are bounded in seconds of wall clock, not in frames. The weapon's
## timers ARE the thing under test and they are in seconds; a check that counted
## frames would be asserting the headless frame rate instead of the rate limit.
##
## Run: godot --headless --path . --script res://tests/weapon.gd
##      .\tools\run_checks.ps1 weapon

## Stand-in for pistol.gd, used only by this harness.
class _PistolProbe extends "res://weapons/pistol/pistol.gd":
	## Mouse mode the gate is evaluated against instead of Input.mouse_mode.
	var gate_mouse_mode: int = Input.MOUSE_MODE_CAPTURED

	func _mouse_mode_for_play_input() -> int:
		return gate_mouse_mode


## Records everything the pistol announces, with wall-clock stamps on the two
## reload signals so the check can measure the reload in seconds.
class _Log extends RefCounted:
	var fired: int = 0
	var reload_started: int = 0
	var reload_finished: int = 0
	var magazine: Array[Vector2i] = []
	var reload_started_at_ms: int = -1
	var reload_finished_at_ms: int = -1

	func _on_fired() -> void:
		fired += 1

	func _on_reload_started() -> void:
		reload_started += 1
		reload_started_at_ms = Time.get_ticks_msec()

	func _on_reload_finished() -> void:
		reload_finished += 1
		reload_finished_at_ms = Time.get_ticks_msec()

	func _on_magazine_changed(current: int, capacity: int) -> void:
		magazine.append(Vector2i(current, capacity))

	func last_magazine() -> Vector2i:
		return magazine[magazine.size() - 1]

	func reload_duration() -> float:
		if reload_started_at_ms < 0 or reload_finished_at_ms < 0:
			return -1.0
		return float(reload_finished_at_ms - reload_started_at_ms) / 1000.0


const _PISTOL_SCRIPT_PATH := "res://weapons/pistol/pistol.gd"
const _PISTOL_DATA_PATH := "res://data/weapons/pistol.tres"
## The shipped pistol, loaded rather than rebuilt. The barrel marker is scene
## wiring, and a marker the harness invents for itself would be a marker the
## game never loads.
const _PISTOL_SCENE_PATH := "res://weapons/pistol/pistol.tscn"

## The values the design fixes for the pistol. They are restated here so a
## balance edit to pistol.tres cannot silently turn the harness into a check of
## different numbers than the one it claims to verify.
const _EXPECTED_MAGAZINE := 18
const _EXPECTED_RELOAD_TIME := 1.2
const _EXPECTED_INTERVAL := 0.4
const _EXPECTED_PROJECTILE_SPEED := 70.0
const _EXPECTED_DAMAGE := 30.0
const _EXPECTED_LIFETIME := 4.0

## Ceiling for every timed wait. Generous, because it only has to keep a broken
## pistol from turning the check into a 120 s runner timeout; a healthy pistol
## leaves it far behind.
const _WAIT_CAP_SECONDS := 15.0
## How far a measured timer may overshoot its nominal value. The timers are real
## seconds drained by per-frame deltas, so the answer overshoots by at most one
## frame -- and still nowhere near enough to hide a doubled interval, a reset
## timer or a reload that never ends.
const _TIMER_TOLERANCE := 0.35
## Float slack on the short side of a timer, so accumulated delta rounding can
## never fake a timer that ended early.
const _TIMER_EPSILON := 0.05
## How many physics ticks the flight is watched for after the aim source is
## turned and moved. At the shipped 120 Hz and 70 m/s that is half a second and
## 35 m of flight -- long enough for a bend of the parent to be unmistakable,
## short enough to stay inside the 4 s projectile lifetime.
const _TRAJECTORY_TICKS := 60
## How far off its own line the projectile may drift, in metres. The bug this
## catches moves a shot sideways by METRES (a parent yaw of 45 deg rotates the
## whole subtree around the pivot), while float32 noise over 35 m is about
## 3e-6 m. Centimetres separate the two with four orders of magnitude to spare.
const _TRAJECTORY_DRIFT_TOLERANCE := 0.05
## How far along the line the projectile must actually have travelled for the
## drift measurement above to mean anything. A projectile that never moved
## reports a drift of exactly zero and would satisfy the tolerance without
## having flown at all.
const _TRAJECTORY_MIN_TRAVEL := 2.0
## How many seconds of real frames the startup check watches a weapon that
## entered the tree with the button held. Two and a half times the 0.4 s rate
## limit, so a pistol that fires on level alone would have spent three rounds.
const _NO_SHOT_WATCH_SECONDS := 1

var _failures: PackedStringArray = []
var _checks := 0
var _data: WeaponData
## One PackedScene for every pistol in this harness, standing in for the
## projectile.tscn that Task 5 will build on disk.
var _projectile_scene: PackedScene


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


func _finish() -> void:
	print("=== RESULT: %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)


## Ends the run on a precondition the rest of the check cannot be evaluated
## against, so the runner gets a named failure and a non-zero exit code instead
## of a crash halfway through.
func _bail(reason: String) -> void:
	print("FATAL: %s" % reason)
	_finish()
	quit(1)


# --------------------------------------------------------------------------
# waiting
# --------------------------------------------------------------------------

## Runs one process frame at a time until `predicate` holds, giving up after
## `max_seconds` of wall clock. Returns whether the predicate was reached, so
## the caller can assert on a timeout instead of silently waiting forever.
func _await_until(predicate: Callable, max_seconds := _WAIT_CAP_SECONDS) -> bool:
	var deadline := _now_ms() + int(max_seconds * 1000.0)
	var reached := false
	for i in 1000000:
		await process_frame
		if predicate.call():
			reached = true
			break
		if _now_ms() >= deadline:
			break
	return reached


func _now_ms() -> int:
	return Time.get_ticks_msec()


## Releases the fire action and lets at least one real process frame go by,
## so a pistol whose arming latch needs an observed release has actually seen
## one before the next press is read as input. Scenarios that fire through the
## real input path start here; a pistol that entered the tree with the button
## already down is exactly what the startup check is about.
func _settle_fire_released() -> void:
	Input.action_release("fire")
	await process_frame
	await process_frame


## A reload key event, delivered through the real input path. Reload is read in
## the pistol's _unhandled_input, and Input.action_press alone never reaches
## _unhandled_input (tests/movement.gd and tests/interact.gd pin the same rule),
## so the press has to be a parsed key event matching the physical R binding
## declared in project.godot.
func _reload_key_event(pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_R
	ev.keycode = KEY_R
	ev.pressed = pressed
	return ev


## The aim source of the trajectory scenario hangs under a parent that the
## scenario moves afterwards. Every other scenario's aim source hangs straight
## off the world and nothing ever touches its ancestors -- which is precisely
## why a shot could stay glued to it and go unnoticed.
func _new_aim_under_pivot(world: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	world.add_child(pivot)
	var aim := Node3D.new()
	aim.name = "AimSource"
	pivot.add_child(aim)
	return pivot


## A player's camera, in the pose player.tscn gives it: high up, and the
## current one in the viewport. pistol.tscn leaves fire_rate_source empty on
## purpose, so this is the node the pistol actually aims from in the game.
func _new_eye(world: Node3D) -> Camera3D:
	var eye := Camera3D.new()
	eye.name = "Eye"
	eye.current = true
	eye.position = Vector3(0.0, 1.7, 0.0)
	world.add_child(eye)
	return eye


## The shipped pistol's geometry grafted onto a probe. The probe is what
## answers the input gate with an explicit mouse mode (headless cannot capture
## the cursor); the children are the scene's own, MOVED rather than copied, so
## the barrel marker under test is the one pistol.tscn really ships. The
## exports are set before the node enters the tree, because _ready() fills the
## magazine from them and a magazine filled from a null data is empty forever.
func _new_pistol_from_scene(world: Node3D, scene: PackedScene,
		data: WeaponData, projectiles := true) -> _PistolProbe:
	var geometry := scene.instantiate()
	var pistol := _PistolProbe.new()
	pistol.name = "Pistol"
	pistol.data = data
	if projectiles:
		pistol.projectile_scene = _projectile_scene
	for child in geometry.get_children():
		geometry.remove_child(child)
		# owner belongs to the scene tree it was packed from; carrying it over
		# would make Godot complain that the probe now owns nodes it never packed.
		child.owner = null
		pistol.add_child(child)
	geometry.free()
	world.add_child(pistol)
	for i in 8:
		await process_frame
		if pistol.is_node_ready():
			return pistol
	print("FATAL: the pistol never became ready")
	return pistol


# --------------------------------------------------------------------------
# world builders
# --------------------------------------------------------------------------

## One scenario's world. Freeing it at the end of the scenario takes the pistol,
## the dummy fire source and every projectile the pistol spawned with it.
func _new_world() -> Node3D:
	var world := Node3D.new()
	world.name = "World"
	root.add_child(world)
	return world


## The stand-in for the player's camera, and the pistol's fire_rate_source: it
## decides the AIM and nothing else. `yaw` turns it, so a shot that follows the
## aim source's forward axis is distinguishable from one that fires along a
## hardcoded world axis.
##
## Named for what it is, not for what it looks like: since the barrel split,
## "Muzzle" in this project means the pistol's Muzzle marker -- the spawn point
## -- and a fire source wearing that name would read as one. The node this
## builds is deliberately not called Muzzle, so a scenario cannot accidentally
## satisfy the barrel lookup with it.
func _new_aim_source(world: Node3D, yaw := 0.0) -> Node3D:
	var aim := Node3D.new()
	aim.name = "AimSource"
	aim.rotation.y = yaw
	world.add_child(aim)
	return aim


## A node added to the tree is not ready the moment add_child() returns: the
## engine queues it and runs _ready() on a later main-loop pass. The harness
## waits for that before measuring anything about a fresh pistol, otherwise
## "a fresh pistol has a full magazine" would be a claim about a node whose
## _ready() had not run yet.
func _new_pistol(world: Node3D, data: WeaponData, aim: Node3D,
		with_projectiles := true) -> _PistolProbe:
	var pistol := _PistolProbe.new()
	pistol.name = "Pistol"
	pistol.data = data
	pistol.fire_rate_source = aim
	if with_projectiles:
		pistol.projectile_scene = _projectile_scene
	world.add_child(pistol)
	for i in 8:
		await process_frame
		if pistol.is_node_ready():
			return pistol
	print("FATAL: the pistol never became ready")
	return pistol


func _watch(pistol: _PistolProbe) -> _Log:
	var log := _Log.new()
	pistol.fired.connect(log._on_fired)
	pistol.reload_started.connect(log._on_reload_started)
	pistol.reload_finished.connect(log._on_reload_finished)
	pistol.magazine_changed.connect(log._on_magazine_changed)
	return log


## The projectiles under `parent`. The pistol parents every shot to its AIM
## source -- that is the lifecycle parent -- so this is how the harness finds
## live bullets. The spawn point is a different node entirely.
func _live_projectiles(parent: Node3D) -> Array[Projectile]:
	var out: Array[Projectile] = []
	for child in parent.get_children():
		if child is Projectile:
			out.append(child as Projectile)
	return out


## The projectile scene, packed in memory. Task 5 builds projectile.tscn; until
## then this stands in for it, with the CollisionShape3D that Task 2 found to be
## mandatory -- an Area3D with no shape finds nothing.
func _build_projectile_scene() -> PackedScene:
	var bullet := Projectile.new()
	bullet.name = "Projectile"
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var sphere := SphereShape3D.new()
	sphere.radius = 0.08
	shape.shape = sphere
	bullet.add_child(shape)
	# pack() stores only children the packed root owns, exactly as the editor
	# does when it saves a scene.
	shape.owner = bullet
	var packed := PackedScene.new()
	var err := packed.pack(bullet)
	bullet.free()
	if err != OK:
		return null
	return packed


func _signal_arg_count(node: Object, signal_name: String) -> int:
	for entry in node.get_signal_list():
		if String(entry.get("name", "")) == signal_name:
			return (entry["args"] as Array).size()
	return -1


## The hint string an @export carries ("PackedScene", "Node3D", ...), which is
## how the harness sees the declared type of an export.
func _property_hint(node: Object, property_name: String) -> String:
	for entry in node.get_property_list():
		if String(entry.get("name", "")) == property_name:
			return String(entry.get("hint_string", ""))
	return "<missing>"


# --------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------

func _initialize() -> void:
	print("=== VibeFPS weapon test ===")
	_data = load(_PISTOL_DATA_PATH) as WeaponData
	if _data == null:
		_bail("cannot load %s as a WeaponData" % _PISTOL_DATA_PATH)
		return
	_projectile_scene = _build_projectile_scene()
	if _projectile_scene == null:
		_bail("cannot pack the in-memory projectile scene")
		return

	_test_source_contract()
	_test_contracts()
	_test_gate_harness()
	await _test_starting_magazine()
	await _test_single_shot()
	await _test_shot_follows_fire_source()
	await _test_shot_keeps_its_line_when_the_aim_source_moves()
	await _test_shot_starts_at_the_barrel()
	await _test_no_shot_while_the_button_is_down_on_entry()
	await _test_empty_magazine_and_manual_reload()
	await _test_reload_blocks_firing_and_cannot_be_restarted()
	await _test_fire_rate()
	await _test_input_gate()
	await _test_full_magazine_has_nothing_to_reload()
	await _test_scene_change_reset()
	await _test_invalid_data_blocks_firing()
	await _test_missing_projectile_scene_keeps_the_round()

	_finish()
	quit(1 if _failures.size() > 0 else 0)


# --------------------------------------------------------------------------
# checks
# --------------------------------------------------------------------------

## Two rules the brief fixes that no behavioural check can see, because a
## violation shows up as a subtly wrong frame budget rather than a named
## failure: the timers must run in _process (firing is an action at render
## cadence, not a physics simulation) and can_fire() must ask InputGate rather
## than reading Input.mouse_mode itself.
func _test_source_contract() -> void:
	print("-- source contract: the frame the timers run in, and who asks the gate")
	var source := FileAccess.get_file_as_string(_PISTOL_SCRIPT_PATH)
	_check(source != "", "pistol.gd is readable", "(%d bytes)" % source.length())
	_check(source.contains("func _process(delta"),
		"pistol.gd runs its timers in _process, not in a physics tick")
	_check(not source.contains("func _physics_process"),
		"pistol.gd declares no _physics_process: the fire interval is in seconds")
	_check(source.count("InputGate.is_play_input_allowed(") >= 1,
		"can_fire() asks InputGate for permission",
		"(call sites=%d)" % source.count("InputGate.is_play_input_allowed("))


## Task 5 builds pistol.tscn against these names, and a renamed export or a
## renamed signal is a silent break for it.
func _test_contracts() -> void:
	print("-- contracts: the class, exports, methods and signals Task 5 binds to")
	var script := load(_PISTOL_SCRIPT_PATH) as Script
	_check(script != null, "pistol.gd loads")
	if script == null:
		return
	_check(script.get_global_name() == "Pistol",
		"pistol.gd declares class_name Pistol", "(got \"%s\")" % script.get_global_name())
	_check(script.get_instance_base_type() == "Node3D", "Pistol extends Node3D",
		"(got %s)" % script.get_instance_base_type())

	var pistol: Node = script.new()
	for method in ["can_fire", "try_fire", "start_reload", "current_mag",
			"is_reloading", "reset_for_scene_change"]:
		_check(pistol.has_method(method), "Pistol exposes %s()" % method)
	for signal_name in ["fired", "reload_started", "reload_finished", "magazine_changed"]:
		_check(pistol.has_signal(signal_name), "Pistol exposes the %s signal" % signal_name)
	_check(_signal_arg_count(pistol, "magazine_changed") == 2,
		"magazine_changed carries (current, capacity)",
		"(got %d args)" % _signal_arg_count(pistol, "magazine_changed"))
	_check(_property_hint(pistol, "data") == "WeaponData",
		"data is a WeaponData export", "(got \"%s\")" % _property_hint(pistol, "data"))
	_check(_property_hint(pistol, "projectile_scene") == "PackedScene",
		"projectile_scene is a PackedScene export",
		"(got \"%s\")" % _property_hint(pistol, "projectile_scene"))
	_check(_property_hint(pistol, "fire_rate_source") == "Node3D",
		"fire_rate_source is a Node3D export",
		"(got \"%s\")" % _property_hint(pistol, "fire_rate_source"))
	# Unassigned, because pistol.tscn leaves it empty on purpose and the pistol
	# has to fall back to the player's own camera.
	_check(pistol.get("fire_rate_source") == null,
		"fire_rate_source is empty by default, so the pistol falls back to the camera")
	pistol.free()


## The gate is only trustworthy if the harness really is driving it. If the seam
## were dead, every "the gate blocks firing" assertion below would pass for the
## wrong reason -- the pistol would deny itself whatever the mouse mode was.
func _test_gate_harness() -> void:
	print("-- gate harness: the seam is live and pistol.gd reads Input.mouse_mode")
	var script := load(_PISTOL_SCRIPT_PATH) as Script
	var stock: Node = script.new()
	_check(int(stock.call("_mouse_mode_for_play_input")) == Input.mouse_mode,
		"the untouched pistol.gd asks the engine for the mouse mode",
		"(mouse_mode=%d)" % Input.mouse_mode)
	stock.free()
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"precondition: headless really cannot capture the cursor",
		"(mouse_mode=%d)" % Input.mouse_mode)
	_check(InputGate.is_play_input_allowed(Input.MOUSE_MODE_CAPTURED),
		"the gate allows play input while the cursor is captured")
	_check(not InputGate.is_play_input_allowed(Input.MOUSE_MODE_VISIBLE),
		"the gate denies play input while the cursor is free")


func _test_starting_magazine() -> void:
	print("-- start: a fresh pistol has a full magazine and nothing else going on")
	var world := _new_world()
	var pistol := await _new_pistol(world, _data, _new_aim_source(world))
	var log := _watch(pistol)

	_check(pistol.current_mag() == _EXPECTED_MAGAZINE,
		"a fresh pistol starts with a full magazine",
		"(got %d of %d)" % [pistol.current_mag(), _EXPECTED_MAGAZINE])
	_check(not pistol.is_reloading(), "a fresh pistol is not reloading")
	_check(pistol.can_fire(), "a fresh pistol with valid data can fire")
	_check(log.fired == 0, "nothing fired just by existing")
	# magazine_changed reports changes. The initial count is read with
	# current_mag(), and a signal that fires on every node that ever appeared
	# would be a HUD that redraws the ammo count for no reason.
	_check(log.magazine.is_empty(),
		"magazine_changed stays quiet on start: it announces changes, not existence",
		"(got %s)" % str(log.magazine))
	world.free()


## One shot has to do all of this at once: consume exactly one round, announce
## itself once, report the new count with the capacity, and put a projectile
## into the world configured from the weapon data and launched along the fire
## source's forward axis.
func _test_single_shot() -> void:
	print("-- one shot: one round, one signal, one flying projectile")
	var world := _new_world()
	var aim := _new_aim_source(world)
	var pistol := await _new_pistol(world, _data, aim)
	var log := _watch(pistol)

	_check(pistol.try_fire(), "try_fire() reports the shot it made")
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
		"the magazine lost exactly one round", "(got %d)" % pistol.current_mag())
	_check(log.fired == 1, "fired arrived exactly once", "(got %d)" % log.fired)
	_check(log.magazine.size() == 1,
		"magazine_changed arrived once for the shot", "(got %d)" % log.magazine.size())
	_check(log.magazine.size() == 1
			and log.last_magazine() == Vector2i(_EXPECTED_MAGAZINE - 1, _EXPECTED_MAGAZINE),
		"magazine_changed carries the new count and the capacity",
		"(got %s)" % str(log.magazine))

	var bullets := _live_projectiles(aim)
	_check(bullets.size() == 1, "exactly one projectile node was spawned",
		"(got %d)" % bullets.size())
	if bullets.size() == 1:
		var bullet := bullets[0]
		_check(is_equal_approx(bullet.speed, _EXPECTED_PROJECTILE_SPEED),
			"the projectile takes its speed from the weapon data",
			"(got %.1f m/s)" % bullet.speed)
		_check(is_equal_approx(bullet.damage, _EXPECTED_DAMAGE),
			"the projectile takes its damage from the weapon data",
			"(got %.1f)" % bullet.damage)
		_check(is_equal_approx(bullet.lifetime, _EXPECTED_LIFETIME),
			"the projectile takes its lifetime from the weapon data",
			"(got %.1f s)" % bullet.lifetime)
		var start: Vector3 = bullet.global_position
		await _await_until(func() -> bool: return bullet.global_position.distance_to(start) > 0.5, 5.0)
		var moved: Vector3 = bullet.global_position - start
		# A projectile that was added to the tree but never launched would sit
		# still: Projectile._ready() switches its own processing off and only
		# launch() switches it back on.
		_check(moved.length() > 0.5,
			"the projectile is flying, so launch() was called on a node already in the tree",
			"(moved %.3f m)" % moved.length())
		_check(moved.normalized().dot(-aim.global_transform.basis.z) > 0.99,
			"it leaves along the fire source's forward axis",
			"(%.3f m along %.3f m forward)" % [
				moved.length(), moved.normalized().dot(-aim.global_transform.basis.z)])
	world.free()


## The same shot with a fire source turned 90 degrees. If the direction came
## from a hardcoded world axis, this shot would fly off into the wall and the
## assertions above would still pass.
func _test_shot_follows_fire_source() -> void:
	print("-- direction: the shot follows the fire source, not a world axis")
	var world := _new_world()
	# -90 degrees of yaw turns the forward axis from -Z into +X.
	var aim := _new_aim_source(world, -PI / 2.0)
	var pistol := await _new_pistol(world, _data, aim)
	_check(pistol.try_fire(), "the shot was fired")

	var bullets := _live_projectiles(aim)
	_check(bullets.size() == 1, "one projectile was spawned", "(got %d)" % bullets.size())
	if bullets.size() == 1:
		var bullet := bullets[0]
		var start: Vector3 = bullet.global_position
		await _await_until(func() -> bool: return bullet.global_position.distance_to(start) > 0.5, 5.0)
		var moved: Vector3 = bullet.global_position - start
		print("    travelled %s" % moved)
		_check(moved.x > 0.5,
			"the shot left along the turned fire source, not along -Z",
			"(dx=%.3f m)" % moved.x)
		_check(absf(moved.z) < 0.05,
			"and left no trace along the world Z axis it was not aimed at",
			"(dz=%.3f m)" % moved.z)
	world.free()


## A shot must keep going where it was sent, whatever the aim source does
## afterwards. The player's camera is attached to a character who turns and
## walks every frame, and a projectile that stays a child of that camera has
## its world transform rewritten by the parent's every tick -- so a 45 degree
## yaw after the shot drags the bullet sideways by metres while it is in
## flight, and the bullet the player sees is not the bullet that hits.
##
## The aim source here hangs under a pivot that the scenario turns and moves
## after the shot, which is the player's own situation with one layer of
## indirection. The projectile is still parented to the aim source (the
## lifecycle parent is what free() and the projectile lists read), so this is
## about the transform, never about the parenting.
func _test_shot_keeps_its_line_when_the_aim_source_moves() -> void:
	print("-- trajectory: the shot keeps its line when the aim source's parent moves")
	var world := _new_world()
	var pivot := _new_aim_under_pivot(world)
	var aim := pivot.get_node("AimSource") as Node3D
	var pistol := await _new_pistol(world, _data, aim)
	await _settle_fire_released()
	Input.action_press("fire")
	var spawned := await _await_until(func() -> bool: return _live_projectiles(aim).size() > 0, 5.0)
	Input.action_release("fire")
	_check(spawned, "the shot was fired through the real input path",
		"(got %d projectiles)" % _live_projectiles(aim).size())
	if not spawned:
		world.free()
		return

	var bullet := _live_projectiles(aim)[0]
	_check(bullet.get_parent() == aim,
		"the projectile is still parented to the aim source: lifecycle did not change")
	var start: Vector3 = bullet.global_position
	# The line the shot is supposed to keep. Read once, before the world moves
	# under it -- that is what "goes where it was aimed" means.
	var line := -aim.global_transform.basis.z

	pivot.rotation.y = deg_to_rad(45.0)
	pivot.position = Vector3(2.0, 0.0, 0.0)

	var worst := 0.0
	var travelled := 0.0
	for i in _TRAJECTORY_TICKS:
		await physics_frame
		if not is_instance_valid(bullet):
			break
		var offset: Vector3 = bullet.global_position - start
		# Distance from the line, not from the origin: the shot is SUPPOSED to
		# travel along `line`, so only the sideways component is drift.
		worst = maxf(worst, (offset - line * offset.dot(line)).length())
		travelled = maxf(travelled, offset.dot(line))
	print("    worst sideways drift %.4f m, forward travel %.3f m over %d physics ticks" % [
		worst, travelled, _TRAJECTORY_TICKS])
	# Precondition, and it is load-bearing. Drift of zero is what a CORRECT shot
	# looks like -- and also what a projectile that never moved looks like: the
	# loop would sample one position forever and pass the tolerance below for
	# the wrong reason. So the flight is proved first, along the line the bullet
	# is supposed to follow. Half a second at 70 m/s is ~35 m; the threshold is
	# 2.0 m, far below that and far above the sub-millimetre distance a frozen
	# bullet accumulates.
	_check(travelled > _TRAJECTORY_MIN_TRAVEL,
		"precondition: the projectile really flew, so a drift of zero means a straight shot",
		"(travelled %.3f m along the line, want > %.1f m)" % [travelled, _TRAJECTORY_MIN_TRAVEL])
	_check(worst <= _TRAJECTORY_DRIFT_TOLERANCE,
		"the shot flew straight: moving the aim source's parent did not bend it",
		"(worst sideways drift %.4f m, tolerance %.3f m)" % [worst, _TRAJECTORY_DRIFT_TOLERANCE])
	_check(is_instance_valid(bullet), "and the projectile was still alive at the end of the flight")
	world.free()


## Where a shot STARTS and where it is AIMED are two different questions. The
## design pins the second one to the camera (a pistol held to the side is
## offset from the eye on purpose, player.tscn), but the first one is the
## barrel: a bullet that leaves the camera is visibly fired out of the
## player's head, and the two points are a hand's width apart.
##
## The pistol here is the shipped pistol.tscn, instantiated rather than
## rebuilt in code, so this is also the wiring check: a scene without a Muzzle
## marker falls back to the camera, and the fallback is asserted below rather
## than left to the log.
func _test_shot_starts_at_the_barrel() -> void:
	print("-- start point: the shot leaves the barrel, aimed by the camera")
	var packed: PackedScene = load(_PISTOL_SCENE_PATH)
	_check(packed != null, "pistol.tscn is loadable", "(%s)" % _PISTOL_SCENE_PATH)
	if packed == null:
		return
	var world := _new_world()
	var eye := _new_eye(world)
	# fire_rate_source left empty on purpose, exactly as pistol.tscn leaves it:
	# the pistol must find the camera the way it does in the game.
	var pistol := await _new_pistol_from_scene(world, packed, _data)

	var barrel := pistol.get_node_or_null("Muzzle") as Node3D
	_check(barrel != null,
		"pistol.tscn carries a Muzzle marker: the barrel is a place, not a guess")
	_check(barrel != null and barrel.global_position.z < -0.1,
		"and it sits in front of the pistol, not inside the grip",
		"(got %s)" % ("no Muzzle" if barrel == null else str(barrel.global_position)))

	var log := _watch(pistol)
	_check(pistol.try_fire(), "the shot was fired")
	_check(log.fired == 1, "and it announced exactly one shot", "(got %d)" % log.fired)
	var bullets := _live_projectiles(eye)
	_check(bullets.size() == 1, "one projectile was spawned under the camera",
		"(got %d)" % bullets.size())
	if bullets.size() == 1 and barrel != null:
		var bullet := bullets[0]
		_check(bullet.global_position.distance_to(barrel.global_position) < 0.001,
			"the shot starts at the barrel, not at the camera",
			"(bullet at %s, barrel at %s, eye at %s)" % [
				str(bullet.global_position), str(barrel.global_position), str(eye.global_position)])
		_check(bullet.global_position.distance_to(eye.global_position) > 0.1,
			"and visibly not out of the eye the player is looking through",
			"(%.3f m from the eye)" % bullet.global_position.distance_to(eye.global_position))
		var start: Vector3 = bullet.global_position
		await _await_until(func() -> bool: return bullet.global_position.distance_to(start) > 0.5, 5.0)
		var moved: Vector3 = bullet.global_position - start
		_check(moved.normalized().dot(-eye.global_transform.basis.z) > 0.99,
			"but it is still aimed by the camera, not by the barrel",
			"(%.3f m along %.3f m of the camera's forward axis)" % [
				moved.length(), moved.normalized().dot(-eye.global_transform.basis.z)])
	world.free()

	# The fallback chain is part of the contract, not an accident: a harness or
	# a scene built without a barrel marker still has to shoot from somewhere.
	# It is asserted here so a future "no barrel in this scene" cannot turn into
	# a bullet fired out of the player's skull with a clean test log.
	var bare_world := _new_world()
	var bare_eye := _new_eye(bare_world)
	var bare := await _new_pistol(bare_world, _data, null)
	_check(bare.get_node_or_null("Muzzle") == null,
		"precondition: a pistol built without a barrel marker really has none")
	_check(bare.try_fire(), "a pistol without a barrel marker still fires")
	var bare_bullets := _live_projectiles(bare_eye)
	_check(bare_bullets.size() == 1, "its projectile is parented to the camera",
		"(got %d)" % bare_bullets.size())
	if bare_bullets.size() == 1:
		_check(bare_bullets[0].global_position.distance_to(bare_eye.global_position) < 0.001,
			"and falls back to firing from the camera rather than refusing to shoot",
			"(bullet at %s, eye at %s)" % [
				str(bare_bullets[0].global_position), str(bare_eye.global_position)])
	bare_world.free()


## The pistol polls `Input.is_action_pressed("fire")` every frame, so the
## button's state at the moment it enters the tree IS a command. A real player
## gets there with the left button already down -- the window took focus with
## the mouse captured and the button never came up -- and the pistol's cooldown
## and magazine both start at zero, so the first frame of every level is a free
## shot the player never asked for.
##
## The latch is "no shot until a release has been observed", so the shot
## happens on the next REAL press, and holding the button afterwards keeps
## firing at the rate limit exactly as before.
func _test_no_shot_while_the_button_is_down_on_entry() -> void:
	print("-- startup: a fire button already down when the pistol enters the tree is not a shot")
	# Pressed BEFORE the pistol exists: this is a button that was down when the
	# level loaded, not a press the player is making now.
	Input.action_press("fire")
	var world := _new_world()
	# Built here rather than through _new_pistol() so the log is subscribed
	# BEFORE the node enters the tree. _new_pistol() awaits frames, and a shot
	# spent during that wait would fire a signal nobody was listening to yet --
	# which would turn this check green for exactly the wrong reason.
	var pistol := _PistolProbe.new()
	pistol.name = "Pistol"
	pistol.data = _data
	pistol.fire_rate_source = _new_aim_source(world)
	pistol.projectile_scene = _projectile_scene
	var log := _watch(pistol)
	world.add_child(pistol)
	for i in 8:
		await process_frame
		if pistol.is_node_ready():
			break
	_check(pistol.gate_mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"precondition: the input gate is open, so only the button can hold the shot back")

	# A full second of real frames with the button down -- longer than the 0.4 s
	# rate limit, so a pistol that fires on level alone would spend three rounds.
	for i in _NO_SHOT_WATCH_SECONDS * 60:
		await process_frame
	_check(log.fired == 0,
		"a weapon that entered the tree with fire held does not shoot",
		"(got %d shots, magazine %d of %d)" % [log.fired, pistol.current_mag(), _EXPECTED_MAGAZINE])
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE,
		"and it kept every round", "(got %d)" % pistol.current_mag())

	# The player's answer to "nothing happened": let go and press again.
	Input.action_release("fire")
	await process_frame
	await process_frame
	Input.action_press("fire")
	var answered := await _await_until(func() -> bool: return log.fired > 0, 2.0)
	Input.action_release("fire")
	await process_frame
	_check(answered, "and it does shoot on the next real press",
		"(got %d shots)" % log.fired)
	_check(log.fired == 1, "exactly one shot, not a burst that undoes the latch",
		"(got %d shots)" % log.fired)
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
		"costing exactly one round", "(got %d)" % pistol.current_mag())
	world.free()


## A full magazine's worth of rounds at the design's rate, then the attempt past
## the last one: refused, with the magazine untouched. The pistol does NOT reload
## itself: an empty magazine stays empty and quiet, and only the reload action
## (physical R) starts the reload -- through the same input gate as fire. The
## held fire button produces nothing for the whole reload, which is the case the
## plan's review section calls out: an empty magazine and a fire press in the
## same frame must neither shoot nor restart the reload.
func _test_empty_magazine_and_manual_reload() -> void:
	print("-- full magazine, the empty magazine, and the reload the player asks for with R")
	var world := _new_world()
	var aim := _new_aim_source(world)
	var pistol := await _new_pistol(world, _data, aim)
	var log := _watch(pistol)

	# The fire action is held from the first frame, so the whole magazine is spent
	# on the real input path rather than by calling try_fire() behind the
	# pistol's back. The release before it is the harness's half of the
	# arming latch (see _settle_fire_released): the pistol has to see the
	# button up before it will read a press as one.
	await _settle_fire_released()
	Input.action_press("fire")
	var emptied := await _await_until(func() -> bool: return log.fired >= _EXPECTED_MAGAZINE, 20.0)
	_check(emptied, "holding fire empties the magazine in %d rounds" % _EXPECTED_MAGAZINE,
		"(got %d)" % log.fired)

	# Same frame as the last round: the cooldown is running and the magazine is
	# empty. can_fire() does not consult the cooldown, so a refusal here is the
	# magazine's doing.
	_check(pistol.current_mag() == 0, "the magazine is empty",
		"(got %d)" % pistol.current_mag())
	_check(not pistol.can_fire(), "can_fire() is false on an empty magazine")
	_check(not pistol.try_fire(), "the try_fire() past the last round is refused")
	_check(pistol.current_mag() == 0, "the refused shot left the magazine at 0",
		"(got %d)" % pistol.current_mag())
	_check(log.fired == _EXPECTED_MAGAZINE,
		"no round past the last one left the magazine", "(got %d signals)" % log.fired)

	# The new contract: no automatic reload. The magazine is empty and the fire
	# button is still held; the pistol is watched for longer than a full reload
	# would have taken, and it has to stay empty and silent.
	Input.action_release("fire")
	var quiet_until := _now_ms() + int(_EXPECTED_RELOAD_TIME * 1.5 * 1000.0)
	while _now_ms() < quiet_until:
		await process_frame
	_check(log.reload_started == 0,
		"an empty magazine does NOT start a reload on its own",
		"(got %d reloads)" % log.reload_started)
	_check(pistol.is_reloading() == false, "and the pistol is not reloading by itself")
	_check(pistol.current_mag() == 0, "the magazine is still empty",
		"(got %d)" % pistol.current_mag())

	# The gate: with the cursor free R is not play input and must not reload.
	pistol.gate_mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.parse_input_event(_reload_key_event(true))
	Input.flush_buffered_events()
	await physics_frame
	Input.parse_input_event(_reload_key_event(false))
	Input.flush_buffered_events()
	await physics_frame
	_check(log.reload_started == 0,
		"R with a free cursor does not start a reload",
		"(got %d reloads)" % log.reload_started)
	_check(not pistol.is_reloading(), "and leaves the pistol idle, not reloading")

	# Capturing the cursor is the only thing that has to change.
	pistol.gate_mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.parse_input_event(_reload_key_event(true))
	Input.flush_buffered_events()
	var started := await _await_until(func() -> bool: return log.reload_started > 0, 5.0)
	Input.parse_input_event(_reload_key_event(false))
	Input.flush_buffered_events()
	_check(started, "pressing reload starts the reload")
	_check(pistol.is_reloading(), "the pistol reports itself reloading")
	_check(log.reload_started == 1, "exactly one reload was started",
		"(got %d)" % log.reload_started)

	# The fire button is held again through the reload. Nothing may come out
	# until the magazine is full again.
	await _settle_fire_released()
	Input.action_press("fire")
	var leaked := await _await_until(func() -> bool: return log.fired > _EXPECTED_MAGAZINE, 0.4)
	_check(not leaked, "a held fire button spends no rounds while the magazine is empty",
		"(got %d)" % log.fired)

	# Released before the reload can end, on purpose: a button still held at the
	# moment the magazine is full fires again in that very frame, which is
	# correct weapon behaviour and is pinned on purpose further down. Leaving it
	# held here would measure the refill and the next shot in one observation.
	Input.action_release("fire")
	var finished := await _await_until(func() -> bool: return log.reload_finished > 0)
	_check(finished, "the reload finished")
	if finished:
		var elapsed := log.reload_duration()
		print("    reload took %.3f s" % elapsed)
		_check(elapsed >= _EXPECTED_RELOAD_TIME - _TIMER_EPSILON
				and elapsed <= _EXPECTED_RELOAD_TIME + _TIMER_TOLERANCE,
			"the reload took about %.1f s" % _EXPECTED_RELOAD_TIME,
			"(got %.3f s, tol +%.2f s)" % [elapsed, _TIMER_TOLERANCE])
		_check(pistol.current_mag() == _EXPECTED_MAGAZINE,
			"the magazine is full again", "(got %d)" % pistol.current_mag())
		_check(not pistol.is_reloading(), "the pistol is no longer reloading")
		_check(log.reload_finished == 1, "reload_finished arrived exactly once",
			"(got %d)" % log.reload_finished)
		_check(log.last_magazine() == Vector2i(_EXPECTED_MAGAZINE, _EXPECTED_MAGAZINE),
			"magazine_changed announced the refilled magazine",
			"(got %s)" % str(log.magazine))
		_check(pistol.can_fire(), "the pistol can shoot again after the reload")

		# And it really can: a press now goes through at once, so the reload left
		# behind neither a stuck reloading flag nor a leftover cooldown.
		Input.action_press("fire")
		var resumed := await _await_until(func() -> bool: return log.fired > _EXPECTED_MAGAZINE, 2.0)
		Input.action_release("fire")
		_check(resumed, "a press right after the reload fires at once: no stuck cooldown",
			"(got %d shots)" % log.fired)
		_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
			"and that press cost exactly one round", "(got %d)" % pistol.current_mag())
	world.free()


## The reload has to be a wall, not a suggestion: a magazine that still has rounds
## in it must not hand them out while the pistol is reloading, and the reload
## must not be restartable. The second half matters because a restart resets the
## timer, and a player who can reset it can postpone the reload forever.
func _test_reload_blocks_firing_and_cannot_be_restarted() -> void:
	print("-- reloading: no rounds from a partly full magazine, and no restart")
	var world := _new_world()
	var aim := _new_aim_source(world)
	var pistol := await _new_pistol(world, _data, aim)
	var log := _watch(pistol)

	pistol.try_fire()
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
		"precondition: a partly spent magazine is left", "(got %d)" % pistol.current_mag())
	_check(pistol.start_reload(), "a spent magazine accepts a reload")
	_check(pistol.is_reloading(), "the pistol reports itself reloading")
	_check(log.reload_started == 1, "reload_started arrived once", "(got %d)" % log.reload_started)

	# The magazine still has rounds in it and the rate limit expires well inside a
	# 1.2 s reload, so without the is_reloading() rule in can_fire() this window
	# hands the player a round one interval in -- before the restart attempt
	# below, so the two defects cannot mask each other. The release first is the
	# harness's half of the arming latch: this pistol was created with the
	# button already up and has to be seen holding it that way.
	await _settle_fire_released()
	Input.action_press("fire")
	var halfway := await _await_until(func() -> bool:
		return _now_ms() - log.reload_started_at_ms >= 600, _EXPECTED_RELOAD_TIME + 1.0)
	_check(halfway, "precondition: half the reload went by with the button still held")
	_check(log.fired == 1,
		"a held fire button spends no rounds while reloading, even with rounds left",
		"(got %d shots, the rate limit expired %.1f s into the reload)" % [
			log.fired, _EXPECTED_INTERVAL])

	# Now halfway in, ask for a second reload.
	var restart_at := _now_ms()
	_check(not pistol.start_reload(),
		"start_reload() refuses to restart a reload in progress")
	_check(pistol.is_reloading(), "the refused restart did not cancel the reload either")
	# Released here for the same reason as in the scenario above: a button held
	# at the instant the magazine is full fires again immediately, and that shot
	# would be counted as a round lost to the reload.
	Input.action_release("fire")

	var finished := await _await_until(func() -> bool: return log.reload_finished > 0)
	_check(finished, "the reload still finished")
	if finished:
		var total := log.reload_duration()
		var left_at_restart := float(log.reload_finished_at_ms - restart_at) / 1000.0
		print("    reload took %.3f s; %.3f s of it were left after the refused restart" % [
			total, left_at_restart])
		_check(total >= _EXPECTED_RELOAD_TIME - _TIMER_EPSILON
				and total <= _EXPECTED_RELOAD_TIME + _TIMER_TOLERANCE,
			"the reload still took about %.1f s in total" % _EXPECTED_RELOAD_TIME,
			"(got %.3f s)" % total)
		# The load-bearing half: the refused restart must not have pushed the
		# timer back to the full reload time. 0.6 s had already gone, so a reset
		# would leave roughly 1.2 s instead of roughly 0.6 s.
		_check(left_at_restart < _EXPECTED_RELOAD_TIME - 0.2,
			"the refused restart did not push the timer back to the full reload time",
			"(%.3f s left after the restart attempt at 0.6 s, expected under %.2f s)" % [
				left_at_restart, _EXPECTED_RELOAD_TIME - 0.2])
		_check(log.reload_started == 1, "still exactly one reload was started",
			"(got %d)" % log.reload_started)
		_check(log.fired == 1,
			"not one round came out of the reload, held or not",
			"(got %d shots)" % log.fired)
		_check(pistol.current_mag() == _EXPECTED_MAGAZINE,
			"the reload refilled the magazine", "(got %d)" % pistol.current_mag())
	world.free()


## The rate limit is in seconds and comes from the weapon data, so it is
## measured in seconds. A limit counted in frames would move with the frame
## rate, and the shipped fire rate has to stay the shipped fire rate on a
## 240 Hz display.
func _test_fire_rate() -> void:
	print("-- rate limit: the interval is the data's %.1f s, counted in seconds" % _EXPECTED_INTERVAL)
	var world := _new_world()
	var pistol := await _new_pistol(world, _data, _new_aim_source(world))
	var log := _watch(pistol)

	_check(is_equal_approx(_data.seconds_between_shots(), _EXPECTED_INTERVAL),
		"precondition: the shipped data asks for one shot per %.1f s" % _EXPECTED_INTERVAL,
		"(got %.4f s)" % _data.seconds_between_shots())
	var start := _now_ms()
	_check(pistol.try_fire(), "the first shot is allowed")
	_check(not pistol.try_fire(),
		"a second shot in the same frame is refused by the interval")
	_check(log.fired == 1, "only one round left the magazine", "(got %d)" % log.fired)
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
		"the refused second shot cost no round", "(got %d)" % pistol.current_mag())

	var frames := 0
	var second := false
	for i in 6000:
		await process_frame
		frames += 1
		if pistol.try_fire():
			second = true
			break
	var elapsed := float(_now_ms() - start) / 1000.0
	print("    second shot after %.3f s and %d process frames" % [elapsed, frames])
	_check(second, "the next shot is allowed once the interval has passed")
	_check(elapsed >= _EXPECTED_INTERVAL - _TIMER_EPSILON,
		"the second shot waited at least the full interval",
		"(waited %.3f s, want >= %.2f s)" % [elapsed, _EXPECTED_INTERVAL - _TIMER_EPSILON])
	_check(elapsed <= _EXPECTED_INTERVAL + _TIMER_TOLERANCE,
		"and did not wait much longer than the interval",
		"(waited %.3f s, want <= %.2f s)" % [
			elapsed, _EXPECTED_INTERVAL + _TIMER_TOLERANCE])
	_check(log.fired == 2, "exactly two rounds left the magazine",
		"(got %d)" % log.fired)
	world.free()


## The fire action must not be a way around the input gate: with the cursor
## free the same held input has to do nothing at all, and opening the gate has
## to be the only thing that changes.
func _test_input_gate() -> void:
	print("-- input gate: the fire action does not get around the cursor being free")
	var world := _new_world()
	var pistol := await _new_pistol(world, _data, _new_aim_source(world))
	var log := _watch(pistol)
	_check(pistol.get_script() == _PistolProbe,
		"precondition: the pistol under test runs the harness probe script")

	pistol.gate_mouse_mode = Input.MOUSE_MODE_VISIBLE
	_check(not pistol.can_fire(), "can_fire() is false while the cursor is free")
	_check(not pistol.try_fire(), "try_fire() refuses while the cursor is free")
	# Released first, and seen released: with the gate shut the pistol must be
	# refusing for the gate's reason alone, not because the arming latch never
	# fired. That is the whole point of pinning the two rules apart.
	await _settle_fire_released()
	Input.action_press("fire")
	var gated_shot := await _await_until(func() -> bool: return log.fired > 0, 1.5)
	_check(not gated_shot, "a held fire action shoots nothing while the cursor is free",
		"(got %d)" % log.fired)
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE,
		"the gated pistol kept every round", "(got %d)" % pistol.current_mag())
	_check(log.magazine.is_empty(),
		"and announced nothing to a HUD either", "(got %s)" % str(log.magazine))
	Input.action_release("fire")

	pistol.gate_mouse_mode = Input.MOUSE_MODE_CAPTURED
	_check(pistol.can_fire(), "can_fire() is true again once the cursor is captured")
	Input.action_press("fire")
	var opened := await _await_until(func() -> bool: return log.fired > 0, 2.0)
	_check(opened, "the same held input fires as soon as the gate opens",
		"(got %d shots)" % log.fired)
	# The gate opened halfway through a second interval; holding the button must
	# not turn that into a shot.
	var burst := await _await_until(func() -> bool: return log.fired > 1, 0.2)
	_check(not burst, "holding fire still does not shoot past the rate limit",
		"(got %d shots)" % log.fired)
	Input.action_release("fire")
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
		"exactly one round was spent by the ungated press", "(got %d)" % pistol.current_mag())
	world.free()


## Reloading a full magazine would announce a reload that ends with the magazine
## unchanged, and it would be a player's way to start a reload while holding the
## button down for no reason.
func _test_full_magazine_has_nothing_to_reload() -> void:
	print("-- full magazine: nothing to reload, and that is not a failure of the pistol")
	var world := _new_world()
	var pistol := await _new_pistol(world, _data, _new_aim_source(world))
	var log := _watch(pistol)
	_check(not pistol.start_reload(), "a full magazine refuses the reload")
	_check(log.reload_started == 0, "no reload was announced",
		"(got %d)" % log.reload_started)
	_check(not pistol.is_reloading(), "and the pistol is not reloading")
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE, "the magazine is untouched",
		"(got %d)" % pistol.current_mag())
	_check(pistol.try_fire(), "a round comes out as usual")
	_check(pistol.start_reload(), "and now the reload is accepted")
	world.free()


## The Phase 4 contract, asserted before anything calls it. A half-full magazine
## that survives a trip to the lobby hands the player free rounds every time.
func _test_scene_change_reset() -> void:
	print("-- scene change: the weapon is reset, so a lobby trip costs no rounds")
	var world := _new_world()
	var pistol := await _new_pistol(world, _data, _new_aim_source(world))
	var log := _watch(pistol)

	pistol.try_fire()
	pistol.start_reload()
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
		"precondition: the magazine is partly spent", "(got %d)" % pistol.current_mag())
	_check(pistol.is_reloading(), "precondition: a reload is in progress")

	pistol.reset_for_scene_change()
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE,
		"the magazine is full again after a scene change",
		"(got %d)" % pistol.current_mag())
	_check(not pistol.is_reloading(), "the reload is cancelled")
	_check(pistol.can_fire(), "the pistol can shoot again")
	_check(log.last_magazine() == Vector2i(_EXPECTED_MAGAZINE, _EXPECTED_MAGAZINE),
		"the reset is announced, so a HUD is not left showing a stale count",
		"(got %s)" % str(log.magazine))
	_check(log.reload_finished == 0,
		"a cancelled reload never claims to have finished", "(got %d)" % log.reload_finished)
	# The rate limit is cleared too: a scene change is not a continuation of the
	# previous one's shot.
	_check(pistol.try_fire(), "the first shot of the new scene is not rate limited")
	world.free()


## A resource edited into a degenerate state must be refused, not obeyed.
func _test_invalid_data_blocks_firing() -> void:
	print("-- degenerate data: a zero magazine size blocks firing instead of dividing by zero")
	var world := _new_world()
	var aim := _new_aim_source(world)

	var stock := await _new_pistol(world, _data, aim)
	_check(stock.can_fire(),
		"precondition: the shipped data lets the pistol fire, so the refusals below mean something")

	var zero_mag := WeaponData.new()
	zero_mag.magazine_size = 0
	var pistol := await _new_pistol(world, zero_mag, aim)
	var log := _watch(pistol)
	_check(pistol.current_mag() == 0,
		"a zero-capacity magazine starts empty", "(got %d)" % pistol.current_mag())
	_check(not pistol.can_fire(), "can_fire() is false for a zero magazine size")
	_check(not pistol.try_fire(), "try_fire() refuses to shoot with a zero magazine size")
	_check(not pistol.start_reload(), "and there is nothing to reload either")
	_check(log.fired == 0, "nothing fired", "(got %d)" % log.fired)
	_check(pistol.current_mag() == 0, "and no round was invented", "(got %d)" % pistol.current_mag())

	var zero_rate := WeaponData.new()
	zero_rate.rounds_per_minute = 0.0
	var rate_pistol := await _new_pistol(world, zero_rate, aim)
	_check(not rate_pistol.can_fire(),
		"a zero fire rate is refused rather than dividing by zero")
	world.free()


## The order inside try_fire() is load-bearing: check, then instantiate, then
## decrement. A pistol that decremented first would eat a round for a shot that
## never happened -- and pistol.tscn without a projectile scene, or one pointing
## at a scene whose root cannot be launched, is exactly that situation.
func _test_missing_projectile_scene_keeps_the_round() -> void:
	print("-- failed instantiation: the round survives the shot that never happened")
	var world := _new_world()
	var pistol := await _new_pistol(world, _data, _new_aim_source(world), false)
	var log := _watch(pistol)
	_check(pistol.projectile_scene == null,
		"precondition: this pistol has no projectile scene at all")
	_check(pistol.can_fire(), "precondition: it is otherwise ready to shoot")
	_check(not pistol.try_fire(), "a pistol with no projectile scene cannot shoot")
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE,
		"the round is still in the magazine: instantiate first, decrement after",
		"(got %d of %d)" % [pistol.current_mag(), _EXPECTED_MAGAZINE])
	_check(log.fired == 0, "a shot that never happened announced nothing",
		"(got %d)" % log.fired)
	_check(log.magazine.is_empty(), "and the magazine never changed",
		"(got %s)" % str(log.magazine))
	world.free()