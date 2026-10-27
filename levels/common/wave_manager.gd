class_name WaveManager
extends Node

## Менеджер 4 волн первой локации (Фаза 4).
##
## Управляет постепенным спавном врагов (контактные, летающие, босс),
## 10-секундной передышкой между волнами, начислением очков (50 за волну,
## 500 за зачистку) и разблокировкой следующей локации в GameState.

signal wave_started(wave_number: int, total_waves: int)
signal wave_completed(wave_number: int)
signal intermission_started(duration: float)
signal intermission_tick(time_remaining: float)
signal intermission_ended()
signal enemy_spawned(enemy: Node3D)
signal boss_spawned(boss: Node3D)
signal location_cleared()

enum State {
	IDLE,
	SPAWNING,
	COMBAT,
	INTERMISSION,
	CLEARED
}

@export var auto_start: bool = true
@export var total_waves: int = 4
@export var intermission_duration: float = 5.0
@export var spawn_interval: float = 1.2
@export var spawn_points: Array[Node3D] = []

@export var contact_enemy_scene: PackedScene
@export var flying_enemy_scene: PackedScene
@export var boss_enemy_scene: PackedScene

var _current_wave: int = 0
var _state: State = State.IDLE
var _intermission_timer: float = 0.0
var _last_emitted_intermission_second: int = -1
var _spawn_timer: float = 0.0

var _spawn_queue: Array[PackedScene] = []
var _active_enemies: Array[Node3D] = []
var _current_boss: Node3D = null
var _ui: CanvasLayer = null


func _ready() -> void:
	_load_default_scenes()
	_find_ui()
	if auto_start:
		call_deferred("start")


func _load_default_scenes() -> void:
	if contact_enemy_scene == null:
		contact_enemy_scene = load("res://entities/enemies/contact/enemy_contact.tscn") as PackedScene
	if flying_enemy_scene == null:
		flying_enemy_scene = load("res://entities/enemies/flying/flying_enemy.tscn") as PackedScene
	if boss_enemy_scene == null:
		boss_enemy_scene = load("res://entities/enemies/boss/boss_enemy.tscn") as PackedScene


func _find_ui() -> void:
	var tree := get_tree()
	if tree != null:
		var uis := tree.get_nodes_in_group("ui")
		if not uis.is_empty():
			_ui = uis[0] as CanvasLayer
			return
		# Поиск под узлом игрока
		var player := tree.get_first_node_in_group("player")
		if player != null:
			_ui = player.get_node_or_null("UI") as CanvasLayer


func start() -> void:
	if _state != State.IDLE:
		return
	_current_wave = 0
	_next_wave()


func current_wave() -> int:
	return _current_wave


func get_total_waves() -> int:
	return total_waves


func get_state() -> State:
	return _state


func active_enemies_count() -> int:
	return _active_enemies.size()


func remaining_to_spawn_count() -> int:
	return _spawn_queue.size()


func _physics_process(delta: float) -> void:
	match _state:
		State.SPAWNING:
			_process_spawning(delta)
		State.INTERMISSION:
			_process_intermission(delta)


func _process_spawning(delta: float) -> void:
	if _spawn_queue.is_empty():
		_state = State.COMBAT
		return

	_spawn_timer += delta
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		_spawn_next_enemy()
		if _spawn_queue.is_empty():
			_state = State.COMBAT


func _process_intermission(delta: float) -> void:
	_intermission_timer -= delta
	var current_second := int(ceil(maxf(0.0, _intermission_timer)))
	if current_second != _last_emitted_intermission_second:
		_last_emitted_intermission_second = current_second
		intermission_tick.emit(maxf(0.0, _intermission_timer))
		if _ui != null and _ui.has_method("set_intermission"):
			_ui.call("set_intermission", maxf(0.0, _intermission_timer))

	if _intermission_timer <= 0.0:
		_intermission_timer = 0.0
		intermission_ended.emit()
		_next_wave()


func skip_intermission() -> void:
	if _state == State.INTERMISSION:
		_intermission_timer = 0.0
		intermission_ended.emit()
		_next_wave()


func _next_wave() -> void:
	_current_wave += 1
	if _current_wave > total_waves:
		_complete_location()
		return

	_state = State.SPAWNING
	_spawn_timer = spawn_interval # Первый враг спавнится немедленно
	_build_wave_queue(_current_wave)
	wave_started.emit(_current_wave, total_waves)
	if _ui != null and _ui.has_method("set_wave"):
		_ui.call("set_wave", _current_wave, total_waves)


func _build_wave_queue(wave_idx: int) -> void:
	_spawn_queue.clear()
	match wave_idx:
		1:
			# Волна 1: 5 базовых контактных врагов
			for i in 5:
				_spawn_queue.append(contact_enemy_scene)
		2:
			# Волна 2: 8 контактных врагов
			for i in 8:
				_spawn_queue.append(contact_enemy_scene)
		3:
			# Волна 3: 4 контактных + 3 летающих врага
			for i in 4:
				_spawn_queue.append(contact_enemy_scene)
			for i in 3:
				_spawn_queue.append(flying_enemy_scene)
		4:
			# Волна 4: 1 Босс + 3 контактных врага свиты
			_spawn_queue.append(boss_enemy_scene)
			for i in 3:
				_spawn_queue.append(contact_enemy_scene)


func _spawn_next_enemy() -> void:
	if _spawn_queue.is_empty():
		return
	var scene := _spawn_queue.pop_front() as PackedScene
	if scene == null:
		return

	var instance := scene.instantiate() as Node3D
	if instance == null:
		return

	var spawn_pos := _pick_spawn_position()
	var spawn_parent := get_parent() if get_parent() != null else self
	spawn_parent.add_child(instance)
	instance.global_position = spawn_pos

	_active_enemies.append(instance)
	if instance.has_signal("died"):
		instance.died.connect(_on_enemy_died.bind(instance))

	if instance is BossEnemy or instance.name.to_lower().contains("boss"):
		_current_boss = instance
		boss_spawned.emit(instance)
		if _ui != null and _ui.has_method("show_boss_bar"):
			var boss_name: String = "БОСС"
			var data: Variant = instance.get("data")
			if data != null and data.get("display_name") != null:
				boss_name = str(data.get("display_name"))
			var hp := float(instance.call("health")) if instance.has_method("health") else 300.0
			var max_hp := float(instance.call("max_health")) if instance.has_method("max_health") else 300.0
			_ui.call("show_boss_bar", boss_name, hp, max_hp)
		if instance.has_signal("health_changed"):
			instance.health_changed.connect(_on_boss_health_changed)

	enemy_spawned.emit(instance)


func _pick_spawn_position() -> Vector3:
	if not spawn_points.is_empty():
		var pt := spawn_points[randi() % spawn_points.size()]
		if pt != null and is_instance_valid(pt):
			return pt.global_position

	# Запасная позиция, если точки спавна не заданы в сцене
	var angle := randf() * TAU
	var radius := randf_range(12.0, 18.0)
	var center := Vector3.ZERO
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		center = player.global_position
	return center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _on_boss_health_changed(current: float, max_val: float) -> void:
	if _ui != null and _ui.has_method("update_boss_health"):
		_ui.call("update_boss_health", current, max_val)


func _on_enemy_died(enemy: Node3D) -> void:
	if enemy == _current_boss:
		_current_boss = null
		if _ui != null and _ui.has_method("hide_boss_bar"):
			_ui.call("hide_boss_bar")

	_active_enemies.erase(enemy)
	_check_wave_completion()


func _check_wave_completion() -> void:
	if _spawn_queue.is_empty() and _active_enemies.is_empty():
		wave_completed.emit(_current_wave)
		var gs := get_node_or_null("/root/GameState") as GameState

		if _current_wave < total_waves:
			# Начисление 50 очков за завершение волны (спека PROJECT.md §7.5)
			if gs != null:
				gs.award_points(int(gs.POINTS_PER_WAVE))
			_start_intermission()
		else:
			_complete_location()


func _start_intermission() -> void:
	_state = State.INTERMISSION
	_intermission_timer = intermission_duration
	_last_emitted_intermission_second = -1
	intermission_started.emit(intermission_duration)


func _complete_location() -> void:
	_state = State.CLEARED
	var gs := get_node_or_null("/root/GameState") as GameState
	if gs != null:
		# Начисление 500 очков за зачистку локации (спека PROJECT.md §7.5)
		gs.award_points(int(gs.POINTS_PER_CLEAR))
		# Безопасная разблокировка следующей локации в лобби
		if gs.has_method("unlock_location"):
			gs.unlock_location("arena_02")

	if _ui != null and _ui.has_method("show_victory"):
		_ui.call("show_victory")

	location_cleared.emit()


## Принудительное уничтожение оставшихся врагов (для тестов).
func kill_all_active_enemies() -> void:
	var copy := _active_enemies.duplicate()
	for enemy in copy:
		if is_instance_valid(enemy):
			if enemy.has_method("take_damage"):
				enemy.call("take_damage", 99999.0)
			else:
				_on_enemy_died(enemy)
				enemy.queue_free()
