extends SceneTree

## Progression harness for VibeFPS (Phase 3, lobby track A): points, buying and
## equipping weapons, unlocked locations, scene transitions and the autosave
## round-trip through SaveSystem.
##
## The SaveSystem autoload does not exist yet (a later task wires it into
## project.godot), so the harness builds one by hand at user://progression_test.json
## -- the same isolation tests/save.gd uses, so the production user://save.json is
## never touched. Scene transitions go through an injected fake changer: headless
## has no window to swap scenes in, and the production scenes must not be loaded
## out from under the harness.
##
## The main instance (`_gs`) walks the whole progression. A second, clean-slate
## instance (`_roundtrip`) is used for the disk round-trip check: the brief fixes
## the expected value after award_points(50) at 50 points, which only holds from
## a fresh state. The main instance has already spent down to 10 points by then,
## so reusing it would make the same operation 60 and tie the round-trip check to
## the purchase arithmetic. Isolating it keeps both numbers exactly what the
## brief states.
##
## Run: godot --headless --path . --script res://tests/progression.gd
##      .\tools\run_checks.ps1 progression

## Isolated path every interaction uses. user://save.json is never touched.
const _TMP_PATH := "user://progression_test.json"

var _failures: PackedStringArray = []
var _checks := 0

var _save: SaveSystem
var _gs: GameState
## Clean-slate instance for the autosave round-trip (see the file header).
var _roundtrip: GameState
## Paths handed to the fake scene changer, in call order. No scene is actually
## swapped -- the fake only records what it was asked for.
var _changed_to: PackedStringArray = []


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


## Fake scene changer: records the requested path and does nothing else. A real
## change_scene_to_file would tear down this very SceneTree under the harness.
func _fake_changer(path: String) -> void:
	_changed_to.append(path)


## PackedStringArray vs Array comparison by contents. Godot does not treat the
## two container types as equal, so a plain `owned == ["pistol"]` would be false
## even when the contents match.
func _packed_eq(packed: PackedStringArray, expected: Array) -> bool:
	if packed.size() != expected.size():
		return false
	for i in packed.size():
		if packed[i] != expected[i]:
			return false
	return true


func _cleanup() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_TMP_PATH))


## The engine registers GameState/SaveSystem as project autoloads
## (project.godot, Task 6) and installs nodes of those names under /root even in
## --script mode. Left in place they would shadow the harness's own nodes of the
## same name (Godot renames the later one, so /root/SaveSystem would resolve to
## the autoload writing user://save.json) and hand GameState the real
## change_scene_to_file. Drop them first, so the harness owns /root/GameState and
## /root/SaveSystem exactly as it did before the autoloads existed. Immediate
## free, not queue_free: the names must be free before the nodes below are added.
func _drop_autoloads() -> void:
	for autoload_name in ["GameState", "SaveSystem"]:
		var node := root.get_node_or_null(autoload_name)
		if node != null:
			root.remove_child(node)
			node.free()


func _initialize() -> void:
	print("=== VibeFPS progression test ===")
	_drop_autoloads()
	# Clean sheet: a leftover save from an interrupted run must not be restored
	# into the state under test.
	_cleanup()

	_save = SaveSystem.new()
	# The name is what makes /root/SaveSystem resolve for GameState's autosave.
	_save.name = "SaveSystem"
	_save.save_path = _TMP_PATH
	root.add_child(_save)

	_gs = GameState.new()
	# Injected before add_child, so GameState._ready() must not overwrite it.
	_gs.scene_changer = _fake_changer
	root.add_child(_gs)
	await physics_frame

	_test_initial_state()
	_test_award_points()
	_test_afford()
	_test_buy_weapon()
	_test_buy_owned_again()
	_test_buy_missing()
	_test_equip()
	_test_enter_location()
	_test_return_to_lobby()
	await _test_autosave_roundtrip()

	_save.clear_save()
	_cleanup()

	print("=== RESULT: %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)
	quit(1 if _failures.size() > 0 else 0)


func _test_initial_state() -> void:
	print("-- start: a fresh game starts with the pistol and the range")
	_check(_gs.points == 0, "points start at 0", "(got %d)" % _gs.points)
	_check(_packed_eq(_gs.owned_weapons, ["pistol"]),
		"only the pistol is owned", "(got %s)" % _gs.owned_weapons)
	_check(_gs.equipped_weapon_id == "pistol", "the pistol is equipped",
		"(got \"%s\")" % _gs.equipped_weapon_id)
	_check(_packed_eq(_gs.unlocked_locations, ["range"]),
		"only the range is unlocked", "(got %s)" % _gs.unlocked_locations)


func _test_award_points() -> void:
	print("-- award_points: adds, ignores negatives")
	_gs.award_points(10)
	_check(_gs.points == 10, "award_points(10) adds 10", "(got %d)" % _gs.points)
	_gs.award_points(-5)
	_check(_gs.points == 10, "award_points(-5) is ignored, not deducted",
		"(got %d)" % _gs.points)


func _test_afford() -> void:
	print("-- can_afford: the auto costs 300")
	_check(_gs.weapon_price("auto") == 300,
		"weapon_price(\"auto\") reads 300 from auto.tres",
		"(got %d)" % _gs.weapon_price("auto"))
	_check(not _gs.can_afford(300), "300 points cannot afford the 300 auto")
	_gs.award_points(300)
	_check(_gs.can_afford(300), "after award_points(300) the auto is affordable")


func _test_buy_weapon() -> void:
	print("-- buy_weapon: deducts the price, owns and equips")
	var bought := _gs.buy_weapon("auto")
	_check(bought, "buy_weapon(\"auto\") succeeds when affordable")
	_check(_gs.points == 10, "the 300 price was deducted (310 -> 10)",
		"(got %d)" % _gs.points)
	_check("auto" in _gs.owned_weapons, "\"auto\" is now owned",
		"(got %s)" % _gs.owned_weapons)
	_check(_gs.equipped_weapon_id == "auto", "and it is equipped",
		"(got \"%s\")" % _gs.equipped_weapon_id)


func _test_buy_owned_again() -> void:
	print("-- buy_weapon on an owned weapon: equips only, no second charge")
	var again := _gs.buy_weapon("auto")
	_check(again, "buying an already-owned weapon returns true")
	_check(_gs.points == 10, "and does not charge twice",
		"(got %d)" % _gs.points)
	_check(_gs.owned_weapons.size() == 2,
		"the weapon is not owned twice", "(got %s)" % _gs.owned_weapons)


## A weapon with no .tres reports price 0, but that must not make it buyable as
## a free item: "no resource" is a refusal, fixed here before the implementation
## is read.
func _test_buy_missing() -> void:
	print("-- buy_weapon(\"nope\"): a missing resource is not for sale")
	_check(_gs.weapon_price("nope") == 0,
		"weapon_price(\"nope\") falls back to 0",
		"(got %d)" % _gs.weapon_price("nope"))
	var bought := _gs.buy_weapon("nope")
	_check(not bought, "buy_weapon refuses a weapon with no .tres")
	_check(not ("nope" in _gs.owned_weapons), "and does not add it to the bag",
		"(got %s)" % _gs.owned_weapons)


func _test_equip() -> void:
	print("-- equip_weapon: only owned weapons")
	_check(_gs.equip_weapon("pistol"), "equipping the owned pistol returns true")
	_check(_gs.equipped_weapon_id == "pistol", "the pistol is equipped again",
		"(got \"%s\")" % _gs.equipped_weapon_id)
	_check(_gs.equip_weapon("auto"), "equipping the owned auto returns true")
	_check(_gs.equipped_weapon_id == "auto", "the auto is equipped",
		"(got \"%s\")" % _gs.equipped_weapon_id)
	_check(not _gs.equip_weapon("nope"), "equipping an unowned weapon is refused")
	_check(_gs.equipped_weapon_id == "auto",
		"and does not change the equipped weapon",
		"(got \"%s\")" % _gs.equipped_weapon_id)


func _test_enter_location() -> void:
	print("-- enter_location: unlocked ids only, through the injected changer")
	var entered := _gs.enter_location("range")
	_check(entered, "entering the unlocked range succeeds")
	_check(_packed_eq(_changed_to, ["res://levels/range/range.tscn"]),
		"the changer was asked for res://levels/range/range.tscn", "(got %s)" % _changed_to)
	var before := _changed_to.size()
	_check(not _gs.enter_location("secret"), "a locked location is refused")
	_check(_changed_to.size() == before,
		"and no scene change was requested", "(got %s)" % _changed_to)


func _test_return_to_lobby() -> void:
	print("-- return_to_lobby: back to the lobby through the changer")
	_gs.return_to_lobby("death")
	_check(_packed_eq(_changed_to, ["res://levels/range/range.tscn", "res://levels/lobby/lobby.tscn"]),
		"the changer was then asked for res://levels/lobby/lobby.tscn",
		"(got %s)" % _changed_to)


func _test_autosave_roundtrip() -> void:
	print("-- autosave: mutations land on disk, and a fresh state reads back")
	# The buy and equip above must already be on disk (autosave after every
	# mutator): points 10, auto equipped.
	var disk := _save.load_state()
	_check(int(disk.get("points", -1)) == 10,
		"autosave after buy/equip persisted points == 10",
		"(got %s)" % disk.get("points"))
	_check(disk.get("equipped_weapon_id") == "auto",
		"autosave persisted the equipped weapon",
		"(got %s)" % disk.get("equipped_weapon_id"))

	# Clean-slate round-trip: award_points(50) on a fresh state, then read the
	# value back from disk. The brief fixes this number at 50.
	_save.clear_save()
	_roundtrip = GameState.new()
	root.add_child(_roundtrip)
	await physics_frame
	_roundtrip.award_points(50)
	await physics_frame
	var loaded := _save.load_state()
	_check(int(loaded.get("points", -1)) == 50,
		"award_points(50) is on disk as points == 50",
		"(got %s)" % loaded.get("points"))
	_check(loaded.get("equipped_weapon_id") == "pistol",
		"and the persisted equipped weapon is correct",
		"(got %s)" % loaded.get("equipped_weapon_id"))
