extends SceneTree

## Тестовый сценарий целостности мира для VibeFPS.
##
## Проверяет коллизии статической геометрии, отсутствие проваливания сквозь пол
## при быстром спринте и логику обработки падения за пределы платформы (kill plane).
##
## Захват курсора: в headless-режиме DisplayServer не может захватывать курсор
## (Input.mouse_mode всегда MOUSE_MODE_VISIBLE), поэтому игрок запускается с тестовым
## скриптом _PlayerProbe, открывающим гейт ввода.
##
## Запуск: godot --headless --path . --script res://tests/integrity.gd
##         .\tools\run_checks.ps1 integrity


## Тестовый зонд на базе player.gd.
class _PlayerProbe extends "res://entities/player/player.gd":
	## Режим мыши, передаваемый гейту ввода вместо Input.mouse_mode.
	var gate_mouse_mode: int = Input.MOUSE_MODE_CAPTURED

	func _mouse_mode_for_play_input() -> int:
		return gate_mouse_mode


## Записывающий GameState: тот же класс, что у автозагрузки, но с записью
## причины возврата в лобби и подменённым scene_changer. Падение игрока идёт
## через него: настоящий change_scene_to_file снёс бы это же дерево.
## Образец — tests/enemies.gd::_RecordingGameState.
##
## `return_to_lobby` переопределён, потому что reason не доходит до
## `scene_changer` (GameState зовёт его только с путём сцены): «падение просит
## лобби» и «падение просит лобби ПО ПРИЧИНЕ падения» — разные утверждения, и
## второе видно только изнутри самого вызова.
class _RecordingGameState extends GameState:
	var lobby_reasons: PackedStringArray = []

	func return_to_lobby(reason: String) -> void:
		lobby_reasons.append(reason)
		super.return_to_lobby(reason)


## Пол в main.tscn — параллелепипед 20x20 от y = -1.0 до 0.0,
## капсула игрока (высота 1.8) опирается на уровень пола y = 0.0.
const _FLOOR_TOP_Y := 0.0
const _OFF_PLATFORM_Y := -1.0
const _STAND_Y := 0.0

## Максимальный скачок позиции за один физический тик при обычном движении (порог детекции телепорта/респавна).
const _TELEPORT_M := 1.0

## Допуск сравнения здоровья: все числа в проверке — целые десятые доли, так что
## 0.0001 отделяет настоящее расхождение от двоичного представления float.
const _HEALTH_EPS := 0.0001

## Битовые маски слоёв из [layer_names] project.godot: слой N = 2^(N-1),
## поэтому 1 world = 1, 2 player_body = 2.
const _LAYER_WORLD := 1
const _LAYER_PLAYER_BODY := 2

var _failures: PackedStringArray = []
var _warnings: PackedStringArray = []
var _checks := 0

## Пробный GameState, пока он стоит в /root. null означает «в root его нет» —
## ровно то состояние, которого требует fallback-ветка падения.
var _probe_game_state: GameState = null
## Пути, запрошенные у подменённого scene_changer, в порядке вызова.
var _lobby_changes: PackedStringArray = []
## Счётчик сигналов смерти игрока. «died ровно один» нельзя проверить по узлу
## после вызова: при fallback-респавне игрок уже выглядит полностью здоровым.
## Счётчик внутри обработчика — единственное место, где смерть ещё наблюдаема.
var _died_count: int = 0
## Здоровье и живость, увиденные обработчиком died, то есть в момент смерти.
var _health_at_death: float = -1.0
var _alive_at_death: bool = true


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


func _set_gate_mode(player: CharacterBody3D, mode: int) -> void:
	player.set("gate_mouse_mode", mode)


func _fall_limit(player: CharacterBody3D) -> float:
	return float(player.get("fall_limit"))


func _spawn_origin(player: CharacterBody3D) -> Vector3:
	return (player.get("_spawn_transform") as Transform3D).origin


func _xz_distance(player: CharacterBody3D, from: Vector3) -> float:
	return Vector2(
		player.global_position.x - from.x,
		player.global_position.z - from.z).length()


## Записывающая заглушка смены сцены: фиксирует запрос и ничего не меняет.
## Именно поэтому игрок после смерти остаётся ниже kill-plane — это и есть
## условие, на котором проверяется гейт «ровно один раз».
func _fake_scene_changer(path: String) -> void:
	_lobby_changes.append(path)


## Живость и здоровье читаются обработчиком в момент сигнала, а не после
## возврата из вызова: при fallback-респавне к тому моменту всё восстановлено.
func _on_player_died(player: Node) -> void:
	_died_count += 1
	_health_at_death = float(player.call("health"))
	_alive_at_death = bool(player.call("is_alive"))


## Ставит пробный GameState в /root. Имя "GameState" — часть контракта: player.gd
## находит его по пути /root/GameState, а не по ссылке.
func _install_probe_game_state() -> GameState:
	var gs := _RecordingGameState.new()
	gs.name = "GameState"
	gs.scene_changer = _fake_scene_changer
	root.add_child(gs)
	_probe_game_state = gs
	return gs


## Убирает пробный GameState из /root. Обязательно ДО fallback-части: живой
## /root/GameState меняет контракт падения.
func _remove_probe_game_state() -> void:
	if _probe_game_state != null and is_instance_valid(_probe_game_state):
		_probe_game_state.queue_free()
	_probe_game_state = null
	await physics_frame


## PackedStringArray vs Array по содержимому: Godot не считает два разных
## контейнера равными, поэтому `packed == ["fall"]` было бы false даже при
## совпадении содержимого.
func _packed_strings_eq(packed: PackedStringArray, expected: Array) -> bool:
	if packed.size() != expected.size():
		return false
	for i in packed.size():
		if packed[i] != expected[i]:
			return false
	return true


## Движок регистрирует GameState/SaveSystem как автозагрузки проекта
## (project.godot) и ставит одноимённые узлы под /root даже в --script-режиме.
## Харнесс целиком опирается на то, что /root/GameState ЛИБО отсутствует
## (fallback-ветка), ЛИБО это поставленная им заглушка: настоящая автозагрузка
## заслонила бы заглушку (Godot переименовал бы поздний узел при занятом имени)
## и отдала бы player.gd настоящий change_scene_to_file, который подменил бы
## сцену на lobby.tscn и завёл бы второго игрока. Освобождение немедленное, а не
## queue_free: имя должно быть свободно до добавления заглушки.
func _drop_autoloads() -> void:
	for autoload_name in ["GameState", "SaveSystem"]:
		var node := root.get_node_or_null(autoload_name)
		if node != null:
			root.remove_child(node)
			node.free()


func _initialize() -> void:
	print("=== VibeFPS: тест целостности мира ===")
	_drop_autoloads()
	var packed: PackedScene = load("res://levels/main/main.tscn")
	if packed == null:
		print("КРИТИЧЕСКАЯ ОШИБКА: не удалось загрузить res://levels/main/main.tscn")
		quit(1)
		return

	var world: Node3D = packed.instantiate()
	var player: CharacterBody3D = world.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		print("КРИТИЧЕСКАЯ ОШИБКА: узел Player не найден в main.tscn")
		quit(1)
		return

	player.set_script(_PlayerProbe)
	root.add_child(world)
	await physics_frame

	print("    сервер_дисплея=%s  Input.mouse_mode=%d (CAPTURED=%d)" % [
		DisplayServer.get_name(), Input.mouse_mode, Input.MOUSE_MODE_CAPTURED])
	print("    уровень пола y=%.1f, порог падения y=%.1f, kill plane y=%.1f" % [
		_FLOOR_TOP_Y, _OFF_PLATFORM_Y, _fall_limit(player)])

	await _test_collision_layers(world, player)

	_check(player.get_script() == _PlayerProbe,
		"предусловие: зонд гейта ввода установлен на игрока")
	_check(float(player.get("sprint_multiplier")) * float(player.get("speed")) > 8.0,
		"предусловие: скорость спринта достаточна для быстрого пересечения платформы")

	await _test_sprint_traverse_no_tunnelling(player)
	await _test_kill_plane_quiet_on_edge_fall(player)
	await _test_fall_recovery(player)

	print("=== ИТОГ: проверок %d, ошибок %d, предупреждений %d ===" % [
		_checks, _failures.size(), _warnings.size()])
	for f in _failures:
		print("  ОШИБКА: %s" % f)
	quit(1 if _failures.size() > 0 else 0)


## Проверка слоёв коллизий сцен (закрывает гэп HANDOFF §8: чека, ловящего
## регрессию слоёв, раньше не было).
##
## Слои объявлены в [layer_names] project.godot (1 world, 2 player_body и т.д.)
## и расставлены на игровых телах, но ничто не мешает при правке main.tscn или
## player.tscn молча вернуть их к значениям по умолчанию. Такие регрессии не
## рушат существующие проверки явно: сдвиг слоя пола с 1 на 2, например, тихо
## ломает урон и снаряды (игрок с маской 1 перестаёт видеть пол), а проверка
## «игрок не провалился» ловит только обнуление маски. Поэтому здесь
## проверяются сами битовые маски, а не их побочные эффекты.
##
## _ready() не синхронный относительно instantiate(): готовность узла ждётся
## явно через is_node_ready(), а не предполагается по факту инстанцирования.
func _test_collision_layers(world: Node3D, player: CharacterBody3D) -> void:
	print("-- collision layers: Floor=layer 1 (world), Player=layer 2/mask 1 (player_body -> world)")
	for i in 120:
		if world.is_node_ready():
			break
		await physics_frame
	_check(world.is_node_ready(),
		"предусловие: main.tscn инстанцирована и готова (is_node_ready)")

	var floor_body := world.get_node_or_null("Floor") as StaticBody3D
	_check(floor_body != null, "предусловие: узел Floor (StaticBody3D) существует в main.tscn")
	if floor_body == null:
		return
	_check(floor_body.collision_layer == _LAYER_WORLD,
		"Floor находится на слое коллизий 1 (world)",
		"(collision_layer=%d, ожидалось %d)" % [
			floor_body.collision_layer, _LAYER_WORLD])
	_check(player.collision_layer == _LAYER_PLAYER_BODY,
		"тело игрока находится на слое коллизий 2 (player_body)",
		"(collision_layer=%d, ожидалось %d)" % [
			player.collision_layer, _LAYER_PLAYER_BODY])
	_check(player.collision_mask == _LAYER_WORLD,
		"тело игрока сталкивается со статическим миром (маска = слой 1)",
		"(collision_mask=%d, ожидалось %d)" % [
			player.collision_mask, _LAYER_WORLD])


## Спринт по полу 20x20: проверка отсутствия проваливания (туннелирования).
func _test_sprint_traverse_no_tunnelling(player: CharacterBody3D) -> void:
	print("-- sprint traverse: спринт на 15 м по полу без проваливания")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)

	player.global_position = Vector3(-9.0, _STAND_Y, 0.0)
	player.velocity = Vector3.ZERO
	await _physics_frames(15)
	_check(player.is_on_floor(), "предусловие: игрок стоит на полу",
		"(y=%.3f)" % player.global_position.y)

	var start := player.global_position
	var start_y := start.y
	var min_y := start_y

	Input.action_press("move_right")
	Input.action_press("sprint")
	for i in 200:
		await physics_frame
		min_y = minf(min_y, player.global_position.y)
	Input.action_release("sprint")
	Input.action_release("move_right")
	await _physics_frames(5)

	var end := player.global_position
	var travelled := _xz_distance(player, start)
	print("    старт=(%.2f, %.2f, %.2f)  конец=(%.2f, %.2f, %.2f)" % [
		start.x, start.y, start.z, end.x, end.y, end.z])
	print("    пройдено %.2f м на спринте, мин y = %.3f (высота стойки %.3f)" % [
		travelled, min_y, start_y])

	_check(travelled > 12.0,
		"спринт действительно переместил игрока по платформе",
		"(пройдено %.2f м)" % travelled)
	_check(min_y > _OFF_PLATFORM_Y,
		"игрок при спринте не провалился сквозь пол",
		"(min_y=%.3f, порог %.1f)" % [min_y, _OFF_PLATFORM_Y])
	_check(player.is_on_floor(),
		"игрок остается на полу после завершения спринта",
		"(y=%.3f)" % end.y)


## Обычное падение с края платформы не должно преждевременно вызывать kill plane.
func _test_kill_plane_quiet_on_edge_fall(player: CharacterBody3D) -> void:
	print("-- ordinary fall: обычное падение с края платформы не должно триггерить kill plane преждевременно")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)

	player.global_position = Vector3(-9.0, _STAND_Y, 0.0)
	player.velocity = Vector3.ZERO
	await _physics_frames(15)
	_check(player.is_on_floor(), "предусловие: игрок стоит на полу",
		"(y=%.3f)" % player.global_position.y)

	var kill_plane := _fall_limit(player)
	var start := player.global_position
	var min_y := start.y
	var max_step := 0.0
	var prev := player.global_position
	var left_the_platform := false

	Input.action_press("move_right")
	Input.action_press("sprint")
	for i in 360:
		await physics_frame
		var pos := player.global_position
		min_y = minf(min_y, pos.y)
		max_step = maxf(max_step, pos.distance_to(prev))
		prev = pos
		if pos.x > 10.0:
			left_the_platform = true
		if left_the_platform and pos.y < _OFF_PLATFORM_Y - 1.0:
			break
	Input.action_release("sprint")
	Input.action_release("move_right")

	var end := player.global_position
	var travelled := _xz_distance(player, start)
	print("    пройдено %.2f м за край +X, мин y = %.3f (kill plane %.1f)" % [
		travelled, min_y, kill_plane])
	print("    наибольший скачок за тик %.3f м (порог телепорта %.1f м)" % [
		max_step, _TELEPORT_M])
	print("    финальная поз=(%.2f, %.2f, %.2f), на_полу=%s, vy=%.3f" % [
		end.x, end.y, end.z, player.is_on_floor(), player.velocity.y])

	_check(travelled > 15.0 and left_the_platform,
		"спринт действительно вывел игрока за пределы платформы",
		"(%.2f м, финиш на x=%.2f)" % [travelled, end.x])
	_check(min_y < _OFF_PLATFORM_Y,
		"предусловие: игрок опустился ниже уровня платформы",
		"(min_y=%.3f)" % min_y)
	_check(min_y > kill_plane,
		"предусловие: падение еще не достигло kill plane",
		"(min_y=%.3f > %.1f)" % [min_y, kill_plane])
	_check(max_step < _TELEPORT_M,
		"kill plane НЕ срабатывает преждевременно при обычном падении с края",
		"(макс скачок %.3f м)" % max_step)
	_check(not player.is_on_floor() and player.velocity.y < 0.0,
		"игрок летит в пустоту и еще не возрожден на полу",
		"(на_полу=%s, vy=%.3f)" % [player.is_on_floor(), player.velocity.y])


## Проверка падения за kill plane: игрок погибает и возвращается в лобби с причиной "fall".
func _test_fall_recovery(player: CharacterBody3D) -> void:
	print("-- fall recovery: падение за kill plane приводит к смерти и возврату в лобби")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)

	_check(root.get_node_or_null("GameState") == null,
		"precondition: до установки заглушки в /root нет GameState")

	_lobby_changes.clear()
	var gs := _install_probe_game_state()
	var spy := gs as _RecordingGameState
	await physics_frame
	_check(root.get_node_or_null("GameState") == gs,
		"precondition: пробный GameState резолвится как /root/GameState")

	_died_count = 0
	_health_at_death = -1.0
	_alive_at_death = true
	player.died.connect(_on_player_died.bind(player))

	var kill_plane := _fall_limit(player)
	player.global_position = Vector3(0, kill_plane + 2.0, 40)
	player.velocity = Vector3(0, -10.0, 0)

	var entered := false
	for i in 120:
		await physics_frame
		if not spy.lobby_reasons.is_empty():
			entered = true
			break
	_check(entered, "падение за kill-plane просит возврат в лобби",
		"(y=%.2f, kill plane %.1f)" % [player.global_position.y, kill_plane])
	_check(_packed_strings_eq(spy.lobby_reasons, ["fall"]),
		"падение возвращает в лобби с причиной \"fall\"",
		"(получено %s)" % str(spy.lobby_reasons))
	_check(_packed_strings_eq(_lobby_changes, ["res://levels/lobby/lobby.tscn"]),
		"падение просит у scene_changer ровно res://levels/lobby/lobby.tscn",
		"(получено %s)" % str(_lobby_changes))
	_check(_died_count == 1, "падение испускает died ровно один раз",
		"(got %d)" % _died_count)
	_check(not _alive_at_death, "в момент сигнала died игрок уже мёртв (is_alive() == false)",
		"(got %s)" % _alive_at_death)
	_check(absf(_health_at_death) < _HEALTH_EPS, "в момент сигнала died здоровье равно 0.0",
		"(got %.4f)" % _health_at_death)

	# Stub scene_changer means the scene does NOT change: the player stays below
	# the kill plane. 20 more frames of falling must add neither a second died
	# nor a second return_to_lobby -- that is the exactly-once gate under test.
	var below_after_gate := player.global_position.y < kill_plane
	await _physics_frames(20)
	print("    y after gate = %.2f (kill plane %.1f), died=%d, lobby=%d" % [
		player.global_position.y, kill_plane, _died_count, spy.lobby_reasons.size()])
	_check(below_after_gate and player.global_position.y < kill_plane,
		"precondition: заглушка сцену не меняет, игрок остался ниже kill-plane",
		"(y=%.2f < %.1f)" % [player.global_position.y, kill_plane])
	_check(_died_count == 1, "падение испускает died ровно один раз, а не каждый кадр",
		"(got %d)" % _died_count)
	_check(spy.lobby_reasons.size() == 1 and _lobby_changes.size() == 1,
		"return_to_lobby(\"fall\") вызван ровно один раз, а не каждый кадр",
		"(лобби=%s, смен=%s)" % [str(spy.lobby_reasons), str(_lobby_changes)])
	_check(not bool(player.call("is_alive")),
		"после смерти от падения игрок остаётся мёртвым, а не воскрешён")

	await _remove_probe_game_state()
	_check(root.get_node_or_null("GameState") == null,
		"после секции пробный GameState убран из /root — fallback снова доступен")

	# Fallback without GameState: the fall still pulls the player out of the void
	# onto the spawn transform and restores health. This is the headless / no-
	# autoload safety net, not a second death contract.
	var spawn := _spawn_origin(player)
	player.call("_respawn", true)
	await _physics_frames(2)
	_died_count = 0
	_health_at_death = -1.0
	_alive_at_death = true
	player.global_position = Vector3(0, kill_plane + 2.0, 40)
	player.velocity = Vector3(0, -10.0, 0)
	var respawned := false
	for i in 120:
		await physics_frame
		if player.global_position.distance_to(spawn) < 2.0:
			respawned = true
			break
	print("    fallback y after fall = %.2f, respawned=%s" % [
		player.global_position.y, respawned])
	_check(respawned, "fallback без GameState: падение возвращает игрока на точку появления",
		"(y=%.2f)" % player.global_position.y)
	_check(_died_count == 1, "fallback: падение испускает died ровно один раз",
		"(got %d)" % _died_count)
	await _physics_frames(10)
	_check(player.is_on_floor(), "fallback: вернувшийся игрок снова на полу",
		"(y=%.3f)" % player.global_position.y)
	_check(bool(player.call("is_alive")),
		"fallback: вернувшийся игрок снова жив (здоровье восстановлено)")
	_check(player.velocity.length() < 0.01, "fallback: скорость обнулена на точке появления",
		"(v=%.3f, %.3f, %.3f)" % [player.velocity.x, player.velocity.y, player.velocity.z])