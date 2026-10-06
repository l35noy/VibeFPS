extends SceneTree

## Visual capture harness: runs main.tscn, simulates gameplay, saves viewport PNGs.
## Run (windowed, needed for real rendering):
##   godot --path . --script res://tests/capture.gd

const OUT_DIR := "user://captures"

var _player: CharacterBody3D
var _cam: Camera3D
var _shot := 0
var _log: Array[String] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var packed: PackedScene = load("res://main.tscn")
	var world: Node3D = packed.instantiate()
	root.add_child(world)
	await process_frame
	_player = world.get_node("Player")
	_cam = _player.get_node("Camera3D")
	_run.call_deferred()


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "%s/%02d_%s.png" % [OUT_DIR, _shot, label]
	img.save_png(path)
	var avg := _avg_color(img)
	print("SHOT %02d %-16s %dx%d avg=(%.3f,%.3f,%.3f) -> %s" % [
		_shot, label, img.get_width(), img.get_height(),
		avg.x, avg.y, avg.z, ProjectSettings.globalize_path(path)])
	_shot += 1


func _avg_color(img: Image) -> Vector3:
	var total := Vector3.ZERO
	var n := 0
	var step := maxi(1, int(minf(img.get_width(), img.get_height()) / 40.0))
	var y := 0
	while y < img.get_height():
		var x := 0
		while x < img.get_width():
			var c := img.get_pixel(x, y)
			total += Vector3(c.r, c.g, c.b)
			n += 1
			x += step
		y += step
	if n == 0:
		return Vector3.ZERO
	return total / float(n)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _press(action: String) -> void:
	Input.action_press(action)


func _release(action: String) -> void:
	Input.action_release(action)


func _look(dx: float, dy: float) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(dx, dy)
	Input.parse_input_event(ev)


func _jump() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.physical_keycode = KEY_SPACE
	ev.pressed = true
	Input.parse_input_event(ev)


func _run() -> void:
	print("=== visual capture ===")
	print("mouse_mode=%d" % Input.mouse_mode)

	await _frames(60)
	await _snap("spawn")

	# look up to the sky
	_look(0, -300)
	await _frames(10)
	await _snap("look_up")

	# look down at the floor
	_look(0, 600)
	await _frames(10)
	await _snap("look_down")
	_look(0, -300)
	await _frames(5)

	# walk forward
	_press("move_forward")
	await _frames(120)
	await _snap("walk_forward")
	_release("move_forward")
	await _frames(10)

	# sprint forward
	_press("move_forward")
	_press("sprint")
	await _frames(120)
	await _snap("sprint")
	_release("move_forward")
	_release("sprint")
	await _frames(10)

	# strafe
	_press("move_right")
	await _frames(90)
	await _snap("strafe_right")
	_release("move_right")
	await _frames(10)

	# jump
	_jump()
	await _frames(18)
	await _snap("jump_rise")
	await _frames(120)
	await _snap("jump_fall")

	# walk off the edge of the 20x20 platform
	_player.global_position = Vector3(9.0, 0.0, 0.0)
	_player.velocity = Vector3.ZERO
	await _frames(5)
	_press("move_right")
	await _frames(90)
	await _snap("walk_off_edge")
	_release("move_right")
	await _frames(200)
	await _snap("after_fall")

	print("final pos=%s" % _player.global_position)
	print("=== done ===")
	quit()
