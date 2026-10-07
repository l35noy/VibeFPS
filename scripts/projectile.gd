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

## Слой 5 — `projectile`.
const _COLLISION_LAYER := 1 << 4
## Маска 1 | 4: мировая геометрия (слой 1) и хитбоксы врага (слой 4). Слоя
## хитбокса игрока (7) в маске нет намеренно: игрок не должен получать урон от
## собственных выстрелов, прошедших мимо цели.
const _COLLISION_MASK := (1 << 0) | (1 << 3)

## Прозрачность шлейфа в начале полёта и её потолок.
const _TRAIL_PEAK_ALPHA := 0.6
const _TRAIL_COLOR := Color(0.15, 0.15, 0.15)

## Направление нормализовано один раз здесь; дальше оно только читается.
var _direction := Vector3.FORWARD
var _age := 0.0
## Снаряд кончился: пересечения больше не обрабатываются, даже если движок
## успеет прислать их в том же проходе.
var _spent := false
var _trail: MeshInstance3D
var _trail_material: StandardMaterial3D


## Слой и маска задаются здесь, а не в сцене: правило «кого я вижу» и логика
## попадания лежат в одном файле, и сцена не может их разъехать.
func _ready() -> void:
	collision_layer = _COLLISION_LAYER
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


func _physics_process(delta: float) -> void:
	# Константа скорости: ровно speed * delta каждый тик, без ускорения, без
	# сглаживания. Расстояние за секунду — ровно speed, и это проверяемо.
	global_position += _direction * (speed * delta)
	_age += delta
	_fade_trail()
	if _age >= lifetime:
		# Ни во что не попал: снимаем снаряд сцены, чтобы он не ждал своей
		# геометрии вечно.
		queue_free()


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
	set_deferred("monitoring", false)
	queue_free()


## Шлейф: дочерний MeshInstance3D, который бледнеет по времени жизни.
##
## Сцена может задать геометрию и цвет шлейфа сама (Task 5 задаёт их из данных
## оружия); если её нет, снаряд остаётся рабочим самодостаточным. Затухание —
## уменьшение `albedo_color.a` каждый кадр, а НЕ Tween: Tween продолжает
## работать и после попадания, а шлейф обязан умирать вместе со снарядом, и
## иначе в месте попадания оставался бы висящий в воздухе полупрозрачный шар.
func _setup_trail() -> void:
	if _trail == null:
		for child in get_children():
			if child is MeshInstance3D:
				_trail = child
				break
	if _trail == null:
		_trail = MeshInstance3D.new()
		_trail.name = "Trail"
		var mesh := SphereMesh.new()
		mesh.radius = 0.08
		mesh.height = 0.16
		_trail.mesh = mesh
		add_child(_trail)
	var mat := _trail.material_override as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		_trail.material_override = mat
		var color := _TRAIL_COLOR
		color.a = _TRAIL_PEAK_ALPHA
		mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if is_zero_approx(mat.albedo_color.a):
		mat.albedo_color.a = _TRAIL_PEAK_ALPHA
	_trail_material = mat


func _fade_trail() -> void:
	if _trail_material == null or lifetime <= 0.0:
		return
	var color := _trail_material.albedo_color
	color.a = _TRAIL_PEAK_ALPHA * clampf(1.0 - _age / lifetime, 0.0, 1.0)
	_trail_material.albedo_color = color