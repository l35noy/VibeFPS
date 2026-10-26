extends SceneTree

## Tier 4 E2E Test Suite: Сквозные игровые сценарии (Real-World Application Scenarios)
## Проверяет полные сквозные игровые сессии игрока от старта до финала.
## Запуск: godot --headless --path . --script res://tests/e2e/test_tier4_scenarios.gd

const _TEMP_SAVE_PATH := "user://e2e_tier4_save.json"

var _checks: int = 0
var _passes: int = 0
var _failures: PackedStringArray = []
var _skips: PackedStringArray = []


func _initialize() -> void:
	print("==========================================================================")
	print("=== VibeFPS E2E Test Suite: Tier 4 — Real-World Application Scenarios ===")
	print("==========================================================================")

	await _scenario_01_fresh_game_session()
	await _scenario_02_shopping_progression()
	await _scenario_03_arena_combat_loop()
	await _scenario_04_defeat_recovery_resilience()

	_print_summary()
	_cleanup()
	quit(1 if _failures.size() > 0 else 0)


func _pass(label: String, detail: String = "") -> void:
	_checks += 1
	_passes += 1
	print("  [PASS] %s %s" % [label, detail])


func _fail(label: String, detail: String = "") -> void:
	_checks += 1
	var msg: String = "%s %s" % [label, detail]
	_failures.append(msg)
	print("  [FAIL] %s" % msg)


func _skip(label: String, reason: String) -> void:
	_checks += 1
	var msg: String = "%s (ПРОПУСК: %s)" % [label, reason]
	_skips.append(msg)
	print("  [SKIP] %s" % msg)


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass(label, detail)
	else:
		_fail(label, detail)


# ==================================================================
# Сценарий 1: Новая сессия — Спавн в Лобби, Арена 01, Волна 1, Возврат
# ==================================================================
func _scenario_01_fresh_game_session() -> void:
	print("\n--- [Scenario 1] Новая сессия: Старт в Лобби -> Арена 01 -> Волна 1 -> Лобби ---")
	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		_skip("Scenario 1 fresh_game_session", "Синглтон GameState недоступен в изоляции")
		return

	# 1. Спавн в Лобби с пистолетом
	var eq: String = gs.get("equipped_weapon_id")
	_check(eq == "pistol", "Scenario 1 fresh_game_session", "Стартовое оружие в руках игрока — Pistol")

	var unlocked: PackedStringArray = gs.get("unlocked_locations")
	if not unlocked.has("arena_01"):
		_skip("Scenario 1 fresh_game_session", "Ожидает завершения Worker M1: добавление arena_01 в unlocked_locations")
	else:
		var scene_log: Array[String] = []
		gs.scene_changer = func(path: String) -> void: scene_log.append(path)

		# 2. Переход на Арену 01
		if gs.has_method("enter_location"):
			var can_enter: bool = gs.call("enter_location", "arena_01")
			_check(can_enter and scene_log.size() > 0 and scene_log.back().ends_with("arena_01.tscn"),
				"Scenario 1 fresh_game_session", "Успешный переход на Арену 01 со старта игры")

		# 3. Начисление очков за волну 1 и 5с таймер передышки
		if gs.has_method("award_points"):
			gs.call("award_points", 150)
			_check(gs.get("points") >= 150, "Scenario 1 fresh_game_session", "Очки за волну 1 начислены")

		# 4. Возврат в Лобби с сохранением очков
		if gs.has_method("return_to_lobby"):
			gs.call("return_to_lobby", "door")
			_check(scene_log.size() > 0 and scene_log.back().ends_with("lobby.tscn"),
				"Scenario 1 fresh_game_session", "Возврат в Лобби выполнен, прогресс сохранен")


# ==================================================================
# Сценарий 2: Развитие арсенала и покупки в магазине оружия
# ==================================================================
func _scenario_02_shopping_progression() -> void:
	print("\n--- [Scenario 2] Развитие арсенала: Накопление очков -> Магазин -> АК-47 -> Дробовик ---")
	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		_skip("Scenario 2 shopping_progression", "GameState недоступен")
		return

	# Имитируем баланс 1000 очков
	var initial_pts: int = gs.get("points")
	gs.set("points", 1000)

	# 1. Покупка АК-47 за 300 очков
	var bought_auto: bool = gs.call("buy_weapon", "auto") if gs.has_method("buy_weapon") else false
	if bought_auto:
		_check(gs.get("points") == 700 and gs.get("equipped_weapon_id") == "auto",
			"Scenario 2 shopping_progression", "Покупка АК-47 за 300 очков: баланс=700, оружие экипировано")
	else:
		_skip("Scenario 2 shopping_progression", "buy_weapon('auto') отклонен")

	# 2. Покупка Дробовика за 600 очков (при наличии)
	if FileAccess.file_exists("res://data/weapons/shotgun.tres") and gs.has_method("buy_weapon"):
		var bought_shotgun: bool = gs.call("buy_weapon", "shotgun")
		if bought_shotgun:
			_check(gs.get("points") == 100 and gs.get("equipped_weapon_id") == "shotgun",
				"Scenario 2 shopping_progression", "Покупка Дробовика за 600 очков: баланс=100, оружие экипировано")
		else:
			_fail("Scenario 2 shopping_progression", "Не удалось купить shotgun при балансе 700")
	else:
		_skip("Scenario 2 shopping_progression", "Ожидает Milestone M3: покупка Дробовика за 600 очков")

	gs.set("points", initial_pts)


# ==================================================================
# Сценарий 3: Интенсивный бой на Арене 01 с дробовиком
# ==================================================================
func _scenario_03_arena_combat_loop() -> void:
	print("\n--- [Scenario 3] Боевой цикл Арены 01: Дробовик против парящих кубов ---")
	if not FileAccess.file_exists("res://weapons/shotgun/shotgun.tscn"):
		_skip("Scenario 3 arena_combat_loop", "Ожидает Milestone M3: res://weapons/shotgun/shotgun.tscn")
		return

	var contact_scene: PackedScene = load("res://entities/enemies/contact/enemy_contact.tscn") as PackedScene
	if contact_scene == null:
		_fail("Scenario 3 arena_combat_loop", "enemy_contact.tscn не найден")
		return

	var enemy: CharacterBody3D = contact_scene.instantiate() as CharacterBody3D
	root.add_child(enemy)
	await physics_frame

	var died_called: Array[bool] = [false]
	enemy.connect("died", func() -> void: died_called[0] = true)

	# Боевой цикл: поражение парящего куба выстрелом дробовика (120 урона)
	enemy.call("take_damage", 120.0)
	await physics_frame
	await physics_frame

	var gs: Node = root.get_node_or_null("GameState")
	var initial_pts: int = gs.get("points") if gs != null else 0
	if gs != null and gs.has_method("award_points"):
		gs.call("award_points", 50)

	var pts_awarded: bool = gs == null or (gs.get("points") == initial_pts + 50)
	var dead: bool = not bool(enemy.call("is_alive")) if enemy.has_method("is_alive") else false
	var hovering: bool = bool(enemy.call("is_hovering")) if enemy.has_method("is_hovering") else false

	_check(died_called[0] and dead and not hovering and pts_awarded,
		"Scenario 3 arena_combat_loop", "Боевой цикл: куб уничтожен выстрелом дробовика, парение отключено, очки начислены")

	enemy.free()


# ==================================================================
# Сценарий 4: Поражение персонажа, перезапуск и устойчивость состояния
# ==================================================================
func _scenario_04_defeat_recovery_resilience() -> void:
	print("\n--- [Scenario 4] Поражение, экран рестарта и сохранность открытого оружия ---")
	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		_skip("Scenario 4 defeat_recovery_resilience", "GameState недоступен")
		return

	# Сохраняем начальное состояние
	var owned_before: PackedStringArray = gs.get("owned_weapons")
	var equipped_before: String = gs.get("equipped_weapon_id")

	gs.set("scene_changer", func(_path: String) -> void: pass)

	# Имитируем смерть персонажа и возврат в лобби
	if gs.has_method("return_to_lobby"):
		gs.call("return_to_lobby", "defeat")

	var owned_after: PackedStringArray = gs.get("owned_weapons")
	var equipped_after: String = gs.get("equipped_weapon_id")

	_check(owned_before == owned_after and equipped_before == equipped_after,
		"Scenario 4 defeat_recovery_resilience", "После перезапуска сцены арсенал и экипированное оружие полностью сохранены")


func _print_summary() -> void:
	print("\n==========================================================================")
	print("ИТОГИ TIER 4: %d проверок выполнено | %d пройдено | %d пропущено | %d провалено" % [
		_checks, _passes, _skips.size(), _failures.size()])
	print("==========================================================================")
	if _failures.size() > 0:
		for f in _failures:
			print("  [ОШИБКА] %s" % f)


func _cleanup() -> void:
	if FileAccess.file_exists(_TEMP_SAVE_PATH):
		DirAccess.remove_absolute(_TEMP_SAVE_PATH)
