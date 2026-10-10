class_name GameState
extends Node

## Глобальное состояние прогресса: очки, купленное и экипированное оружие,
## открытые локации. Живёт как автозагрузка /root/GameState (проводка — Task 6).
##
## Два правила, ради которых этот узел существует:
##   * Переходы между сценами идут ТОЛЬКО через подменяемый `scene_changer`.
##     Спека §6.1 запрещает прямой change_scene_to_file в игровых сценах: смена
##     сцены из середины игрового кода делает переход невидимым для тестов и
##     для того, кто читает вызывающий код. Здесь это единственная дверь, и в
##     тестах она подменяется записывающей заглушкой.
##   * Каждое изменение (очки, покупка, экипировка) автосохраняется через
##     /root/SaveSystem, если он есть. Null-safe: сцена или тест без
##     автозагрузки просто ничего не сохраняет и не падает.
##
## Числа очков — временный баланс владельца (PROJECT.md §7.5): убийство 10,
## волна 50, зачистка 500. Волны и зачистка начнут начисляться в Фазе 4;
## константы заданы уже здесь, чтобы Фазе 4 не пришлось их изобретать.

## Очки изменились. Сигнал об изменении, а не о существовании: начальное
## значение читается напрямую из `points`. HUD подписывается на него, а не
## опрашивает поле каждый кадр.
signal points_changed(points: int)

## Сменилось экипированное оружие (Task 10). Сигнал об изменении, а не о
## существовании: начальное значение читается из `equipped_weapon_id`.
## Игрок подписывается на него, чтобы поменять ствол в руках, а не опрашивать
## поле каждый кадр. Испускается из `equip_weapon` и из ветки покупки
## `buy_weapon` — там, где `equipped_weapon_id` реально меняется.
signal equipped_changed(weapon_id: String)

const POINTS_PER_KILL := 10
const POINTS_PER_WAVE := 50
const POINTS_PER_CLEAR := 500

## id локации -> сцена. Приватный: наружу торчит только enter_location(id).
## "range" — временный бой через дверь лобби; настоящая локация появится в
## Фазе 4, и тогда карта вырастет, а вызывающий код не изменится.
const _LOCATION_SCENES := {
	"range": "res://range.tscn",
}

## id оружия -> сцена, которую игрок держит в руках. Единый источник «id → файл»
## (Task 10): и витрина, и `player.gd` спрашивают сцену здесь, а не собирают путь
## из id каждый по-своему. Приватный; наружу торчит только weapon_scene_path(id).
const _WEAPON_SCENES := {
	"pistol": "res://pistol.tscn",
	"auto": "res://auto.tscn",
}

var points: int = 0
var owned_weapons: PackedStringArray = ["pistol"]
var equipped_weapon_id: String = "pistol"
var unlocked_locations: PackedStringArray = ["range"]

## Подменяемый в тестах. Значение по умолчанию ставится в `_ready()`, а НЕ в
## `_init()`: при ручном `GameState.new()` + `add_child()` (сцена или тест без
## автозагрузки) `get_tree()` в `_init()` ещё null, и Callable указывал бы в
## пустоту. Инъекция из теста ставится ДО add_child, поэтому `_ready()`
## заполняет значение только если его никто не задал (см. там же).
var scene_changer: Callable

## TEMP(dev): разовая выдача стартового капитала, чтобы владелец мог сразу
## проверить покупку автомата за 300. Убирается отдельной задачей — это НЕ
## баланс и НЕ часть контракта класса: дефолт `points` остаётся 0, а тесты и
## headless-прогон ничего не получают (гейт по имени дисплейсера ниже). Заодно
## защищены две вещи, которые иначе сломались бы: `tests/progression.gd`
## (`points start at 0`/`STARTING_POINTS`) и проверка автосейва в тест-прогоне
## (user://save.json в headless не создаётся, потому что выдача не срабатывает).
const _TEMP_DEV_STARTING_POINTS := 300
## Выдача ровно один раз за сессию, а не на каждом входе в лобби. Флаг на
## экземпляре: GameState — автозагрузка, и её `_ready()` выполняется один раз на
## процесс, но флаг оставляет намерение явным и защищает от ручного повторного
## входа, если это когда-нибудь понадобится.
var _temp_dev_grant_done: bool = false


func _ready() -> void:
	# Заполнить движковый переход, только если его никто не подменил. Дефолтный
	# Callable невалиден, поэтому is_valid() отличает «не задан» от заглушки,
	# присвоенной до входа в дерево.
	if not scene_changer.is_valid():
		scene_changer = Callable(get_tree(), "change_scene_to_file")
	# Восстановление только при наличии SaveSystem: он появляется как автозагрузка
	# в Task 6, а до тех пор состояние стартует с дефолтов.
	var ss := get_node_or_null("/root/SaveSystem")
	if ss != null:
		_restore(ss.load_state())
	_apply_temp_dev_starting_points()


## TEMP(dev): выдать 300 один раз за сессию. Только на живом дисплейсере:
## `--headless` не должен ни менять очки (это сломало бы проверки старта), ни
## вызывать автосейв (он создал бы user://save.json в тест-прогоне). Проверка
## через max() означает, что уже большее значение (восстановленный сейв) не
## понижается. Сигнал испускается, потому что это изменение points.
func _apply_temp_dev_starting_points() -> void:
	if _temp_dev_grant_done:
		return
	_temp_dev_grant_done = true
	if DisplayServer.get_name() == "headless":
		return
	if points >= _TEMP_DEV_STARTING_POINTS:
		return
	points = _TEMP_DEV_STARTING_POINTS
	points_changed.emit(points)


## Цена оружия из его ресурса. Нет файла или битый ресурс — 0: витрина должна
## показать цену, не падая на отсутствующем оружии. Отдельный вопрос — можно ли
## такое оружие купить; на него отвечает buy_weapon, а не цена.
func weapon_price(id: String) -> int:
	var data := _load_weapon(id)
	return data.price if data != null else 0


## Сцена оружия по id или пустая строка, если id неизвестен. Игрок по ней
## меняет ствол в руках; пустая строка — «менять не на что», а не ошибка.
func weapon_scene_path(id: String) -> String:
	return _WEAPON_SCENES.get(id, "")


## Начисление очков. Отрицательные значения игнорируются: это не «штраф», а
## защита от опечатки в вызывающем коде, которая тихо уменьшила бы счёт.
func award_points(amount: int) -> void:
	if amount < 0:
		return
	points += amount
	points_changed.emit(points)
	_autosave()


func can_afford(cost: int) -> bool:
	return points >= cost


## Покупка. Уже купленное только экипируется, без второго списания. При нехватке
## очков — отказ без изменений. Несуществующее оружие купить нельзя: иначе
## отсутствие файла (weapon_price == 0) открывало бы бесплатную покупку того,
## чего нет.
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
	points_changed.emit(points)
	equipped_changed.emit(equipped_weapon_id)
	_autosave()
	return true


## Экипировка только из купленного.
func equip_weapon(id: String) -> bool:
	if not (id in owned_weapons):
		return false
	equipped_weapon_id = id
	equipped_changed.emit(equipped_weapon_id)
	_autosave()
	return true


## Вход в локацию только из открытых и только на известную сцену; иначе отказ
## БЕЗ смены сцены.
func enter_location(id: String) -> bool:
	if not (id in unlocked_locations):
		return false
	if not _LOCATION_SCENES.has(id):
		return false
	scene_changer.call(_LOCATION_SCENES[id])
	return true


## Возврат в лобби. reason пока не используется — параметр под будущие экраны
## («смерть», «выход из боя»), чтобы сигнатуру не пришлось менять задним числом.
@warning_ignore("unused_parameter")
func return_to_lobby(reason: String) -> void:
	scene_changer.call("res://lobby.tscn")


## Словарь для SaveSystem: ровно то, что переживает перезапуск. Packed-массивы
## конвертируются в обычные Array — JSON-совместимый вид, который load_state()
## вернёт как Array.
func _persist() -> Dictionary:
	return {
		"points": points,
		"owned_weapons": Array(owned_weapons),
		"equipped_weapon_id": equipped_weapon_id,
		"unlocked_locations": Array(unlocked_locations),
	}


## Применяет только присутствующие ключи и только подходящих типов: битый или
## частичный сейв (или сейв из другой версии игры) не должен ронять
## восстановление и не должен затирать дефолт мусором.
func _restore(saved: Dictionary) -> void:
	if saved.has("points") and (saved["points"] is int or saved["points"] is float):
		points = int(saved["points"])
		points_changed.emit(points)
	if saved.has("owned_weapons") and saved["owned_weapons"] is Array:
		owned_weapons = _to_string_array(saved["owned_weapons"])
	if saved.has("equipped_weapon_id") and saved["equipped_weapon_id"] is String:
		equipped_weapon_id = saved["equipped_weapon_id"]
	if saved.has("unlocked_locations") and saved["unlocked_locations"] is Array:
		unlocked_locations = _to_string_array(saved["unlocked_locations"])


## Автосейв после каждого мутатора. Null-safe: без автозагрузки SaveSystem
## сохранять некуда, и это не ошибка.
func _autosave() -> void:
	var ss := get_node_or_null("/root/SaveSystem")
	if ss != null and ss.has_method("save"):
		ss.save(_persist())


## Загрузка ресурса оружия по id. Пустой id или отсутствующий файл — null.
func _load_weapon(id: String) -> WeaponData:
	if id.is_empty():
		return null
	return load("res://data/weapons/%s.tres" % id) as WeaponData


## Array из JSON -> PackedStringArray. Не-строки отбрасываются, чтобы битый сейв
## не мог положить в мешок оружия мусор чужого типа.
func _to_string_array(value: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for item in value:
		if item is String:
			out.append(item)
	return out
