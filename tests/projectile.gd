extends SceneTree

## Projectile harness for VibeFPS: the bullet, the hurtbox contract Phase 2
## builds enemies on, and the two rules that make the bullet a bullet -- a
## finite constant speed and exactly one hit.
##
## The world is built in code: a wall on layer 1, hurtboxes on layer 4, the
## projectile on layer 5. Nothing here loads a scene, because no projectile
## scene exists yet (that is Task 5) and a check that waited for one would be a
## check that could not run.
##
## Both scripts under test are reached through `load()` rather than through a
## class_name reference. That is deliberate: a static reference to a class_name
## that does not exist yet kills the whole harness at parse time with
## "identifier not declared in the current scope", which reports nothing about
## which contract is missing. Loading by path reports the missing file by name
## and leaves every other assertion runnable.
##
## Two geometry rules the numbers below depend on, both asserted rather than
## assumed:
##
##   * The project runs 120 physics ticks per second and a bullet flies at
##     40 m/s, so one tick is exactly 1/3 of a metre. Discrete overlap testing
##     samples positions, so a target can only be hit if it is wide enough to
##     contain one of those samples. Every target here is at least 0.5 m wide
##     against a 0.333 m step, which is a guaranteed hit; the sampling envelope
##     check states that margin explicitly, because raising the bullet speed
##     far enough would otherwise silently turn every hit check into a coin
##     flip.
##   * The hit must happen strictly before the wall in the same line of fire,
##     otherwise "the shot died" and "the shot was absorbed by the wall" are
##     the same observation and neither proves anything.
##
## Run: godot --headless --path . --script res://tests/projectile.gd
##      .\tools\run_checks.ps1 projectile

## The scripts under test. Loaded by path; see the header.
const _HURTBOX_SCRIPT_PATH := "res://scripts/hurtbox.gd"
const _PROJECTILE_SCRIPT_PATH := "res://scripts/projectile.gd"

## Collision layers, as the bit values Godot stores them by. 1 << (n - 1).
const _LAYER_WORLD := 1 << 0
const _LAYER_PLAYER_BODY := 1 << 1
const _LAYER_ENEMY_HURTBOX := 1 << 3
const _LAYER_PROJECTILE := 1 << 4
const _LAYER_PLAYER_HURTBOX := 1 << 6

const _TICKS_PER_SECOND := 120
## One physics tick of flight, in metres. The sampling envelope below is
## measured in these.
const _STEP := 1.0 / float(_TICKS_PER_SECOND)

const _SPEED := 40.0
const _DAMAGE := 30.0

const _EPS := 0.001

## WeaponData.projectile_radius. The projectile is a small ball; a scene (Task
## 5) is expected to give it a shape of the same size, and the harness gives
## it the equivalent one so the script can be tested before that scene exists.
const _BULLET_RADIUS := 0.08
## Every target below is wider than one tick (0.333 m), which is what makes a
## discrete hit test reliable. See the sampling envelope check.
const _TARGET_RADIUS := 0.5
## World geometry, in metres along +X. The shot is launched from the origin.
const _WALL_FRONT := 20.0
const _NEAR_TARGET_X := 6.0
const _FAR_TARGET_X := 12.0
## A target flush against the wall, used for the same-frame contact check.
const _FLUSH_TARGET_X := 19.5
const _FLUSH_WALL_FRONT := 19.05

## Records every damage_taken an individual hurtbox receives.
class _DamageLog extends RefCounted:
	var amounts: Array[float] = []

	func _on_damage(amount: float) -> void:
		amounts.append(amount)

	func count() -> int:
		return amounts.size()


var _failures: PackedStringArray = []
var _checks := 0
## Loaded once in _initialize; every scenario builds its nodes from these, so a
## missing script fails the whole check by name instead of dereferencing null.
var _hurtbox_script: Script
var _projectile_script: Script
var _hurtbox_id := 0


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


func _initialize() -> void:
	print("=== projectile ===")

	_hurtbox_script = load(_HURTBOX_SCRIPT_PATH) as Script
	_projectile_script = load(_PROJECTILE_SCRIPT_PATH) as Script
	if _hurtbox_script == null:
		_bail("cannot load %s" % _HURTBOX_SCRIPT_PATH)
		return
	if _projectile_script == null:
		_bail("cannot load %s" % _PROJECTILE_SCRIPT_PATH)
		return

	await _test_script_contracts()
	await _test_layers_and_masks()
	await _test_constant_speed_flight()
	await _test_direction_is_normalised_once()
	await _test_hit_hurtbox()
	await _test_hit_world_geometry()
	await _test_only_one_hit()
	await _test_lifetime_expiry()
	await _test_damage_multiplier()
	await _test_ignores_plain_areas()
	await _test_ignores_player_hurtbox()
	await _test_two_contacts_in_one_frame()
	await _test_trail_fades()
	_test_source_contract()

	_finish()
	quit(1 if _failures.size() > 0 else 0)


# --------------------------------------------------------------------------
# world builders
# --------------------------------------------------------------------------

func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame


## Node names must be unique inside one parent, and every scenario puts its
## hurtboxes under the same world node.
func _next_hurtbox_id() -> int:
	_hurtbox_id += 1
	return _hurtbox_id


func _new_world() -> Node3D:
	var world := Node3D.new()
	world.name = "World"
	root.add_child(world)
	return world


func _add_sphere(parent: CollisionObject3D, radius: float) -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	parent.add_child(shape)


## A wall on layer 1 (world geometry). `front_x` is the face the bullet meets,
## so the numbers in this harness read as "how far the shot has to fly".
func _add_wall(world: Node3D, front_x: float) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = "Wall"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 6.0, 6.0)
	shape.shape = box
	wall.add_child(shape)
	wall.collision_layer = _LAYER_WORLD
	wall.collision_mask = 0
	wall.position = Vector3(front_x + 0.5, 0.0, 0.0)
	world.add_child(wall)
	return wall


func _add_hurtbox(world: Node3D, pos: Vector3, radius: float, multiplier := 1.0):
	var hurtbox = _hurtbox_script.new()
	# Unique names: a scenario can hold several hurtboxes, and a failure message
	# that reads "@Area3D@31" instead of a name tells nobody anything.
	hurtbox.name = "Hurtbox%d" % _next_hurtbox_id()
	_add_sphere(hurtbox, radius)
	hurtbox.damage_multiplier = multiplier
	hurtbox.position = pos
	world.add_child(hurtbox)
	return hurtbox


func _add_projectile(world: Node3D, pos: Vector3, speed := _SPEED, dmg := _DAMAGE, life := 3.0):
	var bullet = _projectile_script.new()
	bullet.name = "Projectile"
	_add_sphere(bullet, _BULLET_RADIUS)
	bullet.speed = speed
	bullet.damage = dmg
	bullet.lifetime = life
	bullet.position = pos
	world.add_child(bullet)
	return bullet


## Subscribes to one hurtbox and returns its damage log.
func _watch(hurtbox) -> _DamageLog:
	var log := _DamageLog.new()
	hurtbox.damage_taken.connect(log._on_damage)
	return log


## Ticks until the node is actually gone, or -1 if it outlived the cap. A
## node that was queue_free'd still exists for the rest of the frame it died in,
## so the returned count is the death tick rounded up to the next one.
func _frames_until_free(node, cap: int) -> int:
	for i in cap:
		if not is_instance_valid(node):
			return i
		await physics_frame
	return -1


# --------------------------------------------------------------------------
# checks
# --------------------------------------------------------------------------

## The contracts Task 3 and Phase 2 will call by name. A renamed class or a
## renamed method is a silent break for them, and this is the only place that
## can notice.
func _test_script_contracts() -> void:
	print("-- contracts: class names, types, methods and signals")
	_check(_hurtbox_script.get_global_name() == "Hurtbox",
		"hurtbox.gd declares class_name Hurtbox",
		"(got \"%s\")" % _hurtbox_script.get_global_name())
	_check(_projectile_script.get_global_name() == "Projectile",
		"projectile.gd declares class_name Projectile",
		"(got \"%s\")" % _projectile_script.get_global_name())

	var hurtbox = _hurtbox_script.new()
	var bullet = _projectile_script.new()
	_check(hurtbox is Area3D, "Hurtbox is an Area3D", "(got %s)" % _hurtbox_script.get_instance_base_type())
	_check(bullet is Area3D, "Projectile is an Area3D", "(got %s)" % _projectile_script.get_instance_base_type())
	_check(hurtbox.has_method("apply_damage"),
		"Hurtbox exposes apply_damage(amount), the entry point for the projectile")
	_check(hurtbox.has_signal("damage_taken"),
		"Hurtbox exposes damage_taken(amount), the signal an enemy will listen to")
	_check(bullet.has_method("launch"),
		"Projectile exposes launch(direction)")
	_check(bullet.has_signal("hit_something"),
		"Projectile exposes hit_something(target), the diagnostic a test can read")

	# Exports are read by weapon_data.gd-driven scenes and by Task 3.
	var defaults := {"damage_multiplier": 1.0}
	_check(is_equal_approx(float(hurtbox.get("damage_multiplier")),
		float(defaults["damage_multiplier"])),
		"a fresh hurtbox has damage_multiplier 1.0, an ordinary enemy",
		"(got %.3f)" % float(hurtbox.get("damage_multiplier")))
	_check(is_equal_approx(float(bullet.get("speed")), _SPEED)
			and is_equal_approx(float(bullet.get("damage")), _DAMAGE)
			and is_equal_approx(float(bullet.get("lifetime")), 3.0),
		"a fresh projectile defaults to the pistol's 40 m/s, 30 damage, 3 s",
		"(speed=%.1f damage=%.1f lifetime=%.1f)" % [
			float(bullet.get("speed")), float(bullet.get("damage")), float(bullet.get("lifetime"))])
	hurtbox.free()
	bullet.free()


func _test_layers_and_masks() -> void:
	print("-- layers: who sees whom")
	var world := _new_world()
	var hurtbox = _add_hurtbox(world, Vector3(0.0, 0.0, -5.0), _TARGET_RADIUS)
	var bullet = _add_projectile(world, Vector3.ZERO)
	await _physics_frames(2)

	_check(int(hurtbox.collision_layer) == _LAYER_ENEMY_HURTBOX,
		"the hurtbox sits on layer 4 (enemy_hurtbox)", "(got %d)" % int(hurtbox.collision_layer))
	_check(int(hurtbox.collision_mask) == _LAYER_WORLD,
		"the hurtbox mask is layer 1 only, so it cannot catch the player",
		"(got %d)" % int(hurtbox.collision_mask))
	_check(int(bullet.collision_layer) == _LAYER_PROJECTILE,
		"the projectile sits on layer 5 (projectile)", "(got %d)" % int(bullet.collision_layer))
	_check(int(bullet.collision_mask) == (_LAYER_WORLD | _LAYER_ENEMY_HURTBOX),
		"the projectile mask is 1 | 4: world geometry and hurtboxes",
		"(got %d)" % int(bullet.collision_mask))
	_check(bool(bullet.monitoring),
		"the projectile monitors: it has to be the one that sees hurtboxes")
	_check(not bool(bullet.monitorable),
		"the projectile is not monitorable: it must not show up in other areas' overlaps")
	_check(bool(hurtbox.monitorable),
		"the hurtbox is monitorable, otherwise a monitoring projectile could never see it")
	world.free()


## A bullet that teleports, accelerates, decelerates or coasts would all satisfy
## "it reached the other side". Only a per-tick comparison can tell them apart.
func _test_constant_speed_flight() -> void:
	print("-- flight: constant finite speed along the launch direction")
	var world := _new_world()
	var bullet = _add_projectile(world, Vector3.ZERO)
	await _physics_frames(2)

	var start: Vector3 = bullet.global_position
	bullet.launch(Vector3(1.0, 0.0, 0.0))
	_check(bullet.global_position.is_equal_approx(start),
		"launch() sets a direction without moving the node",
		"(moved %.4f m)" % bullet.global_position.distance_to(start))

	var ticks := 60
	var worst := 0.0
	var slowest := INF
	var previous: Vector3 = bullet.global_position
	var start_position: Vector3 = start
	var y_drift := 0.0
	var z_drift := 0.0
	## The tick on which the bullet first passed the halfway mark. A bullet that
	## teleported to the far end would cross it on the first tick, which is what
	## makes this a claim about time and not just about distance.
	var crossing_tick := -1
	for i in ticks:
		await physics_frame
		var current: Vector3 = bullet.global_position
		var step := current - previous
		worst = maxf(worst, absf(step.length() - _SPEED * _STEP))
		slowest = minf(slowest, step.length())
		y_drift = maxf(y_drift, absf(current.y))
		z_drift = maxf(z_drift, absf(current.z))
		if crossing_tick < 0 and current.x - start_position.x >= 10.0:
			crossing_tick = i + 1
		previous = current

	var travelled: float = (previous - start).length()
	_check(worst <= _EPS,
		"every single tick advances exactly speed * delta, so nothing accelerates or coasts",
		"(worst tick error %.6f m over %d ticks, tol %.4f)" % [worst, ticks, _EPS])
	_check(slowest > 0.0,
		"no tick leaves the bullet standing still", "(slowest tick %.6f m)" % slowest)
	_check(is_equal_approx(travelled, _SPEED * _STEP * float(ticks)),
		"after %d ticks the bullet covered speed * t" % ticks,
		"(%.4f m over %.3f s at %.1f m/s)" % [travelled, _STEP * float(ticks), _SPEED])
	_check(y_drift <= _EPS and z_drift <= _EPS,
		"the path is straight: the bullet dropped and drifted by nothing",
		"(drift y=%.6f z=%.6f)" % [y_drift, z_drift])
	# The dodge window, measured rather than declared: half of 20 m takes half of
	# 0.5 s. A hitscan bullet would cross the same distance on tick 1.
	var expected_crossing := int(round(10.0 / (_SPEED * _STEP)))
	_check(absf(float(crossing_tick) - float(expected_crossing)) <= 1.0,
		"the bullet needs about %d ticks to cover the first 10 m, so it can be dodged" % expected_crossing,
		"(crossed on tick %d, expected %d; tol one tick, because 30 steps of 1/3 m " % [
			crossing_tick, expected_crossing] + "land a float hair under 10.0)")
	world.free()


## A direction that was used unnormalised, and a launch with a vertical
## component, between them catch both "forgot to normalise" and "gravity pulls
## the bullet off the line".
func _test_direction_is_normalised_once() -> void:
	print("-- direction: normalised once at launch, then held")
	var world := _new_world()
	var sloppy = _add_projectile(world, Vector3.ZERO)
	var steady = _add_projectile(world, Vector3(0.0, 0.0, -4.0))
	await _physics_frames(2)
	sloppy.launch(Vector3(7.0, 0.0, 0.0))
	steady.launch(Vector3(0.0, 30.0, 0.0))

	var ticks := 30
	var sloppy_start: Vector3 = sloppy.global_position
	var steady_start: Vector3 = steady.global_position
	for i in ticks:
		await physics_frame

	var sloppy_travel: Vector3 = sloppy.global_position - sloppy_start
	var steady_travel: Vector3 = steady.global_position - steady_start
	_check(is_equal_approx(sloppy_travel.length(), _SPEED * _STEP * float(ticks)),
		"a direction of length 7 flies at the same speed, not at 7x it",
		"(%.4f m, expected %.4f m)" % [
			sloppy_travel.length(), _SPEED * _STEP * float(ticks)])
	_check(sloppy_travel.is_equal_approx(Vector3(_SPEED * _STEP * float(ticks), 0.0, 0.0)),
		"an unnormalised +X direction still flies along +X",
		"(moved %s)" % sloppy_travel)
	_check(steady_travel.is_equal_approx(Vector3(0.0, _SPEED * _STEP * float(ticks), 0.0)),
		"a bullet launched upward climbs in a straight line: no gravity, no drift",
		"(moved %s)" % steady_travel)
	world.free()


func _test_hit_hurtbox() -> void:
	print("-- hit: a hurtbox takes the damage once and the shot dies there")
	var world := _new_world()
	_add_wall(world, _WALL_FRONT)
	var target = _add_hurtbox(world, Vector3(_FAR_TARGET_X, 0.0, 0.0), _TARGET_RADIUS)
	var log := _watch(target)
	var hits: Array[Node] = []
	var bullet = _add_projectile(world, Vector3.ZERO)
	bullet.hit_something.connect(hits.append)
	await _physics_frames(2)

	bullet.launch(Vector3.RIGHT)
	var ticks := await _frames_until_free(bullet, 400)

	_check(log.count() == 1, "damage_taken arrived exactly once", "(got %d: %s)" % [
		log.count(), str(log.amounts)])
	_check(log.count() == 1 and is_equal_approx(log.amounts[0], _DAMAGE),
		"the damage that arrived is the projectile's damage",
		"(got %s)" % str(log.amounts))
	_check(hits.size() == 1, "hit_something fired once", "(got %d)" % hits.size())
	_check(hits.size() == 1 and hits[0] == target,
		"hit_something names the hurtbox that was hit",
		"(got %s)" % ("none" if hits.is_empty() else str(hits[0].name)))
	# The wall is 20 m away and the target 12 m: a shot that "died somewhere" is
	# only meaningful if it died at the target.
	_check(ticks > 0 and ticks < 50,
		"the shot died at the target, well short of the wall",
		"(gone after %d ticks; the wall is at %.0f m = %d ticks)" % [
			ticks, _WALL_FRONT, int(_WALL_FRONT / (_SPEED * _STEP))])
	world.free()


## The half of the hit contract that carries no damage: world geometry stops the
## bullet. A projectile that ignored walls would pass through them and keep
## flying, so this is checked with a hurtbox parked off the line of fire that
## the bullet must NOT reach.
func _test_hit_world_geometry() -> void:
	print("-- world geometry: the wall stops the shot and no damage is dealt")
	var world := _new_world()
	var wall = _add_wall(world, _WALL_FRONT)
	var bystander = _add_hurtbox(world, Vector3(-5.0, 0.0, 0.0), _TARGET_RADIUS)
	var log := _watch(bystander)
	var hits: Array[Node] = []
	var bullet = _add_projectile(world, Vector3.ZERO)
	bullet.hit_something.connect(hits.append)
	await _physics_frames(2)

	bullet.launch(Vector3.RIGHT)
	var ticks := await _frames_until_free(bullet, 400)

	_check(ticks > 0, "the bullet hit the wall and was removed from the scene",
		"(gone after %d ticks)" % ticks)
	_check(log.count() == 0, "a wall deals no damage, and nothing behind it was touched",
		"(got %d)" % log.count())
	_check(hits.size() == 1, "hit_something fired once for the wall", "(got %d)" % hits.size())
	_check(hits.size() == 1 and hits[0] == wall,
		"hit_something names the body, not a hurtbox",
		"(got %s)" % ("none" if hits.is_empty() else str(hits[0].name)))
	# Lifetime is 3 s = 360 ticks. Dying well before that separates "stopped by
	# the wall" from "ran out of time".
	_check(ticks > 0 and ticks < 180,
		"the bullet was stopped by the wall, long before its lifetime ran out",
		"(gone after %d ticks, lifetime is 360)" % ticks)
	world.free()


## The assertion the "die on the first hit" rule exists for: one shot, one
## damage event. A projectile that survives its first hit reaches the second
## target and damages it too, which is a shot that hits two enemies.
func _test_only_one_hit() -> void:
	print("-- only one hit: a bullet that lands on two targets still lands once")
	var world := _new_world()
	_add_wall(world, _WALL_FRONT)
	var near_target = _add_hurtbox(world, Vector3(_NEAR_TARGET_X, 0.0, 0.0), _TARGET_RADIUS)
	var far_target = _add_hurtbox(world, Vector3(_FAR_TARGET_X, 0.0, 0.0), _TARGET_RADIUS)
	var near_log := _watch(near_target)
	var far_log := _watch(far_target)
	var hits: Array[Node] = []
	var bullet = _add_projectile(world, Vector3.ZERO)
	bullet.hit_something.connect(hits.append)
	await _physics_frames(2)

	bullet.launch(Vector3.RIGHT)
	var ticks := await _frames_until_free(bullet, 400)

	_check(near_log.count() == 1, "the target in front took one hit",
		"(got %d: %s)" % [near_log.count(), str(near_log.amounts)])
	_check(far_log.count() == 0, "the target behind it took nothing: the bullet died on the first hit",
		"(got %d: %s)" % [far_log.count(), str(far_log.amounts)])
	_check(near_log.count() + far_log.count() == 1,
		"one shot produced exactly one damage event in the whole world",
		"(got %d)" % (near_log.count() + far_log.count()))
	_check(hits.size() == 1, "hit_something fired once, not once per target",
		"(got %d)" % hits.size())
	_check(ticks > 0 and ticks < 45,
		"the shot ended at the near target, not after passing both",
		"(gone after %d ticks; the far target is at %.0f m)" % [ticks, _FAR_TARGET_X])
	world.free()


func _test_lifetime_expiry() -> void:
	print("-- lifetime: a bullet that hits nothing still dies")
	var world := _new_world()
	var life := 0.25
	var bullet = _add_projectile(world, Vector3.ZERO, _SPEED, _DAMAGE, life)
	await _physics_frames(2)
	bullet.launch(Vector3.RIGHT)

	# Half the lifetime is 15 ticks; the bullet must still be there. The loop
	# below counts from the launch, so the offset is added back into the total.
	var elapsed := 0
	var mid_alive := false
	var mid_position := Vector3.ZERO
	var ticks := -1
	for i in 240:
		if not is_instance_valid(bullet):
			ticks = elapsed
			break
		await physics_frame
		elapsed += 1
		if elapsed == 15:
			mid_alive = is_instance_valid(bullet)
			mid_position = bullet.global_position

	_check(mid_alive, "the bullet is still flying halfway through its lifetime")
	_check(mid_position.x > 0.0, "it has actually been travelling",
		"(x=%.3f m after 15 ticks)" % mid_position.x)

	var expected := int(round(life * float(_TICKS_PER_SECOND)))
	_check(ticks >= 0, "a bullet that hits nothing expires instead of leaking forever",
		"(gone after %d ticks, expected about %d)" % [ticks, expected])
	_check(ticks >= expected - 1 and ticks <= expected + 2,
		"it expires after lifetime, not before",
		"(gone after %d ticks, lifetime %.2f s = %d ticks)" % [ticks, life, expected])
	world.free()


## damage_multiplier is the lever Phase 2 will use for a boss weak spot, so its
## contract has to be right now, while nothing reads it yet.
func _test_damage_multiplier() -> void:
	print("-- damage_multiplier: the contract Phase 2 builds a weak spot on")
	var world := _new_world()
	var weak_spot = _add_hurtbox(world, Vector3(_FAR_TARGET_X, 0.0, 0.0), _TARGET_RADIUS, 2.0)
	var half = _add_hurtbox(world, Vector3(-5.0, 0.0, 0.0), _TARGET_RADIUS, 0.5)
	var weak_log := _watch(weak_spot)
	var half_log := _watch(half)

	weak_spot.apply_damage(_DAMAGE)
	_check(weak_log.count() == 1 and is_equal_approx(weak_log.amounts[0], 2.0 * _DAMAGE),
		"apply_damage(30) emits 60 at damage_multiplier 2.0",
		"(got %s)" % str(weak_log.amounts))
	half.apply_damage(_DAMAGE)
	_check(half_log.count() == 1 and is_equal_approx(half_log.amounts[0], 0.5 * _DAMAGE),
		"apply_damage(30) emits 15 at damage_multiplier 0.5",
		"(got %s)" % str(half_log.amounts))
	# The hurtbox has no health state: two hits are two signals, not one hit and
	# one silence. If it swallowed damage, an enemy could not count its own hits.
	weak_spot.apply_damage(_DAMAGE)
	weak_spot.apply_damage(_DAMAGE)
	_check(weak_log.count() == 3, "the hurtbox keeps no health state: three hits, three signals",
		"(got %d)" % weak_log.count())
	_check(weak_log.count() == 3 and is_equal_approx(weak_log.amounts[2], 2.0 * _DAMAGE),
		"every signal carries the multiplied amount",
		"(got %s)" % str(weak_log.amounts))

	# And the same thing through a real bullet, because the projectile must hand
	# over its own damage untouched: the multiplier belongs to the target.
	var bullet = _add_projectile(world, Vector3.ZERO)
	await _physics_frames(2)
	bullet.launch(Vector3.RIGHT)
	await _frames_until_free(bullet, 400)
	_check(weak_log.count() == 4 and is_equal_approx(weak_log.amounts[3], 2.0 * _DAMAGE),
		"a bullet into a x2 hurtbox does doubled damage, so the multiplier is not ignored",
		"(got %s)" % str(weak_log.amounts))
	_check(weak_log.count() == 4 and is_equal_approx(weak_log.amounts[3], _DAMAGE * weak_spot.damage_multiplier),
		"the projectile passed its own damage through unchanged; the hurtbox multiplied it",
		"(got %.3f)" % (weak_log.amounts[3] if weak_log.count() == 4 else NAN))
	world.free()


## A trigger volume on the hurtbox layer is not a target. Blindly applying
## damage to every area entered would make level triggers eat bullets, and the
## only way to notice is to put one in the line of fire.
func _test_ignores_plain_areas() -> void:
	print("-- plain areas: same layer, no hurtbox, no damage, no end")
	var world := _new_world()
	_add_wall(world, _WALL_FRONT)
	var decoy := Area3D.new()
	decoy.name = "DecoyArea"
	_add_sphere(decoy, _TARGET_RADIUS)
	decoy.collision_layer = _LAYER_ENEMY_HURTBOX
	decoy.position = Vector3(_NEAR_TARGET_X, 0.0, 0.0)
	world.add_child(decoy)
	var real_target = _add_hurtbox(world, Vector3(_FAR_TARGET_X, 0.0, 0.0), _TARGET_RADIUS)
	var log := _watch(real_target)

	var overlapped: Array[Node] = []
	var hits: Array[Node] = []
	var bullet = _add_projectile(world, Vector3.ZERO)
	bullet.area_entered.connect(overlapped.append)
	bullet.hit_something.connect(hits.append)
	await _physics_frames(2)
	_check(int(decoy.collision_layer) == _LAYER_ENEMY_HURTBOX,
		"precondition: the decoy really is on the hurtbox layer")

	bullet.launch(Vector3.RIGHT)
	await _frames_until_free(bullet, 400)

	# If the bullet never saw the decoy, everything below would pass for the
	# wrong reason.
	_check(overlapped.has(decoy),
		"precondition: the bullet really did enter the plain area",
		"(entered %d areas)" % overlapped.size())
	_check(log.count() == 1, "the hurtbox behind the plain area still took the shot",
		"(got %d)" % log.count())
	_check(hits.size() == 1 and hits[0] == real_target,
		"the plain area is not a target: it neither draws damage nor ends the bullet",
		"(reported %s)" % ("nothing" if hits.is_empty() else str(hits[0].name)))
	world.free()


## Layer 7 is the player's hurtbox. A bullet that swept it up would damage the
## shooter, so the projectile's mask must not contain it -- which is only
## observable by putting a hurtbox on that layer and watching nothing happen.
func _test_ignores_player_hurtbox() -> void:
	print("-- player hurtbox: the shooter is not a target")
	var world := _new_world()
	_add_wall(world, _WALL_FRONT)
	var player_hurtbox = _add_hurtbox(world, Vector3(_NEAR_TARGET_X, 0.0, 0.0), _TARGET_RADIUS)
	# _ready() put it on layer 4; move it to layer 7 the way a player rig would.
	player_hurtbox.collision_layer = _LAYER_PLAYER_HURTBOX
	var enemy_hurtbox = _add_hurtbox(world, Vector3(_FAR_TARGET_X, 0.0, 0.0), _TARGET_RADIUS)
	var player_log := _watch(player_hurtbox)
	var enemy_log := _watch(enemy_hurtbox)
	var hits: Array[Node] = []
	var bullet = _add_projectile(world, Vector3.ZERO)
	bullet.hit_something.connect(hits.append)
	await _physics_frames(2)
	_check(int(player_hurtbox.collision_layer) == _LAYER_PLAYER_HURTBOX,
		"precondition: the first hurtbox really is on layer 7 (player_hurtbox)")

	bullet.launch(Vector3.RIGHT)
	var ticks := await _frames_until_free(bullet, 400)

	_check(player_log.count() == 0, "a hurtbox on the player hurtbox layer takes no damage",
		"(got %d: %s)" % [player_log.count(), str(player_log.amounts)])
	_check(enemy_log.count() == 1, "the bullet flew past the player and still hit the enemy",
		"(got %d)" % enemy_log.count())
	_check(hits.size() == 1 and hits[0] == enemy_hurtbox,
		"only the enemy hurtbox was reported as a hit",
		"(reported %s)" % ("nothing" if hits.is_empty() else str(hits[0].name)))
	_check(ticks > 0 and ticks < 50,
		"the bullet did not end on the player hurtbox",
		"(gone after %d ticks)" % ticks)
	world.free()


## A hurtbox flush against a wall makes the bullet touch an area and a body in
## the same physics frame. Two contacts, one shot: the bullet must report one
## and must never deal damage twice. The premise (both contacts really did land
## in the same frame) is asserted first, otherwise the rest would pass on an
## accident of geometry.
func _test_two_contacts_in_one_frame() -> void:
	print("-- same frame: an area and a body in one tick is still one hit")
	var world := _new_world()
	_add_wall(world, _FLUSH_WALL_FRONT)
	var flush_target = _add_hurtbox(world, Vector3(_FLUSH_TARGET_X, 0.0, 0.0), _TARGET_RADIUS)
	var log := _watch(flush_target)
	var hits: Array[Node] = []
	var area_frame := [-1]
	var body_frame := [-1]
	var bullet = _add_projectile(world, Vector3.ZERO)
	bullet.area_entered.connect(func(_a): area_frame[0] = Engine.get_physics_frames())
	bullet.body_entered.connect(func(_b): body_frame[0] = Engine.get_physics_frames())
	bullet.hit_something.connect(hits.append)
	await _physics_frames(2)

	bullet.launch(Vector3.RIGHT)
	await _frames_until_free(bullet, 400)

	_check(area_frame[0] >= 0, "precondition: the bullet entered the hurtbox",
		"(area_entered on physics frame %d)" % area_frame[0])
	_check(body_frame[0] >= 0, "precondition: the bullet entered the wall",
		"(body_entered on physics frame %d)" % body_frame[0])
	_check(area_frame[0] == body_frame[0],
		"precondition: both contacts landed in the same physics frame",
		"(area on frame %d, body on frame %d)" % [area_frame[0], body_frame[0]])
	_check(hits.size() == 1, "one shot reports one contact even though two happened at once",
		"(got %d)" % hits.size())
	_check(log.count() <= 1, "damage is applied at most once when a frame carries two contacts",
		"(got %d)" % log.count())
	world.free()


## The trail must fade with the projectile's own lifetime rather than being
## driven by something that outlives it.
func _test_trail_fades() -> void:
	print("-- trail: alpha fades with the projectile")
	var world := _new_world()
	var life := 0.4
	var bullet = _add_projectile(world, Vector3.ZERO, _SPEED, _DAMAGE, life)
	await _physics_frames(2)

	var trail = bullet.get_node_or_null("Trail") as MeshInstance3D
	_check(trail != null, "the projectile carries a child MeshInstance3D trail")
	if trail != null:
		var material := trail.material_override as StandardMaterial3D
		_check(material != null, "the trail has a material to fade")
		if material != null:
			_check(material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
				"the trail material is alpha-transparent",
				"(transparency=%d)" % material.transparency)
			var start_alpha := material.albedo_color.a
			_check(start_alpha > 0.0, "the trail starts visible", "(alpha=%.3f)" % start_alpha)
			bullet.launch(Vector3.RIGHT)
			await _physics_frames(20)
			var mid_alpha := material.albedo_color.a
			_check(mid_alpha < start_alpha,
				"the trail fades while the bullet flies",
				"(alpha %.3f -> %.3f after 20 of %d ticks)" % [
					start_alpha, mid_alpha, int(life * float(_TICKS_PER_SECOND))])
			_check(mid_alpha > 0.0, "the fade is gradual, the bullet does not blink out",
				"(alpha=%.3f)" % mid_alpha)
			await _physics_frames(28)
			_check(material.albedo_color.a < mid_alpha,
				"the fade keeps going as the lifetime runs out",
				"(alpha %.3f -> %.3f)" % [mid_alpha, material.albedo_color.a])
	world.free()


## Two rules the brief fixes that no behavioural check can see, because their
## failure shows up in the engine console and nowhere else: a Tween outliving
## the projectile, and monitoring being changed inside the same query flush the
## handler was called from ("can't change this state while flushing queries").
func _test_source_contract() -> void:
	print("-- source contract: the two rules nothing else can observe")
	var source := FileAccess.get_file_as_string(_PROJECTILE_SCRIPT_PATH)
	_check(source != "", "projectile.gd is readable", "(%d bytes)" % source.length())
	# Matched on the API tokens rather than the word: all three ways of making a
	# tween are named, and the comment explaining why there is none does not trip
	# its own check.
	var tween_apis := ["create_tween", "Tween.new", "tween_property("]
	var used := PackedStringArray()
	for api in tween_apis:
		if source.contains(api):
			used.append(api)
	_check(used.is_empty(),
		"projectile.gd never creates a tween: it would keep fading a trail that must die with the bullet",
		"(found %s)" % ("nothing" if used.is_empty() else str(used)))
	_check(source.contains("set_deferred(\"monitoring\""),
		"projectile.gd turns monitoring off through set_deferred, not inside the signal flush")