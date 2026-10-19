extends SceneTree

## Проверка целостности базовых сцен VibeFPS.
## Проверяет, что main.tscn и lobby.tscn загружаются и содержат необходимые узлы
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
	var packed: PackedScene = load("res://levels/main/main.tscn")
	if packed == null:
		print("FATAL: не удалось загрузить res://levels/main/main.tscn")
		quit(1)
		return

	# Сцена добавляется в дерево: Camera3D.current и global_position работают
	# только внутри активного вьюпорта, вне дерева они отдают единичную матрицу.
	var world: Node3D = packed.instantiate()
	root.add_child(world)
	await physics_frame

	var player: CharacterBody3D = world.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		print("FATAL: узел Player не найден в main.tscn")
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
	print("-- настройка сцены main.tscn")
	_check(world.get_node_or_null("Floor") != null, "узел Floor существует")
	_check(world.get_node_or_null("WorldEnvironment") != null, "узел WorldEnvironment существует")
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	_check(cam != null and cam.current, "Camera3D существует и активна")
	if cam != null and cam.current and cam.global_position.y < 1.5:
		_warn("камера находится ниже уровня глаз (%.2f м)" % cam.global_position.y)


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
## две точки взаимодействия и три тренировочные мишени.
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

	var door := lobby.get_node_or_null("DoorPoint")
	_check(door != null, "DoorPoint существует")
	if door != null:
		_check(door.is_in_group("interactable"),
			"DoorPoint находится в группе interactable")
		_check(int(door.collision_layer) == 1 << 5,
			"DoorPoint находится на слое 6 (interactable)",
			"(получено %d)" % int(door.collision_layer))

	var target_names := ["TargetNear", "TargetMid", "TargetFar"]
	var targets: Array[Node] = []
	for target_name in target_names:
		var target := lobby.get_node_or_null(target_name)
		_check(target != null, "%s существует" % target_name)
		if target != null:
			targets.append(target)
	_check(targets.size() == 3, "в лобби установлены ровно три мишени",
		"(получено %d)" % targets.size())
	for target in targets:
		var hurtbox := target.get_node_or_null("Hurtbox") as Hurtbox
		_check(hurtbox != null, "%s несёт узел Hurtbox" % target.name)
		if hurtbox != null:
			_check(hurtbox.zone == 0,
				"хитбокс %s относится к зоне 0 (enemy_hurtbox)" % target.name,
				"(получено %d)" % hurtbox.zone)

	lobby.queue_free()