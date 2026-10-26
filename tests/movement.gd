extends SceneTree

## Тестовый сценарий перемещения для VibeFPS: локомоция, прыжок, обзор мышью и
## гейт ввода. Управляет реальным узлом игрока через симулированный ввод.
##
## Захват курсора: в headless-режиме DisplayServer не может захватывать курсор
## (Input.mouse_mode всегда остается VISIBLE). Поэтому узел Player запускается
## с тестовым скриптом-зондом _PlayerProbe, предоставляющим явный режим мыши
## (gate_mouse_mode) и счетчик переключений захвата (capture_toggles).
##
## Запуск: godot --headless --path . --script res://tests/movement.gd
##         .\tools\run_checks.ps1 movement


## Тестовый зонд на базе player.gd.
class _PlayerProbe extends "res://entities/player/player.gd":
	## Режим мыши, передаваемый гейту ввода вместо Input.mouse_mode.
	var gate_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
	## Количество запросов переключения захвата курсора.
	var capture_toggles: int = 0

	func _mouse_mode_for_play_input() -> int:
		return gate_mouse_mode

	func _toggle_mouse_capture() -> void:
		capture_toggles += 1
		super()


var _failures: PackedStringArray = []
var _warnings: PackedStringArray = []
var _checks := 0


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


func _warn(label: String) -> void:
	_warnings.append(label)
	print("  [WARN] %s" % label)


func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame


func _wait_landed(player: CharacterBody3D, max_frames: int = 120) -> void:
	for i in max_frames:
		await physics_frame
		if player.is_on_floor():
			break


func _gate_mode(player: CharacterBody3D) -> int:
	return int(player.get("gate_mouse_mode"))


func _set_gate_mode(player: CharacterBody3D, mode: int) -> void:
	player.set("gate_mouse_mode", mode)


func _capture_toggles(player: CharacterBody3D) -> int:
	return int(player.get("capture_toggles"))


func _jump_queued(player: CharacterBody3D) -> bool:
	return bool(player.get("_jump_queued"))


func _xz_distance(player: CharacterBody3D, from: Vector3) -> float:
	return Vector2(
		player.global_position.x - from.x,
		player.global_position.z - from.z).length()


func _xz_speed(player: CharacterBody3D) -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


## Экспортированные значения считываются напрямую из узла.
func _declared_walk_speed(player: CharacterBody3D) -> float:
	return float(player.get("speed"))


func _declared_sprint_speed(player: CharacterBody3D) -> float:
	return float(player.get("speed")) * float(player.get("sprint_multiplier"))


func _key_event(action: String) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE if action == "jump" else 0
	ev.keycode = KEY_SPACE
	ev.pressed = true
	return ev


func _action_event(action: String) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


func _mouse_button_event(index: MouseButton, pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = index
	ev.pressed = pressed
	return ev


## Новый экземпляр события мыши для каждого вызова во избежание накопления дельт в Godot.
func _mouse_motion_event(relative: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.relative = relative
	return ev


func _initialize() -> void:
	print("=== VibeFPS: тест перемещения и гейта ввода ===")
	var packed: PackedScene = load("res://levels/arena_01/arena_01.tscn")
	if packed == null:
		print("КРИТИЧЕСКАЯ ОШИБКА: не удалось загрузить res://levels/arena_01/arena_01.tscn")
		quit(1)
		return

	var world: Node3D = packed.instantiate()
	var player: CharacterBody3D = world.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		print("КРИТИЧЕСКАЯ ОШИБКА: узел Player не найден в arena_01.tscn")
		quit(1)
		return

	player.set_script(_PlayerProbe)
	root.add_child(world)
	await physics_frame

	print("    сервер_дисплея=%s  Input.mouse_mode=%d (CAPTURED=%d)" % [
		DisplayServer.get_name(), Input.mouse_mode, Input.MOUSE_MODE_CAPTURED])

	await _test_gate_harness(player)
	await _test_idle(player)
	await _test_walk_forward(player)
	await _test_strafe(player)
	await _test_sprint(player)
	await _test_ground_acceleration(player)
	await _test_braking(player)
	await _test_air_control(player)
	await _test_jump(player)
	await _test_jump_height(player)
	await _test_jump_action_event(player)
	await _test_mouse_look(player)
	await _test_mouse_uncaptured(player)
	await _test_play_input_denied_while_uncaptured(player)
	await _test_queued_jump_not_fired_after_release(player)
	await _test_capture_toggle_binding(player)
	await _test_player_source_contract()
	await _test_no_stuck_velocity(player)

	print("=== ИТОГ: проверок %d, ошибок %d, предупреждений %d ===" % [
		_checks, _failures.size(), _warnings.size()])
	for f in _failures:
		print("  ОШИБКА: %s" % f)
	quit(1 if _failures.size() > 0 else 0)


## Проверка работы тестового зонда и базового гейта ввода.
func _test_gate_harness(player: CharacterBody3D) -> void:
	print("-- gate harness: тестовый зонд активен и player.gd проверяет Input.mouse_mode")
	_check(player.get_script() == _PlayerProbe, "Player в сцене использует тестовый скрипт-зонд")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	_check(_gate_mode(player) == Input.MOUSE_MODE_CAPTURED, "тестовый сценарий может переключать режим гейта")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"предусловие: headless-сервер действительно не захватывает курсор",
		"(mouse_mode=%d)" % Input.mouse_mode)

	var stock: Node = (load("res://entities/player/player.tscn") as PackedScene).instantiate()
	_check(int(stock.call("_mouse_mode_for_play_input")) == Input.mouse_mode,
		"player.gd проверяет режим курсора Input.mouse_mode")
	stock.free()

	_check(InputGate.is_play_input_allowed(Input.MOUSE_MODE_CAPTURED),
		"гейт разрешает игровой ввод при захваченном курсоре")
	_check(not InputGate.is_play_input_allowed(Input.MOUSE_MODE_VISIBLE),
		"гейт блокирует игровой ввод при свободном курсоре")


func _test_idle(player: CharacterBody3D) -> void:
	print("-- idle (захват): опускание на пол и остановка движения")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	await _physics_frames(20)
	_check(player.is_on_floor(), "игрок стоит на полу после приземления")
	_check(absf(player.velocity.y) < 0.01, "вертикальная скорость равна 0 в состоянии покоя",
		"(vy=%.3f)" % player.velocity.y)
	var pos := player.global_position
	_check(pos.y < 1.0, "игрок не провалился сквозь пол",
		"(y=%.3f)" % pos.y)


func _test_walk_forward(player: CharacterBody3D) -> void:
	print("-- ходьба вперед (W) в течение 1 с")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	var start := player.global_position
	Input.action_press("move_forward")
	await _physics_frames(120)
	var held_speed := _xz_speed(player)
	Input.action_release("move_forward")
	await _physics_frames(5)
	var dist := _xz_distance(player, start)
	_check(dist > 4.0 and dist < 6.0, "дистанция ходьбы ~5 м (с учетом разгона)",
		"(получено %.2f м)" % dist)
	_check(absf(held_speed - _declared_walk_speed(player)) < 0.01,
		"установившаяся скорость ходьбы равна объявленной скорости",
		"(получено %.4f, объявлено %.4f)" % [held_speed, _declared_walk_speed(player)])
	_check(player.is_on_floor(), "игрок остается на полу после ходьбы")


func _test_strafe(player: CharacterBody3D) -> void:
	print("-- стрейф вправо (D) в течение 0.5 с, смещение по X")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	var start := player.global_position
	Input.action_press("move_right")
	await _physics_frames(60)
	Input.action_release("move_right")
	await _physics_frames(5)
	var dx := player.global_position.x - start.x
	_check(dx > 1.5, "стрейф перемещает игрока по оси X", "(dx=%.2f)" % dx)


func _test_sprint(player: CharacterBody3D) -> void:
	print("-- спринт (Shift+W): скорость должна быть выше обычной ходьбы")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	var walk_start := player.global_position
	Input.action_press("move_forward")
	await _physics_frames(120)
	Input.action_release("move_forward")
	await _physics_frames(5)
	var walk_dist := _xz_distance(player, walk_start)

	player.global_position = Vector3(0, player.global_position.y, 0)
	player.velocity = Vector3.ZERO
	await _physics_frames(10)

	var sprint_start := player.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _physics_frames(120)
	var sprint_speed := _xz_speed(player)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _physics_frames(5)
	var sprint_dist := _xz_distance(player, sprint_start)

	print("    ходьба=%.2f м, спринт=%.2f м" % [walk_dist, sprint_dist])
	_check(sprint_dist > walk_dist * 1.3, "спринт заметно быстрее обычной ходьбы")
	_check(absf(sprint_speed - _declared_sprint_speed(player)) < 0.01,
		"установившаяся скорость спринта равна speed * sprint_multiplier",
		"(получено %.4f, объявлено %.4f)" % [sprint_speed, _declared_sprint_speed(player)])


## Ускорение на земле: плавный разгон до установленной скорости.
func _test_ground_acceleration(player: CharacterBody3D) -> void:
	print("-- ground acceleration: плавный разгон до установленной скорости")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	player.global_position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await _physics_frames(15)
	_check(player.is_on_floor(), "на полу перед началом разгона")

	var declared := _declared_walk_speed(player)
	Input.action_press("move_forward")
	await _physics_frames(4)
	var early := _xz_speed(player)
	_check(early > 0.0, "ввод начинает ускорять игрока",
		"(v=%.3f м/с после 4 кадров)" % early)
	_check(early < declared * 0.5,
		"скорость не перескакивает мгновенно на максимум на первых кадрах",
		"(v=%.3f, объявлено %.3f)" % [early, declared])

	await _physics_frames(20)
	var later := _xz_speed(player)
	_check(later > early, "скорость продолжает расти между замерами",
		"(%.3f -> %.3f м/с)" % [early, later])

	await _physics_frames(66)
	var settled := _xz_speed(player)
	_check(absf(settled - declared) < 0.01,
		"установившаяся скорость равна объявленной",
		"(получено %.4f, объявлено %.4f)" % [settled, declared])
	Input.action_release("move_forward")
	await _physics_frames(15)


## Торможение: постепенное замедление до полной остановки.
func _test_braking(player: CharacterBody3D) -> void:
	print("-- braking: постепенное замедление до полной остановки")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	player.global_position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await _physics_frames(15)
	Input.action_press("move_forward")
	await _physics_frames(45)
	var before := _xz_speed(player)
	_check(absf(before - _declared_walk_speed(player)) < 0.01,
		"предусловие: игрок движется с номинальной скоростью перед торможением",
		"(v=%.4f)" % before)

	Input.action_release("move_forward")
	await _physics_frames(3)
	var coasting := _xz_speed(player)
	_check(coasting > 2.0,
		"торможение плавное: движение продолжается первые кадры после отпускания клавиши",
		"(v=%.3f после 3 кадров)" % coasting)

	await _physics_frames(37)
	var stopped := _xz_speed(player)
	_check(stopped < 0.01,
		"полная остановка за ограниченное время, без остаточного скольжения",
		"(v=%.4f после 40 кадров)" % stopped)


## Контроль в воздухе: ускорение в воздухе слабее ускорения на земле.
func _test_air_control(player: CharacterBody3D) -> void:
	print("-- air control: ускорение в воздухе слабее ускорения на земле")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	player.global_position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await _physics_frames(15)
	_check(player.is_on_floor(), "на полу перед сравнением контроля в воздухе")

	Input.action_press("move_forward")
	await _physics_frames(15)
	var ground_gain := _xz_speed(player)
	Input.action_release("move_forward")
	await _physics_frames(15)
	_check(ground_gain > 1.0, "разгон на земле зафиксирован (корректное сравнение)",
		"(прирост=%.3f м/с)" % ground_gain)
	_check(_xz_speed(player) < 0.01, "полная остановка перед тестом в воздухе",
		"(v=%.4f)" % _xz_speed(player))

	Input.parse_input_event(_key_event("jump"))
	await _physics_frames(10)
	_check(not player.is_on_floor(), "игрок находится в воздухе для замера")
	Input.action_press("move_forward")
	await _physics_frames(15)
	var air_gain := _xz_speed(player)
	Input.action_release("move_forward")
	_check(air_gain > 0.0, "ввод в воздухе дает ускорение",
		"(прирост=%.3f м/с)" % air_gain)
	_check(air_gain < ground_gain * 0.75,
		"ускорение в воздухе слабее ускорения на земле",
		"(воздух %.3f против земли %.3f м/с)" % [air_gain, ground_gain])
	await _wait_landed(player)


func _test_jump(player: CharacterBody3D) -> void:
	print("-- jump (клавиша Пробел): отрыв от пола и приземление")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	_check(player.is_on_floor(), "на полу перед прыжком")
	Input.parse_input_event(_key_event("jump"))
	await _physics_frames(10)
	var airborne := not player.is_on_floor()
	_check(airborne, "игрок оторвался от пола после прыжка")
	_check(player.velocity.y > 0.0, "приложена вертикальная скорость",
		"(vy=%.2f)" % player.velocity.y)
	await _wait_landed(player)
	_check(player.is_on_floor(), "игрок приземлился обратно на пол")


func _test_jump_height(player: CharacterBody3D) -> void:
	print("-- измерение высоты вершины прыжка")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	player.global_position = Vector3(0, 0.0, 0)
	player.velocity = Vector3.ZERO
	await _physics_frames(15)
	var ground_y := player.global_position.y
	var apex := ground_y
	Input.parse_input_event(_key_event("jump"))
	for i in 400:
		await physics_frame
		apex = maxf(apex, player.global_position.y)
		if i > 5 and player.is_on_floor():
			break
	print("    вершина=%.3f м над уровнем пола" % (apex - ground_y))
	_check(apex - ground_y > 0.2, "прыжок обеспечивает измеримый подъем")
	_check(player.is_on_floor(), "игрок вернулся на пол после теста вершины прыжка")


func _test_jump_action_event(player: CharacterBody3D) -> void:
	print("-- jump (действие InputEventAction): виртуальный ввод/геймпад также вызывает прыжок")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	player.global_position = Vector3(0, 0.0, 0)
	player.velocity = Vector3.ZERO
	await _physics_frames(10)
	_check(player.is_on_floor(), "на полу перед прыжком по действию")
	Input.parse_input_event(_action_event("jump"))
	await _physics_frames(10)
	_check(not player.is_on_floor(), "игрок оторвался от пола после прыжка по действию")
	_check(player.velocity.y > 0.0, "прыжок по действию приложил вертикальную скорость",
		"(vy=%.2f)" % player.velocity.y)
	await _wait_landed(player)
	_check(player.is_on_floor(), "игрок приземлился на пол после прыжка по действию")


func _test_mouse_look(player: CharacterBody3D) -> void:
	print("-- mouse look (захват): поворот рыскания и тангажа с ограничением")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		_failures.append("отсутствует Camera3D для теста обзора мышью")
		_checks += 1
		print("  [FAIL] отсутствует Camera3D для теста обзора мышью")
		return
	var yaw0 := player.rotation.y
	var pitch0 := cam.rotation.x

	Input.parse_input_event(_mouse_motion_event(Vector2(100, 0)))
	await physics_frame
	_check(absf(player.rotation.y - yaw0) > 0.0001, "угол рыскания (yaw) изменился при горизонтальном движении мыши",
		"(dyaw=%.4f)" % (player.rotation.y - yaw0))

	# Ограничение тангажа при сильном движении вниз.
	Input.parse_input_event(_mouse_motion_event(Vector2(0, 100000)))
	await physics_frame
	var min_pitch := deg_to_rad(-89.0)
	var max_pitch := deg_to_rad(89.0)
	_check(cam.rotation.x >= min_pitch - 0.001 and cam.rotation.x <= max_pitch + 0.001,
		"угол тангажа (pitch) ограничен диапазоном +-89 градусов", "(pitch=%.2f град)" % rad_to_deg(cam.rotation.x))

	# Ограничение тангажа при движении вверх.
	Input.parse_input_event(_mouse_motion_event(Vector2(0, -100000)))
	await physics_frame
	_check(cam.rotation.x >= min_pitch - 0.001 and cam.rotation.x <= max_pitch + 0.001,
		"тангаж ограничен и при движении мыши вверх", "(pitch=%.2f град)" % rad_to_deg(cam.rotation.x))
	cam.rotation.x = pitch0


func _test_mouse_uncaptured(player: CharacterBody3D) -> void:
	print("-- свободный курсор: движение мыши НЕ должно вращать камеру")
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		_failures.append("отсутствует Camera3D для теста захвата мыши")
		_checks += 1
		print("  [FAIL] отсутствует Camera3D для теста захвата мыши")
		return
	var yaw0 := player.rotation.y
	var pitch0 := cam.rotation.x

	_set_gate_mode(player, Input.MOUSE_MODE_VISIBLE)
	Input.parse_input_event(_mouse_motion_event(Vector2(200, 50)))
	await physics_frame
	_check(absf(player.rotation.y - yaw0) < 0.0001, "угол рыскания не меняется при свободном курсоре",
		"(dyaw=%.4f)" % (player.rotation.y - yaw0))
	_check(absf(cam.rotation.x - pitch0) < 0.0001, "угол тангажа не меняется при свободном курсоре",
		"(dpitch=%.4f)" % (cam.rotation.x - pitch0))

	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	var yaw1 := player.rotation.y
	Input.parse_input_event(_mouse_motion_event(Vector2(200, 50)))
	await physics_frame
	_check(absf(player.rotation.y - yaw1) > 0.0001, "рыскание снова поворачивается после захвата курсора",
		"(dyaw=%.4f)" % (player.rotation.y - yaw1))
	_check(absf(cam.rotation.x - pitch0) > 0.0001, "тангаж снова поворачивается после захвата курсора",
		"(dpitch=%.4f)" % (cam.rotation.x - pitch0))
	cam.rotation.x = pitch0


## Свободный курсор блокирует перемещение, спринт и прыжок.
func _test_play_input_denied_while_uncaptured(player: CharacterBody3D) -> void:
	print("-- input gating: свободный курсор блокирует перемещение, спринт и прыжок")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	player.global_position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await _physics_frames(15)
	_check(player.is_on_floor(), "на полу перед проверкой гейта")

	var start := player.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _physics_frames(90)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var allowed := _xz_distance(player, start)
	print("    захвачен: перемещение %.2f м" % allowed)
	_check(allowed > 3.0, "захваченный курсор перемещает игрока при том же вводе",
		"(перемещение %.2f м)" % allowed)

	player.global_position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await _physics_frames(15)
	_check(player.is_on_floor(), "игрок на полу перед проверкой блокировки")
	start = player.global_position

	_set_gate_mode(player, Input.MOUSE_MODE_VISIBLE)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	Input.parse_input_event(_key_event("jump"))
	await _physics_frames(20)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var denied := _xz_distance(player, start)
	print("    свободен: перемещение %.4f м" % denied)
	_check(denied <= 0.01, "свободный курсор не позволяет перемещать игрока",
		"(перемещение %.4f м)" % denied)
	_check(absf(player.velocity.x) < 0.01 and absf(player.velocity.z) < 0.01,
		"горизонтальная скорость обнулена при заблокированном вводе",
		"(v=%.4f, %.4f)" % [player.velocity.x, player.velocity.z])
	_check(player.is_on_floor(), "свободный курсор блокирует прыжок игрока")
	_check(absf(player.velocity.y) < 0.01, "вертикальная скорость не появляется при заблокированном вводе",
		"(vy=%.4f)" % player.velocity.y)
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)


## Буферизация прыжка: прыжок, поставленный в очередь до освобождения курсора, не должен выполняться после.
func _test_queued_jump_not_fired_after_release(player: CharacterBody3D) -> void:
	print("-- queued jump: прыжок, поставленный в очередь до освобождения курсора, не должен выполняться после")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	player.global_position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await _physics_frames(15)
	_check(player.is_on_floor(), "на полу перед постановкой прыжка в очередь")

	Input.parse_input_event(_key_event("jump"))
	Input.flush_buffered_events()
	_check(_jump_queued(player), "прыжок поставлен в очередь при захваченном курсоре")

	_set_gate_mode(player, Input.MOUSE_MODE_VISIBLE)
	await _physics_frames(20)
	_check(not _jump_queued(player), "прыжок сброшен из очереди и не завис")
	_check(player.is_on_floor(), "отложенный прыжок не срабатывает после освобождения курсора")
	_check(player.velocity.y <= 0.01, "вертикальная скорость не появляется после освобождения курсора",
		"(vy=%.3f)" % player.velocity.y)
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)


## Переключение захвата курсора: пауза переключает режим, ЛКМ не переключает.
func _test_capture_toggle_binding(player: CharacterBody3D) -> void:
	print("-- capture toggle: пауза переключает режим, ЛКМ не переключает")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	var before := _capture_toggles(player)
	Input.parse_input_event(_action_event("pause"))
	await physics_frame
	_check(_capture_toggles(player) == before + 1,
		"действие pause переключает захват курсора",
		"(переключений=%d)" % (_capture_toggles(player) - before))

	var lmb_before := _capture_toggles(player)
	Input.parse_input_event(_mouse_button_event(MOUSE_BUTTON_LEFT, true))
	await physics_frame
	_check(Input.is_action_pressed("fire"),
		"нажатие ЛКМ активирует действие fire")
	_check(_capture_toggles(player) == lmb_before,
		"ЛКМ НЕ переключает захват курсора",
		"(переключений=%d)" % (_capture_toggles(player) - lmb_before))
	Input.parse_input_event(_mouse_button_event(MOUSE_BUTTON_LEFT, false))
	await physics_frame
	_check(not Input.is_action_pressed("fire"),
		"отпускание ЛКМ деактивирует действие fire")


## Проверка исходного кода player.gd на отсутствие устаревших привязок.
func _test_player_source_contract() -> void:
	print("-- source contract: проверка отсутствия старых привязок ui_cancel и MouseButton в player.gd")
	var src := FileAccess.get_file_as_string("res://entities/player/player.gd")
	_check(src != "", "файл player.gd доступен для чтения", "(%d байт)" % src.length())
	_check(not src.contains("ui_cancel"),
		"player.gd не использует стандартное действие ui_cancel")
	_check(not src.contains("InputEventMouseButton"),
		"player.gd не содержит ветвления по InputEventMouseButton")
	_check(src.count("InputGate.is_play_input_allowed(") >= 2,
		"player.gd обращается к InputGate в обоих путях обработки ввода",
		"(вызовов=%d)" % src.count("InputGate.is_play_input_allowed("))
	_check(src.count("_mouse_mode_for_play_input() -> int") == 1,
		"player.gd считывает Input.mouse_mode для гейта ровно в одном методе")


func _test_no_stuck_velocity(player: CharacterBody3D) -> void:
	print("-- release check: отсутствие остаточной горизонтальной скорости после отпускания ввода")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)
	await _physics_frames(10)
	_check(absf(player.velocity.x) < 0.01 and absf(player.velocity.z) < 0.01,
		"горизонтальная скорость равна 0 после отпускания клавиш",
		"(v=%.3f, %.3f)" % [player.velocity.x, player.velocity.z])