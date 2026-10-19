extends SceneTree

## Проверка инвентаря для VibeFPS (Фаза 3, Задача 10): панель инвентаря на игроке
## (физическая клавиша I, кнопки + мышь) и смена экипированного оружия.
##
## Две части задачи: нажатие кнопки в UI запрашивает у GameState смену оружия,
## а узел игрока фактически заменяет оружие в руке.
## Запуск: godot --headless --path . --script res://tests/inventory.gd
##         .\tools\run_checks.ps1 inventory

const _UI_SCENE := "res://ui/ui.tscn"
const _PLAYER_SCENE := "res://entities/player/player.tscn"

var _failures: PackedStringArray = []
var _checks := 0


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


## Удаляет автозагрузки GameState/SaveSystem из /root перед тестом,
## чтобы изолировать прогон от автосохранений на диск.
func _drop_autoloads() -> void:
	for autoload_name in ["GameState", "SaveSystem"]:
		var node := root.get_node_or_null(autoload_name)
		if node != null:
			root.remove_child(node)
			node.free()


## Создаёт изолированный экземпляр GameState в /root.
func _make_game_state() -> GameState:
	var gs := GameState.new()
	gs.name = "GameState"
	root.add_child(gs)
	return gs


## Событие нажатия физической клавиши I для вызова инвентаря.
func _inventory_key_event(pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_I
	ev.keycode = KEY_I
	ev.pressed = pressed
	return ev


## Находит кнопку, чей текст начинается с prefix.
func _button_with(list: Node, prefix: String) -> Button:
	for child in list.get_children():
		if child is Button and (child as Button).text.begins_with(prefix):
			return child
	return null


func _texts(list: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for child in list.get_children():
		if child is Button:
			out.append((child as Button).text)
	return out


## Возвращает display_name текущего оружия игрока.
func _held_name(weapon: Node) -> String:
	if weapon == null:
		return "<none>"
	var data := weapon.get("data") as Resource
	if data == null:
		return "<no data>"
	return str(data.get("display_name"))


func _initialize() -> void:
	print("=== Проверка инвентаря (Inventory) ===")
	_drop_autoloads()
	await _test_panel_buttons()
	await _test_selection_equips_and_closes()
	await _test_toggle_action()
	await _test_null_safety()
	await _test_weapon_swap()

	print("=== РЕЗУЛЬТАТ: %d проверок, %d провалено ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  ОШИБКА: %s" % f)
	quit(1 if _failures.size() > 0 else 0)


## По одной кнопке на каждое купленное оружие; экипированное помечено галочкой.
func _test_panel_buttons() -> void:
	print("-- кнопки: по одной на каждое оружие в собственности, с меткой экипированного")
	var gs := _make_game_state()
	await physics_frame
	gs.owned_weapons = PackedStringArray(["pistol", "auto", "ghost"])
	gs.equipped_weapon_id = "pistol"

	var ui := (load(_UI_SCENE) as PackedScene).instantiate()
	root.add_child(ui)
	await physics_frame

	var panel := ui.get_node_or_null("InventoryPanel")
	_check(panel != null, "ui.tscn содержит узел InventoryPanel")
	if panel == null:
		ui.queue_free()
		gs.queue_free()
		await physics_frame
		return
	_check(panel.has_method("open") and panel.has_method("close"),
		"InventoryPanel реализует методы open() и close() скрипта inventory.gd")
	panel.call("bind", gs)
	panel.call("open")

	var list := panel.get_node_or_null("List")
	_check(list != null, "панель содержит контейнер List")
	if list != null:
		_check(list.get_child_count() == 3, "ровно по одной кнопке на каждое доступное оружие",
			"(получено %d)" % list.get_child_count())
		var texts := _texts(list)
		_check(_button_with(list, "Pistol") != null, "кнопка пистолета использует WeaponData.display_name",
			"(получено %s)" % texts)
		_check("Auto" in texts, "кнопка автомата использует WeaponData.display_name",
			"(получено %s)" % texts)
		_check("ghost" in texts, "оружие без .tres использует fallback на свой id",
			"(получено %s)" % texts)
		var pistol_button := _button_with(list, "Pistol")
		_check(pistol_button != null and "✓" in pistol_button.text,
			"экипированное оружие помечено галочкой ✓",
			"(получено %s)" % (pistol_button.text if pistol_button != null else "<отсутствует>"))
		var auto_button := _button_with(list, "Auto")
		_check(auto_button != null and not ("✓" in auto_button.text),
			"купленное, но не экипированное оружие не имеет отметки",
			"(получено %s)" % (auto_button.text if auto_button != null else "<отсутствует>"))

	ui.queue_free()
	gs.queue_free()
	await physics_frame


## A click equips through GameState and closes the panel.
func _test_selection_equips_and_closes() -> void:
	print("-- selection: a click equips and closes")
	var gs := _make_game_state()
	await physics_frame
	gs.owned_weapons = PackedStringArray(["pistol", "auto"])
	gs.equipped_weapon_id = "pistol"

	var ui := (load(_UI_SCENE) as PackedScene).instantiate()
	root.add_child(ui)
	await physics_frame
	var panel := ui.get_node_or_null("InventoryPanel")
	var list := panel.get_node_or_null("List")
	panel.call("bind", gs)
	panel.call("open")
	_check(bool(panel.call("is_open")), "панель открыта перед кликом")

	var auto_button := _button_with(list, "Auto")
	_check(auto_button != null, "кнопка автомата существует")
	if auto_button != null:
		auto_button.pressed.emit()
	_check(gs.equipped_weapon_id == "auto",
		"клик экипирует оружие через GameState",
		"(получено %s)" % gs.equipped_weapon_id)
	_check(not bool(panel.call("is_open")) and not panel.visible,
		"после выбора панель автоматически закрывается")

	ui.queue_free()
	gs.queue_free()
	await physics_frame


## Нажатие I переключает панель: первое нажатие открывает, повторное закрывает.
## Обрабатывается в _unhandled_input без гейта InputGate (работает при любом режиме мыши).
func _test_toggle_action() -> void:
	print("-- ввод: нажатие клавиши I переключает видимость панели")
	var gs := _make_game_state()
	await physics_frame
	gs.owned_weapons = PackedStringArray(["pistol"])
	gs.equipped_weapon_id = "pistol"

	var ui := (load(_UI_SCENE) as PackedScene).instantiate()
	root.add_child(ui)
	await physics_frame
	var panel := ui.get_node_or_null("InventoryPanel")
	panel.call("bind", gs)
	_check(not bool(panel.call("is_open")) and not panel.visible,
		"панель изначально скрыта")

	Input.parse_input_event(_inventory_key_event(true))
	Input.flush_buffered_events()
	await physics_frame
	_check(bool(panel.call("is_open")) and panel.visible,
		"нажатие I открывает панель")

	Input.parse_input_event(_inventory_key_event(false))
	Input.flush_buffered_events()
	await physics_frame
	Input.parse_input_event(_inventory_key_event(true))
	Input.flush_buffered_events()
	await physics_frame
	_check(not panel.call("is_open") and not panel.visible,
		"повторное нажатие I закрывает панель")

	ui.queue_free()
	gs.queue_free()
	await physics_frame


## Без GameState: панель открывается пустой, игрок сохраняет дефолтный пистолет.
func _test_null_safety() -> void:
	print("-- безопасность без GameState (null safety)")
	root.get_node_or_null("GameState")

	var ui := (load(_UI_SCENE) as PackedScene).instantiate()
	root.add_child(ui)
	await physics_frame
	var panel := ui.get_node_or_null("InventoryPanel")
	_check(panel != null, "панель существует без GameState")
	panel.call("bind", null)
	panel.call("open")
	_check(panel.call("is_open"), "панель открывается без GameState")
	var list := panel.get_node_or_null("List")
	_check(list != null and list.get_child_count() == 0,
		"и не показывает ни одной кнопки",
		"(получено %d)" % (list.get_child_count() if list != null else -1))
	panel.call("close")

	var player := (load(_PLAYER_SCENE) as PackedScene).instantiate()
	root.add_child(player)
	await physics_frame
	var weapon: Node = player.call("current_weapon")
	_check(weapon != null, "игрок держит оружие в руках даже при отсутствии GameState")
	_check(_held_name(weapon) == "Pistol",
		"и это дефолтный пистолет из сцены",
		"(получено %s)" % _held_name(weapon))

	player.queue_free()
	ui.queue_free()
	await physics_frame


## Игрок держит в руках ровно то оружие, которое выбрано в GameState,
## в том же слоте руки, и переключается обратно по запросу.
func _test_weapon_swap() -> void:
	print("-- смена оружия: игрок держит экипированное оружие")
	var gs := _make_game_state()
	await physics_frame
	gs.owned_weapons = PackedStringArray(["pistol", "auto"])
	gs.equipped_weapon_id = "pistol"

	var player := (load(_PLAYER_SCENE) as PackedScene).instantiate()
	root.add_child(player)
	await physics_frame

	var start: Node = player.call("current_weapon")
	_check(start != null, "игрок держит оружие при появлении")
	_check(_held_name(start) == "Pistol", "в руках пистолет, когда экипирован pistol",
		"(получено %s)" % _held_name(start))
	_check(start != null and start.scene_file_path == "res://weapons/pistol/pistol.tscn",
		"и это сцена pistol.tscn",
		"(получено %s)" % ("<none>" if start == null else start.scene_file_path))
	var hand_position := (start as Node3D).position if start is Node3D else Vector3.ZERO

	gs.equip_weapon("auto")
	await physics_frame
	var swapped: Node = player.call("current_weapon")
	_check(swapped != null, "после экипировки auto в руках есть оружие")
	_check(swapped != start, "узел в слоте заменён на новый экземпляр")
	_check(_held_name(swapped) == "Auto", "в руках теперь данные автомата",
		"(получено %s)" % _held_name(swapped))
	_check(swapped != null and swapped.scene_file_path == "res://weapons/auto/auto.tscn",
		"слот занимает сцена auto.tscn",
		"(получено %s)" % ("<none>" if swapped == null else swapped.scene_file_path))
	_check(swapped != null and swapped.name == "Pistol",
		"новое оружие сохраняет имя слота Pistol для обратной совместимости")
	if swapped is Node3D:
		_check((swapped as Node3D).position.is_equal_approx(hand_position),
			"позиция в руке сохранена после смены",
			"(получено %s, ожидалось %s)" % [(swapped as Node3D).position, hand_position])

	gs.equip_weapon("pistol")
	await physics_frame
	var back: Node = player.call("current_weapon")
	_check(_held_name(back) == "Pistol", "повторный выбор pistol возвращает пистолет в руки",
		"(получено %s)" % _held_name(back))

	player.queue_free()
	gs.queue_free()
	await physics_frame
