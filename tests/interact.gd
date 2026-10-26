extends SceneTree

## Тестовый сценарий взаимодействия для VibeFPS (Фаза 3, лобби ветка A): интерактивные точки
## ShopPoint и DoorPoint, метод поиска ближайшего объекта игрока nearest_interactable()
## и обработка клавиши взаимодействия E (interact) через гейт ввода.
##
## Автозагрузка SaveSystem изолируется вручную по пути user://interact_test.json
## — аналогично tests/progression.gd, исключая затрагивание боевого user://save.json.
## Переходы между сценами идут через фейковый обработчик: в headless-режиме нет окна
## для смены сцен.
##
## Персонаж создается из реальной сцены player.tscn с тестовым скриптом _PlayerProbe,
## эмулирующим режим захвата курсора для гейта ввода. Взаимодействие обрабатывается
## в _unhandled_input персонажа через события InputEventKey с принудительным
## сбросом буфера событий Input.flush_buffered_events().
##
## Запуск: godot --headless --path . --script res://tests/interact.gd
##         .\tools\run_checks.ps1 interact


## Тестовый зонд на базе player.gd.
class _PlayerProbe extends "res://entities/player/player.gd":
	## Режим мыши, передаваемый гейту ввода вместо Input.mouse_mode.
	var gate_mouse_mode: int = Input.MOUSE_MODE_CAPTURED

	func _mouse_mode_for_play_input() -> int:
		return gate_mouse_mode


## Регистратор сигналов ShopPoint.
class _ShopLog extends RefCounted:
	var ok_values: Array[bool] = []

	func _on_interacted(ok: bool) -> void:
		ok_values.append(ok)


## Изолированный путь сохранения для теста. user://save.json никогда не затрагивается.
const _TMP_PATH := "user://interact_test.json"
const _PLAYER_SCENE := "res://entities/player/player.tscn"
const _SHOP_SCRIPT := "res://levels/lobby/shop_point.gd"
const _DOOR_SCRIPT := "res://levels/lobby/door_point.gd"

## Ожидаемая дальность взаимодействия персонажа (3.5 м).
const _EXPECTED_RANGE := 3.5
## Стоимость автомата для проверки покупки.
const _AUTO_PRICE := 300

var _failures: PackedStringArray = []
var _checks := 0

var _save: SaveSystem
var _gs: GameState
var _shop: ShopPoint
var _door: DoorPoint
var _player: CharacterBody3D
var _shop_log: _ShopLog
## Зафиксированные пути смены сцен в порядке вызова.
var _changed_to: PackedStringArray = []


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


func _finish() -> void:
	print("=== ИТОГ: проверок %d, ошибок %d ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  ОШИБКА: %s" % f)


## Фейковый обработчик смены сцен: только логирует запрошенные пути.
func _fake_changer(path: String) -> void:
	_changed_to.append(path)


## Сравнение PackedStringArray и Array по элементам.
func _packed_eq(packed: PackedStringArray, expected: Array) -> bool:
	if packed.size() != expected.size():
		return false
	for i in packed.size():
		if packed[i] != expected[i]:
			return false
	return true


## Создание события клавиатуры для действия interact (клавиша E).
func _interact_key_event(pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.keycode = KEY_E
	ev.pressed = pressed
	return ev


## Строка подсказки экспортированного свойства объекта.
func _property_hint(node: Object, property_name: String) -> String:
	for entry in node.get_property_list():
		if String(entry.get("name", "")) == property_name:
			return String(entry.get("hint_string", ""))
	return "<отсутствует>"


## Тип экспортированного свойства из get_property_list().
func _property_type(node: Object, property_name: String) -> Variant.Type:
	for entry in node.get_property_list():
		if String(entry.get("name", "")) == property_name:
			return entry.get("type", TYPE_NIL)
	return TYPE_NIL


func _cleanup() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_TMP_PATH))


## Удаление автозагрузок проекта перед тестом, чтобы тестовые узлы владели именами в /root.
func _drop_autoloads() -> void:
	for autoload_name in ["GameState", "SaveSystem"]:
		var node := root.get_node_or_null(autoload_name)
		if node != null:
			root.remove_child(node)
			node.free()


# --------------------------------------------------------------------------
# построение тестового окружения
# --------------------------------------------------------------------------

## Пол под ногами персонажа для предотвращения падения при физических тиках.
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
# точка входа
# --------------------------------------------------------------------------

func _initialize() -> void:
	print("=== VibeFPS: тест взаимодействия ===")
	_drop_autoloads()
	# Очистка остатков сохранения от прошлых запусков.
	_cleanup()

	_save = SaveSystem.new()
	_save.name = "SaveSystem"
	_save.save_path = _TMP_PATH
	root.add_child(_save)

	_gs = GameState.new()
	_gs.name = "GameState"
	_gs.scene_changer = _fake_changer
	root.add_child(_gs)

	_new_floor()

	_shop = ShopPoint.new()
	_shop.weapon_id = "auto"
	_shop.position = Vector3(0.0, 0.0, -3.0)
	root.add_child(_shop)

	_door = DoorPoint.new()
	_door.location_id = "arena_01"
	_door.position = Vector3(0.0, 0.0, -6.0)
	root.add_child(_door)

	var packed: PackedScene = load(_PLAYER_SCENE)
	if packed == null:
		print("КРИТИЧЕСКАЯ ОШИБКА: не удалось загрузить %s" % _PLAYER_SCENE)
		_finish()
		quit(1)
		return
	_player = packed.instantiate() as CharacterBody3D
	if _player == null:
		print("КРИТИЧЕСКАЯ ОШИБКА: %s не является CharacterBody3D" % _PLAYER_SCENE)
		_finish()
		quit(1)
		return
	_player.set_script(_PlayerProbe)
	_player.position = Vector3(0.0, 0.0, 0.0)
	root.add_child(_player)

	_shop_log = _ShopLog.new()
	_shop.interacted.connect(_shop_log._on_interacted)

	# Ожидание готовности узлов (_ready, вступление в группы, коллизии).
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
# проверки
# --------------------------------------------------------------------------

## Проверка контрактов классов, экспортов, сигналов, слоев коллизий и групп.
func _test_contracts() -> void:
	print("-- contracts: классы, экспорты, сигналы, слои коллизий и группы")
	var shop_script := load(_SHOP_SCRIPT) as Script
	_check(shop_script != null, "shop_point.gd загружается")
	if shop_script == null:
		return
	_check(shop_script.get_global_name() == "ShopPoint",
		"shop_point.gd объявляет class_name ShopPoint",
		"(получено \"%s\")" % shop_script.get_global_name())
	_check(shop_script.get_instance_base_type() == "Area3D",
		"ShopPoint наследует Area3D", "(получено %s)" % shop_script.get_instance_base_type())
	_check(_shop.has_method("interact"), "ShopPoint предоставляет метод interact()")
	_check(_shop.has_signal("interacted"), "ShopPoint предоставляет сигнал interacted")
	_check(_property_type(_shop, "weapon_id") == TYPE_STRING,
		"weapon_id является String экспортом", "(получен тип %s)" % str(_property_type(_shop, "weapon_id")))
	_check(int(_shop.collision_layer) == 1 << 5,
		"ShopPoint находится на слое 6 (interactable)", "(получено %d)" % int(_shop.collision_layer))
	_check(int(_shop.collision_mask) == 1 << 1,
		"маска коллизий ShopPoint включает слой игрока", "(получено %d)" % int(_shop.collision_mask))
	_check(_shop.monitoring, "ShopPoint отслеживает пересечения (monitoring = true)")
	_check(_shop.is_in_group("interactable"), "ShopPoint состоит в группе interactable")

	var door_script := load(_DOOR_SCRIPT) as Script
	_check(door_script != null, "door_point.gd загружается")
	if door_script == null:
		return
	_check(door_script.get_global_name() == "DoorPoint",
		"door_point.gd объявляет class_name DoorPoint",
		"(получено \"%s\")" % door_script.get_global_name())
	_check(door_script.get_instance_base_type() == "Area3D",
		"DoorPoint наследует Area3D", "(получено %s)" % door_script.get_instance_base_type())
	_check(_door.has_method("interact"), "DoorPoint предоставляет метод interact()")
	_check(_property_type(_door, "location_id") == TYPE_STRING,
		"location_id является String экспортом", "(получен тип %s)" % str(_property_type(_door, "location_id")))
	_check(int(_door.collision_layer) == 1 << 5,
		"DoorPoint находится на слое 6 (interactable)", "(получено %d)" % int(_door.collision_layer))
	_check(int(_door.collision_mask) == 1 << 1,
		"маска коллизий DoorPoint включает слой игрока", "(получено %d)" % int(_door.collision_mask))
	_check(_door.monitoring, "DoorPoint отслеживает пересечения (monitoring = true)")
	_check(_door.is_in_group("interactable"), "DoorPoint состоит в группе interactable")


func _test_shop_purchase() -> void:
	print("-- shop: открытие модального окна магазина и покупка оружия")
	_check(_gs.points == 0, "предусловие: у игрока изначально 0 очков",
		"(получено %d)" % _gs.points)
	var opened := _shop.interact(_player)
	_check(opened, "магазин открывает модальное окно при взаимодействии")
	var shop_modal: Control = _player.get_node_or_null("UI/ShopModal") as Control
	_check(shop_modal != null and shop_modal.visible, "ShopModal открыто на экране игрока")
	_check(_packed_eq(_gs.owned_weapons, ["pistol"]),
		"и не выдает оружие без покупки", "(получено %s)" % _gs.owned_weapons)
	_check(_gs.points == 0, "баланс очков не изменяется", "(получено %d)" % _gs.points)
	_check(_shop_log.ok_values.size() == 1 and _shop_log.ok_values[0] == true,
		"сигнал interacted сообщил об успешном открытии магазина (true)",
		"(получено %s)" % str(_shop_log.ok_values))

	_gs.award_points(_AUTO_PRICE)
	if shop_modal != null:
		shop_modal.refresh()
		shop_modal.call("_on_card_action", "auto", _AUTO_PRICE)
	_check("auto" in _gs.owned_weapons, "автомат теперь в наличии", "(получено %s)" % _gs.owned_weapons)
	_check(_gs.equipped_weapon_id == "auto", "и автомат экипирован",
		"(получено \"%s\")" % _gs.equipped_weapon_id)
	_check(_gs.points == 0, "стоимость покупки списана", "(получено %d)" % _gs.points)
	if shop_modal != null:
		shop_modal.close()


func _test_door_transition() -> void:
	print("-- door: переход на арену 01 через смену сцены")
	var entered := _door.interact(_player)
	_check(entered, "дверь открывает разблокированную арену 01")
	_check(_changed_to.size() > 0 and _changed_to[_changed_to.size() - 1] == "res://levels/arena_01/arena_01.tscn",
		"обработчик запросил сцену res://levels/arena_01/arena_01.tscn", "(получено %s)" % _changed_to)


## Проверка радиуса взаимодействия: магазин на 3.0 м доступен (радиус 3.5 м),
## дверь на 6.0 м недоступна.
func _test_nearest_interactable() -> void:
	print("-- reach: ближайший объект в радиусе %.1f м, ничего за его пределами" % _EXPECTED_RANGE)
	_player.global_position = Vector3(0.0, 0.0, 0.0)
	var nearest: Node = _player.call("nearest_interactable")
	_check(nearest == _shop,
		"магазин на 3.0 м обнаружен (радиус 3.5 м)",
		"(получено %s)" % ("null" if nearest == null else nearest.name))

	_shop.position = Vector3(0.0, 0.0, -10.0)
	nearest = _player.call("nearest_interactable")
	_check(nearest == null,
		"когда магазин на 10 м, а дверь на 6 м — в зоне досягаемости ничего нет",
		"(получено %s)" % ("null" if nearest == null else nearest.name))
	# Возвращаем магазин обратно для проверки гейта ввода.
	_shop.position = Vector3(0.0, 0.0, -3.0)


## Взаимодействие является игровым вводом: оно блокируется при свободном курсоре
## и разрешено только при захваченном курсоре мыши.
func _test_input_gate() -> void:
	print("-- input gate: взаимодействие блокируется при свободном курсоре")
	_player.global_position = Vector3(0.0, 0.0, 0.0)
	var before := _shop_log.ok_values.size()
	var shop_modal: Control = _player.get_node_or_null("UI/ShopModal") as Control

	_player.set("gate_mouse_mode", Input.MOUSE_MODE_VISIBLE)
	Input.parse_input_event(_interact_key_event(true))
	Input.flush_buffered_events()
	await physics_frame
	_check(_shop_log.ok_values.size() == before,
		"нажатие при свободном курсоре не достигает магазина и не вызывает сигнал",
		"(получено сигналов: %d)" % (_shop_log.ok_values.size() - before))
	if shop_modal != null:
		_check(not shop_modal.visible, "модальное окно магазина не открывается при свободном курсоре")
	_check(_gs.points == 0, "очки не тратятся",
		"(получено %d)" % _gs.points)
	_check(_gs.equipped_weapon_id == "auto",
		"экипированное оружие не изменяется", "(получено \"%s\")" % _gs.equipped_weapon_id)

	# Отпускаем и снова нажимаем при захваченном курсоре.
	_player.set("gate_mouse_mode", Input.MOUSE_MODE_CAPTURED)
	Input.parse_input_event(_interact_key_event(false))
	Input.flush_buffered_events()
	await physics_frame
	Input.parse_input_event(_interact_key_event(true))
	Input.flush_buffered_events()
	await physics_frame
	_check(_shop_log.ok_values.size() == before + 1,
		"то же нажатие достигает магазина при захваченном курсоре",
		"(получено сигналов: %d)" % (_shop_log.ok_values.size() - before))
	if shop_modal != null:
		_check(shop_modal.visible, "модальное окно магазина успешно открыто при захваченном курсоре")
		shop_modal.close()

	_check(_gs.equipped_weapon_id == "auto",
		"автомат остается экипирован",
		"(получено \"%s\")" % _gs.equipped_weapon_id)
	_check(_gs.points == 0, "баланс очков сохранен",
		"(получено %d)" % _gs.points)
