extends SceneTree

## Проверка интерфейса HUD для VibeFPS (Фаза 3, Задача 9): CanvasLayer игрока,
## отображающий здоровье, магазин текущего оружия и счёт очков.
##
## Запуск: godot --headless --path . --script res://tests/ui.gd
##         .\tools\run_checks.ps1 ui

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


## Заглушка игрока: реализует интерфейс, необходимый для HUD (health_changed, weapon_changed).
class _FakePlayer extends Node:
	signal health_changed(current: float, maximum: float)
	signal weapon_changed(weapon: Node)

	var max_health: float = 100.0
	var _health: float = 100.0
	var _weapon: Node = null

	func health() -> float:
		return _health

	func current_weapon() -> Node:
		return _weapon

	func report_health(current: float, maximum: float) -> void:
		_health = current
		max_health = maximum
		health_changed.emit(current, maximum)

	func equip(weapon: Node) -> void:
		_weapon = weapon
		weapon_changed.emit(weapon)


## Заглушка оружия: magazine_changed и current_mag().
class _FakeWeapon extends Node:
	signal magazine_changed(current: int, capacity: int)

	var _mag: int = 0

	func current_mag() -> int:
		return _mag

	func report_magazine(current: int, capacity: int) -> void:
		_mag = current
		magazine_changed.emit(current, capacity)


## Заглушка GameState: points_changed и поле points.
class _FakeGameState extends Node:
	signal points_changed(points: int)

	var points: int = 0

	func report_points(value: int) -> void:
		points = value
		points_changed.emit(value)


func _label_text(ui: Node, node_name: String) -> String:
	var label := ui.get_node_or_null(node_name) as Label
	return label.text if label != null else "<missing>"


func _bar_value(ui: Node, node_name: String) -> float:
	var bar := ui.get_node_or_null(node_name) as ProgressBar
	return bar.value if bar != null else -1.0


func _bar_max(ui: Node, node_name: String) -> float:
	var bar := ui.get_node_or_null(node_name) as ProgressBar
	return bar.max_value if bar != null else -1.0


func _initialize() -> void:
	print("=== Проверка интерфейса (UI/HUD) ===")
	await _test_scene_contract()
	await _test_player_wiring()
	await _test_binding()
	await _test_weapon_changed_rebinds()
	await _test_null_safety()

	print("=== РЕЗУЛЬТАТ: %d проверок, %d провалено ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  ОШИБКА: %s" % f)
	quit(1 if _failures.size() > 0 else 0)


## Проверка контракта ui.tscn: узел верхнего уровня — CanvasLayer с ui.gd,
## четыре обязательных элемента UI существуют и имеют верные типы.
func _test_scene_contract() -> void:
	print("-- контракт ui.tscn")
	var packed: PackedScene = load(_UI_SCENE)
	_check(packed != null, "res://ui/ui.tscn загружается")
	if packed == null:
		return
	var ui := packed.instantiate()
	_check(ui is CanvasLayer, "корень ui.tscn является CanvasLayer",
		"(получено %s)" % ("null" if ui == null else ui.get_class()))
	if ui == null:
		return
	root.add_child(ui)
	await physics_frame
	_check(ui.has_method("bind"), "ui.gd предоставляет публичный метод bind(player, weapon, game_state)")
	_check(ui.get_node_or_null("HealthLabel") is Label, "HealthLabel является Label")
	_check(ui.get_node_or_null("HealthBar") is ProgressBar, "HealthBar является ProgressBar")
	_check(ui.get_node_or_null("AmmoLabel") is Label, "AmmoLabel является Label")
	_check(ui.get_node_or_null("PointsLabel") is Label, "PointsLabel является Label")
	ui.queue_free()
	await physics_frame


## Проводка сцены player.tscn: HUD висит дочерним узлом, игрок выставляет
## current_weapon() и weapon_changed, значения HUD заполняются при спавне.
func _test_player_wiring() -> void:
	print("-- проводка player.tscn: HUD привязан к игроку и заполняется при спавне")
	var packed: PackedScene = load(_PLAYER_SCENE)
	_check(packed != null, "res://entities/player/player.tscn загружается")
	if packed == null:
		return
	var player := packed.instantiate()
	if player == null:
		_check(false, "player.tscn инстанцируется")
		return
	var seen_weapons: Array = []
	player.weapon_changed.connect(func(weapon: Node) -> void: seen_weapons.append(weapon))
	root.add_child(player)
	await physics_frame

	_check(player.has_method("current_weapon"),
		"player.gd предоставляет метод current_weapon()")
	_check(player.has_signal("weapon_changed"),
		"player.gd предоставляет сигнал weapon_changed")
	var pistol := player.get_node_or_null("Pistol")
	_check(player.current_weapon() == pistol,
		"current_weapon() возвращает узел Pistol",
		"(получено %s)" % ("null" if player.current_weapon() == null else player.current_weapon().name))
	_check(seen_weapons.size() >= 1 and seen_weapons[0] == pistol,
		"weapon_changed сработал один раз с узлом pistol при готовности",
		"(получено %d событий)" % seen_weapons.size())

	var hud := player.get_node_or_null("UI")
	_check(hud != null and hud is CanvasLayer,
		"в player.tscn есть дочерний CanvasLayer с именем UI")
	if hud != null:
		_check(hud.has_method("bind"), "the player's UI runs ui.gd")
		# The player emits health_changed/weapon_changed in _ready, and the HUD
		# is a child (its _ready runs first), so it is already subscribed.
		_check(_label_text(hud, "HealthLabel") == "HP 100%",
			"the HUD health label starts full",
			"(got %s)" % _label_text(hud, "HealthLabel"))
		var ammo_expected := str(pistol.current_mag()) if pistol != null else "<none>"
		_check(_label_text(hud, "AmmoLabel") == ammo_expected,
			"the HUD ammo label starts at the loaded magazine",
			"(got %s, expected %s)" % [_label_text(hud, "AmmoLabel"), ammo_expected])
	player.queue_free()
	await physics_frame


## Метод bind() заполняет данные на месте и подписывается на сигналы.
func _test_binding() -> void:
	print("-- привязка данных (bind): здоровье, патроны и очки следуют за сигналами")
	var packed: PackedScene = load(_UI_SCENE)
	if packed == null:
		_check(false, "res://ui/ui.tscn загружается (binding)")
		return
	var ui := packed.instantiate()
	root.add_child(ui)
	await physics_frame

	var player := _FakePlayer.new()
	var weapon := _FakeWeapon.new()
	var gs := _FakeGameState.new()
	root.add_child(player)
	root.add_child(weapon)
	root.add_child(gs)

	player.report_health(75.0, 100.0)
	player.equip(weapon)
	weapon.report_magazine(12, 18)
	gs.report_points(300)

	ui.call("bind", player, weapon, gs)
	_check(_label_text(ui, "HealthLabel") == "HP 75%",
		"bind() считывает текущее здоровье на месте",
		"(получено %s)" % _label_text(ui, "HealthLabel"))
	_check(_bar_value(ui, "HealthBar") == 75.0 and _bar_max(ui, "HealthBar") == 100.0,
		"bind() устанавливает полосу здоровья в current/max",
		"(получено %.1f/%.1f)" % [_bar_value(ui, "HealthBar"), _bar_max(ui, "HealthBar")])
	_check(_label_text(ui, "AmmoLabel") == "12",
		"bind() считывает текущий магазин на месте",
		"(получено %s)" % _label_text(ui, "AmmoLabel"))
	_check(_label_text(ui, "PointsLabel") == "300",
		"bind() считывает текущие очки на месте",
		"(получено %s)" % _label_text(ui, "PointsLabel"))

	player.report_health(40.0, 100.0)
	_check(_label_text(ui, "HealthLabel") == "HP 40%",
		"health_changed обновляет текстовую метку здоровья")
	_check(_bar_value(ui, "HealthBar") == 40.0, "и полосу здоровья")

	weapon.report_magazine(5, 18)
	_check(_label_text(ui, "AmmoLabel") == "5", "magazine_changed обновляет счётчик патронов")

	gs.report_points(250)
	_check(_label_text(ui, "PointsLabel") == "250", "points_changed обновляет счётчик очков")

	ui.queue_free()
	player.queue_free()
	weapon.queue_free()
	gs.queue_free()
	await physics_frame


## Смена оружия на игроке перенаправляет счётчик патронов на новое оружие.
func _test_weapon_changed_rebinds() -> void:
	print("-- weapon_changed переподключает счётчик патронов к новому оружию")
	var packed: PackedScene = load(_UI_SCENE)
	if packed == null:
		_check(false, "res://ui/ui.tscn загружается (weapon_changed)")
		return
	var ui := packed.instantiate()
	root.add_child(ui)
	await physics_frame

	var player := _FakePlayer.new()
	var first := _FakeWeapon.new()
	var second := _FakeWeapon.new()
	root.add_child(player)
	root.add_child(first)
	root.add_child(second)
	first.report_magazine(18, 18)
	second.report_magazine(7, 30)

	ui.call("bind", player, first, null)
	_check(_label_text(ui, "AmmoLabel") == "18",
		"патроны изначально привязаны к первому оружию", "(получено %s)" % _label_text(ui, "AmmoLabel"))

	player.equip(second)
	_check(_label_text(ui, "AmmoLabel") == "7",
		"weapon_changed переподключает отображение патронов к новому оружию",
		"(получено %s)" % _label_text(ui, "AmmoLabel"))

	first.report_magazine(1, 18)
	_check(_label_text(ui, "AmmoLabel") == "7",
		"старое оружие больше не управляет счётчиком",
		"(получено %s)" % _label_text(ui, "AmmoLabel"))
	second.report_magazine(2, 30)
	_check(_label_text(ui, "AmmoLabel") == "2",
		"а новое оружие корректно обновляет счётчик", "(получено %s)" % _label_text(ui, "AmmoLabel"))

	ui.queue_free()
	player.queue_free()
	first.queue_free()
	second.queue_free()
	await physics_frame


## Безопасность при отсутствии источников (null safety).
func _test_null_safety() -> void:
	print("-- безопасность при null: нет игрока, оружия или GameState")
	var packed: PackedScene = load(_UI_SCENE)
	if packed == null:
		_check(false, "res://ui/ui.tscn загружается (null safety)")
		return
	var ui := packed.instantiate()
	root.add_child(ui)
	await physics_frame

	ui.call("bind", null, null, null)
	_check(true, "bind(null, null, null) выполняется без ошибок")

	var plain := Node.new()
	root.add_child(plain)
	ui.call("bind", plain, null, null)
	_check(true, "привязка обычного узла без сигналов проходит без ошибок")

	var weapon := _FakeWeapon.new()
	weapon.report_magazine(9, 18)
	root.add_child(weapon)
	ui.call("bind", null, weapon, null)
	_check(_label_text(ui, "AmmoLabel") == "9", "одного оружия достаточно для отображения патронов")
	ui.call("bind", null, null, null)
	weapon.report_magazine(3, 18)
	_check(_label_text(ui, "AmmoLabel") == "9",
		"после отвязки старое оружие больше не меняет счётчик",
		"(получено %s)" % _label_text(ui, "AmmoLabel"))

	ui.queue_free()
	plain.queue_free()
	weapon.queue_free()
	await physics_frame
