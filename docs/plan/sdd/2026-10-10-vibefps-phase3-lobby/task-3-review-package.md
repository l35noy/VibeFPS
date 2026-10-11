# Task 3 Review Package — GameState + tests/progression.gd
Base: b7ad7c5 (HEAD; project policy: no commits by implementers — working-tree state)
New files of this task only (no tracked files modified by this task).

--- FILE: scripts/game_state.gd ---
class_name GameState
extends Node

## Р“Р»РѕР±Р°Р»СЊРЅРѕРµ СЃРѕСЃС‚РѕСЏРЅРёРµ РїСЂРѕРіСЂРµСЃСЃР°: РѕС‡РєРё, РєСѓРїР»РµРЅРЅРѕРµ Рё СЌРєРёРїРёСЂРѕРІР°РЅРЅРѕРµ РѕСЂСѓР¶РёРµ,
## РѕС‚РєСЂС‹С‚С‹Рµ Р»РѕРєР°С†РёРё. Р–РёРІС‘С‚ РєР°Рє Р°РІС‚РѕР·Р°РіСЂСѓР·РєР° /root/GameState (РїСЂРѕРІРѕРґРєР° вЂ” Task 6).
##
## Р”РІР° РїСЂР°РІРёР»Р°, СЂР°РґРё РєРѕС‚РѕСЂС‹С… СЌС‚РѕС‚ СѓР·РµР» СЃСѓС‰РµСЃС‚РІСѓРµС‚:
##   * РџРµСЂРµС…РѕРґС‹ РјРµР¶РґСѓ СЃС†РµРЅР°РјРё РёРґСѓС‚ РўРћР›Р¬РљРћ С‡РµСЂРµР· РїРѕРґРјРµРЅСЏРµРјС‹Р№ `scene_changer`.
##     РЎРїРµРєР° В§6.1 Р·Р°РїСЂРµС‰Р°РµС‚ РїСЂСЏРјРѕР№ change_scene_to_file РІ РёРіСЂРѕРІС‹С… СЃС†РµРЅР°С…: СЃРјРµРЅР°
##     СЃС†РµРЅС‹ РёР· СЃРµСЂРµРґРёРЅС‹ РёРіСЂРѕРІРѕРіРѕ РєРѕРґР° РґРµР»Р°РµС‚ РїРµСЂРµС…РѕРґ РЅРµРІРёРґРёРјС‹Рј РґР»СЏ С‚РµСЃС‚РѕРІ Рё
##     РґР»СЏ С‚РѕРіРѕ, РєС‚Рѕ С‡РёС‚Р°РµС‚ РІС‹Р·С‹РІР°СЋС‰РёР№ РєРѕРґ. Р—РґРµСЃСЊ СЌС‚Рѕ РµРґРёРЅСЃС‚РІРµРЅРЅР°СЏ РґРІРµСЂСЊ, Рё РІ
##     С‚РµСЃС‚Р°С… РѕРЅР° РїРѕРґРјРµРЅСЏРµС‚СЃСЏ Р·Р°РїРёСЃС‹РІР°СЋС‰РµР№ Р·Р°РіР»СѓС€РєРѕР№.
##   * РљР°Р¶РґРѕРµ РёР·РјРµРЅРµРЅРёРµ (РѕС‡РєРё, РїРѕРєСѓРїРєР°, СЌРєРёРїРёСЂРѕРІРєР°) Р°РІС‚РѕСЃРѕС…СЂР°РЅСЏРµС‚СЃСЏ С‡РµСЂРµР·
##     /root/SaveSystem, РµСЃР»Рё РѕРЅ РµСЃС‚СЊ. Null-safe: СЃС†РµРЅР° РёР»Рё С‚РµСЃС‚ Р±РµР·
##     Р°РІС‚РѕР·Р°РіСЂСѓР·РєРё РїСЂРѕСЃС‚Рѕ РЅРёС‡РµРіРѕ РЅРµ СЃРѕС…СЂР°РЅСЏРµС‚ Рё РЅРµ РїР°РґР°РµС‚.
##
## Р§РёСЃР»Р° РѕС‡РєРѕРІ вЂ” РІСЂРµРјРµРЅРЅС‹Р№ Р±Р°Р»Р°РЅСЃ РІР»Р°РґРµР»СЊС†Р° (PROJECT.md В§7.5): СѓР±РёР№СЃС‚РІРѕ 10,
## РІРѕР»РЅР° 50, Р·Р°С‡РёСЃС‚РєР° 500. Р’РѕР»РЅС‹ Рё Р·Р°С‡РёСЃС‚РєР° РЅР°С‡РЅСѓС‚ РЅР°С‡РёСЃР»СЏС‚СЊСЃСЏ РІ Р¤Р°Р·Рµ 4;
## РєРѕРЅСЃС‚Р°РЅС‚С‹ Р·Р°РґР°РЅС‹ СѓР¶Рµ Р·РґРµСЃСЊ, С‡С‚РѕР±С‹ Р¤Р°Р·Рµ 4 РЅРµ РїСЂРёС€Р»РѕСЃСЊ РёС… РёР·РѕР±СЂРµС‚Р°С‚СЊ.

const POINTS_PER_KILL := 10
const POINTS_PER_WAVE := 50
const POINTS_PER_CLEAR := 500

## id Р»РѕРєР°С†РёРё -> СЃС†РµРЅР°. РџСЂРёРІР°С‚РЅС‹Р№: РЅР°СЂСѓР¶Сѓ С‚РѕСЂС‡РёС‚ С‚РѕР»СЊРєРѕ enter_location(id).
## "range" вЂ” РІСЂРµРјРµРЅРЅС‹Р№ Р±РѕР№ С‡РµСЂРµР· РґРІРµСЂСЊ Р»РѕР±Р±Рё; РЅР°СЃС‚РѕСЏС‰Р°СЏ Р»РѕРєР°С†РёСЏ РїРѕСЏРІРёС‚СЃСЏ РІ
## Р¤Р°Р·Рµ 4, Рё С‚РѕРіРґР° РєР°СЂС‚Р° РІС‹СЂР°СЃС‚РµС‚, Р° РІС‹Р·С‹РІР°СЋС‰РёР№ РєРѕРґ РЅРµ РёР·РјРµРЅРёС‚СЃСЏ.
const _LOCATION_SCENES := {
	"range": "res://range.tscn",
}

var points: int = 0
var owned_weapons: PackedStringArray = ["pistol"]
var equipped_weapon_id: String = "pistol"
var unlocked_locations: PackedStringArray = ["range"]

## РџРѕРґРјРµРЅСЏРµРјС‹Р№ РІ С‚РµСЃС‚Р°С…. Р—РЅР°С‡РµРЅРёРµ РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ СЃС‚Р°РІРёС‚СЃСЏ РІ `_ready()`, Р° РќР• РІ
## `_init()`: РїСЂРё СЂСѓС‡РЅРѕРј `GameState.new()` + `add_child()` (СЃС†РµРЅР° РёР»Рё С‚РµСЃС‚ Р±РµР·
## Р°РІС‚РѕР·Р°РіСЂСѓР·РєРё) `get_tree()` РІ `_init()` РµС‰С‘ null, Рё Callable СѓРєР°Р·С‹РІР°Р» Р±С‹ РІ
## РїСѓСЃС‚РѕС‚Сѓ. РРЅСЉРµРєС†РёСЏ РёР· С‚РµСЃС‚Р° СЃС‚Р°РІРёС‚СЃСЏ Р”Рћ add_child, РїРѕСЌС‚РѕРјСѓ `_ready()`
## Р·Р°РїРѕР»РЅСЏРµС‚ Р·РЅР°С‡РµРЅРёРµ С‚РѕР»СЊРєРѕ РµСЃР»Рё РµРіРѕ РЅРёРєС‚Рѕ РЅРµ Р·Р°РґР°Р» (СЃРј. С‚Р°Рј Р¶Рµ).
var scene_changer: Callable


func _ready() -> void:
	# Р—Р°РїРѕР»РЅРёС‚СЊ РґРІРёР¶РєРѕРІС‹Р№ РїРµСЂРµС…РѕРґ, С‚РѕР»СЊРєРѕ РµСЃР»Рё РµРіРѕ РЅРёРєС‚Рѕ РЅРµ РїРѕРґРјРµРЅРёР». Р”РµС„РѕР»С‚РЅС‹Р№
	# Callable РЅРµРІР°Р»РёРґРµРЅ, РїРѕСЌС‚РѕРјСѓ is_valid() РѕС‚Р»РёС‡Р°РµС‚ В«РЅРµ Р·Р°РґР°РЅВ» РѕС‚ Р·Р°РіР»СѓС€РєРё,
	# РїСЂРёСЃРІРѕРµРЅРЅРѕР№ РґРѕ РІС…РѕРґР° РІ РґРµСЂРµРІРѕ.
	if not scene_changer.is_valid():
		scene_changer = Callable(get_tree(), "change_scene_to_file")
	# Р’РѕСЃСЃС‚Р°РЅРѕРІР»РµРЅРёРµ С‚РѕР»СЊРєРѕ РїСЂРё РЅР°Р»РёС‡РёРё SaveSystem: РѕРЅ РїРѕСЏРІР»СЏРµС‚СЃСЏ РєР°Рє Р°РІС‚РѕР·Р°РіСЂСѓР·РєР°
	# РІ Task 6, Р° РґРѕ С‚РµС… РїРѕСЂ СЃРѕСЃС‚РѕСЏРЅРёРµ СЃС‚Р°СЂС‚СѓРµС‚ СЃ РґРµС„РѕР»С‚РѕРІ.
	var ss := get_node_or_null("/root/SaveSystem")
	if ss != null:
		_restore(ss.load_state())


## Р¦РµРЅР° РѕСЂСѓР¶РёСЏ РёР· РµРіРѕ СЂРµСЃСѓСЂСЃР°. РќРµС‚ С„Р°Р№Р»Р° РёР»Рё Р±РёС‚С‹Р№ СЂРµСЃСѓСЂСЃ вЂ” 0: РІРёС‚СЂРёРЅР° РґРѕР»Р¶РЅР°
## РїРѕРєР°Р·Р°С‚СЊ С†РµРЅСѓ, РЅРµ РїР°РґР°СЏ РЅР° РѕС‚СЃСѓС‚СЃС‚РІСѓСЋС‰РµРј РѕСЂСѓР¶РёРё. РћС‚РґРµР»СЊРЅС‹Р№ РІРѕРїСЂРѕСЃ вЂ” РјРѕР¶РЅРѕ Р»Рё
## С‚Р°РєРѕРµ РѕСЂСѓР¶РёРµ РєСѓРїРёС‚СЊ; РЅР° РЅРµРіРѕ РѕС‚РІРµС‡Р°РµС‚ buy_weapon, Р° РЅРµ С†РµРЅР°.
func weapon_price(id: String) -> int:
	var data := _load_weapon(id)
	return data.price if data != null else 0


## РќР°С‡РёСЃР»РµРЅРёРµ РѕС‡РєРѕРІ. РћС‚СЂРёС†Р°С‚РµР»СЊРЅС‹Рµ Р·РЅР°С‡РµРЅРёСЏ РёРіРЅРѕСЂРёСЂСѓСЋС‚СЃСЏ: СЌС‚Рѕ РЅРµ В«С€С‚СЂР°С„В», Р°
## Р·Р°С‰РёС‚Р° РѕС‚ РѕРїРµС‡Р°С‚РєРё РІ РІС‹Р·С‹РІР°СЋС‰РµРј РєРѕРґРµ, РєРѕС‚РѕСЂР°СЏ С‚РёС…Рѕ СѓРјРµРЅСЊС€РёР»Р° Р±С‹ СЃС‡С‘С‚.
func award_points(amount: int) -> void:
	if amount < 0:
		return
	points += amount
	_autosave()


func can_afford(cost: int) -> bool:
	return points >= cost


## РџРѕРєСѓРїРєР°. РЈР¶Рµ РєСѓРїР»РµРЅРЅРѕРµ С‚РѕР»СЊРєРѕ СЌРєРёРїРёСЂСѓРµС‚СЃСЏ, Р±РµР· РІС‚РѕСЂРѕРіРѕ СЃРїРёСЃР°РЅРёСЏ. РџСЂРё РЅРµС…РІР°С‚РєРµ
## РѕС‡РєРѕРІ вЂ” РѕС‚РєР°Р· Р±РµР· РёР·РјРµРЅРµРЅРёР№. РќРµСЃСѓС‰РµСЃС‚РІСѓСЋС‰РµРµ РѕСЂСѓР¶РёРµ РєСѓРїРёС‚СЊ РЅРµР»СЊР·СЏ: РёРЅР°С‡Рµ
## РѕС‚СЃСѓС‚СЃС‚РІРёРµ С„Р°Р№Р»Р° (weapon_price == 0) РѕС‚РєСЂС‹РІР°Р»Рѕ Р±С‹ Р±РµСЃРїР»Р°С‚РЅСѓСЋ РїРѕРєСѓРїРєСѓ С‚РѕРіРѕ,
## С‡РµРіРѕ РЅРµС‚.
func buy_weapon(id: String) -> bool:
	if id in owned_weapons:
		return equip_weapon(id)
	var data := _load_weapon(id)
	if data == null:
		return false
	if not can_afford(data.price):
		return false
	points -= data.price
	owned_weapons.append(id)
	equipped_weapon_id = id
	_autosave()
	return true


## Р­РєРёРїРёСЂРѕРІРєР° С‚РѕР»СЊРєРѕ РёР· РєСѓРїР»РµРЅРЅРѕРіРѕ.
func equip_weapon(id: String) -> bool:
	if not (id in owned_weapons):
		return false
	equipped_weapon_id = id
	_autosave()
	return true


## Р’С…РѕРґ РІ Р»РѕРєР°С†РёСЋ С‚РѕР»СЊРєРѕ РёР· РѕС‚РєСЂС‹С‚С‹С… Рё С‚РѕР»СЊРєРѕ РЅР° РёР·РІРµСЃС‚РЅСѓСЋ СЃС†РµРЅСѓ; РёРЅР°С‡Рµ РѕС‚РєР°Р·
## Р‘Р•Р— СЃРјРµРЅС‹ СЃС†РµРЅС‹.
func enter_location(id: String) -> bool:
	if not (id in unlocked_locations):
		return false
	if not _LOCATION_SCENES.has(id):
		return false
	scene_changer.call(_LOCATION_SCENES[id])
	return true


## Р’РѕР·РІСЂР°С‚ РІ Р»РѕР±Р±Рё. reason РїРѕРєР° РЅРµ РёСЃРїРѕР»СЊР·СѓРµС‚СЃСЏ вЂ” РїР°СЂР°РјРµС‚СЂ РїРѕРґ Р±СѓРґСѓС‰РёРµ СЌРєСЂР°РЅС‹
## (В«СЃРјРµСЂС‚СЊВ», В«РІС‹С…РѕРґ РёР· Р±РѕСЏВ»), С‡С‚РѕР±С‹ СЃРёРіРЅР°С‚СѓСЂСѓ РЅРµ РїСЂРёС€Р»РѕСЃСЊ РјРµРЅСЏС‚СЊ Р·Р°РґРЅРёРј С‡РёСЃР»РѕРј.
@warning_ignore("unused_parameter")
func return_to_lobby(reason: String) -> void:
	scene_changer.call("res://lobby.tscn")


## РЎР»РѕРІР°СЂСЊ РґР»СЏ SaveSystem: СЂРѕРІРЅРѕ С‚Рѕ, С‡С‚Рѕ РїРµСЂРµР¶РёРІР°РµС‚ РїРµСЂРµР·Р°РїСѓСЃРє. Packed-РјР°СЃСЃРёРІС‹
## РєРѕРЅРІРµСЂС‚РёСЂСѓСЋС‚СЃСЏ РІ РѕР±С‹С‡РЅС‹Рµ Array вЂ” JSON-СЃРѕРІРјРµСЃС‚РёРјС‹Р№ РІРёРґ, РєРѕС‚РѕСЂС‹Р№ load_state()
## РІРµСЂРЅС‘С‚ РєР°Рє Array.
func _persist() -> Dictionary:
	return {
		"points": points,
		"owned_weapons": Array(owned_weapons),
		"equipped_weapon_id": equipped_weapon_id,
		"unlocked_locations": Array(unlocked_locations),
	}


## РџСЂРёРјРµРЅСЏРµС‚ С‚РѕР»СЊРєРѕ РїСЂРёСЃСѓС‚СЃС‚РІСѓСЋС‰РёРµ РєР»СЋС‡Рё Рё С‚РѕР»СЊРєРѕ РїРѕРґС…РѕРґСЏС‰РёС… С‚РёРїРѕРІ: Р±РёС‚С‹Р№ РёР»Рё
## С‡Р°СЃС‚РёС‡РЅС‹Р№ СЃРµР№РІ (РёР»Рё СЃРµР№РІ РёР· РґСЂСѓРіРѕР№ РІРµСЂСЃРёРё РёРіСЂС‹) РЅРµ РґРѕР»Р¶РµРЅ СЂРѕРЅСЏС‚СЊ
## РІРѕСЃСЃС‚Р°РЅРѕРІР»РµРЅРёРµ Рё РЅРµ РґРѕР»Р¶РµРЅ Р·Р°С‚РёСЂР°С‚СЊ РґРµС„РѕР»С‚ РјСѓСЃРѕСЂРѕРј.
func _restore(saved: Dictionary) -> void:
	if saved.has("points") and (saved["points"] is int or saved["points"] is float):
		points = int(saved["points"])
	if saved.has("owned_weapons") and saved["owned_weapons"] is Array:
		owned_weapons = _to_string_array(saved["owned_weapons"])
	if saved.has("equipped_weapon_id") and saved["equipped_weapon_id"] is String:
		equipped_weapon_id = saved["equipped_weapon_id"]
	if saved.has("unlocked_locations") and saved["unlocked_locations"] is Array:
		unlocked_locations = _to_string_array(saved["unlocked_locations"])


## РђРІС‚РѕСЃРµР№РІ РїРѕСЃР»Рµ РєР°Р¶РґРѕРіРѕ РјСѓС‚Р°С‚РѕСЂР°. Null-safe: Р±РµР· Р°РІС‚РѕР·Р°РіСЂСѓР·РєРё SaveSystem
## СЃРѕС…СЂР°РЅСЏС‚СЊ РЅРµРєСѓРґР°, Рё СЌС‚Рѕ РЅРµ РѕС€РёР±РєР°.
func _autosave() -> void:
	var ss := get_node_or_null("/root/SaveSystem")
	if ss != null and ss.has_method("save"):
		ss.save(_persist())


## Р—Р°РіСЂСѓР·РєР° СЂРµСЃСѓСЂСЃР° РѕСЂСѓР¶РёСЏ РїРѕ id. РџСѓСЃС‚РѕР№ id РёР»Рё РѕС‚СЃСѓС‚СЃС‚РІСѓСЋС‰РёР№ С„Р°Р№Р» вЂ” null.
func _load_weapon(id: String) -> WeaponData:
	if id.is_empty():
		return null
	return load("res://data/weapons/%s.tres" % id) as WeaponData


## Array РёР· JSON -> PackedStringArray. РќРµ-СЃС‚СЂРѕРєРё РѕС‚Р±СЂР°СЃС‹РІР°СЋС‚СЃСЏ, С‡С‚РѕР±С‹ Р±РёС‚С‹Р№ СЃРµР№РІ
## РЅРµ РјРѕРі РїРѕР»РѕР¶РёС‚СЊ РІ РјРµС€РѕРє РѕСЂСѓР¶РёСЏ РјСѓСЃРѕСЂ С‡СѓР¶РѕРіРѕ С‚РёРїР°.
func _to_string_array(value: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for item in value:
		if item is String:
			out.append(item)
	return out


--- FILE: tests/progression.gd ---
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


func _initialize() -> void:
	print("=== VibeFPS progression test ===")
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
	_check(_packed_eq(_changed_to, ["res://range.tscn"]),
		"the changer was asked for res://range.tscn", "(got %s)" % _changed_to)
	var before := _changed_to.size()
	_check(not _gs.enter_location("secret"), "a locked location is refused")
	_check(_changed_to.size() == before,
		"and no scene change was requested", "(got %s)" % _changed_to)


func _test_return_to_lobby() -> void:
	print("-- return_to_lobby: back to the lobby through the changer")
	_gs.return_to_lobby("death")
	_check(_packed_eq(_changed_to, ["res://range.tscn", "res://lobby.tscn"]),
		"the changer was then asked for res://lobby.tscn",
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


--- FILE: scripts/game_state.gd.uid ---
uid://8w02fhw76f8v


--- FILE: tests/progression.gd.uid ---
uid://hvmej780r6ji

