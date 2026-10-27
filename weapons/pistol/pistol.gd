class_name Pistol
extends Node3D

## Пистолет: магазин, темп стрельбы, перезарядка, огонь.
##
## Характеристики приходят из `WeaponData`, поведение живёт здесь. Одно
## оружие — один скрипт, параметризованный ресурсом: второго оружия в Фазе 1
## нет, а иерархия «под будущее» — это код, который никто не запускает.
##
## Восемь решений, каждое из которых проверка закрепляет:
##
## 1. Порядок внутри `try_fire()`: сначала проверки, потом инстанцирование
##    снаряда, и только потом уменьшение магазина. Обратный порядок съедает
##    патрон на провалившемся инстанцировании — игрок теряет пулю, которую
##    не стрелял. Промахнуться можно легко: сцена не назначена, сцена указывает
##    не на тот узел.
## 2. Перезарядку нельзя перезапустить. Перезапуск сбрасывает таймер, а
##    значит игрок, нажимая перезарядку на пустом магазине, откладывает её
##    бесконечно. Поэтому `start_reload()` отказывает, когда перезарядка уже
##    идёт, и не трогает таймер.
## 3. Темп стрельбы — это секунды (`data.seconds_between_shots()`), а не
##    кадры. 150 выстр./мин это один выстрел за 0.4 с при любой частоте кадров;
##    счётчик кадров на 240 Гц превратил бы пистолет в автомат.
## 4. `_process`, а не физический тик: стрельба — игровое действие с частотой
##    кадров рендера, а не часть физической симуляции. Таймеры при этом всё
##    равно в секундах, поэтому правило темпа от выбора функции не зависит.
## 5. Гейт ввода тот же, что у движения: действие `fire` не должно обходить
##    его, иначе пистолет стреляет при отпущенном курсоре, пока остальной
##    персонаж стоит.
## 6. Перезарядку инициирует игрок клавишей R, а не пустой магазин. Пистолет не
##    перезаряжается сам: пустой магазин остаётся пустым и молчит, пока игрок
##    не попросит. Действие `reload` проходит через тот же гейт ввода, что и
##    огонь, поэтому при свободном курсоре R не перезаряжает.
## 7. Точка старта снаряда и точка прицеливания — разные узлы (`_muzzle()` и
##    `_spawn_point()`): направление задаёт прицел, а вылетать пуля должна из
##    ствола, иначе она вылетает из головы игрока.
## 8. Защёлка взведения (`_armed`): первый выстрел возможен только после того,
##    как оружие увидело отпущенную кнопку. ЛКМ может быть зажат ещё до входа
##    в дерево, и уровневый опрос без взведения превращает это в бесплатный
##    выстрел на каждом старте уровня.

## Выстрел произошёл. Один сигнал — одна пуля, в том числе когда попадание
## не принесло урона.
signal fired()
## Перезарядка началась.
signal reload_started()
## Перезарядка закончилась, магазин полон.
signal reload_finished()
## Изменилось число патронов. Сигнал об изменении, а не о существовании:
## начальное состояние читается через `current_mag()`.
signal magazine_changed(current: int, capacity: int)

## Характеристики: темп, ёмкость, время перезарядки, урон и параметры снаряда.
@export var data: WeaponData
## Сцена снаряда для инстанцирования. Без неё оружие не стреляет, но и не
## тратит патроны.
@export var projectile_scene: PackedScene
## Откуда ЦЕЛИТЬСЯ. По умолчанию — камера игрока: выстрел должен уходить туда,
## куда смотрит глаз, а не туда, где висит оружие.
##
## Это направление, а не точка старта: снаряд выпускается из `_spawn_point()`
## (ствол). Узел остаётся и родителем снаряда — за это отвечает его жизненный
## цикл, а не позиция.
@export var fire_rate_source: Node3D

## Осталось патронов.
var _current: int = 0
## Сколько секунд осталось до конца перезарядки; 0 — перезарядки нет.
var _reload_remaining: float = 0.0
## Сколько секунд осталось до следующего выстрела.
var _cooldown: float = 0.0
## Взведён ли огонь. Пока ложь, кнопку огня можно держать сколько угодно и
## выстрела не будет: первый настоящий выстрел — после первого наблюдаемого
## отпускания. Подробность в _process().
var _armed := false

## Начальные локальные трансформации дочерних мешей для процедурной отдачи.
var _mesh_initial_transforms: Dictionary = {}
var _recoil_offset: Vector3 = Vector3.ZERO
var _recoil_rotation: float = 0.0


func _ready() -> void:
	# Полный магазин при появлении оружия. magazine_changed здесь не
	# испускается: HUD читает начальное состояние через current_mag().
	_current = _capacity()
	_cache_mesh_transforms()


func _process(delta: float) -> void:
	# 1. Темп стрельбы. Секунды, поэтому частота кадров на скорострельность не
	#    влияет, а maxf не даёт таймеру уйти в отрицательные значения.
	_cooldown = maxf(0.0, _cooldown - delta)

	# 2. Перезарядка.
	if _reload_remaining > 0.0:
		_reload_remaining -= delta
		if _reload_remaining <= 0.0:
			_reload_remaining = 0.0
			_complete_reload()

	# 3. Процедурная отдача оружия: плавное возвращение дочерних мешей в покой
	if _recoil_offset.length_squared() > 0.000001 or absf(_recoil_rotation) > 0.0001:
		var decay := clampf(delta * 16.0, 0.0, 1.0)
		_recoil_offset = _recoil_offset.lerp(Vector3.ZERO, decay)
		_recoil_rotation = lerpf(_recoil_rotation, 0.0, decay)
		for mesh in _mesh_initial_transforms:
			if is_instance_valid(mesh):
				var init_t: Transform3D = _mesh_initial_transforms[mesh]
				var t := init_t
				t.origin += _recoil_offset
				t.basis = init_t.basis.rotated(Vector3.RIGHT, _recoil_rotation)
				(mesh as MeshInstance3D).transform = t

	# 4. Действие огня. try_fire() внутри спрашивает гейт ввода, поэтому
	#    нажатая кнопка при отпущенном курсоре выстрела не даёт.
	#
	#    Защёлка взведения — обязательна перед выстрелом. Мышь захватывается
	#    раньше первого _process (player.gd::_ready()), а перезарядка и темп
	#    стрельбы стартуют с нуля, поэтому остаточный бит ЛКМ на кадре 0 без
	#    взведения даёт бесплатный выстрел, который игрок не нажимал. Взводит
	#    первое же наблюдаемое отпускание; после взведения удержание стреляет
	#    как обычно, темп не меняется.
	var fire_held := Input.is_action_pressed("fire")
	if not _armed:
		if not fire_held:
			_armed = true
	elif fire_held:
		try_fire()


## Перезарядку просит игрок клавишей R; пустой магазин сам её не начинает.
##
## Гейт тот же, что у огня и движения: со свободным курсором действие `reload`
## не перезаряжает. Обработка живёт в `_unhandled_input`, а не в `_process`,
## потому что это событие нажатия, а не удержание: `Input.action_press()` и
## опрос уровня не доставляют край нажатия, а разобранное событие доставляет.
## `start_reload()` сам решает, можно ли перезаряжаться: полный магазин и уже
## идущая перезарядка отказывают, повторный запуск таймер не сбрасывает.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reload") and InputGate.is_play_input_allowed(_mouse_mode_for_play_input()):
		start_reload()


## Режим курсора для тестов в headless (-1 = использовать Input.mouse_mode).
var mock_mouse_mode: int = -1


## Единственное место в игре, где читается Input.mouse_mode для гейта ввода.
## Обёрнуто в метод по той же причине, что и в player.gd: headless-дисплейсер
## не умеет захватывать курсор, поэтому проверка подменяет только значение,
## попадающее в гейт, а не синглтон Input.
func _mouse_mode_for_play_input() -> int:
	if mock_mouse_mode >= 0:
		return mock_mouse_mode
	return Input.mouse_mode


## Можно ли сейчас произвести выстрел.
##
## Четыре игровых правила: данные пригодны, ввод разрешён, перезарядки нет,
## магазин не пуст. Темп стрельбы здесь не проверяется — это таймер, а не
## право стрелять; его держит `try_fire()`. Пока это так, «магазин пуст» и
## «выстрел запрещён» — два разных вопроса, и проверка спрашивает их по
## отдельности.
func can_fire() -> bool:
	if not _has_valid_data():
		return false
	if not InputGate.is_play_input_allowed(_mouse_mode_for_play_input()):
		return false
	if is_reloading():
		return false
	return _current > 0


## Выстрел, если он разрешен. Возвращает `true`, только если выстрел был.
##
## Порядок обязателен: проверки, инстанцирование снаряда, уменьшение
## магазина, таймер, сигналы. Уменьшать магазин до инстанцирования нельзя —
## провалившееся инстанцирование съело бы патрон, который игрок не потратил.
func try_fire() -> bool:
	if not can_fire():
		return false
	# Темп стрельбы держится здесь, а не в can_fire(): can_fire() отвечает на
	# вопрос «имеет ли игрок право стрелять», и право от темпа не зависит.
	if _cooldown > 0.0:
		return false
	var projectile := _instantiate_projectile()
	if projectile == null:
		# Снаряда не будет — патрон остаётся в магазине.
		return false
	_current -= 1
	_cooldown = data.seconds_between_shots()
	_apply_visual_recoil()
	# Сигналы после уменьшения: и fired, и magazine_changed наблюдаются уже с
	# новым состоянием, поэтому слушатель никогда не прочитает устаревшее
	# число патронов.
	fired.emit()
	magazine_changed.emit(_current, data.magazine_size)
	return true


## Начать перезарядку. `false`, если перезаряжаться нечего.
##
## Перезапуск идющей перезарядки запрещён и таймер не трогается: перезапуск
## обнулил бы отсчёт, и игрок держал бы R сколько угодно, откладывая
## перезарядку бесконечно.
func start_reload() -> bool:
	if is_reloading():
		return false
	if not _has_valid_data():
		return false
	if _current >= _capacity():
		# Полный магазин перезаряжать нечего: перезагрузка кончилась бы без
		# единого изменения состояния.
		return false
	_reload_remaining = data.reload_time
	# magazine_changed здесь не испускается: число патронов ещё не изменилось,
	# о начале перезагрузки говорит reload_started.
	reload_started.emit()
	return true


## Сколько патронов осталось.
func current_mag() -> int:
	return _current


## Идёт ли перезарядка.
func is_reloading() -> bool:
	return _reload_remaining > 0.0


## Вернуть оружие в исходное состояние при смене сцены.
##
## Контракт на Фазу 4 (лобби), а не мёртвый код: полный магазин, без
## перезарядки, обнулённый темп. Вызывается из player.gd::_ready(). Без него
## полупустой магазин пережил бы поездку в лобби и обратно, и каждая такая
## поездка стоила бы игроку бесплатных патронов.
func reset_for_scene_change() -> void:
	_reload_remaining = 0.0
	_cooldown = 0.0
	_current = _capacity()
	# Взведение сбрасывается вместе с остальным состоянием: кнопка, залипшая
	# на прошлой сцене, не должна выстрелить в новой раньше, чем игрок её
	# отпустит.
	_armed = false
	_recoil_offset = Vector3.ZERO
	_recoil_rotation = 0.0
	for mesh in _mesh_initial_transforms:
		if is_instance_valid(mesh):
			(mesh as MeshInstance3D).transform = _mesh_initial_transforms[mesh]
	magazine_changed.emit(_current, _capacity())


func _cache_mesh_transforms() -> void:
	_mesh_initial_transforms.clear()
	for child in get_children():
		if child is MeshInstance3D:
			_mesh_initial_transforms[child] = (child as MeshInstance3D).transform


func _apply_visual_recoil() -> void:
	if _mesh_initial_transforms.is_empty():
		_cache_mesh_transforms()
	if _mesh_initial_transforms.is_empty():
		return
	# Легкий импульс отдачи назад и подброс вверх
	_recoil_offset.z = minf(_recoil_offset.z + 0.035, 0.07)
	_recoil_rotation = minf(_recoil_rotation + deg_to_rad(3.0), deg_to_rad(6.0))


# --------------------------------------------------------------------------
# внутреннее
# --------------------------------------------------------------------------

func _has_valid_data() -> bool:
	return data != null and data.is_valid()


func _capacity() -> int:
	return data.magazine_size if data != null else 0


func _complete_reload() -> void:
	_current = _capacity()
	reload_finished.emit()
	magazine_changed.emit(_current, _capacity())


## Откуда ЦЕЛИТЬСЯ: заданный источник, иначе камера игрока — выстрел должен
## уходить туда, куда смотрит глаз. Если камеры нет (пистолет проверен без
## игрока), целимся от самого оружия.
func _muzzle() -> Node3D:
	if is_instance_valid(fire_rate_source) and fire_rate_source.is_inside_tree():
		return fire_rate_source
	var viewport := get_viewport()
	if viewport != null:
		var camera := viewport.get_camera_3d()
		if is_instance_valid(camera) and camera.is_inside_tree():
			return camera
	return self


## Откуда СТАРТОВАТЬ снаряду — это другой вопрос, и раньше на оба отвечал
## `_muzzle()`, из-за чего пуля вылетала из головы игрока.
##
## Точка — узел `Muzzle` в pistol.tscn, конец дула: рамка длиной 0.3 м, то
## есть чуть за дульной кромкой. Направление при этом остаётся прежним, от
## `_muzzle()`: пистолет довёрнут относительно камеры (player.tscn), и
## смещать точку старта вместе с ним нельзя — пуля пошла бы мимо прицела.
##
## Узла `Muzzle` нет — значит сцена собрана без ствола (харнесс, макетка без
## оружия), и точка остаётся прежней цепочкой. Предупреждение выходит только
## когда цепочка приводит в камеру (fire_rate_source == null): там подмена
## заметна игроку, а в проверках, где источник задан, маркер не нужен и
## сообщение было бы шумом на каждый выстрел.
func _spawn_point() -> Node3D:
	var barrel := get_node_or_null("Muzzle") as Node3D
	if barrel != null:
		return barrel
	if fire_rate_source == null:
		push_warning("[pistol] %s: в сцене нет узла Muzzle — снаряд стартует из прицела" % name)
	return _muzzle()


## Вычисляет направление выстрела со сведением в точку прицела камеры (устранение параллакса).
func _calculate_shot_direction(spawn_pos: Vector3, muzzle: Node3D) -> Vector3:
	var fallback_dir: Vector3 = -muzzle.global_transform.basis.z.normalized()
	# Если задан специальный источник прицеливания (например, в изолированных тестах без камеры),
	# используем прямое направление этого источника
	if fire_rate_source != null and not (fire_rate_source is Camera3D):
		return fallback_dir

	var viewport := get_viewport()
	if viewport == null:
		return fallback_dir
	var camera := viewport.get_camera_3d()
	if not is_instance_valid(camera) or not camera.is_inside_tree():
		return fallback_dir

	var world_3d := camera.get_world_3d()
	if world_3d == null:
		return fallback_dir
	var space_state := world_3d.direct_space_state
	if space_state == null:
		return fallback_dir

	# Если точка старта снаряда совпадает с положением камеры (например, нет узла Muzzle)
	if spawn_pos.distance_squared_to(camera.global_position) < 0.001:
		return fallback_dir

	var cam_pos: Vector3 = camera.global_position
	var cam_forward: Vector3 = -camera.global_transform.basis.z.normalized()
	var ray_end: Vector3 = cam_pos + cam_forward * 100.0

	var query := PhysicsRayQueryParameters3D.create(cam_pos, ray_end)
	# Маска: мир (слой 1) + хитбокс врага (слой 4)
	query.collision_mask = (1 << 0) | (1 << 3)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit := space_state.intersect_ray(query)
	var target_point: Vector3 = hit.position if not hit.is_empty() else ray_end

	var to_target: Vector3 = target_point - spawn_pos
	if to_target.length_squared() < 0.0001:
		return fallback_dir
	return to_target.normalized()


## Снаряд из `projectile_scene` или `null`, если выстрела не будет.
##
## Порядок обязателен, и каждая строка в нём load-bearing: узел добавляется в
## дерево ДО `launch()` (`Projectile._ready()` выключает свою обработку и
## включает её только `launch()`, поэтому вызов до входа в дерево был бы затёрт
## этим же `_ready()` — снаряд висел бы в мире неподвижным), отвязка от
## родителя идёт ДО записи позиции, а позиция — ДО `launch()`.
func _instantiate_projectile() -> Node3D:
	if projectile_scene == null:
		return null
	var instance := projectile_scene.instantiate()
	var projectile := instance as Node3D
	if projectile == null or not projectile.has_method("launch"):
		# Сцена не снаряда. Ранний выход: узел не в дереве, и queue_free() для
		# него недоступен.
		if instance != null:
			instance.free()
		return null
	# Характеристики приходят из данных оружия, а не из значений сцены: одно
	# место, откуда берутся урон, скорость пули и внешний вид снаряда.
	if projectile is Projectile:
		var bullet := projectile as Projectile
		bullet.speed = data.projectile_speed
		bullet.damage = data.damage
		bullet.lifetime = data.projectile_lifetime
		bullet.radius = data.projectile_radius
		bullet.color = data.projectile_color
	var muzzle := _muzzle()
	# Точка старта и направление — два разных узла (см. _spawn_point()).
	var spawn := _spawn_point()
	var spawn_pos: Vector3 = spawn.global_position if spawn.is_inside_tree() else (global_position + (spawn.position if spawn != null else Vector3.ZERO))
	# Базовое направление с расчётом сведения в прицел (устранение параллакса)
	var direction := _calculate_shot_direction(spawn_pos, muzzle)
	muzzle.add_child(projectile)
	# Отвязка от трансформа родителя — вторая часть фикса SHOOT-1 (первая, выше,
	# это точка старта). У Node3D мировой трансформ = global(родителя) * local,
	# поэтому запись global_position у привязанной ноды лишь пересчитывает
	# local.origin: между тиками мировая позиция снаряда едет вместе с
	# родителем, а Projectile, пишущий global_position += _direction * speed *
	# delta, каждый тик закрепляет себе накопленную погрешность. Поворот камеры
	# на 0.05 rad — это полметра увода на десяти метрах, и повторяется он
	# каждый кадр. top_level делает трансформ снаряда его собственным: после
	# выстрела камера двигает только картинку. Родителем он остаётся прежним —
	# это жизненный цикл (queue_free, списки снарядов), а не позиция.
	projectile.set_as_top_level(true)
	# Мировая позиция ставится ПОСЛЕ отвязки: у top_level-ноды это уже абсолютная
	# точка, а до отвязки та же запись пересчитала бы локальную позицию прежнего
	# родителя.
	projectile.global_position = spawn_pos
	projectile.call("launch", direction)
	return projectile