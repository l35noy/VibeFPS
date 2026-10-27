extends CanvasLayer

## HUD игрока: здоровье (слева внизу), патроны в магазине (справа внизу) и очки
## (справа вверху). Висит ребёнком player.tscn, поэтому переживает смену сцены
## вместе с персонажем и не требует отдельной проводки в каждой локации.
##
## Источники — сигналы, а не опрос каждый кадр:
##   * здоровье — player.health_changed
##   * патроны  — текущее оружие.magazine_changed
##   * очки     — GameState.points_changed
## Плюс player.weapon_changed: при свопе оружия (Task 10) счётчик патронов
## пере-привязывается к новому стволу, а не остаётся на старом.
##
## bind() отделён от _ready() намеренно: _ready() вычисляет источники из
## окружения, а bind() принимает их явно, поэтому тест впрыскивает фейки и
## проверяет HUD отдельно от игрока, пистолета и GameState. Повторный bind()
## отключает прежние подписки, поэтому пере-привязка не плодит дубли.
##
## Null-safe: нет игрока, оружия или GameState — HUD молчит и не падает. Это не
## запас на всякий случай: лобби и макетки создают игрока без оружия, а
## headless-проверки — без GameState.

var _player: Node = null
var _weapon: Node = null
var _game_state: Node = null
var _is_reloading: bool = false

@onready var _health_label: Label = get_node_or_null("HealthLabel") as Label
@onready var _health_bar: ProgressBar = get_node_or_null("HealthBar") as ProgressBar
@onready var _reload_label: Label = get_node_or_null("ReloadLabel") as Label
@onready var _ammo_label: Label = get_node_or_null("AmmoLabel") as Label
@onready var _points_label: Label = get_node_or_null("PointsLabel") as Label
@onready var _inventory_panel: Control = get_node_or_null("InventoryPanel") as Control
@onready var _wave_label: Label = get_node_or_null("WaveLabel") as Label
@onready var _boss_container: Control = get_node_or_null("BossContainer") as Control
@onready var _boss_label: Label = get_node_or_null("BossContainer/BossLabel") as Label
@onready var _boss_bar: ProgressBar = get_node_or_null("BossContainer/BossBar") as ProgressBar
@onready var _interact_prompt: Label = get_node_or_null("InteractPrompt") as Label
@onready var _shop_modal: Control = get_node_or_null("ShopModal") as Control
@onready var _defeat_panel: Control = get_node_or_null("DefeatPanel") as Control
@onready var _defeat_btn: Button = get_node_or_null("DefeatPanel/VBox/LobbyButton") as Button
@onready var _victory_panel: Control = get_node_or_null("VictoryPanel") as Control
@onready var _victory_btn: Button = get_node_or_null("VictoryPanel/VBox/LobbyButton") as Button
@onready var _crosshair: Control = get_node_or_null("Crosshair") as Control


func _process(_delta: float) -> void:
	# Скрываем прицел при открытых модальных окнах (магазин, инвентарь, экраны победы/поражения)
	var ch := get_crosshair()
	if ch != null:
		var should_show := not is_modal_open()
		if ch.visible != should_show:
			ch.visible = should_show


## Получить узел прицела
func get_crosshair() -> Control:
	if _crosshair != null:
		return _crosshair
	_crosshair = get_node_or_null("Crosshair") as Control
	return _crosshair


## Управление видимостью прицела (скрывается в модальных окнах)
func set_crosshair_visible(is_visible: bool) -> void:
	var ch := get_crosshair()
	if ch != null and ch.visible != is_visible:
		ch.visible = is_visible


func _ready() -> void:
	bind(_find_player(), _find_weapon(), _find_game_state())
	if _defeat_btn != null and not _defeat_btn.pressed.is_connected(_on_defeat_return_pressed):
		_defeat_btn.pressed.connect(_on_defeat_return_pressed)
	if _victory_btn != null and not _victory_btn.pressed.is_connected(_on_victory_return_pressed):
		_victory_btn.pressed.connect(_on_victory_return_pressed)


func _get_interact_prompt() -> Label:
	if _interact_prompt != null:
		return _interact_prompt
	_interact_prompt = get_node_or_null("InteractPrompt") as Label
	return _interact_prompt


func _get_shop_modal() -> Control:
	if _shop_modal != null:
		return _shop_modal
	_shop_modal = get_node_or_null("ShopModal") as Control
	return _shop_modal


## Открыто ли какое-либо модальное окно интерфейса (инвентарь, магазин, экран поражения, экран победы).
func is_modal_open() -> bool:
	if _inventory_panel != null and _inventory_panel.has_method("is_open") and bool(_inventory_panel.call("is_open")):
		return true
	var shop := _get_shop_modal()
	if shop != null and shop.has_method("is_open") and bool(shop.call("is_open")):
		return true
	if _defeat_panel != null and _defeat_panel.visible:
		return true
	if _victory_panel != null and _victory_panel.visible:
		return true
	for child in get_children():
		if child != _inventory_panel and child != shop and child.is_in_group("modal_ui"):
			if child.has_method("is_open") and bool(child.call("is_open")):
				return true
			if (child is CanvasItem) and (child as CanvasItem).visible:
				return true
	return false


## Установить контекстный текст подсказки взаимодействия [E].
func set_interaction_prompt(prompt_text: String) -> void:
	var prompt := _get_interact_prompt()
	if prompt == null:
		return
	if prompt_text.is_empty() or is_modal_open():
		if prompt.visible:
			prompt.visible = false
		if not prompt.text.is_empty():
			prompt.text = ""
	else:
		var target_text := "[E] " + prompt_text
		if not prompt.visible:
			prompt.visible = true
		if prompt.text != target_text:
			prompt.text = target_text


## Обновление видимости подсказки взаимодействия (скрыть при открытом модальном окне).
func update_interaction_visibility() -> void:
	var prompt := _get_interact_prompt()
	if is_modal_open() and prompt != null:
		prompt.visible = false


## Открыть модальное окно магазина оружия.
func open_shop_modal() -> void:
	var shop := _get_shop_modal()
	if shop != null and shop.has_method("open"):
		shop.call("open")
		update_interaction_visibility()


## Отписка при выходе из дерева: узлы, к которым HUD был привязан, переживают
## его (GameState — автозагрузка), и оставлять в живом сигнале обработчик
## мёртвого узла не нужно.
func _exit_tree() -> void:
	_disconnect_sources()


## Привязать HUD к источникам. Любой аргумент может быть null. Вызывается из
## _ready() с источниками из окружения; тест зовёт напрямую с фейками. Повторный
## вызов сначала снимает прежние подписки, поэтому безопасен.
func bind(player: Node, weapon: Node, game_state: Node) -> void:
	_disconnect_sources()
	_player = player
	_weapon = weapon
	_game_state = game_state
	_connect_sources()
	_refresh_all()


## HUD — ребёнок игрока, и это единственная причина, по которой он знает, кого
## показывать. Поиск по группе здесь не нужен: узел уже стоит на персонаже.
func _find_player() -> Node:
	return get_parent()


func _find_weapon() -> Node:
	var player := get_parent()
	if player != null and player.has_method("current_weapon"):
		return player.current_weapon()
	return null


func _find_game_state() -> Node:
	return get_node_or_null("/root/GameState")


# --------------------------------------------------------------------------
# подписки
# --------------------------------------------------------------------------

func _connect_sources() -> void:
	if _player != null:
		_connect(_player, "health_changed", _on_health_changed)
		_connect(_player, "weapon_changed", _on_weapon_changed)
	_connect(_weapon, "magazine_changed", _on_magazine_changed)
	_connect(_weapon, "reload_started", _on_reload_started)
	_connect(_weapon, "reload_finished", _on_reload_finished)
	_connect(_game_state, "points_changed", _on_points_changed)


func _disconnect_sources() -> void:
	_disconnect(_player, "health_changed", _on_health_changed)
	_disconnect(_player, "weapon_changed", _on_weapon_changed)
	_disconnect(_weapon, "magazine_changed", _on_magazine_changed)
	_disconnect(_weapon, "reload_started", _on_reload_started)
	_disconnect(_weapon, "reload_finished", _on_reload_finished)
	_disconnect(_game_state, "points_changed", _on_points_changed)
	_render_reload(false)


## Подписка на сигнал, если он вообще есть у источника: узел без нужного сигнала
## (плайн-Node, игрок без оружия) — это не ошибка, а «показывать нечего».
## is_instance_valid, а не `!= null`: ссылка на освобождённый узел не null, и
## обращение к ней падает с «previously freed».
func _connect(source: Node, signal_name: String, handler: Callable) -> void:
	if not is_instance_valid(source):
		return
	if source.has_signal(signal_name) and not source.is_connected(signal_name, handler):
		source.connect(signal_name, handler)


func _disconnect(source: Node, signal_name: String, handler: Callable) -> void:
	if not is_instance_valid(source):
		return
	if source.has_signal(signal_name) and source.is_connected(signal_name, handler):
		source.disconnect(signal_name, handler)


# --------------------------------------------------------------------------
# начальное состояние
# --------------------------------------------------------------------------

## Заполнить все три элемента из текущего состояния источников. Нужен, потому
## что сигналы сообщают только об изменениях, а HUD появляется уже после того,
## как игрок, оружие и очки получили начальные значения.
func _refresh_all() -> void:
	if _player != null and _player.has_method("health"):
		_render_health(float(_player.call("health")), _max_health_of(_player))
	if _weapon != null and _weapon.has_method("current_mag"):
		_render_ammo(int(_weapon.call("current_mag")))
	if _weapon != null and _weapon.has_method("is_reloading"):
		_render_reload(bool(_weapon.call("is_reloading")))
	else:
		_render_reload(false)
	if _game_state != null:
		var current_points: Variant = _game_state.get("points")
		if current_points != null:
			_render_points(int(current_points))


## Потолок здоровья из свойства игрока. Нет свойства — 0.0, и полоса покажет
## пусто, а не поделит на выдуманное число.
func _max_health_of(player: Node) -> float:
	var maximum: Variant = player.get("max_health")
	return float(maximum) if maximum != null else 0.0


# --------------------------------------------------------------------------
# реакции на сигналы
# --------------------------------------------------------------------------

func _on_health_changed(current: float, maximum: float) -> void:
	_render_health(current, maximum)


## Своп оружия: старый ствол больше не источник патронов.
func _on_weapon_changed(weapon: Node) -> void:
	_disconnect(_weapon, "magazine_changed", _on_magazine_changed)
	_disconnect(_weapon, "reload_started", _on_reload_started)
	_disconnect(_weapon, "reload_finished", _on_reload_finished)
	_weapon = weapon
	_connect(_weapon, "magazine_changed", _on_magazine_changed)
	_connect(_weapon, "reload_started", _on_reload_started)
	_connect(_weapon, "reload_finished", _on_reload_finished)
	if _weapon != null and _weapon.has_method("current_mag"):
		_render_ammo(int(_weapon.call("current_mag")))
	var reloading := false
	if _weapon != null and _weapon.has_method("is_reloading"):
		reloading = bool(_weapon.call("is_reloading"))
	_render_reload(reloading)


func _on_magazine_changed(current: int, _capacity: int) -> void:
	_render_ammo(current)


func _on_points_changed(points: int) -> void:
	_render_points(points)


func _on_reload_started() -> void:
	_render_reload(true)


func _on_reload_finished() -> void:
	_render_reload(false)


# --------------------------------------------------------------------------
# отрисовка
# --------------------------------------------------------------------------

## Полоса и подпись считаются от одной доли, чтобы проценты в тексте и
## заполнение шкалы не могли разойтись. Ноль или отрицательный потолок — пустая
## полоса, а не деление на ноль.
func _render_health(current: float, maximum: float) -> void:
	var fraction := 0.0
	if maximum > 0.0:
		fraction = clampf(current / maximum, 0.0, 1.0)
	if _health_label != null:
		_health_label.text = "HP %d%%" % int(round(fraction * 100.0))
	if _health_bar != null:
		_health_bar.max_value = maxf(maximum, 1.0)
		_health_bar.value = clampf(current, 0.0, maxf(maximum, 1.0))


func _render_ammo(count: int) -> void:
	if _ammo_label != null:
		_ammo_label.text = str(count)


func _render_points(value: int) -> void:
	if _points_label != null:
		_points_label.text = str(value)


func _render_reload(reloading: bool) -> void:
	_is_reloading = reloading
	if _reload_label != null:
		_reload_label.visible = reloading


## Публичный геттер для проверок и тестов: идёт ли сейчас перезарядка.
func is_reloading() -> bool:
	return _is_reloading


# --------------------------------------------------------------------------
# волны, босс и экраны победы/поражения (Фаза 4)
# --------------------------------------------------------------------------

func set_wave(current: int, total: int) -> void:
	if _wave_label != null:
		_wave_label.text = "ВОЛНА %d / %d" % [current, total]


func set_intermission(time_left: float) -> void:
	if _wave_label != null:
		var seconds := int(ceil(time_left))
		_wave_label.text = "СЛЕДУЮЩАЯ ВОЛНА ЧЕРЕЗ: %d С" % seconds


func clear_wave_display() -> void:
	if _wave_label != null:
		_wave_label.text = ""


## Сообщение о зачистке локации и открытии портала выхода.
func show_location_cleared() -> void:
	if _wave_label != null:
		_wave_label.text = "ЛОКАЦИЯ ЗАЧИЩЕНА! ПОРТАЛ ВЫХОДА ОТКРЫТ"


func show_boss_bar(boss_name: String, current: float, maximum: float) -> void:
	if _boss_container != null:
		_boss_container.visible = true
	if _boss_label != null and not boss_name.is_empty():
		_boss_label.text = "БОСС: %s" % boss_name.to_upper()
	update_boss_health(current, maximum)


func update_boss_health(current: float, maximum: float) -> void:
	if _boss_bar != null:
		_boss_bar.max_value = maxf(maximum, 1.0)
		_boss_bar.value = clampf(current, 0.0, maxf(maximum, 1.0))


func hide_boss_bar() -> void:
	if _boss_container != null:
		_boss_container.visible = false


func show_defeat() -> void:
	if _defeat_panel != null:
		_defeat_panel.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func show_victory() -> void:
	if _victory_panel != null:
		_victory_panel.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_defeat_return_pressed() -> void:
	var gs := get_node_or_null("/root/GameState") as GameState
	if gs != null:
		gs.return_to_lobby("death")


func _on_victory_return_pressed() -> void:
	var gs := get_node_or_null("/root/GameState") as GameState
	if gs != null:
		gs.return_to_lobby("victory")
