class_name ShopModal
extends Control

## Интерактивное модальное окно магазина оружия (R4) в архитектурном стиле VibeFPS.
## Содержит 3 карточки оружия (Пистолет, АК-47, Дробовик) с 2D CAD-проекциями,
## характеристиками и кнопками покупки/экипировки.

signal closed()
signal opened()

const WEAPONS_DATA := [
	{
		"id": "pistol",
		"name": "ПИСТОЛЕТ",
		"price": 0,
		"damage": "30",
		"rpm": "150",
		"mag": "18",
		"reload": "1.2 с",
	},
	{
		"id": "auto",
		"name": "АВТОМАТ АК-47",
		"price": 300,
		"damage": "15",
		"rpm": "300",
		"mag": "36",
		"reload": "1.6 с",
	},
	{
		"id": "shotgun",
		"name": "ДРОБОВИК (ДВУСТВОЛКА)",
		"price": 600,
		"damage": "120 (10×12)",
		"rpm": "120",
		"mag": "2",
		"reload": "1.1 с",
	}
]

var _game_state: Node = null
var last_mouse_mode_set: int = -1

var _points_display: Label = null
var _close_button: Button = null
var _cards_container: HBoxContainer = null
var _action_buttons: Dictionary = {}


func _init() -> void:
	# Инициализация базовых свойств до входа в дерево
	anchors_preset = PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	visible = false
	add_to_group("modal_ui")
	_build_ui_if_needed()


func _ready() -> void:
	add_to_group("modal_ui")
	_build_ui_if_needed()
	_connect_game_state()
	refresh()


func _exit_tree() -> void:
	_disconnect_game_state()
	if visible:
		close()


## Построение интерфейса модального окна, если узлы ещё не созданы
func _build_ui_if_needed() -> void:
	if _cards_container != null:
		return

	# Затемняющий фон
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.anchors_preset = PRESET_FULL_RECT
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	add_child(bg)

	# Центральный диалоговый контейнер
	var center := CenterContainer.new()
	center.name = "Center"
	center.anchors_preset = PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "DialogPanel"
	panel.custom_minimum_size = Vector2(920, 520)

	# Стиль панели в техническом чертёжном CAD стиле
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.06, 0.96)
	style.border_color = Color(1.0, 1.0, 1.0, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.add_theme_constant_override("separation", 20)
	panel.add_child(main_vbox)

	# Заголовок (Header)
	var header := HBoxContainer.new()
	header.name = "Header"
	main_vbox.add_child(header)

	var title := Label.new()
	title.name = "Title"
	title.text = "МАГАЗИН ОРУЖИЯ"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(spacer)

	_points_display = Label.new()
	_points_display.name = "PointsDisplay"
	_points_display.text = "ОЧКИ: 0"
	_points_display.add_theme_font_size_override("font_size", 22)
	_points_display.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1.0))
	header.add_child(_points_display)

	var close_spacer := Control.new()
	close_spacer.custom_minimum_size = Vector2(24, 0)
	header.add_child(close_spacer)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "✕"
	_close_button.custom_minimum_size = Vector2(36, 36)
	_close_button.pressed.connect(close)
	header.add_child(_close_button)

	# Контейнер карточек (CardsContainer)
	_cards_container = HBoxContainer.new()
	_cards_container.name = "CardsContainer"
	_cards_container.size_flags_vertical = SIZE_EXPAND_FILL
	_cards_container.add_theme_constant_override("separation", 16)
	main_vbox.add_child(_cards_container)

	# Построение 3 карточек
	for item in WEAPONS_DATA:
		var card := _create_weapon_card(item)
		_cards_container.add_child(card)


## Создание карточки оружия
func _create_weapon_card(data: Dictionary) -> Control:
	var w_id: String = data["id"]
	var w_name: String = data["name"]
	var w_price: int = data["price"]

	var card_panel := PanelContainer.new()
	card_panel.name = "Card_" + w_id
	card_panel.set_meta("weapon_id", w_id)
	card_panel.custom_minimum_size = Vector2(270, 400)
	card_panel.size_flags_horizontal = SIZE_EXPAND_FILL

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	card_style.border_color = Color(0.8, 0.8, 0.8, 0.4)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(4)
	card_style.set_content_margin_all(14)
	card_panel.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	card_panel.add_child(vbox)

	# Название оружия
	var title_lbl := Label.new()
	title_lbl.name = "Title"
	title_lbl.text = w_name
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	vbox.add_child(title_lbl)

	# 2D CAD проекция
	var cad_view := WeaponCadView.new()
	cad_view.name = "WeaponCadView"
	cad_view.weapon_id = w_id
	cad_view.custom_minimum_size = Vector2(240, 150)
	vbox.add_child(cad_view)

	# Характеристики
	var specs_vbox := VBoxContainer.new()
	specs_vbox.name = "Specs"
	specs_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(specs_vbox)

	var damage_lbl := Label.new()
	damage_lbl.name = "DamageLabel"
	damage_lbl.text = "Урон: %s" % data["damage"]
	damage_lbl.add_theme_font_size_override("font_size", 14)
	damage_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))
	specs_vbox.add_child(damage_lbl)

	var rpm_lbl := Label.new()
	rpm_lbl.name = "RpmLabel"
	rpm_lbl.text = "Темп: %s выстр/мин" % data["rpm"]
	rpm_lbl.add_theme_font_size_override("font_size", 14)
	rpm_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))
	specs_vbox.add_child(rpm_lbl)

	var mag_lbl := Label.new()
	mag_lbl.name = "MagLabel"
	mag_lbl.text = "Обойма: %s" % data["mag"]
	mag_lbl.add_theme_font_size_override("font_size", 14)
	mag_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))
	specs_vbox.add_child(mag_lbl)

	var reload_lbl := Label.new()
	reload_lbl.name = "ReloadLabel"
	reload_lbl.text = "Перезарядка: %s" % data["reload"]
	reload_lbl.add_theme_font_size_override("font_size", 14)
	reload_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))
	specs_vbox.add_child(reload_lbl)

	var card_spacer := Control.new()
	card_spacer.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(card_spacer)

	# Кнопка действия (ActionButton)
	var btn := Button.new()
	btn.name = "ActionButton"
	btn.custom_minimum_size = Vector2(0, 42)
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(_on_card_action.bind(w_id, w_price))
	vbox.add_child(btn)

	_action_buttons[w_id] = btn
	return card_panel


## Открыть модальное окно: освободить курсор, обновить карточки
func open() -> void:
	_build_ui_if_needed()
	visible = true
	last_mouse_mode_set = Input.MOUSE_MODE_VISIBLE
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	refresh()
	opened.emit()


## Закрыть модальное окно: скрыть, захватить курсор
func close() -> void:
	visible = false
	last_mouse_mode_set = Input.MOUSE_MODE_CAPTURED
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	closed.emit()


func is_open() -> bool:
	return visible


## Ручное связывание с GameState (для изолированного тестирования)
func bind(game_state: Node) -> void:
	_disconnect_game_state()
	_game_state = game_state
	_connect_game_state()
	refresh()


func _find_game_state() -> Node:
	if _game_state != null and is_instance_valid(_game_state):
		return _game_state
	if is_inside_tree():
		return get_node_or_null("/root/GameState")
	var main_loop := Engine.get_main_loop() as SceneTree
	if main_loop != null and main_loop.root != null:
		return main_loop.root.get_node_or_null("GameState")
	return null


func _connect_game_state() -> void:
	var gs := _find_game_state()
	if is_instance_valid(gs):
		if gs.has_signal("points_changed") and not gs.points_changed.is_connected(_on_points_changed):
			gs.points_changed.connect(_on_points_changed)
		if gs.has_signal("equipped_changed") and not gs.equipped_changed.is_connected(_on_equipped_changed):
			gs.equipped_changed.connect(_on_equipped_changed)


func _disconnect_game_state() -> void:
	var gs := _find_game_state()
	if is_instance_valid(gs):
		if gs.has_signal("points_changed") and gs.points_changed.is_connected(_on_points_changed):
			gs.points_changed.disconnect(_on_points_changed)
		if gs.has_signal("equipped_changed") and gs.equipped_changed.is_connected(_on_equipped_changed):
			gs.equipped_changed.disconnect(_on_equipped_changed)


func _on_points_changed(_pts: int) -> void:
	if visible:
		refresh()


func _on_equipped_changed(_weapon_id: String) -> void:
	if visible:
		refresh()


## Обновление баланса очков и состояний всех кнопок карточек
func refresh() -> void:
	_build_ui_if_needed()

	var gs := _find_game_state()
	var current_points: int = 0
	var equipped: String = "pistol"
	var owned: Array = ["pistol"]

	if gs != null:
		if gs.get("points") != null:
			current_points = int(gs.get("points"))
		if gs.get("equipped_weapon_id") != null:
			equipped = str(gs.get("equipped_weapon_id"))
		elif gs.get("equipped_weapon") != null:
			equipped = str(gs.get("equipped_weapon"))

		var owned_val: Variant = gs.get("owned_weapons")
		if owned_val == null:
			owned_val = gs.get("unlocked_weapons")
		if owned_val is PackedStringArray or owned_val is Array:
			owned = Array(owned_val)

	if _points_display != null:
		_points_display.text = "ОЧКИ: %d" % current_points

	for item in WEAPONS_DATA:
		var w_id: String = item["id"]
		var w_price: int = item["price"]
		var btn: Button = _action_buttons.get(w_id) as Button
		if btn == null:
			continue

		if w_id == equipped:
			btn.text = "В руках"
			btn.disabled = true
		elif w_id in owned:
			btn.text = "Экипировать"
			btn.disabled = false
		else:
			btn.text = "Купить за %d очков" % w_price
			btn.disabled = (current_points < w_price)


## Обработка клика по кнопке действия карточки
func _on_card_action(id: String, price: int) -> void:
	var gs := _find_game_state()
	if gs == null:
		return

	var owned: Array = ["pistol"]
	var owned_val: Variant = gs.get("owned_weapons")
	if owned_val == null:
		owned_val = gs.get("unlocked_weapons")
	if owned_val is PackedStringArray or owned_val is Array:
		owned = Array(owned_val)

	if id in owned:
		if gs.has_method("equip_weapon"):
			gs.call("equip_weapon", id)
	else:
		if gs.has_method("buy_weapon"):
			gs.call("buy_weapon", id)
	refresh()


## Закрытие по Esc или E
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	var is_escape: bool = event.is_action_pressed("ui_cancel") or (
		event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE
	)
	var is_interact: bool = event.is_action_pressed("interact") or (
		event is InputEventKey and event.pressed and event.keycode == KEY_E
	)

	if is_escape or is_interact:
		close()
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
