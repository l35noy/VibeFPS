extends SceneTree

## World integrity harness for VibeFPS.
##
## Why the old fall-off-edge check was removed: it teleported the player to
## (1000, 50, 1000), waited 240 physics frames and asserted y > -50.0. There is
## no geometry out there -- the floor in main.tscn is a single 20x20 box -- so
## there was nothing to fall *through* even with collisions disabled entirely,
## and 2 s of free fall from y = 50 only reaches y ~ 30.5. The assertion held by
## construction. It is replaced here by checks driven against real floor
## geometry, each of which a specific regression turns red.
##
## Capture: the headless display server cannot capture the cursor, so
## Input.mouse_mode stays MOUSE_MODE_VISIBLE for the whole run and player.gd's
## input gate denies every movement action. A sprint traverse pushed through
## that gate would never move the player and would sail through a "never sank
## through the floor" assertion for the wrong reason. So the Player node runs
## the same probe script tests/movement.gd uses: only the mouse mode the gate
## reads comes from the harness, everything else -- gravity, move_and_slide,
## the kill plane, the collision shape -- is the real player.gd and the real
## main.tscn. Every traverse additionally asserts the distance it actually
## covered, so a probe that failed to open the gate turns these checks red
## instead of green.
##
## Run: godot --headless --path . --script res://tests/integrity.gd
##      .\tools\run_checks.ps1 integrity


## Stand-in for player.gd, used only by this harness.
class _PlayerProbe extends "res://player.gd":
	## Mouse mode the gate is evaluated against instead of Input.mouse_mode.
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


## The floor in main.tscn is a 20x20 box spanning y = -1.0 .. 0.0, and the
## player's capsule (height 1.8, CollisionShape3D offset y = 0.9) spans
## y = 0.0 .. 1.8 relative to its own origin, so a standing player's origin sits
## exactly on the floor's top face at y = 0.0. Anything below -1.0 is
## unambiguously off the platform -- that is, underneath the slab.
const _FLOOR_TOP_Y := 0.0
const _OFF_PLATFORM_Y := -1.0
const _STAND_Y := 1.0

## The biggest position jump one physics tick can legitimately produce. Physics
## runs at 120 Hz and the fastest thing in the game is a sprint at 9 m/s
## combined with free fall, i.e. sqrt(9^2 + 9.2^2) / 120 ~ 0.11 m per tick, so
## 1.0 m leaves a 9x margin while still being far below any plausible respawn
## distance. Used as a respawn detector: _respawn() is a teleport, never motion.
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
	print("=== VibeFPS world integrity test ===")
	_drop_autoloads()
	var packed: PackedScene = load("res://main.tscn")
	if packed == null:
		print("FATAL: cannot load res://main.tscn")
		quit(1)
		return

	var world: Node3D = packed.instantiate()
	var player: CharacterBody3D = world.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		print("FATAL: Player node not found in main.tscn")
		quit(1)
		return

	# Swapped before the node enters the tree, so _ready runs on the probe. The
	# node under test is still main.tscn's Player, with the real exports,
	# collision shape and children.
	player.set_script(_PlayerProbe)
	root.add_child(world)
	await physics_frame

	print("    display=%s  Input.mouse_mode=%d (CAPTURED=%d)" % [
		DisplayServer.get_name(), Input.mouse_mode, Input.MOUSE_MODE_CAPTURED])
	print("    floor top y=%.1f, off-platform threshold y=%.1f, kill plane y=%.1f" % [
		_FLOOR_TOP_Y, _OFF_PLATFORM_Y, _fall_limit(player)])

	await _test_collision_layers(world, player)

	_check(player.get_script() == _PlayerProbe,
		"precondition: the gate probe is installed on the scene Player")
	_check(float(player.get("sprint_multiplier")) * float(player.get("speed")) > 8.0,
		"precondition: sprint speed is high enough to cross the platform fast")

	await _test_sprint_traverse_no_tunnelling(player)
	await _test_kill_plane_quiet_on_edge_fall(player)
	await _test_fall_recovery(player)

	print("=== RESULT: %d checks, %d failed, %d warnings ===" % [
		_checks, _failures.size(), _warnings.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)
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
		"precondition: main.tscn is instantiated and node-ready")

	var floor_body := world.get_node_or_null("Floor") as StaticBody3D
	_check(floor_body != null, "precondition: Floor (StaticBody3D) exists in main.tscn")
	if floor_body == null:
		return
	_check(floor_body.collision_layer == _LAYER_WORLD,
		"Floor sits on collision layer 1 (world)",
		"(collision_layer=%d, expected %d)" % [
			floor_body.collision_layer, _LAYER_WORLD])
	_check(player.collision_layer == _LAYER_PLAYER_BODY,
		"player body sits on collision layer 2 (player_body)",
		"(collision_layer=%d, expected %d)" % [
			player.collision_layer, _LAYER_PLAYER_BODY])
	_check(player.collision_mask == _LAYER_WORLD,
		"player body collides with the world (mask = layer 1)",
		"(collision_mask=%d, expected %d)" % [
			player.collision_mask, _LAYER_WORLD])


## Sprint traverse across the real 20x20 floor.
##
## What it catches, and how each one reaches the assertion:
##   * collision layers/mask broken (mask 0, or the floor's layer removed from
##     player.tscn / main.tscn) -- the player drops through the slab and
##     min_y collapses;
##   * the floor missing from main.tscn, or its CollisionShape3D removed -- the
##     same collapse;
##   * tunnelling at sprint speed -- a high-speed frame that crosses the 1 m
##     slab in one step shows up as min_y dipping below the slab;
##   * an input regression that silently stops the player -- caught by the
##     travel assertion, so the min_y assertion cannot pass by never moving.
func _test_sprint_traverse_no_tunnelling(player: CharacterBody3D) -> void:
	print("-- sprint traverse: 15 m across the real floor must not sink through it")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)

	# Start 9 m from the near (-X) edge: 200 physics frames at 5.0 * 1.8 = 9 m/s
	# cover 15 m and finish at x = +6, i.e. the whole sprint stays on the floor.
	# The traverse deliberately does NOT run off the platform -- a correct game
	# legitimately falls off a 20 m platform, so a "never went below the slab"
	# assertion across a run-off-the-edge trajectory could not be true.
	player.global_position = Vector3(-9.0, _STAND_Y, 0.0)
	player.velocity = Vector3.ZERO
	await _physics_frames(60)
	_check(player.is_on_floor(), "precondition: the player settles on the floor",
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
	print("    start=(%.2f, %.2f, %.2f)  end=(%.2f, %.2f, %.2f)" % [
		start.x, start.y, start.z, end.x, end.y, end.z])
	print("    travelled %.2f m at sprint, lowest y = %.3f (stand height %.3f)" % [
		travelled, min_y, start_y])

	_check(travelled > 12.0,
		"sprint input really drove the player across the platform",
		"(%.2f m; without this the floor assertion below would be vacuous)" % travelled)
	_check(min_y > _OFF_PLATFORM_Y,
		"sprinting across the floor never sank through it",
		"(min_y=%.3f, threshold %.1f)" % [min_y, _OFF_PLATFORM_Y])
	_check(player.is_on_floor(),
		"player is still standing on the floor after the sprint traverse",
		"(y=%.3f)" % end.y)


## The kill plane must stay silent on an ordinary fall off the platform.
##
## The player sprints past the +X edge and falls 3+ m into the void. That is
## normal gameplay, not falling out of the world, so no respawn may happen: the
## floor is 20 m across and the kill plane is 50 m down, so a fall from the
## platform cannot reach it. This is the negative half the old harness lacked --
## a check that only proved "respawn happens" would pass no matter how eagerly
## the kill plane fired.
##
## How the respawn is detected: by the teleport, not by proximity to the spawn
## point. Proximity is useless here -- the sprint carries the player straight
## *through* the spawn point on its way off the platform, so "closest approach
## to spawn" reads 0.00 m even in a perfectly correct game. A respawn instead
## shows up as a single-tick position jump, which no amount of falling can
## produce at 120 Hz.
##
## What it catches: a fall_limit regression that fires on an ordinary fall (the
## kill plane teleports the player back onto the platform mid-fall), and a kill
## plane raised so that merely walking off a platform respawns you.
func _test_kill_plane_quiet_on_edge_fall(player: CharacterBody3D) -> void:
	print("-- ordinary fall off the platform edge: the kill plane must stay quiet")
	_set_gate_mode(player, Input.MOUSE_MODE_CAPTURED)

	player.global_position = Vector3(-9.0, _STAND_Y, 0.0)
	player.velocity = Vector3.ZERO
	await _physics_frames(60)
	_check(player.is_on_floor(), "precondition: the player settles on the floor",
		"(y=%.3f)" % player.global_position.y)

	var kill_plane := _fall_limit(player)
	var start := player.global_position
	var min_y := start.y
	var max_step := 0.0
	var prev := player.global_position
	var left_the_platform := false

	Input.action_press("move_right")
	Input.action_press("sprint")
	# 360 frames: the +X edge (x = 10, capsule radius 0.4) is ~248 frames away
	# at sprint speed, leaving ~0.9 s of falling, i.e. roughly y = -3.7. That is
	# well clear of the platform but nowhere near the kill plane at -50.
	for i in 360:
		await physics_frame
		var pos := player.global_position
		min_y = minf(min_y, pos.y)
		max_step = maxf(max_step, pos.distance_to(prev))
		prev = pos
		if pos.x > 10.0:
			left_the_platform = true
	Input.action_release("sprint")
	Input.action_release("move_right")

	var end := player.global_position
	var travelled := _xz_distance(player, start)
	print("    travelled %.2f m off the +X edge, lowest y = %.3f (kill plane %.1f)" % [
		travelled, min_y, kill_plane])
	print("    largest single-tick jump %.3f m (teleport threshold %.1f m)" % [
		max_step, _TELEPORT_M])
	print("    final pos=(%.2f, %.2f, %.2f), on_floor=%s, vy=%.3f" % [
		end.x, end.y, end.z, player.is_on_floor(), player.velocity.y])

	_check(travelled > 15.0 and left_the_platform,
		"the sprint really carried the player off the platform",
		"(%.2f m, ended at x=%.2f)" % [travelled, end.x])
	_check(min_y < _OFF_PLATFORM_Y,
		"precondition: the player really fell below platform height",
		"(min_y=%.3f)" % min_y)
	_check(min_y > kill_plane,
		"precondition: that fall never reached the kill plane",
		"(min_y=%.3f > %.1f; without this the silence below proves nothing)" % [
			min_y, kill_plane])
	_check(max_step < _TELEPORT_M,
		"kill plane does NOT fire on an ordinary fall off the platform",
		"(largest single-tick jump %.3f m; sprint 9.0 m/s plus gravity moves at most ~0.11 m per 1/120 s tick)" % max_step)
	_check(not player.is_on_floor() and player.velocity.y < 0.0,
		"the player is still airborne over the void, not respawned on the floor",
		"(on_floor=%s, vy=%.3f)" % [player.is_on_floor(), player.velocity.y])


## The positive half: falling past the kill plane is now DEATH (Task 7), not a
## silent respawn -- the player must return to the lobby with reason "fall".
##
## Observed through a recording GameState whose scene_changer is a stub: the
## scene never actually changes, so the player stays below the kill plane. That
## is exactly the condition the "exactly once" gate has to survive -- a naive
## fall branch would call died/return_to_lobby every physics frame.
##
## The old world-integrity meaning ("the player is pulled out of the void and
## never falls forever") is kept as a separate fallback section: with no
## /root/GameState the fall branch respawns the player at the spawn transform,
## alive and on the floor.
func _test_fall_recovery(player: CharacterBody3D) -> void:
	print("-- fall recovery: falling past the kill plane is death -> lobby")
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
	player.global_position = Vector3(0, 5, 40)
	player.velocity = Vector3.ZERO

	var entered := false
	for i in 600:
		await physics_frame
		if not spy.lobby_reasons.is_empty():
			entered = true
			break
	_check(entered, "падение за kill-plane просит возврат в лобби",
		"(y=%.2f, kill plane %.1f)" % [player.global_position.y, kill_plane])
	_check(_packed_strings_eq(spy.lobby_reasons, ["fall"]),
		"падение возвращает в лобби с причиной \"fall\"",
		"(получено %s)" % str(spy.lobby_reasons))
	_check(_packed_strings_eq(_lobby_changes, ["res://lobby.tscn"]),
		"падение просит у scene_changer ровно res://lobby.tscn",
		"(получено %s)" % str(_lobby_changes))
	_check(_died_count == 1, "падение испускает died ровно один раз",
		"(got %d)" % _died_count)
	_check(not _alive_at_death, "в момент сигнала died игрок уже мёртв (is_alive() == false)",
		"(got %s)" % _alive_at_death)
	_check(absf(_health_at_death) < _HEALTH_EPS, "в момент сигнала died здоровье равно 0.0",
		"(got %.4f)" % _health_at_death)

	# Stub scene_changer means the scene does NOT change: the player stays below
	# the kill plane. 60 more frames of falling must add neither a second died
	# nor a second return_to_lobby -- that is the exactly-once gate under test.
	var below_after_gate := player.global_position.y < kill_plane
	await _physics_frames(60)
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
	player.global_position = Vector3(0, 5, 40)
	player.velocity = Vector3.ZERO
	var respawned := false
	for i in 600:
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
	await _physics_frames(30)
	_check(player.is_on_floor(), "fallback: вернувшийся игрок снова на полу",
		"(y=%.3f)" % player.global_position.y)
	_check(bool(player.call("is_alive")),
		"fallback: вернувшийся игрок снова жив (здоровье восстановлено)")
	_check(player.velocity.length() < 0.01, "fallback: скорость обнулена на точке появления",
		"(v=%.3f, %.3f, %.3f)" % [player.velocity.x, player.velocity.y, player.velocity.z])