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


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	set_spawn_transform()


func set_spawn_transform() -> void:
	_spawn_transform = global_transform


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)
		_camera.rotation.x = clampf(
			_camera.rotation.x - motion.relative.y * mouse_sensitivity,
			deg_to_rad(-89.0),
			deg_to_rad(89.0)
		)
	elif event.is_action_pressed("ui_cancel"):
		_toggle_mouse_capture()
	elif event.is_action_pressed("jump"):
		_jump_queued = true
	elif event is InputEventMouseButton and event.pressed:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_toggle_mouse_capture()


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

	if _jump_queued:
		_jump_queued = false
		if is_on_floor():
			velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var current_speed := speed
	if Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO:
		current_speed *= sprint_multiplier

	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

	move_and_slide()

	if global_position.y < fall_limit:
		_respawn()


func _respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_jump_queued = false
	_camera.rotation.x = 0.0
