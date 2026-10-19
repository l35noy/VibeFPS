extends SceneTree

## Тестовый сценарий оружия для VibeFPS: магазин пистолета, ограничение темпа
## стрельбы, перезарядка и гейт ввода.
##
## Пистолет собирается здесь программно с обычным Node3D в роли источника огня
## и без присутствия игрока на сцене: тестируется учёт патронов магазина,
## интервал стрельбы и гейт ввода, для чего персонаж или уровень не требуются.
## Пистолету передаётся PackedScene снаряда и запрашивается его создание,
## что позволяет реально проверить списание патрона только после создания снаряда.
##
## В headless-режиме курсор мыши захватить невозможно: Input.set_mouse_mode() там
## игнорируется, и Input.mouse_mode остаётся VISIBLE. Аналогично tests/movement.gd,
## пистолету передаётся подкласс с явным режимом курсора для гейта ввода.
##
## Ожидания ограничены реальным временем (в секундах), а не кадрами, так как
## таймеры оружия работают в секундах.
##
## Запуск:
##   godot --headless --path . --script res://tests/weapon.gd
##   powershell -File .\tools\run_checks.ps1 weapon

## Тестовый подкласс pistol.gd для подмены режима курсора.
class _PistolProbe extends "res://weapons/pistol/pistol.gd":
	## Режим курсора мыши для проверки гейта ввода вместо Input.mouse_mode.
	var gate_mouse_mode: int = Input.MOUSE_MODE_CAPTURED

	func _mouse_mode_for_play_input() -> int:
		return gate_mouse_mode


## Записывает сигналы пистолета с временными метками для замера длительности перезарядки.
class _Log extends RefCounted:
	var fired: int = 0
	var reload_started: int = 0
	var reload_finished: int = 0
	var magazine: Array[Vector2i] = []
	var reload_started_at_ms: int = -1
	var reload_finished_at_ms: int = -1

	func _on_fired() -> void:
		fired += 1

	func _on_reload_started() -> void:
		reload_started += 1
		reload_started_at_ms = Time.get_ticks_msec()

	func _on_reload_finished() -> void:
		reload_finished += 1
		reload_finished_at_ms = Time.get_ticks_msec()

	func _on_magazine_changed(current: int, capacity: int) -> void:
		magazine.append(Vector2i(current, capacity))

	func last_magazine() -> Vector2i:
		return magazine[magazine.size() - 1]

	func reload_duration() -> float:
		if reload_started_at_ms < 0 or reload_finished_at_ms < 0:
			return -1.0
		return float(reload_finished_at_ms - reload_started_at_ms) / 1000.0


const _PISTOL_SCRIPT_PATH := "res://weapons/pistol/pistol.gd"
const _PISTOL_DATA_PATH := "res://data/weapons/pistol.tres"
## Готовая сцена пистолета, загружаемая из ресурсов.
const _PISTOL_SCENE_PATH := "res://weapons/pistol/pistol.tscn"

## Проектные параметры пистолета для защиты от непреднамеренных правок баланса.
const _EXPECTED_MAGAZINE := 18
const _EXPECTED_RELOAD_TIME := 1.2
const _EXPECTED_INTERVAL := 0.4
const _EXPECTED_PROJECTILE_SPEED := 70.0
const _EXPECTED_DAMAGE := 30.0
const _EXPECTED_LIFETIME := 4.0

## Максимальный таймаут ожидания по реальному времени.
const _WAIT_CAP_SECONDS := 15.0
## Допустимое превышение таймера из-за дискретности кадров.
const _TIMER_TOLERANCE := 0.35
## Погрешность для защиты от преждевременного завершения таймера.
const _TIMER_EPSILON := 0.05
## Число физических тиков наблюдения за полётом снаряда.
const _TRAJECTORY_TICKS := 60
## Допустимое боковое отклонение траектории снаряда в метрах.
const _TRAJECTORY_DRIFT_TOLERANCE := 0.05
## Минимальная дистанция полёта снаряда для валидности замера траектории.
const _TRAJECTORY_MIN_TRAVEL := 2.0
## Длительность наблюдения за оружием при зажатой на старте кнопке (в секундах).
const _NO_SHOT_WATCH_SECONDS := 1

var _failures: PackedStringArray = []
var _checks := 0
var _data: WeaponData
## PackedScene снаряда в памяти для подстановки в оружие.
var _projectile_scene: PackedScene


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


func _finish() -> void:
	print("=== RESULT: %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)


## Прерывает выполнение при нарушении критического предусловия.
func _bail(reason: String) -> void:
	print("FATAL: %s" % reason)
	_finish()
	quit(1)


# --------------------------------------------------------------------------
# waiting
# --------------------------------------------------------------------------

## Runs one process frame at a time until `predicate` holds, giving up after
## `max_seconds` of wall clock. Returns whether the predicate was reached, so
## the caller can assert on a timeout instead of silently waiting forever.
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


## Сбрасывает действие fire и ожидает кадры обработки, чтобы защёлка первого
## нажатия зафиксировала отпущенное состояние кнопки.
func _settle_fire_released() -> void:
	Input.action_release("fire")
	await process_frame
	await process_frame


## Создаёт событие нажатия/отпускания клавиши перезарядки (R) для отправки через Input.
func _reload_key_event(pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_R
	ev.keycode = KEY_R
	ev.pressed = pressed
	return ev


## Создаёт источник прицеливания внутри родительского узла-поворота для проверки
## независимости траектории полёта снаряда от движения родителя.
func _new_aim_under_pivot(world: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	world.add_child(pivot)
	var aim := Node3D.new()
	aim.name = "AimSource"
	pivot.add_child(aim)
	return pivot


## Создаёт тестовую камеру игрока с положением на высоте глаз (1.7 м).
func _new_eye(world: Node3D) -> Camera3D:
	var eye := Camera3D.new()
	eye.name = "Eye"
	eye.current = true
	eye.position = Vector3(0.0, 1.7, 0.0)
	world.add_child(eye)
	return eye


## Создаёт экземпляр пистолета из загруженной сцены, прививая геометрию тестовому зонду.
func _new_pistol_from_scene(world: Node3D, scene: PackedScene,
		data: WeaponData, projectiles := true) -> _PistolProbe:
	var geometry := scene.instantiate()
	var pistol := _PistolProbe.new()
	pistol.name = "Pistol"
	pistol.data = data
	if projectiles:
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
	print("FATAL: пистолет так и не стал ready")
	return pistol


# --------------------------------------------------------------------------
# функции построения мира
# --------------------------------------------------------------------------

## Создаёт изолированный тестовый мир для отдельного сценария.
func _new_world() -> Node3D:
	var world := Node3D.new()
	world.name = "World"
	root.add_child(world)
	return world


## Создаёт узел-источник прицеливания с заданным углом поворота вокруг оси Y.
func _new_aim_source(world: Node3D, yaw := 0.0) -> Node3D:
	var aim := Node3D.new()
	aim.name = "AimSource"
	aim.rotation.y = yaw
	world.add_child(aim)
	return aim


## Создаёт экземпляр тестового зонда пистолета и ожидает его готовности (ready).
func _new_pistol(world: Node3D, data: WeaponData, aim: Node3D,
		with_projectiles := true) -> _PistolProbe:
	var pistol := _PistolProbe.new()
	pistol.name = "Pistol"
	pistol.data = data
	pistol.fire_rate_source = aim
	if with_projectiles:
		pistol.projectile_scene = _projectile_scene
	world.add_child(pistol)
	for i in 8:
		await process_frame
		if pistol.is_node_ready():
			return pistol
	print("FATAL: пистолет так и не стал ready")
	return pistol


func _watch(pistol: _PistolProbe) -> _Log:
	var log := _Log.new()
	pistol.fired.connect(log._on_fired)
	pistol.reload_started.connect(log._on_reload_started)
	pistol.reload_finished.connect(log._on_reload_finished)
	pistol.magazine_changed.connect(log._on_magazine_changed)
	return log


## Возвращает список активных узлов Projectile среди дочерних узлов родителя.
func _live_projectiles(parent: Node3D) -> Array[Projectile]:
	var out: Array[Projectile] = []
	for child in parent.get_children():
		if child is Projectile:
			out.append(child as Projectile)
	return out


## Собирает и упаковывает в памяти минимальную сцену снаряда с CollisionShape3D.
func _build_projectile_scene() -> PackedScene:
	var bullet := Projectile.new()
	bullet.name = "Projectile"
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var sphere := SphereShape3D.new()
	sphere.radius = 0.08
	shape.shape = sphere
	bullet.add_child(shape)
	shape.owner = bullet
	var packed := PackedScene.new()
	var err := packed.pack(bullet)
	bullet.free()
	if err != OK:
		return null
	return packed


func _signal_arg_count(node: Object, signal_name: String) -> int:
	for entry in node.get_signal_list():
		if String(entry.get("name", "")) == signal_name:
			return (entry["args"] as Array).size()
	return -1


## Возвращает строку подсказки свойства (@export) для проверки объявленного типа.
func _property_hint(node: Object, property_name: String) -> String:
	for entry in node.get_property_list():
		if String(entry.get("name", "")) == property_name:
			return String(entry.get("hint_string", ""))
	return "<отсутствует>"


# --------------------------------------------------------------------------
# точка входа
# --------------------------------------------------------------------------

func _initialize() -> void:
	print("=== VibeFPS weapon test ===")
	_data = load(_PISTOL_DATA_PATH) as WeaponData
	if _data == null:
		_bail("не удалось загрузить %s как WeaponData" % _PISTOL_DATA_PATH)
		return
	_projectile_scene = _build_projectile_scene()
	if _projectile_scene == null:
		_bail("не удалось упаковать сцену снаряда в памяти")
		return

	_test_source_contract()
	_test_contracts()
	_test_gate_harness()
	await _test_starting_magazine()
	await _test_single_shot()
	await _test_shot_follows_fire_source()
	await _test_shot_keeps_its_line_when_the_aim_source_moves()
	await _test_shot_starts_at_the_barrel()
	await _test_no_shot_while_the_button_is_down_on_entry()
	await _test_empty_magazine_and_manual_reload()
	await _test_reload_blocks_firing_and_cannot_be_restarted()
	await _test_fire_rate()
	await _test_input_gate()
	await _test_full_magazine_has_nothing_to_reload()
	await _test_scene_change_reset()
	await _test_invalid_data_blocks_firing()
	await _test_missing_projectile_scene_keeps_the_round()

	_finish()
	quit(1 if _failures.size() > 0 else 0)


# --------------------------------------------------------------------------
# проверки
# --------------------------------------------------------------------------

## Проверяет архитектурные правила: таймеры работают в _process (не в тиках физики),
## а can_fire() запрашивает разрешение у InputGate.
func _test_source_contract() -> void:
	print("-- контракт исходного кода: цикл таймеров и опрос гейта ввода")
	var source := FileAccess.get_file_as_string(_PISTOL_SCRIPT_PATH)
	_check(source != "", "pistol.gd доступен для чтения", "(%d байт)" % source.length())
	_check(source.contains("func _process(delta"),
		"pistol.gd обрабатывает таймеры в _process, а не в физическом тике")
	_check(not source.contains("func _physics_process"),
		"pistol.gd не объявляет _physics_process: интервал стрельбы измеряется в секундах")
	_check(source.count("InputGate.is_play_input_allowed(") >= 1,
		"can_fire() запрашивает разрешение у InputGate",
		"(мест вызова=%d)" % source.count("InputGate.is_play_input_allowed("))


## Проверяет объявленный класс, экспортируемые свойства, методы и сигналы.
func _test_contracts() -> void:
	print("-- контракты: класс, экспорт, методы и сигналы для связывания")
	var script := load(_PISTOL_SCRIPT_PATH) as Script
	_check(script != null, "pistol.gd успешно загружается")
	if script == null:
		return
	_check(script.get_global_name() == "Pistol",
		"pistol.gd объявляет class_name Pistol", "(got \"%s\")" % script.get_global_name())
	_check(script.get_instance_base_type() == "Node3D", "Pistol расширяет Node3D",
		"(got %s)" % script.get_instance_base_type())

	var pistol: Node = script.new()
	for method in ["can_fire", "try_fire", "start_reload", "current_mag",
			"is_reloading", "reset_for_scene_change"]:
		_check(pistol.has_method(method), "Pistol содержит метод %s()" % method)
	for signal_name in ["fired", "reload_started", "reload_finished", "magazine_changed"]:
		_check(pistol.has_signal(signal_name), "Pistol объявляет сигнал %s" % signal_name)
	_check(_signal_arg_count(pistol, "magazine_changed") == 2,
		"сигнал magazine_changed принимает (current, capacity)",
		"(got %d args)" % _signal_arg_count(pistol, "magazine_changed"))
	_check(_property_hint(pistol, "data") == "WeaponData",
		"data является экспортом типа WeaponData", "(got \"%s\")" % _property_hint(pistol, "data"))
	_check(_property_hint(pistol, "projectile_scene") == "PackedScene",
		"projectile_scene является экспортом типа PackedScene",
		"(got \"%s\")" % _property_hint(pistol, "projectile_scene"))
	_check(_property_hint(pistol, "fire_rate_source") == "Node3D",
		"fire_rate_source является экспортом типа Node3D",
		"(got \"%s\")" % _property_hint(pistol, "fire_rate_source"))
	_check(pistol.get("fire_rate_source") == null,
		"fire_rate_source по умолчанию пуст: пистолет использует камеру игрока")
	pistol.free()


## Проверяет корректность работы гейта ввода в тестовом окружении.
func _test_gate_harness() -> void:
	print("-- проверка гейта ввода: зонд активен и pistol.gd читает Input.mouse_mode")
	var script := load(_PISTOL_SCRIPT_PATH) as Script
	var stock: Node = script.new()
	_check(int(stock.call("_mouse_mode_for_play_input")) == Input.mouse_mode,
		"немодифицированный pistol.gd запрашивает режим мыши у движка",
		"(mouse_mode=%d)" % Input.mouse_mode)
	stock.free()
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"предусловие: headless-режим не захватывает курсор",
		"(mouse_mode=%d)" % Input.mouse_mode)
	_check(InputGate.is_play_input_allowed(Input.MOUSE_MODE_CAPTURED),
		"гейт разрешает игровой ввод при захваченном курсоре")
	_check(not InputGate.is_play_input_allowed(Input.MOUSE_MODE_VISIBLE),
		"гейт блокирует игровой ввод при свободном курсоре")


func _test_starting_magazine() -> void:
	print("-- начальное состояние: новый пистолет имеет полный магазин")
	var world := _new_world()
	var pistol := await _new_pistol(world, _data, _new_aim_source(world))
	var log := _watch(pistol)

	_check(pistol.current_mag() == _EXPECTED_MAGAZINE,
		"новый пистолет начинает с полным магазином",
		"(got %d из %d)" % [pistol.current_mag(), _EXPECTED_MAGAZINE])
	_check(not pistol.is_reloading(), "новый пистолет не находится в процессе перезарядки")
	_check(pistol.can_fire(), "новый пистолет с валидными данными готов к стрельбе")
	_check(log.fired == 0, "при создании пистолета выстрелов не происходит")
	_check(log.magazine.is_empty(),
		"magazine_changed молчит на старте: он оповещает об изменениях, а не о создании",
		"(got %s)" % str(log.magazine))
	world.free()


## Один выстрел: расходует один патрон, испускает сигнал и создаёт летящий снаряд.
func _test_single_shot() -> void:
	print("-- одиночный выстрел: один патрон, один сигнал, летящий снаряд")
	var world := _new_world()
	var aim := _new_aim_source(world)
	var pistol := await _new_pistol(world, _data, aim)
	var log := _watch(pistol)

	_check(pistol.try_fire(), "try_fire() сообщает об успешном выстреле")
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
		"магазин уменьшился ровно на один патрон", "(got %d)" % pistol.current_mag())
	_check(log.fired == 1, "сигнал fired испущен ровно один раз", "(got %d)" % log.fired)
	_check(log.magazine.size() == 1,
		"сигнал magazine_changed сработал один раз на выстрел", "(got %d)" % log.magazine.size())
	_check(log.magazine.size() == 1
			and log.last_magazine() == Vector2i(_EXPECTED_MAGAZINE - 1, _EXPECTED_MAGAZINE),
		"magazine_changed передаёт новое количество патронов и вместимость магазина",
		"(got %s)" % str(log.magazine))

	var bullets := _live_projectiles(aim)
	_check(bullets.size() == 1, "создан ровно один узел снаряда",
		"(got %d)" % bullets.size())
	if bullets.size() == 1:
		var bullet := bullets[0]
		_check(is_equal_approx(bullet.speed, _EXPECTED_PROJECTILE_SPEED),
			"снаряд берёт скорость из данных оружия",
			"(got %.1f м/с)" % bullet.speed)
		_check(is_equal_approx(bullet.damage, _EXPECTED_DAMAGE),
			"снаряд берёт урон из данных оружия",
			"(got %.1f)" % bullet.damage)
		_check(is_equal_approx(bullet.lifetime, _EXPECTED_LIFETIME),
			"снаряд берёт время жизни из данных оружия",
			"(got %.1f с)" % bullet.lifetime)
		var start: Vector3 = bullet.global_position
		await _await_until(func() -> bool: return bullet.global_position.distance_to(start) > 0.5, 5.0)
		var moved: Vector3 = bullet.global_position - start
		_check(moved.length() > 0.5,
			"снаряд находится в полёте: launch() вызван на узле в дереве сцены",
			"(пролетел %.3f м)" % moved.length())
		_check(moved.normalized().dot(-aim.global_transform.basis.z) > 0.99,
			"снаряд вылетает вдоль оси направления источника прицеливания",
			"(%.3f м вдоль %.3f м направления)" % [
				moved.length(), moved.normalized().dot(-aim.global_transform.basis.z)])
	world.free()


## Выстрел с источником прицеливания, повёрнутым на 90 градусов.
func _test_shot_follows_fire_source() -> void:
	print("-- направление: выстрел следует за источником прицеливания, а не за мировой осью")
	var world := _new_world()
	# -90 градусов рыскания разворачивает ось вперёд из -Z в +X.
	var aim := _new_aim_source(world, -PI / 2.0)
	var pistol := await _new_pistol(world, _data, aim)
	_check(pistol.try_fire(), "выстрел произведён")

	var bullets := _live_projectiles(aim)
	_check(bullets.size() == 1, "создан один снаряд", "(got %d)" % bullets.size())
	if bullets.size() == 1:
		var bullet := bullets[0]
		var start: Vector3 = bullet.global_position
		await _await_until(func() -> bool: return bullet.global_position.distance_to(start) > 0.5, 5.0)
		var moved: Vector3 = bullet.global_position - start
		print("    пролетел %s" % moved)
		_check(moved.x > 0.5,
			"выстрел направлен вдоль повёрнутого источника, а не по оси -Z",
			"(dx=%.3f м)" % moved.x)
		_check(absf(moved.z) < 0.05,
			"и не имеет смещения по мировой оси Z",
			"(dz=%.3f м)" % moved.z)
	world.free()


## Снаряд обязан сохранять траекторию выстрела независимо от движения источника прицеливания.
func _test_shot_keeps_its_line_when_the_aim_source_moves() -> void:
	print("-- траектория: снаряд сохраняет линию при движении родителя источника прицеливания")
	var world := _new_world()
	var pivot := _new_aim_under_pivot(world)
	var aim := pivot.get_node("AimSource") as Node3D
	var pistol := await _new_pistol(world, _data, aim)
	await _settle_fire_released()
	Input.action_press("fire")
	var spawned := await _await_until(func() -> bool: return _live_projectiles(aim).size() > 0, 5.0)
	Input.action_release("fire")
	_check(spawned, "выстрел произведён через реальный ввод",
		"(получено %d снарядов)" % _live_projectiles(aim).size())
	if not spawned:
		world.free()
		return

	var bullet := _live_projectiles(aim)[0]
	_check(bullet.get_parent() == aim,
		"снаряд остаётся дочерним узлом источника прицеливания: жизненный цикл не изменился")
	var start: Vector3 = bullet.global_position
	var line := -aim.global_transform.basis.z

	pivot.rotation.y = deg_to_rad(45.0)
	pivot.position = Vector3(2.0, 0.0, 0.0)

	var worst := 0.0
	var travelled := 0.0
	for i in _TRAJECTORY_TICKS:
		await physics_frame
		if not is_instance_valid(bullet):
			break
		var offset: Vector3 = bullet.global_position - start
		worst = maxf(worst, (offset - line * offset.dot(line)).length())
		travelled = maxf(travelled, offset.dot(line))
	print("    худшее боковое отклонение %.4f м, путь вперёд %.3f м за %d тиков физики" % [
		worst, travelled, _TRAJECTORY_TICKS])
	_check(travelled > _TRAJECTORY_MIN_TRAVEL,
		"предусловие: снаряд реально летит (нулевое отклонение означает прямой выстрел)",
		"(пройдено %.3f м вдоль линии, ожидается > %.1f м)" % [travelled, _TRAJECTORY_MIN_TRAVEL])
	_check(worst <= _TRAJECTORY_DRIFT_TOLERANCE,
		"снаряд летит прямо: поворот родителя источника прицеливания не искривляет траекторию",
		"(худшее боковое отклонение %.4f м, допуск %.3f м)" % [worst, _TRAJECTORY_DRIFT_TOLERANCE])
	_check(is_instance_valid(bullet), "снаряд всё ещё существует в конце полёта")
	world.free()


## Выстрел начинается из дула оружия (Muzzle), но прицеливается через камеру игрока.
func _test_shot_starts_at_the_barrel() -> void:
	print("-- начальная точка: выстрел вылетает из дула, прицеливаясь по камере")
	var packed: PackedScene = load(_PISTOL_SCENE_PATH)
	_check(packed != null, "pistol.tscn загружается", "(%s)" % _PISTOL_SCENE_PATH)
	if packed == null:
		return
	var world := _new_world()
	var eye := _new_eye(world)
	var pistol := await _new_pistol_from_scene(world, packed, _data)

	var barrel := pistol.get_node_or_null("Muzzle") as Node3D
	_check(barrel != null,
		"pistol.tscn содержит маркер Muzzle: дуло задано в сцене, а не угадывается")
	_check(barrel != null and barrel.global_position.z < -0.1,
		"дуло расположено впереди пистолета, а не внутри рукояти",
		"(got %s)" % ("нет Muzzle" if barrel == null else str(barrel.global_position)))

	var log := _watch(pistol)
	_check(pistol.try_fire(), "выстрел произведён")
	_check(log.fired == 1, "сигнал fired испущен ровно один раз", "(got %d)" % log.fired)
	var bullets := _live_projectiles(eye)
	_check(bullets.size() == 1, "один снаряд создан под камерой",
		"(got %d)" % bullets.size())
	if bullets.size() == 1 and barrel != null:
		var bullet := bullets[0]
		_check(bullet.global_position.distance_to(barrel.global_position) < 0.001,
			"выстрел начинается в позиции дула, а не в позиции камеры",
			"(снаряд в %s, дуло в %s, глаз в %s)" % [
				str(bullet.global_position), str(barrel.global_position), str(eye.global_position)])
		_check(bullet.global_position.distance_to(eye.global_position) > 0.1,
			"выстрел визуально происходит не из глаза игрока",
			"(%.3f м от глаза)" % bullet.global_position.distance_to(eye.global_position))
		var start: Vector3 = bullet.global_position
		await _await_until(func() -> bool: return bullet.global_position.distance_to(start) > 0.5, 5.0)
		var moved: Vector3 = bullet.global_position - start
		_check(moved.normalized().dot(-eye.global_transform.basis.z) > 0.99,
			"но снаряд прицелен по камере, а не по оси дула",
			"(%.3f м вдоль %.3f м оси направления камеры)" % [
				moved.length(), moved.normalized().dot(-eye.global_transform.basis.z)])
	world.free()

	# Проверка fallback: пистолет без маркера дула всё равно стреляет из позиции камеры
	var bare_world := _new_world()
	var bare_eye := _new_eye(bare_world)
	var bare := await _new_pistol(bare_world, _data, null)
	_check(bare.get_node_or_null("Muzzle") == null,
		"предусловие: пистолет без маркера дула действительно его не имеет")
	_check(bare.try_fire(), "пистолет без маркера дула успешно стреляет")
	var bare_bullets := _live_projectiles(bare_eye)
	_check(bare_bullets.size() == 1, "его снаряд прикреплён к камере",
		"(got %d)" % bare_bullets.size())
	if bare_bullets.size() == 1:
		_check(bare_bullets[0].global_position.distance_to(bare_eye.global_position) < 0.001,
			"и откатывается к стрельбе из камеры вместо отказа от выстрела",
			"(снаряд в %s, глаз в %s)" % [
				str(bare_bullets[0].global_position), str(bare_eye.global_position)])
	bare_world.free()


## Кнопка огня, уже зажатая при входе пистолета в дерево сцены, не должна приводить к выстрелу.
func _test_no_shot_while_the_button_is_down_on_entry() -> void:
	print("-- запуск: зажатая на входе кнопка огня не производит спонтанного выстрела")
	Input.action_press("fire")
	var world := _new_world()
	var pistol := _PistolProbe.new()
	pistol.name = "Pistol"
	pistol.data = _data
	pistol.fire_rate_source = _new_aim_source(world)
	pistol.projectile_scene = _projectile_scene
	var log := _watch(pistol)
	world.add_child(pistol)
	for i in 8:
		await process_frame
		if pistol.is_node_ready():
			break
	_check(pistol.gate_mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"предусловие: гейт ввода открыт, выстрел сдерживается только защёлкой кнопки")

	for i in _NO_SHOT_WATCH_SECONDS * 60:
		await process_frame
	_check(log.fired == 0,
		"оружие, вошедшее в дерево с зажатой кнопкой, не производит выстрелов",
		"(выстрелов %d, магазин %d из %d)" % [log.fired, pistol.current_mag(), _EXPECTED_MAGAZINE])
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE,
		"все патроны в магазине сохранены", "(got %d)" % pistol.current_mag())

	# Реакция игрока: отпустить и нажать снова
	Input.action_release("fire")
	await process_frame
	await process_frame
	Input.action_press("fire")
	var answered := await _await_until(func() -> bool: return log.fired > 0, 2.0)
	Input.action_release("fire")
	await process_frame
	_check(answered, "выстрел происходит при следующем реальном нажатии",
		"(got %d выстрелов)" % log.fired)
	_check(log.fired == 1, "произведён ровно один выстрел, без очереди",
		"(got %d выстрелов)" % log.fired)
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
		"израсходован ровно один патрон", "(got %d)" % pistol.current_mag())
	world.free()


## Полный магазин расходуется до нуля, затем выстрел блокируется.
## Перезарядка не начинается автоматически: только по клавише R через гейт ввода.
func _test_empty_magazine_and_manual_reload() -> void:
	print("-- полный магазин, пустой магазин и ручная перезарядка по R")
	var world := _new_world()
	var aim := _new_aim_source(world)
	var pistol := await _new_pistol(world, _data, aim)
	var log := _watch(pistol)

	await _settle_fire_released()
	Input.action_press("fire")
	var emptied := await _await_until(func() -> bool: return log.fired >= _EXPECTED_MAGAZINE, 20.0)
	_check(emptied, "удержание огня опустошает магазин за %d выстрелов" % _EXPECTED_MAGAZINE,
		"(got %d)" % log.fired)

	_check(pistol.current_mag() == 0, "магазин пуст",
		"(got %d)" % pistol.current_mag())
	_check(not pistol.can_fire(), "can_fire() возвращает false при пустом магазине")
	_check(not pistol.try_fire(), "try_fire() отклоняется при пустом магазине")
	_check(pistol.current_mag() == 0, "отклонённый выстрел оставляет магазин на 0",
		"(got %d)" % pistol.current_mag())
	_check(log.fired == _EXPECTED_MAGAZINE,
		"лишних выстрелов сверх ёмкости магазина не произошло", "(got %d signals)" % log.fired)

	# Отсутствие автоматической перезарядки: магазин пуст, кнопка отпущена
	Input.action_release("fire")
	var quiet_until := _now_ms() + 300
	while _now_ms() < quiet_until:
		await process_frame
	_check(log.reload_started == 0,
		"пустой магазин НЕ запускает перезарядку автоматически",
		"(got %d reloads)" % log.reload_started)
	_check(pistol.is_reloading() == false, "пистолет самостоятельно не перезаряжается")
	_check(pistol.current_mag() == 0, "магазин всё ещё пуст",
		"(got %d)" % pistol.current_mag())

	# Гейт ввода: при свободном курсоре R блокируется
	pistol.gate_mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.parse_input_event(_reload_key_event(true))
	Input.flush_buffered_events()
	await physics_frame
	Input.parse_input_event(_reload_key_event(false))
	Input.flush_buffered_events()
	await physics_frame
	_check(log.reload_started == 0,
		"нажатие R при свободном курсоре не начинает перезарядку",
		"(got %d reloads)" % log.reload_started)
	_check(not pistol.is_reloading(), "пистолет остаётся в покое, а не в перезарядке")

	# Захват курсора: перезарядка разрешена
	pistol.gate_mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.parse_input_event(_reload_key_event(true))
	Input.flush_buffered_events()
	var started := await _await_until(func() -> bool: return log.reload_started > 0, 5.0)
	Input.parse_input_event(_reload_key_event(false))
	Input.flush_buffered_events()
	_check(started, "нажатие R при захваченном курсоре начинает перезарядку")
	_check(pistol.is_reloading(), "пистолет сообщает о состоянии перезарядки")
	_check(log.reload_started == 1, "сигнал reload_started испущен ровно один раз",
		"(got %d)" % log.reload_started)

	# Зажатая кнопка огня во время перезарядки не должна тратить патроны
	await _settle_fire_released()
	Input.action_press("fire")
	var leaked := await _await_until(func() -> bool: return log.fired > _EXPECTED_MAGAZINE, 0.4)
	_check(not leaked, "зажатый огонь не производит выстрелов при пустом магазине",
		"(got %d)" % log.fired)

	Input.action_release("fire")
	var finished := await _await_until(func() -> bool: return log.reload_finished > 0)
	_check(finished, "перезарядка завершилась")
	if finished:
		var elapsed := log.reload_duration()
		print("    перезарядка заняла %.3f с" % elapsed)
		_check(elapsed >= _EXPECTED_RELOAD_TIME - _TIMER_EPSILON
				and elapsed <= _EXPECTED_RELOAD_TIME + _TIMER_TOLERANCE,
			"перезарядка заняла около %.1f с" % _EXPECTED_RELOAD_TIME,
			"(got %.3f с, tol +%.2f с)" % [elapsed, _TIMER_TOLERANCE])
		_check(pistol.current_mag() == _EXPECTED_MAGAZINE,
			"магазин снова полон", "(got %d)" % pistol.current_mag())
		_check(not pistol.is_reloading(), "пистолет больше не находится в перезарядке")
		_check(log.reload_finished == 1, "сигнал reload_finished испущен ровно один раз",
			"(got %d)" % log.reload_finished)
		_check(log.last_magazine() == Vector2i(_EXPECTED_MAGAZINE, _EXPECTED_MAGAZINE),
			"magazine_changed сообщил о полном магазине",
			"(got %s)" % str(log.magazine))
		_check(pistol.can_fire(), "после перезарядки пистолет снова готов стрелять")

		Input.action_press("fire")
		var resumed := await _await_until(func() -> bool: return log.fired > _EXPECTED_MAGAZINE, 2.0)
		Input.action_release("fire")
		_check(resumed, "нажатие сразу после перезарядки производит выстрел без задержек",
			"(got %d shots)" % log.fired)
		_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
			"этот выстрел израсходовал ровно один патрон", "(got %d)" % pistol.current_mag())
	world.free()


## Перезарядка блокирует стрельбу даже из частично заполненного магазина и не может быть перезапущена повторно.
func _test_reload_blocks_firing_and_cannot_be_restarted() -> void:
	print("-- перезарядка: отсутствие выстрелов из непустого магазина и невозможность сброса таймера")
	var world := _new_world()
	var aim := _new_aim_source(world)
	var pistol := await _new_pistol(world, _data, aim)
	var log := _watch(pistol)

	pistol.try_fire()
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
		"предусловие: в магазине остался неполный боезапас", "(got %d)" % pistol.current_mag())
	_check(pistol.start_reload(), "неполный магазин принимает команду перезарядки")
	_check(pistol.is_reloading(), "пистолет сообщает о состоянии перезарядки")
	_check(log.reload_started == 1, "сигнал reload_started испущен один раз", "(got %d)" % log.reload_started)

	await _settle_fire_released()
	Input.action_press("fire")
	var halfway := await _await_until(func() -> bool:
		return _now_ms() - log.reload_started_at_ms >= 600, _EXPECTED_RELOAD_TIME + 1.0)
	_check(halfway, "предусловие: половина времени перезарядки прошла с зажатой кнопкой")
	_check(log.fired == 1,
		"зажатый огонь во время перезарядки не производит выстрелов даже при наличии патронов",
		"(выстрелов %d, интервал темпа %.1f с истёк во время перезарядки)" % [
			log.fired, _EXPECTED_INTERVAL])

	# Попытка повторного запуска перезарядки
	var restart_at := _now_ms()
	_check(not pistol.start_reload(),
		"start_reload() отклоняет повторный запуск уже идущей перезарядки")
	_check(pistol.is_reloading(), "отклонённый перезапуск не отменил текущую перезарядку")
	Input.action_release("fire")

	var finished := await _await_until(func() -> bool: return log.reload_finished > 0)
	_check(finished, "перезарядка успешно завершилась")
	if finished:
		var total := log.reload_duration()
		var left_at_restart := float(log.reload_finished_at_ms - restart_at) / 1000.0
		print("    перезарядка заняла %.3f с; оставалось %.3f с после отклонённого перезапуска" % [
			total, left_at_restart])
		_check(total >= _EXPECTED_RELOAD_TIME - _TIMER_EPSILON
				and total <= _EXPECTED_RELOAD_TIME + _TIMER_TOLERANCE,
			"суммарно перезарядка заняла около %.1f с" % _EXPECTED_RELOAD_TIME,
			"(got %.3f с)" % total)
		_check(left_at_restart < _EXPECTED_RELOAD_TIME - 0.2,
			"отклонённый перезапуск не сбросил таймер к началу",
			"(оставалось %.3f с после попытки перезапуска на 0.6 с, ожидалось < %.2f с)" % [
				left_at_restart, _EXPECTED_RELOAD_TIME - 0.2])
		_check(log.reload_started == 1, "по-прежнему начата ровно одна перезарядка",
			"(got %d)" % log.reload_started)
		_check(log.fired == 1,
			"во время перезарядки не вылетело ни одной пули",
			"(got %d shots)" % log.fired)
		_check(pistol.current_mag() == _EXPECTED_MAGAZINE,
			"перезарядка полностью заполнила магазин", "(got %d)" % pistol.current_mag())
	world.free()


## Ограничение темпа стрельбы задаётся в секундах и берётся из данных оружия.
func _test_fire_rate() -> void:
	print("-- ограничение темпа: интервал составляет %.1f с из данных" % _EXPECTED_INTERVAL)
	var world := _new_world()
	var pistol := await _new_pistol(world, _data, _new_aim_source(world))
	var log := _watch(pistol)

	_check(is_equal_approx(_data.seconds_between_shots(), _EXPECTED_INTERVAL),
		"предусловие: данные оружия требуют один выстрел каждые %.1f с" % _EXPECTED_INTERVAL,
		"(got %.4f с)" % _data.seconds_between_shots())
	var start := _now_ms()
	_check(pistol.try_fire(), "первый выстрел разрешён")
	_check(not pistol.try_fire(),
		"второй выстрел в том же кадре заблокирован ограничением темпа")
	_check(log.fired == 1, "израсходован только один патрон", "(got %d)" % log.fired)
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
		"отклонённый выстрел не уменьшил патроны", "(got %d)" % pistol.current_mag())

	var frames := 0
	var second := false
	for i in 6000:
		await process_frame
		frames += 1
		if pistol.try_fire():
			second = true
			break
	var elapsed := float(_now_ms() - start) / 1000.0
	print("    второй выстрел через %.3f с и %d кадров процесса" % [elapsed, frames])
	_check(second, "следующий выстрел разрешён после истечения интервала")
	_check(elapsed >= _EXPECTED_INTERVAL - _TIMER_EPSILON,
		"второй выстрел выждал не менее полного интервала",
		"(выждано %.3f с, ожидается >= %.2f с)" % [elapsed, _EXPECTED_INTERVAL - _TIMER_EPSILON])
	_check(elapsed <= _EXPECTED_INTERVAL + _TIMER_TOLERANCE,
		"и не задержался существенно дольше интервала",
		"(выждано %.3f с, ожидается <= %.2f с)" % [
			elapsed, _EXPECTED_INTERVAL + _TIMER_TOLERANCE])
	_check(log.fired == 2, "израсходовано ровно два патрона",
		"(got %d)" % log.fired)
	world.free()


## Действие fire не должно обходить гейт ввода: при свободном курсоре зажатый ввод
## не производит выстрелов, а захват курсора сразу возобновляет огонь.
func _test_input_gate() -> void:
	print("-- гейт ввода: стрельба блокируется при свободном курсоре")
	var world := _new_world()
	var pistol := await _new_pistol(world, _data, _new_aim_source(world))
	var log := _watch(pistol)
	_check(pistol.get_script() == _PistolProbe,
		"предусловие: тестируемый пистолет использует тестовый зонд")

	pistol.gate_mouse_mode = Input.MOUSE_MODE_VISIBLE
	_check(not pistol.can_fire(), "can_fire() возвращает false при свободном курсоре")
	_check(not pistol.try_fire(), "try_fire() отклоняется при свободном курсоре")
	# Released first, and seen released: with the gate shut the pistol must be
	# refusing for the gate's reason alone, not because the arming latch never
	# fired. That is the whole point of pinning the two rules apart.
	await _settle_fire_released()
	Input.action_press("fire")
	var gated_shot := await _await_until(func() -> bool: return log.fired > 0, 1.5)
	_check(not gated_shot, "зажатый огонь не стреляет при свободном курсоре",
		"(got %d)" % log.fired)
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE,
		"пистолет сохранил все патроны", "(got %d)" % pistol.current_mag())
	_check(log.magazine.is_empty(),
		"сигналы в интерфейс не испускались", "(got %s)" % str(log.magazine))
	Input.action_release("fire")

	pistol.gate_mouse_mode = Input.MOUSE_MODE_CAPTURED
	_check(pistol.can_fire(), "can_fire() снова true после захвата курсора")
	Input.action_press("fire")
	var opened := await _await_until(func() -> bool: return log.fired > 0, 2.0)
	_check(opened, "тот же зажатый ввод начинает стрелять сразу при открытии гейта",
		"(got %d shots)" % log.fired)
	# The gate opened halfway through a second interval; holding the button must
	# not turn that into a shot.
	var burst := await _await_until(func() -> bool: return log.fired > 1, 0.2)
	_check(not burst, "удержание огня не стреляет чаще ограничения темпа",
		"(got %d shots)" % log.fired)
	Input.action_release("fire")
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
		"разблокированное нажатие израсходовало ровно один патрон", "(got %d)" % pistol.current_mag())
	world.free()


## Попытка перезарядки полного магазина отклоняется без ошибок.
func _test_full_magazine_has_nothing_to_reload() -> void:
	print("-- полный магазин: перезарядка отклоняется за ненадобностью")
	var world := _new_world()
	var pistol := await _new_pistol(world, _data, _new_aim_source(world))
	var log := _watch(pistol)
	_check(not pistol.start_reload(), "полный магазин отклоняет перезарядку")
	_check(log.reload_started == 0, "перезарядка не объявлялась",
		"(got %d)" % log.reload_started)
	_check(not pistol.is_reloading(), "пистолет не находится в перезарядке")
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE, "магазин не изменён",
		"(got %d)" % pistol.current_mag())
	_check(pistol.try_fire(), "выстрел происходит штатно")
	_check(pistol.start_reload(), "теперь неполный магазин принимает перезарядку")
	world.free()


## Смена сцены полностью сбрасывает оружие: магазин заполнен, перезарядка отменена.
func _test_scene_change_reset() -> void:
	print("-- смена сцены: оружие сбрасывается к начальному состоянию")
	var world := _new_world()
	var pistol := await _new_pistol(world, _data, _new_aim_source(world))
	var log := _watch(pistol)

	pistol.try_fire()
	pistol.start_reload()
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
		"предусловие: магазин частично израсходован", "(got %d)" % pistol.current_mag())
	_check(pistol.is_reloading(), "предусловие: идёт процесс перезарядки")

	pistol.reset_for_scene_change()
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE,
		"магазин снова полон после смены сцены",
		"(got %d)" % pistol.current_mag())
	_check(not pistol.is_reloading(), "перезарядка отменена")
	_check(pistol.can_fire(), "пистолет снова готов к стрельбе")
	_check(log.last_magazine() == Vector2i(_EXPECTED_MAGAZINE, _EXPECTED_MAGAZINE),
		"сброс объявлен сигналом, исключая устаревшие данные в HUD",
		"(got %s)" % str(log.magazine))
	_check(log.reload_finished == 0,
		"отменённая перезарядка не испускает reload_finished", "(got %d)" % log.reload_finished)
	# The rate limit is cleared too: a scene change is not a continuation of the
	# previous one's shot.
	_check(pistol.try_fire(), "первый выстрел новой сцены не заблокирован кулдауном")
	world.free()


## Некорректные параметры ресурса оружия блокируют стрельбу без деления на ноль.
func _test_invalid_data_blocks_firing() -> void:
	print("-- некорректные данные: нулевой магазин блокирует стрельбу без деления на ноль")
	var world := _new_world()
	var aim := _new_aim_source(world)

	var stock := await _new_pistol(world, _data, aim)
	_check(stock.can_fire(),
		"предусловие: исходные данные позволяют стрелять, проверки ниже информативны")

	var zero_mag := WeaponData.new()
	zero_mag.magazine_size = 0
	var pistol := await _new_pistol(world, zero_mag, aim)
	var log := _watch(pistol)
	_check(pistol.current_mag() == 0,
		"магазин с нулевой ёмкостью начинается пустым", "(got %d)" % pistol.current_mag())
	_check(not pistol.can_fire(), "can_fire() возвращает false при нулевом размере магазина")
	_check(not pistol.try_fire(), "try_fire() отклоняется при нулевом размере магазина")
	_check(not pistol.start_reload(), "перезаряжать также нечего")
	_check(log.fired == 0, "выстрелов не произошло", "(got %d)" % log.fired)
	_check(pistol.current_mag() == 0, "патронов не появилось", "(got %d)" % pistol.current_mag())

	var zero_rate := WeaponData.new()
	zero_rate.rounds_per_minute = 0.0
	var rate_pistol := await _new_pistol(world, zero_rate, aim)
	_check(not rate_pistol.can_fire(),
		"нулевой темп стрельбы отклоняется без деления на ноль")
	world.free()


## Очередность в try_fire(): сначала создание снаряда, потом списание патрона.
func _test_missing_projectile_scene_keeps_the_round() -> void:
	print("-- сбой создания снаряда: патрон сохраняется при несостоявшемся выстреле")
	var world := _new_world()
	var pistol := await _new_pistol(world, _data, _new_aim_source(world), false)
	var log := _watch(pistol)
	_check(pistol.projectile_scene == null,
		"предусловие: у пистолета отсутствует сцена снаряда")
	_check(pistol.can_fire(), "предусловие: в остальном оружие готово к стрельбе")
	_check(not pistol.try_fire(), "пистолет без сцены снаряда не может стрелять")
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE,
		"патрон остался в магазине: создание снаряда предшествует списанию",
		"(got %d из %d)" % [pistol.current_mag(), _EXPECTED_MAGAZINE])
	_check(log.fired == 0, "несостоявшийся выстрел ничего не объявил",
		"(got %d)" % log.fired)
	_check(log.magazine.is_empty(), "состояние магазина не менялось",
		"(got %s)" % str(log.magazine))
	world.free()