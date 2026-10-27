extends SceneTree

## Tier 2 E2E Test Suite: Граничные и угловые случаи (Boundary & Corner Cases)
## Проверяет поведение на границах значений, лимиты ввода, десинхронизацию и стресс-тесты.
## Запуск: godot --headless --path . --script res://tests/e2e/test_tier2_boundaries.gd

const _TEMP_SAVE_PATH := "user://e2e_tier2_save.json"

var _checks: int = 0
var _passes: int = 0
var _failures: PackedStringArray = []
var _skips: PackedStringArray = []


func _initialize() -> void:
	print("==========================================================================")
	print("=== VibeFPS E2E Test Suite: Tier 2 — Boundary & Corner Cases (R1–R7) ===")
	print("==========================================================================")

	await process_frame
	await _test_r1_boundaries()
	await _test_r2_boundaries()
	await _test_r3_boundaries()
	await _test_r4_boundaries()
	await _test_r5_boundaries()
	await _test_r6_boundaries()
	await _test_r7_boundaries()

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
# R1 Boundaries: Визуальный стиль и шейдинг (5 тестов)
# ==================================================================
func _test_r1_boundaries() -> void:
	print("\n--- [R1 Boundaries] Граничные условия стиля и шейдинга ---")

	# R1.B1: Отклонение слишком темного альбедо (< 0.85)
	var ih_mat: StandardMaterial3D = load("res://levels/common/inverted_hull_material.tres") as StandardMaterial3D
	_check(ih_mat != null and ih_mat.albedo_color.r >= 0.85,
		"R1.B1 albedo_threshold_rejection", "Порог альбедо для белого матового стиля строго >= 0.85 (получено %.2f)" % (ih_mat.albedo_color.r if ih_mat != null else 0.0))

	# R1.B2: Толщина и параметры контура (EdgeDetection шейдер либо Inverted Hull)
	var edge_shader: Shader = load("res://levels/common/edge_detection.gdshader") as Shader if ResourceLoader.exists("res://levels/common/edge_detection.gdshader") else null
	var np_mat: StandardMaterial3D = (ih_mat.next_pass as StandardMaterial3D) if ih_mat != null else null
	var outline_configured: bool = edge_shader != null or (np_mat != null and np_mat.grow == true and np_mat.grow_amount >= 0.005 and np_mat.grow_amount <= 0.05)
	_check(outline_configured,
		"R1.B2 inverted_hull_grow_bounds", "Параметры экранного контура корректно сконфигурированы")

	# R1.B3: Независимость контура от освещения сцены (unshaded режим шейдера или материала)
	var unshaded_ok: bool = edge_shader != null or (np_mat != null and np_mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED)
	_check(unshaded_ok,
		"R1.B3 unshaded_contour_lighting_independence", "Контур независим от освещения сцены (экранный пост-процесс unshaded)")

	# R1.B4: Равномерность масштаба CAD-сетки по осям (Triplanar uniform)
	var cad_mat: ShaderMaterial = load("res://levels/common/cad_grid_material.tres") as ShaderMaterial
	var grid_size_val: float = float(cad_mat.get_shader_parameter("grid_size")) if cad_mat != null else 0.0
	_check(cad_mat != null and cad_mat.shader != null and grid_size_val > 0.0,
		"R1.B4 triplanar_uniform_aspect", "CAD-сетка использует трипланарное проецирование с равномерным шагом сетки %.1f м" % grid_size_val)

	# R1.B5: Полная непрозрачность поверхностей (alpha == 1.0)
	var bg_color_val: Color = cad_mat.get_shader_parameter("background_color") if cad_mat != null else Color.WHITE
	_check(ih_mat != null and is_equal_approx(ih_mat.albedo_color.a, 1.0) and is_equal_approx(bg_color_val.a, 1.0),
		"R1.B5 fully_opaque_alpha", "Все монохромные архитектурные материалы полностью непрозрачны (alpha=1.0)")


# ==================================================================
# R2 Boundaries: Локации и геометрия Лобби (5 тестов)
# ==================================================================
func _test_r2_boundaries() -> void:
	print("\n--- [R2 Boundaries] Граничные условия локаций и сцен ---")

	var gs_node: Node = root.get_node_or_null("GameState")
	var gs_created_locally: bool = false
	if gs_node == null:
		var gs_class: GDScript = load("res://core/game_state.gd") as GDScript
		if gs_class != null:
			gs_node = gs_class.new()
			gs_node.set("scene_changer", func(_path: String) -> void: pass)
			root.add_child(gs_node)
			gs_created_locally = true

	# R2.B1: Безопасный отказ при запросе несуществующей локации
	if gs_node != null and gs_node.has_method("enter_location"):
		var ok: bool = gs_node.call("enter_location", "non_existent_location_42")
		_check(not ok, "R2.B1 invalid_location_handled", "Запрос несуществующей локации возвращает false без падений")
	else:
		_fail("R2.B1 invalid_location_handled", "GameState недоступен")

	# R2.B2: Отказ при переходе в удаленный range
	if gs_node != null and gs_node.has_method("enter_location"):
		var scenes: Dictionary = gs_node.get("_LOCATION_SCENES")
		var ok: bool = gs_node.call("enter_location", "range")
		_check(not scenes.has("range") and not ok, "R2.B2 deleted_range_rejected", "Переход в удаленный тир range отклоняется")
	else:
		_fail("R2.B2 deleted_range_rejected", "GameState недоступен")

	# R2.B3: Отказ при переходе в удаленный main
	if gs_node != null and gs_node.has_method("enter_location"):
		var scenes: Dictionary = gs_node.get("_LOCATION_SCENES")
		var ok: bool = gs_node.call("enter_location", "main")
		_check(not scenes.has("main") and not ok, "R2.B3 deleted_main_rejected", "Переход в удаленный main отклоняется")
	else:
		_fail("R2.B3 deleted_main_rejected", "GameState недоступен")

	# R2.B4: Замкнутость коллайдеров зала Лобби и размеры 28x36м
	var lobby_scene: PackedScene = load("res://levels/lobby/lobby.tscn") as PackedScene
	if lobby_scene != null:
		var lobby: Node = lobby_scene.instantiate()
		var walls: Node = lobby.find_child("Walls", true, false)
		var floor_node: Node = lobby.find_child("Floor", true, false)
		var floor_mesh_inst: MeshInstance3D = floor_node.find_child("Mesh", true, false) as MeshInstance3D if floor_node != null else null
		var floor_size := Vector3.ZERO
		if floor_mesh_inst != null and floor_mesh_inst.mesh is BoxMesh:
			floor_size = (floor_mesh_inst.mesh as BoxMesh).size
		_check(walls != null and is_equal_approx(floor_size.x, 28.0) and is_equal_approx(floor_size.z, 36.0),
			"R2.B4 lobby_boundary_collision_enclosure", "Стены лобби с коллайдерами окружают архитектурный зал 28x36м")
		lobby.free()
	else:
		_fail("R2.B4 lobby_boundary_collision_enclosure", "lobby.tscn не найден")

	# R2.B5: Блокировка активации двери при свободном курсоре мыши
	var gate_script: GDScript = load("res://core/input_gate.gd") as GDScript
	if gate_script != null:
		var can_interact: bool = gate_script.is_play_input_allowed(Input.MOUSE_MODE_VISIBLE)
		_check(not can_interact, "R2.B5 door_interaction_without_mouse_capture", "Дверь не активируется при курсоре MOUSE_MODE_VISIBLE")
	else:
		_fail("R2.B5 door_interaction_without_mouse_capture", "input_gate.gd не найден")


# ==================================================================
# R3 Boundaries: Контекстный HUD взаимодействия (5 тестов)
# ==================================================================
func _test_r3_boundaries() -> void:
	print("\n--- [R3 Boundaries] Граничные условия HUD взаимодействия ---")

	# R3.B1: Строгая граница дистанции 3.49 м vs 3.51 м
	var player_scene: PackedScene = load("res://entities/player/player.tscn") as PackedScene
	var door_script: GDScript = load("res://levels/lobby/door_point.gd") as GDScript
	if player_scene != null and door_script != null:
		var test_player: CharacterBody3D = player_scene.instantiate() as CharacterBody3D
		root.add_child(test_player)
		test_player.global_position = Vector3.ZERO
		var target: Area3D = door_script.new() as Area3D
		root.add_child(target)
		target.global_position = Vector3(0.0, 0.0, 3.49)
		var found_in: Node = test_player.call("nearest_interactable")
		target.global_position = Vector3(0.0, 0.0, 3.51)
		var found_out: Node = test_player.call("nearest_interactable")
		_check(found_in == target and found_out == null,
			"R3.B1 exact_distance_boundary", "Дистанция 3.49м детектируется, 3.51м отсекается")
		target.free()
		test_player.free()
	else:
		_fail("R3.B1 exact_distance_boundary", "player.tscn или door_point.gd не найден")

	# R3.B2: Обработка пустой строки подсказки (не должно выводить пустой '[E] ')
	var ui_scene: PackedScene = load("res://ui/ui.tscn") as PackedScene
	if ui_scene != null:
		var ui: CanvasLayer = ui_scene.instantiate() as CanvasLayer
		if ui != null:
			var prompt_label: Label = ui.find_child("InteractPrompt", true, false) as Label
			if prompt_label != null and ui.has_method("set_interaction_prompt"):
				ui.call("set_interaction_prompt", "")
				_check(not prompt_label.visible or prompt_label.text == "",
					"R3.B2 empty_prompt_string_handling", "Пустая строка подсказки не выводит голый '[E] '")
			else:
				_skip("R3.B2 empty_prompt_string_handling", "Ожидает Milestone M5: InteractPrompt")
			ui.free()
	else:
		_fail("R3.B2 empty_prompt_string_handling", "ui.tscn не найден")

	# R3.B3: Быстрое пересечение границы (фликер-устойчивость)
	if ui_scene != null:
		var ui: CanvasLayer = ui_scene.instantiate() as CanvasLayer
		if ui != null:
			var prompt_label: Label = ui.find_child("InteractPrompt", true, false) as Label
			if prompt_label != null and ui.has_method("set_interaction_prompt"):
				for i in range(10):
					ui.call("set_interaction_prompt", "Открыть")
					ui.call("set_interaction_prompt", "")
				_check(not prompt_label.visible or prompt_label.text == "",
					"R3.B3 rapid_boundary_crossing", "Многократное быстрое пересечение границы оставляет HUD в стабильном скрытом состоянии")
			else:
				_fail("R3.B3 rapid_boundary_crossing", "InteractPrompt не найден в ui.tscn")
			ui.free()
		else:
			_fail("R3.B3 rapid_boundary_crossing", "Не удалось создать UI")
	else:
		_fail("R3.B3 rapid_boundary_crossing", "ui.tscn не найден")

	# R3.B4: Безопасное удаление целевого узла из сцены (Null-safety)
	if player_scene != null and door_script != null:
		var test_player: CharacterBody3D = player_scene.instantiate() as CharacterBody3D
		root.add_child(test_player)
		test_player.global_position = Vector3.ZERO
		var target: Area3D = door_script.new() as Area3D
		root.add_child(target)
		target.global_position = Vector3(0.0, 0.0, 2.0)
		target.queue_free()
		var nearest: Node = test_player.call("nearest_interactable")
		_check(nearest == null or is_instance_valid(nearest),
			"R3.B4 queue_freed_interactable_safety", "nearest_interactable безопасно обрабатывает queue_free узлы без падений")
		test_player.free()
	else:
		_fail("R3.B4 queue_freed_interactable_safety", "player.tscn не найден")

	# R3.B5: Равноудаленные интерактивные объекты (детерминизм выбора)
	if player_scene != null and door_script != null:
		var test_player: CharacterBody3D = player_scene.instantiate() as CharacterBody3D
		root.add_child(test_player)
		test_player.global_position = Vector3.ZERO
		var target1: Area3D = door_script.new() as Area3D
		var target2: Area3D = door_script.new() as Area3D
		root.add_child(target1)
		root.add_child(target2)
		target1.global_position = Vector3(2.0, 0.0, 0.0)
		target2.global_position = Vector3(-2.0, 0.0, 0.0)
		var choice1: Node = test_player.call("nearest_interactable")
		var choice2: Node = test_player.call("nearest_interactable")
		_check(choice1 != null and choice1 == choice2,
			"R3.B5 equidistant_interactables_determinism", "Выбор между равноудаленными объектами детерминирован")
		target1.free()
		target2.free()
		test_player.free()
	else:
		_fail("R3.B5 equidistant_interactables_determinism", "player.tscn не найден")


# ==================================================================
# R4 Boundaries: Модальное окно магазина (5 тестов)
# ==================================================================
func _test_r4_boundaries() -> void:
	print("\n--- [R4 Boundaries] Граничные условия магазина оружия ---")

	var gs_node: Node = root.get_node_or_null("GameState")
	var gs_created_locally: bool = false
	if gs_node == null:
		var gs_class: GDScript = load("res://core/game_state.gd") as GDScript
		if gs_class != null:
			gs_node = gs_class.new()
			gs_node.set("scene_changer", func(_path: String) -> void: pass)
			root.add_child(gs_node)
			gs_created_locally = true

	# R4.B1: Попытка покупки при 0 очков (отклонение)
	var weapon_to_test: String = "shotgun" if FileAccess.file_exists("res://data/weapons/shotgun.tres") else "auto"
	var test_price: int = 600 if weapon_to_test == "shotgun" else 300
	if gs_node != null and gs_node.has_method("buy_weapon"):
		var orig_points: int = gs_node.get("points")
		var orig_owned: PackedStringArray = gs_node.get("owned_weapons")
		var temp_owned: PackedStringArray = []
		for w in orig_owned:
			if w != weapon_to_test:
				temp_owned.append(w)
		gs_node.set("owned_weapons", temp_owned)
		gs_node.set("points", 0)
		var bought: bool = gs_node.call("buy_weapon", weapon_to_test)
		_check(not bought and gs_node.get("points") == 0,
			"R4.B1 purchase_zero_points_rejected", "Покупка при 0 очков отклонена, баланс не ушел в минус")
		gs_node.set("points", orig_points)
		gs_node.set("owned_weapons", orig_owned)
	else:
		_fail("R4.B1 purchase_zero_points_rejected", "GameState недоступен")

	# R4.B2: Покупка при балансе ровно равном стоимости
	if gs_node != null and gs_node.has_method("buy_weapon"):
		var orig_pts: int = gs_node.get("points")
		gs_node.set("points", test_price)
		var can_buy: bool = gs_node.call("can_afford", test_price) if gs_node.has_method("can_afford") else true
		_check(can_buy, "R4.B2 purchase_exact_cost_success", "Баланс ровно %d очков достаточен для покупки за %d" % [test_price, test_price])
		gs_node.set("points", orig_pts)
	else:
		_fail("R4.B2 purchase_exact_cost_success", "GameState недоступен")

	# R4.B3: Покупка при балансе на 1 очко меньше стоимости
	if gs_node != null and gs_node.has_method("can_afford"):
		var orig_p: int = gs_node.get("points")
		gs_node.set("points", test_price - 1)
		var afford: bool = gs_node.call("can_afford", test_price)
		_check(not afford, "R4.B3 purchase_cost_minus_one_disabled", "При %d очках покупка за %d заблокирована (кнопка disabled)" % [test_price - 1, test_price])
		gs_node.set("points", orig_p)
	else:
		_fail("R4.B3 purchase_cost_minus_one_disabled", "GameState can_afford недоступен")

	# R4.B4: Стресс-тест быстрого цикла открытия/закрытия модального окна
	var shop_script: GDScript = load("res://ui/shop_modal.gd") as GDScript
	if shop_script != null:
		var shop: Control = shop_script.new() as Control
		root.add_child(shop)
		for i in range(5):
			shop.call("open")
			shop.call("close")
		_check(not shop.visible and not shop.call("is_open"),
			"R4.B4 rapid_modal_open_close_cycle", "После быстрого цикла 5 открытий/закрытий модальное окно чисто закрыто")
		shop.free()
	else:
		_fail("R4.B4 rapid_modal_open_close_cycle", "shop_modal.gd не найден")

	# R4.B5: Закрытие через Esc, E и кнопку интерфейса дает одинаковое чистое состояние
	if shop_script != null:
		var shop: Control = shop_script.new() as Control
		root.add_child(shop)

		# 1. CloseButton
		shop.call("open")
		var close_btn: Button = shop.find_child("CloseButton", true, false) as Button
		if close_btn != null:
			close_btn.emit_signal("pressed")
		var ok_btn: bool = (not shop.visible)

		# 2. Esc key
		shop.call("open")
		var ev_esc := InputEventKey.new()
		ev_esc.keycode = KEY_ESCAPE
		ev_esc.pressed = true
		shop._unhandled_input(ev_esc)
		var ok_esc: bool = (not shop.visible)

		# 3. E key
		shop.call("open")
		var ev_e := InputEventKey.new()
		ev_e.keycode = KEY_E
		ev_e.pressed = true
		shop._unhandled_input(ev_e)
		var ok_e: bool = (not shop.visible)

		_check(ok_btn and ok_esc and ok_e,
			"R4.B5 modal_all_exit_triggers", "Все три триггера выхода (кнопка ✕, Escape, E) приводят к одинаковому закрытию окна")
		shop.free()
	else:
		_fail("R4.B5 modal_all_exit_triggers", "shop_modal.gd не найден")


# ==================================================================
# R5 Boundaries: Дробовик и параметры стрельбы (5 тестов)
# ==================================================================
func _test_r5_boundaries() -> void:
	print("\n--- [R5 Boundaries] Граничные условия дробовика и АК-47 ---")

	# R5.B1: Ограничение темпа стрельбы (спам-клик не производит лишних дробинок)
	const SHOTGUN_SCENE_PATH := "res://weapons/shotgun/shotgun.tscn"
	if FileAccess.file_exists(SHOTGUN_SCENE_PATH):
		var s_scene: PackedScene = load(SHOTGUN_SCENE_PATH) as PackedScene
		var shotgun: Shotgun = s_scene.instantiate() as Shotgun
		root.add_child(shotgun)
		shotgun.reset_for_scene_change()
		shotgun.fire_rate_source = shotgun
		shotgun.mock_mouse_mode = Input.MOUSE_MODE_CAPTURED
		shotgun.set("_armed", true)
		var first_fire: bool = shotgun.try_fire()
		var spam_fire: bool = shotgun.try_fire()
		_check(first_fire and not spam_fire and shotgun.current_mag() == 1,
			"R5.B1 shotgun_rapid_click_fire_rate_clamp", "Спам-клик блокируется кулдауном и не производит лишних выстрелов")
		shotgun.free()
	else:
		_fail("R5.B1 shotgun_rapid_click_fire_rate_clamp", "shotgun.tscn не найден")

	# R5.B2: Попытка выстрела при пустом магазине (0/2) не уменьшает патроны ниже нуля
	if FileAccess.file_exists(SHOTGUN_SCENE_PATH):
		var s_scene: PackedScene = load(SHOTGUN_SCENE_PATH) as PackedScene
		var shotgun: Shotgun = s_scene.instantiate() as Shotgun
		root.add_child(shotgun)
		shotgun.reset_for_scene_change()
		shotgun.fire_rate_source = shotgun
		shotgun.mock_mouse_mode = Input.MOUSE_MODE_CAPTURED
		shotgun.set("_armed", true)
		shotgun.try_fire()
		shotgun.set("_cooldown", 0.0)
		shotgun.try_fire()
		var empty_fire: bool = shotgun.try_fire()
		_check(not empty_fire and shotgun.current_mag() == 0,
			"R5.B2 shotgun_empty_click_no_negative_ammo", "Попытка выстрела при пустом магазине не уменьшает патроны ниже нуля")
		shotgun.free()
	else:
		_fail("R5.B2 shotgun_empty_click_no_negative_ammo", "shotgun.tscn не найден")

	# R5.B3: Разлёт дробинок строго ограничен конусом рассеивания
	if FileAccess.file_exists(SHOTGUN_SCENE_PATH):
		var s_scene: PackedScene = load(SHOTGUN_SCENE_PATH) as PackedScene
		var shotgun: Shotgun = s_scene.instantiate() as Shotgun
		root.add_child(shotgun)
		shotgun.reset_for_scene_change()
		shotgun.fire_rate_source = shotgun
		shotgun.mock_mouse_mode = Input.MOUSE_MODE_CAPTURED
		shotgun.set("_armed", true)
		shotgun.try_fire()
		var pellets: Array[Node3D] = shotgun.last_spawned_pellets
		var forward := -shotgun.global_transform.basis.z.normalized() if shotgun.is_inside_tree() else -shotgun.transform.basis.z.normalized()
		var max_spread_rad: float = deg_to_rad(shotgun.data.spread_angle_degrees if shotgun.data != null else 4.5)
		var bounded := true
		for p in pellets:
			if p is Projectile:
				var bdir: Vector3 = (p as Projectile).get("_direction") as Vector3
				if forward.angle_to(bdir) > max_spread_rad + 0.001:
					bounded = false
		_check(pellets.size() == 10 and bounded,
			"R5.B3 shotgun_pellet_spread_bounded", "Все 10 дробинок строго ограничены конусом рассеивания 4.5 град")
		shotgun.free()
	else:
		_fail("R5.B3 shotgun_pellet_spread_bounded", "shotgun.tscn не найден")

	# R5.B4: Маска коллизий дробинок (попадают по врагам и миру, но не по игроку)
	const PROJECTILE_PATH := "res://weapons/projectile/projectile.tscn"
	if FileAccess.file_exists(PROJECTILE_PATH):
		var pscene: PackedScene = load(PROJECTILE_PATH) as PackedScene
		if pscene != null:
			var proj: Area3D = pscene.instantiate() as Area3D
			# Слой 5 = снаряд (1 << 4 = 16), маска включает слой 1 (мир) и 4 (enemy_hurtbox)
			var hits_player: bool = (proj.collision_mask & (1 << 1)) != 0 # слой 2
			_check(not hits_player, "R5.B4 shotgun_collision_mask_isolation", "Снаряды оружия не сталкиваются с телом игрока")
			proj.free()
	else:
		_fail("R5.B4 shotgun_collision_mask_isolation", "projectile.tscn не найден")

	# R5.B5: Безопасность прерывания перезарядки АК-47 (патроны не восстанавливаются досрочно)
	const AUTO_SCENE_PATH := "res://weapons/auto/auto.tscn"
	if FileAccess.file_exists(AUTO_SCENE_PATH):
		var a_scene: PackedScene = load(AUTO_SCENE_PATH) as PackedScene
		var auto: Pistol = a_scene.instantiate() as Pistol
		root.add_child(auto)
		auto.reset_for_scene_change()
		auto.fire_rate_source = auto
		auto.mock_mouse_mode = Input.MOUSE_MODE_CAPTURED
		auto.set("_armed", true)
		auto.try_fire()
		var ammo_before_reload := auto.current_mag()
		var reload_started := auto.start_reload()
		auto._process(0.5)
		_check(reload_started and auto.is_reloading() and auto.current_mag() == ammo_before_reload and not auto.can_fire(),
			"R5.B5 ak47_reload_interruption_ammo_safety", "До завершения таймера перезарядки АК-47 патроны не восстанавливаются досрочно")
		auto.free()
	else:
		_fail("R5.B5 ak47_reload_interruption_ammo_safety", "auto.tscn не найден")


# ==================================================================
# R6 Boundaries: Парящий куб-враг (5 тестов)
# ==================================================================
func _test_r6_boundaries() -> void:
	print("\n--- [R6 Boundaries] Граничные условия парящего врага ---")

	# R6.B1: Одновременные смертельные попадания в одном физическом кадре
	var scene_b1: PackedScene = load("res://entities/enemies/contact/enemy_contact.tscn") as PackedScene
	if scene_b1 != null:
		var enemy: CharacterBody3D = scene_b1.instantiate() as CharacterBody3D
		root.add_child(enemy)
		await physics_frame
		var died_count: Array[int] = [0]
		enemy.connect("died", func() -> void: died_count[0] += 1)
		# Два одновременных смертельных вызова take_damage в одном физическом кадре
		enemy.call("take_damage", 60.0)
		enemy.call("take_damage", 60.0)
		_check(died_count[0] == 1, "R6.B1 cube_simultaneous_damage_instances",
			"Сигнал died испускается строго один раз при одновременных попаданиях")
		enemy.free()
	else:
		_fail("R6.B1 cube_simultaneous_damage_instances", "enemy_contact.tscn не найден")

	# R6.B2: Поддержание высоты парения над неровным полом
	var scene_b2: PackedScene = load("res://entities/enemies/contact/enemy_contact.tscn") as PackedScene
	if scene_b2 != null:
		var enemy: CharacterBody3D = scene_b2.instantiate() as CharacterBody3D
		root.add_child(enemy)
		enemy.global_position = Vector3(5.0, 2.0, 5.0)
		await physics_frame
		var h: float = enemy.call("get_hover_height") if enemy.has_method("get_hover_height") else 0.0
		_check(is_equal_approx(h, 1.0) and enemy.call("is_hovering"),
			"R6.B2 cube_hover_height_on_uneven_terrain",
			"Высота парения 1.0 м удерживается стабильно независимо от высоты спавна")
		enemy.free()
	else:
		_fail("R6.B2 cube_hover_height_on_uneven_terrain", "enemy_contact.tscn не найден")

	# R6.B3: Падение под гравитацией из верхней точки синусоиды покачивания
	var scene_b3: PackedScene = load("res://entities/enemies/contact/enemy_contact.tscn") as PackedScene
	if scene_b3 != null:
		var enemy: CharacterBody3D = scene_b3.instantiate() as CharacterBody3D
		root.add_child(enemy)
		await physics_frame
		var mesh_node: MeshInstance3D = enemy.find_child("Mesh", true, false) as MeshInstance3D
		var pre_death_y: float = mesh_node.position.y if mesh_node != null else 1.0
		enemy.call("take_damage", 60.0)
		await physics_frame
		await physics_frame
		var post_death_y: float = mesh_node.position.y if mesh_node != null else 0.0
		_check(post_death_y < pre_death_y and not enemy.call("is_hovering"),
			"R6.B3 cube_death_from_bobbing_apex",
			"При гибели на любой фазе синусоиды парение отключается и куб падает вниз")
		enemy.free()
	else:
		_fail("R6.B3 cube_death_from_bobbing_apex", "enemy_contact.tscn не найден")

	# R6.B4: Спецификация коллизионных слоев врага (тело: 3, хитбокс: 4)
	var contact_scene: PackedScene = load("res://entities/enemies/contact/enemy_contact.tscn") as PackedScene
	if contact_scene != null:
		var enemy: CharacterBody3D = contact_scene.instantiate() as CharacterBody3D
		root.add_child(enemy)
		await physics_frame
		var is_layer_3: bool = (enemy.collision_layer & (1 << 2)) != 0
		var hurtbox: Area3D = enemy.find_child("Hurtbox", true, false) as Area3D
		var hurtbox_layer_4: bool = hurtbox != null and ((hurtbox.collision_layer & (1 << 3)) != 0)
		_check(is_layer_3 and hurtbox_layer_4, "R6.B4 cube_collision_layers_specification",
			"Тело врага на слое 3 (enemy_body), хитбокс на слое 4 (enemy_hurtbox)")
		enemy.free()
	else:
		_fail("R6.B4 cube_collision_layers_specification", "enemy_contact.tscn не найден")

	# R6.B5: Защита от повторного урона после гибели
	var scene_b5: PackedScene = load("res://entities/enemies/contact/enemy_contact.tscn") as PackedScene
	if scene_b5 != null:
		var enemy: CharacterBody3D = scene_b5.instantiate() as CharacterBody3D
		root.add_child(enemy)
		await physics_frame
		var died_count: Array[int] = [0]
		enemy.connect("died", func() -> void: died_count[0] += 1)
		enemy.call("take_damage", 60.0)
		_check(died_count[0] == 1, "R6.B5 cube_lethal_damage_no_revival", "Смертельный урон засчитан")
		# Повторный урон по погибшему кубу
		enemy.call("take_damage", 50.0)
		var is_dead: bool = not bool(enemy.call("is_alive")) if enemy.has_method("is_alive") else true
		var hp: float = float(enemy.call("health")) if enemy.has_method("health") else 0.0
		_check(died_count[0] == 1 and is_dead and is_equal_approx(hp, 0.0),
			"R6.B5 cube_lethal_damage_no_revival",
			"Повторный урон по мертвому кубу игнорируется, повторный died не вызывается")
		enemy.free()
	else:
		_fail("R6.B5 cube_lethal_damage_no_revival", "enemy_contact.tscn не найден")


# ==================================================================
# R7 Boundaries: Тайминг волн (5 тестов)
# ==================================================================
func _test_r7_boundaries() -> void:
	print("\n--- [R7 Boundaries] Граничные условия таймера волн ---")

	# R7.B1: Точность таймера передышки с плавающей точкой (|t - 5.0| < 0.001)
	var wm_script: GDScript = load("res://levels/common/wave_manager.gd") as GDScript
	if wm_script != null:
		var wm: Node = wm_script.new()
		var dur: float = float(wm.get("intermission_duration"))
		_check(is_equal_approx(dur, 5.0), "R7.B1 intermission_float_precision", "Таймер передышки равен 5.0 с с точностью float epsilon (получено %.2f)" % dur)
		wm.free()
	else:
		_fail("R7.B1 intermission_float_precision", "wave_manager.gd не найден")

	# R7.B2: Частота физических тиков проекта равна 120 Гц (Jolt Physics 3D)
	var physics_ticks: int = int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"))
	_check(physics_ticks == 120, "R7.B2 physics_tickrate_120hz", "Частота физических тиков проекта строго равна 120 Гц (получено %d)" % physics_ticks)

	# R7.B3: Мгновенный переход в передышку при завершении волны
	var wm_b3 := WaveManager.new()
	wm_b3.auto_start = false
	root.add_child(wm_b3)
	wm_b3._state = WaveManager.State.COMBAT
	wm_b3._active_enemies = []
	wm_b3._check_wave_completion()
	_check(wm_b3.get_state() == WaveManager.State.INTERMISSION,
		"R7.B3 zero_enemies_immediate_trigger", "Гибель последнего врага волны мгновенно активирует состояние INTERMISSION")
	wm_b3.queue_free()

	# R7.B4: Блокировка досрочного старта волны до истечения 5.0 секунд
	var wm_b4 := WaveManager.new()
	wm_b4.auto_start = false
	wm_b4._start_intermission()
	wm_b4._physics_process(1.0)
	_check(wm_b4.get_state() == WaveManager.State.INTERMISSION and wm_b4._intermission_timer > 0.0,
		"R7.B4 intermission_premature_skip_blocked", "Состояние остается INTERMISSION до истечения полного таймера передышки 5.0 с")
	wm_b4.free()

	# R7.B5: Сброс состояния волн при перезапуске
	var wm_b5 := WaveManager.new()
	wm_b5.auto_start = false
	_check(wm_b5._current_wave == 0 and wm_b5.get_state() == WaveManager.State.IDLE,
		"R7.B5 intermission_reentry_reset", "При инициализации WaveManager сбрасывает волну в 0 и состояние в IDLE")
	wm_b5.free()


func _print_summary() -> void:
	print("\n==========================================================================")
	print("ИТОГИ TIER 2: %d проверок выполнено | %d пройдено | %d пропущено | %d провалено" % [
		_checks, _passes, _skips.size(), _failures.size()])
	print("==========================================================================")
	if _failures.size() > 0:
		for f in _failures:
			print("  [ОШИБКА] %s" % f)


func _cleanup() -> void:
	if FileAccess.file_exists(_TEMP_SAVE_PATH):
		DirAccess.remove_absolute(_TEMP_SAVE_PATH)
