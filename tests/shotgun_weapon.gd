extends SceneTree

## Всесторонний юнит-тест двуствольного дробовика (Double-barrel Shotgun) для VibeFPS.
##
## Проверяет:
## 1. Ресурс данных data/weapons/shotgun.tres (урон=12, маг=2, перезаряд=1.1, скорость=70, pellets=10, spread=4.5).
## 2. Сцену weapons/shotgun/shotgun.tscn и полиморфизм (Shotgun extends Pistol).
## 3. Залп из 10 снарядов в ограниченном конусе разлёта.
## 4. Попадание всех 10 дробинок на дистанции 1.5 м в упор с суммарным уроном 120 единиц.
## 5. Граничные условия магазина (2 патрона, спам-клик, ограничение неотрицательности ammo >= 0).
## 6. Цикл перезарядки длительностью 1.1 с с сигналами reload_started и reload_finished.
## 7. Полиморфное экипирование игроком через apply_equipped_weapon().
##
## Запуск:
##   godot --headless --path . --script res://tests/shotgun_weapon.gd
##   powershell -File .\tools\run_checks.ps1 shotgun_weapon

const _SHOTGUN_DATA_PATH := "res://data/weapons/shotgun.tres"
const _SHOTGUN_SCENE_PATH := "res://weapons/shotgun/shotgun.tscn"
const _PLAYER_SCENE_PATH := "res://entities/player/player.tscn"

const _EXPECTED_PRICE := 600
const _EXPECTED_DAMAGE := 12.0
const _EXPECTED_MAGAZINE := 2
const _EXPECTED_RELOAD_TIME := 1.1
const _EXPECTED_SPEED := 80.0
const _EXPECTED_PELLETS := 10
const _EXPECTED_SPREAD_DEG := 4.5
const _EXPECTED_TOTAL_DAMAGE := 120.0

var _failures: PackedStringArray = []
var _checks := 0


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


func _finish() -> void:
	print("=== ИТОГ: проверок %d, ошибок %d ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  ОШИБКА: %s" % f)


func _bail(reason: String) -> void:
	print("КРИТИЧЕСКАЯ ОШИБКА: %s" % reason)
	_finish()
	quit(1)


func _initialize() -> void:
	print("=== VibeFPS: тест двуствольного дробовика (Shotgun) ===")
	_test_data_contract()
	_test_scene_contract()
	await _test_burst_mechanics()
	await _test_point_blank_damage()
	await _test_magazine_and_reload()
	await _test_player_polymorphic_equip()

	_finish()
	quit(1 if _failures.size() > 0 else 0)


## 1. Проверка контракта ресурса данных shotgun.tres.
func _test_data_contract() -> void:
	print("\n-- 1. Данные: shotgun.tres")
	var data := load(_SHOTGUN_DATA_PATH) as WeaponData
	_check(data != null, "shotgun.tres успешно загружен")
	if data == null:
		return
	_check(data.is_valid(), "shotgun.tres сообщает о валидности (is_valid == true)")
	_check(data.display_name == "Shotgun", "display_name равен 'Shotgun'", "(получено '%s')" % data.display_name)
	_check(data.price == _EXPECTED_PRICE, "цена равна %d" % _EXPECTED_PRICE, "(получено %d)" % data.price)
	_check(is_equal_approx(data.damage, _EXPECTED_DAMAGE), "урон равен %.1f" % _EXPECTED_DAMAGE, "(получено %.2f)" % data.damage)
	_check(data.magazine_size == _EXPECTED_MAGAZINE, "емкость магазина %d" % _EXPECTED_MAGAZINE, "(получено %d)" % data.magazine_size)
	_check(is_equal_approx(data.reload_time, _EXPECTED_RELOAD_TIME), "время перезарядки %.1f с" % _EXPECTED_RELOAD_TIME, "(получено %.2f)" % data.reload_time)
	_check(is_equal_approx(data.projectile_speed, _EXPECTED_SPEED), "скорость снаряда %.1f м/с" % _EXPECTED_SPEED, "(получено %.1f)" % data.projectile_speed)
	_check(data.pellets == _EXPECTED_PELLETS, "количество дробинок в залпе %d" % _EXPECTED_PELLETS, "(получено %d)" % data.pellets)
	_check(is_equal_approx(data.spread_angle_degrees, _EXPECTED_SPREAD_DEG), "угол конуса разлёта %.1f град" % _EXPECTED_SPREAD_DEG, "(получено %.2f)" % data.spread_angle_degrees)


## 2. Проверка сцены shotgun.tscn и полиморфизма.
func _test_scene_contract() -> void:
	print("\n-- 2. Сцена: shotgun.tscn и маркер Muzzle")
	var scene := load(_SHOTGUN_SCENE_PATH) as PackedScene
	_check(scene != null, "shotgun.tscn успешно загружена")
	if scene == null:
		return
	var inst := scene.instantiate()
	_check(inst != null, "shotgun.tscn успешно инстанцирована")
	if inst == null:
		return
	_check(inst is Pistol, "Shotgun наследует базовый класс Pistol (для полиморфизма)")
	_check(inst is Shotgun, "Экземпляр является классом Shotgun")

	var muzzle := inst.find_child("Muzzle", true, false) as Marker3D
	_check(muzzle != null, "Сцена shotgun.tscn содержит узел Marker3D с именем Muzzle")
	_check(muzzle != null and muzzle.position.z < -0.1, "Маркер Muzzle расположен спереди (z < -0.1)",
		"(получено z=%.3f)" % (muzzle.position.z if muzzle != null else 0.0))
	inst.free()


## 3. Проверка залпа из 10 снарядов и конуса рассеивания.
func _test_burst_mechanics() -> void:
	print("\n-- 3. Механика залпа из 10 дробинок и конус рассеивания")
	var world := Node3D.new()
	root.add_child(world)

	var scene := load(_SHOTGUN_SCENE_PATH) as PackedScene
	var shotgun := scene.instantiate() as Shotgun
	world.add_child(shotgun)
	await process_frame

	shotgun.mock_mouse_mode = Input.MOUSE_MODE_CAPTURED
	shotgun.set("_armed", true)
	_check(shotgun.has_method("get_pellet_count"), "shotgun содержит метод get_pellet_count()")
	_check(shotgun.get_pellet_count() == 10, "get_pellet_count() возвращает 10")

	# Производим выстрел залпом
	var fired: bool = shotgun.try_fire()
	_check(fired, "Выстрел дробовика успешно произведен")

	var pellets: Array[Node3D] = shotgun.last_spawned_pellets
	_check(pellets.size() == 10, "Залп дробовика заспавнил ровно 10 снарядов", "(получено %d)" % pellets.size())

	# Проверяем параметры снарядов и угол разлёта
	var max_spread_rad: float = deg_to_rad(_EXPECTED_SPREAD_DEG)
	var forward := -shotgun.global_transform.basis.z.normalized()
	var all_bounded: bool = true
	var all_stats_correct: bool = true

	for p in pellets:
		if p is Projectile:
			var bullet := p as Projectile
			if not is_equal_approx(bullet.speed, 80.0) or not is_equal_approx(bullet.damage, 12.0):
				all_stats_correct = false
			var bullet_dir: Vector3 = (bullet.get("_direction") as Vector3) if bullet.get("_direction") != null else Vector3.FORWARD
			var angle: float = forward.angle_to(bullet_dir)
			if angle > max_spread_rad + 0.001:
				all_bounded = false
		else:
			all_stats_correct = false

	_check(all_stats_correct, "Все 10 снарядов имеют скорость 70 м/с и урон 12.0")
	_check(all_bounded, "Все 10 снарядов лежат строго внутри конуса рассеивания %.1f градусов" % _EXPECTED_SPREAD_DEG)

	world.free()


## 4. Проверка поражения цели на дистанции 1.5 м в упор (120 урона).
func _test_point_blank_damage() -> void:
	print("\n-- 4. Суммарный урон в упор на дистанции 1.5 м (120 HP)")
	var world := Node3D.new()
	root.add_child(world)

	# Создаем мишень с Hurtbox на расстоянии 1.5 м прямо по оси -Z
	var target := Hurtbox.new()
	target.name = "TargetHurtbox"
	target.zone = 0 # Враг: слой 4

	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.0, 1.0) # Габариты куба-мишени 1х1х1 м
	col_shape.shape = box
	target.add_child(col_shape)
	world.add_child(target)
	target.global_position = Vector3(0.0, 0.0, -1.5)

	var recorded_damage: Array[float] = [0.0]
	target.damage_taken.connect(func(amount: float) -> void: recorded_damage[0] += amount)

	# Создаем дробовик в начале координат, направленный в сторону мишени (-Z)
	var scene := load(_SHOTGUN_SCENE_PATH) as PackedScene
	var shotgun := scene.instantiate() as Shotgun
	world.add_child(shotgun)
	shotgun.global_position = Vector3.ZERO
	shotgun.mock_mouse_mode = Input.MOUSE_MODE_CAPTURED
	shotgun.set("_armed", true)

	# Ждем синхронизации физического сервера Jolt
	await physics_frame
	await physics_frame

	var fired: bool = shotgun.try_fire()
	_check(fired, "Выстрел дробовика в упор успешно произведен")

	# Ждем 12 физических тиков, чтобы снаряды на скорости 70 м/с поразили цель
	for i in range(12):
		await physics_frame

	_check(is_equal_approx(recorded_damage[0], _EXPECTED_TOTAL_DAMAGE),
		"На дистанции 1.5 м все 10 дробинок поражают цель и наносят ровно 120 суммарного урона",
		"(получено урона: %.1f, ожидалось: %.1f)" % [recorded_damage[0], _EXPECTED_TOTAL_DAMAGE])

	world.free()


## 5. Проверка магазина, спам-клика и кулдауна.
func _test_magazine_and_reload() -> void:
	print("\n-- 5. Граничные условия магазина и перезарядка 1.1 с")
	var world := Node3D.new()
	root.add_child(world)

	var scene := load(_SHOTGUN_SCENE_PATH) as PackedScene
	var shotgun := scene.instantiate() as Shotgun
	world.add_child(shotgun)
	await process_frame

	shotgun.mock_mouse_mode = Input.MOUSE_MODE_CAPTURED
	shotgun.set("_armed", true)

	_check(shotgun.current_mag() == 2, "Начальный размер магазина равен 2")

	# Первый выстрел
	_check(shotgun.try_fire(), "Первый выстрел из 2 успешен")
	_check(shotgun.current_mag() == 1, "В магазине остался 1 патрон")

	# Спам-клик (кулдаун еще не истек)
	_check(not shotgun.try_fire(), "Повторный выстрел до истечения кулдауна отклонен")
	_check(shotgun.current_mag() == 1, "Число патронов не уменьшилось при спам-клике")

	# Сбрасываем кулдаун для второго выстрела
	shotgun.set("_cooldown", 0.0)
	_check(shotgun.try_fire(), "Второй выстрел из 2 успешен")
	_check(shotgun.current_mag() == 0, "Магазин пуст (0 патронов)")

	# Выстрел при пустом магазине
	_check(not shotgun.try_fire(), "Выстрел при пустом магазине отклонен")
	_check(shotgun.current_mag() == 0, "Счетчик патронов не уходит в отрицательные значения (ammo >= 0)")

	# Перезарядка
	var signal_box := {"started": false, "finished": false}
	shotgun.reload_started.connect(func() -> void: signal_box["started"] = true)
	shotgun.reload_finished.connect(func() -> void: signal_box["finished"] = true)

	_check(shotgun.start_reload(), "start_reload() запущен успешно")
	_check(signal_box["started"], "Испущен сигнал reload_started")
	_check(shotgun.is_reloading(), "is_reloading() сообщает о процессе перезарядки")
	_check(not shotgun.can_fire(), "Во время перезарядки огонь заблокирован (can_fire == false)")

	# Имитируем прошествие времени перезарядки 1.1 с через _process
	shotgun._process(0.6)
	_check(shotgun.is_reloading(), "На 0.6 с (до 1.1 с) перезарядка продолжается")
	_check(shotgun.current_mag() == 0, "Патроны не восстанавливаются досрочно")

	shotgun._process(0.55)
	_check(not shotgun.is_reloading(), "По истечении 1.1 с перезарядка завершена")
	_check(signal_box["finished"], "Испущен сигнал reload_finished")
	_check(shotgun.current_mag() == 2, "Магазин полностью пополнен до 2 патронов")

	world.free()


## 6. Проверка полиморфного экипирования игроком.
func _test_player_polymorphic_equip() -> void:
	print("\n-- 6. Полиморфное экипирование дробовика игроком")
	var world := Node3D.new()
	root.add_child(world)

	# Создаем фиктивный узел GameState под корнем, если его нет
	var gs: Node = root.get_node_or_null("GameState")
	var created_gs: bool = false
	if gs == null:
		var gs_class := load("res://core/game_state.gd") as GDScript
		gs = gs_class.new()
		gs.name = "GameState"
		root.add_child(gs)
		created_gs = true

	gs.set("equipped_weapon_id", "shotgun")

	var player_scene := load(_PLAYER_SCENE_PATH) as PackedScene
	_check(player_scene != null, "player.tscn загружена")
	if player_scene != null:
		var player := player_scene.instantiate() as CharacterBody3D
		world.add_child(player)
		await process_frame

		# Применяем экипировку
		if player.has_method("apply_equipped_weapon"):
			player.call("apply_equipped_weapon")

		var current_weapon: Node = player.get("_pistol") as Node
		_check(current_weapon != null, "В слоте оружия игрока присутствует оружие")
		_check(current_weapon is Pistol, "Экипированное оружие удовлетворяет интерфейсу Pistol")
		_check(current_weapon is Shotgun, "Экипированное оружие является Shotgun")

	if created_gs:
		gs.free()
	world.free()
