extends SceneTree

## Auto-weapon harness for VibeFPS: the second weapon (an automatic pistol) is
## the same pistol.gd behaviour driven by a different WeaponData, so this check
## pins the parts that differ -- the data itself, the scene wiring, the shot
## through the real projectile.tscn -- and the projectile visual that has to
## follow the weapon data (radius 0.06, yellow trail) instead of the pistol's
## defaults.
##
## The pattern is borrowed from tests/weapon.gd: a _PistolProbe answers the
## input gate with an explicit mouse mode (headless cannot capture the cursor),
## the shipped auto.tscn geometry is grafted onto the probe, and waits are
## bounded in wall-clock seconds because the weapon's rate limit is the thing
## under test and lives in seconds, not frames.
##
## Run: godot --headless --path . --script res://tests/auto_weapon.gd
##      .\tools\run_checks.ps1 auto_weapon

## Stand-in for pistol.gd, used only by this harness.
class _PistolProbe extends "res://weapons/pistol/pistol.gd":
	## Mouse mode the gate is evaluated against instead of Input.mouse_mode.
	var gate_mouse_mode: int = Input.MOUSE_MODE_CAPTURED

	func _mouse_mode_for_play_input() -> int:
		return gate_mouse_mode


## Records what the weapon announces. fired counts shots -- one signal, one
## round, which is what "the auto really shoots" reduces to here; the full
## magazine bookkeeping is already pinned for pistol.gd by tests/weapon.gd.
class _Log extends RefCounted:
	var fired: int = 0

	func _on_fired() -> void:
		fired += 1


const _AUTO_DATA_PATH := "res://data/weapons/auto.tres"
const _AUTO_SCENE_PATH := "res://weapons/auto/auto.tscn"
## The projectile scene auto.tscn points at, loaded rather than rebuilt: the
## trail under data-driven test is the trail the shipped scene really carries.
const _PROJECTILE_SCENE_PATH := "res://weapons/projectile/projectile.tscn"

## The values the design fixes for the auto. Restated here so a balance edit to
## auto.tres cannot silently turn the harness into a check of numbers it does
## not claim to verify.
const _EXPECTED_MAGAZINE := 36
const _EXPECTED_INTERVAL := 0.2
const _EXPECTED_DAMAGE := 15.0
const _EXPECTED_SPEED := 70.0
const _EXPECTED_RADIUS := 0.06
const _EXPECTED_PRICE := 300
const _EXPECTED_COLOR := Color(0.95, 0.75, 0.15)

## Ceiling for every timed wait; a broken weapon leaves it far behind, a hung
## one cannot turn the check into a runner timeout.
const _WAIT_CAP_SECONDS := 15.0
## How far a measured timer may overshoot the nominal interval.
const _TIMER_TOLERANCE := 0.35
## Float slack on the short side of a timer.
const _TIMER_EPSILON := 0.05

var _failures: PackedStringArray = []
var _checks := 0
var _data: WeaponData
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


func _bail(reason: String) -> void:
	print("FATAL: %s" % reason)
	_finish()
	quit(1)


func _close(a: float, b: float) -> bool:
	return is_equal_approx(a, b)


func _close_color(a: Color, b: Color) -> bool:
	return is_equal_approx(a.r, b.r) and is_equal_approx(a.g, b.g) \
		and is_equal_approx(a.b, b.b)


# --------------------------------------------------------------------------
# waiting
# --------------------------------------------------------------------------

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


## Releases the fire action and lets real frames go by, so the arming latch has
## seen the button up before the next press is read as input.
func _settle_fire_released() -> void:
	Input.action_release("fire")
	await process_frame
	await process_frame


# --------------------------------------------------------------------------
# world builders
# --------------------------------------------------------------------------

func _new_world() -> Node3D:
	var world := Node3D.new()
	world.name = "World"
	root.add_child(world)
	return world


## A current camera in the pose a player's head hangs at, standing in for
## player.tscn. auto.tscn leaves fire_rate_source empty on purpose, so this is
## the node the weapon actually aims from in the game.
func _new_eye(world: Node3D) -> Camera3D:
	var eye := Camera3D.new()
	eye.name = "Eye"
	eye.current = true
	eye.position = Vector3(0.0, 1.7, 0.0)
	world.add_child(eye)
	return eye


## The shipped auto geometry grafted onto a probe. Children are MOVED over, so
## the Muzzle marker under test is the one auto.tscn really ships; the probe is
## what answers the gate (see the class), and data plus projectile scene are
## set before the node enters the tree because _ready() fills the magazine from
## them.
func _new_pistol_from_scene(world: Node3D, scene: PackedScene, data: WeaponData) -> _PistolProbe:
	var geometry := scene.instantiate()
	var pistol := _PistolProbe.new()
	pistol.name = "Auto"
	pistol.data = data
	pistol.projectile_scene = _projectile_scene
	for child in geometry.get_children():
		geometry.remove_child(child)
		child.owner = null
		pistol.add_child(child)
	geometry.free()
	world.add_child(pistol)
	for i in 8:
		await process_frame
		if pistol.is_node_ready():
			return pistol
	print("FATAL: the auto never became ready")
	return pistol


func _watch(pistol: _PistolProbe) -> _Log:
	var log := _Log.new()
	pistol.fired.connect(log._on_fired)
	return log


## The projectiles under `parent`. The weapon parents every shot to its aim
## source (here: the camera), so this is how live bullets are found.
func _live_projectiles(parent: Node3D) -> Array[Projectile]:
	var out: Array[Projectile] = []
	for child in parent.get_children():
		if child is Projectile:
			out.append(child as Projectile)
	return out


# --------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------

func _initialize() -> void:
	print("=== VibeFPS auto weapon test ===")
	_data = load(_AUTO_DATA_PATH) as WeaponData
	if _data == null:
		_bail("cannot load %s as a WeaponData" % _AUTO_DATA_PATH)
		return
	_projectile_scene = load(_PROJECTILE_SCENE_PATH) as PackedScene
	if _projectile_scene == null:
		_bail("cannot load %s" % _PROJECTILE_SCENE_PATH)
		return

	_test_data_contract()
	_test_scene_contract()
	await _test_scene_shot()
	await _test_fire_interval()

	_finish()
	quit(1 if _failures.size() > 0 else 0)


# --------------------------------------------------------------------------
# checks
# --------------------------------------------------------------------------

## The data the auto is defined by. A balance edit to auto.tres has to turn a
## check red, never a scene or a hardcode.
func _test_data_contract() -> void:
	print("-- data: auto.tres is the auto the design fixes")
	_check(_data.is_valid(), "auto.tres reports itself valid")
	_check(_data.display_name == "Auto", "display_name is \"Auto\"",
		"(got \"%s\")" % _data.display_name)
	_check(_close(_data.seconds_between_shots(), _EXPECTED_INTERVAL),
		"seconds_between_shots() is %.1f s at 300 rpm" % _EXPECTED_INTERVAL,
		"(got %.6f)" % _data.seconds_between_shots())
	_check(_data.magazine_size == _EXPECTED_MAGAZINE,
		"magazine_size is %d" % _EXPECTED_MAGAZINE,
		"(got %d)" % _data.magazine_size)
	_check(_close(_data.damage, _EXPECTED_DAMAGE),
		"damage is %.1f" % _EXPECTED_DAMAGE, "(got %.4f)" % _data.damage)
	_check(_data.price == _EXPECTED_PRICE,
		"price is %d" % _EXPECTED_PRICE, "(got %d)" % _data.price)
	_check(_close(_data.projectile_speed, _EXPECTED_SPEED),
		"projectile_speed is %.1f m/s" % _EXPECTED_SPEED,
		"(got %.4f)" % _data.projectile_speed)
	_check(_close(_data.projectile_radius, _EXPECTED_RADIUS),
		"projectile_radius is %.2f" % _EXPECTED_RADIUS,
		"(got %.4f)" % _data.projectile_radius)
	_check(_close_color(_data.projectile_color, _EXPECTED_COLOR),
		"projectile_color is the auto's yellow", "(got %s)" % _data.projectile_color)


## The scene wiring: auto.tscn is the auto with a barrel, carrying the auto
## data and the projectile scene, and no fire_rate_source (the weapon falls
## back to the player's camera exactly like the pistol).
func _test_scene_contract() -> void:
	print("-- scene: auto.tscn instantiates and is wired to auto.tres")
	var packed: PackedScene = load(_AUTO_SCENE_PATH)
	_check(packed != null, "auto.tscn is loadable", "(%s)" % _AUTO_SCENE_PATH)
	if packed == null:
		return
	var direct := packed.instantiate()
	_check(direct != null, "auto.tscn instantiates")
	if direct == null:
		return
	_check(direct.get("data") == _data,
		"auto.tscn carries data = auto.tres")
	_check(direct.get("projectile_scene") == _projectile_scene,
		"auto.tscn drives res://weapons/projectile/projectile.tscn")
	_check(direct.get("fire_rate_source") == null,
		"auto.tscn leaves fire_rate_source empty: it aims from the camera")
	var barrel := direct.get_node_or_null("Muzzle") as Node3D
	_check(barrel != null, "auto.tscn carries a Muzzle marker")
	_check(barrel != null and barrel.position.z < -0.1,
		"and it sits in front of the weapon, not inside the grip",
		"(got %s)" % ("no Muzzle" if barrel == null else str(barrel.position)))
	direct.free()


## One real shot through the input path with the scene grafted onto the probe:
## the round leaves the barrel, flies at the auto's speed, and the projectile
## instance carries the data -- speed, damage, and the visual radius/color the
## trail is built from. The trail of the shipped projectile.tscn is checked
## too, because that is the "projectile look from data" contract end to end.
func _test_scene_shot() -> void:
	print("-- shot: one round, aimed by a camera, projectile look from auto.tres")
	var world := _new_world()
	var eye := _new_eye(world)
	var packed: PackedScene = load(_AUTO_SCENE_PATH)
	if packed == null:
		world.free()
		return
	var pistol := await _new_pistol_from_scene(world, packed, _data)
	var log := _watch(pistol)

	var barrel := pistol.get_node_or_null("Muzzle") as Node3D
	_check(barrel != null, "precondition: the grafted scene carries its Muzzle marker")

	await _settle_fire_released()
	Input.action_press("fire")
	var fired := await _await_until(func() -> bool: return log.fired > 0, 5.0)
	Input.action_release("fire")
	_check(fired, "the held fire button produced a shot", "(got %d)" % log.fired)
	_check(log.fired == 1, "exactly one shot came out", "(got %d)" % log.fired)
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
		"the shot cost exactly one round", "(got %d)" % pistol.current_mag())

	var bullets := _live_projectiles(eye)
	_check(bullets.size() == 1, "one projectile was spawned under the camera",
		"(got %d)" % bullets.size())
	if bullets.size() == 1 and barrel != null:
		var bullet := bullets[0]
		# Sample late by design: the shot came through the input path, so the
		# projectile has already flown part of its line by the time the harness
		# sees it. What the start point is, is still decidable: a bullet that
		# left the eye would sit at eye height (~1.7 m), one that left the
		# barrel hangs at the barrel's height (~0 m) on the camera's line.
		_check(bullet.global_position.distance_to(eye.global_position) > 0.5,
			"the projectile is not hanging out of the eye",
			"(%.3f m from the eye)" % bullet.global_position.distance_to(eye.global_position))
		_check(absf(bullet.global_position.y - barrel.global_position.y) < 0.2,
			"it left from the barrel height, not the camera height",
			"(bullet y=%.3f, barrel y=%.3f, eye y=%.3f)" % [
				bullet.global_position.y, barrel.global_position.y, eye.global_position.y])
		_check(_close(bullet.speed, _EXPECTED_SPEED),
			"the projectile takes the auto's speed from the data",
			"(got %.1f m/s)" % bullet.speed)
		_check(_close(bullet.damage, _EXPECTED_DAMAGE),
			"the projectile takes the auto's damage from the data",
			"(got %.1f)" % bullet.damage)
		_check(_close(bullet.radius, _EXPECTED_RADIUS),
			"the projectile carries the auto's radius from the data",
			"(got %.4f)" % bullet.radius)
		_check(_close_color(bullet.color, _data.projectile_color),
			"the projectile carries the auto's color from the data",
			"(got %s, want %s)" % [str(bullet.color), str(_data.projectile_color)])

		var trail := bullet.get_node_or_null("Trail") as MeshInstance3D
		_check(trail != null, "the projectile carries a trail node")
		if trail != null:
			var sphere := trail.mesh as SphereMesh
			_check(sphere != null and _close(sphere.radius, bullet.radius),
				"the trail sphere has the data radius, so the visual follows auto.tres",
				"(got %s)" % ("no SphereMesh" if sphere == null else "%.4f" % sphere.radius))
			var mat := trail.material_override as StandardMaterial3D
			_check(mat != null and _close_color(mat.albedo_color, _data.projectile_color),
				"the trail material carries the data color",
				"(got %s)" % ("no material" if mat == null else str(mat.albedo_color)))

		var start: Vector3 = bullet.global_position
		await _await_until(func() -> bool: return bullet.global_position.distance_to(start) > 0.5, 5.0)
		var moved: Vector3 = bullet.global_position - start
		_check(moved.length() > 0.5,
			"the projectile is flying, so launch() was called on a node in the tree",
			"(moved %.3f m)" % moved.length())
		_check(moved.normalized().dot(-eye.global_transform.basis.z) > 0.99,
			"it leaves along the camera's forward axis",
			"(%.3f m along %.3f m forward)" % [
				moved.length(), moved.normalized().dot(-eye.global_transform.basis.z)])
	world.free()


## The rate limit lives in seconds and comes from the data: 300 rpm is one shot
## every 0.2 s, refused in the same instant and allowed once the interval has
## passed. The interval is measured on the scene-created weapon, so the whole
## chain (auto.tres -> pistol.gd -> actual timing) is under test, not just the
## resource's arithmetic.
func _test_fire_interval() -> void:
	print("-- rate limit: one shot per %.1f s, in seconds not frames" % _EXPECTED_INTERVAL)
	var world := _new_world()
	var packed: PackedScene = load(_AUTO_SCENE_PATH)
	if packed == null:
		world.free()
		return
	var pistol := await _new_pistol_from_scene(world, packed, _data)
	var log := _watch(pistol)

	_check(pistol.try_fire(), "the first shot is allowed")
	_check(not pistol.try_fire(), "a second shot in the same instant is refused")
	_check(log.fired == 1, "only one round left the magazine",
		"(got %d)" % log.fired)

	var start := _now_ms()
	var second := false
	for i in 6000:
		await process_frame
		if pistol.try_fire():
			second = true
			break
	var elapsed := float(_now_ms() - start) / 1000.0
	print("    second shot after %.3f s" % elapsed)
	_check(second, "the next shot is allowed once the interval has passed")
	_check(elapsed >= _EXPECTED_INTERVAL - _TIMER_EPSILON,
		"the second shot waited at least the full interval",
		"(waited %.3f s, want >= %.2f s)" % [elapsed, _EXPECTED_INTERVAL - _TIMER_EPSILON])
	_check(elapsed <= _EXPECTED_INTERVAL + _TIMER_TOLERANCE,
		"and did not wait much longer than the interval",
		"(waited %.3f s, want <= %.2f s)" % [elapsed, _EXPECTED_INTERVAL + _TIMER_TOLERANCE])
	_check(log.fired == 2, "exactly two rounds came out",
		"(got %d)" % log.fired)
	world.free()