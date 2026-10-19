extends SceneTree

## Тестовый сценарий автоматического оружия для VibeFPS: второе оружие (автоматический пистолет)
## использует логику pistol.gd, управляемую отдельным WeaponData. Данный тест проверяет
## отличающиеся компоненты: данные auto.tres, настройку сцены auto.tscn, выстрел через
## реальный projectile.tscn и визуал снаряда (радиус 0.06, желтый след).
##
## Паттерн аналогичен tests/weapon.gd: _PistolProbe переопределяет режим курсора
## для гейта ввода (в headless-режиме захват мыши недоступен), геометрия auto.tscn
## переносится на зонд, а задержки измеряются в секундах реального времени.
##
## Запуск: godot --headless --path . --script res://tests/auto_weapon.gd
##         .\tools\run_checks.ps1 auto_weapon

## Тестовый зонд на базе pistol.gd.
class _PistolProbe extends "res://weapons/pistol/pistol.gd":
	## Режим мыши, передаваемый гейту ввода вместо Input.mouse_mode.
	var gate_mouse_mode: int = Input.MOUSE_MODE_CAPTURED

	func _mouse_mode_for_play_input() -> int:
		return gate_mouse_mode


## Регистратор событий выстрелов оружия.
class _Log extends RefCounted:
	var fired: int = 0

	func _on_fired() -> void:
		fired += 1


const _AUTO_DATA_PATH := "res://data/weapons/auto.tres"
const _AUTO_SCENE_PATH := "res://weapons/auto/auto.tscn"
## Сцена снаряда, загружаемая напрямую для проверки реального следа.
const _PROJECTILE_SCENE_PATH := "res://weapons/projectile/projectile.tscn"

## Ожидаемые параметры автомата согласно проектной спецификации.
const _EXPECTED_MAGAZINE := 36
const _EXPECTED_INTERVAL := 0.2
const _EXPECTED_DAMAGE := 15.0
const _EXPECTED_SPEED := 70.0
const _EXPECTED_RADIUS := 0.06
const _EXPECTED_PRICE := 300
const _EXPECTED_COLOR := Color(0.95, 0.75, 0.15)

## Предельное время ожидания в секундах.
const _WAIT_CAP_SECONDS := 15.0
## Допустимое превышение таймера над номинальным интервалом.
const _TIMER_TOLERANCE := 0.35
## Допустимая погрешность снизу для таймера.
const _TIMER_EPSILON := 0.05

var _failures: PackedStringArray = []
var _checks := 0
var _data: WeaponData
var _projectile_scene: PackedScene


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


func _close(a: float, b: float) -> bool:
	return is_equal_approx(a, b)


func _close_color(a: Color, b: Color) -> bool:
	return is_equal_approx(a.r, b.r) and is_equal_approx(a.g, b.g) \
		and is_equal_approx(a.b, b.b)


# --------------------------------------------------------------------------
# ожидание
# --------------------------------------------------------------------------

func _await_until(predicate: Callable, max_seconds := _WAIT_CAP_SECONDS) -> bool:
	var deadline := _now_ms() + int(max_seconds * 1000.0)
	var reached := false
	for i in 1000000:
		await process_frame
		if predicate.call():
			reached = true
			break
		if _now_ms() >= deadline:
			break
	return reached


func _now_ms() -> int:
	return Time.get_ticks_msec()


## Отпускает действие стрельбы и ожидает пару кадров для сброса триггера ввода.
func _settle_fire_released() -> void:
	Input.action_release("fire")
	await process_frame
	await process_frame


# --------------------------------------------------------------------------
# построение тестового окружения
# --------------------------------------------------------------------------

func _new_world() -> Node3D:
	var world := Node3D.new()
	world.name = "World"
	root.add_child(world)
	return world


## Камера на высоте головы персонажа (1.7 м). В auto.tscn поле fire_rate_source
## пустое, поэтому прицеливание производится от камеры.
func _new_eye(world: Node3D) -> Camera3D:
	var eye := Camera3D.new()
	eye.name = "Eye"
	eye.current = true
	eye.position = Vector3(0.0, 1.7, 0.0)
	world.add_child(eye)
	return eye


## Геометрия auto.tscn переносится на тестовый зонд _PistolProbe.
func _new_pistol_from_scene(world: Node3D, scene: PackedScene, data: WeaponData) -> _PistolProbe:
	var geometry := scene.instantiate()
	var pistol := _PistolProbe.new()
	pistol.name = "Auto"
	pistol.data = data
	pistol.projectile_scene = _projectile_scene
	for child in geometry.get_children():
		geometry.remove_child(child)
		child.owner = null
		pistol.add_child(child)
	geometry.free()
	world.add_child(pistol)
	for i in 8:
		await process_frame
		if pistol.is_node_ready():
			return pistol
	print("КРИТИЧЕСКАЯ ОШИБКА: узел автомата не перешел в состояние ready")
	return pistol


func _watch(pistol: _PistolProbe) -> _Log:
	var log := _Log.new()
	pistol.fired.connect(log._on_fired)
	return log


## Снаряды под родительским узлом `parent`.
func _live_projectiles(parent: Node3D) -> Array[Projectile]:
	var out: Array[Projectile] = []
	for child in parent.get_children():
		if child is Projectile:
			out.append(child as Projectile)
	return out


# --------------------------------------------------------------------------
# точка входа
# --------------------------------------------------------------------------

func _initialize() -> void:
	print("=== VibeFPS: тест автоматического оружия ===")
	_data = load(_AUTO_DATA_PATH) as WeaponData
	if _data == null:
		_bail("не удалось загрузить %s как WeaponData" % _AUTO_DATA_PATH)
		return
	_projectile_scene = load(_PROJECTILE_SCENE_PATH) as PackedScene
	if _projectile_scene == null:
		_bail("не удалось загрузить %s" % _PROJECTILE_SCENE_PATH)
		return

	_test_data_contract()
	_test_scene_contract()
	await _test_scene_shot()
	await _test_fire_interval()

	_finish()
	quit(1 if _failures.size() > 0 else 0)


# --------------------------------------------------------------------------
# проверки
# --------------------------------------------------------------------------

## Проверка ресурса параметров оружия auto.tres.
func _test_data_contract() -> void:
	print("-- data: auto.tres соответствует спецификации")
	_check(_data.is_valid(), "auto.tres сообщает о валидности")
	_check(_data.display_name == "Auto", "display_name равен \"Auto\"",
		"(получено \"%s\")" % _data.display_name)
	_check(_close(_data.seconds_between_shots(), _EXPECTED_INTERVAL),
		"seconds_between_shots() равен %.1f с при 300 выстр/мин" % _EXPECTED_INTERVAL,
		"(получено %.6f)" % _data.seconds_between_shots())
	_check(_data.magazine_size == _EXPECTED_MAGAZINE,
		"размер магазина %d" % _EXPECTED_MAGAZINE,
		"(получено %d)" % _data.magazine_size)
	_check(_close(_data.damage, _EXPECTED_DAMAGE),
		"урон равен %.1f" % _EXPECTED_DAMAGE, "(получено %.4f)" % _data.damage)
	_check(_data.price == _EXPECTED_PRICE,
		"цена равна %d" % _EXPECTED_PRICE, "(получено %d)" % _data.price)
	_check(_close(_data.projectile_speed, _EXPECTED_SPEED),
		"скорость снаряда равна %.1f м/с" % _EXPECTED_SPEED,
		"(получено %.4f)" % _data.projectile_speed)
	_check(_close(_data.projectile_radius, _EXPECTED_RADIUS),
		"радиус снаряда равен %.2f м" % _EXPECTED_RADIUS,
		"(получено %.4f)" % _data.projectile_radius)
	_check(_close_color(_data.projectile_color, _EXPECTED_COLOR),
		"цвет снаряда соответствует желтому цвету автомата", "(получено %s)" % _data.projectile_color)


## Проверка сцены auto.tscn и её привязок.
func _test_scene_contract() -> void:
	print("-- scene: сцена auto.tscn загружается и привязана к auto.tres")
	var packed: PackedScene = load(_AUTO_SCENE_PATH)
	_check(packed != null, "auto.tscn успешно загружена", "(%s)" % _AUTO_SCENE_PATH)
	if packed == null:
		return
	var direct := packed.instantiate()
	_check(direct != null, "auto.tscn успешно создана")
	if direct == null:
		return
	_check(direct.get("data") == _data,
		"auto.tscn использует data = auto.tres")
	_check(direct.get("projectile_scene") == _projectile_scene,
		"auto.tscn управляет res://weapons/projectile/projectile.tscn")
	_check(direct.get("fire_rate_source") == null,
		"auto.tscn оставляет fire_rate_source пустым: прицеливание от камеры")
	var barrel := direct.get_node_or_null("Muzzle") as Node3D
	_check(barrel != null, "auto.tscn содержит маркер Muzzle")
	_check(barrel != null and barrel.position.z < -0.1,
		"и дуло расположено перед оружием, а не внутри рукояти",
		"(получено %s)" % ("нет Muzzle" if barrel == null else str(barrel.position)))
	direct.free()


## Проверка реального выстрела через ввод и параметров созданного снаряда.
func _test_scene_shot() -> void:
	print("-- shot: один выстрел с прицеливанием по камере, визуал снаряда из auto.tres")
	var world := _new_world()
	var eye := _new_eye(world)
	var packed: PackedScene = load(_AUTO_SCENE_PATH)
	if packed == null:
		world.free()
		return
	var pistol := await _new_pistol_from_scene(world, packed, _data)
	var log := _watch(pistol)

	var barrel := pistol.get_node_or_null("Muzzle") as Node3D
	_check(barrel != null, "предусловие: внедренная сцена содержит маркер Muzzle")

	await _settle_fire_released()
	Input.action_press("fire")
	var fired := await _await_until(func() -> bool: return log.fired > 0, 5.0)
	Input.action_release("fire")
	_check(fired, "зажатие кнопки стрельбы вызвало выстрел", "(получено %d)" % log.fired)
	_check(log.fired == 1, "произведен ровно один выстрел", "(получено %d)" % log.fired)
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
		"выстрел потратил ровно один патрон", "(получено %d)" % pistol.current_mag())

	var bullets := _live_projectiles(eye)
	_check(bullets.size() == 1, "один снаряд создан под камерой",
		"(получено %d)" % bullets.size())
	if bullets.size() == 1 and barrel != null:
		var bullet := bullets[0]
		_check(bullet.global_position.distance_to(eye.global_position) > 0.5,
			"снаряд не висит внутри камеры",
			"(%.3f м от камеры)" % bullet.global_position.distance_to(eye.global_position))
		_check(absf(bullet.global_position.y - barrel.global_position.y) < 0.2,
			"вылет происходит на высоте ствола, а не камеры",
			"(снаряд y=%.3f, ствол y=%.3f, камера y=%.3f)" % [
				bullet.global_position.y, barrel.global_position.y, eye.global_position.y])
		_check(_close(bullet.speed, _EXPECTED_SPEED),
			"снаряд перенимает скорость автомата из ресурса данных",
			"(получено %.1f м/с)" % bullet.speed)
		_check(_close(bullet.damage, _EXPECTED_DAMAGE),
			"снаряд перенимает урон автомата из ресурса данных",
			"(получено %.1f)" % bullet.damage)
		_check(_close(bullet.radius, _EXPECTED_RADIUS),
			"снаряд перенимает радиус автомата из ресурса данных",
			"(получено %.4f)" % bullet.radius)
		_check(_close_color(bullet.color, _data.projectile_color),
			"снаряд перенимает цвет автомата из ресурса данных",
			"(получено %s, ожидалось %s)" % [str(bullet.color), str(_data.projectile_color)])

		var trail := bullet.get_node_or_null("Trail") as MeshInstance3D
		_check(trail != null, "снаряд содержит узел шлейфа Trail")
		if trail != null:
			var sphere := trail.mesh as SphereMesh
			_check(sphere != null and _close(sphere.radius, bullet.radius),
				"сфера шлейфа имеет радиус из данных: визуал следует auto.tres",
				"(получено %s)" % ("нет SphereMesh" if sphere == null else "%.4f" % sphere.radius))
			var mat := trail.material_override as StandardMaterial3D
			_check(mat != null and _close_color(mat.albedo_color, _data.projectile_color),
				"материал шлейфа использует цвет из данных",
				"(получено %s)" % ("нет материала" if mat == null else str(mat.albedo_color)))

		var start: Vector3 = bullet.global_position
		await _await_until(func() -> bool: return bullet.global_position.distance_to(start) > 0.5, 5.0)
		var moved: Vector3 = bullet.global_position - start
		_check(moved.length() > 0.5,
			"снаряд летит в пространстве: launch() вызван на узле в дереве",
			"(смещение %.3f м)" % moved.length())
		_check(moved.normalized().dot(-eye.global_transform.basis.z) > 0.99,
			"полет направлен строго вперед по оси камеры",
			"(%.3f м вдоль %.3f м вперед)" % [
				moved.length(), moved.normalized().dot(-eye.global_transform.basis.z)])
	world.free()


## Проверка темпа стрельбы: 300 выстр/мин соответствует интервалу 0.2 с.
func _test_fire_interval() -> void:
	print("-- rate limit: один выстрел за %.1f с, тайминг в секундах, а не кадрах" % _EXPECTED_INTERVAL)
	var world := _new_world()
	var packed: PackedScene = load(_AUTO_SCENE_PATH)
	if packed == null:
		world.free()
		return
	var pistol := await _new_pistol_from_scene(world, packed, _data)
	var log := _watch(pistol)

	_check(pistol.try_fire(), "первый выстрел разрешен")
	_check(not pistol.try_fire(), "повторный выстрел в тот же миг отклоняется")
	_check(log.fired == 1, "потрачен ровно один патрон",
		"(получено %d)" % log.fired)

	var start := _now_ms()
	var second := false
	for i in 6000:
		await process_frame
		if pistol.try_fire():
			second = true
			break
	var elapsed := float(_now_ms() - start) / 1000.0
	print("    второй выстрел спустя %.3f с" % elapsed)
	_check(second, "следующий выстрел разрешен по истечении интервала")
	_check(elapsed >= _EXPECTED_INTERVAL - _TIMER_EPSILON,
		"второй выстрел выждал как минимум полный интервал",
		"(прошло %.3f с, ожидалось >= %.2f с)" % [elapsed, _EXPECTED_INTERVAL - _TIMER_EPSILON])
	_check(elapsed <= _EXPECTED_INTERVAL + _TIMER_TOLERANCE,
		"и не задержался существенно дольше интервала",
		"(прошло %.3f с, ожидалось <= %.2f с)" % [elapsed, _EXPECTED_INTERVAL + _TIMER_TOLERANCE])
	_check(log.fired == 2, "произведено ровно два выстрела",
		"(получено %d)" % log.fired)
	world.free()