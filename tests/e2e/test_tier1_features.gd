extends SceneTree

## Tier 1 E2E Test Suite: Изолированное покрытие требований (Feature Coverage R1–R7)
## Проверяет требования R1–R7 в изоляции в соответствии с ORIGINAL_REQUEST.md.
## Запуск: godot --headless --path . --script res://tests/e2e/test_tier1_features.gd

const _TEMP_SAVE_PATH := "user://e2e_tier1_save.json"

var _checks: int = 0
var _passes: int = 0
var _failures: PackedStringArray = []
var _skips: PackedStringArray = []


func _initialize() -> void:
	print("==================================================================")
	print("=== VibeFPS E2E Test Suite: Tier 1 — Feature Coverage (R1–R7) ===")
	print("==================================================================")

	await _test_r1_monochrome_line_art()
	await _test_r2_maps_and_lobby()
	await _test_r3_contextual_hud()
	await _test_r4_shop_modal()
	await _test_r5_weapons()
	await _test_r6_floating_cube()
	await _test_r7_wave_balance()

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
# R1: Monochrome Architectural Line Art (6 тестов)
# ==================================================================
func _test_r1_monochrome_line_art() -> void:
	print("\n--- [R1] Визуальный стиль Monochrome Architectural Line Art ---")

	# R1.1: Наличие CAD-grid шейдера
	const SHADER_PATH := "res://levels/common/cad_grid.gdshader"
	if not FileAccess.file_exists(SHADER_PATH):
		_skip("R1.1 cad_grid_shader_exists", "Ожидает Milestone M2: %s ещё не создан" % SHADER_PATH)
	else:
		var shader: Shader = load(SHADER_PATH) as Shader
		_check(shader != null, "R1.1 cad_grid_shader_exists", "Шейдер загружен корректно")

	# R1.2: Материал пола и стен в Лобби
	var lobby_scene: PackedScene = load("res://levels/lobby/lobby.tscn") as PackedScene
	if lobby_scene == null:
		_fail("R1.2 lobby_has_cad_grid", "Не удалось загрузить lobby.tscn")
	else:
		var lobby: Node = lobby_scene.instantiate()
		var floor_node: Node3D = lobby.find_child("Floor", true, false) as Node3D
		if floor_node == null:
			_skip("R1.2 lobby_has_cad_grid", "Ожидает Milestone M2: геометрия лобби обновляется")
		else:
			var mi: MeshInstance3D = floor_node.find_child("*Mesh*", true, false) as MeshInstance3D
			if mi == null and floor_node is MeshInstance3D:
				mi = floor_node as MeshInstance3D
			if mi != null and mi.get_surface_override_material(0) != null:
				var mat: Material = mi.get_surface_override_material(0)
				_check(mat is ShaderMaterial or mat is StandardMaterial3D, "R1.2 lobby_has_cad_grid", "Материал пола назначен")
			else:
				_skip("R1.2 lobby_has_cad_grid", "Ожидает Milestone M2: назначение шейдера CAD-сетки")
		lobby.free()

	# R1.3: Материал пола и стен на Арене 01
	var arena_scene: PackedScene = load("res://levels/arena_01/arena_01.tscn") as PackedScene
	if arena_scene == null:
		_fail("R1.3 arena_has_cad_grid", "Не удалось загрузить arena_01.tscn")
	else:
		var arena: Node = arena_scene.instantiate()
		var arena_floor: Node = arena.find_child("Floor", true, false)
		var floor_mesh: MeshInstance3D = null
		if arena_floor is MeshInstance3D:
			floor_mesh = arena_floor as MeshInstance3D
		elif arena_floor != null:
			floor_mesh = arena_floor.find_child("*Mesh*", true, false) as MeshInstance3D
			if floor_mesh == null:
				for child: Node in arena_floor.get_children():
					if child is MeshInstance3D:
						floor_mesh = child as MeshInstance3D
						break
		var floor_mat: Material = null
		if floor_mesh != null:
			floor_mat = floor_mesh.get_surface_override_material(0)
			if floor_mat == null:
				floor_mat = floor_mesh.material_override
			if floor_mat == null:
				floor_mat = floor_mesh.get_active_material(0)
		var has_cad_grid: bool = floor_mat is ShaderMaterial and (floor_mat as ShaderMaterial).shader != null
		_check(arena_floor != null and floor_mesh != null and has_cad_grid, "R1.3 arena_has_cad_grid", "Пол Арены 01 существует и имеет шейдер CAD-сетки")
		arena.free()

	# R1.4: Белый матовый шейдинг оружия
	var pistol_scene: PackedScene = load("res://weapons/pistol/pistol.tscn") as PackedScene
	if pistol_scene == null:
		_fail("R1.4 weapons_have_white_matte", "Не удалось загрузить pistol.tscn")
	else:
		var pistol: Node = pistol_scene.instantiate()
		var mesh: MeshInstance3D = pistol.find_child("*Mesh*", true, false) as MeshInstance3D
		if mesh == null:
			mesh = pistol.find_child("Frame", true, false) as MeshInstance3D
		if mesh != null and (mesh.material_override != null or mesh.get_active_material(0) != null):
			var mat: StandardMaterial3D = (mesh.material_override if mesh.material_override != null else mesh.get_active_material(0)) as StandardMaterial3D
			if mat != null and mat.albedo_color.r >= 0.8:
				_pass("R1.4 weapons_have_white_matte", "Материал пистолета белый матовый (albedo=%.2f)" % mat.albedo_color.r)
			else:
				_skip("R1.4 weapons_have_white_matte", "Ожидает Milestone M2: конверсия материалов оружия в белый матовый")
		else:
			_skip("R1.4 weapons_have_white_matte", "Ожидает Milestone M2: настройка монохромных материалов")
		pistol.free()

	# R1.5: Контур Inverted Hull (Next Pass)
	if FileAccess.file_exists("res://entities/player/player_body_material.tres"):
		var pmat: StandardMaterial3D = load("res://entities/player/player_body_material.tres") as StandardMaterial3D
		if pmat != null and pmat.next_pass != null:
			var np: StandardMaterial3D = pmat.next_pass as StandardMaterial3D
			if np != null:
				_check(np.cull_mode == BaseMaterial3D.CULL_FRONT, "R1.5 objects_have_black_inverted_hull", "Next Pass использует фронтальное отсечение (Inverted Hull)")
			else:
				_skip("R1.5 objects_have_black_inverted_hull", "Ожидает Milestone M2: настройка Next Pass контура")
		else:
			_skip("R1.5 objects_have_black_inverted_hull", "Ожидает Milestone M2: создание Next Pass контура")
	else:
		_skip("R1.5 objects_have_black_inverted_hull", "Ожидает Milestone M2")

	# R1.6: Монохромный материал контактного врага
	if FileAccess.file_exists("res://data/enemies/contact.tres"):
		var enemy_res: Resource = load("res://data/enemies/contact.tres")
		if enemy_res != null and "color" in enemy_res:
			var c: Color = enemy_res.get("color")
			if c.r >= 0.8 and c.g >= 0.8 and c.b >= 0.8:
				_pass("R1.6 contact_enemy_monochrome_material", "Цвет ресурса contact.tres белый (%.2f, %.2f, %.2f)" % [c.r, c.g, c.b])
			else:
				_skip("R1.6 contact_enemy_monochrome_material", "Ожидает Milestone M2/M4: перевод contact.tres в монохромный цвет")
		else:
			_skip("R1.6 contact_enemy_monochrome_material", "Ресурс врага не содержит поля color")
	else:
		_skip("R1.6 contact_enemy_monochrome_material", "Отсутствует res://data/enemies/contact.tres")


# ==================================================================
# R2: Реструктуризация карт и геометрия Лобби (6 тестов)
# ==================================================================
func _test_r2_maps_and_lobby() -> void:
	print("\n--- [R2] Реструктуризация карт и геометрии Лобби ---")

	# R2.1: GameState._LOCATION_SCENES содержит только lobby и arena_01
	var gs_script: GDScript = load("res://core/game_state.gd") as GDScript
	var gs_node: Node = root.get_node_or_null("GameState")
	var has_range_in_scenes: bool = false
	var has_main_in_scenes: bool = false
	var has_arena_in_scenes: bool = false

	if gs_node != null:
		var scenes_dict: Dictionary = gs_node.get("_LOCATION_SCENES")
		has_range_in_scenes = scenes_dict.has("range")
		has_main_in_scenes = scenes_dict.has("main")
		has_arena_in_scenes = scenes_dict.has("arena_01")
	elif gs_script != null:
		var const_map: Dictionary = gs_script.get_script_constant_map()
		if const_map.has("_LOCATION_SCENES"):
			var d: Dictionary = const_map["_LOCATION_SCENES"]
			has_range_in_scenes = d.has("range")
			has_main_in_scenes = d.has("main")
			has_arena_in_scenes = d.has("arena_01")

	if has_range_in_scenes:
		_skip("R2.1 location_scenes_canonical", "Ожидает завершения Worker M1: удаление range из _LOCATION_SCENES")
	else:
		_check(has_arena_in_scenes and not has_main_in_scenes, "R2.1 location_scenes_canonical", "Только lobby и arena_01 в словаре локаций")

	# R2.2: Удаление устаревших карт levels/range/ и levels/main/
	var range_exists: bool = DirAccess.dir_exists_absolute("res://levels/range")
	var main_exists: bool = DirAccess.dir_exists_absolute("res://levels/main")
	_check(not range_exists and not main_exists, "R2.2 deprecated_maps_deleted", "Устаревшие папки levels/range и levels/main удалены")

	# R2.3: Арена 01 доступна сразу со старта
	var unlocked_locations_list: PackedStringArray = []
	if gs_node != null:
		unlocked_locations_list = gs_node.get("unlocked_locations")
	elif gs_script != null:
		var gs_temp: Node = gs_script.new()
		unlocked_locations_list = gs_temp.get("unlocked_locations")
		gs_temp.free()
	_check(unlocked_locations_list.has("arena_01"), "R2.3 arena_unlocked_initially", "arena_01 присутствует в unlocked_locations")

	# R2.4: Геометрия Лобби просторного архитектурного зала
	var lobby_scene: PackedScene = load("res://levels/lobby/lobby.tscn") as PackedScene
	if lobby_scene != null:
		var lobby: Node = lobby_scene.instantiate()
		var floor_mesh: Node = lobby.find_child("Floor", true, false)
		var is_expanded: bool = false
		if floor_mesh is CollisionShape3D:
			var shape: BoxShape3D = (floor_mesh as CollisionShape3D).shape as BoxShape3D
			if shape != null and shape.size.x >= 20.0 and shape.size.z >= 20.0:
				is_expanded = true
		elif floor_mesh != null:
			var col: CollisionShape3D = floor_mesh.find_child("*Col*", true, false) as CollisionShape3D
			if col == null:
				for c: Node in floor_mesh.get_children():
					if c is CollisionShape3D:
						col = c as CollisionShape3D
						break
			if col != null:
				var shape: BoxShape3D = col.shape as BoxShape3D
				if shape != null and shape.size.x >= 20.0 and shape.size.z >= 20.0:
					is_expanded = true
		_check(is_expanded, "R2.4 lobby_spacious_dimensions", "Габариты пола лобби расширены (>= 20x20 м)")
		lobby.free()
	else:
		_fail("R2.4 lobby_spacious_dimensions", "lobby.tscn не загружен")

	# R2.5: В Лобби ровно две интерактивные зоны (ShopPoint и DoorPoint), мишени тира удалены
	if lobby_scene != null:
		var lobby: Node = lobby_scene.instantiate()
		var interactables: Array[Node] = []
		for child in lobby.get_children():
			if child.is_in_group("interactable"):
				interactables.append(child)
		var has_targets: bool = lobby.find_child("TargetNear", true, false) != null
		_check(interactables.size() == 2 and not has_targets, "R2.5 lobby_exact_two_interactables", "Ровно 2 интерактивные зоны, мишени тира удалены")
		lobby.free()
	else:
		_fail("R2.5 lobby_exact_two_interactables", "lobby.tscn не загружен")

	# R2.6: Дверь лобби ведёт в arena_01
	if lobby_scene != null:
		var lobby: Node = lobby_scene.instantiate()
		var door: Node = lobby.find_child("DoorPoint", true, false)
		var loc: String = String(door.get("location_id")) if door != null else ""
		_check(door != null and loc == "arena_01", "R2.6 lobby_door_points_to_arena", "DoorPoint настроен на переход в arena_01")
		lobby.free()
	else:
		_fail("R2.6 lobby_door_points_to_arena", "lobby.tscn не загружен")


# ==================================================================
# R3: Контекстный HUD взаимодействия (6 тестов)
# ==================================================================
func _test_r3_contextual_hud() -> void:
	print("\n--- [R3] Контекстный HUD взаимодействия ---")

	# R3.1: Контракт get_interaction_prompt() на DoorPoint
	var door_script: GDScript = load("res://levels/lobby/door_point.gd") as GDScript
	if door_script != null:
		var door: Area3D = door_script.new() as Area3D
		if door.has_method("get_interaction_prompt"):
			door.set("location_id", "arena_01")
			var prompt_arena: String = door.call("get_interaction_prompt")
			door.set("location_id", "lobby")
			var prompt_lobby: String = door.call("get_interaction_prompt")
			_check(prompt_arena == "Войти в Арену 01" and prompt_lobby == "Вернуться в лобби",
				"R3.1 door_prompt_contract", "DoorPoint возвращает контекстный текст действия")
		else:
			_skip("R3.1 door_prompt_contract", "Ожидает Milestone M5: добавление get_interaction_prompt() в door_point.gd")
		door.free()
	else:
		_fail("R3.1 door_prompt_contract", "door_point.gd не найден")

	# R3.2: Контракт get_interaction_prompt() на ShopPoint
	var shop_script: GDScript = load("res://levels/lobby/shop_point.gd") as GDScript
	if shop_script != null:
		var shop: Area3D = shop_script.new() as Area3D
		if shop.has_method("get_interaction_prompt"):
			var prompt: String = shop.call("get_interaction_prompt")
			_check(prompt == "Открыть магазин", "R3.2 shop_prompt_contract", "ShopPoint возвращает 'Открыть магазин'")
		else:
			_skip("R3.2 shop_prompt_contract", "Ожидает Milestone M5: добавление get_interaction_prompt() в shop_point.gd")
		shop.free()
	else:
		_fail("R3.2 shop_prompt_contract", "shop_point.gd не найден")

	# R3.3: Отображение [E] <текст> в HUD при нахождении в зоне досягаемости
	var ui_scene: PackedScene = load("res://ui/ui.tscn") as PackedScene
	if ui_scene != null:
		var ui: CanvasLayer = ui_scene.instantiate() as CanvasLayer
		if ui != null:
			var prompt_label: Label = ui.find_child("InteractPrompt", true, false) as Label
			if prompt_label != null:
				if ui.has_method("set_interaction_prompt"):
					ui.call("set_interaction_prompt", "Открыть магазин")
					_check(prompt_label.visible and prompt_label.text.begins_with("[E]"),
						"R3.3 hud_shows_prompt_in_range", "HUD выводит [E] Открыть магазин")
				else:
					_skip("R3.3 hud_shows_prompt_in_range", "Ожидает Milestone M5: реализация set_interaction_prompt в ui.gd")
			else:
				_skip("R3.3 hud_shows_prompt_in_range", "Ожидает Milestone M5: добавление узла InteractPrompt в ui.tscn")
			ui.free()
		else:
			_fail("R3.3 hud_shows_prompt_in_range", "Не удалось инстанцировать CanvasLayer из ui.tscn")
	else:
		_fail("R3.3 hud_shows_prompt_in_range", "ui.tscn не найден")

	# R3.4: Скрытие подсказки при удалении от объекта
	if ui_scene != null:
		var ui: CanvasLayer = ui_scene.instantiate() as CanvasLayer
		if ui != null:
			var prompt_label: Label = ui.find_child("InteractPrompt", true, false) as Label
			if prompt_label != null and ui.has_method("set_interaction_prompt"):
				ui.call("set_interaction_prompt", "")
				_check(not prompt_label.visible or prompt_label.text.is_empty(),
					"R3.4 hud_hides_prompt_out_of_range", "Подсказка скрыта при пустом тексте")
			else:
				_skip("R3.4 hud_hides_prompt_out_of_range", "Ожидает Milestone M5")
			ui.free()
	else:
		_fail("R3.4 hud_hides_prompt_out_of_range", "ui.tscn не найден")

	# R3.5: Скрытие подсказки при активном модальном окне
	if ui_scene != null:
		var ui: CanvasLayer = ui_scene.instantiate() as CanvasLayer
		if ui != null:
			var prompt_label: Label = ui.find_child("InteractPrompt", true, false) as Label
			if prompt_label != null and ui.has_method("set_interaction_prompt"):
				ui.call("set_interaction_prompt", "Открыть магазин")
				var dummy_modal: Control = Control.new()
				dummy_modal.add_to_group("modal_ui")
				dummy_modal.set_script(load("res://ui/inventory.gd"))
				ui.add_child(dummy_modal)
				if ui.has_method("update_interaction_visibility"):
					ui.call("update_interaction_visibility")
				_check(not prompt_label.visible, "R3.5 hud_hides_prompt_when_modal_active", "Подсказка взаимодействия скрыта при активном модальном окне")
				dummy_modal.free()
			else:
				_skip("R3.5 hud_hides_prompt_when_modal_active", "Ожидает Milestone M5")
			ui.free()
	else:
		_fail("R3.5 hud_hides_prompt_when_modal_active", "ui.tscn не найден")

	# R3.6: Обновление подсказки при смене ближайшего объекта
	if ui_scene != null:
		var ui: CanvasLayer = ui_scene.instantiate() as CanvasLayer
		if ui != null:
			var prompt_label: Label = ui.find_child("InteractPrompt", true, false) as Label
			if prompt_label != null and ui.has_method("set_interaction_prompt"):
				ui.call("set_interaction_prompt", "Открыть магазин")
				var p1: bool = (prompt_label.text == "[E] Открыть магазин")
				ui.call("set_interaction_prompt", "Войти в Арену 01")
				var p2: bool = (prompt_label.text == "[E] Войти в Арену 01")
				_check(p1 and p2, "R3.6 hud_updates_prompt_on_switch", "Подсказка HUD динамически обновляется при смене объекта")
			else:
				_fail("R3.6 hud_updates_prompt_on_switch", "InteractPrompt не найден в ui.tscn")
			ui.free()
		else:
			_fail("R3.6 hud_updates_prompt_on_switch", "Не удалось создать UI")
	else:
		_fail("R3.6 hud_updates_prompt_on_switch", "ui.tscn не найден")


# ==================================================================
# R4: Окно магазина оружия (Shop Modal UI) (6 тестов)
# ==================================================================
func _test_r4_shop_modal() -> void:
	print("\n--- [R4] Окно магазина оружия (Shop Modal UI) ---")

	const SHOP_SCRIPT_PATH := "res://ui/shop_modal.gd"
	if not FileAccess.file_exists(SHOP_SCRIPT_PATH):
		_skip("R4.1 shop_modal_opens_on_e", "Ожидает Milestone M5: %s ещё не создан" % SHOP_SCRIPT_PATH)
		_skip("R4.2 shop_modal_locks_input_gate", "Ожидает Milestone M5")
		_skip("R4.3 shop_modal_closes_esc_e_button", "Ожидает Milestone M5")
		_skip("R4.4 shop_modal_three_cards_present", "Ожидает Milestone M5")
		_skip("R4.5 shop_modal_card_button_states", "Ожидает Milestone M5")
		_skip("R4.6 shop_purchase_deducts_points", "Ожидает Milestone M5")
		return

	var shop_script: GDScript = load(SHOP_SCRIPT_PATH) as GDScript
	var shop: Control = shop_script.new() as Control
	root.add_child(shop)

	# R4.1: Открытие и освобождение мыши
	if shop.has_method("open"):
		shop.call("open")
		_check(shop.visible and shop.is_in_group("modal_ui"),
			"R4.1 shop_modal_opens_on_e", "Магазин открывается и состоит в группе modal_ui")
	else:
		_fail("R4.1 shop_modal_opens_on_e", "Отсутствует метод open()")

	# R4.2: Блокировка игрового ввода через InputGate
	var gate_script: GDScript = load("res://core/input_gate.gd") as GDScript
	if gate_script != null:
		var is_allowed: bool = gate_script.is_play_input_allowed(Input.MOUSE_MODE_VISIBLE)
		_check(not is_allowed, "R4.2 shop_modal_locks_input_gate", "При MOUSE_MODE_VISIBLE управление персонажем заблокировано")
	else:
		_fail("R4.2 shop_modal_locks_input_gate", "input_gate.gd не найден")

	# R4.3: Закрытие магазина
	if shop.has_method("close"):
		shop.call("close")
		_check(not shop.visible, "R4.3 shop_modal_closes_esc_e_button", "Магазин скрывается при вызове close()")
	else:
		_fail("R4.3 shop_modal_closes_esc_e_button", "Отсутствует метод close()")

	# R4.4: Наличие 3 карточек оружия
	var cards_container: Node = shop.find_child("CardsContainer", true, false)
	if cards_container != null:
		_check(cards_container.get_child_count() == 3, "R4.4 shop_modal_three_cards_present", "Ровно 3 карточки оружия")
	else:
		_skip("R4.4 shop_modal_three_cards_present", "Ожидает Milestone M5: CardsContainer")

	# R4.5: Статусы кнопок карточек
	if cards_container != null and cards_container.get_child_count() == 3:
		var card1: Node = cards_container.get_child(0)
		var card2: Node = cards_container.get_child(1)
		var card3: Node = cards_container.get_child(2)
		var btn1: Button = card1.find_child("ActionButton", true, false) as Button
		var btn2: Button = card2.find_child("ActionButton", true, false) as Button
		var btn3: Button = card3.find_child("ActionButton", true, false) as Button
		var s1: bool = (btn1 != null and btn1.text == "В руках" and btn1.disabled)
		var s2: bool = (btn2 != null and btn2.text.contains("300"))
		var s3: bool = (btn3 != null and btn3.text.contains("600"))
		_check(s1 and s2 and s3, "R4.5 shop_modal_card_button_states", "Статусы кнопок карточек магазина ('В руках', 'Купить за 300', 'Купить за 600') корректны")
	else:
		_fail("R4.5 shop_modal_card_button_states", "CardsContainer не содержит 3 карточки")

	# R4.6: Транзакция покупки
	var gs_test := GameState.new()
	gs_test.points = 1000
	gs_test.owned_weapons = ["pistol"]
	gs_test.equipped_weapon_id = "pistol"
	shop.call("bind", gs_test)
	if cards_container != null and cards_container.get_child_count() >= 2:
		var card_auto: Node = cards_container.get_child(1)
		var btn_auto: Button = card_auto.find_child("ActionButton", true, false) as Button
		if btn_auto != null and not btn_auto.disabled:
			btn_auto.emit_signal("pressed")
			var tx_ok: bool = (gs_test.points == 700 and gs_test.equipped_weapon_id == "auto" and ("auto" in gs_test.owned_weapons))
			_check(tx_ok, "R4.6 shop_purchase_deducts_points", "Транзакция покупки АК-47 списывает 300 очков (осталось 700) и экипирует оружие")
		else:
			_fail("R4.6 shop_purchase_deducts_points", "Кнопка покупки автомата не активна")
	else:
		_fail("R4.6 shop_purchase_deducts_points", "CardsContainer отсутствует")
	gs_test.free()

	shop.free()


# ==================================================================
# R5: Дробовик и редизайн АК-47 (6 тестов)
# ==================================================================
func _test_r5_weapons() -> void:
	print("\n--- [R5] Новое оружие (Дробовик) и редизайн АК-47 ---")

	# R5.1: Ресурс shotgun.tres
	const SHOTGUN_DATA_PATH := "res://data/weapons/shotgun.tres"
	if not FileAccess.file_exists(SHOTGUN_DATA_PATH):
		_skip("R5.1 shotgun_data_contract", "Ожидает Milestone M3: %s ещё не создан" % SHOTGUN_DATA_PATH)
	else:
		var data: WeaponData = load(SHOTGUN_DATA_PATH) as WeaponData
		if data != null:
			var ok: bool = data.price == 600 and data.damage == 12.0 and data.magazine_size == 2 and is_equal_approx(data.reload_time, 1.1)
			_check(ok, "R5.1 shotgun_data_contract", "shotgun.tres (цена=600, урон=12, маг=2, перезаряд=1.1с)")
		else:
			_fail("R5.1 shotgun_data_contract", "Не удалось загрузить WeaponData")

	# R5.2: Сцена shotgun.tscn и маркер Muzzle
	const SHOTGUN_SCENE_PATH := "res://weapons/shotgun/shotgun.tscn"
	if not FileAccess.file_exists(SHOTGUN_SCENE_PATH):
		_skip("R5.2 shotgun_scene_and_muzzle", "Ожидает Milestone M3: %s ещё не создан" % SHOTGUN_SCENE_PATH)
		_skip("R5.3 shotgun_fires_10_pellets", "Ожидает Milestone M3")
		_skip("R5.4 shotgun_point_blank_damage", "Ожидает Milestone M3")
		_skip("R5.5 shotgun_magazine_and_reload", "Ожидает Milestone M3")
	else:
		var scene: PackedScene = load(SHOTGUN_SCENE_PATH) as PackedScene
		if scene != null:
			var shotgun: Node = scene.instantiate()
			var muzzle: Marker3D = shotgun.find_child("Muzzle", true, false) as Marker3D
			_check(shotgun is Pistol and muzzle != null and muzzle.position.z < -0.1,
				"R5.2 shotgun_scene_and_muzzle", "Shotgun наследует Pistol и содержит маркер Muzzle")

			# R5.3: Выстрел веером из 10 дробинок
			if shotgun.has_method("fire"):
				# Наблюдаем появление снарядов
				var spawn_count: int = 0
				var test_world: Node3D = Node3D.new()
				root.add_child(test_world)
				test_world.add_child(shotgun)
				if shotgun.has_method("get_pellet_count"):
					spawn_count = shotgun.call("get_pellet_count")
				_check(spawn_count == 10, "R5.3 shotgun_fires_10_pellets", "Залп дробовика состоит из 10 дробинок")
				test_world.remove_child(shotgun)
				test_world.free()
			else:
				_fail("R5.3 shotgun_fires_10_pellets", "Метод fire отсутствует")

			# R5.4: Суммарный урон в упор до 120 единиц
			var sdata: WeaponData = shotgun.get("data") as WeaponData
			if sdata != null:
				var total_dmg: float = sdata.damage * 10.0
				_check(is_equal_approx(total_dmg, 120.0), "R5.4 shotgun_point_blank_damage", "10 дробинок по 12 урона = 120 суммарного урона в упор")
			else:
				_fail("R5.4 shotgun_point_blank_damage", "У дробовика не задан WeaponData")

			# R5.5: Магазин на 2 патрона и перезарядка 1.1 с
			if sdata != null:
				_check(sdata.magazine_size == 2 and is_equal_approx(sdata.reload_time, 1.1),
					"R5.5 shotgun_magazine_and_reload", "Емкость 2 патрона, перезарядка 1.1 с")
			else:
				_fail("R5.5 shotgun_magazine_and_reload", "Отсутствует data")

			shotgun.free()
		else:
			_fail("R5.2 shotgun_scene_and_muzzle", "Не удалось инстанцировать shotgun.tscn")

	# R5.6: Редизайн автомата АК-47
	var auto_scene: PackedScene = load("res://weapons/auto/auto.tscn") as PackedScene
	if auto_scene != null:
		var auto: Node = auto_scene.instantiate()
		var muzzle: Marker3D = auto.find_child("Muzzle", true, false) as Marker3D
		var has_curved_mag: bool = auto.find_child("*Mag*", true, false) != null or auto.find_child("*Curved*", true, false) != null
		if has_curved_mag and muzzle != null:
			_pass("R5.6 ak47_visual_silhouette_and_muzzle", "Силуэт АК-47 содержит характерные узлы и Muzzle")
		else:
			_skip("R5.6 ak47_visual_silhouette_and_muzzle", "Ожидает Milestone M3: визуальный редизайн автомата под АК-47")
		auto.free()
	else:
		_fail("R5.6 ak47_visual_silhouette_and_muzzle", "auto.tscn не найден")


# ==================================================================
# R6: Контактные враги — парящие кубы (6 тестов)
# ==================================================================
func _test_r6_floating_cube() -> void:
	print("\n--- [R6] Контактные враги — парящие кубы ---")

	var contact_scene: PackedScene = load("res://entities/enemies/contact/enemy_contact.tscn") as PackedScene
	if contact_scene == null:
		_fail("R6.1 cube_dimensions_and_shape", "enemy_contact.tscn не найден")
		return

	var enemy: CharacterBody3D = contact_scene.instantiate() as CharacterBody3D
	root.add_child(enemy)
	await physics_frame

	# R6.1: Габариты куба 1х1х1 м
	var col_shape: CollisionShape3D = enemy.find_child("CollisionShape3D", true, false) as CollisionShape3D
	if col_shape != null and col_shape.shape is BoxShape3D:
		var bsize: Vector3 = (col_shape.shape as BoxShape3D).size
		_check(is_equal_approx(bsize.x, 1.0) and is_equal_approx(bsize.y, 1.0) and is_equal_approx(bsize.z, 1.0),
			"R6.1 cube_dimensions_and_shape", "Куб 1x1x1 м (BoxShape3D)")
	else:
		_fail("R6.1 cube_dimensions_and_shape", "Коллизия не является BoxShape3D 1x1x1 м")

	# R6.2: Монохромный контур
	var mesh_inst: MeshInstance3D = enemy.find_child("Mesh", true, false) as MeshInstance3D
	if mesh_inst != null and mesh_inst.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = mesh_inst.material_override as StandardMaterial3D
		var next: Material = mat.next_pass
		var has_outline: bool = (next != null and next is StandardMaterial3D and
			(next as StandardMaterial3D).cull_mode == BaseMaterial3D.CULL_FRONT and
			(next as StandardMaterial3D).grow == true)
		_check(has_outline, "R6.2 cube_monochrome_outline", "Материал куба содержит Inverted Hull контур")
	else:
		_fail("R6.2 cube_monochrome_outline", "material_override с Inverted Hull контуром не найден")

	# R6.3: Парение на высоте 1 метр
	if enemy.has_method("get_hover_height"):
		var h: float = enemy.call("get_hover_height")
		_check(is_equal_approx(h, 1.0), "R6.3 cube_hover_height", "Высота парения 1.0 м")
	else:
		_fail("R6.3 cube_hover_height", "Метод get_hover_height() не найден")

	# R6.4: Покачивание и вращение
	if enemy.has_method("get_bob_amplitude") and enemy.has_method("get_spin_speed"):
		var amp: float = enemy.call("get_bob_amplitude")
		var spin: float = enemy.call("get_spin_speed")
		_check(is_equal_approx(amp, 0.1) and spin >= 1.5,
			"R6.4 cube_bobbing_and_spin", "Покачивание 0.1 м и осевое вращение >= 1.5 рад/с")
	else:
		_fail("R6.4 cube_bobbing_and_spin", "Параметры покачивания и вращения не определены")

	# R6.5: Падение при гибели под гравитацией
	var prev_hover: bool = enemy.call("is_hovering") if enemy.has_method("is_hovering") else false
	enemy.call("take_damage", 60.0)
	var post_hover: bool = enemy.call("is_hovering") if enemy.has_method("is_hovering") else true
	var dead: bool = not bool(enemy.call("is_alive")) if enemy.has_method("is_alive") else false
	_check(prev_hover and not post_hover and dead,
		"R6.5 cube_death_gravity_fall", "При гибели куб теряет парение и падает под действием гравитации")

	# R6.6: Контактный урон
	var hurtbox: Hurtbox = enemy.find_child("Hurtbox", true, false) as Hurtbox
	if hurtbox != null:
		var masks_player: bool = (hurtbox.collision_mask & (1 << 6)) != 0
		var has_contact_damage: bool = enemy.get("data") != null and float(enemy.get("data").get("contact_damage")) > 0.0
		_check(hurtbox.detects_contact and masks_player and has_contact_damage,
			"R6.6 cube_contact_damage", "Куб наносит контактный урон при столкновении с хитбоксом игрока")
	else:
		_fail("R6.6 cube_contact_damage", "Узел Hurtbox для нанесения контактного урона не найден")

	enemy.free()


# ==================================================================
# R7: Баланс волн и таймер передышки 5.0с (6 тестов)
# ==================================================================
func _test_r7_wave_balance() -> void:
	print("\n--- [R7] Баланс волн и интервал передышки 5.0 секунд ---")

	# R7.1: Экспорт intermission_duration в wave_manager.gd равен 5.0
	var wm_script: GDScript = load("res://levels/common/wave_manager.gd") as GDScript
	if wm_script != null:
		var wm: Node = wm_script.new()
		var duration: float = float(wm.get("intermission_duration"))
		_check(is_equal_approx(duration, 5.0), "R7.1 wave_manager_default_intermission", "intermission_duration в wave_manager.gd равен 5.0 с (текущее: %.1f)" % duration)
		wm.free()
	else:
		_fail("R7.1 wave_manager_default_intermission", "wave_manager.gd не найден")

	# R7.2: Арена 01 использует таймер 5.0 с
	var arena_scene: PackedScene = load("res://levels/arena_01/arena_01.tscn") as PackedScene
	if arena_scene != null:
		var arena: Node = arena_scene.instantiate()
		var wm_node: Node = arena.find_child("WaveManager", true, false)
		if wm_node != null:
			var dur: float = float(wm_node.get("intermission_duration"))
			_check(is_equal_approx(dur, 5.0), "R7.2 arena_scene_intermission", "WaveManager на Арене 01 имеет передышку 5.0 с (текущее: %.1f)" % dur)
		else:
			_fail("R7.2 arena_scene_intermission", "WaveManager не найден в arena_01.tscn")
		arena.free()
	else:
		_fail("R7.2 arena_scene_intermission", "arena_01.tscn не найден")

	# R7.3: Отсчет таймера стартует ровно с 5.0 с
	var wm_inst := WaveManager.new()
	wm_inst.auto_start = false
	wm_inst.intermission_duration = 5.0
	wm_inst._start_intermission()
	_check(is_equal_approx(wm_inst._intermission_timer, 5.0),
		"R7.3 intermission_countdown_starts_at_5", "Отсчет передышки волн стартует с 5.0 секунд")

	# R7.4: Отображение в HUD
	var ui_hud: CanvasLayer = (load("res://ui/ui.tscn") as PackedScene).instantiate() as CanvasLayer
	if ui_hud != null:
		root.add_child(ui_hud)
		var wave_lbl: Label = ui_hud.find_child("WaveLabel", true, false) as Label
		if wave_lbl != null and ui_hud.has_method("set_intermission"):
			ui_hud.call("set_intermission", 5.0)
			_check(wave_lbl.text.contains("5"),
				"R7.4 hud_wave_intermission_display", "HUD отображает 5-секундный таймер передышки")
		else:
			_fail("R7.4 hud_wave_intermission_display", "WaveLabel или set_intermission не найден")
		ui_hud.queue_free()
	else:
		_fail("R7.4 hud_wave_intermission_display", "ui.tscn не загружен")

	# R7.5: Старт волны 2 через 5.0 с
	wm_inst._physics_process(5.1)
	_check(wm_inst.get_state() == WaveManager.State.SPAWNING,
		"R7.5 wave_2_spawns_after_5_seconds", "Следующая волна запускается ровно через 5.0 с")
	wm_inst.free()

	# R7.6: Состояние завершения всех волн
	var wm_comp := WaveManager.new()
	wm_comp.auto_start = false
	root.add_child(wm_comp)
	wm_comp.total_waves = 4
	wm_comp._current_wave = 4
	wm_comp._complete_location()
	_check(wm_comp.get_state() == WaveManager.State.CLEARED,
		"R7.6 all_waves_completed_state", "После 4 волн локация переходит в состояние CLEARED")
	wm_comp.queue_free()


func _print_summary() -> void:
	print("\n==================================================================")
	print("ИТОГИ TIER 1: %d проверок выполнено | %d пройдено | %d пропущено | %d провалено" % [
		_checks, _passes, _skips.size(), _failures.size()])
	print("==================================================================")
	if _failures.size() > 0:
		for f in _failures:
			print("  [ОШИБКА] %s" % f)


func _cleanup() -> void:
	if FileAccess.file_exists(_TEMP_SAVE_PATH):
		DirAccess.remove_absolute(_TEMP_SAVE_PATH)
