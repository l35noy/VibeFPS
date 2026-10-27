class_name ContactEnemy
extends CharacterBody3D

## Контактный враг (R6: Парящий куб): парит на высоте 1.0 м над полом,
## совершает синусоидальное вертикальное покачивание (bobbing) и непрерывное
## осевое вращение вокруг оси Y (spin). Преследует игрока по навмешу, наносит
## контактный урон с каденцией. При летальном уроне отключает левитацию,
## падает на пол под действием силы тяжести и исчезает после задержки затухания.
##
## Здоровье живёт здесь, а не в хитбоксе: `Hurtbox` по контракту только
## сообщает о попадании сигналом `damage_taken`, и «у врага 60 HP» обязано быть
## правдой ровно в одном месте.
##
## Ключевые архитектурные решения:
## 1. Слои задаются в `_ready()`: тело на слое 3 (`enemy_body`), хитбокс на слое 4 (`enemy_hurtbox`).
## 2. Детект контакта включается на стороне врага (спека §6.3).
## 3. Смерть наблюдаема: `died` уходит ровно один раз, включается гравитационное падение
##    к полу, а тело обесцвечивается и задерживается на сцене (~0.8 с).
## 4. Цели ищутся по группе `"player"`.
## 5. Парение куба реализовано через смещение его геометрии (Mesh, Hurtbox, CollisionShape3D)
##    на высоту `hover_height = 1.0` м с синусоидальным боббингом, что обеспечивает
##    совместимость с навмешем пола и навигацией NavigationAgent3D.
## 6. При смерти коллизионный слой обнуляется (труп не блокирует игрока и оружие),
##    а куб ускоряется вниз до поверхности пола (`is_on_floor()`).

## Изменилось здоровье врага: сколько осталось из скольких.
signal health_changed(current: float, maximum: float)
## Враг умер. Испускается строго один раз за смерть.
signal died()

@export var data: EnemyData
## Каденция контактного урона, сек.
@export var contact_interval: float = 1.0
## Базовая высота парения над полом, метры (R6).
@export var hover_height: float = 1.0
## Амплитуда синусоидального покачивания, метры (R6).
@export var bob_amplitude: float = 0.1
## Частота покачивания, рад/с.
@export var bob_frequency: float = 3.0
## Скорость осевого вращения вокруг оси Y, рад/с (R6: ~1.5–2.0 рад/с).
@export var spin_speed: float = 1.8

## Слои коллизий
const _LAYER_WORLD := 1 << 0
const _LAYER_PLAYER_BODY := 1 << 1
const _LAYER_ENEMY_BODY := 1 << 2
const _LAYER_ENEMY_HURTBOX := 1 << 3
const _LAYER_PLAYER_HURTBOX := 1 << 6

## Цвет мёртвого тела (нейтральный серый).
const _DEATH_COLOR := Color(0.5, 0.5, 0.5)
## Время задержки мёртвого тела на сцене перед queue_free, сек (R6: ~0.8 с).
const _DEATH_LINGER: float = 0.8
## Порог совпадения точек пути.
const _PATH_EPS := 0.001
## Периодичность обновления целевой точки навигации (сек).
const _NAV_UPDATE_INTERVAL: float = 0.1
## Порог смещения игрока для немедленного пересчёта пути (метры).
const _NAV_DISPLACEMENT_THRESHOLD_SQ: float = 0.25 * 0.25

## Гравитация берётся из настроек проекта
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _hurtbox: Hurtbox = get_node_or_null("Hurtbox") as Hurtbox
@onready var _mesh: MeshInstance3D = get_node_or_null("Mesh") as MeshInstance3D
@onready var _agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
@onready var _collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D

var _health: float = 0.0
var _max_health: float = 0.0
var _contact_active: bool = false
var _contact_accumulator: float = 0.0
var _dying: bool = false
var _death_timer: float = 0.0
var _hover_active: bool = true
var _bob_time: float = 0.0
var _has_landed: bool = false
var _current_cube_y: float = 1.0
var _cube_velocity_y: float = 0.0
var _material: StandardMaterial3D = null
var _hit_flash_timer: float = 0.0
var _cached_player: Node3D = null
var _last_target_position: Vector3 = Vector3.INF
var _nav_update_timer: float = 0.0
var _nav_updates_count: int = 0


func _ready() -> void:
	collision_layer = _LAYER_ENEMY_BODY
	collision_mask = _LAYER_WORLD | _LAYER_ENEMY_BODY
	_setup_material()
	_current_cube_y = hover_height
	_update_cube_transform()
	if _agent == null:
		push_warning("[enemy] %s: в сцене нет NavigationAgent3D — враг останется на месте" % name)
	if not _data_usable():
		set_physics_process(false)
		return
	_health = data.max_health
	_max_health = _health
	_connect_hurtbox()


func _data_usable() -> bool:
	if data == null:
		push_error("[enemy] %s: нет данных EnemyData — враг выключен" % name)
		return false
	if not data.is_valid():
		push_error("[enemy] %s: данные «%s» непригодны к спавну — враг выключен" % [
			name, data.display_name])
		return false
	return true


func _connect_hurtbox() -> void:
	if _hurtbox == null:
		return
	if not _hurtbox.damage_taken.is_connected(_on_damage_taken):
		_hurtbox.damage_taken.connect(_on_damage_taken)
	if not _hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		_hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	if not _hurtbox.area_exited.is_connected(_on_hurtbox_area_exited):
		_hurtbox.area_exited.connect(_on_hurtbox_area_exited)


func _setup_material() -> void:
	if _mesh == null:
		return
	var override := _mesh.material_override as StandardMaterial3D
	if override == null:
		override = StandardMaterial3D.new()
	_material = override.duplicate()
	_mesh.material_override = _material
	if data != null:
		_material.albedo_color = data.color


func health() -> float:
	return _health


func is_alive() -> bool:
	return _health > 0.0 and not _dying


func get_hover_height() -> float:
	return hover_height


func get_bob_amplitude() -> float:
	return bob_amplitude


func get_spin_speed() -> float:
	return spin_speed


func is_hovering() -> bool:
	return not _dying and _hover_active


func has_landed() -> bool:
	return _has_landed


func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	if not is_alive():
		return
	_health = maxf(_health - amount, 0.0)
	health_changed.emit(_health, _max_health)
	if _health > 0.0:
		_trigger_hit_flash()
		return
	_die()


func _trigger_hit_flash() -> void:
	if _material == null:
		return
	_hit_flash_timer = 0.07
	_material.albedo_color = Color(0.15, 0.15, 0.15)


func _physics_process(delta: float) -> void:
	if _dying:
		_death_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		if not _has_landed:
			_cube_velocity_y -= _gravity * delta
			_current_cube_y += _cube_velocity_y * delta
			if _current_cube_y <= 0.5:
				_current_cube_y = 0.5
				_cube_velocity_y = 0.0
				_has_landed = true
			_update_cube_transform()
		velocity.y = _cube_velocity_y
		move_and_slide()
		if _death_timer <= 0.0:
			set_physics_process(false)
			queue_free()
		return

	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0.0:
			_hit_flash_timer = 0.0
			if _material != null:
				_material.albedo_color = data.color if data != null else Color(0.92, 0.92, 0.94)

	# Режим парения: вертикальная координата с синусоидальным покачиванием
	_apply_hover(delta)
	# Непрерывное осевое вращение вокруг вертикальной оси Y
	rotate_y(spin_speed * delta)
	# Горизонтальное следование по навмешу к игроку
	_steer_to_player(delta)
	# Контактный урон
	_tick_contact(delta)
	# В живом состоянии парение удерживает постоянную высоту, гравитация не стягивает вниз
	velocity.y = 0.0
	move_and_slide()


## Синхронизация высоты узлов куба (Mesh, Hurtbox, CollisionShape3D).
func _update_cube_transform() -> void:
	if _mesh != null:
		_mesh.position.y = _current_cube_y
	if _hurtbox != null:
		_hurtbox.position.y = _current_cube_y
	if _collision_shape != null:
		_collision_shape.position.y = _current_cube_y


## Управление высотой парения и синусоидальным покачиванием куба.
func _apply_hover(delta: float) -> void:
	if not _hover_active:
		return
	_bob_time += delta
	var bob_offset: float = sin(_bob_time * bob_frequency) * bob_amplitude
	_current_cube_y = hover_height + bob_offset
	_update_cube_transform()


func _steer_to_player(delta: float = 0.0) -> void:
	var target := _player()
	if target == null or _agent == null or not is_alive():
		velocity.x = 0.0
		velocity.z = 0.0
		return
	_nav_update_timer += delta
	var target_pos := target.global_position
	var needs_nav_update: bool = _last_target_position == Vector3.INF \
			or _nav_update_timer >= _NAV_UPDATE_INTERVAL \
			or target_pos.distance_squared_to(_last_target_position) >= _NAV_DISPLACEMENT_THRESHOLD_SQ

	if needs_nav_update:
		_agent.target_position = target_pos
		_last_target_position = target_pos
		_nav_update_timer = 0.0
		_nav_updates_count += 1

	var direction := next_path_direction()
	if direction == Vector3.ZERO:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	velocity.x = direction.x * data.move_speed
	velocity.z = direction.z * data.move_speed


func next_path_direction() -> Vector3:
	if _agent == null or not is_inside_tree():
		return Vector3.ZERO
	if _agent.is_navigation_finished():
		return Vector3.ZERO
	var offset := _agent.get_next_path_position() - global_position
	offset.y = 0.0
	if offset.length() <= _PATH_EPS:
		return Vector3.ZERO
	return offset.normalized()


func _tick_contact(delta: float) -> void:
	if not _contact_active:
		return
	if _player() == null:
		_contact_active = false
		_contact_accumulator = 0.0
		return
	_contact_accumulator += delta
	if _contact_accumulator >= contact_interval:
		_contact_accumulator -= contact_interval
		_deal_contact_damage()


func _deal_contact_damage() -> void:
	var player := _player()
	if player == null or not player.has_method("take_damage"):
		return
	player.call("take_damage", data.contact_damage)


func _on_damage_taken(amount: float) -> void:
	take_damage(amount)


func _on_hurtbox_area_entered(area: Area3D) -> void:
	if _dying or not is_alive():
		return
	if not (area is Hurtbox) or (area as Hurtbox).zone != 1:
		return
	if _player() == null:
		return
	_contact_active = true
	_contact_accumulator = 0.0
	_deal_contact_damage()


func _on_hurtbox_area_exited(area: Area3D) -> void:
	if not (area is Hurtbox) or (area as Hurtbox).zone != 1:
		return
	_contact_active = false
	_contact_accumulator = 0.0


func _player() -> Node3D:
	if not is_inside_tree():
		return null
	if is_instance_valid(_cached_player) and _cached_player.is_inside_tree() and _cached_player.is_in_group("player"):
		return _cached_player
	_cached_player = get_tree().get_first_node_in_group("player") as Node3D
	return _cached_player


func _die() -> void:
	if _dying:
		return
	_dying = true
	_hover_active = false
	_contact_active = false
	_contact_accumulator = 0.0
	_last_target_position = Vector3.INF
	_nav_update_timer = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	_cube_velocity_y = 0.0
	_discolor()
	_disable_collisions()
	_death_timer = _DEATH_LINGER
	died.emit()
	var gs := get_node_or_null("/root/GameState") as GameState
	if gs != null:
		gs.award_points(int(gs.POINTS_PER_KILL))


func _discolor() -> void:
	if _material == null:
		return
	_material.albedo_color = _DEATH_COLOR


func _disable_collisions() -> void:
	collision_layer = 0
	collision_mask = _LAYER_WORLD
	if _hurtbox == null:
		return
	_hurtbox.collision_layer = 0
	_hurtbox.set_deferred("monitoring", false)
	_hurtbox.set_deferred("monitorable", false)
