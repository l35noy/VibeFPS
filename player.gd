extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 5.0
@export var sprint_multiplier: float = 1.8
@export var mouse_sensitivity: float = 0.002
@export var fall_limit: float = -50.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _jump_queued: bool = false
var _spawn_transform: Transform3D = Transform3D.IDENTITY

@onready var _camera: Camera3D = $Camera3D
## Пистолет игрока. Может отсутствовать: лобби Фазы 4 и любые сцены без
## оружия создают того же персонажа, и требовать в каждой из них узел с
## характеристиками оружия было бы требованием к сцене, а не к игроку.
@onready var _pistol: Pistol = get_node_or_null("Pistol") as Pistol


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	set_spawn_transform()
	_connect_focus_recapture()
	if _pistol != null:
		# Контракт смены сцены, а не гигиена: полупустой магазин, переживший
		# поездку в лобби и обратно, стоил бы игроку бесплатных патронов при
		# каждом входе в бой.
		_pistol.reset_for_scene_change()


func _exit_tree() -> void:
	_disconnect_focus_recapture()


## Захват курсора восстанавливается при возврате фокуса окну: Godot отпускает
## курсор, когда окно теряет фокус, и без этого игрок возвращался бы в игру с
## невидимым управлением.
func _connect_focus_recapture() -> void:
	var window := get_tree().root
	if window != null and not window.focus_entered.is_connected(_on_focus_entered):
		window.focus_entered.connect(_on_focus_entered)


## Отписка обязательна с проверкой is_connected: лобби и локация создают игрока
## повторно, а без неё второй вход в сцену падает на "signal already connected".
func _disconnect_focus_recapture() -> void:
	var window := get_tree().root if is_inside_tree() else null
	if window != null and window.focus_entered.is_connected(_on_focus_entered):
		window.focus_entered.disconnect(_on_focus_entered)


func _on_focus_entered() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func set_spawn_transform() -> void:
	_spawn_transform = global_transform


## Единственное место в игре, где читается Input.mouse_mode для гейта ввода.
## Обёрнуто в метод, а не вчитывается прямо в _unhandled_input и
## _physics_process, потому что headless-дисплейсер вообще не умеет захватывать
## курсор: Input.set_mouse_mode() там молча ничего не делает и Input.mouse_mode
## навсегда остаётся VISIBLE. Проверки не могут ни захватить курсор, ни подменить
## синглтон Input, поэтому подменяется только значение, попадающее в гейт.
func _mouse_mode_for_play_input() -> int:
	return Input.mouse_mode


func _unhandled_input(event: InputEvent) -> void:
	# ЛКМ здесь намеренно не обрабатывается: он принадлежит действию fire,
	# которое выстрел реализует на следующей фазе. Захват курсора
	# переключается только действием pause (Esc).
	if event is InputEventMouseMotion:
		if not InputGate.is_play_input_allowed(_mouse_mode_for_play_input()):
			return
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)
		_camera.rotation.x = clampf(
			_camera.rotation.x - motion.relative.y * mouse_sensitivity,
			deg_to_rad(-89.0),
			deg_to_rad(89.0)
		)
	elif event.is_action_pressed("pause"):
		_toggle_mouse_capture()
	elif event.is_action_pressed("jump"):
		# Проверка разрешения идёт до постановки в очередь: при свободном
		# курсоре персонаж не прыгает.
		if InputGate.is_play_input_allowed(_mouse_mode_for_play_input()):
			_jump_queued = true


func _toggle_mouse_capture() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta

	var play_input_allowed := InputGate.is_play_input_allowed(_mouse_mode_for_play_input())

	# Очередь прыжка съедается всегда, но поднимает персонаж только пока ввод
	# разрешён: прыжок, разрешённый до отпускания курсора, не должен сработать
	# после него.
	if _jump_queued:
		_jump_queued = false
		if play_input_allowed and is_on_floor():
			velocity.y = jump_velocity

	if play_input_allowed:
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

		var current_speed := speed
		if Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO:
			current_speed *= sprint_multiplier

		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		# Горизонтальная скорость обнуляется явно, а не остаётся от прошлого
		# кадра: иначе персонаж едет по инерции при свободном курсоре.
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()

	if global_position.y < fall_limit:
		_respawn()


func _respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_jump_queued = false
	_camera.rotation.x = 0.0