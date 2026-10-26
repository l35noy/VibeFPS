extends SceneTree

## Проверка целостности базовых сцен VibeFPS.
## Проверяет, что arena_01.tscn и lobby.tscn загружаются и содержат необходимые узлы
## и ресурсы, от которых зависит игра.
## Запуск: godot --headless --path . --script res://tests/smoke.gd
##         .\tools\run_checks.ps1 smoke

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


func _initialize() -> void:
	print("=== VibeFPS: базовый смоук-тест сцен ===")
	var packed: PackedScene = load("res://levels/arena_01/arena_01.tscn")
	if packed == null:
		print("FATAL: не удалось загрузить res://levels/arena_01/arena_01.tscn")
		quit(1)
		return

	# Сцена добавляется в дерево: Camera3D.current и global_position работают
	# только внутри активного вьюпорта, вне дерева они отдают единичную матрицу.
	var world: Node3D = packed.instantiate()
	root.add_child(world)
	await physics_frame

	var player: CharacterBody3D = world.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		print("FATAL: узел Player не найден в arena_01.tscn")
		quit(1)
		return

	_test_scene_setup(world, player)
	_test_sky_background(world)
	await _test_lobby()

	print("=== РЕЗУЛЬТАТ: %d проверок, %d провалено, %d предупреждений ===" % [
		_checks, _failures.size(), _warnings.size()])
	for f in _failures:
		print("  ОШИБКА: %s" % f)
	quit(1 if _failures.size() > 0 else 0)


func _test_scene_setup(world: Node3D, player: CharacterBody3D) -> void:
	print("-- настройка сцены arena_01.tscn")
	_check(world.find_child("Floor") != null, "узел Floor существует")
	_check(world.get_node_or_null("WorldEnvironment") != null, "узел WorldEnvironment существует")
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	_check(cam != null and cam.current, "Camera3D существует и активна")
	if cam != null:
		_check(is_equal_approx(cam.position.y, 1.7), "камера находится на оптимальном уровне глаз (1.7 м)",
			"(y=%.3f м)" % cam.position.y)
		var edge_detection := cam.get_node_or_null("EdgeDetection") as MeshInstance3D
		_check(edge_detection != null, "пост-процесс EdgeDetection прикреплён к Camera3D")
	_check(ResourceLoader.exists("res://levels/common/edge_detection.gdshader"),
		"шейдер res://levels/common/edge_detection.gdshader существует")
	_check(ResourceLoader.exists("res://weapons/weapon_body_material.tres"),
		"материал оружия res://weapons/weapon_body_material.tres существует")
	var body_mesh := player.get_node_or_null("BodyMesh") as MeshInstance3D
	_check(body_mesh != null, "узел BodyMesh существует")
	if body_mesh != null:
		_check(not body_mesh.visible, "тело игрока (BodyMesh) невидимо")
		_check(body_mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"тело игрока (BodyMesh) не отбрасывает тень (cast_shadow == OFF)")


func _test_sky_background(world: Node3D) -> void:
	print("-- небо: окружение рендерит небо, а не чёрную пустоту")
	var we := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null or we.environment == null:
		_failures.append("в WorldEnvironment нет ресурса Environment")
		print("  [FAIL] в WorldEnvironment нет ресурса Environment")
		_checks += 1
		return
	var env := we.environment
	_check(env.background_mode == Environment.BG_SKY, "background_mode равен BG_SKY (2)",
		"(получено %d)" % env.background_mode)
	_check(env.sky != null, "в окружении задан ресурс Sky")
	if env.sky != null:
		_check(env.sky.sky_material != null, "у неба задан sky_material")


## Проверка сборки лобби: сцена появления игрока содержит пол, игрока,
## и две точки взаимодействия (ShopPoint и DoorPoint).
func _test_lobby() -> void:
	print("-- лобби: сборка сцены")
	var packed: PackedScene = load("res://levels/lobby/lobby.tscn")
	_check(packed != null, "res://levels/lobby/lobby.tscn загружается")
	if packed == null:
		return

	var lobby: Node3D = packed.instantiate()
	_check(lobby != null, "lobby.tscn инстанцируется в узел")
	if lobby == null:
		return
	root.add_child(lobby)
	# _ready() выставляет слои, группы и зоны хитбоксов: читаем после одного кадра в дереве
	await physics_frame

	_check(lobby is Node3D, "корень лобби является Node3D")
	_check(lobby.get_node_or_null("Player") != null, "Player инстанцирован в лобби")

	var floor := lobby.get_node_or_null("Floor") as StaticBody3D
	_check(floor != null, "StaticBody3D Floor существует")
	if floor != null:
		_check(int(floor.collision_layer) == 1,
			"пол лобби находится на слое 1 (world)",
			"(получено %d)" % int(floor.collision_layer))

	var shop := lobby.get_node_or_null("ShopPoint")
	_check(shop != null, "ShopPoint существует")
	if shop != null:
		_check(shop.is_in_group("interactable"),
			"ShopPoint находится в группе interactable")
		_check(int(shop.collision_layer) == 1 << 5,
			"ShopPoint находится на слое 6 (interactable)",
			"(получено %d)" % int(shop.collision_layer))

	var door := lobby.get_node_or_null("DoorPoint") as DoorPoint
	_check(door != null, "DoorPoint существует")
	if door != null:
		_check(door.is_in_group("interactable"),
			"DoorPoint находится в группе interactable")
		_check(int(door.collision_layer) == 1 << 5,
			"DoorPoint находится на слое 6 (interactable)",
			"(получено %d)" % int(door.collision_layer))
		_check(door.location_id == "arena_01",
			"DoorPoint ведёт на arena_01",
			"(получено \"%s\")" % door.location_id)

	lobby.queue_free()