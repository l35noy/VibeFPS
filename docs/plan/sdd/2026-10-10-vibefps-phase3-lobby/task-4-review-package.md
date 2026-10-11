# Task 4 Review Package — Взаимодействие (ShopPoint/DoorPoint/_try_interact)
Base: b7ad7c5 (HEAD; project policy: no commits by implementers — working-tree state)
NOTE: diff по scripts/player.gd включает пред-существующую владельческую правку (перевод строки в конце файла) — фокус на добавлениях Task 4 (ветка interact, nearest_interactable, _try_interact).

=== git diff -U10 (modified tracked files of this task) ===
diff --git a/tools/run_checks.ps1 b/tools/run_checks.ps1
index 275aaae..d09abfa 100644
--- a/tools/run_checks.ps1
+++ b/tools/run_checks.ps1
@@ -39,21 +39,22 @@
 
 $ErrorActionPreference = 'Stop'
 
 # Godot 4.7.2 stable. This is the single supported engine for the project; do
 # not add a second path here, the test contract (exit codes, [FAIL] markers on
 # stdout, --headless flag) is tied to this build.
 $GodotBin = "E:\Godot\Godot_v4.7.2-stable_win64.exe"
 
 # Ordered list of check names, without the .gd extension.
 $Tests = @("smoke", "movement", "input_actions", "input_gate", "weapon_data", "integrity",
-           "weapon", "projectile", "enemies", "waves", "save", "progression")
+           "weapon", "auto_weapon", "projectile", "enemies", "waves", "save", "progression",
+           "interact")
 
 # tests\capture.gd needs a real renderer and tests\diagnose.gd is run by hand,
 # so neither belongs here.
 
 $Filter = ''
 if ($args.Count -gt 0 -and $null -ne $args[0]) {
     $Filter = [string]$args[0]
 }
 
 # Godot's --path . is resolved against the process working directory, and the

=== NEW FILES (full contents) ===

--- FILE: scripts/shop_point.gd ---
class_name ShopPoint
extends Area3D

## Р’РёС‚СЂРёРЅР° Р»РѕР±Р±Рё: С‚РѕС‡РєР° РїРѕРєСѓРїРєРё РѕСЂСѓР¶РёСЏ. РЎС‚РѕРёС‚ РІ РєРѕРјРЅР°С‚Рµ, РёРіСЂРѕРє РїРѕРґС…РѕРґРёС‚ РІРїР»РѕС‚РЅСѓСЋ
## Рё Р¶РјС‘С‚ E; interact() РїСЂРѕРІРѕРґРёС‚ РїРѕРєСѓРїРєСѓ С‡РµСЂРµР· GameState Рё РіРѕРІРѕСЂРёС‚, СѓРґР°Р»Р°СЃСЊ Р»Рё
## РѕРЅР°. РЎР»РѕР№ 6 (interactable), РјР°СЃРєР° вЂ” С‚РѕР»СЊРєРѕ РёРіСЂРѕРє: С‚РѕС‡РєР° РґРѕР»Р¶РЅР° РІРёРґРµС‚СЊ РёРіСЂРѕРєР°
## СЃРІРѕРёРј С‚СЂРёРіРіРµСЂРѕРј, РЅРѕ РЅРµ СЃС‚Р°Р»РєРёРІР°С‚СЊСЃСЏ РЅРё СЃ С‡РµРј РѕСЃС‚Р°Р»СЊРЅС‹Рј.
##
## interact(player) РґРµСЂР¶РёС‚ player С‚РѕР»СЊРєРѕ СЂР°РґРё РµРґРёРЅРѕРіРѕ РїСЂРѕС‚РѕРєРѕР»Р° РІР·Р°РёРјРѕРґРµР№СЃС‚РІРёСЏ
## (Сѓ DoorPoint СЃРёРіРЅР°С‚СѓСЂР° С‚Р° Р¶Рµ) вЂ” РїРѕРєСѓРїР°РµС‚ СЃР°РјР° РїРѕРєСѓРїРєР°, Р° РЅРµ РёРіСЂРѕРє.

## РџРѕРєСѓРїРєР° СЃРѕСЃС‚РѕСЏР»Р°СЃСЊ (РёР»Рё Р±С‹Р»Р° РѕС‚РєР»РѕРЅРµРЅР°). РЎРёРіРЅР°Р» РѕР± РёР·РјРµРЅРµРЅРёРё: HUD Рё С‚РµСЃС‚С‹
## СѓР·РЅР°СЋС‚ Рѕ СЂРµР·СѓР»СЊС‚Р°С‚Рµ, РЅРµ РѕРїСЂР°С€РёРІР°СЏ СЃРѕСЃС‚РѕСЏРЅРёРµ.
signal interacted(ok: bool)

## РљР°РєРѕРµ РѕСЂСѓР¶РёРµ РїСЂРѕРґР°С‘С‚ СЌС‚Р° РІРёС‚СЂРёРЅР°. РРјСЏ С„Р°Р№Р»Р° РІ data/weapons Р±РµР· СЂР°СЃС€РёСЂРµРЅРёСЏ.
@export var weapon_id: String = "auto"


func _ready() -> void:
	collision_layer = 1 << 5
	collision_mask = 1 << 1
	monitoring = true
	add_to_group("interactable")


@warning_ignore("unused_parameter")
func interact(player: Node) -> bool:
	var gs := get_node_or_null("/root/GameState") as GameState
	if gs == null:
		return false
	var ok := gs.buy_weapon(weapon_id)
	interacted.emit(ok)
	return ok

--- FILE: scripts/shop_point.gd.uid ---
uid://ccdd7kao2dobf


--- FILE: scripts/door_point.gd ---
class_name DoorPoint
extends Area3D

## Р”РІРµСЂСЊ Р»РѕР±Р±Рё: С‚РѕС‡РєР° РІС…РѕРґР° РІ Р»РѕРєР°С†РёСЋ. РўРµ Р¶Рµ РєРѕРЅРІРµРЅС†РёРё, С‡С‚Рѕ Сѓ ShopPoint: СЃР»РѕР№ 6
## (interactable), С‚СЂРёРіРіРµСЂ РІРёРґРёС‚ С‚РѕР»СЊРєРѕ РёРіСЂРѕРєР°. interact() Р·РѕРІС‘С‚
## GameState.enter_location(location_id), РєРѕС‚РѕСЂС‹Р№ СЃР°Рј СЂРµС€Р°РµС‚, РѕС‚РєСЂС‹С‚Р° Р»Рё
## Р»РѕРєР°С†РёСЏ, Рё СѓС…РѕРґРёС‚ РІ СЃРјРµРЅСѓ СЃС†РµРЅС‹ С‡РµСЂРµР· РїРѕРґРјРµРЅСЏРµРјС‹Р№ scene_changer.

## РљР°РєСѓСЋ Р»РѕРєР°С†РёСЋ РѕС‚РєСЂС‹РІР°РµС‚ СЌС‚Р° РґРІРµСЂСЊ (id РёР· GameState._LOCATION_SCENES).
@export var location_id: String = "range"


func _ready() -> void:
	collision_layer = 1 << 5
	collision_mask = 1 << 1
	monitoring = true
	add_to_group("interactable")


@warning_ignore("unused_parameter")
func interact(player: Node) -> bool:
	var gs := get_node_or_null("/root/GameState") as GameState
	if gs == null:
		return false
	return gs.enter_location(location_id)

--- FILE: scripts/door_point.gd.uid ---
uid://c633dn78qj1c3


--- FILE: tests/interact.gd ---
extends SceneTree

## Interaction harness for VibeFPS (Phase 3, lobby track A): the ShopPoint and
## DoorPoint interactables, the player's nearest_interactable() reach pick, and
## the E (interact) route through the input gate.
##
## The SaveSystem autoload does not exist yet (a later task wires it into
## project.godot), so the harness builds one by hand at
## user://interact_test.json -- the same isolation tests/progression.gd uses, so
## the production user://save.json is never touched. Scene transitions go
## through an injected fake changer: headless has no window to swap scenes in,
## and the production scenes must not be loaded out from under the harness.
##
## The player is the shipped player.tscn instantiated on the root, with a probe
## script answering the gate with an explicit mouse mode -- headless cannot
## capture the cursor (Input.mouse_mode stays VISIBLE), exactly as
## tests/movement.gd does. Interact lives in player.gd's _unhandled_input, so it
## is driven with a parsed key event plus Input.flush_buffered_events():
## Input.action_press alone never reaches _unhandled_input (tests/movement.gd
## pins the same rule for jump), and an InputEventAction pressed while the
## action is already pressed is deduplicated before it reaches the tree -- which
## would make the second press in the gate check arrive nowhere. The key event
## is the honest shape of the input anyway: input_actions.gd pins interact to
## the physical E key.
##
## Run: godot --headless --path . --script res://tests/interact.gd
##      .\tools\run_checks.ps1 interact


## Stand-in for player.gd, used only by this harness.
class _PlayerProbe extends "res://player.gd":
	## Mouse mode the gate is evaluated against instead of Input.mouse_mode.
	var gate_mouse_mode: int = Input.MOUSE_MODE_CAPTURED

	func _mouse_mode_for_play_input() -> int:
		return gate_mouse_mode


## Records what ShopPoint announces. The signal is the observable the gate check
## needs: a second "purchase" of an already-owned weapon only equips, so it
## changes no points and leaves the equipped id where it was -- without the
## signal a gated press and an ungated one would look identical.
class _ShopLog extends RefCounted:
	var ok_values: Array[bool] = []

	func _on_interacted(ok: bool) -> void:
		ok_values.append(ok)


## Isolated path every interaction uses. user://save.json is never touched.
const _TMP_PATH := "user://interact_test.json"
const _PLAYER_SCENE := "res://player.tscn"
const _SHOP_SCRIPT := "res://scripts/shop_point.gd"
const _DOOR_SCRIPT := "res://scripts/door_point.gd"

## The reach the design fixes, restated here so a silent retune to 2.5 -- the
## value the brief explicitly overrules (R2: the shop at 3.0 m must be found,
## the door at 6.0 m must not) -- cannot turn this harness into a check of a
## different number.
const _EXPECTED_RANGE := 3.5
## The shops's stand-in price is whatever GameState reads from auto.tres; the
## points the harness grants match it so the arithmetic below is exact.
const _AUTO_PRICE := 300

var _failures: PackedStringArray = []
var _checks := 0

var _save: SaveSystem
var _gs: GameState
var _shop: ShopPoint
var _door: DoorPoint
var _player: CharacterBody3D
var _shop_log: _ShopLog
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


func _finish() -> void:
	print("=== RESULT: %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)


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


## Dispatchable key event bound to the interact action. The gate check uses this
## instead of InputEventAction on purpose: an InputEventAction pressed while the
## action is already pressed is deduplicated before it reaches the tree, so the
## second press in a row would silently arrive nowhere. A key event has no such
## dedup, and it is the honest shape of the input anyway -- input_actions.gd pins
## interact to the physical E key.
func _interact_key_event(pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.keycode = KEY_E
	ev.pressed = pressed
	return ev


## The hint string an @export carries ("Node3D", "WeaponData"...), a marker of an
## object-typed export. Plain String exports carry no hint, so the type check
## below reads the property's declared Variant.Type instead.
func _property_hint(node: Object, property_name: String) -> String:
	for entry in node.get_property_list():
		if String(entry.get("name", "")) == property_name:
			return String(entry.get("hint_string", ""))
	return "<missing>"


## The declared Variant.Type of an export, straight from get_property_list().
func _property_type(node: Object, property_name: String) -> Variant.Type:
	for entry in node.get_property_list():
		if String(entry.get("name", "")) == property_name:
			return entry.get("type", TYPE_NIL)
	return TYPE_NIL


func _cleanup() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_TMP_PATH))


# --------------------------------------------------------------------------
# world builders
# --------------------------------------------------------------------------

## A floor under the player so the physics ticks the gate check awaits cannot
## quietly drop it out of the shop's reach. Top face at y = 0, where the
## player capsule's bottom sits (1.8 height centred at 0.9 in player.tscn).
func _new_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	root.add_child(floor_body)


# --------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------

func _initialize() -> void:
	print("=== VibeFPS interact test ===")
	# Clean sheet: a leftover save from an interrupted run must not be restored
	# into the state under test.
	_cleanup()

	_save = SaveSystem.new()
	# The name is what makes /root/SaveSystem resolve for GameState's autosave.
	_save.name = "SaveSystem"
	_save.save_path = _TMP_PATH
	root.add_child(_save)

	_gs = GameState.new()
	# The name is what makes /root/GameState resolve for ShopPoint/DoorPoint.
	_gs.name = "GameState"
	# Injected before add_child, so GameState._ready() must not overwrite it.
	_gs.scene_changer = _fake_changer
	root.add_child(_gs)

	_new_floor()

	# The two interactables are built before the player, so the player's first
	# nearest_interactable() already sees both.
	_shop = ShopPoint.new()
	_shop.weapon_id = "auto"
	_shop.position = Vector3(0.0, 0.0, -3.0)
	root.add_child(_shop)

	_door = DoorPoint.new()
	_door.location_id = "range"
	_door.position = Vector3(0.0, 0.0, -6.0)
	root.add_child(_door)

	var packed: PackedScene = load(_PLAYER_SCENE)
	if packed == null:
		print("FATAL: cannot load %s" % _PLAYER_SCENE)
		_finish()
		quit(1)
		return
	_player = packed.instantiate() as CharacterBody3D
	if _player == null:
		print("FATAL: %s does not instantiate to a CharacterBody3D" % _PLAYER_SCENE)
		_finish()
		quit(1)
		return
	# Swapped before the node enters the tree, so @onready and _ready run on the
	# probe script. Everything under test is the real player.gd; only the mouse
	# mode the gate reads comes from the harness.
	_player.set_script(_PlayerProbe)
	_player.position = Vector3(0.0, 0.0, 0.0)
	root.add_child(_player)

	_shop_log = _ShopLog.new()
	_shop.interacted.connect(_shop_log._on_interacted)

	# Let every _ready run (group join, collision layers, GameState restore).
	await physics_frame

	_test_contracts()
	_test_shop_purchase()
	_test_door_transition()
	_test_nearest_interactable()
	await _test_input_gate()

	_save.clear_save()
	_cleanup()

	_finish()
	quit(1 if _failures.size() > 0 else 0)


# --------------------------------------------------------------------------
# checks
# --------------------------------------------------------------------------

## The references later tasks bind to: a renamed class, export, signal or layer
## is a silent break for lobby.tscn and for the interaction itself.
func _test_contracts() -> void:
	print("-- contracts: the classes, exports, signals, layers and group")
	var shop_script := load(_SHOP_SCRIPT) as Script
	_check(shop_script != null, "shop_point.gd loads")
	if shop_script == null:
		return
	_check(shop_script.get_global_name() == "ShopPoint",
		"shop_point.gd declares class_name ShopPoint",
		"(got \"%s\")" % shop_script.get_global_name())
	_check(shop_script.get_instance_base_type() == "Area3D",
		"ShopPoint extends Area3D", "(got %s)" % shop_script.get_instance_base_type())
	_check(_shop.has_method("interact"), "ShopPoint exposes interact()")
	_check(_shop.has_signal("interacted"), "ShopPoint exposes the interacted signal")
	_check(_property_type(_shop, "weapon_id") == TYPE_STRING,
		"weapon_id is a String export", "(got type %s)" % str(_property_type(_shop, "weapon_id")))
	_check(int(_shop.collision_layer) == 1 << 5,
		"ShopPoint lives on layer 6 (interactable)", "(got %d)" % int(_shop.collision_layer))
	_check(int(_shop.collision_mask) == 1 << 1,
		"and its mask is the player layer", "(got %d)" % int(_shop.collision_mask))
	_check(_shop.monitoring, "ShopPoint monitors overlaps")
	_check(_shop.is_in_group("interactable"), "ShopPoint joins the interactable group")

	var door_script := load(_DOOR_SCRIPT) as Script
	_check(door_script != null, "door_point.gd loads")
	if door_script == null:
		return
	_check(door_script.get_global_name() == "DoorPoint",
		"door_point.gd declares class_name DoorPoint",
		"(got \"%s\")" % door_script.get_global_name())
	_check(door_script.get_instance_base_type() == "Area3D",
		"DoorPoint extends Area3D", "(got %s)" % door_script.get_instance_base_type())
	_check(_door.has_method("interact"), "DoorPoint exposes interact()")
	_check(_property_type(_door, "location_id") == TYPE_STRING,
		"location_id is a String export", "(got type %s)" % str(_property_type(_door, "location_id")))
	_check(int(_door.collision_layer) == 1 << 5,
		"DoorPoint lives on layer 6 (interactable)", "(got %d)" % int(_door.collision_layer))
	_check(int(_door.collision_mask) == 1 << 1,
		"and its mask is the player layer", "(got %d)" % int(_door.collision_mask))
	_check(_door.monitoring, "DoorPoint monitors overlaps")
	_check(_door.is_in_group("interactable"), "DoorPoint joins the interactable group")


func _test_shop_purchase() -> void:
	print("-- shop: refused without points, bought with them")
	_check(_gs.points == 0, "precondition: the player starts with no points",
		"(got %d)" % _gs.points)
	var refused := _shop.interact(_player)
	_check(not refused, "the shop refuses the auto without points")
	_check(_packed_eq(_gs.owned_weapons, ["pistol"]),
		"and does not hand it over", "(got %s)" % _gs.owned_weapons)
	_check(_gs.points == 0, "and charges nothing", "(got %d)" % _gs.points)
	_check(_shop_log.ok_values.size() == 1 and _shop_log.ok_values[0] == false,
		"the refused sale is announced as a refusal",
		"(got %s)" % str(_shop_log.ok_values))

	_gs.award_points(_AUTO_PRICE)
	var bought := _shop.interact(_player)
	_check(bought, "the shop sells the %d auto once the player can afford it" % _AUTO_PRICE)
	_check("auto" in _gs.owned_weapons, "the auto is now owned", "(got %s)" % _gs.owned_weapons)
	_check(_gs.equipped_weapon_id == "auto", "and equipped",
		"(got \"%s\")" % _gs.equipped_weapon_id)
	_check(_gs.points == 0, "the price was deducted", "(got %d)" % _gs.points)
	_check(_shop_log.ok_values.size() == 2 and _shop_log.ok_values[1] == true,
		"the sale is announced as a success", "(got %s)" % str(_shop_log.ok_values))


func _test_door_transition() -> void:
	print("-- door: entering the range goes through the scene changer")
	var entered := _door.interact(_player)
	_check(entered, "the door enters the unlocked range")
	_check(_changed_to.size() > 0 and _changed_to[_changed_to.size() - 1] == "res://range.tscn",
		"the changer was asked for res://range.tscn", "(got %s)" % _changed_to)


## The reach the brief overrules 2.5 with (R2): a shop at 3.0 m is inside 3.5 m
## and a door at 6.0 m is outside it, so a 2.5 m range or a 6.0 m one both fail
## this pair.
func _test_nearest_interactable() -> void:
	print("-- reach: the nearest interactable within %.1f m, and nothing beyond" % _EXPECTED_RANGE)
	_player.global_position = Vector3(0.0, 0.0, 0.0)
	var nearest: Node = _player.call("nearest_interactable")
	_check(nearest == _shop,
		"the shop at 3.0 m is found (the range is 3.5, not 2.5)",
		"(got %s)" % ("null" if nearest == null else nearest.name))

	_shop.position = Vector3(0.0, 0.0, -10.0)
	nearest = _player.call("nearest_interactable")
	_check(nearest == null,
		"with the shop at 10 m and the door at 6 m, nothing is in reach",
		"(got %s)" % ("null" if nearest == null else nearest.name))
	# Put the shop back: the gate check below needs a target an ungated press
	# can actually reach.
	_shop.position = Vector3(0.0, 0.0, -3.0)


## Interact is play input: it must not be a way around a free cursor. With the
## cursor free the same press has to do nothing at all, and capturing it has to
## be the only thing that changes.
func _test_input_gate() -> void:
	print("-- input gate: interact does not get around the cursor being free")
	_player.global_position = Vector3(0.0, 0.0, 0.0)
	var before := _shop_log.ok_values.size()

	_player.set("gate_mouse_mode", Input.MOUSE_MODE_VISIBLE)
	Input.parse_input_event(_interact_key_event(true))
	# Synchronous delivery, exactly as tests/movement.gd does for jump: Godot
	# otherwise accumulates parsed events and flushes them only on the next main
	# loop iteration, which would let the assertions race the delivery.
	Input.flush_buffered_events()
	await physics_frame
	_check(_shop_log.ok_values.size() == before,
		"a press with the cursor free reaches neither the shop nor its signal",
		"(got %d signals)" % (_shop_log.ok_values.size() - before))
	_check(_gs.points == 0, "and spends no points",
		"(got %d)" % _gs.points)
	_check(_gs.equipped_weapon_id == "auto",
		"and leaves the equipped weapon alone", "(got \"%s\")" % _gs.equipped_weapon_id)

	# A real press returns through a release: the second press is a new press,
	# not a repeat of the first one.
	_player.set("gate_mouse_mode", Input.MOUSE_MODE_CAPTURED)
	Input.parse_input_event(_interact_key_event(false))
	Input.flush_buffered_events()
	await physics_frame
	Input.parse_input_event(_interact_key_event(true))
	Input.flush_buffered_events()
	await physics_frame
	_check(_shop_log.ok_values.size() == before + 1,
		"the same press reaches the shop once the cursor is captured",
		"(got %d signals)" % (_shop_log.ok_values.size() - before))
	if _shop_log.ok_values.size() == before + 1:
		_check(_shop_log.ok_values[before] == true,
			"and reports the second purchase as a success")

	# The second purchase of an owned weapon is an equip, not a charge.
	_check(_gs.equipped_weapon_id == "auto",
		"the second purchase only equips: auto stays equipped",
		"(got \"%s\")" % _gs.equipped_weapon_id)
	_check(_gs.points == 0, "and it charged nothing",
		"(got %d)" % _gs.points)


--- FILE: tests/interact.gd.uid ---
uid://d1ye3d6m8ojce

