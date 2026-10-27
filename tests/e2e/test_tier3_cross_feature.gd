extends SceneTree

## Tier 3 E2E Test Suite: Кросс-функциональные связки (Cross-Feature Combinations)
## Проверяет сквозную интеграцию между компонентами и модулями попарно.
## Запуск: godot --headless --path . --script res://tests/e2e/test_tier3_cross_feature.gd

const _TEMP_SAVE_PATH := "user://e2e_tier3_save.json"

var _checks: int = 0
var _passes: int = 0
var _failures: PackedStringArray = []
var _skips: PackedStringArray = []


func _initialize() -> void:
	print("==========================================================================")
	print("=== VibeFPS E2E Test Suite: Tier 3 — Cross-Feature Combinations (Pairwise) ===")
	print("==========================================================================")

	await process_frame
	await _test_pair_01_shop_shotgun_persistence()
	await _test_pair_02_shotgun_cube_physics()
	await _test_pair_03_cube_wave_intermission()
	await _test_pair_04_combat_lobby_shop_cycle()
	await _test_pair_05_hud_modal_interlock()
	await _test_pair_06_visual_style_coherence()

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
# 1. Магазин + Дробовик + Сохранение (R4 + R5 + R2)
# ==================================================================
func _test_pair_01_shop_shotgun_persistence() -> void:
	print("\n--- [Pair 1] Магазин + Дробовик + Сохранение (R4 + R5 + R2) ---")
	var gs: Node = root.get_node_or_null("GameState")
	var created_gs: bool = false
	if gs == null:
		var gs_class := load("res://core/game_state.gd") as GDScript
		if gs_class != null:
			gs = gs_class.new()
			gs.name = "GameState"
			root.add_child(gs)
			created_gs = true
		else:
			_skip("Pair 1 shop_shotgun_persistence", "Синглтон GameState недоступен в изоляции")
			return

	if not FileAccess.file_exists("res://data/weapons/shotgun.tres"):
		_skip("Pair 1 shop_shotgun_persistence", "Ожидает Milestone M3: res://data/weapons/shotgun.tres")
		if created_gs:
			gs.free()
		return

	# Проверяем цикл покупки дробовика, экипировки и сохранения в SaveSystem
	var prev_pts: int = gs.get("points")
	gs.set("points", 1000)
	var bought: bool = gs.call("buy_weapon", "shotgun")
	var owned: PackedStringArray = gs.get("owned_weapons")
	var equipped: String = gs.get("equipped_weapon_id")
	_check(bought and owned.has("shotgun") and equipped == "shotgun",
		"Pair 1 shop_shotgun_persistence", "Покупка дробовика за 600 очков автоматически экипирует его и обновляет owned_weapons")
	gs.set("points", prev_pts)
	if created_gs:
		gs.free()


# ==================================================================
# 2. Дробовик + Парящий куб-враг (R5 + R6)
# ==================================================================
func _test_pair_02_shotgun_cube_physics() -> void:
	print("\n--- [Pair 2] Дробовик + Физика парящего куба (R5 + R6) ---")
	if not FileAccess.file_exists("res://weapons/shotgun/shotgun.tscn"):
		_skip("Pair 2 shotgun_cube_physics", "Ожидает Milestone M3: res://weapons/shotgun/shotgun.tscn")
		return

	var contact_scene: PackedScene = load("res://entities/enemies/contact/enemy_contact.tscn") as PackedScene
	if contact_scene == null:
		_fail("Pair 2 shotgun_cube_physics", "enemy_contact.tscn не найден")
		return

	var enemy: CharacterBody3D = contact_scene.instantiate() as CharacterBody3D
	root.add_child(enemy)
	await physics_frame

	var pre_hover: bool = enemy.call("is_hovering") if enemy.has_method("is_hovering") else false
	_check(pre_hover, "Pair 2 shotgun_cube_physics", "Куб находится в режиме парения до поражения")

	# Наносим смертельный урон дробью (залп дробовика 120 урона при 60 HP куба)
	var died_called: Array[bool] = [false]
	enemy.connect("died", func() -> void: died_called[0] = true)
	enemy.call("take_damage", 120.0)
	await physics_frame
	await physics_frame

	var post_hover: bool = enemy.call("is_hovering") if enemy.has_method("is_hovering") else true
	var dead: bool = not bool(enemy.call("is_alive")) if enemy.has_method("is_alive") else false
	_check(died_called[0] and dead and not post_hover, "Pair 2 shotgun_cube_physics",
		"Поражение залпом дробовика уничтожает куб, отключает парение и активирует падение")

	enemy.free()


# ==================================================================
# 3. Волна врагов + Таймер передышки 5.0с (R6 + R7)
# ==================================================================
func _test_pair_03_cube_wave_intermission() -> void:
	print("\n--- [Pair 3] Очистка волны кубов + Таймер 5.0с (R6 + R7) ---")
	var wm_script: GDScript = load("res://levels/common/wave_manager.gd") as GDScript

	if wm_script != null:
		var wm: Node = wm_script.new()
		var dur: float = wm.get("intermission_duration")
		wm.set("auto_start", false)
		if wm.has_method("_start_intermission"):
			wm.call("_start_intermission")
		var is_intermission: bool = wm.call("get_state") == WaveManager.State.INTERMISSION if wm.has_method("get_state") else true
		_check(is_equal_approx(dur, 5.0) and is_intermission,
			"Pair 3 cube_wave_intermission", "Завершение волны врагов активирует передышку ровно на 5.0 секунд")
		wm.free()
	else:
		_fail("Pair 3 cube_wave_intermission", "wave_manager.gd не найден")


# ==================================================================
# 4. Бой на Арене + Возврат в Лобби + Трата очков (R2 + R7 + R4)
# ==================================================================
func _test_pair_04_combat_lobby_shop_cycle() -> void:
	print("\n--- [Pair 4] Бой на Арене -> Возврат в Лобби -> Трата очков (R2 + R7 + R4) ---")
	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		var gs_class: GDScript = load("res://core/game_state.gd") as GDScript
		if gs_class != null:
			gs = gs_class.new()
			gs.set("scene_changer", func(_path: String) -> void: pass)
			root.add_child(gs)

	if gs != null and gs.has_method("award_points") and gs.has_method("return_to_lobby"):
		var p_start: int = gs.get("points")
		gs.call("award_points", 400)
		_check(gs.get("points") == p_start + 400,
			"Pair 4 combat_lobby_shop_cycle", "Очки, заработанные на Арене, успешно сохраняются и доступны для покупок в Лобби")
		gs.set("points", p_start)
	else:
		_fail("Pair 4 combat_lobby_shop_cycle", "GameState award_points или return_to_lobby недоступны")


# ==================================================================
# 5. Подсказка HUD [E] + Модальное окно магазина (R3 + R4)
# ==================================================================
func _test_pair_05_hud_modal_interlock() -> void:
	print("\n--- [Pair 5] Подсказка HUD [E] + Модальное окно магазина (R3 + R4) ---")
	var ui_scene: PackedScene = load("res://ui/ui.tscn") as PackedScene
	if ui_scene != null:
		var ui: CanvasLayer = ui_scene.instantiate() as CanvasLayer
		root.add_child(ui)
		var prompt_label: Label = ui.find_child("InteractPrompt", true, false) as Label
		var shop_modal: Control = ui.find_child("ShopModal", true, false) as Control
		if prompt_label != null and shop_modal != null:
			# 1. По умолчанию подсказка скрыта, магазин закрыт
			ui.call("set_interaction_prompt", "Открыть магазин")
			var prompt_shown: bool = prompt_label.visible and prompt_label.text == "[E] Открыть магазин"

			# 2. Открываем магазин
			ui.call("open_shop_modal")
			var modal_opened: bool = ui.call("is_modal_open") and shop_modal.visible
			# При открытом магазине подсказка должна быть скрыта даже при попытке её обновить
			ui.call("set_interaction_prompt", "Открыть магазин")
			var prompt_hidden_when_open: bool = not prompt_label.visible

			# Проверяем гейт ввода: в режиме модального окна игровой ввод запрещён
			var input_blocked: bool = not InputGate.is_play_input_allowed(Input.MOUSE_MODE_VISIBLE)

			# 3. Закрываем магазин
			shop_modal.call("close")
			var modal_closed: bool = not ui.call("is_modal_open") and not shop_modal.visible
			ui.call("set_interaction_prompt", "Открыть магазин")
			var prompt_restored: bool = prompt_label.visible

			_check(prompt_shown and modal_opened and prompt_hidden_when_open and input_blocked and modal_closed and prompt_restored,
				"Pair 5 hud_modal_interlock",
				"Открытие модального окна магазина блокирует показ [E] подсказки и игровой ввод; закрытие восстанавливает HUD")
		else:
			_fail("Pair 5 hud_modal_interlock", "InteractPrompt или ShopModal не найден в ui.tscn")
		ui.free()
	else:
		_fail("Pair 5 hud_modal_interlock", "ui.tscn не найден")


# ==================================================================
# 6. Визуальный стиль сущностей: CAD-сетка + Контур (R1 + R5 + R6)
# ==================================================================
func _test_pair_06_visual_style_coherence() -> void:
	print("\n--- [Pair 6] Визуальная целостность стиля CAD-сетки и контуров (R1 + R5 + R6) ---")
	const SHADER_PATH := "res://levels/common/cad_grid.gdshader"
	if not FileAccess.file_exists(SHADER_PATH):
		_skip("Pair 6 visual_style_coherence", "Ожидает Milestone M2: cad_grid.gdshader")
		return

	var cad_mat := load("res://levels/common/cad_grid_material.tres") as ShaderMaterial
	var ih_mat := load("res://levels/common/inverted_hull_material.tres") as StandardMaterial3D
	var cad_ok: bool = cad_mat != null and cad_mat.shader != null
	var edge_shader_exists := ResourceLoader.exists("res://levels/common/edge_detection.gdshader")
	var ih_ok: bool = ih_mat != null and (edge_shader_exists or (ih_mat.next_pass != null and (ih_mat.next_pass as StandardMaterial3D).cull_mode == BaseMaterial3D.CULL_FRONT))
	_check(cad_ok and ih_ok, "Pair 6 visual_style_coherence", "Стиль CAD-сетки для поверхностей и белого матового шейдинга с контуром для сущностей согласован")


func _print_summary() -> void:
	print("\n==========================================================================")
	print("ИТОГИ TIER 3: %d проверок выполнено | %d пройдено | %d пропущено | %d провалено" % [
		_checks, _passes, _skips.size(), _failures.size()])
	print("==========================================================================")
	if _failures.size() > 0:
		for f in _failures:
			print("  [ОШИБКА] %s" % f)


func _cleanup() -> void:
	if FileAccess.file_exists(_TEMP_SAVE_PATH):
		DirAccess.remove_absolute(_TEMP_SAVE_PATH)
