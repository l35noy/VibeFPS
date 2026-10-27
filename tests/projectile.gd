extends SceneTree

## Тестовый сценарий снарядов для VibeFPS: пуля, контракт получения урона Hurtbox,
## на котором строятся враги, и два базовых правила: постоянная конечная скорость
## и регистрация ровно одного попадания.
##
## Тестовый мир собирается программно: стена на слое 1, хертбоксы на слое 4, снаряд на слое 5.
##
## Оба тестируемых скрипта загружаются через `load()` по пути.
## Физика работает на 120 Гц, скорость пули 40 м/с (1 тик = 1/3 метра).
## Все мишени имеют радиус не менее 0.5 м для гарантированного дискретного пересечения.
##
## Запуск: godot --headless --path . --script res://tests/projectile.gd
##         .\tools\run_checks.ps1 projectile

## Скрипты под тестом. Загружаются по пути (см. заголовок).
const _HURTBOX_SCRIPT_PATH := "res://entities/common/hurtbox.gd"
const _PROJECTILE_SCRIPT_PATH := "res://weapons/projectile/projectile.gd"

## Слои коллизий в виде битовых масок Godot: 1 << (n - 1).
const _LAYER_WORLD := 1 << 0
const _LAYER_PLAYER_BODY := 1 << 1
const _LAYER_ENEMY_HURTBOX := 1 << 3
const _LAYER_PROJECTILE := 1 << 4
const _LAYER_PLAYER_HURTBOX := 1 << 6

const _TICKS_PER_SECOND := 120
## Один физический тик полета в метрах.
const _STEP := 1.0 / float(_TICKS_PER_SECOND)

const _SPEED := 40.0
const _DAMAGE := 30.0

const _EPS := 0.001

## Радиус снаряда WeaponData.projectile_radius.
const _BULLET_RADIUS := 0.08
## Мишени шире одного тика (0.333 м) для надежности дискретной проверки попадания.
const _TARGET_RADIUS := 0.5
## Геометрия мира в метрах вдоль оси +X. Запуск пули происходит из начала координат.
const _WALL_FRONT := 20.0
const _NEAR_TARGET_X := 6.0
const _FAR_TARGET_X := 12.0
## Мишень вплотную к стене для проверки одновременного контакта в одном кадре.
const _FLUSH_TARGET_X := 19.5
const _FLUSH_WALL_FRONT := 19.05

## Журнал получения урона отдельным Hurtbox.
class _DamageLog extends RefCounted:
	var amounts: Array[float] = []

	func _on_damage(amount: float) -> void:
		amounts.append(amount)

	func count() -> int:
		return amounts.size()


var _failures: PackedStringArray = []
var _checks := 0
## Загружаются один раз в _initialize; узлы создаются из этих скриптов.
var _hurtbox_script: Script
var _projectile_script: Script
var _hurtbox_id := 0


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


## Завершение выполнения при невыполнении критического предусловия.
func _bail(reason: String) -> void:
	print("КРИТИЧЕСКАЯ ОШИБКА: %s" % reason)
	_finish()
	quit(1)


func _initialize() -> void:
	print("=== VibeFPS: тест снарядов и хертбоксов ===")

	_hurtbox_script = load(_HURTBOX_SCRIPT_PATH) as Script
	_projectile_script = load(_PROJECTILE_SCRIPT_PATH) as Script
	if _hurtbox_script == null:
		_bail("не удалось загрузить %s" % _HURTBOX_SCRIPT_PATH)
		return
	if _projectile_script == null:
		_bail("не удалось загрузить %s" % _PROJECTILE_SCRIPT_PATH)
		return

	await _test_script_contracts()
	await _test_layers_and_masks()
	await _test_custom_collision_mask()
	await _test_constant_speed_flight()
	await _test_direction_is_normalised_once()
	await _test_hit_hurtbox()
	await _test_hit_world_geometry()
	await _test_only_one_hit()
	await _test_lifetime_expiry()
	await _test_damage_multiplier()
	await _test_ignores_plain_areas()
	await _test_ignores_player_hurtbox()
	await _test_hits_player_hurtbox_with_custom_mask()
	await _test_two_contacts_in_one_frame()
	await _test_trail_fades()
	await _test_shared_graphic_resources()
	await _test_collision_shape_radius_sync()
	_test_source_contract()

	_finish()
	quit(1 if _failures.size() > 0 else 0)


# --------------------------------------------------------------------------
# world builders
# --------------------------------------------------------------------------

func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame


## Node names must be unique inside one parent, and every scenario puts its
## hurtboxes under the same world node.
func _next_hurtbox_id() -> int:
	_hurtbox_id += 1
	return _hurtbox_id


func _new_world() -> Node3D:
	var world := Node3D.new()
	world.name = "World"
	root.add_child(world)
	return world


func _add_sphere(parent: CollisionObject3D, radius: float) -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	parent.add_child(shape)


## Стена на слое 1 (статическая геометрия world). front_x — координата передней грани.
func _add_wall(world: Node3D, front_x: float) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = "Wall"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 6.0, 6.0)
	shape.shape = box
	wall.add_child(shape)
	wall.collision_layer = _LAYER_WORLD
	wall.collision_mask = 0
	wall.position = Vector3(front_x + 0.5, 0.0, 0.0)
	world.add_child(wall)
	return wall


func _add_hurtbox(world: Node3D, pos: Vector3, radius: float, multiplier := 1.0):
	var hurtbox = _hurtbox_script.new()
	# Уникальные имена: сценарий может содержать несколько хертбоксов.
	hurtbox.name = "Hurtbox%d" % _next_hurtbox_id()
	_add_sphere(hurtbox, radius)
	hurtbox.damage_multiplier = multiplier
	hurtbox.position = pos
	world.add_child(hurtbox)
	return hurtbox


func _add_projectile(world: Node3D, pos: Vector3, speed := _SPEED, dmg := _DAMAGE, life := 3.0):
	var bullet = _projectile_script.new()
	bullet.name = "Projectile"
	_add_sphere(bullet, _BULLET_RADIUS)
	bullet.speed = speed
	bullet.damage = dmg
	bullet.lifetime = life
	bullet.position = pos
	world.add_child(bullet)
	return bullet


## Подписка на Hurtbox для логирования полученного урона.
func _watch(hurtbox) -> _DamageLog:
	var log := _DamageLog.new()
	hurtbox.damage_taken.connect(log._on_damage)
	return log


## Ожидание удаления узла или -1 при превышении лимита тиков.
func _frames_until_free(node, cap: int) -> int:
	for i in cap:
		if not is_instance_valid(node):
			return i
		await physics_frame
	return -1


# --------------------------------------------------------------------------
# проверки
# --------------------------------------------------------------------------

## Проверка контрактов классов, базовых типов, методов и сигналов.
func _test_script_contracts() -> void:
	print("-- contracts: имена классов, базовые типы, методы и сигналы")
	_check(_hurtbox_script.get_global_name() == "Hurtbox",
		"hurtbox.gd объявляет class_name Hurtbox",
		"(получено \"%s\")" % _hurtbox_script.get_global_name())
	_check(_projectile_script.get_global_name() == "Projectile",
		"projectile.gd объявляет class_name Projectile",
		"(получено \"%s\")" % _projectile_script.get_global_name())

	var hurtbox = _hurtbox_script.new()
	var bullet = _projectile_script.new()
	_check(hurtbox is Area3D, "Hurtbox является Area3D", "(получено %s)" % _hurtbox_script.get_instance_base_type())
	_check(bullet is Area3D, "Projectile является Area3D", "(получено %s)" % _projectile_script.get_instance_base_type())
	_check(hurtbox.has_method("apply_damage"),
		"Hurtbox предоставляет метод apply_damage(amount) для снарядов")
	_check(hurtbox.has_signal("damage_taken"),
		"Hurtbox предоставляет сигнал damage_taken(amount)")
	_check(bullet.has_method("launch"),
		"Projectile предоставляет метод launch(direction)")
	_check(bullet.has_signal("hit_something"),
		"Projectile предоставляет сигнал hit_something(target)")

	var defaults := {"damage_multiplier": 1.0}
	_check(is_equal_approx(float(hurtbox.get("damage_multiplier")),
		float(defaults["damage_multiplier"])),
		"новый hurtbox имеет damage_multiplier 1.0",
		"(получено %.3f)" % float(hurtbox.get("damage_multiplier")))
	_check(is_equal_approx(float(bullet.get("speed")), _SPEED)
			and is_equal_approx(float(bullet.get("damage")), _DAMAGE)
			and is_equal_approx(float(bullet.get("lifetime")), 3.0),
		"новый projectile по умолчанию имеет параметры пистолета (40 м/с, 30 урона, 3 с)",
		"(speed=%.1f damage=%.1f lifetime=%.1f)" % [
			float(bullet.get("speed")), float(bullet.get("damage")), float(bullet.get("lifetime"))])
	hurtbox.free()
	bullet.free()


func _test_layers_and_masks() -> void:
	print("-- layers: слои коллизий и маски пересечений")
	var world := _new_world()
	var hurtbox = _add_hurtbox(world, Vector3(0.0, 0.0, -5.0), _TARGET_RADIUS)
	var bullet = _add_projectile(world, Vector3.ZERO)
	await _physics_frames(2)

	_check(int(hurtbox.collision_layer) == _LAYER_ENEMY_HURTBOX,
		"hurtbox находится на слое 4 (enemy_hurtbox)", "(получено %d)" % int(hurtbox.collision_layer))
	_check(int(hurtbox.collision_mask) == _LAYER_WORLD,
		"маска hurtbox включает только слой 1 (world)",
		"(получено %d)" % int(hurtbox.collision_mask))
	_check(int(bullet.collision_layer) == _LAYER_PROJECTILE,
		"снаряд находится на слое 5 (projectile)", "(получено %d)" % int(bullet.collision_layer))
	_check(int(bullet.collision_mask) == (_LAYER_WORLD | _LAYER_ENEMY_HURTBOX),
		"маска снаряда равна 1 | 4 (world и enemy_hurtbox)",
		"(получено %d)" % int(bullet.collision_mask))
	_check(bool(bullet.monitoring),
		"снаряд выполняет мониторинг (monitoring = true)")
	_check(not bool(bullet.monitorable),
		"снаряд не является monitorable (false)")
	_check(bool(hurtbox.monitorable),
		"hurtbox доступен для обнаружения (monitorable = true)")
	world.free()


## Проверка сохранения кастомной маски коллизий при добавлении в дерево узлов (R2).
func _test_custom_collision_mask() -> void:
	print("-- custom mask: сохранение кастомной маски коллизий при добавлении в дерево")
	var world := _new_world()

	# 1. Снаряд по умолчанию: 1 (Area3D default) преобразуется в DEFAULT_COLLISION_MASK (1 | 4 = 9)
	var bullet_default = _projectile_script.new()
	world.add_child(bullet_default)
	_check(int(bullet_default.collision_mask) == (_LAYER_WORLD | _LAYER_ENEMY_HURTBOX),
		"снаряд без кастомизации получает маску мира и хитбокса врага (9)",
		"(маска %d)" % int(bullet_default.collision_mask))
	bullet_default.free()

	# 2. Установка через target_mask сохраняется
	var bullet_target = _projectile_script.new()
	var custom_mask := _LAYER_WORLD | _LAYER_PLAYER_HURTBOX
	bullet_target.target_mask = custom_mask
	world.add_child(bullet_target)
	_check(int(bullet_target.collision_mask) == custom_mask,
		"снаряд с target_mask сохраняет маску после add_child",
		"(ожидалось %d, получено %d)" % [custom_mask, int(bullet_target.collision_mask)])
	bullet_target.free()

	# 3. Прямая установка collision_mask до add_child сохраняется
	var bullet_direct = _projectile_script.new()
	bullet_direct.collision_mask = custom_mask
	world.add_child(bullet_direct)
	_check(int(bullet_direct.collision_mask) == custom_mask,
		"снаряд с предварительно настроенным collision_mask сохраняет его в _ready",
		"(ожидалось %d, получено %d)" % [custom_mask, int(bullet_direct.collision_mask)])
	bullet_direct.free()

	# 4. Если collision_mask был 0, назначается стандартная маска
	var bullet_zero = _projectile_script.new()
	bullet_zero.collision_mask = 0
	world.add_child(bullet_zero)
	_check(int(bullet_zero.collision_mask) == (_LAYER_WORLD | _LAYER_ENEMY_HURTBOX),
		"некастомизированная маска 0 сбрасывается на дефолтную маску",
		"(маска %d)" % int(bullet_zero.collision_mask))
	bullet_zero.free()

	world.free()


## Проверка постоянной конечной скорости полета вдоль направления запуска.
func _test_constant_speed_flight() -> void:
	print("-- flight: постоянная конечная скорость вдоль направления запуска")
	var world := _new_world()
	var bullet = _add_projectile(world, Vector3.ZERO)
	await _physics_frames(2)

	var start: Vector3 = bullet.global_position
	bullet.launch(Vector3(1.0, 0.0, 0.0))
	_check(bullet.global_position.is_equal_approx(start),
		"launch() задает направление без мгновенного сдвига узла",
		"(смещение %.4f м)" % bullet.global_position.distance_to(start))

	var ticks := 60
	var worst := 0.0
	var slowest := INF
	var previous: Vector3 = bullet.global_position
	var start_position: Vector3 = start
	var y_drift := 0.0
	var z_drift := 0.0
	var crossing_tick := -1
	for i in ticks:
		await physics_frame
		var current: Vector3 = bullet.global_position
		var step := current - previous
		worst = maxf(worst, absf(step.length() - _SPEED * _STEP))
		slowest = minf(slowest, step.length())
		y_drift = maxf(y_drift, absf(current.y))
		z_drift = maxf(z_drift, absf(current.z))
		if crossing_tick < 0 and current.x - start_position.x >= 10.0:
			crossing_tick = i + 1
		previous = current

	var travelled: float = (previous - start).length()
	_check(worst <= _EPS,
		"каждый тик перемещает ровно на speed * delta: нет ускорения или замедления",
		"(худшая ошибка %.6f м за %d тиков, допуск %.4f)" % [worst, ticks, _EPS])
	_check(slowest > 0.0,
		"снаряд не останавливается ни на одном тике", "(наименьший тик %.6f м)" % slowest)
	_check(is_equal_approx(travelled, _SPEED * _STEP * float(ticks)),
		"за %d тиков снаряд преодолел расстояние speed * t" % ticks,
		"(%.4f м за %.3f с при %.1f м/с)" % [travelled, _STEP * float(ticks), _SPEED])
	_check(y_drift <= _EPS and z_drift <= _EPS,
		"траектория прямая: снаряд не отклоняется и не падает под гравитацией",
		"(снос y=%.6f z=%.6f)" % [y_drift, z_drift])
	var expected_crossing := int(round(10.0 / (_SPEED * _STEP)))
	_check(absf(float(crossing_tick) - float(expected_crossing)) <= 1.0,
		"снаряду требуется около %d тиков на первые 10 м: от него можно уклониться" % expected_crossing,
		"(пересечение на тике %d, ожидалось %d)" % [crossing_tick, expected_crossing])
	world.free()


## Проверка нормализации вектора направления при запуске.
func _test_direction_is_normalised_once() -> void:
	print("-- direction: направление нормализуется при запуске и сохраняется")
	var world := _new_world()
	var sloppy = _add_projectile(world, Vector3.ZERO)
	var steady = _add_projectile(world, Vector3(0.0, 0.0, -4.0))
	await _physics_frames(2)
	sloppy.launch(Vector3(7.0, 0.0, 0.0))
	steady.launch(Vector3(0.0, 30.0, 0.0))

	var ticks := 30
	var sloppy_start: Vector3 = sloppy.global_position
	var steady_start: Vector3 = steady.global_position
	for i in ticks:
		await physics_frame

	var sloppy_travel: Vector3 = sloppy.global_position - sloppy_start
	var steady_travel: Vector3 = steady.global_position - steady_start
	_check(is_equal_approx(sloppy_travel.length(), _SPEED * _STEP * float(ticks)),
		"вектор запуска длины 7 летит с номинальной скоростью, а не в 7 раз быстрее",
		"(%.4f м, ожидалось %.4f м)" % [
			sloppy_travel.length(), _SPEED * _STEP * float(ticks)])
	_check(sloppy_travel.is_equal_approx(Vector3(_SPEED * _STEP * float(ticks), 0.0, 0.0)),
		"ненормализованный вектор +X летит строго вдоль +X",
		"(смещение %s)" % sloppy_travel)
	_check(steady_travel.is_equal_approx(Vector3(0.0, _SPEED * _STEP * float(ticks), 0.0)),
		"снаряд, запущенный вверх, поднимается по прямой линии: без гравитации и сноса",
		"(смещение %s)" % steady_travel)
	world.free()


func _test_hit_hurtbox() -> void:
	print("-- hit: hurtbox получает урон один раз, и снаряд уничтожается")
	var world := _new_world()
	_add_wall(world, _WALL_FRONT)
	var target = _add_hurtbox(world, Vector3(_FAR_TARGET_X, 0.0, 0.0), _TARGET_RADIUS)
	var log := _watch(target)
	var hits: Array[Node] = []
	var bullet = _add_projectile(world, Vector3.ZERO)
	bullet.hit_something.connect(hits.append)
	await _physics_frames(2)

	bullet.launch(Vector3.RIGHT)
	var ticks := await _frames_until_free(bullet, 400)

	_check(log.count() == 1, "сигнал damage_taken сработал ровно один раз", "(получено %d: %s)" % [
		log.count(), str(log.amounts)])
	_check(log.count() == 1 and is_equal_approx(log.amounts[0], _DAMAGE),
		"полученный урон соответствует урону снаряда",
		"(получено %s)" % str(log.amounts))
	_check(hits.size() == 1, "сигнал hit_something сработал один раз", "(получено %d)" % hits.size())
	_check(hits.size() == 1 and hits[0] == target,
		"hit_something указывает на пораженный hurtbox",
		"(получено %s)" % ("нет" if hits.is_empty() else str(hits[0].name)))
	_check(ticks > 0 and ticks < 50,
		"снаряд уничтожен на мишени задолго до стены",
		"(удален через %d тиков; стена на %.0f м = %d тиков)" % [
			ticks, _WALL_FRONT, int(_WALL_FRONT / (_SPEED * _STEP))])
	world.free()


## Проверка попадания в геометрию мира: стена останавливает снаряд, урон не наносится.
func _test_hit_world_geometry() -> void:
	print("-- world geometry: стена останавливает снаряд, урон не наносится")
	var world := _new_world()
	var wall = _add_wall(world, _WALL_FRONT)
	var bystander = _add_hurtbox(world, Vector3(-5.0, 0.0, 0.0), _TARGET_RADIUS)
	var log := _watch(bystander)
	var hits: Array[Node] = []
	var bullet = _add_projectile(world, Vector3.ZERO)
	bullet.hit_something.connect(hits.append)
	await _physics_frames(2)

	bullet.launch(Vector3.RIGHT)
	var ticks := await _frames_until_free(bullet, 400)

	_check(ticks > 0, "снаряд попал в стену и был удален со сцены",
		"(удален через %d тиков)" % ticks)
	_check(log.count() == 0, "стена не наносит урон, и посторонние хертбоксы не затронуты",
		"(получено %d)" % log.count())
	_check(hits.size() == 1, "сигнал hit_something сработал для стены", "(получено %d)" % hits.size())
	_check(hits.size() == 1 and hits[0] == wall,
		"hit_something указывает на тело стены, а не на hurtbox",
		"(получено %s)" % ("нет" if hits.is_empty() else str(hits[0].name)))
	_check(ticks > 0 and ticks < 180,
		"снаряд остановлен стеной задолго до истечения времени жизни",
		"(удален через %d тиков, время жизни 360)" % ticks)
	world.free()


## Проверка правила одного попадания: снаряд поражает только первую цель на линии.
func _test_only_one_hit() -> void:
	print("-- only one hit: снаряд поражает только первую цель на линии")
	var world := _new_world()
	_add_wall(world, _WALL_FRONT)
	var near_target = _add_hurtbox(world, Vector3(_NEAR_TARGET_X, 0.0, 0.0), _TARGET_RADIUS)
	var far_target = _add_hurtbox(world, Vector3(_FAR_TARGET_X, 0.0, 0.0), _TARGET_RADIUS)
	var near_log := _watch(near_target)
	var far_log := _watch(far_target)
	var hits: Array[Node] = []
	var bullet = _add_projectile(world, Vector3.ZERO)
	bullet.hit_something.connect(hits.append)
	await _physics_frames(2)

	bullet.launch(Vector3.RIGHT)
	var ticks := await _frames_until_free(bullet, 400)

	_check(near_log.count() == 1, "передняя мишень получила одно попадание",
		"(получено %d: %s)" % [near_log.count(), str(near_log.amounts)])
	_check(far_log.count() == 0, "мишень позади не получила урон: снаряд уничтожен при первом попадании",
		"(получено %d: %s)" % [far_log.count(), str(far_log.amounts)])
	_check(near_log.count() + far_log.count() == 1,
		"один выстрел вызвал ровно одно событие урона во всем мире",
		"(получено %d)" % (near_log.count() + far_log.count()))
	_check(hits.size() == 1, "hit_something сработал один раз, а не на каждой цели",
		"(получено %d)" % hits.size())
	_check(ticks > 0 and ticks < 45,
		"полет завершился на ближней цели",
		"(удален через %d тиков; дальняя цель на %.0f м)" % [ticks, _FAR_TARGET_X])
	world.free()


func _test_lifetime_expiry() -> void:
	print("-- lifetime: снаряд без попадания уничтожается по таймеру")
	var world := _new_world()
	var life := 0.25
	var bullet = _add_projectile(world, Vector3.ZERO, _SPEED, _DAMAGE, life)
	await _physics_frames(2)
	bullet.launch(Vector3.RIGHT)

	var elapsed := 0
	var mid_alive := false
	var mid_position := Vector3.ZERO
	var ticks := -1
	for i in 240:
		if not is_instance_valid(bullet):
			ticks = elapsed
			break
		await physics_frame
		elapsed += 1
		if elapsed == 15:
			mid_alive = is_instance_valid(bullet)
			mid_position = bullet.global_position

	_check(mid_alive, "снаряд продолжает полет на середине времени жизни")
	_check(mid_position.x > 0.0, "снаряд действительно преодолевает дистанцию",
		"(x=%.3f м после 15 тиков)" % mid_position.x)

	var expected := int(round(life * float(_TICKS_PER_SECOND)))
	_check(ticks >= 0, "снаряд без попадания удаляется по истечении срока жизни",
		"(удален через %d тиков, ожидалось около %d)" % [ticks, expected])
	_check(ticks >= expected - 1 and ticks <= expected + 2,
		"снаряд удаляется после истечения времени жизни, а не раньше",
		"(удален через %d тиков, время жизни %.2f с = %d тиков)" % [ticks, life, expected])
	world.free()


## Проверка множителя урона damage_multiplier хертбокса.
func _test_damage_multiplier() -> void:
	print("-- damage_multiplier: множитель урона хертбокса")
	var world := _new_world()
	var weak_spot = _add_hurtbox(world, Vector3(_FAR_TARGET_X, 0.0, 0.0), _TARGET_RADIUS, 2.0)
	var half = _add_hurtbox(world, Vector3(-5.0, 0.0, 0.0), _TARGET_RADIUS, 0.5)
	var weak_log := _watch(weak_spot)
	var half_log := _watch(half)

	weak_spot.apply_damage(_DAMAGE)
	_check(weak_log.count() == 1 and is_equal_approx(weak_log.amounts[0], 2.0 * _DAMAGE),
		"apply_damage(30) выдает 60 урона при damage_multiplier 2.0",
		"(получено %s)" % str(weak_log.amounts))
	half.apply_damage(_DAMAGE)
	_check(half_log.count() == 1 and is_equal_approx(half_log.amounts[0], 0.5 * _DAMAGE),
		"apply_damage(30) выдает 15 урона при damage_multiplier 0.5",
		"(получено %s)" % str(half_log.amounts))
	# Hurtbox не хранит здоровье: три попадания — три сигнала.
	weak_spot.apply_damage(_DAMAGE)
	weak_spot.apply_damage(_DAMAGE)
	_check(weak_log.count() == 3, "hurtbox не хранит здоровье: три попадания — три сигнала",
		"(получено %d)" % weak_log.count())
	_check(weak_log.count() == 3 and is_equal_approx(weak_log.amounts[2], 2.0 * _DAMAGE),
		"каждый сигнал содержит урон с учетом множителя",
		"(получено %s)" % str(weak_log.amounts))

	# Проверка через реальный снаряд.
	var bullet = _add_projectile(world, Vector3.ZERO)
	await _physics_frames(2)
	bullet.launch(Vector3.RIGHT)
	await _frames_until_free(bullet, 400)
	_check(weak_log.count() == 4 and is_equal_approx(weak_log.amounts[3], 2.0 * _DAMAGE),
		"попадание пули в hurtbox x2 наносит удвоенный урон: множитель учитывается",
		"(получено %s)" % str(weak_log.amounts))
	_check(weak_log.count() == 4 and is_equal_approx(weak_log.amounts[3], _DAMAGE * weak_spot.damage_multiplier),
		"снаряд передает базовый урон, а hurtbox умножает его",
		"(получено %.3f)" % (weak_log.amounts[3] if weak_log.count() == 4 else NAN))
	world.free()


## Обычные Area3D на том же слое не должны перехватывать пулю или получать урон.
func _test_ignores_plain_areas() -> void:
	print("-- plain areas: обычные Area3D на том же слое не получают урон и не останавливают пулю")
	var world := _new_world()
	_add_wall(world, _WALL_FRONT)
	var decoy := Area3D.new()
	decoy.name = "DecoyArea"
	_add_sphere(decoy, _TARGET_RADIUS)
	decoy.collision_layer = _LAYER_ENEMY_HURTBOX
	decoy.position = Vector3(_NEAR_TARGET_X, 0.0, 0.0)
	world.add_child(decoy)
	var real_target = _add_hurtbox(world, Vector3(_FAR_TARGET_X, 0.0, 0.0), _TARGET_RADIUS)
	var log := _watch(real_target)

	var overlapped: Array[Node] = []
	var hits: Array[Node] = []
	var bullet = _add_projectile(world, Vector3.ZERO)
	bullet.area_entered.connect(overlapped.append)
	bullet.hit_something.connect(hits.append)
	await _physics_frames(2)
	_check(int(decoy.collision_layer) == _LAYER_ENEMY_HURTBOX,
		"предусловие: ложная зона действительно на слое hurtbox")

	bullet.launch(Vector3.RIGHT)
	await _frames_until_free(bullet, 400)

	_check(overlapped.has(decoy),
		"предусловие: снаряд действительно пересек ложную зону",
		"(пересечено зон: %d)" % overlapped.size())
	_check(log.count() == 1, "хертбокс позади ложной зоны успешно получил урон",
		"(получено %d)" % log.count())
	_check(hits.size() == 1 and hits[0] == real_target,
		"обычная зона не является целью: она не получает урон и не уничтожает снаряд",
		"(зафиксировано %s)" % ("ничего" if hits.is_empty() else str(hits[0].name)))
	world.free()


## Хертбокс игрока на слое 7 не должен поражаться собственными пулями.
func _test_ignores_player_hurtbox() -> void:
	print("-- player hurtbox: хертбокс игрока не является целью для собственных пуль")
	var world := _new_world()
	_add_wall(world, _WALL_FRONT)
	var player_hurtbox = _add_hurtbox(world, Vector3(_NEAR_TARGET_X, 0.0, 0.0), _TARGET_RADIUS)
	player_hurtbox.collision_layer = _LAYER_PLAYER_HURTBOX
	var enemy_hurtbox = _add_hurtbox(world, Vector3(_FAR_TARGET_X, 0.0, 0.0), _TARGET_RADIUS)
	var player_log := _watch(player_hurtbox)
	var enemy_log := _watch(enemy_hurtbox)
	var hits: Array[Node] = []
	var bullet = _add_projectile(world, Vector3.ZERO)
	bullet.hit_something.connect(hits.append)
	await _physics_frames(2)
	_check(int(player_hurtbox.collision_layer) == _LAYER_PLAYER_HURTBOX,
		"предусловие: первый хертбокс находится на слое 7 (player_hurtbox)")

	bullet.launch(Vector3.RIGHT)
	var ticks := await _frames_until_free(bullet, 400)

	_check(player_log.count() == 0, "хертбокс на слое игрока не получает урон",
		"(получено %d: %s)" % [player_log.count(), str(player_log.amounts)])
	_check(enemy_log.count() == 1, "снаряд пролетел мимо игрока и поразил врага",
		"(получено %d)" % enemy_log.count())
	_check(hits.size() == 1 and hits[0] == enemy_hurtbox,
		"в сигнале hit_something зарегистрирован только хертбокс врага",
		"(зафиксировано %s)" % ("ничего" if hits.is_empty() else str(hits[0].name)))
	_check(ticks > 0 and ticks < 50,
		"снаряд не уничтожился о хертбокс игрока",
		"(удален через %d тиков)" % ticks)
	world.free()


## Проверка возможности поражения хертбокса игрока снарядом с соответствующей маской (R2).
func _test_hits_player_hurtbox_with_custom_mask() -> void:
	print("-- hit player hurtbox: снаряд с маской игрока поражает хертбокс игрока")
	var world := _new_world()
	_add_wall(world, _WALL_FRONT)
	var player_hurtbox = _add_hurtbox(world, Vector3(_NEAR_TARGET_X, 0.0, 0.0), _TARGET_RADIUS)
	player_hurtbox.collision_layer = _LAYER_PLAYER_HURTBOX
	var enemy_hurtbox = _add_hurtbox(world, Vector3(_FAR_TARGET_X, 0.0, 0.0), _TARGET_RADIUS)
	var player_log := _watch(player_hurtbox)
	var enemy_log := _watch(enemy_hurtbox)
	var hits: Array[Node] = []

	var bullet = _projectile_script.new()
	bullet.name = "EnemyProjectile"
	_add_sphere(bullet, _BULLET_RADIUS)
	bullet.speed = _SPEED
	bullet.damage = _DAMAGE
	bullet.lifetime = 3.0
	bullet.target_mask = _LAYER_WORLD | _LAYER_PLAYER_HURTBOX
	bullet.position = Vector3.ZERO
	bullet.hit_something.connect(hits.append)
	world.add_child(bullet)
	await _physics_frames(2)

	_check(int(bullet.collision_mask) == (_LAYER_WORLD | _LAYER_PLAYER_HURTBOX),
		"маска снаряда настроена на мир и хертбокс игрока (65)",
		"(маска %d)" % int(bullet.collision_mask))

	bullet.launch(Vector3.RIGHT)
	await _frames_until_free(bullet, 400)

	_check(player_log.count() == 1,
		"хертбокс игрока успешно получил урон от вражеского снаряда",
		"(получено %d)" % player_log.count())
	_check(player_log.count() == 1 and is_equal_approx(player_log.amounts[0], _DAMAGE),
		"урон хертбоксу игрока равен урону снаряда",
		"(получено %s)" % str(player_log.amounts))
	_check(enemy_log.count() == 0,
		"вражеский хертбокс за игроком не получил урон: снаряд потрачен на игроке",
		"(получено %d)" % enemy_log.count())
	_check(hits.size() == 1 and hits[0] == player_hurtbox,
		"сигнал hit_something зарегистрировал попадание в хертбокс игрока",
		"(зафиксировано %s)" % ("ничего" if hits.is_empty() else str(hits[0].name)))
	world.free()


## Проверка одновременного контакта с зоной и телом в одном кадре.
func _test_two_contacts_in_one_frame() -> void:
	print("-- same frame: одновременный контакт с зоной и телом в одном кадре дает ровно одно попадание")
	var world := _new_world()
	_add_wall(world, _FLUSH_WALL_FRONT)
	var flush_target = _add_hurtbox(world, Vector3(_FLUSH_TARGET_X, 0.0, 0.0), _TARGET_RADIUS)
	var log := _watch(flush_target)
	var hits: Array[Node] = []
	var area_frame := [-1]
	var body_frame := [-1]
	var bullet = _add_projectile(world, Vector3.ZERO)
	bullet.area_entered.connect(func(_a): area_frame[0] = Engine.get_physics_frames())
	bullet.body_entered.connect(func(_b): body_frame[0] = Engine.get_physics_frames())
	bullet.hit_something.connect(hits.append)
	await _physics_frames(2)

	bullet.launch(Vector3.RIGHT)
	await _frames_until_free(bullet, 400)

	_check(area_frame[0] >= 0, "предусловие: снаряд вошел в хертбокс",
		"(area_entered на кадре %d)" % area_frame[0])
	_check(body_frame[0] >= 0, "предусловие: снаряд вошел в стену",
		"(body_entered на кадре %d)" % body_frame[0])
	_check(area_frame[0] == body_frame[0],
		"предусловие: оба контакта зафиксированы в одном физическом кадре",
		"(зона на кадре %d, тело на кадре %d)" % [area_frame[0], body_frame[0]])
	_check(hits.size() == 1, "зарегистрирован ровно один контакт, даже если два произошли одновременно",
		"(получено %d)" % hits.size())
	_check(log.count() <= 1, "урон наносится не более одного раза при двойном контакте",
		"(получено %d)" % log.count())
	world.free()


## Затухание прозрачности шлейфа со временем жизни снаряда.
func _test_trail_fades() -> void:
	print("-- trail: альфа-канал шлейфа угасает по мере жизни снаряда")
	var world := _new_world()
	var life := 0.4
	var bullet = _add_projectile(world, Vector3.ZERO, _SPEED, _DAMAGE, life)
	await _physics_frames(2)

	var trail = bullet.get_node_or_null("Trail") as MeshInstance3D
	_check(trail != null, "снаряд содержит дочерний узел шлейфа MeshInstance3D")
	if trail != null:
		var material := trail.material_override as StandardMaterial3D
		_check(material != null, "шлейф имеет материал для затухания")
		if material != null:
			_check(material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
				"материал шлейфа поддерживает альфа-прозрачность",
				"(transparency=%d)" % material.transparency)
			var start_alpha: float = material.albedo_color.a * (1.0 - trail.transparency)
			_check(start_alpha > 0.0, "шлейф изначально видим", "(alpha=%.3f)" % start_alpha)
			bullet.launch(Vector3.RIGHT)
			await _physics_frames(20)
			var mid_alpha: float = material.albedo_color.a * (1.0 - trail.transparency)
			_check(mid_alpha < start_alpha,
				"шлейф затухает во время полета снаряда",
				"(alpha %.3f -> %.3f после 20 из %d тиков)" % [
					start_alpha, mid_alpha, int(life * float(_TICKS_PER_SECOND))])
			_check(mid_alpha > 0.0, "затухание постепенное, снаряд не исчезает мгновенно",
				"(alpha=%.3f)" % mid_alpha)
			await _physics_frames(26)
			var end_alpha: float = material.albedo_color.a * (1.0 - trail.transparency)
			_check(end_alpha < mid_alpha,
				"затухание продолжается до конца времени жизни",
				"(alpha %.3f -> %.3f)" % [mid_alpha, end_alpha])
	world.free()


## Проверка разделения графических ресурсов (SphereMesh и StandardMaterial3D) между выстрелами (R6).
func _test_shared_graphic_resources() -> void:
	print("-- graphic resources: повторные выстрелы используют один и тот же инстанс SphereMesh и StandardMaterial3D")
	var world := _new_world()
	var bullet1 = _add_projectile(world, Vector3(0.0, 0.0, 0.0))
	var bullet2 = _add_projectile(world, Vector3(0.0, 1.0, 0.0))
	await _physics_frames(2)

	var trail1 = bullet1.get_node_or_null("Trail") as MeshInstance3D
	var trail2 = bullet2.get_node_or_null("Trail") as MeshInstance3D
	_check(trail1 != null and trail2 != null,
		"оба снаряда содержат узел Trail MeshInstance3D")
	if trail1 != null and trail2 != null:
		var mesh1 := trail1.mesh as SphereMesh
		var mesh2 := trail2.mesh as SphereMesh
		_check(mesh1 != null and mesh2 != null,
			"оба шлейфа имеют SphereMesh")
		_check(mesh1 == mesh2,
			"повторные выстрелы одного радиуса разделяют один и тот же инстанс SphereMesh без duplicate()",
			"(mesh1: %s, mesh2: %s)" % [str(mesh1), str(mesh2)])
		var mat1 := trail1.material_override as StandardMaterial3D
		var mat2 := trail2.material_override as StandardMaterial3D
		_check(mat1 != null and mat2 != null,
			"оба шлейфа имеют StandardMaterial3D")
		_check(mat1 == mat2,
			"снаряды одного цвета разделяют один и тот же экземпляр StandardMaterial3D",
			"(mat1: %s, mat2: %s)" % [str(mat1), str(mat2)])

	# Снаряд с другим радиусом получает отдельный меш из кэша
	var bullet3 = _projectile_script.new()
	bullet3.radius = 0.12
	world.add_child(bullet3)
	await _physics_frames(2)
	var trail3 = bullet3.get_node_or_null("Trail") as MeshInstance3D
	if trail3 != null and trail1 != null:
		_check(trail3.mesh != trail1.mesh,
			"снаряд с другим калибром использует отдельный меш соответствующего радиуса")
	bullet3.free()

	world.free()


## Проверка исходного кода projectile.gd на отсутствие твинов и корректное использование set_deferred.
func _test_source_contract() -> void:
	print("-- source contract: проверка кода projectile.gd на отсутствие Tween и корректный deferred-вызов")
	var source := FileAccess.get_file_as_string(_PROJECTILE_SCRIPT_PATH)
	_check(source != "", "файл projectile.gd доступен для чтения", "(%d байт)" % source.length())
	var tween_apis := ["create_tween", "Tween.new", "tween_property("]
	var used := PackedStringArray()
	for api in tween_apis:
		if source.contains(api):
			used.append(api)
	_check(used.is_empty(),
		"projectile.gd не создает твины: шлейф должен удаляться вместе со снарядом",
		"(найдено: %s)" % ("ничего" if used.is_empty() else str(used)))
	_check(source.contains("set_deferred(\"monitoring\""),
		"projectile.gd отключает monitoring через set_deferred, а не напрямую в обработчике")


## Проверка синхронизации радиуса коллизии CollisionShape3D со значением projectile.radius (120 Гц контракт).
func _test_collision_shape_radius_sync() -> void:
	print("-- collision shape sync: проверка синхронизации радиуса формы коллизии с размером снаряда")
	var scene := load("res://weapons/projectile/projectile.tscn") as PackedScene
	_check(scene != null, "сцена res://weapons/projectile/projectile.tscn существует")
	if scene == null:
		return

	var p1 := scene.instantiate() as Projectile
	root.add_child(p1)
	await _physics_frames(2)

	var shape_node := p1.get_node_or_null("Shape") as CollisionShape3D
	_check(shape_node != null and shape_node.shape is SphereShape3D,
		"снаряд содержит узел Shape с формой SphereShape3D")
	if shape_node != null and shape_node.shape is SphereShape3D:
		var orig_radius: float = (shape_node.shape as SphereShape3D).radius
		_check(is_equal_approx(orig_radius, 0.05), "начальный радиус коллизии равен 0.05 м", "(получено %.3f)" % orig_radius)

		# Изменяем радиус снаряда: форма коллизии должна синхронизироваться
		p1.radius = 0.15
		var updated_radius: float = (shape_node.shape as SphereShape3D).radius
		_check(is_equal_approx(updated_radius, 0.15),
			"сеттер radius обновляет радиус CollisionShape3D до 0.15 м", "(получено %.3f)" % updated_radius)

		# Проверяем изоляцию формы: второй снаряд не должен пострадать от изменения первого
		var p2 := scene.instantiate() as Projectile
		root.add_child(p2)
		await _physics_frames(2)
		var p2_shape := (p2.get_node("Shape") as CollisionShape3D).shape as SphereShape3D
		_check(is_equal_approx(p2_shape.radius, 0.05),
			"изменение радиуса одного снаряда не затрагивает другие инстансы (изоляция duplicate())",
			"(получено %.3f)" % p2_shape.radius)
		p2.free()

	p1.free()