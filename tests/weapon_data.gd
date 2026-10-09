extends SceneTree

## Weapon data harness for VibeFPS.
##
## Reads res://data/weapons/pistol.tres through load() and asks it the same
## questions the weapon script will ask in Phase 1 Task 3: what are the
## numbers, what does the derived fire interval come out as, and does the
## resource consider itself usable. Nothing is instantiated as a scene node --
## this is data, and a data check that had to build a world in order to read a
## number would be testing the world instead.
##
## Every assertion below names the edit that turns it red. The negative halves
## are asserted too, not only the green ones: seconds_between_shots() is asked
## to follow a *changed* fire rate, and is_valid() is asked to reject each
## degenerate value in turn. Without those, a method hardcoded to return 0.4
## and true would sail through a check that only ever saw the good resource.
##
## Run: godot --headless --path . --script res://tests/weapon_data.gd
##      .\tools\run_checks.ps1 weapon_data

const _PISTOL_PATH := "res://data/weapons/pistol.tres"

## The fire interval is a division, so it is compared with a tolerance rather
## than for exact equality.
const _EPS := 0.0001

## The design fixes the pistol at 150 rounds per minute with 18 rounds in the
## magazine. 150 rpm is one shot every 0.4 s, so a full magazine is 7.2 s of
## continuous fire. The assertion recomputes that from the resource's own
## fields instead of reading a hardcoded constant, so a future balance edit
## that changes the fire rate or the magazine size alone cannot pass unnoticed.
const _EXPECTED_BURST_SECONDS := 7.2

var _failures: PackedStringArray = []
var _checks := 0


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


func _close(got: float, want: float) -> bool:
	return absf(got - want) <= _EPS


## Builds a throwaway WeaponData with one field overwritten, so the derived
## methods can be asked a question the shipped resource never asks.
func _probe(overrides: Dictionary) -> WeaponData:
	var probe := WeaponData.new()
	for key in overrides:
		probe.set(key, overrides[key])
	return probe


## Must come back true only when is_valid() really rejects the degenerate
## value, which is what makes "is_valid() is true" on pistol.tres meaningful.
func _is_valid_rejects(overrides: Dictionary) -> bool:
	return not _probe(overrides).is_valid()


func _finish() -> void:
	print("=== RESULT: %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)


## Ends the run on a precondition the rest of the check cannot be evaluated
## against. Without this the field assertions below would dereference a null
## resource and the runner would report a crash instead of a named failure.
func _bail(reason: String) -> void:
	print("FATAL: %s" % reason)
	_finish()
	quit(1)


func _initialize() -> void:
	print("=== weapon data ===")

	print("-- %s must load as a WeaponData" % _PISTOL_PATH)
	var res: Resource = load(_PISTOL_PATH)
	if res == null:
		_bail("cannot load %s" % _PISTOL_PATH)
		return
	var script_res := res.get_script() as Script
	_check(res is WeaponData, "pistol.tres is a WeaponData",
		"(script=%s)" % ("none" if script_res == null else script_res.resource_path))
	var data := res as WeaponData
	if data == null:
		_bail("pistol.tres is not a WeaponData, the field checks below would be meaningless")
		return

	print("-- the values the design fixes for the pistol")
	# Each of these turns red on a single field edit in pistol.tres.
	_check(data.display_name == "Pistol", "display_name is \"Pistol\"",
		"(got \"%s\")" % data.display_name)
	_check(data.damage == 30.0, "damage is 30.0", "(got %.4f)" % data.damage)
	_check(data.rounds_per_minute == 150.0, "rounds_per_minute is 150.0",
		"(got %.4f)" % data.rounds_per_minute)
	_check(data.magazine_size == 18, "magazine_size is 18",
		"(got %d)" % data.magazine_size)
	_check(data.reload_time == 1.2, "reload_time is 1.2", "(got %.4f)" % data.reload_time)
	_check(data.projectile_speed == 70.0, "projectile_speed is 70.0",
		"(got %.4f)" % data.projectile_speed)
	_check(data.projectile_radius == 0.08, "projectile_radius is 0.08",
		"(got %.4f)" % data.projectile_radius)
	_check(data.projectile_lifetime == 4.0, "projectile_lifetime is 4.0",
		"(got %.4f)" % data.projectile_lifetime)
	# Not written in pistol.tres, so this pins the script's own default: it is
	# what Task 5 feeds into the projectile material, and nothing else in the
	# project would notice a change to it.
	_check(data.projectile_color == Color(0.15, 0.15, 0.15),
		"projectile_color is the script default Color(0.15, 0.15, 0.15)",
		"(got %s)" % data.projectile_color)

	# PROJECT.md 9.8 makes this a game rule rather than a technical detail: a
	# hitscan weapon would remove the dodge window the bullet travel creates.
	_check(data.projectile_speed > 0.0 and is_finite(data.projectile_speed),
		"projectile speed is finite and non-zero, so the bullet travels and can be dodged",
		"(%.1f m/s; a pistol round covers 15 m in %.3f s)" % [
			data.projectile_speed, 15.0 / data.projectile_speed])

	print("-- derived fire interval")
	_check(_close(data.seconds_between_shots(), 0.4),
		"seconds_between_shots() is 0.4 s at 150 rpm", "(got %.6f, tol %.4f)" % [
			data.seconds_between_shots(), _EPS])
	# The 0.4 above could also be satisfied by a method that always returns
	# 0.4. Halving the fire rate must halve the interval, which a constant
	# cannot do.
	_check(_close(_probe({"rounds_per_minute": 60.0}).seconds_between_shots(), 1.0),
		"seconds_between_shots() follows the fire rate, it is not a constant",
		"(60 rpm -> %.6f s)" % _probe({"rounds_per_minute": 60.0}).seconds_between_shots())

	print("-- is_valid() can answer false, so is_valid() == true means something")
	_check(data.is_valid(), "pistol.tres reports itself valid")
	# One assertion per term of is_valid()'s condition: dropping any single
	# term from the implementation turns exactly this one red.
	_check(_is_valid_rejects({"rounds_per_minute": 0.0}),
		"a zero fire rate is rejected")
	_check(_is_valid_rejects({"magazine_size": 0}),
		"an empty magazine capacity is rejected")
	_check(_is_valid_rejects({"reload_time": 0.0}),
		"a zero reload time is rejected")
	_check(_is_valid_rejects({"damage": 0.0}),
		"zero damage is rejected")
	_check(_is_valid_rejects({"projectile_speed": 0.0}),
		"a zero projectile speed is rejected")

	print("-- burst length invariant")
	# magazine_size * seconds_between_shots(): 18 rounds at one shot per 0.4 s.
	var burst := float(data.magazine_size) * data.seconds_between_shots()
	_check(_close(burst, _EXPECTED_BURST_SECONDS),
		"a full magazine is %.1f s of continuous fire" % _EXPECTED_BURST_SECONDS,
		"(computed %.6f from magazine_size=%d and %.6f s per shot)" % [
			burst, data.magazine_size, data.seconds_between_shots()])

	_finish()
	quit(1 if _failures.size() > 0 else 0)
