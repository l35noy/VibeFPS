# Review package — Phase 2 Task 1

BASE: d10ce8f (no commits — owner commits; package = diff vs HEAD + full content of new files)

## git status --short
?? .opencode/
?? data/enemies/
?? scripts/enemy_data.gd
?? scripts/enemy_data.gd.uid
?? tests/enemies.gd
?? tests/enemies.gd.uid

## git diff --stat (tracked files)

## Full diff (tracked, -U10)

---

## NEW FILE: scripts/enemy_data.gd

class_name EnemyData
extends Resource

## РўРёРї РІСЂР°РіР°. CONTACT вЂ” СЌС‚Р° С„Р°Р·Р°; FLYING Рё BOSS РѕР±СЉСЏРІР»РµРЅС‹ СЃРµР№С‡Р°СЃ, РїРѕС‚РѕРјСѓ С‡С‚Рѕ
## С‚РёРїС‹ РїРµСЂРµС‡РёСЃР»РµРЅС‹ РІ СЃРїРµРєРµ В§6.2, Р° РґРѕР±Р°РІР»РµРЅРёРµ Р·РЅР°С‡РµРЅРёСЏ РІ enum РїРѕР·Р¶Рµ СЃР»РѕРјР°РµС‚
## СЃРѕС…СЂР°РЅРµРЅРёСЏ Рё РїСЂРѕРІРµСЂРєРё, С‡РёС‚Р°СЋС‰РёРµ С‚РёРї.
enum EnemyKind { CONTACT, FLYING, BOSS }

@export var display_name: String = "Enemy"
@export var max_health: float = 50.0
## РљРѕРЅС‚Р°РєС‚РЅС‹Р№ СѓСЂРѕРЅ Р·Р° РѕРґРёРЅ С‚РёРє РєРѕРЅС‚Р°РєС‚Р° (РєР°РґРµРЅС†РёСЏ вЂ” Сѓ РІСЂР°РіР°, РЅРµ Р·РґРµСЃСЊ).
@export var contact_damage: float = 10.0
@export var move_speed: float = 6.0
## РРЅС‚РµСЂРІР°Р» РјРµР¶РґСѓ СЃРїР°РІРЅР°РјРё РІ СЃРµРєСѓРЅРґР°С… вЂ” РґР»СЏ Р¤Р°Р·С‹ 3; РїРѕР»Рµ Р·РґРµСЃСЊ, С‡С‚РѕР±С‹ РґР°РЅРЅС‹Рµ
## Р±С‹Р»Рё РїРѕР»РЅС‹РјРё СЃ РїРµСЂРІРѕРіРѕ РґРЅСЏ (СЃРїРµРєР° В§6.2).
@export var spawn_interval: float = 1.5
@export var color: Color = Color(0.8, 0.25, 0.25)
@export var kind: EnemyKind = EnemyKind.CONTACT


## РџСЂРёРіРѕРґРЅС‹ Р»Рё РґР°РЅРЅС‹Рµ Рє СЃРїР°РІРЅСѓ. Р’СЂР°Рі СЃРїСЂР°С€РёРІР°РµС‚ СЌС‚Рѕ РґРѕ РїРѕСЏРІР»РµРЅРёСЏ РІ РјРёСЂРµ, Р° РЅРµ
## РїР°РґР°РµС‚ СЃР°Рј: РЅСѓР»РµРІР°СЏ СЃРєРѕСЂРѕСЃС‚СЊ РѕСЃС‚Р°РІРёР»Р° Р±С‹ РІСЂР°РіР° РІРёСЃРµС‚СЊ РІ С‚РѕС‡РєРµ СЃРїР°РІРЅР°, РЅСѓР»РµРІРѕР№
## РєРѕРЅС‚Р°РєС‚РЅС‹Р№ СѓСЂРѕРЅ вЂ” Р±РµСЃСЃРјРµСЂС‚РЅС‹Рј, Р° РЅСѓР»РµРІРѕР№ РёРЅС‚РµСЂРІР°Р» СЃРїР°РІРЅР° СѓСЂРѕРЅРёР» Р±С‹ РІРѕР»РЅСѓ.
func is_valid() -> bool:
	return max_health > 0.0 and contact_damage > 0.0 \
		and move_speed > 0.0 and spawn_interval > 0.0

---

## NEW FILE: data/enemies/contact.tres

[gd_resource type="Resource" script_class="EnemyData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/enemy_data.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
display_name = "Contact"
max_health = 50.0
contact_damage = 10.0
move_speed = 6.0
spawn_interval = 1.5
color = Color(0.8, 0.25, 0.25, 1)
kind = 0

---

## NEW FILE: tests/enemies.gd

extends SceneTree

## Enemy data harness for VibeFPS -- the first check of Phase 2.
##
## Structured and worded after tests/weapon_data.gd: one section, [PASS]/[FAIL]
## per assertion, a counter, quit(1) on any failure. It reads
## res://data/enemies/contact.tres through load() and asks it the questions the
## enemy script will ask in Phase 2: what are the numbers, what kind is it, and
## does the resource consider itself usable. Nothing is instantiated as a scene
## node -- this is data, and a data check that had to build a world in order to
## read a number would be testing the world instead.
##
## Every assertion below names the edit that turns it red. The negative halves
## are asserted too, not only the green ones: is_valid() is asked to reject each
## degenerate value in turn. Without those, a method hardcoded to return true
## would sail through a check that only ever saw the good resource.
##
## Run: godot --headless --path . --script res://tests/enemies.gd
##      .\tools\run_checks.ps1 enemies

const _CONTACT_PATH := "res://data/enemies/contact.tres"

var _failures: PackedStringArray = []
var _checks := 0


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


## Builds a throwaway EnemyData with one field overwritten, so is_valid() can be
## asked about a value no shipped resource ever carries.
func _probe(overrides: Dictionary) -> EnemyData:
	var probe := EnemyData.new()
	for key in overrides:
		probe.set(key, overrides[key])
	return probe


## Must come back true only when is_valid() really rejects the degenerate
## value, which is what makes "is_valid() is true" on contact.tres meaningful.
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
	print("=== enemies ===")

	print("-- %s must load as an EnemyData" % _CONTACT_PATH)
	var res: Resource = load(_CONTACT_PATH)
	if res == null:
		_bail("cannot load %s" % _CONTACT_PATH)
		return
	var script_res := res.get_script() as Script
	_check(res is EnemyData, "contact.tres is an EnemyData",
		"(script=%s)" % ("none" if script_res == null else script_res.resource_path))
	var data := res as EnemyData
	if data == null:
		_bail("contact.tres is not an EnemyData, the field checks below would be meaningless")
		return

	print("-- the values the design fixes for the contact enemy")
	# Design spec 7.3: the contact enemy has 50 health and 10 contact damage.
	# Each of these turns red on a single field edit in contact.tres.
	_check(data.max_health == 50.0, "max_health is 50.0", "(got %.4f)" % data.max_health)
	_check(data.contact_damage == 10.0, "contact_damage is 10.0", "(got %.4f)" % data.contact_damage)
	_check(data.move_speed == 6.0, "move_speed is 6.0", "(got %.4f)" % data.move_speed)
	_check(data.spawn_interval == 1.5, "spawn_interval is 1.5", "(got %.4f)" % data.spawn_interval)
	# The kind is what Phase 2 wires movement and the scene off, so a resource
	# that loads with a default kind must not be able to pass as a contact enemy.
	_check(data.kind == EnemyData.EnemyKind.CONTACT, "kind is EnemyData.EnemyKind.CONTACT",
		"(got %d)" % int(data.kind))

	print("-- is_valid() can answer false, so is_valid() == true means something")
	_check(data.is_valid(), "contact.tres reports itself valid")
	# One assertion per term of is_valid()'s condition: dropping any single term
	# from the implementation turns exactly this one red.
	_check(_is_valid_rejects({"max_health": 0.0}),
		"a zero max health is rejected")
	_check(_is_valid_rejects({"contact_damage": 0.0}),
		"a zero contact damage is rejected")
	_check(_is_valid_rejects({"move_speed": 0.0}),
		"a zero move speed is rejected")
	_check(_is_valid_rejects({"spawn_interval": 0.0}),
		"a zero spawn interval is rejected")

	_finish()
	quit(1 if _failures.size() > 0 else 0)
