extends SceneTree

## Автономный модульный тест модального окна магазина оружия (ShopModal — R4).
## Проверяет структуру, CAD-проекции, группу modal_ui, отображение характеристик,
## динамику состояний кнопок, покупку/экипировку и все способы закрытия (Esc, E, кнопка).
## Запуск: godot --headless --path . --script res://tests/shop_modal.gd
##         pwsh -File .\tools\run_checks.ps1 shop_modal

const _SHOP_SCRIPT := "res://ui/shop_modal.gd"

var _failures: PackedStringArray = []
var _checks: int = 0


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


func _key_event(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = true
	return ev


func _initialize() -> void:
	print("=== Проверка модального окна магазина оружия (ShopModal — R4) ===")

	var shop_script := load(_SHOP_SCRIPT) as GDScript
	_check(shop_script != null, "res://ui/shop_modal.gd загружается")
	if shop_script == null:
		quit(1)
		return

	var shop := shop_script.new() as Control
	root.add_child(shop)

	_test_structure_and_group(shop)
	_test_card_specs_and_cad(shop)
	_test_open_close_mouse_modes(shop)
	_test_button_states_and_transactions(shop)
	_test_close_triggers(shop)

	shop.queue_free()

	print("=== РЕЗУЛЬТАТ: %d проверок, %d провалено ===" % [_checks, _failures.size()])
	if _failures.size() > 0:
		for f in _failures:
			print("  ОШИБКА: %s" % f)
		quit(1)
	else:
		quit(0)


## 1. Проверка структуры, дочерних узлов и группы modal_ui
func _test_structure_and_group(shop: Control) -> void:
	print("-- структура и группа modal_ui")
	_check(shop.is_in_group("modal_ui"), "ShopModal состоит в группе modal_ui")
	_check(not shop.visible, "ShopModal изначально скрыт (visible = false)")

	var cards_container: Node = shop.find_child("CardsContainer", true, false)
	_check(cards_container != null, "CardsContainer присутствует в дереве узлов")
	if cards_container != null:
		_check(cards_container.get_child_count() == 3, "CardsContainer содержит ровно 3 карточки оружия",
			"(найдено %d)" % cards_container.get_child_count())

	var points_display: Node = shop.find_child("PointsDisplay", true, false)
	_check(points_display is Label, "PointsDisplay присутствует и является Label")

	var close_btn: Node = shop.find_child("CloseButton", true, false)
	_check(close_btn is Button, "CloseButton присутствует и является Button")


## 2. Проверка отображения характеристик и наличия CAD-проекций
func _test_card_specs_and_cad(shop: Control) -> void:
	print("-- характеристики оружия и 2D CAD проекции")
	var cards_container: Node = shop.find_child("CardsContainer", true, false)
	if cards_container == null:
		_check(false, "CardsContainer отсутствует для проверки характеристик")
		return

	var expected_weapons := ["pistol", "auto", "shotgun"]
	for i in range(cards_container.get_child_count()):
		var card: Node = cards_container.get_child(i)
		var cad_view: Node = card.find_child("WeaponCadView", true, false)
		_check(cad_view is WeaponCadView, "Карточка %d содержит WeaponCadView" % i)
		if cad_view is WeaponCadView:
			var w_id: String = cad_view.weapon_id
			_check(w_id == expected_weapons[i], "Карточка %d имеет weapon_id '%s'" % [i, expected_weapons[i]],
				"(получено '%s')" % w_id)

		var title_node: Node = card.find_child("Title", true, false)
		_check(title_node is Label and not (title_node as Label).text.is_empty(),
			"Карточка %d содержит непустое название" % i)

		var specs_node: Node = card.find_child("Specs", true, false)
		_check(specs_node != null, "Карточка %d содержит блок характеристик Specs" % i)
		if specs_node != null:
			var dmg: Node = specs_node.find_child("DamageLabel", true, false)
			var rpm: Node = specs_node.find_child("RpmLabel", true, false)
			var mag: Node = specs_node.find_child("MagLabel", true, false)
			var rld: Node = specs_node.find_child("ReloadLabel", true, false)
			_check(dmg != null and rpm != null and mag != null and rld != null,
				"Карточка %d содержит все 4 характеристики (Урон, Темп, Обойма, Перезарядка)" % i)


## 3. Открытие/закрытие и переключение режимов мыши
func _test_open_close_mouse_modes(shop: Control) -> void:
	print("-- открытие/закрытие и переключение режимов курсора мыши")
	shop.close()
	_check(not shop.visible and not shop.is_open(), "Метод is_open() возвращает false при закрытом окне")
	var is_headless: bool = (DisplayServer.get_name() == "headless")
	var mode_captured: bool = (int(shop.get("last_mouse_mode_set")) == Input.MOUSE_MODE_CAPTURED) if is_headless else (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	_check(mode_captured, "При close() курсор переведен в MOUSE_MODE_CAPTURED")

	shop.open()
	_check(shop.visible and shop.is_open(), "Метод open() отображает окно и is_open() == true")
	var mode_visible: bool = (int(shop.get("last_mouse_mode_set")) == Input.MOUSE_MODE_VISIBLE) if is_headless else (Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	_check(mode_visible, "При open() курсор переведен в MOUSE_MODE_VISIBLE")

	shop.close()
	_check(not shop.visible, "Метод close() скрывает окно")
	var mode_recaptured: bool = (int(shop.get("last_mouse_mode_set")) == Input.MOUSE_MODE_CAPTURED) if is_headless else (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	_check(mode_recaptured, "Курсор снова захвачен после close()")


## 4. Состояния кнопок и транзакции покупки/экипировки
func _test_button_states_and_transactions(shop: Control) -> void:
	print("-- динамика кнопок и транзакции покупки/экипировки")
	# Создаем изолированный экземпляр GameState для тестирования
	var gs := GameState.new()
	gs.points = 0
	gs.owned_weapons = ["pistol"]
	gs.equipped_weapon_id = "pistol"
	shop.bind(gs)

	var cards: Node = shop.find_child("CardsContainer", true, false)
	var btn_pistol: Button = cards.get_child(0).find_child("ActionButton", true, false) as Button
	var btn_auto: Button = cards.get_child(1).find_child("ActionButton", true, false) as Button
	var btn_shotgun: Button = cards.get_child(2).find_child("ActionButton", true, false) as Button

	# Исходное состояние: пистолет в руках, автомат и дробовик не куплены и заблокированы (0 очков)
	_check(btn_pistol.text == "В руках" and btn_pistol.disabled,
		"Пистолет экипирован по умолчанию: кнопка 'В руках' (disabled)")
	_check(btn_auto.text.contains("300") and btn_auto.disabled,
		"Автомат за 300 очков недоступен при 0 очков: кнопка disabled")
	_check(btn_shotgun.text.contains("600") and btn_shotgun.disabled,
		"Дробовик за 600 очков недоступен при 0 очков: кнопка disabled")

	# Начисляем 300 очков -> автомат становится доступным для покупки
	gs.points = 300
	shop.refresh()
	_check(not btn_auto.disabled, "При 300 очках кнопка покупки автомата активна (disabled = false)")
	_check(btn_shotgun.disabled, "При 300 очках покупка дробовика за 600 очков по-прежнему заблокирована")

	# Покупка автомата
	btn_auto.emit_signal("pressed")
	_check(gs.points == 0, "После покупки автомата 300 очков списаны (осталось 0)",
		"(баланс: %d)" % gs.points)
	_check("auto" in gs.owned_weapons, "Автомат добавлен в owned_weapons")
	_check(gs.equipped_weapon_id == "auto", "Автомат автоматически экипирован")
	_check(btn_auto.text == "В руках" and btn_auto.disabled,
		"Кнопка автомата переключена в 'В руках' (disabled)")
	_check(btn_pistol.text == "Экипировать" and not btn_pistol.disabled,
		"Кнопка пистолета переключена в 'Экипировать' (enabled)")

	# Экипировка пистолета обратно
	btn_pistol.emit_signal("pressed")
	_check(gs.equipped_weapon_id == "pistol", "Пистолет снова экипирован")
	_check(btn_pistol.text == "В руках" and btn_pistol.disabled,
		"Кнопка пистолета снова 'В руках'")
	_check(btn_auto.text == "Экипировать" and not btn_auto.disabled,
		"Кнопка купленного автомата теперь 'Экипировать'")

	# Начисляем 600 очков и покупаем дробовик
	gs.points = 600
	shop.refresh()
	_check(not btn_shotgun.disabled, "При 600 очках кнопка покупки дробовика активна")
	btn_shotgun.emit_signal("pressed")
	_check(gs.points == 0, "После покупки дробовика 600 очков списаны")
	_check("shotgun" in gs.owned_weapons, "Дробовик добавлен в owned_weapons")
	_check(gs.equipped_weapon_id == "shotgun", "Дробовик экипирован")
	_check(btn_shotgun.text == "В руках" and btn_shotgun.disabled,
		"Кнопка дробовика переключена в 'В руках'")

	gs.free()


## 5. Проверка всех триггеров закрытия: кнопка CloseButton, Escape, E
func _test_close_triggers(shop: Control) -> void:
	print("-- триггеры закрытия окна (CloseButton, Esc, E)")
	var close_btn: Button = shop.find_child("CloseButton", true, false) as Button

	# 1. Закрытие кликом по кнопке CloseButton
	shop.open()
	_check(shop.visible, "Окно открыто перед тестом CloseButton")
	close_btn.emit_signal("pressed")
	_check(not shop.visible, "CloseButton закрывает модальное окно")

	# 2. Закрытие клавишей Escape
	shop.open()
	_check(shop.visible, "Окно открыто перед тестом Escape")
	shop._unhandled_input(_key_event(KEY_ESCAPE))
	_check(not shop.visible, "Клавиша Escape закрывает модальное окно")

	# 3. Закрытие клавишей E
	shop.open()
	_check(shop.visible, "Окно открыто перед тестом E")
	shop._unhandled_input(_key_event(KEY_E))
	_check(not shop.visible, "Клавиша E закрывает модальное окно")
