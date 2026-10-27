class_name Projectile
extends Area3D

## Снаряд: летит по прямой с конечной постоянной скоростью, попадает один раз
## и исчезает.
##
## Три решения здесь — игровые правила, а не технические детали:
##
## 1. Конечная скорость. На 40 м/с снаряд пистолета пролетает 15 м за 0.375 с.
##    Это окно, за которое цель успевает отойти, поэтому и игрок, и враг могут
##    уклоняться. Мгновенный (хитскан) выстрел это окно убирает, и уклонение
##    становится невозможным — значит, скорость обязана быть в данных, а не
##    бесконечной.
## 2. Никакого ускорения и отскока: направление нормализуется один раз при
##    запуске, дальше скорость постоянна. Сглаживание, интерполяция или
##    «доводка» до цели сломали бы правило «сколько метров за секунду» и,
##    вместе с ним, окно уклонения.
## 3. Один выстрел — одно попадание. Снаряд, переживший попадание, за тот же
##    кадр достал бы вторую цель и нанёс урон двоим.

## Выстрел попал во что-то. Для диагностики и для проверок: попадание, которое
## нельзя увидеть, невозможно и отладить.
signal hit_something(target: Node)

## Скорость в м/с. Конечная: см. пункт 1 выше.
@export var speed: float = 40.0
## Сколько урона наносит одно попадание. Хитбокс применяет свой
## `damage_multiplier` — множитель живёт у цели, а не у снаряда.
@export var damage: float = 30.0
## Через сколько секунд снаряд истекает, если ни во что не попал. Страховка от
## снаряда, улетевшего в пустоту на шум в приложении.
@export var lifetime: float = 3.0

## Радиус шлейфа в метрах. Приходит из данных оружия
## (WeaponData.projectile_radius): след показывает, где летит пуля, поэтому
## его размер обязан повторять размер снаряда.
@export var radius: float = 0.05:
	set(value):
		radius = value
		if _trail != null:
			_trail.mesh = get_shared_mesh(radius)
		_sync_collision_shape()

## Цвет шлейфа. Приходит из данных оружия (WeaponData.projectile_color):
## след делает оружие узнаваемым на глаз — яркие белые снаряды в монохромном стиле.
@export var color: Color = Color(1.0, 1.0, 1.0):
	set(value):
		color = value
		if _trail != null:
			var mat := get_shared_material(color)
			_trail.material_override = mat
			_trail_material = mat

## Кастомная маска коллизий для целей. Если не 0, переопределяет стандартную маску (R2).
@export_flags_3d_physics var target_mask: int = 0

## Слой 5 — `projectile`.
const DEFAULT_COLLISION_LAYER := 1 << 4
const _COLLISION_LAYER := DEFAULT_COLLISION_LAYER
## Маска 1 | 4: мировая геометрия (слой 1) и хитбоксы врага (слой 4).
## Для вражеских снарядов маска может настраиваться на хитбокс игрока (слой 7, 1 << 6).
const DEFAULT_COLLISION_MASK := (1 << 0) | (1 << 3)
const _COLLISION_MASK := DEFAULT_COLLISION_MASK

## Прозрачность шлейфа в начале полёта и её потолок.
const _TRAIL_PEAK_ALPHA := 0.95

## Статический кэш ресурсов шлейфа снарядов для предотвращения повторных аллокаций
## и обеспечения эффективного батчинга рендеринга Godot (R6).
static var _mesh_cache: Dictionary = {}
static var _material_cache: Dictionary = {}


## Получить или создать разделяемый экземпляр SphereMesh для заданного радиуса.
static func get_shared_mesh(r: float) -> SphereMesh:
	var key := snappedf(r, 0.0001)
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var sphere := SphereMesh.new()
	sphere.radius = r
	sphere.height = r * 2.0
	_mesh_cache[key] = sphere
	return sphere


## Получить или создать разделяемый экземпляр StandardMaterial3D для заданного базового цвета.
static func get_shared_material(base_color: Color) -> StandardMaterial3D:
	var key := base_color
	if _material_cache.has(key):
		return _material_cache[key]
	var mat := StandardMaterial3D.new()
	var trail_color := base_color
	trail_color.a = _TRAIL_PEAK_ALPHA
	mat.albedo_color = trail_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic_specular = 0.0
	mat.emission_enabled = true
	mat.emission = base_color
	mat.emission_energy_multiplier = 3.0
	mat.render_priority = 10
	_material_cache[key] = mat
	return mat

## Направление нормализовано один раз здесь; дальше оно только читается.
var _direction := Vector3.FORWARD
var _age := 0.0
## Снаряд кончился: пересечения больше не обрабатываются, даже если движок
## успеет прислать их в том же проходе.
var _spent := false
var _trail: MeshInstance3D
var _trail_material: StandardMaterial3D
var _collision_shape: CollisionShape3D


## Слой и маска настраиваются при инициализации без безусловного затирания кастомной маски (R2).
func _ready() -> void:
	collision_layer = _COLLISION_LAYER
	if target_mask != 0:
		collision_mask = target_mask
	elif collision_mask != 1 and collision_mask != 0:
		# Вызывающий код заранее настроил collision_mask до _ready(), сохраняем его
		pass
	else:
		collision_mask = _COLLISION_MASK
	# Снаряду нужно видеть другие Area3D, но сам он в чужие пересечения попадать
	# не должен: иначе чужой код, слушающий пересечения, увидит каждый снаряд.
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	_setup_trail()
	# До launch() снаряд стоит на месте: выстрел сам решает, когда снаряд
	# появится в мире.
	set_physics_process(false)
	set_process(false)


## Задать направление и включить полёт. Узел при этом не двигается: решение
## «откуда и куда» принимает выстрел, а снаряд начинает оттуда, где уже стоит.
func launch(direction: Vector3) -> void:
	if direction.is_zero_approx():
		# Нулевое направление — это не «лети куда попало», а отсутствие выстрела:
		# нормализация нуля дала бы NaN, и снаряд улетел бы в никуда молча.
		return
	_direction = direction.normalized()
	_age = 0.0
	_spent = false
	set_physics_process(true)
	set_process(true)


func _physics_process(delta: float) -> void:
	# Константа скорости: ровно speed * delta каждый тик, без ускорения, без
	# сглаживания. Расстояние за секунду — ровно speed, и это проверяемо.
	global_position += _direction * (speed * delta)
	_age += delta
	if _age >= lifetime:
		# Ни во что не попал: снимаем снаряд сцены, чтобы он не ждал своей
		# геометрии вечно.
		queue_free()


func _process(_delta: float) -> void:
	# Визуальное затухание шлейфа вынесено из физического цикла 120 Гц в процесс кадра
	_fade_trail()


## Синхронизация радиуса формы коллизии CollisionShape3D с размером снаряда
func _sync_collision_shape() -> void:
	if _collision_shape == null:
		_collision_shape = get_node_or_null("Shape") as CollisionShape3D
		if _collision_shape == null:
			for child in get_children():
				if child is CollisionShape3D:
					_collision_shape = child
					break
	if _collision_shape != null and _collision_shape.shape is SphereShape3D:
		var sphere := _collision_shape.shape as SphereShape3D
		if not is_equal_approx(sphere.radius, radius):
			var new_shape := sphere.duplicate() as SphereShape3D
			new_shape.radius = radius
			_collision_shape.shape = new_shape


## Урон наносится только хитбоксу. Любой другой Area3D — это «снаряд пролетел
## мимо», а не ошибка: вслепую вешать урон на любую зону нельзя, иначе
## триггерные зоны уровня начнут принимать пули.
func _on_area_entered(area: Area3D) -> void:
	if _spent:
		return
	if not (area is Hurtbox):
		return
	(area as Hurtbox).apply_damage(damage)
	hit_something.emit(area)
	_spend()


## Геометрия мира (слой 1): стена, пол, укрытие. Урона не несёт, но снаряд
## кончается — иначе пуля продолжала бы лететь сквозь стену.
func _on_body_entered(body: Node3D) -> void:
	if _spent:
		return
	hit_something.emit(body)
	_spend()


## Снаряд отстрелял своё единственное попадание.
##
## Порядок обязателен. `monitoring` выключается через set_deferred, а не
## присваиванием: этот обработчик вызывается движком в том самом проходе, в
## котором обновляются пересечения, и прямое изменение состояния там даёт
## ошибку Godot «can't change this state while flushing queries». Эта ошибка
## уходит в консоль, а не в проверку, поэтому её приходится предотвращать
## здесь, а не ловить.
func _spend() -> void:
	_spent = true
	set_physics_process(false)
	set_process(false)
	set_deferred("monitoring", false)
	queue_free()


## Шлейф: дочерний MeshInstance3D, использующий разделяемые статические ресурсы
## SphereMesh и StandardMaterial3D без вызовов duplicate() на каждый выстрел (R6).
## Затухание управляется свойством transparency узла MeshInstance3D (GeometryInstance3D),
## что исключает взаимную перезапись альфа-канала общего материала одновременно летящих пуль.
func _setup_trail() -> void:
	if _trail == null:
		for child in get_children():
			if child is MeshInstance3D:
				_trail = child
				break
	if _trail == null:
		_trail = MeshInstance3D.new()
		_trail.name = "Trail"
		add_child(_trail)
	_trail.mesh = get_shared_mesh(radius)
	var mat := get_shared_material(color)
	_trail.material_override = mat
	_trail_material = mat
	_trail.transparency = 0.0


func _fade_trail() -> void:
	if _trail == null or lifetime <= 0.0:
		return
	_trail.transparency = clampf(_age / lifetime, 0.0, 1.0)


## Задать целевую маску коллизий для снаряда.
func set_target_mask(mask: int) -> void:
	target_mask = mask
	collision_mask = mask


## Эффективная альфа шлейфа с учетом прозрачности геометрии.
func get_trail_alpha() -> float:
	if _trail == null or _trail_material == null:
		return 0.0
	return _trail_material.albedo_color.a * (1.0 - _trail.transparency)