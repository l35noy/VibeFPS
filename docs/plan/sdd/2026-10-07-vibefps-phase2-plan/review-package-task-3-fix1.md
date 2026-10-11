# Re-review package — Phase 2 Task 3, fix round 1

FIX_BASE: state seen by the task review (tests/enemies.gd SHA-256 A62C244C…516917). Fix touches ONLY tests/enemies.gd (now 9FAF5515…CBBA74); game code byte-identical. Package = full content of the fixed file + fix report section.

## git status --short
 M player.gd
 M player.tscn
 M scripts/hurtbox.gd
?? .opencode/
?? data/enemies/
?? enemy_contact.tscn
?? scripts/enemy_contact.gd
?? scripts/enemy_contact.gd.uid
?? scripts/enemy_data.gd
?? scripts/enemy_data.gd.uid
?? tests/enemies.gd
?? tests/enemies.gd.uid

## git diff --stat vs HEAD (should show NO new files vs task review)
 player.gd          | 84 ++++++++++++++++++++++++++++++++++++++++++++++++++++--
 player.tscn        | 17 +++++++++--
 scripts/hurtbox.gd | 46 ++++++++++++++++++------------
 3 files changed, 125 insertions(+), 22 deletions(-)

---

## FULL CONTENT: tests/enemies.gd (post-fix)
extends SceneTree

## Enemy data harness for VibeFPS -- the first check of Phase 2.
##
## Structured and worded after tests/weapon_data.gd: sections, [PASS]/[FAIL]
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
## Task 2 adds the second section, "Р—РґРѕСЂРѕРІСЊРµ РёРіСЂРѕРєР°". It loads the real
## res://player.tscn and waits for is_node_ready() instead of assembling a player
## out of nodes: what is under test is the wiring stored in the scene file, and a
## harness that built the player itself would stay green with player.tscn
## carrying no Hurtbox at all. The damage is dealt through that scene's own
## Hurtbox node, so "damage_taken -> take_damage" is exercised as a connection
## rather than as two methods that happen to exist.
##
## Task 3 adds the third section, "РљРѕРЅС‚Р°РєС‚РЅС‹Р№ РІСЂР°Рі". Same rule, one level deeper:
## the enemy comes from res://enemy_contact.tscn and is hurt by the real
## res://projectile.tscn, while only the world around it (floor, wall) is built
## in code. tests/projectile.gd cannot cover this: its world is made of nodes, so
## it proves nothing about the wiring stored in the enemy's scene file -- layers,
## hurtbox zone, data reference. Everything the enemy needs is read with call()/
## get()/has_method() rather than through the ContactEnemy class, exactly like
## the player helpers above: a static reference to a class_name that does not
## exist yet kills the whole harness at parse time and reports nothing about what
## is missing.
##
## Run: godot --headless --path . --script res://tests/enemies.gd
##      .\tools\run_checks.ps1 enemies

const _CONTACT_PATH := "res://data/enemies/contact.tres"
const _PLAYER_PATH := "res://player.tscn"
const _ENEMY_PATH := "res://enemy_contact.tscn"
const _PROJECTILE_PATH := "res://projectile.tscn"
## РЎР»РѕР№ 4 вЂ” enemy_hurtbox, СЃР»РѕР№ 7 вЂ” player_hurtbox (project.godot, [layer_names]).
## РќРѕРјРµСЂР° СЃР»РѕС‘РІ вЂ” Р±РёС‚РѕРІС‹Рµ РјР°СЃРєРё: СЃР»РѕР№ N = 1 << (N - 1).
const _LAYER_WORLD := 1 << 0
const _LAYER_ENEMY_BODY := 1 << 2
const _LAYER_ENEMY_HURTBOX := 1 << 3
const _LAYER_PLAYER_HURTBOX := 1 << 6
## Р”РѕРїСѓСЃРє СЃСЂР°РІРЅРµРЅРёСЏ Р·РґРѕСЂРѕРІСЊСЏ. Р’СЃРµ С‡РёСЃР»Р° РїСЂРѕРІРµСЂРєРё С†РµР»С‹Рµ РґРµСЃСЏС‚С‹Рµ РґРѕР»Рё, С‚Р°Рє С‡С‚Рѕ
## 0.0001 РѕС‚РґРµР»СЏРµС‚ РЅР°СЃС‚РѕСЏС‰РµРµ СЂР°СЃС…РѕР¶РґРµРЅРёРµ РѕС‚ РґРІРѕРёС‡РЅРѕРіРѕ РїСЂРµРґСЃС‚Р°РІР»РµРЅРёСЏ.
const _HEALTH_EPS := 0.0001
## Р”РѕРїСѓСЃРє СЃСЂР°РІРЅРµРЅРёСЏ С†РІРµС‚Р°: .tres С…СЂР°РЅРёС‚ float32, Р° 0.01 вЂ” СЌС‚Рѕ СЂР°Р·РЅРёС†Р°, РєРѕС‚РѕСЂСѓСЋ
## РіР»Р°Р· СѓР¶Рµ РЅР°Р·РІР°Р» Р±С‹ РґСЂСѓРіРёРј С†РІРµС‚РѕРј, Р° РЅРµ РґРІРѕРёС‡РЅС‹Рј С€СѓРјРѕРј Р·Р°РїРёСЃРё.
const _COLOR_EPS := 0.01
## Р¤РёР·РёРєР° РёРґС‘С‚ РЅР° 120 С‚РёРєР°С… РІ СЃРµРєСѓРЅРґСѓ (project.godot [physics]), РїРѕСЌС‚РѕРјСѓ РѕРґРёРЅ
## С‚РёРє вЂ” СЂРѕРІРЅРѕ 1/120 СЃ. РљРѕРЅС‚Р°РєС‚РЅС‹Р№ РёРЅС‚РµСЂРІР°Р» 0.1 СЃ СЂР°РІРµРЅ 12 С‚РёРєР°Рј, Рё СЃСЂР°РІРЅРµРЅРёРµ
## РєР°РґРµРЅС†РёРё РїРѕ С‚РёРєР°Рј РЅРµ Р·Р°РІРёСЃРёС‚ РѕС‚ РїР»Р°РІР°СЋС‰РµР№ РїРѕРіСЂРµС€РЅРѕСЃС‚Рё РЅР°РєРѕРїР»РµРЅРёСЏ delta.
const _TICKS_PER_SECOND := 120

var _failures: PackedStringArray = []
var _checks := 0

## РЎС‡С‘С‚С‡РёРєРё СЃРёРіРЅР°Р»РѕРІ РёРіСЂРѕРєР°, РєРѕС‚РѕСЂС‹Рµ С‡РёС‚Р°РµС‚ С‚РѕР»СЊРєРѕ РїРѕРґРєР»СЋС‡С‘РЅРЅС‹Р№ РѕР±СЂР°Р±РѕС‚С‡РёРє.
## В«died СЂРѕРІРЅРѕ РѕРґРёРЅВ» РЅРµР»СЊР·СЏ РїСЂРѕРІРµСЂРёС‚СЊ РїРѕ СѓР·Р»Сѓ РїРѕСЃР»Рµ РІС‹Р·РѕРІР°: Рє С‚РѕРјСѓ РјРѕРјРµРЅС‚Сѓ, РєР°Рє
## РїСЂРѕРІРµСЂРєР° РїРѕСЃРјРѕС‚СЂРёС‚ СЃРЅРѕРІР°, РёРіСЂРѕРє СѓР¶Рµ СЂРµСЃРїР°РІРЅРёР»СЃСЏ Рё РІС‹РіР»СЏРґРёС‚ РїРѕР»РЅРѕСЃС‚СЊСЋ
## Р·РґРѕСЂРѕРІС‹Рј. РЎС‡С‘С‚С‡РёРє РІРЅСѓС‚СЂРё РѕР±СЂР°Р±РѕС‚С‡РёРєР° вЂ” РµРґРёРЅСЃС‚РІРµРЅРЅРѕРµ РјРµСЃС‚Рѕ, РіРґРµ СЃРјРµСЂС‚СЊ РµС‰С‘
## РЅР°Р±Р»СЋРґР°РµРјР°.
var _died_count: int = 0
## Р—РґРѕСЂРѕРІСЊРµ Рё Р¶РёРІРѕСЃС‚СЊ, СѓРІРёРґРµРЅРЅС‹Рµ РѕР±СЂР°Р±РѕС‚С‡РёРєРѕРј died, С‚Рѕ РµСЃС‚СЊ РІ РјРѕРјРµРЅС‚ СЃРјРµСЂС‚Рё, РґРѕ
## С‚РѕРіРѕ РєР°Рє СЂРµСЃРїР°РІРЅ РІРѕСЃСЃС‚Р°РЅРѕРІРёС‚ РёС….
var _health_at_death: float = -1.0
var _alive_at_death: bool = true
## Р’СЃРµ РїР°СЂС‹ health_changed РїРѕ РїРѕСЂСЏРґРєСѓ: В«РїРѕСЃР»РµРґРЅРµРµ СЃРѕР±С‹С‚РёРµ 100/100В» вЂ” СѓС‚РІРµСЂР¶РґРµРЅРёРµ
## Рѕ РїРѕСЃР»РµРґРѕРІР°С‚РµР»СЊРЅРѕСЃС‚Рё, Р° РЅРµ РѕР± РѕРґРЅРѕРј СЃСЌРјРїР»Рµ.
var _health_events: Array[Vector2] = []
## РЎС‡С‘С‚С‡РёРєРё СЃРёРіРЅР°Р»РѕРІ Р’Р РђР“Рђ. РћС‚РґРµР»СЊРЅРѕ РѕС‚ РёРіСЂРѕРІС‹С…: РѕРґРёРЅ Рё С‚РѕС‚ Р¶Рµ РѕР±СЂР°Р±РѕС‚С‡РёРє РЅРµР»СЊР·СЏ
## РїРѕРІРµСЃРёС‚СЊ РЅР° РѕР±Р° СѓР·Р»Р°, Р° СЂР°Р·Р»РёС‡Р°С‚СЊ РёС… РїРѕ РёРјРµРЅРё СѓР·Р»Р° Р·РЅР°С‡РёР»Рѕ Р±С‹ Р·Р°РІСЏР·Р°С‚СЊ
## РїСЂРѕРІРµСЂРєСѓ РЅР° С‚РµРєСЃС‚ РёРјС‘РЅ.
var _enemy_died_count: int = 0
## Р—РґРѕСЂРѕРІСЊРµ Рё Р¶РёРІРѕСЃС‚СЊ РІСЂР°РіР°, СѓРІРёРґРµРЅРЅС‹Рµ РІ РјРѕРјРµРЅС‚ РµРіРѕ died. РЈ РёРіСЂРѕРєР° СЌС‚Рѕ Р±С‹Р»Рѕ
## РѕР±СЏР·Р°С‚РµР»СЊРЅРѕ (СЂРµСЃРїР°РІРЅ РІРѕСЃСЃС‚Р°РЅР°РІР»РёРІР°РµС‚ РІСЃС‘ СЃСЂР°Р·Сѓ), Сѓ РІСЂР°РіР° вЂ” СЃС‚СЂР°С…РѕРІРєР°: СЃРјРµСЂС‚СЊ
## РІСЂР°РіР° С‚РѕР¶Рµ РЅР°Р±Р»СЋРґР°РµРјР° С‚РѕР»СЊРєРѕ РІ СЃРІРѕС‘Рј РѕР±СЂР°Р±РѕС‚С‡РёРєРµ, РїРѕРєР° СѓР·РµР» РІРёСЃРёС‚ РЅР° СЃС†РµРЅРµ.
var _enemy_health_at_death: float = -1.0
var _enemy_alive_at_death: bool = true
## РЎС‡С‘С‚С‡РёРє РёРјС‘РЅС‘РЅРЅС‹С… РјРёСЂРѕРІ. РРјРµРЅР° СѓР·Р»РѕРІ СѓРЅРёРєР°Р»СЊРЅС‹ С‚РѕР»СЊРєРѕ РІРЅСѓС‚СЂРё СЂРѕРґРёС‚РµР»СЏ, Р°
## РєР°Р¶РґС‹Р№ СЃС†РµРЅР°СЂРёР№ РґРѕР±Р°РІР»СЏРµС‚ СЃРІРѕР№ РїРѕР» РІ СЃРІРѕР№ РєРѕРЅС‚РµР№РЅРµСЂ: Р±РµР· СЃС‡С‘С‚С‡РёРєР° РІС‚РѕСЂРѕР№
## РїРѕР» РїРѕР»СѓС‡РёР» Р±С‹ "Floor2" Рё СЃРѕРѕР±С‰РµРЅРёРµ РѕР± РѕС€РёР±РєРµ РЅР°Р·С‹РІР°Р»Рѕ Р±С‹ РЅРµ С‚РѕС‚ СѓР·РµР».
var _world_id: int = 0
## РџСЂРѕРІРµСЂРєР° СѓРїС‘СЂР»Р°СЃСЊ РІ РЅРµРІС‹РїРѕР»РЅРёРјРѕРµ СѓСЃР»РѕРІРёРµ Рё РІС‹Р·РІР°Р»Р° _bail(). Р¤Р»Р°Рі РѕР±СЏР·Р°С‚РµР»РµРЅ:
## _bail() Р·РѕРІС‘С‚ quit(1), РЅРѕ РІС‹Р·С‹РІР°РІС€РёР№ СЂР°Р·РґРµР» РґРµР»Р°РµС‚ `return`, Р° _initialize()
## РїРѕСЃР»Рµ РЅРµРіРѕ РІСЃС‘ СЂР°РІРЅРѕ РґРѕС…РѕРґРёС‚ РґРѕ СЃРІРѕРµРіРѕ quit(0) вЂ” Р° РїРѕСЃР»РµРґРЅРёР№ РІС‹Р·РѕРІ quit()
## РїРµСЂРµР·Р°РїРёСЃС‹РІР°РµС‚ РєРѕРґ РІРѕР·РІСЂР°С‚Р°, Рё РїСЂРѕРІРµСЂРєР° СЃ FATAL С‡РёС‚Р°Р»Р°СЃСЊ Р±С‹ РєР°Рє PASS.
var _bailed: bool = false


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
	_bailed = true
	print("FATAL: %s" % reason)
	_finish()
	quit(1)


## РЎРєРѕР»СЊРєРѕ Р·РґРѕСЂРѕРІСЊСЏ РѕСЃС‚Р°Р»РѕСЃСЊ Сѓ СѓР·Р»Р° РёРіСЂРѕРєР°. РњРµС‚РѕРґС‹ Р±РµСЂСѓС‚СЃСЏ РІС‹Р·РѕРІРѕРј call(), Р° РЅРµ
## С‚РёРїРёР·РёСЂРѕРІР°РЅРЅС‹Рј РґРѕСЃС‚СѓРїРѕРј: player.tscn РѕС‚РґР°С‘С‚ CharacterBody3D, Р° health()/
## is_alive() Р¶РёРІСѓС‚ РІ player.gd, Рё С…Р°СЂРґРєРѕРґ С‚РёРїР° Р·РґРµСЃСЊ РѕР·РЅР°С‡Р°Р» Р±С‹, С‡С‚Рѕ РїСЂРѕРІРµСЂРєР°
## РїРµСЂРµСЃС‚Р°Р»Р° РІРёРґРµС‚СЊ РЅР°СЃС‚РѕСЏС‰РёР№ СЃРєСЂРёРїС‚.
func _health(player: Node) -> float:
	return float(player.call("health"))


func _alive(player: Node) -> bool:
	return bool(player.call("is_alive"))


func _near(got: float, want: float) -> bool:
	return absf(got - want) < _HEALTH_EPS


## Р–РёРІРѕСЃС‚СЊ Рё Р·РґРѕСЂРѕРІСЊРµ С‡РёС‚Р°СЋС‚СЃСЏ РѕР±СЂР°Р±РѕС‚С‡РёРєРѕРј РІ РјРѕРјРµРЅС‚ СЃРёРіРЅР°Р»Р°, Р° РЅРµ РїРѕСЃР»Рµ
## РІРѕР·РІСЂР°С‚Р° РёР· take_damage: Рє РјРѕРјРµРЅС‚Сѓ РІРѕР·РІСЂР°С‚Р° СЂРµСЃРїР°РІРЅ СѓР¶Рµ РІСЃС‘ РІРѕСЃСЃС‚Р°РЅРѕРІРёР».
func _on_player_died(player: Node) -> void:
	_died_count += 1
	_health_at_death = _health(player)
	_alive_at_death = _alive(player)


func _on_player_health_changed(current: float, maximum: float) -> void:
	_health_events.append(Vector2(current, maximum))


## РЎРѕР·РґР°С‘С‚ СѓР·РµР», Р¶РґС‘С‚ РµРіРѕ РіРѕС‚РѕРІРЅРѕСЃС‚Рё Рё РІРѕР·РІСЂР°С‰Р°РµС‚ false, РµСЃР»Рё РѕРЅ С‚Р°Рє Рё РЅРµ СЃС‚Р°Р»
## РіРѕС‚РѕРІ. is_node_ready() РїСЂРѕРІРµСЂСЏРµС‚СЃСЏ СЏРІРЅРѕ: _ready() РЅРµ СЃРёРЅС…СЂРѕРЅРµРЅ РѕС‚РЅРѕСЃРёС‚РµР»СЊРЅРѕ
## instantiate(), Рё РїСЂРѕРІРµСЂРєР°, С‡РёС‚Р°СЋС‰Р°СЏ СЃР»РѕРё РґРѕ РіРѕС‚РѕРІРЅРѕСЃС‚Рё, РјРµСЂСЏР»Р° Р±С‹ Р·РЅР°С‡РµРЅРёСЏ РїРѕ
## СѓРјРѕР»С‡Р°РЅРёСЋ, Р° РЅРµ Р·Р°РґР°РЅРЅС‹Рµ СЃРєСЂРёРїС‚РѕРј.
func _spawn_and_wait(node: Node) -> bool:
	root.add_child(node)
	for i in 120:
		if node.is_node_ready():
			return true
		await physics_frame
	return node.is_node_ready()


## Р’С‚РѕСЂРѕР№ СЂР°Р·РґРµР»: Р·РґРѕСЂРѕРІСЊРµ РёРіСЂРѕРєР° Рё Р·РѕРЅР° РµРіРѕ С…РёС‚Р±РѕРєСЃР°.
##
## Р’СЃС‘ СЃРѕСЃС‚РѕСЏРЅРёРµ С‡РёС‚Р°РµС‚СЃСЏ СЃ РЅР°СЃС‚РѕСЏС‰РµРіРѕ РёРЅСЃС‚Р°РЅСЃР° player.tscn. РЎР»РѕР№ С…РёС‚Р±РѕРєСЃР°
## РїСЂРѕРІРµСЂСЏРµС‚СЃСЏ Рё РЅР° РґРµС„РѕР»С‚РЅРѕРј Hurtbox.new() вЂ” СЌС‚Рѕ РєРѕРЅС‚СЂР°РєС‚ Р¤Р°Р·С‹ 1 РґР»СЏ РјРёС€РµРЅРµР№ Рё
## РІСЂР°РіРѕРІ, РєРѕС‚РѕСЂС‹Р№ РЅРѕРІР°СЏ РЅР°СЃС‚СЂРѕР№РєР° Р·РѕРЅС‹ РѕР±СЏР·Р°РЅР° СЃРѕС…СЂР°РЅРёС‚СЊ, Р° РЅРµ Р·Р°РјРµРЅРёС‚СЊ.
func _test_player_health() -> void:
	print("-- Р—РґРѕСЂРѕРІСЊРµ РёРіСЂРѕРєР° (Task 2)")

	_died_count = 0
	_health_at_death = -1.0
	_alive_at_death = true
	_health_events.clear()

	var packed: PackedScene = load(_PLAYER_PATH)
	if packed == null:
		_bail("cannot load %s" % _PLAYER_PATH)
		return
	var player := packed.instantiate()
	if not await _spawn_and_wait(player):
		_bail("%s never became node-ready" % _PLAYER_PATH)
		return
	_check(player.is_node_ready(), "precondition: player.tscn is instantiated and node-ready")

	print("-- РґРµС„РѕР»С‚РЅС‹Р№ Hurtbox СЃРѕС…СЂР°РЅСЏРµС‚ РєРѕРЅС‚СЂР°РєС‚ Р¤Р°Р·С‹ 1")
	var plain := Hurtbox.new()
	if not await _spawn_and_wait(plain):
		_bail("a bare Hurtbox.new() never became node-ready")
		return
	_check(plain.collision_layer == _LAYER_ENEMY_HURTBOX,
		"РґРµС„РѕР»С‚РЅС‹Р№ Hurtbox.new() Р»РµР¶РёС‚ РЅР° СЃР»РѕРµ 4 (enemy_hurtbox)",
		"(got %d, expected %d)" % [plain.collision_layer, _LAYER_ENEMY_HURTBOX])
	_check(not plain.monitoring,
		"РґРµС„РѕР»С‚РЅС‹Р№ Hurtbox.new() РЅРёС‡РµРіРѕ РЅРµ РѕР±РЅР°СЂСѓР¶РёРІР°РµС‚ СЃР°Рј",
		"(monitoring=%s)" % plain.monitoring)

	print("-- РІ player.tscn РµСЃС‚СЊ СѓР·РµР» Hurtbox РІ Р·РѕРЅРµ РёРіСЂРѕРєР°")
	var hurtbox := player.get_node_or_null("Hurtbox") as Hurtbox
	# РќР°Р»РёС‡РёРµ API СЃРїСЂР°С€РёРІР°РµС‚СЃСЏ С‡РµСЂРµР· has_method/has_signal, Р° РЅРµ РїСЂСЏРјС‹Рј
	# РѕР±СЂР°С‰РµРЅРёРµРј: РѕР±СЂР°С‰РµРЅРёРµ Рє РѕС‚СЃСѓС‚СЃС‚РІСѓСЋС‰РµРјСѓ С‡Р»РµРЅСѓ вЂ” СЂР°РЅС‚Р°Р№Рј-РѕС€РёР±РєР°, Рё РїСЂРѕРІРµСЂРєР°
	# СѓРїР°Р»Р° Р±С‹ СЃ С‚СЂР°СЃСЃРёСЂРѕРІРєРѕР№ РІРјРµСЃС‚Рѕ РёРјРµРЅРѕРІР°РЅРЅРѕРіРѕ [FAIL].
	_check(hurtbox != null, "Сѓ player.tscn РµСЃС‚СЊ РґРѕС‡РµСЂРЅРёР№ СѓР·РµР» Hurtbox")
	_check(_health_api_ready(player),
		"Сѓ player.gd РµСЃС‚СЊ API Р·РґРѕСЂРѕРІСЊСЏ Р¤Р°Р·С‹ 2: health, is_alive, take_damage, died, health_changed")
	if hurtbox == null or not _health_api_ready(player):
		print("  (РѕС†РµРЅРєР° СѓСЂРѕРЅР° РЅРµРІРѕР·РјРѕР¶РЅР° Р±РµР· С…РёС‚Р±РѕРєСЃР° Рё API Р·РґРѕСЂРѕРІСЊСЏ: РїСЂРѕРІРµСЂРєРё РЅРёР¶Рµ РїСЂРѕРїСѓС‰РµРЅС‹)")
		return
	_check(hurtbox.zone == 1, "С…РёС‚Р±РѕРєСЃ РёРіСЂРѕРєР° РѕР±СЉСЏРІР»РµРЅ РІ Р·РѕРЅРµ 1 (player_hurtbox)",
		"(got zone %d)" % hurtbox.zone)
	_check(hurtbox.collision_layer == _LAYER_PLAYER_HURTBOX,
		"РїРѕСЃР»Рµ РіРѕС‚РѕРІРЅРѕСЃС‚Рё С…РёС‚Р±РѕРєСЃ РёРіСЂРѕРєР° Р»РµР¶РёС‚ РЅР° СЃР»РѕРµ 7 (player_hurtbox)",
		"(got %d, expected %d)" % [hurtbox.collision_layer, _LAYER_PLAYER_HURTBOX])

	print("-- СЃС‚Р°СЂС‚РѕРІРѕРµ СЃРѕСЃС‚РѕСЏРЅРёРµ")
	_check(_near(_health(player), 100.0), "РёРіСЂРѕРє РЅР°С‡РёРЅР°РµС‚ СЃ 100 Р·РґРѕСЂРѕРІСЊСЏ",
		"(got %.4f)" % _health(player))
	_check(_alive(player), "РёРіСЂРѕРє РЅР°С‡РёРЅР°РµС‚ Р¶РёРІ")

	print("-- 10 РїРѕРїР°РґР°РЅРёР№ РєРѕРЅС‚Р°РєС‚РЅРѕРіРѕ РІСЂР°РіР° РґРѕ СЃРјРµСЂС‚Рё РёРіСЂРѕРєР° (СЃРїРµРєР° 7.2)")
	var contact := load(_CONTACT_PATH) as EnemyData
	if contact == null:
		_bail("cannot load %s as EnemyData for the player survivability invariant" % _CONTACT_PATH)
		return
	var hits_to_death := float(player.get("max_health")) / contact.contact_damage
	_check(absf(hits_to_death - 10.0) < _HEALTH_EPS,
		"10 РїРѕРїР°РґР°РЅРёР№ РґРѕ СЃРјРµСЂС‚Рё РёРіСЂРѕРєР°",
		"(max_health %.4f / contact_damage %.4f = %.4f)" % [
			float(player.get("max_health")), contact.contact_damage, hits_to_death])

	print("-- РїРѕРґРєР»СЋС‡РµРЅРёРµ РѕР±СЂР°Р±РѕС‚С‡РёРєРѕРІ СЃРёРіРЅР°Р»РѕРІ РёРіСЂРѕРєР°")
	player.died.connect(_on_player_died.bind(player))
	player.health_changed.connect(_on_player_health_changed)

	# РџРѕСЂСЏРґРѕРє С€Р°РіРѕРІ РѕС‚Р»РёС‡Р°РµС‚СЃСЏ РѕС‚ РїРѕСЂСЏРґРєР° СѓС‚РІРµСЂР¶РґРµРЅРёР№ РІ Р±СЂРёС„Рµ, Рё СЌС‚Рѕ РІС‹РЅСѓР¶РґРµРЅРЅРѕ:
	# В«take_damage(90.0) в†’ health() == 10.0В» Рё В«РґРµСЃСЏС‚РѕРµ take_damage(10.0) в†’
	# СЃРјРµСЂС‚СЊВ» СЃС‡РёС‚Р°СЋС‚ РѕС‚ 100 HP, Р° РїСЂРѕРІРµСЂРєР° РїСЂРѕРІРѕРґРєРё СѓР¶Рµ СЃСЉРµРґР°РµС‚ 10 HP. РћР±Рµ
	# РїРѕСЃР»РµРґРѕРІР°С‚РµР»СЊРЅРѕСЃС‚Рё РЅР° РѕРґРЅРѕРј РёРіСЂРѕРєРµ РЅРµ СЃС…РѕРґСЏС‚СЃСЏ, РїРѕСЌС‚РѕРјСѓ СЃРЅР°С‡Р°Р»Р° РёРґС‘С‚
	# РїРѕР»РЅС‹Р№ С†РёРєР» СѓСЂРѕРЅР° РґРѕ СЃРјРµСЂС‚Рё, Р° РїСЂРѕРІРѕРґРєР° РїСЂРѕРІРµСЂСЏРµС‚СЃСЏ РЅР° С‚РѕР»СЊРєРѕ С‡С‚Рѕ
	# РІРѕСЃСЃС‚Р°РЅРѕРІР»РµРЅРЅРѕРј РёРіСЂРѕРєРµ вЂ” РµС‘ СѓС‚РІРµСЂР¶РґРµРЅРёРµ (100 - 10 = 90) РѕС‚ СЂРµСЃРїР°РІРЅР° РЅРµ
	# Р·Р°РІРёСЃРёС‚.
	player.call("take_damage", 90.0)
	_check(_alive(player), "РґРµРІСЏС‚РѕРµ РїРѕРїР°РґР°РЅРёРµ РЅРµ СѓР±РёРІР°РµС‚ РёРіСЂРѕРєР°")
	_check(_near(_health(player), 10.0), "РїРѕСЃР»Рµ РґРµРІСЏС‚Рё С‚РёРєРѕРІ РѕСЃС‚Р°С‘С‚СЃСЏ 10 Р·РґРѕСЂРѕРІСЊСЏ",
		"(got %.4f)" % _health(player))

	print("-- РґРµСЃСЏС‚РѕРµ РїРѕРїР°РґР°РЅРёРµ: СЃРјРµСЂС‚СЊ Рё РЅРµРјРµРґР»РµРЅРЅС‹Р№ СЂРµСЃРїР°РІРЅ")
	player.call("take_damage", 10.0)
	_check(_died_count == 1, "СЃРёРіРЅР°Р» died СЂРѕРІРЅРѕ РѕРґРёРЅ", "(got %d)" % _died_count)
	_check(not _alive_at_death, "РІ РјРѕРјРµРЅС‚ СЃРёРіРЅР°Р»Р° died РёРіСЂРѕРє СѓР¶Рµ РјС‘СЂС‚РІ (is_alive() == false)",
		"(got %s)" % _alive_at_death)
	_check(_near(_health_at_death, 0.0), "РІ РјРѕРјРµРЅС‚ СЃРёРіРЅР°Р»Р° died Р·РґРѕСЂРѕРІСЊРµ СЂР°РІРЅРѕ 0.0",
		"(got %.4f)" % _health_at_death)
	_check(_near(_health(player), 100.0), "РїРѕСЃР»Рµ СЃРјРµСЂС‚Рё 100.0 (СЂРµСЃРїР°РІРЅ РІРѕСЃСЃС‚Р°РЅРѕРІРёР» Р·РґРѕСЂРѕРІСЊРµ)",
		"(got %.4f)" % _health(player))
	_check(_alive(player), "РїРѕСЃР»Рµ СЃРјРµСЂС‚Рё РёРіСЂРѕРє СЃРЅРѕРІР° Р¶РёРІ")

	print("-- health_changed РёСЃРїСѓС‰РµРЅ СЃ РЅР°СЃС‚РѕСЏС‰РёРјРё С‡РёСЃР»Р°РјРё")
	var max_health := float(player.get("max_health"))
	_check(_health_events.size() > 0, "health_changed РёСЃРїСѓС‰РµРЅ С…РѕС‚СЏ Р±С‹ СЂР°Р·",
		"(events=%d)" % _health_events.size())
	if not _health_events.is_empty():
		var last := _health_events[_health_events.size() - 1]
		_check(_near(last.x, 100.0) and _near(last.y, max_health),
			"РїРѕСЃР»РµРґРЅРµРµ СЃРѕР±С‹С‚РёРµ health_changed РїРѕСЃР»Рµ СЂРµСЃРїР°РІРЅР° вЂ” 100.0/max_health",
			"(got %.4f/%.4f)" % [last.x, last.y])
		var death_event := _find_health_event(0.0)
		_check(_near(death_event.x, 0.0) and _near(death_event.y, max_health),
			"СЃРјРµСЂС‚СЊ РѕС‚СЂР°Р¶РµРЅР° СЃРѕР±С‹С‚РёРµРј 0.0/max_health",
			"(got %.4f/%.4f)" % [death_event.x, death_event.y])

	print("-- РїСЂРѕРІРѕРґРєР° СЃС†РµРЅС‹: Hurtbox.damage_taken -> Player.take_damage")
	hurtbox.apply_damage(10.0)
	_check(_near(_health(player), 90.0),
		"СѓСЂРѕРЅ С‡РµСЂРµР· СѓР·РµР» Hurtbox СЃС†РµРЅС‹ РґРѕС…РѕРґРёС‚ РґРѕ РёРіСЂРѕРєР° РїРѕ СЃРёРіРЅР°Р»Сѓ damage_taken",
		"(got %.4f)" % _health(player))
	var hit_event := _find_health_event(90.0)
	_check(_near(hit_event.x, 90.0) and _near(hit_event.y, max_health),
		"РїРѕРїР°РґР°РЅРёРµ С‡РµСЂРµР· Hurtbox РѕС‚СЂР°Р¶РµРЅРѕ СЃРѕР±С‹С‚РёРµРј 90.0/max_health",
		"(got %.4f/%.4f)" % [hit_event.x, hit_event.y])

	print("-- РЅСѓР»РµРІРѕР№ Рё РѕС‚СЂРёС†Р°С‚РµР»СЊРЅС‹Р№ СѓСЂРѕРЅ РёРіРЅРѕСЂРёСЂСѓСЋС‚СЃСЏ")
	player.call("take_damage", 0.0)
	player.call("take_damage", -5.0)
	_check(_near(_health(player), 90.0), "РЅСѓР»РµРІРѕР№ Рё РѕС‚СЂРёС†Р°С‚РµР»СЊРЅС‹Р№ СѓСЂРѕРЅ РЅРµ РјРµРЅСЏСЋС‚ Р·РґРѕСЂРѕРІСЊРµ",
		"(got %.4f)" % _health(player))
	_check(_died_count == 1, "РЅСѓР»РµРІРѕР№ Рё РѕС‚СЂРёС†Р°С‚РµР»СЊРЅС‹Р№ СѓСЂРѕРЅ РЅРµ РёСЃРїСѓСЃРєР°СЋС‚ died",
		"(got %d)" % _died_count)

	player.queue_free()
	plain.queue_free()


## РЎСѓС‰РµСЃС‚РІСѓРµС‚ Р»Рё РЅР° СѓР·Р»Рµ РІРµСЃСЊ API Р·РґРѕСЂРѕРІСЊСЏ Р¤Р°Р·С‹ 2. РћС‚РґРµР»СЊРЅР°СЏ С„СѓРЅРєС†РёСЏ, РїРѕС‚РѕРјСѓ С‡С‚Рѕ
## РѕС‚РІРµС‚ РЅСѓР¶РµРЅ РґРІР°Р¶РґС‹: РёРјРµРЅРѕРІР°РЅРЅС‹Рј [FAIL] Рё СЂРµС€РµРЅРёРµРј, РјРѕР¶РЅРѕ Р»Рё РІРѕРѕР±С‰Рµ РѕС†РµРЅРёРІР°С‚СЊ
## СѓСЂРѕРЅ, РЅРµ СѓРїР°РІ РІ СЂР°РЅС‚Р°Р№Рј.
func _health_api_ready(player: Node) -> bool:
	return player.has_method("health") and player.has_method("is_alive") \
		and player.has_method("take_damage") \
		and player.has_signal("died") and player.has_signal("health_changed")


## РС‰РµС‚ РїРµСЂРІРѕРµ СЃРѕР±С‹С‚РёРµ health_changed СЃ С‚Р°РєРёРј Р·РЅР°С‡РµРЅРёРµРј Р·РґРѕСЂРѕРІСЊСЏ. РћС‚СЃСѓС‚СЃС‚РІРёРµ
## СЃРѕР±С‹С‚РёСЏ РІРѕР·РІСЂР°С‰Р°РµС‚ (-1.0, -1.0): РїР°СЂР°, РєРѕС‚РѕСЂСѓСЋ РЅРµ СЃ С‡РµРј СЃСЂР°РІРЅРёС‚СЊ, Рё
## _check() РЅР° РЅРµР№ С‡РµСЃС‚РЅРѕ РїР°РґР°РµС‚.
func _find_health_event(value: float) -> Vector2:
	for event in _health_events:
		if _near(event.x, value):
			return event
	return Vector2(-1.0, -1.0)


# --------------------------------------------------------------------------
# Task 3: РєРѕРЅС‚Р°РєС‚РЅС‹Р№ РІСЂР°Рі
# --------------------------------------------------------------------------

## РўСЂРµС‚РёР№ СЂР°Р·РґРµР»: РІСЂР°Рі С†РµР»РёРєРѕРј РёР· СЃРІРѕРµР№ СЃС†РµРЅС‹.
##
## Р§С‚Рѕ РіСЂСѓР·РёС‚СЃСЏ РёР· СЃС†РµРЅС‹, Р° С‡С‚Рѕ СЃРѕР±РёСЂР°РµС‚СЃСЏ РєРѕРґРѕРј, СЂР°Р·РјРµС‡РµРЅРѕ Р·РґРµСЃСЊ РЅР°РјРµСЂРµРЅРЅРѕ.
## РЎС†РµРЅР° `enemy_contact.tscn` вЂ” СЌС‚Рѕ РїСЂРµРґРјРµС‚ РїСЂРѕРІРµСЂРєРё: РёРјРµРЅРЅРѕ РІ РЅРµР№ С…СЂР°РЅСЏС‚СЃСЏ
## СЃСЃС‹Р»РєР° РЅР° РґР°РЅРЅС‹Рµ, СЃР»РѕРё С…РёС‚Р±РѕРєСЃР° Рё РєР°РїСЃСѓР»Р°, Рё С…Р°СЂРЅРµСЃСЃ, СЃРѕР±СЂР°РІС€РёР№ Р±С‹ С‚РѕРіРѕ Р¶Рµ
## РІСЂР°РіР° РёР· СѓР·Р»РѕРІ РєРѕРґР°, РѕСЃС‚Р°Р»СЃСЏ Р±С‹ Р·РµР»С‘РЅС‹Рј РЅР° СЃС†РµРЅРµ Р±РµР· С…РёС‚Р±РѕРєСЃР° РІРѕРѕР±С‰Рµ.
## РџРѕР» Рё СЃС‚РµРЅР° вЂ” РѕРєСЂСѓР¶РµРЅРёРµ, Р° РЅРµ РїСЂРµРґРјРµС‚ РїСЂРѕРІРµСЂРєРё, Рё Р±РµСЂСѓС‚СЃСЏ РёР· РєРѕРґР°, РєР°Рє РІ
## tests/projectile.gd.
func _test_contact_enemy() -> void:
	print("-- РљРѕРЅС‚Р°РєС‚РЅС‹Р№ РІСЂР°Рі (Task 3)")

	var packed: PackedScene = load(_ENEMY_PATH)
	if packed == null:
		_bail("cannot load %s" % _ENEMY_PATH)
		return
	var world := _new_world()
	_add_floor(world)
	var enemy := packed.instantiate()
	if not await _spawn_in(world, enemy, Vector3(6.0, 0.0, 0.0)):
		_bail("%s never became node-ready" % _ENEMY_PATH)
		return
	_check(enemy.is_node_ready(), "precondition: enemy_contact.tscn is instantiated and node-ready")

	print("-- СЃС†РµРЅР° Рё РєР»Р°СЃСЃ РІСЂР°РіР°")
	# РўРёРї РєРѕСЂРЅСЏ РїСЂРѕРІРµСЂСЏРµС‚СЃСЏ С‡РµСЂРµР· get_script(), Р° РЅРµ С‡РµСЂРµР· `enemy is
	# ContactEnemy`: РёРјСЏ РєР»Р°СЃСЃР° РїРѕСЏРІРёС‚СЃСЏ С‚РѕР»СЊРєРѕ РІРјРµСЃС‚Рµ СЃ Task 3, Р° СЃС‚Р°С‚РёС‡РµСЃРєР°СЏ
	# СЃСЃС‹Р»РєР° РЅР° РЅРµСЃСѓС‰РµСЃС‚РІСѓСЋС‰РёР№ class_name СѓР±РёР»Р° Р±С‹ РІРµСЃСЊ С„Р°Р№Р» РЅР° СЂР°Р·Р±РѕСЂРµ вЂ”
	# РІРјРµСЃС‚Рµ СЃ РґРІСѓРјСЏ СѓР¶Рµ РіРѕС‚РѕРІС‹РјРё СЂР°Р·РґРµР»Р°РјРё.
	var script_res := enemy.get_script() as Script
	_check(enemy is CharacterBody3D,
		"РєРѕСЂРµРЅСЊ enemy_contact.tscn вЂ” CharacterBody3D (Р° РЅРµ Node3D Рё РЅРµ Area3D)",
		"(got %s)" % ("none" if script_res == null else script_res.get_instance_base_type()))
	_check(script_res != null and script_res.get_global_name() == "ContactEnemy",
		"СЃРєСЂРёРїС‚ РІСЂР°РіР° РѕР±СЉСЏРІР»СЏРµС‚ class_name ContactEnemy",
		"(got \"%s\")" % ("none" if script_res == null else script_res.get_global_name()))
	_check(_enemy_api_ready(enemy),
		"Сѓ enemy_contact.gd РµСЃС‚СЊ API Р¤Р°Р·С‹ 2: health, is_alive, take_damage, died, health_changed")

	print("-- РґР°РЅРЅС‹Рµ РІСЂР°РіР° РёР· res://data/enemies/contact.tres")
	# data С‡РёС‚Р°РµС‚СЃСЏ С‡РµСЂРµР· get(), Р° РЅРµ РїСЂСЏРјС‹Рј РѕР±СЂР°С‰РµРЅРёРµРј: СЃС†РµРЅР° РѕС‚РґР°С‘С‚
	# CharacterBody3D, Рё РїРѕР»Рµ data Р¶РёРІС‘С‚ РІ СЃРєСЂРёРїС‚Рµ. РћР±СЂР°С‰РµРЅРёРµ Рє РѕС‚СЃСѓС‚СЃС‚РІСѓСЋС‰РµРјСѓ
	# С‡Р»РµРЅСѓ вЂ” СЂР°РЅС‚Р°Р№Рј-РѕС€РёР±РєР°, Р° РїСЂРѕРІРµСЂРєР° РѕР±СЏР·Р°РЅР° РїР°РґР°С‚СЊ РёРјРµРЅРѕРІР°РЅРЅРѕ.
	var data: EnemyData = enemy.get("data")
	_check(data is EnemyData, "Сѓ РІСЂР°РіР° РµСЃС‚СЊ data С‚РёРїР° EnemyData",
		"(got %s)" % type_string(typeof(enemy.get("data"))))
	_check(data != null and data.resource_path == _CONTACT_PATH,
		"data РІСЂР°РіР° вЂ” РёРјРµРЅРЅРѕ res://data/enemies/contact.tres",
		"(got \"%s\")" % ("none" if data == null else data.resource_path))
	if data != null:
		_check(_near(data.max_health, 50.0), "max_health РґР°РЅРЅС‹С… РІСЂР°РіР° СЂР°РІРµРЅ 50.0",
			"(got %.4f)" % data.max_health)
		_check(_near(data.contact_damage, 10.0), "contact_damage РґР°РЅРЅС‹С… РІСЂР°РіР° СЂР°РІРµРЅ 10.0",
			"(got %.4f)" % data.contact_damage)

	print("-- РїСЂРѕРІРѕРґРєР° СЃР»РѕС‘РІ: С‚РµР»Рѕ РЅР° 3, С…РёС‚Р±РѕРєСЃ РЅР° 4, РґРµС‚РµРєС‚ РЅР° СЃС‚РѕСЂРѕРЅРµ РІСЂР°РіР°")
	# РЎР»РѕРё Р·Р°РґР°СЋС‚СЃСЏ СЃРєСЂРёРїС‚РѕРј РІ _ready(), Р° РЅРµ СЃС†РµРЅРѕР№: Р·РЅР°С‡РµРЅРёРµ РІ СЃС†РµРЅРµ РјРѕР»С‡Р°
	# СЂР°Р·СЉРµС…Р°Р»РѕСЃСЊ Р±С‹ СЃ Р»РѕРіРёРєРѕР№, Рё СЃРЅСЏС‚РёРµ СЃР»РѕСЏ СЃ РІСЂР°РіР° РЅРёРєС‚Рѕ РЅРµ Р·Р°РјРµС‚РёР» Р±С‹.
	# РЎРІРµСЂС… С‚РѕРіРѕ, РјР°СЃРєР° С‚РµР»Р° Р±РµР· СЃР»РѕСЏ 7 (РёРіСЂРѕРєР°) вЂ” РѕС‚РґРµР»СЊРЅРѕРµ РїСЂР°РІРёР»Рѕ СЃРїРµРєРё В§6.3:
	# РІСЂР°Рі РїСЂРѕС…РѕРґРёС‚ СЃРєРІРѕР·СЊ С‚РµР»Рѕ РёРіСЂРѕРєР°, РєРѕРЅС‚Р°РєС‚ Р»РѕРІРёС‚СЃСЏ С…РёС‚Р±РѕРєСЃР°РјРё.
	_check(int(enemy.collision_layer) == _LAYER_ENEMY_BODY,
		"С‚РµР»Рѕ РІСЂР°РіР° Р»РµР¶РёС‚ РЅР° СЃР»РѕРµ 3 (enemy_body)",
		"(got %d, expected %d)" % [int(enemy.collision_layer), _LAYER_ENEMY_BODY])
	_check(int(enemy.collision_mask) == (_LAYER_WORLD | _LAYER_ENEMY_BODY),
		"РјР°СЃРєР° С‚РµР»Р° РІСЂР°РіР° вЂ” СЃР»РѕРё 1 Рё 3: РјРёСЂ Рё СЃРІРѕРё; С‚РµР»Р° РёРіСЂРѕРєР° РІ РЅРµР№ РЅРµС‚ (СЃРїРµРєР° 6.3)",
		"(got %d, expected %d)" % [
			int(enemy.collision_mask), (_LAYER_WORLD | _LAYER_ENEMY_BODY)])
	var hurtbox := enemy.get_node_or_null("Hurtbox") as Hurtbox
	_check(hurtbox != null, "Сѓ РІСЂР°РіР° РµСЃС‚СЊ РґРѕС‡РµСЂРЅРёР№ СѓР·РµР» Hurtbox")
	if hurtbox != null:
		_check(hurtbox.zone == 0, "С…РёС‚Р±РѕРєСЃ РІСЂР°РіР° РѕР±СЉСЏРІР»РµРЅ РІ Р·РѕРЅРµ 0 (enemy_hurtbox)",
			"(got zone %d)" % hurtbox.zone)
		_check(bool(hurtbox.detects_contact),
			"С…РёС‚Р±РѕРєСЃ РІСЂР°РіР° СЃР°Рј РѕР±РЅР°СЂСѓР¶РёРІР°РµС‚ РєРѕРЅС‚Р°РєС‚: detects_contact == true")
		_check(int(hurtbox.collision_layer) == _LAYER_ENEMY_HURTBOX,
			"РїРѕСЃР»Рµ РіРѕС‚РѕРІРЅРѕСЃС‚Рё С…РёС‚Р±РѕРєСЃ РІСЂР°РіР° Р»РµР¶РёС‚ РЅР° СЃР»РѕРµ 4 (enemy_hurtbox)",
			"(got %d, expected %d)" % [int(hurtbox.collision_layer), _LAYER_ENEMY_HURTBOX])
		_check(bool(hurtbox.monitoring),
			"С…РёС‚Р±РѕРєСЃ РІСЂР°РіР° РѕР±РЅР°СЂСѓР¶РёРІР°РµС‚: monitoring == true (РєРѕРЅС‚Р°РєС‚ Р»РѕРІРёС‚ РІСЂР°Рі, СЃРїРµРєР° 6.3)")
		_check(int(hurtbox.collision_mask) == _LAYER_PLAYER_HURTBOX,
			"РјР°СЃРєР° С…РёС‚Р±РѕРєСЃР° РІСЂР°РіР° вЂ” СЃР»РѕР№ 7 (player_hurtbox): РѕРЅ РёС‰РµС‚ РёРіСЂРѕРєР°",
			"(got %d, expected %d)" % [int(hurtbox.collision_mask), _LAYER_PLAYER_HURTBOX])
	var shape := hurtbox.get_node_or_null("CollisionShape3D") if hurtbox != null else null
	_check(shape != null, "Сѓ С…РёС‚Р±РѕРєСЃР° РІСЂР°РіР° РµСЃС‚СЊ CollisionShape3D: РїСѓСЃС‚Р°СЏ Р·РѕРЅР° РЅРёС‡РµРіРѕ РЅРµ РїРѕР№РјР°РµС‚")

	print("-- РјР°С‚РµСЂРёР°Р» РјРµС€Р°")
	# РЈСЂРѕРє range_target.gd: РјР°С‚РµСЂРёР°Р» РёР· СЃС†РµРЅС‹ вЂ” РѕР±С‰РёР№ SubResource, Рё РїРµСЂРµРєСЂР°СЃРєР°
	# РѕРґРЅРѕРіРѕ РІСЂР°РіР° РїРµСЂРµРєСЂР°СЃРёР»Р° Р±С‹ РёС… РІСЃРµС…. РџСЂРѕРІРµСЂСЏРµС‚СЃСЏ СЃСЂР°РІРЅРµРЅРёРµРј РґРІСѓС…
	# РёРЅСЃС‚Р°РЅСЃРѕРІ РѕРґРЅРѕР№ СЃС†РµРЅС‹, Р° РЅРµ РЅР° РіР»Р°Р·.
	var mesh := enemy.get_node_or_null("Mesh") as MeshInstance3D
	_check(mesh != null, "Сѓ РІСЂР°РіР° РµСЃС‚СЊ СѓР·РµР» Mesh (MeshInstance3D)")
	var twin := packed.instantiate()
	twin.name = "TwinEnemy"
	if not await _spawn_in(world, twin, Vector3(6.0, 0.0, 4.0)):
		_bail("the twin enemy of %s never became node-ready" % _ENEMY_PATH)
		return
	var twin_mesh := twin.get_node_or_null("Mesh") as MeshInstance3D
	var material := mesh.material_override as StandardMaterial3D if mesh != null else null
	var twin_material := twin_mesh.material_override as StandardMaterial3D if twin_mesh != null else null
	_check(material != null, "РјРµС€ РІСЂР°РіР° РЅРµСЃС‘С‚ material_override, РєРѕС‚РѕСЂС‹Р№ РјРѕР¶РЅРѕ РѕР±РµСЃС†РІРµС‚РёС‚СЊ")
	_check(material != null and twin_material != null and material != twin_material,
		"РґРІР° РІСЂР°РіР° РёР· РѕРґРЅРѕР№ СЃС†РµРЅС‹ РїРѕР»СѓС‡РёР»Рё Р РђР—РќР«Р• РјР°С‚РµСЂРёР°Р»С‹ (РґСѓР±Р»РёСЂРѕРІР°РЅРёРµ РІ _ready)")
	if material != null:
		_check(_color_near(material.albedo_color, data.color),
			"Р¶РёРІРѕР№ РІСЂР°Рі РїРѕРєСЂР°С€РµРЅ РІ С†РІРµС‚ СЃРІРѕРёС… РґР°РЅРЅС‹С… (data.color)",
			"(got %s, data.color %s)" % [str(material.albedo_color), str(data.color)])

	print("-- СЃС‚Р°СЂС‚РѕРІРѕРµ СЃРѕСЃС‚РѕСЏРЅРёРµ")
	_check(_near(_enemy_health(enemy), 50.0), "РІСЂР°Рі РЅР°С‡РёРЅР°РµС‚ СЃ 50 Р·РґРѕСЂРѕРІСЊСЏ (data.max_health)",
		"(got %.4f)" % _enemy_health(enemy))
	_check(_enemy_alive(enemy), "РІСЂР°Рі РЅР°С‡РёРЅР°РµС‚ Р¶РёРІ")
	# РљРѕРЅС‚Р°РєС‚РЅР°СЏ РєР°РґРµРЅС†РёСЏ вЂ” СЂРµС€РµРЅРёРµ Р¤Р°Р·С‹ 2, Р° РЅРµ РїРѕР»Рµ СЃС†РµРЅС‹: РµСЃР»Рё РґРµС„РѕР»С‚
	# СЃРјРµРЅРёС‚СЊ, РІРѕР»РЅР° РІСЂР°РіРѕРІ РЅР°С‡РЅС‘С‚ Р±РёС‚СЊ РІС‚СЂРѕРµ С‡Р°С‰Рµ, Рё РїСЂРѕРІРµСЂРєР° РґРѕР»Р¶РЅР° СЌС‚Рѕ РІРёРґРµС‚СЊ.
	_check(_near(float(enemy.get("contact_interval")), 1.0),
		"contact_interval РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ 1.0 СЃ",
		"(got %.4f)" % float(enemy.get("contact_interval")))

	print("-- РЅРµРїСЂРёРіРѕРґРЅС‹Рµ РґР°РЅРЅС‹Рµ: РІСЂР°Рі РІС‹РєР»СЋС‡Р°РµС‚СЃСЏ, Р° РЅРµ РїР°РґР°РµС‚ РґРµР»РµРЅРёРµРј РЅР° РЅРѕР»СЊ")
	await _test_invalid_enemy_data(packed)

	if not _enemy_api_ready(enemy) or hurtbox == null:
		print("  (РїРѕРІРµРґРµРЅРёРµ РѕС†РµРЅРёРІР°С‚СЊ РЅРµР»СЊР·СЏ Р±РµР· API Р·РґРѕСЂРѕРІСЊСЏ Рё С…РёС‚Р±РѕРєСЃР°: РїСЂРѕРІРµСЂРєРё РЅРёР¶Рµ РїСЂРѕРїСѓС‰РµРЅС‹)")
		world.queue_free()
		return

	enemy.died.connect(_on_enemy_died.bind(enemy))

	print("-- СЃРєРІРѕР·РЅР°СЏ РїСЂРѕРІРѕРґРєР°: СЃРЅР°СЂСЏРґ в†’ СЃР»РѕРё в†’ С…РёС‚Р±РѕРєСЃ в†’ РІСЂР°Рі")
	# РЈСЂРѕРЅ РёРґС‘С‚ РЅР°СЃС‚РѕСЏС‰РёРј СЃРЅР°СЂСЏРґРѕРј РёР· projectile.tscn, Р° РЅРµ РїСЂСЏРјС‹Рј
	# apply_damage: РїСЂСЏРјР°СЏ РїСЂРѕРІРµСЂРєР° Р±С‹Р»Р° Р±С‹ Р·РµР»С‘РЅРѕР№ РЅР° РІСЂР°РіРµ, С‡РµР№ С…РёС‚Р±РѕРєСЃ Р»РµР¶РёС‚
	# РЅРµ РЅР° СЃР»РѕРµ 4 Рё РєРѕС‚РѕСЂРѕРіРѕ РЅРµ РІРёРґРёС‚ РЅРё РѕРґРёРЅ СЃРЅР°СЂСЏРґ РІ РёРіСЂРµ.
	var bullet := _spawn_projectile(world, Vector3(0.0, 0.9, 0.0))
	var enemy_hurtbox := enemy.get_node_or_null("Hurtbox") as Hurtbox
	var hits: Array[Node] = []
	bullet.hit_something.connect(hits.append)
	bullet.launch(Vector3.RIGHT)
	await _frames_until_free(bullet, 200)
	_check(hits.size() == 1 and hits[0] == enemy_hurtbox,
		"СЃРЅР°СЂСЏРґ РїРѕРїР°Р» РІ С…РёС‚Р±РѕРєСЃ РІСЂР°РіР° Рё С‚РѕР»СЊРєРѕ РІ РЅРµРіРѕ",
		"(hit %s)" % ("nothing" if hits.is_empty() else str((hits[0] as Node).name)))
	_check(_near(_enemy_health(enemy), 20.0), "РїРѕСЃР»Рµ РѕРґРЅРѕРіРѕ РїРѕРїР°РґР°РЅРёСЏ Сѓ РІСЂР°РіР° 20 Р·РґРѕСЂРѕРІСЊСЏ (50 - 30)",
		"(got %.4f)" % _enemy_health(enemy))
	_check(_enemy_alive(enemy), "РІСЂР°Рі Р¶РёРІ РїРѕСЃР»Рµ РѕРґРЅРѕРіРѕ РїРѕРїР°РґР°РЅРёСЏ")
	_check(_enemy_died_count == 0, "РїРѕСЃР»Рµ РѕРґРЅРѕРіРѕ РїРѕРїР°РґР°РЅРёСЏ СЃРёРіРЅР°Р» died РµС‰С‘ РЅРµ РёСЃРїСѓСЃРєР°Р»СЃСЏ",
		"(got %d)" % _enemy_died_count)

	print("-- РІС‚РѕСЂРѕР№ СЃРЅР°СЂСЏРґ: СЃРјРµСЂС‚СЊ")
	var bullet2 := _spawn_projectile(world, Vector3(0.0, 0.9, 0.0))
	bullet2.launch(Vector3.RIGHT)
	await _frames_until_free(bullet2, 200)
	_check(_enemy_died_count == 1, "РІС‚РѕСЂРѕРµ РїРѕРїР°РґР°РЅРёРµ СѓР±РёРІР°РµС‚ РІСЂР°РіР°, died СЂРѕРІРЅРѕ РѕРґРёРЅ",
		"(got %d)" % _enemy_died_count)
	_check(_near(_enemy_health(enemy), 0.0), "Р·РґРѕСЂРѕРІСЊРµ РјС‘СЂС‚РІРѕРіРѕ РІСЂР°РіР° СЂР°РІРЅРѕ 0.0",
		"(got %.4f)" % _enemy_health(enemy))
	_check(not _enemy_alive(enemy), "РІСЂР°Рі РјС‘СЂС‚РІ: is_alive() == false")
	_check(_near(_enemy_health_at_death, 0.0),
		"РІ РјРѕРјРµРЅС‚ СЃРёРіРЅР°Р»Р° died Р·РґРѕСЂРѕРІСЊРµ РІСЂР°РіР° СѓР¶Рµ СЂР°РІРЅРѕ 0.0",
		"(got %.4f)" % _enemy_health_at_death)
	_check(not _enemy_alive_at_death,
		"РІ РјРѕРјРµРЅС‚ СЃРёРіРЅР°Р»Р° died РІСЂР°Рі СѓР¶Рµ РјС‘СЂС‚РІ (is_alive() == false)")

	print("-- РјС‘СЂС‚РІС‹Р№ РІСЂР°Рі: С‚РµСЂСЏРµС‚ С†РІРµС‚ Рё Р±РѕР»СЊС€Рµ РЅРµ РїСЂРёРЅРёРјР°РµС‚ СѓСЂРѕРЅ")
	var dead_material := mesh.material_override as StandardMaterial3D
	_check(dead_material != null and _color_near(dead_material.albedo_color, Color(0.5, 0.5, 0.5)),
		"РїРѕСЃР»Рµ СЃРјРµСЂС‚Рё РјР°С‚РµСЂРёР°Р» РјРµС€Р° Р±Р»РёР·РѕРє Рє СЃРµСЂРѕРјСѓ (С‚РµСЂСЏРµС‚ С†РІРµС‚)",
		"(got %s, expected Color(0.5, 0.5, 0.5, 1))" % str(dead_material.albedo_color if dead_material != null else Color.TRANSPARENT))
	_check(int(enemy.collision_layer) == 0,
		"РјС‘СЂС‚РІРѕРµ С‚РµР»Рѕ СЃРЅСЏС‚Рѕ СЃ РєРѕР»Р»РёР·РёР№: collision_layer == 0",
		"(got %d)" % int(enemy.collision_layer))
	await _frames_until_free(enemy, 1)
	_check(not bool(hurtbox.monitoring),
		"С…РёС‚Р±РѕРєСЃ РјС‘СЂС‚РІРѕРіРѕ РІСЂР°РіР° РїРµСЂРµСЃС‚Р°Р» РѕР±РЅР°СЂСѓР¶РёРІР°С‚СЊ (set_deferred(\"monitoring\", false))")
	enemy.call("take_damage", 30.0)
	_check(_enemy_died_count == 1, "СѓСЂРѕРЅ РїРѕ РјС‘СЂС‚РІРѕРјСѓ РІСЂР°РіСѓ РЅРµ РёСЃРїСѓСЃРєР°РµС‚ died РїРѕРІС‚РѕСЂРЅРѕ",
		"(got %d)" % _enemy_died_count)
	_check(_near(_enemy_health(enemy), 0.0), "СѓСЂРѕРЅ РїРѕ РјС‘СЂС‚РІРѕРјСѓ РІСЂР°РіСѓ РЅРµ РґРІРёРіР°РµС‚ Р·РґРѕСЂРѕРІСЊРµ",
		"(got %.4f)" % _enemy_health(enemy))

	print("-- РјС‘СЂС‚РІРѕРµ С‚РµР»Рѕ РёСЃС‡РµР·Р°РµС‚ РЅРµ СЃСЂР°Р·Сѓ: С†РІРµС‚ СЃРјРµСЂС‚Рё РґРѕР»Р¶РµРЅ Р±С‹С‚СЊ РІРёРґРµРЅ")
	await _frames_until_free(enemy, 120)
	_check(not is_instance_valid(enemy),
		"РјС‘СЂС‚РІС‹Р№ РІСЂР°Рі СѓР±СЂР°РЅ СЃРѕ СЃС†РµРЅС‹ С‡РµСЂРµР· ~0.2 СЃ, Р° РЅРµ РјРіРЅРѕРІРµРЅРЅРѕ")

	world.queue_free()
	await physics_frame

	await _test_two_projectiles_one_frame(packed)
	await _test_enemy_contact_tick(packed)


## Р”РІР° СЃРЅР°СЂСЏРґР°, РѕРґРЅР° С†РµР»СЊ, РѕРґРёРЅ РєР°РґСЂ вЂ” РµРґРёРЅСЃС‚РІРµРЅРЅР°СЏ РіРѕРЅРєР°, РІ РєРѕС‚РѕСЂРѕР№ РІСЂР°Рі РјРѕР¶РµС‚
## СѓРјРµСЂРµС‚СЊ РґРІР°Р¶РґС‹ Р·Р° РѕРґРёРЅ РєР°РґСЂ.
##
## РџСЂРѕРІРµСЂРєР° РѕР±СЏР·Р°РЅР° РїР°РґР°С‚СЊ Рё С‚РѕРіРґР°, РєРѕРіРґР° РѕР±Р° СЃРЅР°СЂСЏРґР° РџР РћРњРђРҐРќРЈР›РРЎР¬: СЃРЅР°СЂСЏРґ,
## СѓР»РµС‚РµРІС€РёР№ РІ СЃС‚РµРЅСѓ, С‚РѕР¶Рµ РёСЃС‡РµР·Р°РµС‚, Рё В«РїРѕСЃР»Рµ РєР°РґСЂР° РІСЂР°Рі РјС‘СЂС‚РІВ» РЅРёС‡РµРіРѕ РЅРµ РіРѕРІРѕСЂРёС‚
## Рѕ РїРѕРїР°РґР°РЅРёСЏС…. РџРѕСЌС‚РѕРјСѓ РєР°Р¶РґС‹Р№ СЃРЅР°СЂСЏРґ РѕР±СЏР·Р°РЅ СЃР°Рј РїСЂРµРґСЉСЏРІРёС‚СЊ `hit_something` СЃ
## РёРјРµРЅРµРј С…РёС‚Р±РѕРєСЃР° РІСЂР°РіР°, Рё РѕР±Р° РїРѕРїР°РґР°РЅРёСЏ РѕР±СЏР·Р°РЅС‹ РїСЂРёР№С‚РёСЃСЊ РЅР° РѕРґРёРЅ С„РёР·РёС‡РµСЃРєРёР№
## РєР°РґСЂ вЂ” РёРЅР°С‡Рµ СЌС‚Рѕ РЅРµ В«РѕРґРёРЅ РєР°РґСЂВ», Р° РґРІР° С‚РёРєР° РїРѕРґСЂСЏРґ, Р° С‚Р°РєСѓСЋ РіРѕРЅРєСѓ РІС‹РёРіСЂР°С‚СЊ
## РЅРµС‡РµРј.
func _test_two_projectiles_one_frame(packed: PackedScene) -> void:
	print("-- РґРІР° СЃРЅР°СЂСЏРґР°, РѕРґРЅР° С†РµР»СЊ, РѕРґРёРЅ РєР°РґСЂ")

	var world := _new_world()
	_add_floor(world)
	_add_wall(world, 20.0)
	_enemy_died_count = 0
	_enemy_health_at_death = -1.0
	_enemy_alive_at_death = true
	# Р’СЂР°Рі РІ 3 Рј РѕС‚ СЃС‚СЂРµР»СЊР±С‹: СЃРЅР°СЂСЏРґ Р»РµС‚РёС‚ 1/3 Рј Р·Р° С‚РёРє, РїРѕСЌС‚РѕРјСѓ РѕР±Р° РїРѕРїР°РґСѓС‚ РЅР°
	# РґРµРІСЏС‚РѕРј С‚РёРєРµ, Р° РЅРµ В«РєРѕРіРґР°-РЅРёР±СѓРґСЊВ» вЂ” Рё Сѓ СЃС‚РµРЅС‹ Р·Р° 20 Рј СЌС‚Рѕ РїСЂРѕРёР·РѕР№С‚Рё РЅРµ
	# РјРѕР¶РµС‚.
	var enemy := packed.instantiate()
	if not await _spawn_in(world, enemy, Vector3(3.0, 0.0, 0.0)):
		_bail("%s never became node-ready for the two-projectile test" % _ENEMY_PATH)
		return
	enemy.died.connect(_on_enemy_died.bind(enemy))
	var enemy_hurtbox := enemy.get_node_or_null("Hurtbox") as Hurtbox
	_check(enemy_hurtbox != null, "precondition: Сѓ РІСЂР°РіР° РµСЃС‚СЊ С…РёС‚Р±РѕРєСЃ, РєСѓРґР° С†РµР»СЏС‚СЃСЏ РѕР±Р° СЃРЅР°СЂСЏРґР°")

	var targets: Array = [[], []]
	var hit_frames: Array[int] = [-1, -1]
	var bullets: Array[Projectile] = []
	for i in 2:
		var bullet := _spawn_projectile(world, Vector3(0.0, 0.9, 0.0))
		var index := i
		bullet.hit_something.connect(func(target: Node) -> void:
			(targets[index] as Array).append(target)
			hit_frames[index] = Engine.get_physics_frames())
		bullets.append(bullet)
	await physics_frame
	# РћР±Р° Р·Р°РїСѓСЃРєР°СЋС‚СЃСЏ РїРѕРґСЂСЏРґ, Р±РµР· await РјРµР¶РґСѓ РЅРёРјРё: РїР°СѓР·Р° РІ РєР°РґСЂ СЂР°Р·СЉРµС…Р°Р»Р° Р±С‹
	# СЃРЅР°СЂСЏРґС‹ РЅР° С‚СЂРµС‚СЊ РјРµС‚СЂР°, Рё РІС‚РѕСЂРѕР№ РїСЂРёС€С‘Р» Р±С‹ РІ С†РµР»СЊ РЅР° РєР°РґСЂ РїРѕР·Р¶Рµ.
	for bullet in bullets:
		bullet.launch(Vector3.RIGHT)
	# Р–РґР°С‚СЊ СЃРЅР°СЂСЏРґРѕРІ РїРѕ РѕС‡РµСЂРµРґРё РЅРµР»СЊР·СЏ: РѕРЅРё РєРѕРЅС‡Р°СЋС‚СЃСЏ РІ РѕРґРёРЅ РєР°РґСЂ, Рё РєРѕ РІС‚РѕСЂРѕРјСѓ
	# РІС‹Р·РѕРІСѓ СѓР·РµР» СѓР¶Рµ РѕСЃРІРѕР±РѕР¶РґС‘РЅ вЂ” РїРµСЂРµРґР°С‚СЊ С‚Р°РєРѕР№ РѕР±СЉРµРєС‚ РІ РїР°СЂР°РјРµС‚СЂ С‚РёРїР° Node
	# РЅРµР»СЊР·СЏ, Рё РїСЂРѕРІРµСЂРєР° РїР°РґР°Р»Р° Р±С‹ СЃ С‚СЂР°СЃСЃРёСЂРѕРІРєРѕР№ РІРјРµСЃС‚Рѕ [FAIL].
	var waited := 0
	while waited < 60 and (is_instance_valid(bullets[0]) or is_instance_valid(bullets[1])):
		waited += 1
		await physics_frame
	_check(not is_instance_valid(bullets[0]) and not is_instance_valid(bullets[1]),
		"РѕР±Р° СЃРЅР°СЂСЏРґР° РєРѕРЅС‡РёР»РёСЃСЊ РЅР° РІСЂР°РіРµ Рё СѓР±СЂР°РЅС‹ СЃРѕ СЃС†РµРЅС‹",
		"(waited %d ticks)" % waited)

	for i in 2:
		var hit := targets[i] as Array
		_check(hit.size() == 1 and hit[0] == enemy_hurtbox,
			"СЃРЅР°СЂСЏРґ в„–%d РїРѕРїР°Р» РІ С…РёС‚Р±РѕРєСЃ РІСЂР°РіР° Рё С‚РѕР»СЊРєРѕ РІ РЅРµРіРѕ" % (i + 1),
			"(hit %s)" % ("nothing" if hit.is_empty() else str((hit[0] as Node).name)))
	_check(hit_frames[0] >= 0 and hit_frames[0] == hit_frames[1],
		"РѕР±Р° РїРѕРїР°РґР°РЅРёСЏ РїСЂРёС€Р»РёСЃСЊ РЅР° РѕРґРёРЅ С„РёР·РёС‡РµСЃРєРёР№ РєР°РґСЂ",
		"(РєР°РґСЂС‹ %d Рё %d)" % [hit_frames[0], hit_frames[1]])
	_check(_enemy_died_count == 1,
		"РґРІР° СЃРЅР°СЂСЏРґР° РІ РѕРґРёРЅ РєР°РґСЂ СѓР±РёРІР°СЋС‚ РІСЂР°РіР° РѕРґРёРЅ СЂР°Р·, died СЂРѕРІРЅРѕ РѕРґРёРЅ",
		"(got %d)" % _enemy_died_count)
	_check(_near(_enemy_health(enemy), 0.0), "РїРѕСЃР»Рµ РґРІСѓС… РїРѕРїР°РґР°РЅРёР№ Р·РґРѕСЂРѕРІСЊРµ РІСЂР°РіР° СЂРѕРІРЅРѕ 0.0",
		"(got %.4f)" % _enemy_health(enemy))
	_check(not _enemy_alive(enemy), "РІСЂР°Рі РјС‘СЂС‚РІ: is_alive() == false")
	_check(_near(_enemy_health_at_death, 0.0),
		"РІ РјРѕРјРµРЅС‚ СЃРёРіРЅР°Р»Р° died Р·РґРѕСЂРѕРІСЊРµ РІСЂР°РіР° СѓР¶Рµ СЂР°РІРЅРѕ 0.0",
		"(got %.4f)" % _enemy_health_at_death)

	world.queue_free()
	await physics_frame


## РќРµРїСЂРёРіРѕРґРЅС‹Рµ РґР°РЅРЅС‹Рµ РґРѕР»Р¶РЅС‹ РІС‹РєР»СЋС‡Р°С‚СЊ РІСЂР°РіР°, Р° РЅРµ СЂРѕРЅСЏС‚СЊ РїСЂРѕРІРµСЂРєСѓ. Р‘РµР· РґР°РЅРЅС‹С… Сѓ
## РІСЂР°РіР° РЅРµС‚ РЅРё РјР°РєСЃРёРјСѓРјР° Р·РґРѕСЂРѕРІСЊСЏ, РЅРё СѓСЂРѕРЅР° Р·Р° С‚РёРє, Рё Р»СЋР±РѕРµ РѕР±СЂР°С‰РµРЅРёРµ Рє РЅРёРј
## РґРµР»РёС‚ РЅР° РЅРѕР»СЊ РёР»Рё РїР°РґР°РµС‚ РЅР° null вЂ” С‚Рѕ РµСЃС‚СЊ Р»РѕРјР°РµС‚ РїСЂРѕРІРµСЂРєСѓ РІРјРµСЃС‚Рѕ С‚РѕРіРѕ, С‡С‚РѕР±С‹
## РїРѕРєР°Р·Р°С‚СЊ, С‡С‚Рѕ РІСЂР°Рі РїР»РѕС…Рѕ РЅР°СЃС‚СЂРѕРµРЅ.
func _test_invalid_enemy_data(packed: PackedScene) -> void:
	var world := _new_world()
	var no_data := packed.instantiate()
	no_data.set("data", null)
	if not await _spawn_in(world, no_data, Vector3(0.0, 0.0, 6.0)):
		_bail("an enemy without data never became node-ready")
		return
	var broken_data := packed.instantiate()
	# EnemyData.new() Р·РґРµСЃСЊ РќР• РіРѕРґРёС‚СЃСЏ: Сѓ СЂРµСЃСѓСЂСЃР° РІСЃРµ РїРѕР»СЏ СѓР¶Рµ РёРјРµСЋС‚ СЂР°Р±РѕС‡РёРµ
	# Р·РЅР°С‡РµРЅРёСЏ РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ (50 HP, 10 СѓСЂРѕРЅР°, 6 Рј/СЃ), Рё С‚Р°РєРѕР№ В«СЃР»РѕРјР°РЅРЅС‹Р№В» РІСЂР°Рі
	# РїСЂРѕС€С‘Р» Р±С‹ is_valid(). РќРµРїСЂРёРіРѕРґРЅРѕСЃС‚СЊ СЃРѕР·РґР°С‘С‚СЃСЏ СЏРІРЅРѕР№ РїСЂР°РІРєРѕР№ РїРѕР»СЏ.
	var unusable := EnemyData.new()
	unusable.max_health = 0.0
	broken_data.set("data", unusable)
	if not await _spawn_in(world, broken_data, Vector3(0.0, 0.0, 12.0)):
		_bail("an enemy with invalid data never became node-ready")
		return

	_check(not broken_data.get("data").is_valid(),
		"precondition: РїРѕРґСЃС‚Р°РІР»РµРЅРЅС‹Рµ РґР°РЅРЅС‹Рµ РґРµР№СЃС‚РІРёС‚РµР»СЊРЅРѕ РЅРµРїСЂРёРіРѕРґРЅС‹ (is_valid() == false)")
	_check(_near(_enemy_health(no_data), 0.0) and _near(_enemy_health(broken_data), 0.0),
		"РІСЂР°Рі Р±РµР· РґР°РЅРЅС‹С… Рё РІСЂР°Рі СЃ РЅРµРїСЂРёРіРѕРґРЅС‹РјРё РґР°РЅРЅС‹РјРё РЅРµ РїР°РґР°СЋС‚: Р·РґРѕСЂРѕРІСЊРµ 0.0",
		"(no_data %.4f, broken_data %.4f)" % [_enemy_health(no_data), _enemy_health(broken_data)])
	_check(not _enemy_alive(no_data) and not _enemy_alive(broken_data),
		"РІС‹РєР»СЋС‡РµРЅРЅС‹Р№ РІСЂР°Рі РЅРµ СЃС‡РёС‚Р°РµС‚СЃСЏ Р¶РёРІС‹Рј")
	_check(not no_data.is_physics_processing() and not broken_data.is_physics_processing(),
		"РІС‹РєР»СЋС‡РµРЅРЅС‹Р№ РІСЂР°Рі РЅРµ РѕР±СЂР°Р±Р°С‚С‹РІР°РµС‚ С„РёР·РёРєСѓ: РЅРё С‚РёРєРѕРІ, РЅРё РґРµР»РµРЅРёСЏ РЅР° РЅРѕР»СЊ")
	# РћР±Р° СѓР·Р»Р° РѕР±СЏР·Р°РЅС‹ РїРµСЂРµР¶РёС‚СЊ РЅРµСЃРєРѕР»СЊРєРѕ РєР°РґСЂРѕРІ: РїР°РґРµРЅРёРµ _ready() РІС‹РіР»СЏРґРµР»Рѕ Р±С‹
	# РєР°Рє РєСЂР°С€ РїСЂРѕС†РµСЃСЃР°, Р° РЅРµ РєР°Рє РёРјРµРЅРѕРІР°РЅРЅС‹Р№ [FAIL].
	await _physics_frames(20)
	_check(is_instance_valid(no_data) and is_instance_valid(broken_data),
		"РІС‹РєР»СЋС‡РµРЅРЅС‹Р№ РІСЂР°Рі Р¶РёРІС‘С‚ РІ СЃС†РµРЅРµ 20 С‚РёРєРѕРІ Р±РµР· РїР°РґРµРЅРёСЏ")

	world.queue_free()
	await physics_frame


## РљРѕРЅС‚Р°РєС‚РЅС‹Р№ СѓСЂРѕРЅ: РІС…РѕРґ, РєР°РґРµРЅС†РёСЏ, РіСЂР°РЅРёС†Р° СЃРјРµСЂС‚Рё Рё РѕР±СЂС‹РІ РєРѕРЅС‚Р°РєС‚Р°.
##
## РџРѕР·РёС†РёРё РїРѕРґРѕР±СЂР°РЅС‹ С‚Р°Рє, С‡С‚РѕР±С‹ РєР°Р¶РґРѕРµ СѓС‚РІРµСЂР¶РґРµРЅРёРµ Р»РѕРІРёР»Рѕ СЃРІРѕР№ РѕС‚РєР°Р·: РІСЂР°Рі РІ
## 0.4 Рј РѕС‚ РёРіСЂРѕРєР° (РєР°РїСЃСѓР»С‹ РїРѕ 0.4 Рј СЂР°РґРёСѓСЃР°, Р·РѕРЅС‹ Р·Р°С…Р»С‘РЅСѓС‚С‹), РєР°РґРµРЅС†РёСЏ 0.1 СЃ
## вЂ” СЌС‚Рѕ СЂРѕРІРЅРѕ 12 С‚РёРєРѕРІ РЅР° 120 С‚РёРєР°С… РІ СЃРµРєСѓРЅРґСѓ, Рё С‚РёРєРё С‡РёС‚Р°СЋС‚СЃСЏ РїРѕРєР°РґСЂРѕРІРѕ, Р° РЅРµ
## РїРѕ РѕР±С‰РµРјСѓ СѓСЂРѕРЅСѓ. РЈСЂРѕРЅ РЅРёРіРґРµ РЅРµ Р·Р°С…Р°СЂРґРєРѕР¶РµРЅ: РѕРЅ Р±РµСЂС‘С‚СЃСЏ РёР· data.contact_damage.
func _test_enemy_contact_tick(packed: PackedScene) -> void:
	print("-- РљРѕРЅС‚Р°РєС‚РЅС‹Р№ СѓСЂРѕРЅ (Task 3)")

	_died_count = 0
	_health_at_death = -1.0
	_alive_at_death = true

	var world := _new_world()
	_add_floor(world)

	var player_packed: PackedScene = load(_PLAYER_PATH)
	if player_packed == null:
		_bail("cannot load %s for the contact test" % _PLAYER_PATH)
		return
	var player := player_packed.instantiate()
	# РўРѕС‡РєР° РїРѕСЏРІР»РµРЅРёСЏ РёРіСЂРѕРєР° вЂ” С‚Р° Р¶Рµ С‚РѕС‡РєР°, РіРґРµ РѕРЅ СЃС‚РѕРёС‚: РїРѕСЃР»Рµ СЃРјРµСЂС‚Рё СЂРµСЃРїР°РІРЅ
	# РІРѕР·РІСЂР°С‰Р°РµС‚ РµРіРѕ РІ РєРѕРЅС‚Р°РєС‚, Рё СЌС‚Рѕ С‡Р°СЃС‚СЊ РїСЂРѕРІРµСЂСЏРµРјРѕРіРѕ РєРѕРЅС‚СЂР°РєС‚Р°.
	if not await _spawn_in(world, player, Vector3(0.0, 0.0, 0.0)):
		_bail("%s never became node-ready for the contact test" % _PLAYER_PATH)
		return
	await _physics_frames(20)
	_check(player.is_on_floor(), "precondition: РёРіСЂРѕРє СЃС‚РѕРёС‚ РЅР° РїРѕР»Сѓ, Р° РЅРµ РІРёСЃРёС‚ РІ РІРѕР·РґСѓС…Рµ")
	_check(player.is_in_group("player"),
		"РёРіСЂРѕРє РІРѕС€С‘Р» РІ РіСЂСѓРїРїСѓ \"player\": РІСЂР°Рі РЅР°С…РѕРґРёС‚ С†РµР»СЊ РїРѕ РіСЂСѓРїРїРµ, Р° РЅРµ РїРѕ РїСѓС‚Рё РІ СЃС†РµРЅРµ")
	var player_hurtbox := player.get_node_or_null("Hurtbox") as Hurtbox
	_check(player_hurtbox != null, "Сѓ РёРіСЂРѕРєР° РµСЃС‚СЊ С…РёС‚Р±РѕРєСЃ, РІ РєРѕС‚РѕСЂС‹Р№ РІР»РµС‚Р°РµС‚ С…РёС‚Р±РѕРєСЃ РІСЂР°РіР°")
	if player_hurtbox == null:
		_bail("player.tscn carries no Hurtbox: the contact test cannot run")
		return
	# Р”РµС‚РµРєС‚ РєРѕРЅС‚Р°РєС‚Р° РІРєР»СЋС‡Р°РµС‚СЃСЏ РЅР° СЃС‚РѕСЂРѕРЅРµ РІСЂР°РіР° (СЃРїРµРєР° В§6.3), РїРѕСЌС‚РѕРјСѓ С…РёС‚Р±РѕРєСЃ
	# РёРіСЂРѕРєР° РѕР±СЏР·Р°РЅ РѕСЃС‚Р°С‚СЊСЃСЏ РїР°СЃСЃРёРІРЅС‹Рј. РҐРёС‚Р±РѕРєСЃ РёРіСЂРѕРєР°, РЅР°С‡Р°РІС€РёР№ РѕР±РЅР°СЂСѓР¶РёРІР°С‚СЊ,
	# Р»РѕРІРёР» Р±С‹ Рё РІСЂР°Р¶РµСЃРєРёРµ С…РёС‚Р±РѕРєСЃС‹ Рё СѓСЂРѕРЅ РЅР°РЅРѕСЃРёР»СЃСЏ Р±С‹ РґРІР°Р¶РґС‹ вЂ” Р° РјРѕР»С‡Р°.
	_check(not bool(player_hurtbox.monitoring),
		"С…РёС‚Р±РѕРєСЃ РёРіСЂРѕРєР° РќР• РѕР±РЅР°СЂСѓР¶РёРІР°РµС‚ СЃР°Рј: monitoring == false (РґРµС‚РµРєС‚ РЅР° СЃС‚РѕСЂРѕРЅРµ РІСЂР°РіР°)")
	_check(int(player_hurtbox.collision_mask) == _LAYER_WORLD,
		"РјР°СЃРєР° С…РёС‚Р±РѕРєСЃР° РёРіСЂРѕРєР° вЂ” СЃР»РѕР№ 1: РѕРЅ РЅРµ РёС‰РµС‚ РІСЂР°РіР°",
		"(got %d, expected %d)" % [
			int(player_hurtbox.collision_mask), _LAYER_WORLD])

	player.died.connect(_on_player_died.bind(player))

	var enemy := packed.instantiate()
	enemy.set("contact_interval", 0.1)
	# РЎС†РµРЅР°СЂРёР№ СЃС‡РёС‚Р°РµС‚ РЅРµСЃС‚Р°РЅРґР°СЂС‚РЅС‹Р№ СѓСЂРѕРЅ Р·Р° С‚РёРє, Рё СЌС‚Рѕ РµРґРёРЅСЃС‚РІРµРЅРЅС‹Р№ СЃРїРѕСЃРѕР±
	# РѕС‚Р»РёС‡РёС‚СЊ В«СѓСЂРѕРЅ РІР·СЏС‚ РёР· РґР°РЅРЅС‹С…В» РѕС‚ В«СѓСЂРѕРЅ Р·Р°С€РёС‚ РІ РєРѕРґРµВ»: РїСЂРё 10.0 Р»СЋР±РѕР№
	# Р·Р°С…Р°СЂРґРєРѕР¶РµРЅРЅС‹Р№ СѓСЂРѕРЅ СЃРѕРІРїР°Р» Р±С‹ СЃ РѕР¶РёРґР°РµРјС‹Рј С‡РёСЃР»РѕРј, Рё РїСЂРѕРІРµСЂРєР° РЅРёС‡РµРіРѕ Р±С‹ РЅРµ
	# СЂР°Р·Р»РёС‡Р°Р»Р°. Р”СѓР±Р»РёРєР°С‚ РґР°РЅРЅС‹С…, Р° РЅРµ РїСЂР°РІРєР° contact.tres вЂ” СЂРµСЃСѓСЂСЃ С‡РёС‚Р°СЋС‚ Рё
	# РґСЂСѓРіРёРµ СЂР°Р·РґРµР»С‹, Рё РїСЂР°РІРєР° РЅР° РјРµСЃС‚Рµ СѓС‚РµРєР»Р° Р±С‹ РІ РЅРёС….
	var probe := (enemy.get("data") as EnemyData).duplicate() as EnemyData
	probe.contact_damage = 7.5
	enemy.set("data", probe)
	if not await _spawn_in(world, enemy, Vector3(0.4, 0.0, 0.0)):
		_bail("%s never became node-ready for the contact test" % _ENEMY_PATH)
		return
	enemy.died.connect(_on_enemy_died.bind(enemy))

	var shipped_damage := float((load(_CONTACT_PATH) as EnemyData).contact_damage)
	var contact_damage := float(enemy.get("data").contact_damage)
	_check(_near(contact_damage, probe.contact_damage) and not _near(contact_damage, shipped_damage),
		"precondition: СЃС†РµРЅР°СЂРёР№ РєРѕРЅС‚Р°РєС‚Р° РёРґС‘С‚ РїРѕ РќР•РЎРўРђРќР”РђР РўРќРћРњРЈ СѓСЂРѕРЅСѓ Р·Р° С‚РёРє, Р° РЅРµ РїРѕ %.1f РёР· contact.tres" % shipped_damage,
		"(contact_damage %.4f, СѓСЂРѕРЅ contact.tres %.4f)" % [contact_damage, shipped_damage])

	# Р’СЃРµ РѕР¶РёРґР°РµРјС‹Рµ С‡РёСЃР»Р° СЌС‚РѕРіРѕ СЃС†РµРЅР°СЂРёСЏ РІС‹РІРѕРґСЏС‚СЃСЏ РёР· РґРІСѓС… РІРµР»РёС‡РёРЅ: Р·Р° С‚РёРє РёРіСЂРѕРє
	# С‚РµСЂСЏРµС‚ СЂРѕРІРЅРѕ contact_damage, РїРѕСЌС‚РѕРјСѓ РїРѕСЃР»Рµ k С‚РёРєРѕРІ Сѓ РЅРµРіРѕ РѕСЃС‚Р°С‘С‚СЃСЏ
	# player_max_health - k * contact_damage, Р° С‚РёРє, РєРѕС‚РѕСЂС‹Р№ РµРіРѕ СѓР±СЊС‘С‚, вЂ”
	# ceil(max_health / contact_damage). РќРё РѕРґРЅР° С†РёС„СЂР° РѕР¶РёРґР°РЅРёСЏ РЅРµ Р·Р°С€РёС‚Р° РІ
	# РїСЂРѕРІРµСЂРєСѓ, РїРѕСЌС‚РѕРјСѓ РїРѕРґРјРµРЅР° СѓСЂРѕРЅР° РІ enemy_contact.gd РµС‘ Р»РѕРјР°РµС‚.
	var player_max_health := float(player.get("max_health"))
	var interval_ticks := int(round(float(enemy.get("contact_interval")) * float(_TICKS_PER_SECOND)))
	var ticks_to_death := int(ceil(player_max_health / contact_damage))
	var survivable_ticks := ticks_to_death - 1
	var health_before_death := player_max_health - float(survivable_ticks) * contact_damage
	print("    СѓСЂРѕРЅ Р·Р° С‚РёРє %.4f, HP РёРіСЂРѕРєР° %.1f, С‚РёРєРѕРІ РґРѕ СЃРјРµСЂС‚Рё %d, РЅР° РіСЂР°РЅРёС†Рµ РѕСЃС‚Р°С‘С‚СЃСЏ %.4f" % [
		contact_damage, player_max_health, ticks_to_death, health_before_death])

	var overlap_frame := Engine.get_physics_frames()
	var previous := _health(player)
	var ticks: Array[int] = []
	var boundary_health := -1.0
	## РҐСѓРґС€Р°СЏ РѕС€РёР±РєР° В«СЃРєРѕР»СЊРєРѕ СЃРЅСЏР»Рё Р·Р° РѕРґРёРЅ С‚РёРєВ» РѕС‚РЅРѕСЃРёС‚РµР»СЊРЅРѕ СѓСЂРѕРЅР° РёР· РґР°РЅРЅС‹С….
	## РЎС‡РёС‚Р°РµС‚СЃСЏ РЅР° РєР°Р¶РґРѕРј С‚РёРєРµ, Р° РЅРµ РѕРґРёРЅ СЂР°Р· РЅР° СЃСѓРјРјРµ: СЃСѓРјРјР° Р·Р° N С‚РёРєРѕРІ
	## СЃРѕРІРїР°Р»Р° Р±С‹ Рё РїСЂРё РєСЂСѓРіР»РѕР№ РїРѕРґРјРµРЅРµ, Р° С‚РёРє вЂ” РЅРµС‚.
	var worst_damage_error := 0.0
	for i in 300:
		await physics_frame
		var current := _health(player)
		if not _near(current, previous):
			ticks.append(Engine.get_physics_frames())
			worst_damage_error = maxf(worst_damage_error, absf((previous - current) - contact_damage))
			previous = current
		if ticks.size() == survivable_ticks:
			boundary_health = current
			break

	print("    С‚РёРєРё РєРѕРЅС‚Р°РєС‚Р°: %s (РёРЅС‚РµСЂРІР°Р» %d С‚РёРєРѕРІ)" % [str(ticks), interval_ticks])
	_check(ticks.size() == survivable_ticks,
		"РїРѕР»СѓС‡РµРЅРѕ СЂРѕРІРЅРѕ %d С‚РёРєРѕРІ РєРѕРЅС‚Р°РєС‚Р° Р·Р° 300 С‚РёРєРѕРІ РѕР¶РёРґР°РЅРёСЏ" % survivable_ticks,
		"(got %d: %s)" % [ticks.size(), str(ticks)])
	# РџРµСЂРІС‹Р№ С‚РёРє РѕР±СЏР·Р°РЅ РїСЂРёР№С‚Рё РЅР° РІС…РѕРґРµ, Р° РЅРµ С‡РµСЂРµР· РёРЅС‚РµСЂРІР°Р»: Р±РµР· РЅРµРіРѕ РІСЂР°Рі,
	# РєРѕСЃРЅСѓРІС€РёР№СЃСЏ РёРіСЂРѕРєР°, С†РµР»С‹Р№ С†РёРєР» СЃС‚РѕСЏР» Р±С‹ СЂСЏРґРѕРј Р±РµР·РІСЂРµРґРЅС‹Рј. Р“СЂР°РЅРёС†Р° вЂ” РїРѕР»РѕРІРёРЅР°
	# РёРЅС‚РµСЂРІР°Р»Р°: С‚РёРє РїРѕ СЂР°СЃРїРёСЃР°РЅРёСЋ РѕРїРѕР·РґР°Р» Р±С‹ РЅР° С†РµР»С‹Р№ РёРЅС‚РµСЂРІР°Р», Р° С‚РёРє РЅР° РІС…РѕРґСѓ
	# РїСЂРёС…РѕРґРёС‚ Р·Р° РѕРґРёРЅ-РґРІР° РєР°РґСЂР°.
	_check(ticks.size() > 0 and ticks[0] - overlap_frame <= maxi(2, interval_ticks / 2),
		"РїРµСЂРІС‹Р№ С‚РёРє РїСЂРёС…РѕРґРёС‚ СЃСЂР°Р·Сѓ РїСЂРё РІС…РѕРґРµ, РЅРµ С‡РµСЂРµР· contact_interval",
		"(РІС…РѕРґ РЅР° РєР°РґСЂРµ %d, РїРµСЂРІС‹Р№ С‚РёРє РЅР° РєР°РґСЂРµ %d, Р·Р°РґРµСЂР¶РєР° %d С‚РёРєРѕРІ РёР· %d)" % [
			overlap_frame, ticks[0] if ticks.size() > 0 else -1,
			(ticks[0] - overlap_frame) if ticks.size() > 0 else -1, interval_ticks])
	var worst_gap := 0
	for i in range(1, ticks.size()):
		worst_gap = maxi(worst_gap, absi(ticks[i] - ticks[i - 1] - interval_ticks))
	_check(ticks.size() > 1 and worst_gap <= 1,
		"РїРѕСЃР»Рµ РїРµСЂРІРѕРіРѕ С‚РёРєР° РєР°РґРµРЅС†РёСЏ СЂРѕРІРЅРѕ contact_interval (%d С‚РёРєРѕРІ)" % interval_ticks,
		"(worst gap error %d ticks over %d gaps)" % [worst_gap, ticks.size() - 1])
	_check(ticks.size() > 0 and worst_damage_error < _HEALTH_EPS,
		"СѓСЂРѕРЅ РљРђР–Р”РћР“Рћ С‚РёРєР° СЂР°РІРµРЅ data.contact_damage, Р° РЅРµ Р·Р°С…Р°СЂРґРєРѕР¶РµРЅРЅРѕРјСѓ С‡РёСЃР»Сѓ",
		"(С…СѓРґС€Р°СЏ РѕС€РёР±РєР° Р·Р° С‚РёРє %.4f РїСЂРё СѓСЂРѕРЅРµ %.4f)" % [worst_damage_error, contact_damage])
	_check(_near(boundary_health, health_before_death),
		"РїРѕСЃР»Рµ %d С‚РёРєРѕРІ Сѓ РёРіСЂРѕРєР° РѕСЃС‚Р°Р»РѕСЃСЊ СЂРѕРІРЅРѕ %.4f HP (max_health - %d * contact_damage)" % [
			survivable_ticks, health_before_death, survivable_ticks],
		"(got %.4f)" % boundary_health)
	_check(_alive(player), "РёРіСЂРѕРє Р¶РёРІ РїРѕСЃР»Рµ %d С‚РёРєРѕРІ РєРѕРЅС‚Р°РєС‚Р°" % survivable_ticks)

	print("-- РєРѕРЅС‚Р°РєС‚ РїСЂРµРєСЂР°С‰Р°РµС‚СЃСЏ: РІСЂР°Рі СѓС€С‘Р»")
	# РЈС…РѕРґ РІСЂР°РіР° РЅР°Р±Р»СЋРґР°РµС‚СЃСЏ РЅРµ С„Р»Р°РіРѕРј СЃС†РµРЅС‹, Р° С‚РµРј, С‡С‚Рѕ СѓСЂРѕРЅ РїСЂРµРєСЂР°С‚РёР»СЃСЏ:
	# Сѓ ContactEnemy РЅРµС‚ РїСѓР±Р»РёС‡РЅРѕРіРѕ В«СЏ РІ РєРѕРЅС‚Р°РєС‚РµВ», Рё РІС‹РґСѓРјС‹РІР°С‚СЊ РµРіРѕ СЂР°РґРё
	# РїСЂРѕРІРµСЂРєРё Р·РЅР°С‡РёР»Рѕ Р±С‹ РїСЂРѕРІРµСЂСЏС‚СЊ РЅРµСЃСѓС‰РµСЃС‚РІСѓСЋС‰РёР№ API. 30 С‚РёРєРѕРІ вЂ” СЌС‚Рѕ 2.5
	# РёРЅС‚РµСЂРІР°Р»Р°: РµСЃР»Рё Р±С‹ area_exited РЅРµ РѕСЃС‚Р°РЅРѕРІРёР» С‚РёРєРё, РёРіСЂРѕРє СЃ %.4f HP (РјРµРЅСЊС€Рµ
	# РѕРґРЅРѕРіРѕ С‚РёРєР° СѓСЂРѕРЅР°) РґР°РІРЅРѕ Р±С‹ СѓРјРµСЂ.
	enemy.global_position = Vector3(6.0, 0.0, 0.0)
	var after_exit := _health(player)
	for i in 30:
		await physics_frame
		if not _near(_health(player), after_exit):
			break
	_check(_near(_health(player), after_exit),
		"РїРѕСЃР»Рµ СѓС…РѕРґР° РІСЂР°РіР° С‚РёРєРё РїСЂРµРєСЂР°С‰Р°СЋС‚СЃСЏ: Р·РґРѕСЂРѕРІСЊРµ РёРіСЂРѕРєР° РЅРµ СѓР±С‹РІР°РµС‚",
		"(got %.4f, Р±С‹Р»Рѕ %.4f)" % [_health(player), after_exit])
	_check(_alive(player), "РёРіСЂРѕРє РїРµСЂРµР¶РёР» СѓС…РѕРґ РІСЂР°РіР°")

	print("-- РєРѕРЅС‚Р°РєС‚ РІРѕР·РѕР±РЅРѕРІР»СЏРµС‚СЃСЏ: С‚РёРє %d СѓР±РёРІР°РµС‚ РёРіСЂРѕРєР°" % ticks_to_death)
	enemy.global_position = Vector3(0.4, 0.0, 0.0)
	var died_frame := -1
	for i in 60:
		await physics_frame
		if _died_count >= 1:
			died_frame = i
			break
	_check(_died_count == 1,
		"С‚РёРє %d РєРѕРЅС‚Р°РєС‚Р° СѓР±РёРІР°РµС‚ РёРіСЂРѕРєР°, died СЂРѕРІРЅРѕ РѕРґРёРЅ" % ticks_to_death,
		"(got %d, СѓРјРµСЂ РЅР° РєР°РґСЂРµ %d РїРѕСЃР»Рµ РІРѕР·РІСЂР°С‚Р° РІСЂР°РіР°)" % [_died_count, died_frame])
	_check(_near(_health_at_death, 0.0), "РІ РјРѕРјРµРЅС‚ СЃРёРіРЅР°Р»Р° died Р·РґРѕСЂРѕРІСЊРµ РёРіСЂРѕРєР° СЂР°РІРЅРѕ 0.0",
		"(got %.4f)" % _health_at_death)
	_check(not _alive_at_death, "РІ РјРѕРјРµРЅС‚ СЃРёРіРЅР°Р»Р° died РёРіСЂРѕРє СѓР¶Рµ РјС‘СЂС‚РІ (is_alive() == false)")
	_check(_near(_health(player), player_max_health),
		"РёРіСЂРѕРє СЂРµСЃРїР°РІРЅРёР»СЃСЏ СЃ РїРѕР»РЅС‹Рј Р·РґРѕСЂРѕРІСЊРµРј max_health (РєРѕРЅС‚СЂР°РєС‚ Task 2)",
		"(got %.4f, max_health %.4f)" % [_health(player), player_max_health])

	world.queue_free()
	await physics_frame


## Р•СЃС‚СЊ Р»Рё РЅР° СѓР·Р»Рµ РІРµСЃСЊ API РІСЂР°РіР°. РћС‚РґРµР»СЊРЅР°СЏ С„СѓРЅРєС†РёСЏ, РїРѕС‚РѕРјСѓ С‡С‚Рѕ РѕС‚РІРµС‚ РЅСѓР¶РµРЅ
## РґРІР°Р¶РґС‹: РёРјРµРЅРѕРІР°РЅРЅС‹Рј [FAIL] Рё СЂРµС€РµРЅРёРµРј, РјРѕР¶РЅРѕ Р»Рё РІРѕРѕР±С‰Рµ Р·РІР°С‚СЊ health()
## РІС‹Р·РѕРІРѕРј call(), РЅРµ СѓРїР°РІ РІ СЂР°РЅС‚Р°Р№Рј РІРјРµСЃС‚Рѕ РїСЂРѕРІРµСЂРєРё.
func _enemy_api_ready(enemy: Node) -> bool:
	return enemy.has_method("health") and enemy.has_method("is_alive") \
		and enemy.has_method("take_damage") \
		and enemy.has_signal("died") and enemy.has_signal("health_changed")


## РўСЂРё СЃРёРіРЅР°Р»Р° СЃРјРµСЂС‚Рё РІСЂР°РіР°. РџРѕРґРїРёСЃС‡РёРє РѕРґРёРЅ РЅР° РІСЃРµ РёРЅСЃС‚Р°РЅСЃС‹ Рё РЅРµ Р·РЅР°РµС‚, РєР°РєРѕР№ РёР·
## РЅРёС… СѓРјРµСЂ, вЂ” СЃС‡С‘С‚С‡РёРє Рё СЃРѕСЃС‚РѕСЏРЅРёРµ РІ РјРѕРјРµРЅС‚ СЃРёРіРЅР°Р»Р° Рё РµСЃС‚СЊ РІРµСЃСЊ РЅР°Р±Р»СЋРґР°РµРјС‹Р№ СЃР»РµРґ.
func _on_enemy_died(enemy: Node) -> void:
	_enemy_died_count += 1
	_enemy_health_at_death = _enemy_health(enemy)
	_enemy_alive_at_death = _enemy_alive(enemy)


## Р”РѕСЃС‚СѓРї Рє Р·РґРѕСЂРѕРІСЊСЋ РІСЂР°РіР°. Р’С‹Р·РѕРІРѕРј call(), Р° РЅРµ С‚РёРїРёР·РёСЂРѕРІР°РЅРЅС‹Рј РґРѕСЃС‚СѓРїРѕРј: СЃС†РµРЅР°
## РѕС‚РґР°С‘С‚ CharacterBody3D, Р° health()/is_alive() Р¶РёРІСѓС‚ РІ enemy_contact.gd, Рё
## С…Р°СЂРґРєРѕРґ С‚РёРїР° Р·РґРµСЃСЊ РѕР·РЅР°С‡Р°Р» Р±С‹, С‡С‚Рѕ РїСЂРѕРІРµСЂРєР° РїРµСЂРµСЃС‚Р°Р»Р° РІРёРґРµС‚СЊ РЅР°СЃС‚РѕСЏС‰РёР№
## СЃРєСЂРёРїС‚. РРјРµРЅР° СЃ СЃСѓС„С„РёРєСЃРѕРј _enemy_ РѕС‚Р»РёС‡Р°СЋС‚ РёС… РѕС‚ РёРіСЂРѕРІС‹С… С…РµР»РїРµСЂРѕРІ РІС‹С€Рµ:
## РїРѕРґРїРёСЃС‡РёРєРё РЅР° СЃРёРіРЅР°Р»С‹ РёРіСЂРѕРєР° Рё РІСЂР°РіР° РґРѕР»Р¶РЅС‹ РѕСЃС‚Р°РІР°С‚СЊСЃСЏ СЂР°Р·РЅС‹РјРё.
func _enemy_health(enemy: Node) -> float:
	return float(enemy.call("health"))


func _enemy_alive(enemy: Node) -> bool:
	return bool(enemy.call("is_alive"))


func _color_near(got: Color, want: Color) -> bool:
	return absf(got.r - want.r) < _COLOR_EPS and absf(got.g - want.g) < _COLOR_EPS \
		and absf(got.b - want.b) < _COLOR_EPS and absf(got.a - want.a) < _COLOR_EPS


func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame


## РЎРІРѕР№ РјРёСЂ РїРѕРґ РєР°Р¶РґС‹Р№ СЃС†РµРЅР°СЂРёР№: РїРѕР» Рё СЃС‚РµРЅР° РІ РѕР±С‰РµР№ СЃС†РµРЅРµ РјРµС€Р°Р»Рё Р±С‹ РїСЂРѕРІРµСЂРєРµ
## В«РІСЂР°Рі РїРѕРїР°Р» РїРѕРґ СЃРЅР°СЂСЏРґ РґРѕ СЃС‚РµРЅС‹В», Р° РёРјСЏ СѓР·Р»Р° РІ СЃРѕРѕР±С‰РµРЅРёРё РѕР± РѕС€РёР±РєРµ РґРѕР»Р¶РЅРѕ
## РЅР°Р·С‹РІР°С‚СЊ С‚Сѓ СЃС‚РµРЅСѓ, РєРѕС‚РѕСЂР°СЏ РЅР° СЃР°РјРѕРј РґРµР»Рµ СЃС‚РѕСЏР»Р° РІ СЃС†РµРЅР°СЂРёРё.
func _new_world() -> Node3D:
	_world_id += 1
	var world := Node3D.new()
	world.name = "World%d" % _world_id
	root.add_child(world)
	return world


## РџРѕР» СЃР»РѕСЏ 1 (world) СЃ РІРµСЂС…РЅРµР№ РіСЂР°РЅСЊСЋ РЅР° top_y. Р’СЂР°Рі CharacterBody3D, Сѓ РєРѕС‚РѕСЂРѕРіРѕ
## РЅРµС‚ РЅРё РіСЂР°РІРёС‚Р°С†РёРё, РЅРё move_and_slide (РґРІРёР¶РµРЅРёРµ вЂ” Task 4), РІСЃС‚Р°Р» Р±С‹ РіРґРµ РµРіРѕ
## РїРѕСЃС‚Р°РІРёР»Рё, Р° РёРіСЂРѕРє Р±РµР· РїРѕР»Р° РїСЂРѕРІР°Р»РёР»СЃСЏ Р±С‹ РїРѕРґ РЅРѕР»СЊ РґРѕ РїРµСЂРІРѕРіРѕ С‚РёРєР°.
func _add_floor(world: Node3D, top_y: float = 0.0) -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "Floor"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	floor.add_child(shape)
	floor.collision_layer = _LAYER_WORLD
	floor.collision_mask = 0
	floor.position = Vector3(0.0, top_y - 0.5, 0.0)
	world.add_child(floor)
	return floor


## РЎС‚РµРЅР° СЃР»РѕСЏ 1 РїРµСЂРµРґ Р»РёС†РѕРј РЅР° front_x. РЎРЅР°СЂСЏРґ, РєРѕС‚РѕСЂС‹Р№ РЅРµ РЅР°С€С‘Р» РІСЂР°РіР°, РєРѕРЅС‡РёР»СЃСЏ
## Р±С‹ Р·РґРµСЃСЊ: РёРЅР°С‡Рµ В«СЃРЅР°СЂСЏРґ РїСЂРѕРїР°Р»В» Рё В«СЃРЅР°СЂСЏРґ РѕСЃС‚Р°РЅРѕРІРёР»СЃСЏ РЅР° РІСЂР°РіРµВ» вЂ” РѕРґРЅРѕ Рё С‚Рѕ
## Р¶Рµ РЅР°Р±Р»СЋРґРµРЅРёРµ.
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
	wall.position = Vector3(front_x + 0.5, 3.0, 0.0)
	world.add_child(wall)
	return wall


## РЎС‚Р°РІРёС‚ СѓР·РµР» РІ РїРѕР·РёС†РёСЋ Рё Р¶РґС‘С‚ РµРіРѕ РіРѕС‚РѕРІРЅРѕСЃС‚Рё. РџРѕР·РёС†РёСЏ Р·Р°РґР°С‘С‚СЃСЏ Р”Рћ РґРѕР±Р°РІР»РµРЅРёСЏ РІ
## РґРµСЂРµРІРѕ: СѓР·РµР», РєРѕС‚РѕСЂС‹Р№ РѕС‚СЂР°Р±РѕС‚Р°РµС‚ РєР°РґСЂ РІ СЃС‚РѕСЂРѕРЅРµ РѕС‚ С†РµР»Рё, Р° РїРѕС‚РѕРј teleport'РЅРµС‚СЃСЏ
## РЅР° РЅРµС‘, РґР°Р» Р±С‹ РїСЂРѕРІРµСЂРєРµ РїРѕРїР°РґР°РЅРёРµ, Р·Р°РІРёСЃСЏС‰РµРµ РѕС‚ С‚РѕРіРѕ, РіРґРµ РѕРЅ СЃС‚РѕСЏР» РІ С‚Сѓ СЃРµРєСѓРЅРґСѓ.
func _spawn_in(parent: Node, node: Node3D, pos: Vector3) -> bool:
	node.position = pos
	parent.add_child(node)
	for i in 120:
		if node.is_node_ready():
			return true
		await physics_frame
	return node.is_node_ready()


## РЎРЅР°СЂСЏРґ РёР· РЅР°СЃС‚РѕСЏС‰РµР№ СЃС†РµРЅС‹, РїРѕСЃС‚Р°РІР»РµРЅРЅС‹Р№ РІ РїРѕР·РёС†РёСЋ. launch() РІС‹Р·С‹РІР°РµС‚СЃСЏ
## РѕС‚РґРµР»СЊРЅРѕ Рё РїРѕСЃР»Рµ РїР°СѓР·С‹ РІ РєР°РґСЂ: РґРІР° СЃРЅР°СЂСЏРґР°, РІС‹РїСѓС‰РµРЅРЅС‹Рµ РІ СЂР°Р·РЅС‹Рµ РєР°РґСЂС‹,
## СЂР°Р·СЉРµРґСѓС‚СЃСЏ РЅР° С‡РµС‚РІРµСЂС‚СЊ РјРµС‚СЂР° Рё РЅРµ РїРѕРїР°РґСѓС‚ РІ РѕРґРЅСѓ С†РµР»СЊ РІ РѕРґРёРЅ РєР°РґСЂ, Р° РІРµСЃСЊ
## СЃРјС‹СЃР» РїСЂРѕРІРµСЂРєРё В«РґРІР° СЃРЅР°СЂСЏРґР°, РѕРґРЅР° С†РµР»СЊ, РѕРґРёРЅ РєР°РґСЂВ» РёРјРµРЅРЅРѕ РІ СЌС‚РѕРј.
func _spawn_projectile(world: Node3D, pos: Vector3) -> Projectile:
	var packed: PackedScene = load(_PROJECTILE_PATH)
	if packed == null:
		_bail("cannot load %s" % _PROJECTILE_PATH)
		return null
	var bullet := packed.instantiate() as Projectile
	bullet.position = pos
	world.add_child(bullet)
	return bullet


## РЎРєРѕР»СЊРєРѕ С‚РёРєРѕРІ РґРѕ РёСЃС‡РµР·РЅРѕРІРµРЅРёСЏ СѓР·Р»Р° РёР»Рё -1, РµСЃР»Рё РѕРЅ РїРµСЂРµР¶РёР» cap. РЈР·РµР» РїРѕСЃР»Рµ
## queue_free() РµС‰С‘ СЃСѓС‰РµСЃС‚РІСѓРµС‚ РґРѕ РєРѕРЅС†Р° РєР°РґСЂР°, РІ РєРѕС‚РѕСЂРѕРј СѓРґР°Р»С‘РЅ, РїРѕСЌС‚РѕРјСѓ
## РІРѕР·РІСЂР°С‰Р°РµС‚СЃСЏ РЅРѕРјРµСЂ С‚РёРєР°, РѕРєСЂСѓРіР»С‘РЅРЅС‹Р№ РІРІРµСЂС… РґРѕ СЃР»РµРґСѓСЋС‰РµРіРѕ.
func _frames_until_free(node: Node, cap: int) -> int:
	for i in cap:
		if not is_instance_valid(node):
			return i
		await physics_frame
	return -1


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

	await _test_player_health()
	await _test_contact_enemy()

	if _bailed:
		# _bail() СѓР¶Рµ РЅР°РїРµС‡Р°С‚Р°Р» СЃРІРѕРґРєСѓ Рё Р·Р°РїСЂРѕСЃРёР» quit(1). Р’С‚РѕСЂРѕР№ quit() Р·РґРµСЃСЊ
		# РїРµСЂРµР·Р°РїРёСЃР°Р» Р±С‹ РєРѕРґ РІРѕР·РІСЂР°С‚Р° РЅСѓР»С‘Рј, Рё FATAL РїСЂРѕС‡РёС‚Р°Р»Рё Р±С‹ РєР°Рє PASS.
		quit(1)
		return
	_finish()
	quit(1 if _failures.size() > 0 else 0)

---

## Fix report section (tail of task-3-report.md)
# Fix round 1 вЂ” Р·Р°РјРµС‡Р°РЅРёСЏ СЂРµРІСЊСЋ

**РЎС‚Р°С‚СѓСЃ:** DONE. Finding В«ImportantВ» СѓСЃС‚СЂР°РЅС‘РЅ С†РµР»РёРєРѕРј, РёРіСЂР°Р»СЊРЅС‹Р№ РєРѕРґ РЅРµ РјРµРЅСЏР»СЃСЏ.

## F1. Р Р°Р·Р»РёС‡Р°СЋС‰Р°СЏ РїСЂРѕРІРµСЂРєР° В«СѓСЂРѕРЅ Р±РµСЂС‘С‚СЃСЏ РёР· `data.contact_damage`В»

**Р—Р°РјРµС‡Р°РЅРёРµ (РґРѕСЃР»РѕРІРЅРѕ СЃРјС‹СЃР»):** Р±СЂРёС„ С‚СЂРµР±СѓРµС‚ В«РўРµСЃС‚РѕРІС‹Р№ СѓСЂРѕРЅ Р±РµСЂС‘С‚СЃСЏ РёР·
`data.contact_damage`, РЅРµ Р·Р°С…Р°СЂРґРєРѕР¶РµРЅВ», РЅРѕ РїСЂРѕРІРµСЂРєРё СЃСЂР°РІРЅРёРІР°Р»Рё СЃ Р»РёС‚РµСЂР°Р»РѕРј `10.0`,
Рё СЂРµР°Р»РёР·Р°С†РёСЏ СЃ `player.call("take_damage", 10.0)` РїСЂРѕС…РѕРґРёР»Р° РІСЃС‘. РџР»СЋСЃ РїСЂРѕРІРµСЂРєР°
В«СѓСЂРѕРЅ Р·Р° С‚РёРє Р±СЂР°Р»СЃСЏ РёР· data.contact_damage вЂ¦В» Р±С‹Р»Р° РёР·Р±С‹С‚РѕС‡РЅР°.

**Р§С‚Рѕ РёР·РјРµРЅРµРЅРѕ вЂ” С‚РѕР»СЊРєРѕ `tests/enemies.gd`, С„СѓРЅРєС†РёСЏ `_test_enemy_contact_tick`.**
РРіСЂРѕРІРѕР№ РєРѕРґ РЅРµ С‚СЂРѕРЅСѓС‚: `scripts/enemy_contact.gd`, `enemy_contact.tscn`, `player.gd`
Рё `tools/run_checks.ps1` РїРѕР±Р°Р№С‚РѕРІРѕ С‚Рµ Р¶Рµ.

1. **РЎС†РµРЅР°СЂРёР№ РІРµРґС‘С‚СЃСЏ РЅР° РЅРµСЃС‚Р°РЅРґР°СЂС‚РЅРѕРј СѓСЂРѕРЅРµ.** РџРµСЂРµРґ СЃРїР°РІРЅРѕРј РІСЂР°РіСѓ РїРѕРґСЃС‚Р°РІР»СЏРµС‚СЃСЏ
   **РґСѓР±Р»РёРєР°С‚** `EnemyData` СЃ `contact_damage = 7.5` (`enemy.get("data").duplicate()`
   в†’ `probe.contact_damage = 7.5` в†’ `enemy.set("data", probe)`). Р”СѓР±Р»РёРєР°С‚, Р° РЅРµ РїСЂР°РІРєР°
   `contact.tres`: СЂРµСЃСѓСЂСЃ С‡РёС‚Р°СЋС‚ СЂР°Р·РґРµР»С‹ Tasks 1вЂ“2, Рё РїСЂР°РІРєР° РЅР° РјРµСЃС‚Рµ СѓС‚РµРєР»Р° Р±С‹ РІ РЅРёС….
   РџСЂРё 7.5 Р·Р°С…Р°СЂРґРєРѕР¶РµРЅРЅР°СЏ РґРµСЃСЏС‚РєР° РЅРµ РјРѕР¶РµС‚ СЃРѕРІРїР°СЃС‚СЊ РЅРё СЃ РѕРґРЅРёРј РїСЂРѕРёР·РІРѕРґРЅС‹Рј С‡РёСЃР»РѕРј.
   РќРѕРІРѕРµ **РїСЂРµРґСѓСЃР»РѕРІРёРµ** РїРµС‡Р°С‚Р°РµС‚ РѕР±Р° С‡РёСЃР»Р° Рё РїР°РґР°РµС‚, РµСЃР»Рё РїРѕРґСЃС‚Р°РЅРѕРІРєР° РЅРµ СЃСЂР°Р±РѕС‚Р°Р»Р°:
   ```
   [PASS] precondition: СЃС†РµРЅР°СЂРёР№ РєРѕРЅС‚Р°РєС‚Р° РёРґС‘С‚ РїРѕ РќР•РЎРўРђРќР”РђР РўРќРћРњРЈ СѓСЂРѕРЅСѓ Р·Р° С‚РёРє, Р° РЅРµ РїРѕ 10.0 РёР· contact.tres
          (contact_damage 7.5000, СѓСЂРѕРЅ contact.tres 10.0000)
   ```
2. **Р’СЃРµ РѕР¶РёРґР°РµРјС‹Рµ С‡РёСЃР»Р° РІС‹РІРµРґРµРЅС‹, Р° РЅРµ Р·Р°С€РёС‚С‹.** РР· `data.contact_damage` Рё
   `player.max_health`:
   - `ticks_to_death = ceil(max_health / contact_damage)` = `ceil(100/7.5)` = **14**;
   - `survivable_ticks = ticks_to_death - 1` = **13** (РІРјРµСЃС‚Рѕ Р¶С‘СЃС‚РєРёС… В«РґРµРІСЏС‚РёВ»);
   - `health_before_death = max_health - survivable_ticks * contact_damage` = **2.5**
     (РІРјРµСЃС‚Рѕ Р¶С‘СЃС‚РєРёС… `10.0`);
   - `interval_ticks = round(contact_interval * 120)` = **12** вЂ” РёР· СЌРєСЃРїРѕСЂС‚Р° РІСЂР°РіР°,
     СЂР°РЅСЊС€Рµ Р»РёС‚РµСЂР°Р» В«12 С‚РёРєРѕРІВ» Р±С‹Р» Р·Р°С€РёС‚ РІ РїРѕРґРїРёСЃСЊ Рё РІ СЃСЂР°РІРЅРµРЅРёРµ;
   - РіСЂР°РЅРёС†Р° В«РїРµСЂРІС‹Р№ С‚РёРє РЅР° РІС…РѕРґРµВ» вЂ” `maxi(2, interval_ticks / 2)` = 6 РІРјРµСЃС‚Рѕ 5
     (С‚РёРє РїРѕ СЂР°СЃРїРёСЃР°РЅРёСЋ РѕРїРѕР·РґР°Р» Р±С‹ РЅР° С†РµР»С‹Р№ РёРЅС‚РµСЂРІР°Р», С‚РёРє РЅР° РІС…РѕРґСѓ РїСЂРёС…РѕРґРёС‚ Р·Р° 1 РєР°РґСЂ).
   Р”РёР°РіРѕРіРёС‡РµСЃРєР°СЏ РїРµС‡Р°С‚СЊ СЂР°Р·РґРµР»Р°:
   ```
   СѓСЂРѕРЅ Р·Р° С‚РёРє 7.5000, HP РёРіСЂРѕРєР° 100.0, С‚РёРєРѕРІ РґРѕ СЃРјРµСЂС‚Рё 14, РЅР° РіСЂР°РЅРёС†Рµ РѕСЃС‚Р°С‘С‚СЃСЏ 2.5000
   С‚РёРєРё РєРѕРЅС‚Р°РєС‚Р°: [115, 128, 140, 152, 164, 176, 188, 200, 212, 224, 236, 248, 260] (РёРЅС‚РµСЂРІР°Р» 12 С‚РёРєРѕРІ)
   ```
3. **РќРѕРІР°СЏ РїСЂРѕРІРµСЂРєР° СѓСЂРѕРЅР° Р·Р° РєР°Р¶РґС‹Р№ С‚РёРє**, Р° РЅРµ С‚РѕР»СЊРєРѕ РЅР° РіСЂР°РЅРёС†Рµ. Р’ С†РёРєР»Рµ РѕРїСЂРѕСЃР°
   СЃС‡РёС‚Р°РµС‚СЃСЏ С…СѓРґС€Р°СЏ РѕС€РёР±РєР° `|РїСЂРѕС€Р»С‹Р№ HP в€’ С‚РµРєСѓС‰РёР№ HP в€’ contact_damage|`, Рё РѕРЅР°
   СЃСЂР°РІРЅРёРІР°РµС‚СЃСЏ СЃ `_HEALTH_EPS`:
   ```
   [PASS] СѓСЂРѕРЅ РљРђР–Р”РћР“Рћ С‚РёРєР° СЂР°РІРµРЅ data.contact_damage, Р° РЅРµ Р·Р°С…Р°СЂРґРєРѕР¶РµРЅРЅРѕРјСѓ С‡РёСЃР»Сѓ
          (С…СѓРґС€Р°СЏ РѕС€РёР±РєР° Р·Р° С‚РёРє 0.0000 РїСЂРё СѓСЂРѕРЅРµ 7.5000)
   ```
   РРјРµРЅРЅРѕ СЌС‚Р° РїСЂРѕРІРµСЂРєР° Р»РѕРІРёС‚ РїРѕРґРјРµРЅСѓ РІ РїРµСЂРІРѕРј Р¶Рµ С‚РёРєРµ, С‚РѕРіРґР° РєР°Рє СЃСѓРјРјР° Р·Р° N С‚РёРєРѕРІ
   РјРѕРіР»Р° Р±С‹ СЃРѕР№С‚РёСЃСЊ РїСЂРё РєСЂСѓРіР»РѕР№ РїРѕРґРјРµРЅРµ.
4. **РР·Р±С‹С‚РѕС‡РЅР°СЏ РїСЂРѕРІРµСЂРєР° СѓР±СЂР°РЅР°.** `_check(_near(contact_damage, 10.0), "СѓСЂРѕРЅ Р·Р° С‚РёРє
   Р±СЂР°Р»СЃСЏ РёР· data.contact_damage, Р° РЅРµ РёР· Р·Р°С…Р°СЂРґРєРѕР¶РµРЅРЅРѕР№ РґРµСЃСЏС‚РєРё")` СѓРґР°Р»РµРЅР°: РѕРЅР°
   РїРѕРІС‚РѕСЂСЏР»Р° СѓС‚РІРµСЂР¶РґРµРЅРёРµ Tasks 1вЂ“2 Рѕ `contact.tres.contact_damage == 10.0` Рё РЅРµ РјРѕРіР»Р°
   РєСЂР°СЃРЅРµС‚СЊ. Р•С‘ СЂРѕР»СЊ РїРµСЂРµС€Р»Р° Рє Рї. 3 Рё Рє РїСЂРµРґСѓСЃР»РѕРІРёСЋ РёР· Рї. 1.
5. РћСЃС‚Р°Р»СЊРЅС‹Рµ РїРѕРґРїРёСЃРё СЂР°Р·РґРµР»Р° РїРµСЂРµРІРµРґРµРЅС‹ РЅР° РїСЂРѕРёР·РІРѕРґРЅС‹Рµ С‡РёСЃР»Р°
   (В«РїРѕР»СѓС‡РµРЅРѕ СЂРѕРІРЅРѕ 13 С‚РёРєРѕРІВ», В«РїРѕСЃР»Рµ 13 С‚РёРєРѕРІ РѕСЃС‚Р°Р»РѕСЃСЊ СЂРѕРІРЅРѕ 2.5000 HP
   (max_health в€’ 13 * contact_damage)В», В«С‚РёРє 14 РєРѕРЅС‚Р°РєС‚Р° СѓР±РёРІР°РµС‚ РёРіСЂРѕРєР°В»).

## РџРѕРєСЂС‹РІР°СЋС‰РёРµ РїСЂРѕРІРµСЂРєРё

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies
RESULT: 1 passed, 0 failed, 0 skipped
EXIT=0
```

Р’РЅСѓС‚СЂРµРЅРЅСЏСЏ СЃРІРѕРґРєР°: `=== RESULT: 106 checks, 0 failed ===` (Р±С‹Р»Рѕ 105; +1 РїСЂРµРґСѓСЃР»РѕРІРёРµ
Рё +1 РїСЂРѕРІРµСЂРєР° СѓСЂРѕРЅР° Р·Р° РєР°Р¶РґС‹Р№ С‚РёРє, в€’1 Р·Р° РёР·Р±С‹С‚РѕС‡РЅСѓСЋ).

РџРѕР»РЅС‹Р№ РїСЂРѕРіРѕРЅ:

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1
smoke PASS / movement PASS / input_actions PASS / input_gate PASS / weapon_data PASS
integrity PASS / weapon PASS / projectile PASS / enemies PASS
waves, save, progression [SKIP]
RESULT: 9 passed, 0 failed, 3 skipped
EXIT=0
```

9 passed, Р° РЅРµ 10 вЂ” С‚Рѕ Р¶Рµ СЂР°СЃС…РѕР¶РґРµРЅРёРµ РёР· СЂР°Р·РґРµР»Р° 5 РѕСЃРЅРѕРІРЅРѕР№ С‡Р°СЃС‚Рё: РІ `$Tests` СЂР°РЅРЅРµСЂР°
12 РёРјС‘РЅ, РёР· РЅРёС… 9 СЃСѓС‰РµСЃС‚РІСѓСЋС‚. `tools/run_checks.ps1` РЅРµ РјРµРЅСЏР»СЃСЏ.

## Р”РѕРєР°Р·Р°С‚РµР»СЊСЃС‚РІРѕ, С‡С‚Рѕ РёСЃРїСЂР°РІР»РµРЅРЅС‹Рµ РїСЂРѕРІРµСЂРєРё РїР°РґР°СЋС‚

РњСѓС‚Р°С†РёСЏ (d): `scripts/enemy_contact.gd`, `_deal_contact_damage()` вЂ”
`player.call("take_damage", data.contact_damage)` в†’ `player.call("take_damage", 10.0)`.
РўРѕС‡РєР° РѕРґРЅР° РЅР° РѕР±Р° РїСѓС‚Рё (РЅРµРјРµРґР»РµРЅРЅС‹Р№ С‚РёРє РЅР° РІС…РѕРґРµ Рё С‚РёРє РїРѕ РєР°РґРµРЅС†РёРё), РїРѕСЌС‚РѕРјСѓ РїРѕРґРјРµРЅР°
РїРѕРєСЂС‹РІР°РµС‚ СЂРѕРІРЅРѕ С‚Рѕ, С‡С‚Рѕ РїСЂРѕРІРµСЂСЏРµС‚ СЃРµРєС†РёСЏ.

```
MUT-D FDD8C39A05ADB1C3DE10CD6D9E185E6CA03AD1BE65DF33F95126F3287391860D

      [FAIL] СѓСЂРѕРЅ РљРђР–Р”РћР“Рћ С‚РёРєР° СЂР°РІРµРЅ data.contact_damage, Р° РЅРµ Р·Р°С…Р°СЂРґРєРѕР¶РµРЅРЅРѕРјСѓ С‡РёСЃР»Сѓ
             (С…СѓРґС€Р°СЏ РѕС€РёР±РєР° Р·Р° С‚РёРє 97.5000 РїСЂРё СѓСЂРѕРЅРµ 7.5000)
      [FAIL] РїРѕСЃР»Рµ 13 С‚РёРєРѕРІ Сѓ РёРіСЂРѕРєР° РѕСЃС‚Р°Р»РѕСЃСЊ СЂРѕРІРЅРѕ 2.5000 HP (max_health - 13 * contact_damage)
             (got 70.0000)
      [FAIL] РёРіСЂРѕРє СЂРµСЃРїР°РІРЅРёР»СЃСЏ СЃ РїРѕР»РЅС‹Рј Р·РґРѕСЂРѕРІСЊРµРј max_health (РєРѕРЅС‚СЂР°РєС‚ Task 2)
             (got 60.0000, max_health 100.0000)
    === RESULT: 106 checks, 3 failed ===
RESULT: 0 passed, 1 failed, 0 skipped      EXIT=1
```

Р’РѕСЃСЃС‚Р°РЅРѕРІР»РµРЅРёРµ Р±Р°Р№С‚-РІ-Р±Р°Р№С‚:

```
RESTORED-D A0BCA85A5541518AD5FF423E6857A3268BAA2953AA06A1AA3EE805430B0D8ABF   (== РёСЃС…РѕРґРЅС‹Р№)
RESULT: 1 passed, 0 failed, 0 skipped
```

Р—Р°РјРµС‡Р°РЅРёРµ РґР»СЏ СЂРµРІСЊСЋ: РїСЂРё РїРѕРґРјРµРЅРµ РЅР° 10.0 РєСЂР°СЃРЅРµСЋС‚ С‚СЂРё РїСЂРѕРёР·РІРѕРґРЅС‹С… СѓС‚РІРµСЂР¶РґРµРЅРёСЏ.
РЈС‚РІРµСЂР¶РґРµРЅРёРµ В«РїРѕР»СѓС‡РµРЅРѕ СЂРѕРІРЅРѕ 13 С‚РёРєРѕРІВ» РїСЂРё СЌС‚РѕРј РѕСЃС‚Р°С‘С‚СЃСЏ Р·РµР»С‘РЅС‹Рј вЂ” СЃ СѓСЂРѕРЅРѕРј 10 РёРіСЂРѕРє
СѓРјРёСЂР°РµС‚ РЅР° РґРµСЃСЏС‚РѕРј С‚РёРєРµ Рё СЂРµСЃРїР°РІРЅРёС‚СЃСЏ, Р° РѕРїСЂРѕСЃ Р»РѕРІРёС‚ РїР°РґРµРЅРёРµ HP Рё РїРѕСЃР»Рµ СЂРµСЃРїР°РІРЅР°
СЃРЅРѕРІР°, РїРѕСЌС‚РѕРјСѓ СЃС‡С‘С‚С‡РёРє С‚РёРєРѕРІ СЃР»СѓС‡Р°Р№РЅРѕ РЅР°Р±РёСЂР°РµС‚ 13. Р­С‚Рѕ РЅРµ РґС‹СЂР° РІ РєРѕРЅС‚СЂР°РєС‚Рµ: Р·РґРѕСЂРѕРІСЊРµ
РЅР° РіСЂР°РЅРёС†Рµ, СѓСЂРѕРЅ Р·Р° С‚РёРє Рё СЂРµСЃРїР°РІРЅ РїСЂРѕРІРµСЂСЏСЋС‚СЃСЏ РЅР°РїСЂСЏРјСѓСЋ, Рё РёРјРµРЅРЅРѕ РѕРЅРё РєСЂР°СЃРЅРµСЋС‚.

## РҐРµС€Рё (SHA-256) РїРѕСЃР»Рµ fix round 1

| Р¤Р°Р№Р» | SHA-256 | РР·РјРµРЅРёР»СЃСЏ? |
|---|---|---|
| `scripts/enemy_contact.gd` | `A0BCA85A5541518AD5FF423E6857A3268BAA2953AA06A1AA3EE805430B0D8ABF` | РЅРµС‚ (С‚РѕС‚ Р¶Рµ, С‡С‚Рѕ РІ СЂР°Р·РґРµР»Рµ 8) |
| `enemy_contact.tscn` | `F197B98DA13C5CF31AFC26EF1E4A072D89CC423F5C78E137B2FF59E18D25446B` | РЅРµС‚ |
| `player.gd` | `2C7D8853CA9815D5EF3425B3A49A62095E950700B49B35415FD9319FC2A79684` | РЅРµС‚ |
| `tests/enemies.gd` | `9FAF551519206FAAF4BA77B97BBAB058D6DFB6672C753B08B4443BAE4FCBBA74` | **РґР°** (Р±С‹Р»Рѕ `A62C244CвЂ¦0516917`) |

Git-РјСѓС‚Р°С†РёРё РїРѕ-РїСЂРµР¶РЅРµРјСѓ РЅРµ РІС‹РїРѕР»РЅСЏР»РёСЃСЊ.

