extends SceneTree

## Автоматический тестовый сьют волн, врагов Фазы 4 и арены (VibeFPS).
##
## Проверяет:
## 1. Ресурсы данных новых врагов: data/enemies/flying.tres и boss.tres.
## 2. Инстанцирование и контракты урона/слоёв FlyingEnemy и BossEnemy.
## 3. WaveManager: прогрессия 4 волн, постепенный спавн, передышка, начисление очков (50 за волну, 500 за зачистку) и разблокировка локации.
## 4. Проводка сцены первой арены: levels/arena_01/arena_01.tscn, навмеш, укрытия, игрок, портал.
##
## Запуск:
##   godot --headless --path . --script res://tests/waves.gd
##   pwsh -File .\tools\run_checks.ps1 waves

const _FLYING_DATA_PATH := "res://data/enemies/flying.tres"
const _BOSS_DATA_PATH := "res://data/enemies/boss.tres"
const _FLYING_SCENE_PATH := "res://entities/enemies/flying/flying_enemy.tscn"
const _BOSS_SCENE_PATH := "res://entities/enemies/boss/boss_enemy.tscn"
const _ARENA_SCENE_PATH := "res://levels/arena_01/arena_01.tscn"

const _LAYER_WORLD := 1 << 0
const _LAYER_ENEMY_BODY := 1 << 2
const _LAYER_ENEMY_HURTBOX := 1 << 3
const _LAYER_PLAYER_HURTBOX := 1 << 6
const _LAYER_INTERACTABLE := 1 << 5

var _failures: PackedStringArray = []
var _checks: int = 0
var _game_state: GameState = null

var _flying_died_count: int = 0
var _boss_died_count: int = 0
var _wave_completed_count: int = 0
var _last_completed_wave: int = -1
var _location_cleared_count: int = 0


func _on_flying_died() -> void:
	_flying_died_count += 1


func _on_boss_died() -> void:
	_boss_died_count += 1


func _on_wave_completed(wave_num: int) -> void:
	_wave_completed_count += 1
	_last_completed_wave = wave_num


func _on_location_cleared() -> void:
	_location_cleared_count += 1


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame


func _initialize() -> void:
	print("=== VibeFPS: Тестирование волн, врагов Фазы 4 и арены ===")

	_setup_test_game_state()

	await _test_enemy_data_resources()
	await _test_flying_enemy_contracts()
	await _test_boss_enemy_contracts()
	await _test_wave_manager_progression()
	await _test_arena_scene_wiring()

	_cleanup_test_game_state()

	print("=== ИТОГ: проверок %d, ошибок %d ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  ОШИБКА: %s" % f)
	quit(1 if _failures.size() > 0 else 0)


func _setup_test_game_state() -> void:
	# Изолированный GameState под /root для тестов очков и локаций
	var existing := root.get_node_or_null("GameState")
	if existing != null:
		root.remove_child(existing)
		existing.free()

	_game_state = GameState.new()
	_game_state.name = "GameState"
	_game_state.scene_changer = Callable(self, "_dummy_scene_changer")
	root.add_child(_game_state)


func _cleanup_test_game_state() -> void:
	if _game_state != null and is_instance_valid(_game_state):
		if _game_state.is_inside_tree():
			root.remove_child(_game_state)
		_game_state.free()
		_game_state = null


func _dummy_scene_changer(_path: String) -> void:
	pass


# --------------------------------------------------------------------------
# Раздел 1: Ресурсы данных новых врагов
# --------------------------------------------------------------------------

func _test_enemy_data_resources() -> void:
	print("-- Раздел 1: Ресурсы параметров летающего врага и босса")

	# FlyingEnemy
	var flying_data := load(_FLYING_DATA_PATH) as EnemyData
	_check(flying_data != null, "ресурс data/enemies/flying.tres загружается")
	if flying_data != null:
		_check(flying_data.kind == EnemyData.EnemyKind.FLYING, "тип летающего врага EnemyKind.FLYING")
		_check(flying_data.max_health == 40.0, "здоровье дрона 40.0 HP", "(получено %.1f)" % flying_data.max_health)
		_check(flying_data.contact_damage == 15.0, "урон дрона 15.0", "(получено %.1f)" % flying_data.contact_damage)
		_check(flying_data.move_speed == 3.5, "скорость дрона 3.5 м/с", "(получено %.1f)" % flying_data.move_speed)
		_check(flying_data.is_valid(), "flying_data.is_valid() возвращает true")

	# BossEnemy
	var boss_data := load(_BOSS_DATA_PATH) as EnemyData
	_check(boss_data != null, "ресурс data/enemies/boss.tres загружается")
	if boss_data != null:
		_check(boss_data.kind == EnemyData.EnemyKind.BOSS, "тип босса EnemyKind.BOSS")
		_check(boss_data.max_health == 300.0, "здоровье босса 300.0 HP", "(получено %.1f)" % boss_data.max_health)
		_check(boss_data.contact_damage == 40.0, "контактный урон босса 40.0", "(получено %.1f)" % boss_data.contact_damage)
		_check(boss_data.move_speed == 2.2, "скорость босса 2.2 м/с", "(получено %.1f)" % boss_data.move_speed)
		_check(boss_data.is_valid(), "boss_data.is_valid() возвращает true")


# --------------------------------------------------------------------------
# Раздел 2: Летающий враг
# --------------------------------------------------------------------------

func _test_flying_enemy_contracts() -> void:
	print("-- Раздел 2: Контракты и поведение FlyingEnemy")

	var packed := load(_FLYING_SCENE_PATH) as PackedScene
	_check(packed != null, "сцена flying_enemy.tscn загружается")
	if packed == null:
		return

	var enemy := packed.instantiate() as FlyingEnemy
	_check(enemy != null, "экземпляр сцены имеет тип FlyingEnemy")
	if enemy == null:
		return

	root.add_child(enemy)
	await _physics_frames(2)

	_check(int(enemy.collision_layer) == _LAYER_ENEMY_BODY, "тело дрона на слое 3 (enemy_body)")
	var hurtbox := enemy.get_node_or_null("Hurtbox") as Hurtbox
	_check(hurtbox != null, "у дрона есть узел Hurtbox")
	if hurtbox != null:
		_check(int(hurtbox.collision_layer) == _LAYER_ENEMY_HURTBOX, "хитбокс дрона на слое 4 (enemy_hurtbox)")

	var muzzle := enemy.get_node_or_null("Muzzle") as Node3D
	_check(muzzle != null, "у дрона есть узел Muzzle для стрельбы")

	# Получение урона
	var hp_before := enemy.health()
	enemy.take_damage(20.0)
	_check(enemy.health() == hp_before - 20.0, "take_damage(20) снижает здоровье дрона", "(HP: %.1f)" % enemy.health())
	_check(enemy.is_alive(), "дрон жив при остатке 20 HP")

	# Летальный урон и сигнал died
	_flying_died_count = 0
	enemy.died.connect(_on_flying_died)
	enemy.take_damage(25.0)
	_check(not enemy.is_alive(), "дрон погиб после летального урона")
	_check(_flying_died_count == 1, "сигнал died испущен при гибели дрона")

	await _physics_frames(2)
	if is_instance_valid(enemy) and enemy.is_inside_tree():
		root.remove_child(enemy)
		enemy.free()


# --------------------------------------------------------------------------
# Раздел 3: Босс локации
# --------------------------------------------------------------------------

func _test_boss_enemy_contracts() -> void:
	print("-- Раздел 3: Контракты и поведение BossEnemy")

	var packed := load(_BOSS_SCENE_PATH) as PackedScene
	_check(packed != null, "сцена boss_enemy.tscn загружается")
	if packed == null:
		return

	var boss := packed.instantiate() as BossEnemy
	_check(boss != null, "экземпляр сцены имеет тип BossEnemy")
	if boss == null:
		return

	root.add_child(boss)
	await _physics_frames(2)

	_check(int(boss.collision_layer) == _LAYER_ENEMY_BODY, "тело босса на слое 3 (enemy_body)")
	var hurtbox := boss.get_node_or_null("Hurtbox") as Hurtbox
	_check(hurtbox != null and hurtbox.detects_contact, "хитбокс босса детектирует контакт (detects_contact = true)")

	var nav_agent := boss.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	_check(nav_agent != null, "у босса есть NavigationAgent3D для перемещения к игроку")

	# Фаза ярости при здоровье <= 50%
	_check(not boss._enraged, "босс изначально не в ярости")
	boss.take_damage(160.0)
	_check(boss.health() == 140.0, "здоровье босса снижено до 140 HP", "(получено %.1f)" % boss.health())
	_check(boss._enraged, "босс перешёл в фазу ярости при здоровье <= 50%")

	# Летальный урон
	_boss_died_count = 0
	boss.died.connect(_on_boss_died)
	boss.take_damage(150.0)
	_check(_boss_died_count == 1, "сигнал died испущен при гибели босса")

	await _physics_frames(2)
	if is_instance_valid(boss) and boss.is_inside_tree():
		root.remove_child(boss)
		boss.free()


# --------------------------------------------------------------------------
# Раздел 4: WaveManager
# --------------------------------------------------------------------------

func _test_wave_manager_progression() -> void:
	print("-- Раздел 4: Прогрессия волн и начисление наград WaveManager")

	var wm := WaveManager.new()
	_check(wm.intermission_duration == 5.0, "длительность передышки по умолчанию 5.0 с (R7)", "(получено %.1f)" % wm.intermission_duration)
	wm.auto_start = false
	wm.spawn_interval = 0.01
	root.add_child(wm)
	await _physics_frames(2)

	_check(wm.get_total_waves() == 4, "общее число волн равно 4")
	_check(wm.get_state() == WaveManager.State.IDLE, "начальное состояние IDLE")

	_game_state.points = 0

	# Проверка построения очередей волн 1..4
	wm._build_wave_queue(1)
	_check(wm.remaining_to_spawn_count() == 5, "волна 1: 5 врагов")
	wm._build_wave_queue(2)
	_check(wm.remaining_to_spawn_count() == 8, "волна 2: 8 врагов")
	wm._build_wave_queue(3)
	_check(wm.remaining_to_spawn_count() == 7, "волна 3: 7 врагов (4 контактных + 3 летающих)")
	wm._build_wave_queue(4)
	_check(wm.remaining_to_spawn_count() == 4, "волна 4: 4 врага (1 босс + 3 контактных)")

	# Прохождение волны 1 со спавном и уничтожением
	_wave_completed_count = 0
	_last_completed_wave = -1
	wm.wave_completed.connect(_on_wave_completed)

	wm.start()
	_check(wm.current_wave() == 1, "текущая волна 1 после start()")

	# Ждём спавна всех врагов волны 1
	for i in 60:
		await physics_frame
		if wm.get_state() == WaveManager.State.COMBAT:
			break

	_check(wm.active_enemies_count() == 5, "в волне 1 заспавнено 5 активных врагов", "(получено %d)" % wm.active_enemies_count())

	# Уничтожаем врагов волны 1
	wm.kill_all_active_enemies()
	await _physics_frames(2)

	_check(_wave_completed_count >= 1 and _last_completed_wave == 1, "волна 1 завершена после гибели всех врагов")
	_check(_game_state.points >= 50, "за завершение волны начислено 50 очков", "(очки: %d)" % _game_state.points)
	_check(wm.get_state() == WaveManager.State.INTERMISSION, "состояние перешло в INTERMISSION")

	# Пропуск передышки и переход к финальной волне
	wm.skip_intermission()
	await _physics_frames(5)
	_check(wm.current_wave() == 2, "после передышки стартовала волна 2")

	# Имитация зачистки локации через завершение 4 волны
	wm._current_wave = 4
	wm._state = WaveManager.State.COMBAT
	wm._spawn_queue.clear()
	wm._active_enemies.clear()

	_location_cleared_count = 0
	wm.location_cleared.connect(_on_location_cleared)

	var points_before_clear := _game_state.points
	wm._check_wave_completion()
	await _physics_frames(5)

	_check(_location_cleared_count == 1, "сигнал location_cleared испущен при завершении волны 4")
	_check(_game_state.points == points_before_clear + 500, "за зачистку локации начислено 500 очков", "(очки: %d)" % _game_state.points)
	_check(wm.get_state() == WaveManager.State.CLEARED, "состояние WaveManager перешло в CLEARED")
	_check(not ("arena_02" in _game_state.unlocked_locations), "несуществующая локация arena_02 не разблокируется и не ломает состояние")
	_check("arena_01" in _game_state.unlocked_locations, "стартовая локация arena_01 доступна в GameState")

	wm.queue_free()
	await _physics_frames(2)


# --------------------------------------------------------------------------
# Раздел 5: Проводка арены arena_01.tscn
# --------------------------------------------------------------------------

func _test_arena_scene_wiring() -> void:
	print("-- Раздел 5: Проводка сцены arena_01.tscn")

	var packed := load(_ARENA_SCENE_PATH) as PackedScene
	_check(packed != null, "сцена arena_01.tscn успешно загружается")
	if packed == null:
		return

	var arena := packed.instantiate() as Node3D
	root.add_child(arena)
	await _physics_frames(5)

	_check(arena.is_node_ready(), "сцена arena_01.tscn готова (is_node_ready)")

	var region := arena.get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	_check(region != null, "в сцене есть NavigationRegion3D")
	if region != null:
		var nav_mesh := region.navigation_mesh as NavigationMesh
		_check(nav_mesh != null and nav_mesh.get_polygon_count() > 0, "навмеш арены успешно запечён (polygons > 0)")

	var player := arena.get_node_or_null("Player") as Node3D
	_check(player != null, "в сцене есть узел Player")
	if player != null:
		var hurtbox := player.get_node_or_null("Hurtbox") as Hurtbox
		_check(hurtbox != null and int(hurtbox.collision_layer) == _LAYER_PLAYER_HURTBOX, "хитбокс игрока на слое 7 (player_hurtbox)")

	var wm := arena.get_node_or_null("WaveManager") as WaveManager
	_check(wm != null, "в сцене арены есть WaveManager")
	if wm != null:
		_check(wm.spawn_points.size() >= 4, "у WaveManager настроено не менее 4 точек спавна", "(получено %d)" % wm.spawn_points.size())

	var portal := arena.get_node_or_null("ExitPortal") as DoorPoint
	_check(portal != null, "в сцене арены есть ExitPortal (DoorPoint)")
	if portal != null:
		_check(int(portal.collision_layer) == 0, "до зачистки портал выхода деактивирован (слой 0)")
		if wm != null:
			wm.location_cleared.emit()
		_check(int(portal.collision_layer) == _LAYER_INTERACTABLE, "после зачистки портал выхода активен на слое 6 (interactable)")
		_check(portal.location_id == "lobby", "портал настроен на возврат в лобби (location_id == \"lobby\")")

	# Укрытия
	var cover1 := arena.get_node_or_null("NavigationRegion3D/Cover1") as StaticBody3D
	_check(cover1 != null and int(cover1.collision_layer) == _LAYER_WORLD, "геометрические укрытия Cover на слое 1 (world)")

	arena.queue_free()
	await _physics_frames(2)
