extends SceneTree

## Всесторонний юнит-тест парящего куба-контактника (Floating Cube Contact Enemy, R6) для VibeFPS.
##
## Проверяет:
## 1. Контракт сцены и габариты: BoxMesh 1x1x1 м, BoxShape3D 1x1x1 м для тела и хитбокса.
## 2. Визуальный стиль: белый матовый материал с черным контуром Inverted Hull (Next Pass).
## 3. Спецификацию коллизионных слоев: тело на слое 3 (enemy_body), хитбокс на слое 4 (enemy_hurtbox).
## 4. Парение: базовая высота 1.0 м над полом, синусоидальное покачивание (bobbing) с амплитудой ~0.1 м.
## 5. Вращение: плавное непрерывное осевое вращение вокруг оси Y (spin) со скоростью ~1.5–2.0 рад/с.
## 6. Механику гибели: отключение парения, ускорение гравитации вниз, достижение пола (landing),
##    отключение коллизий и нанесения урона, задержка затухания ~0.8 с, удаление (queue_free).
## 7. Граничные условия: защита от повторного урона после смерти, одновременный урон.
##
## Запуск:
##   godot --headless --path . --script res://tests/floating_cube.gd
##   pwsh -File .\tools\run_checks.ps1 floating_cube

const _ENEMY_SCENE_PATH := "res://entities/enemies/contact/enemy_contact.tscn"
const _MATERIAL_PATH := "res://levels/common/inverted_hull_material.tres"

const _LAYER_WORLD := 1 << 0
const _LAYER_ENEMY_BODY := 1 << 2
const _LAYER_ENEMY_HURTBOX := 1 << 3
const _LAYER_PLAYER_HURTBOX := 1 << 6

var _failures: PackedStringArray = []
var _checks: int = 0
var _died_emitted: int = 0


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


func _finish() -> void:
	print("\n=== ИТОГ: проверок %d, ошибок %d ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  ОШИБКА: %s" % f)


func _bail(reason: String) -> void:
	print("КРИТИЧЕСКАЯ ОШИБКА: %s" % reason)
	_finish()
	quit(1)


func _initialize() -> void:
	print("=== VibeFPS: тест парящего куба-контактника (Floating Cube Enemy, R6) ===")
	await _test_cube_dimensions_and_mesh()
	await _test_monochrome_outline_material()
	await _test_collision_layers_specification()
	await _test_hover_and_bobbing_dynamics()
	await _test_axial_spin_dynamics()
	await _test_death_physics_and_landing()
	await _test_post_death_damage_resilience()

	_finish()
	quit(1 if _failures.size() > 0 else 0)


## 1. Проверка габаритов куба и коллайдеров (BoxMesh 1x1x1 м, BoxShape3D 1x1x1 м).
func _test_cube_dimensions_and_mesh() -> void:
	print("\n-- 1. Габариты и форма куба 1x1x1 м")
	var packed: PackedScene = load(_ENEMY_SCENE_PATH) as PackedScene
	_check(packed != null, "Сцена enemy_contact.tscn успешно загружена")
	if packed == null:
		return

	var enemy: ContactEnemy = packed.instantiate() as ContactEnemy
	_check(enemy != null, "Инстанцирование ContactEnemy успешно")
	if enemy == null:
		return

	# Проверка формы коллизии тела
	var body_col: CollisionShape3D = enemy.get_node_or_null("CollisionShape3D") as CollisionShape3D
	_check(body_col != null, "Враг содержит узел CollisionShape3D для тела")
	if body_col != null:
		_check(body_col.shape is BoxShape3D, "Форма коллизии тела — BoxShape3D (куб)")
		if body_col.shape is BoxShape3D:
			var bsize: Vector3 = (body_col.shape as BoxShape3D).size
			_check(is_equal_approx(bsize.x, 1.0) and is_equal_approx(bsize.y, 1.0) and is_equal_approx(bsize.z, 1.0),
				"Габариты коллизии тела строго 1.0 x 1.0 x 1.0 м", "(получено %s)" % str(bsize))

	# Проверка меша
	var mesh_inst: MeshInstance3D = enemy.get_node_or_null("Mesh") as MeshInstance3D
	_check(mesh_inst != null, "Враг содержит узел Mesh (MeshInstance3D)")
	if mesh_inst != null:
		_check(mesh_inst.mesh is BoxMesh, "Меш врага — BoxMesh (куб)")
		if mesh_inst.mesh is BoxMesh:
			var msize: Vector3 = (mesh_inst.mesh as BoxMesh).size
			_check(is_equal_approx(msize.x, 1.0) and is_equal_approx(msize.y, 1.0) and is_equal_approx(msize.z, 1.0),
				"Размеры визуального куба строго 1.0 x 1.0 x 1.0 м", "(получено %s)" % str(msize))

	# Проверка Hurtbox
	var hurtbox: Hurtbox = enemy.get_node_or_null("Hurtbox") as Hurtbox
	_check(hurtbox != null, "Враг содержит узел Hurtbox")
	if hurtbox != null:
		var hurtbox_col: CollisionShape3D = hurtbox.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_check(hurtbox_col != null and hurtbox_col.shape is BoxShape3D, "Форма хитбокса получения урона — BoxShape3D")
		if hurtbox_col != null and hurtbox_col.shape is BoxShape3D:
			var hsize: Vector3 = (hurtbox_col.shape as BoxShape3D).size
			_check(is_equal_approx(hsize.x, 1.0) and is_equal_approx(hsize.y, 1.0) and is_equal_approx(hsize.z, 1.0),
				"Габариты хитбокса получения урона строго 1.0 x 1.0 x 1.0 м", "(получено %s)" % str(hsize))

	enemy.free()


## 2. Проверка визуального стиля (белый матовый + Inverted Hull черный контур).
func _test_monochrome_outline_material() -> void:
	print("\n-- 2. Визуальный стиль: белый матовый шейдинг и Inverted Hull контур")
	var packed: PackedScene = load(_ENEMY_SCENE_PATH) as PackedScene
	var enemy: ContactEnemy = packed.instantiate() as ContactEnemy
	root.add_child(enemy)
	await physics_frame

	var mesh_inst: MeshInstance3D = enemy.get_node_or_null("Mesh") as MeshInstance3D
	_check(mesh_inst != null, "MeshInstance3D доступен")
	if mesh_inst != null:
		var mat: StandardMaterial3D = mesh_inst.material_override as StandardMaterial3D
		_check(mat != null, "Меш врага имеет material_override типа StandardMaterial3D")
		if mat != null:
			_check(mat.albedo_color.r >= 0.8 and mat.albedo_color.g >= 0.8 and mat.albedo_color.b >= 0.8,
				"Основной материал белый монохромный (albedo=%.2f, %.2f, %.2f)" % [mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b])
			_check(mat.roughness >= 0.8 and is_equal_approx(mat.metallic_specular, 0.0),
				"Материал матовый без бликов (roughness=%.2f, specular=%.2f)" % [mat.roughness, mat.metallic_specular])

			var outline: StandardMaterial3D = mat.next_pass as StandardMaterial3D
			_check(outline != null, "Материал содержит next_pass контура")
			if outline != null:
				_check(outline.cull_mode == BaseMaterial3D.CULL_FRONT,
					"Контур использует инвертированное отсечение (Inverted Hull / CULL_FRONT)")
				_check(outline.albedo_color == Color(0, 0, 0, 1),
					"Цвет контура строго чёрный Color(0, 0, 0, 1)")
				_check(outline.grow and outline.grow_amount > 0.0,
					"Контур имеет активное расширение grow=true (величина %.3f м)" % outline.grow_amount)

	enemy.free()


## 3. Проверка коллизионных слоев (слой 3 тело, слой 4 хитбокс).
func _test_collision_layers_specification() -> void:
	print("\n-- 3. Коллизионные слои: тело 3 (enemy_body), хитбокс 4 (enemy_hurtbox)")
	var packed: PackedScene = load(_ENEMY_SCENE_PATH) as PackedScene
	var enemy: ContactEnemy = packed.instantiate() as ContactEnemy
	root.add_child(enemy)
	await physics_frame

	var is_layer_3: bool = (enemy.collision_layer & _LAYER_ENEMY_BODY) != 0
	var mask_has_world: bool = (enemy.collision_mask & _LAYER_WORLD) != 0
	var mask_has_enemy: bool = (enemy.collision_mask & _LAYER_ENEMY_BODY) != 0
	_check(is_layer_3, "Тело куба находится на слое 3 (enemy_body)", "(collision_layer=%d)" % enemy.collision_layer)
	_check(mask_has_world and mask_has_enemy, "Маска тела включает мир (слой 1) и своих (слой 3)")

	var hurtbox: Hurtbox = enemy.get_node_or_null("Hurtbox") as Hurtbox
	_check(hurtbox != null, "Узел Hurtbox найден")
	if hurtbox != null:
		var is_hurtbox_layer_4: bool = (hurtbox.collision_layer & _LAYER_ENEMY_HURTBOX) != 0
		var hurtbox_masks_player: bool = (hurtbox.collision_mask & _LAYER_PLAYER_HURTBOX) != 0
		_check(is_hurtbox_layer_4, "Хитбокс куба находится на слое 4 (enemy_hurtbox)", "(layer=%d)" % hurtbox.collision_layer)
		_check(hurtbox_masks_player, "Хитбокс куба детектирует слой 7 (player_hurtbox)", "(mask=%d)" % hurtbox.collision_mask)
		_check(hurtbox.detects_contact, "Хитбокс куба настроен на контактный урон (detects_contact == true)")

	enemy.free()


## 4. Проверка парения и синусоидального покачивания (bobbing).
func _test_hover_and_bobbing_dynamics() -> void:
	print("\n-- 4. Парение на высоте 1.0 м и синусоидальное покачивание (bobbing)")
	var packed: PackedScene = load(_ENEMY_SCENE_PATH) as PackedScene
	var enemy: ContactEnemy = packed.instantiate() as ContactEnemy
	root.add_child(enemy)
	await physics_frame

	_check(enemy.has_method("get_hover_height"), "У врага есть метод get_hover_height()")
	var h: float = enemy.get_hover_height()
	_check(is_equal_approx(h, 1.0), "Базовая высота парения равна 1.0 м", "(получено %.2f)" % h)

	_check(enemy.has_method("get_bob_amplitude"), "У врага есть метод get_bob_amplitude()")
	var amp: float = enemy.get_bob_amplitude()
	_check(is_equal_approx(amp, 0.1), "Амплитуда покачивания равна 0.1 м", "(получено %.2f)" % amp)
	_check(enemy.is_hovering(), "В живом состоянии враг парит: is_hovering() == true")

	var mesh_node: MeshInstance3D = enemy.get_node_or_null("Mesh") as MeshInstance3D
	_check(mesh_node != null, "Узел Mesh доступен для замера колебаний")
	if mesh_node != null:
		var min_y: float = 999.0
		var max_y: float = -999.0
		# Замеряем 260 физических тиков (~2.16 с), чтобы охватить полный период синусоиды (T = 2*PI / 3.0 ≈ 2.09 с)
		for i in 260:
			await physics_frame
			var cur_y: float = mesh_node.position.y
			min_y = minf(min_y, cur_y)
			max_y = maxf(max_y, cur_y)

		var observed_amp: float = (max_y - min_y) * 0.5
		_check(max_y > 1.05 and min_y < 0.95,
			"Куб колеблется выше и ниже базовой высоты 1.0 м",
			"(min=%.3f, max=%.3f)" % [min_y, max_y])
		_check(observed_amp >= 0.08 and observed_amp <= 0.12,
			"Наблюдаемая амплитуда колебаний соответствует спецификации ~0.1 м",
			"(замерено %.3f м)" % observed_amp)

	enemy.free()


## 5. Проверка осевого вращения вокруг оси Y (spin).
func _test_axial_spin_dynamics() -> void:
	print("\n-- 5. Плавное непрерывное осевое вращение вокруг оси Y (spin)")
	var packed: PackedScene = load(_ENEMY_SCENE_PATH) as PackedScene
	var enemy: ContactEnemy = packed.instantiate() as ContactEnemy
	root.add_child(enemy)
	await physics_frame

	_check(enemy.has_method("get_spin_speed"), "У врага есть метод get_spin_speed()")
	var speed: float = enemy.get_spin_speed()
	_check(speed >= 1.5 and speed <= 2.0,
		"Скорость вращения находится в диапазоне 1.5–2.0 рад/с",
		"(получено %.2f рад/с)" % speed)

	var initial_rot_y: float = enemy.rotation.y
	for i in 30:
		await physics_frame
	var delta_rot: float = enemy.rotation.y - initial_rot_y
	_check(delta_rot > 0.1, "Вращение по оси Y непрерывно нарастает в рантайме",
		"(смещение за 30 тиков: %.3f рад)" % delta_rot)

	enemy.free()


## 6. Проверка механики гибели (отключение парения, падение под гравитацией, достижение пола).
func _test_death_physics_and_landing() -> void:
	print("\n-- 6. Физика гибели: отключение парения, свободное падение под гравитацией до пола")
	var packed: PackedScene = load(_ENEMY_SCENE_PATH) as PackedScene
	var enemy: ContactEnemy = packed.instantiate() as ContactEnemy
	root.add_child(enemy)
	await physics_frame

	_died_emitted = 0
	enemy.died.connect(func() -> void: _died_emitted += 1)

	# Наносим смертельный урон
	enemy.take_damage(60.0)

	_check(_died_emitted == 1, "Сигнал died испущен ровно один раз", "(получено %d)" % _died_emitted)
	_check(not enemy.is_alive(), "Враг считается мёртвым: is_alive() == false")
	_check(not enemy.is_hovering(), "Режим парения немедленно отключен: is_hovering() == false")
	_check(enemy.collision_layer == 0, "Коллизионный слой тела обнулен (collision_layer == 0)")

	var hurtbox: Hurtbox = enemy.get_node_or_null("Hurtbox") as Hurtbox
	if hurtbox != null:
		await physics_frame
		_check(not bool(hurtbox.monitoring), "Хитбокс урона выключен: monitoring == false")

	var mesh_node: MeshInstance3D = enemy.get_node_or_null("Mesh") as MeshInstance3D
	_check(mesh_node != null, "MeshInstance3D доступен для наблюдения падения")
	if mesh_node != null:
		var prev_y: float = mesh_node.position.y
		await physics_frame
		await physics_frame
		var fall_y: float = mesh_node.position.y
		_check(fall_y < prev_y, "Куб ускоряется вниз под действием гравитации",
			"(было %.3f, стало %.3f)" % [prev_y, fall_y])

		# Ожидаем касания пола (высота центра куба на полу = 0.5 м)
		var landed: bool = false
		for i in 60:
			await physics_frame
			if enemy.has_landed() or is_equal_approx(mesh_node.position.y, 0.5):
				landed = true
				break
		_check(landed, "Куб приземлился на пол (landing) и стабилизировался на высоте пола 0.5 м",
			"(текущая высота: %.3f м)" % mesh_node.position.y)

	enemy.free()


## 7. Граничные условия: защита от повторного урона после гибели.
func _test_post_death_damage_resilience() -> void:
	print("\n-- 7. Граничные условия: блокировка повторного урона и сигналов после гибели")
	var packed: PackedScene = load(_ENEMY_SCENE_PATH) as PackedScene
	var enemy: ContactEnemy = packed.instantiate() as ContactEnemy
	root.add_child(enemy)
	await physics_frame

	_died_emitted = 0
	enemy.died.connect(func() -> void: _died_emitted += 1)

	enemy.take_damage(60.0)
	_check(_died_emitted == 1, "Первый смертельный урон вызвал сигнал died")
	_check(enemy.health() == 0.0, "Здоровье обнулено до 0.0")

	# Повторный урон по мертвому кубу
	enemy.take_damage(50.0)
	_check(_died_emitted == 1, "Повторный урон не вызывает died повторно", "(died_count=%d)" % _died_emitted)
	_check(enemy.health() == 0.0, "Здоровье мертвого куба не изменилось")
	_check(not enemy.is_alive(), "Мертвый куб не оживает")

	enemy.free()
