extends SceneTree

## Scene integrity harness for VibeFPS.
## Verifies that main.tscn loads and carries the nodes and resources the rest
## of the game depends on, without simulating anything.
## Run: godot --headless --path . --script res://tests/smoke.gd
##      .\tools\run_checks.ps1 smoke

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
	print("=== VibeFPS scene smoke test ===")
	var packed: PackedScene = load("res://main.tscn")
	if packed == null:
		print("FATAL: cannot load res://main.tscn")
		quit(1)
		return

	# The scene does go into the tree even though this harness simulates nothing:
	# Camera3D.current and Camera3D.global_position both answer from the live
	# viewport, and off-tree they report errors and an identity transform, which
	# would make the eye-height warning fire on a correctly authored scene.
	var world: Node3D = packed.instantiate()
	root.add_child(world)
	await physics_frame

	var player: CharacterBody3D = world.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		print("FATAL: Player node not found in main.tscn")
		quit(1)
		return

	_test_scene_setup(world, player)
	_test_sky_background(world)
	await _test_lobby()

	print("=== RESULT: %d checks, %d failed, %d warnings ===" % [
		_checks, _failures.size(), _warnings.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)
	quit(1 if _failures.size() > 0 else 0)


func _test_scene_setup(world: Node3D, player: CharacterBody3D) -> void:
	print("-- scene setup")
	_check(world.get_node_or_null("Floor") != null, "Floor node exists")
	_check(world.get_node_or_null("WorldEnvironment") != null, "WorldEnvironment exists")
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	_check(cam != null and cam.current, "Camera3D exists and is current")
	if cam != null and cam.current and cam.global_position.y < 1.5:
		_warn("camera sits below expected eye height (%.2f)" % cam.global_position.y)


func _test_sky_background(world: Node3D) -> void:
	print("-- sky: environment must render the sky, not a black clear color")
	var we := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null or we.environment == null:
		_failures.append("WorldEnvironment has no Environment resource")
		print("  [FAIL] WorldEnvironment has no Environment resource")
		_checks += 1
		return
	var env := we.environment
	_check(env.background_mode == Environment.BG_SKY, "background_mode is BG_SKY (2)",
		"(got %d)" % env.background_mode)
	_check(env.sky != null, "environment has a Sky resource")
	if env.sky != null:
		_check(env.sky.sky_material != null, "sky has a sky_material")


## Lobby assembly check: the home scene the player lands in must carry the floor
## to stand on, the player, the two interaction points and the three test-range
## targets. Loaded and instantiated exactly as the game loads it -- a harness
## that rebuilt the nodes would stay green on a lobby.tscn with nothing in it.
## Run last, and leave main.tscn's section above untouched.
func _test_lobby() -> void:
	print("-- lobby: scene assembly")
	var packed: PackedScene = load("res://lobby.tscn")
	_check(packed != null, "res://lobby.tscn loads")
	if packed == null:
		return

	var lobby: Node3D = packed.instantiate()
	_check(lobby != null, "lobby.tscn instantiates to a node")
	if lobby == null:
		return
	root.add_child(lobby)
	# _ready() sets layers, groups and hurtbox zones; they are only readable once
	# the nodes have gone through a frame in the tree.
	await physics_frame

	_check(lobby is Node3D, "lobby root is a Node3D")
	_check(lobby.get_node_or_null("Player") != null, "Player is instantiated in the lobby")

	var floor := lobby.get_node_or_null("Floor") as StaticBody3D
	_check(floor != null, "Floor StaticBody3D exists")
	if floor != null:
		_check(int(floor.collision_layer) == 1,
			"the lobby floor is on layer 1 (world)",
			"(got %d)" % int(floor.collision_layer))

	var shop := lobby.get_node_or_null("ShopPoint")
	_check(shop != null, "ShopPoint exists")
	if shop != null:
		_check(shop.is_in_group("interactable"),
			"ShopPoint is in the interactable group")
		_check(int(shop.collision_layer) == 1 << 5,
			"ShopPoint is on layer 6 (interactable)",
			"(got %d)" % int(shop.collision_layer))

	var door := lobby.get_node_or_null("DoorPoint")
	_check(door != null, "DoorPoint exists")
	if door != null:
		_check(door.is_in_group("interactable"),
			"DoorPoint is in the interactable group")
		_check(int(door.collision_layer) == 1 << 5,
			"DoorPoint is on layer 6 (interactable)",
			"(got %d)" % int(door.collision_layer))

	var target_names := ["TargetNear", "TargetMid", "TargetFar"]
	var targets: Array[Node] = []
	for target_name in target_names:
		var target := lobby.get_node_or_null(target_name)
		_check(target != null, "%s exists" % target_name)
		if target != null:
			targets.append(target)
	_check(targets.size() == 3, "three targets stand in the lobby",
		"(got %d)" % targets.size())
	for target in targets:
		var hurtbox := target.get_node_or_null("Hurtbox") as Hurtbox
		_check(hurtbox != null, "%s carries a Hurtbox" % target.name)
		if hurtbox != null:
			_check(hurtbox.zone == 0,
				"%s hurtbox is zone 0 (enemy_hurtbox)" % target.name,
				"(got %d)" % hurtbox.zone)

	lobby.queue_free()