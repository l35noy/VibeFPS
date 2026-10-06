extends SceneTree

## World integrity harness for VibeFPS.
## Checks that the world cannot be fallen out of, and that the player returns
## to the spawn point after doing so.
## Run: godot --headless --path . --script res://tests/integrity.gd
##      .\tools\run_checks.ps1 integrity

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


func _initialize() -> void:
	print("=== VibeFPS world integrity test ===")
	var packed: PackedScene = load("res://main.tscn")
	if packed == null:
		print("FATAL: cannot load res://main.tscn")
		quit(1)
		return

	var world: Node3D = packed.instantiate()
	root.add_child(world)
	await physics_frame

	var player: CharacterBody3D = world.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		print("FATAL: Player node not found in main.tscn")
		quit(1)
		return

	await _test_fall_off_edge(player)
	await _test_fall_recovery(player)

	print("=== RESULT: %d checks, %d failed, %d warnings ===" % [
		_checks, _failures.size(), _warnings.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)
	quit(1 if _failures.size() > 0 else 0)


func _test_fall_off_edge(player: CharacterBody3D) -> void:
	print("-- fall off edge: must NOT sink through world")
	player.global_position = Vector3(1000, 50, 1000)
	player.velocity = Vector3.ZERO
	await _physics_frames(240)
	var y := player.global_position.y
	print("    y after 2s of falling = %.2f" % y)
	_check(y > -50.0, "player did not fall out of the world",
		"(y=%.2f)" % y)


func _test_fall_recovery(player: CharacterBody3D) -> void:
	print("-- fall recovery: falling past the kill plane respawns at spawn")
	var spawn := Vector3.ZERO
	player.global_position = Vector3(0, 5, 40)
	player.velocity = Vector3.ZERO
	var respawned := false
	for i in 600:
		await physics_frame
		if player.global_position.distance_to(spawn) < 2.0:
			respawned = true
			break
	print("    y after fall = %.2f, respawned=%s" % [player.global_position.y, respawned])
	_check(respawned, "player respawned near the spawn point after falling out of world")
	await _physics_frames(30)
	_check(player.is_on_floor(), "respawned player is on the floor again")
	_check(player.global_position.y > -1.0, "respawned player is at platform height",
		"(y=%.2f)" % player.global_position.y)
	_check(player.velocity.length() < 0.01, "velocity zeroed on respawn",
		"(v=%.3f, %.3f, %.3f)" % [player.velocity.x, player.velocity.y, player.velocity.z])