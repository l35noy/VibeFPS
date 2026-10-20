class_name BossEnemy
extends CharacterBody3D

## Босс первой локации — геометрический колосс (Фаза 4).
##
## Обладает увеличенным запасом здоровья (300 HP), наносит сильный контактный
## урон (40 HP) и периодически выпускает веерный залп снарядов в сторону игрока.
## При падении здоровья ниже 50% входит в фазу ярости с увеличенной скоростью.

signal health_changed(current: float, maximum: float)
signal died()

@export var data: EnemyData
@export var contact_interval: float = 1.0
@export var ranged_attack_interval: float = 3.5
@export var projectile_scene: PackedScene

const _LAYER_WORLD := 1 << 0
const _LAYER_ENEMY_BODY := 1 << 2
const _DEATH_COLOR := Color(0.4, 0.4, 0.4)
const _DEATH_LINGER := 0.5
const _NAV_UPDATE_INTERVAL: float = 0.1
const _NAV_DISPLACEMENT_THRESHOLD_SQ: float = 0.25 * 0.25

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _health: float = 0.0
var _max_health: float = 0.0
var _dying: bool = false
var _death_timer: float = 0.0
var _contact_active: bool = false
var _contact_accumulator: float = 0.0
var _ranged_timer: float = 0.0
var _enraged: bool = false

var _cached_player: Node3D = null
var _last_target_position: Vector3 = Vector3.INF
var _nav_update_timer: float = 0.0
var _material: StandardMaterial3D

@onready var _hurtbox: Hurtbox = get_node_or_null("Hurtbox") as Hurtbox
@onready var _mesh: MeshInstance3D = get_node_or_null("Mesh") as MeshInstance3D
@onready var _agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
@onready var _muzzle: Node3D = get_node_or_null("Muzzle") as Node3D


func _ready() -> void:
	collision_layer = _LAYER_ENEMY_BODY
	collision_mask = _LAYER_WORLD | _LAYER_ENEMY_BODY
	if projectile_scene == null:
		projectile_scene = load("res://weapons/projectile/projectile.tscn") as PackedScene
	_setup_material()
	if data == null:
		data = load("res://data/enemies/boss.tres") as EnemyData
	if data != null:
		_health = data.max_health
		_max_health = data.max_health
	else:
		_health = 300.0
		_max_health = 300.0
	_connect_hurtbox()


func _setup_material() -> void:
	if _mesh == null:
		return
	var override := _mesh.material_override as StandardMaterial3D
	if override != null:
		_material = override.duplicate() as StandardMaterial3D
		_mesh.material_override = _material
	elif data != null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = data.color
		_mesh.material_override = _material


func _connect_hurtbox() -> void:
	if _hurtbox != null:
		if not _hurtbox.damage_taken.is_connected(take_damage):
			_hurtbox.damage_taken.connect(take_damage)
		if not _hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
			_hurtbox.area_entered.connect(_on_hurtbox_area_entered)
		if not _hurtbox.area_exited.is_connected(_on_hurtbox_area_exited):
			_hurtbox.area_exited.connect(_on_hurtbox_area_exited)


func is_alive() -> bool:
	return _health > 0.0 and not _dying


func health() -> float:
	return _health


func max_health() -> float:
	return _max_health


func take_damage(amount: float) -> void:
	if amount <= 0.0 or not is_alive():
		return
	_health = maxf(0.0, _health - amount)
	health_changed.emit(_health, _max_health)

	# Фаза ярости при здоровье <= 50%
	if not _enraged and _health <= _max_health * 0.5:
		_enraged = true
		if _material != null:
			_material.emission_enabled = true
			_material.emission = Color(1.0, 0.2, 0.2)
			_material.emission_energy_multiplier = 2.0

	if _health <= 0.0:
		_die()


func _physics_process(delta: float) -> void:
	if _dying:
		_death_timer -= delta
		if _death_timer <= 0.0:
			set_physics_process(false)
			queue_free()
		return

	_apply_gravity(delta)
	_steer_to_player(delta)
	_tick_contact(delta)
	_tick_ranged_attack(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta


func _player() -> Node3D:
	if not is_inside_tree():
		return null
	if is_instance_valid(_cached_player) and _cached_player.is_inside_tree() and _cached_player.is_in_group("player"):
		return _cached_player
	_cached_player = get_tree().get_first_node_in_group("player") as Node3D
	return _cached_player


func _steer_to_player(delta: float) -> void:
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

	var direction := next_path_direction()
	if direction == Vector3.ZERO:
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var current_speed := (data.move_speed if data != null else 2.2)
	if _enraged:
		current_speed *= 1.35

	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

	# Плавный доворот к направлению движения
	if not direction.is_zero_approx():
		var look_target := global_position + Vector3(direction.x, 0.0, direction.z)
		look_at(look_target, Vector3.UP)


func next_path_direction() -> Vector3:
	if _agent == null or not is_inside_tree() or _agent.is_navigation_finished():
		return Vector3.ZERO
	var offset := _agent.get_next_path_position() - global_position
	offset.y = 0.0
	if offset.length() <= 0.001:
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
	var target := _player()
	if target == null or not target.has_method("take_damage"):
		return
	var dmg := data.contact_damage if data != null else 40.0
	target.call("take_damage", dmg)


func _on_hurtbox_area_entered(area: Area3D) -> void:
	if not (area is Hurtbox) or (area as Hurtbox).zone != 1:
		return
	_contact_active = true
	_contact_accumulator = 0.0
	_deal_contact_damage()


func _on_hurtbox_area_exited(area: Area3D) -> void:
	if not (area is Hurtbox) or (area as Hurtbox).zone != 1:
		return
	_contact_active = false
	_contact_accumulator = 0.0


func _tick_ranged_attack(delta: float) -> void:
	var cooldown := ranged_attack_interval * (0.75 if _enraged else 1.0)
	_ranged_timer += delta
	if _ranged_timer >= cooldown:
		_ranged_timer = 0.0
		_fire_volley()


## Веерный залп из 3 снарядов в сторону игрока.
func _fire_volley() -> void:
	var target := _player()
	if target == null or projectile_scene == null or not is_inside_tree():
		return

	var spawn_pos := _muzzle.global_position if _muzzle != null else global_position + Vector3(0.0, 1.5, 0.0)
	var target_center := target.global_position + Vector3(0.0, 0.9, 0.0)
	var base_dir := (target_center - spawn_pos).normalized()
	if base_dir.is_zero_approx():
		return

	var angles := [-0.25, 0.0, 0.25] # ~ -14°, 0°, +14°
	for angle in angles:
		var dir := base_dir.rotated(Vector3.UP, angle)
		_spawn_boss_bullet(spawn_pos, dir)


func _spawn_boss_bullet(pos: Vector3, dir: Vector3) -> void:
	var instance := projectile_scene.instantiate()
	var bullet := instance as Projectile
	if bullet == null:
		if instance != null:
			instance.free()
		return

	bullet.speed = 30.0
	bullet.damage = 20.0
	bullet.color = Color(1.0, 0.15, 0.45)
	bullet.radius = 0.14
	bullet.set_target_mask((1 << 0) | (1 << 6)) # Слой 1 (мир) и 7 (игрок)

	var root_node := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	root_node.add_child(bullet)
	bullet.set_as_top_level(true)
	bullet.global_position = pos
	bullet.launch(dir)


func _die() -> void:
	_dying = true
	_contact_active = false
	_contact_accumulator = 0.0
	velocity = Vector3.ZERO
	if _material != null:
		_material.albedo_color = _DEATH_COLOR
	_disable_collisions()
	_death_timer = _DEATH_LINGER
	died.emit()
	var gs := get_node_or_null("/root/GameState") as GameState
	if gs != null:
		gs.award_points(100) # Бонус за убийство босса


func _disable_collisions() -> void:
	collision_layer = 0
	collision_mask = 0
	if _hurtbox != null:
		_hurtbox.collision_layer = 0
		_hurtbox.set_deferred("monitoring", false)
