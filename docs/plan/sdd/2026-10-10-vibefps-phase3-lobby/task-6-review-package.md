# Task 6 Review Package — lobby.tscn + автозагрузки + main_scene (финальная сборка)
Base: b7ad7c5 (HEAD; project policy: no commits by implementers — working-tree state)
NOTE: diff по project.godot содержит ДО-существующую правку владельца (удаление §1A-ключей) — фокус на [autoload] и run/main_scene. diff по tests/enemies.gd содержит правки Task 5 (контракт смерти/очки) — фокус на _drop_autoloads. tests/progression.gd и tests/interact.gd — untracked (не в git diff), их полный текст ниже; единственная правка Task 6 в них — _drop_autoloads.

=== git hash-object project.godot (ожидается e884017...) ===
e8840171dac3ea7cdd248779d14f1d4e3bfbdeb8

=== git diff --stat (tracked task files) ===
 project.godot    |  13 ++--
 tests/enemies.gd | 217 ++++++++++++++++++++++++++++++++++++++++++++++++++++++-
 tests/smoke.gd   |  72 +++++++++++++++++-
 3 files changed, 293 insertions(+), 9 deletions(-)

=== git diff -U10: project.godot ===
diff --git a/project.godot b/project.godot
index e8c1ab3..e884017 100644
--- a/project.godot
+++ b/project.godot
@@ -4,36 +4,37 @@
 ;
 ; Format:
 ;   [section] ; section goes between []
 ;   param=value ; assign values to parameters
 
 config_version=5
 
 [application]
 
 config/name="VibeFPS"
-run/main_scene="uid://jyplrr3l"
+run/main_scene="uid://l0bby5c7n2v4m"
 config/features=PackedStringArray("4.7", "Forward Plus")
 config/icon="res://icon.svg"
-; ╨С╨╡╨╖ ╨╢╤С╤Б╤В╨║╨╛╨│╨╛ ╨╛╨│╤А╨░╨╜╨╕╤З╨╡╨╜╨╕╤П ╨║╨░╨┤╤А╨╛╨▓ (0 = ╨╗╨╕╨╝╨╕╤В FPS ╤Б╨╜╤П╤В, ╤Б╨╝. CHECKLIST ┬з1A).
-run/max_fps=0
+
+[autoload]
+
+GameState="res://scripts/game_state.gd"
+SaveSystem="res://scripts/save_system.gd"
 
 [display]
 
 window/size/viewport_width=2560
 window/size/viewport_height=1440
 window/size/mode=3
 window/size/resizable=false
 window/stretch/mode="canvas_items"
 window/stretch/aspect="expand"
-; ╨б╨╕╨╜╤Е╤А╨╛╨╜╨╕╨╖╨░╤Ж╨╕╤П ╨║╨░╨┤╤А╨╛╨▓ ╤Б ╨╝╨╛╨╜╨╕╤В╨╛╤А╨╛╨╝ ╨▓╨║╨╗╤О╤З╨╡╨╜╨░ (1 = Enabled), CHECKLIST ┬з1A.
-window/vsync/vsync_mode=1
 
 [input]
 
 move_forward={
 "deadzone": 0.5,
 "events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":119,"location":0,"echo":false,"script":null)
 ]
 }
 move_backward={
 "deadzone": 0.5,
@@ -88,12 +89,10 @@ interact={
 
 [physics]
 
 common/physics_ticks_per_second=120
 3d/physics_engine="Jolt Physics"
 
 [rendering]
 
 rendering_device/driver.windows="d3d12"
 anti_aliasing/quality/msaa_3d=2
-; ╨Ь╨░╤Б╤И╤В╨░╨▒ 3D-╨▒╤Г╤Д╨╡╤А╨░ 1.0 тАФ ╤А╨╡╨╜╨┤╨╡╤А ╨▓ ╨╜╨░╤В╨╕╨▓╨╜╨╛╨╡ ╤А╨░╨╖╤А╨╡╤И╨╡╨╜╨╕╨╡, CHECKLIST ┬з1A.
-scaling_3d/scale=1.0

=== git diff -U10: tests/smoke.gd ===
diff --git a/tests/smoke.gd b/tests/smoke.gd
index 6c94a03..706fbd9 100644
--- a/tests/smoke.gd
+++ b/tests/smoke.gd
@@ -42,20 +42,21 @@ func _initialize() -> void:
 	await physics_frame
 
 	var player: CharacterBody3D = world.get_node_or_null("Player") as CharacterBody3D
 	if player == null:
 		print("FATAL: Player node not found in main.tscn")
 		quit(1)
 		return
 
 	_test_scene_setup(world, player)
 	_test_sky_background(world)
+	await _test_lobby()
 
 	print("=== RESULT: %d checks, %d failed, %d warnings ===" % [
 		_checks, _failures.size(), _warnings.size()])
 	for f in _failures:
 		print("  FAILURE: %s" % f)
 	quit(1 if _failures.size() > 0 else 0)
 
 
 func _test_scene_setup(world: Node3D, player: CharacterBody3D) -> void:
 	print("-- scene setup")
@@ -73,11 +74,80 @@ func _test_sky_background(world: Node3D) -> void:
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
-		_check(env.sky.sky_material != null, "sky has a sky_material")
\ No newline at end of file
+		_check(env.sky.sky_material != null, "sky has a sky_material")
+
+
+## Lobby assembly check: the home scene the player lands in must carry the floor
+## to stand on, the player, the two interaction points and the three test-range
+## targets. Loaded and instantiated exactly as the game loads it -- a harness
+## that rebuilt the nodes would stay green on a lobby.tscn with nothing in it.
+## Run last, and leave main.tscn's section above untouched.
+func _test_lobby() -> void:
+	print("-- lobby: scene assembly")
+	var packed: PackedScene = load("res://lobby.tscn")
+	_check(packed != null, "res://lobby.tscn loads")
+	if packed == null:
+		return
+
+	var lobby: Node3D = packed.instantiate()
+	_check(lobby != null, "lobby.tscn instantiates to a node")
+	if lobby == null:
+		return
+	root.add_child(lobby)
+	# _ready() sets layers, groups and hurtbox zones; they are only readable once
+	# the nodes have gone through a frame in the tree.
+	await physics_frame
+
+	_check(lobby is Node3D, "lobby root is a Node3D")
+	_check(lobby.get_node_or_null("Player") != null, "Player is instantiated in the lobby")
+
+	var floor := lobby.get_node_or_null("Floor") as StaticBody3D
+	_check(floor != null, "Floor StaticBody3D exists")
+	if floor != null:
+		_check(int(floor.collision_layer) == 1,
+			"the lobby floor is on layer 1 (world)",
+			"(got %d)" % int(floor.collision_layer))
+
+	var shop := lobby.get_node_or_null("ShopPoint")
+	_check(shop != null, "ShopPoint exists")
+	if shop != null:
+		_check(shop.is_in_group("interactable"),
+			"ShopPoint is in the interactable group")
+		_check(int(shop.collision_layer) == 1 << 5,
+			"ShopPoint is on layer 6 (interactable)",
+			"(got %d)" % int(shop.collision_layer))
+
+	var door := lobby.get_node_or_null("DoorPoint")
+	_check(door != null, "DoorPoint exists")
+	if door != null:
+		_check(door.is_in_group("interactable"),
+			"DoorPoint is in the interactable group")
+		_check(int(door.collision_layer) == 1 << 5,
+			"DoorPoint is on layer 6 (interactable)",
+			"(got %d)" % int(door.collision_layer))
+
+	var target_names := ["TargetNear", "TargetMid", "TargetFar"]
+	var targets: Array[Node] = []
+	for target_name in target_names:
+		var target := lobby.get_node_or_null(target_name)
+		_check(target != null, "%s exists" % target_name)
+		if target != null:
+			targets.append(target)
+	_check(targets.size() == 3, "three targets stand in the lobby",
+		"(got %d)" % targets.size())
+	for target in targets:
+		var hurtbox := target.get_node_or_null("Hurtbox") as Hurtbox
+		_check(hurtbox != null, "%s carries a Hurtbox" % target.name)
+		if hurtbox != null:
+			_check(hurtbox.zone == 0,
+				"%s hurtbox is zone 0 (enemy_hurtbox)" % target.name,
+				"(got %d)" % hurtbox.zone)
+
+	lobby.queue_free()
\ No newline at end of file

=== git diff -U10: tests/enemies.gd ===
diff --git a/tests/enemies.gd b/tests/enemies.gd
index bc56077..c64d526 100644
--- a/tests/enemies.gd
+++ b/tests/enemies.gd
@@ -144,20 +144,86 @@ const _NAV_EXACT_EPS := 0.0001
 ## path_desired_distance тАФ ┬л╤Б╨╗╨╡╨┤╤Г╤О╤Й╨░╤П ╤В╨╛╤З╨║╨░ ╨┐╤Г╤В╨╕ ╨╖╨░╤Б╤З╨╕╤В╨░╨╜╨░ ╨┐╤А╨╛╨╣╨┤╨╡╨╜╨╜╨╛╨╣┬╗, ╨░
 ## target_desired_distance тАФ ┬л╨┤╨╛ ╤Ж╨╡╨╗╨╕ ╨┤╨╛╤Б╤В╨░╤В╨╛╤З╨╜╨╛ ╨▒╨╗╨╕╨╖╨║╨╛, ╨╝╨╛╨╢╨╜╨╛ ╨╛╤Б╤В╨░╨╜╨░╨▓╨╗╨╕╨▓╨░╤В╤М╤Б╤П┬╗.
 ## ╨Т╤В╨╛╤А╨╛╨╡ ╨╕ ╨╡╤Б╤В╤М ╤А╨░╨┤╨╕╤Г╤Б, ╨╜╨░ ╨║╨╛╤В╨╛╤А╨╛╨╝ ╨▓╤А╨░╨│ ╨▓╤Б╤В╨░╤С╤В ╤Г ╨╕╨│╤А╨╛╨║╨░, ╨╕ ╨║╨╛╨╜╤В╨░╨║╤В╨╜╤Л╨╣ ╤Г╤А╨╛╨╜
 ## ╨╗╨╛╨▓╨╕╤В╤Б╤П ╨┐╨╡╤А╨╡╤Б╨╡╤З╨╡╨╜╨╕╨╡╨╝ ╤Е╨╕╤В╨▒╨╛╨║╤Б╨╛╨▓ ╤А╨░╨┤╨╕╤Г╤Б╨╛╨╝ 0.4 + 0.4 = 0.8 ╨╝, ╤В╨╛ ╨╡╤Б╤В╤М ╨┐╤А╨╕
 ## ╤Б╤В╨╛╨┐-╨┤╨╕╤Б╤В╨░╨╜╤Ж╨╕╨╕ 1.0 ╨╝ ╨▓╤А╨░╨│ ╤Б╤В╨╛╤П╨╗ ╨▒╤Л ╨▓ ╨╝╨╡╤В╤А╨╡ ╨╕ ╨╜╨╡ ╨▒╨╕╨╗ ╨▒╤Л ╨╜╨╕╨║╨╛╨│╨┤╨░. ╨Ю╤В╤Б╤О╨┤╨░ 0.5.
 const _NAV_TARGET_DISTANCE := 0.5
 ## ╨Ф╤А╨╡╨╣╤Д ╤Г ╤Ж╨╡╨╗╨╕: ╨╖╨░ ╨┐╨╛╨╗╤Б╨╡╨║╤Г╨╜╨┤╤Л ╨┐╤А╨╛╤Б╤В╨╛╤П ╨┤╨╕╤Б╤В╨░╨╜╤Ж╨╕╤П ╨╜╨╡ ╨┤╨╛╨╗╨╢╨╜╨░ ╨╕╨╖╨╝╨╡╨╜╨╕╤В╤М╤Б╤П ╨▒╨╛╨╗╤М╤И╨╡ ╤З╨╡╨╝
 ## ╨╜╨░ 2 ╤Б╨╝. ╨Т╤А╨░╨│ ╤Б╤В╨╛╨╕╤В, ╨░ ╨╜╨╡ ╨┐╨╡╤А╨╡╨╝╨╕╨╜╨░╨╡╤В╤Б╤П ╨╜╨░ ╨╝╨╡╤Б╤В╨╡.
 const _NAV_DRIFT_EPS := 0.02
 
+# --------------------------------------------------------------------------
+# Phase 3 Task 5: ╤Б╨╝╨╡╤А╤В╤М тЖТ ╨╗╨╛╨▒╨▒╨╕, ╨╛╤З╨║╨╕ ╨╖╨░ ╤Г╨▒╨╕╨╣╤Б╤В╨▓╨╛ ╨▓╤А╨░╨│╨░
+# --------------------------------------------------------------------------
+
+## ╨Я╤А╨╛╨▒╨╜╤Л╨╣ GameState: ╤В╨╛╤В ╨╢╨╡ ╨║╨╗╨░╤Б╤Б, ╤З╤В╨╛ ╤Г ╨░╨▓╤В╨╛╨╖╨░╨│╤А╤Г╨╖╨║╨╕ (Task 3), ╨╜╨╛ ╤Б
+## ╨╖╨░╨┐╨╕╤Б╤Л╨▓╨░╤О╤Й╨╕╨╝ `return_to_lobby` ╨╕ ╨┐╨╛╨┤╨╝╨╡╨╜╤С╨╜╨╜╤Л╨╝ `scene_changer`. ╨б╨╝╨╡╤А╤В╤М ╨╕╨│╤А╨╛╨║╨░
+## ╨╕╨┤╤С╤В ╤З╨╡╤А╨╡╨╖ ╨╜╨╡╨│╨╛ тАФ ╨╜╨░╤Б╤В╨╛╤П╤Й╨╕╨╣ change_scene_to_file ╤Б╨╜╤С╤Б ╨▒╤Л ╤Н╤В╨╛ ╨╢╨╡ ╨┤╨╡╤А╨╡╨▓╨╛.
+##
+## `return_to_lobby` ╨┐╨╡╤А╨╡╨╛╨┐╤А╨╡╨┤╨╡╨╗╤С╨╜, ╨┐╨╛╤В╨╛╨╝╤Г ╤З╤В╨╛ reason ╨╜╨╡ ╨┤╨╛╤Е╨╛╨┤╨╕╤В ╨┤╨╛
+## `scene_changer` (GameState ╨╖╨╛╨▓╤С╤В ╨╡╨│╨╛ ╤В╨╛╨╗╤М╨║╨╛ ╤Б ╨┐╤Г╤В╤С╨╝ ╤Б╤Ж╨╡╨╜╤Л): ┬л╤Б╨╝╨╡╤А╤В╤М ╨┐╤А╨╛╤Б╨╕╤В
+## ╨╗╨╛╨▒╨▒╨╕┬╗ ╨╕ ┬л╤Б╨╝╨╡╤А╤В╤М ╨┐╤А╨╛╤Б╨╕╤В ╨╗╨╛╨▒╨▒╨╕ ╨Я╨Ю ╨Я╨а╨Ш╨з╨Ш╨Э╨Х ╤Б╨╝╨╡╤А╤В╨╕┬╗ тАФ ╤А╨░╨╖╨╜╤Л╨╡ ╤Г╤В╨▓╨╡╤А╨╢╨┤╨╡╨╜╨╕╤П, ╨╕
+## ╨▓╤В╨╛╤А╨╛╨╡ ╨▓╨╕╨┤╨╜╨╛ ╤В╨╛╨╗╤М╨║╨╛ ╨╕╨╖╨╜╤Г╤В╤А╨╕ ╤Б╨░╨╝╨╛╨│╨╛ ╨▓╤Л╨╖╨╛╨▓╨░.
+class _RecordingGameState extends GameState:
+	var lobby_reasons: PackedStringArray = []
+
+	func return_to_lobby(reason: String) -> void:
+		lobby_reasons.append(reason)
+		super.return_to_lobby(reason)
+
+
+## ╨Я╤А╨╛╨▒╨╜╤Л╨╣ GameState, ╨┐╨╛╨║╨░ ╨╛╨╜ ╤Б╤В╨╛╨╕╤В ╨▓ /root. null ╨╛╨╖╨╜╨░╤З╨░╨╡╤В ┬л╨▓ root ╨╡╨│╨╛ ╨╜╨╡╤В┬╗ тАФ
+## ╤А╨╛╨▓╨╜╨╛ ╤В╨╛ ╤Б╨╛╤Б╤В╨╛╤П╨╜╨╕╨╡, ╨║╨╛╤В╨╛╤А╨╛╨│╨╛ ╤В╤А╨╡╨▒╤Г╤О╤В fallback-╤Б╨╡╨║╤Ж╨╕╤П ╤Б╨╝╨╡╤А╤В╨╕ ╨╕ ╨▓╤Б╨╡ ╨┐╤А╨╛╨▓╨╡╤А╨║╨╕
+## ╨▓╤А╨░╨│╨░, ╨╜╨╡ ╨╢╨┤╤Г╤Й╨╕╨╡ ╨╛╤З╨║╨╛╨▓.
+var _probe_game_state: GameState = null
+## ╨Я╤Г╤В╨╕, ╨╖╨░╨┐╤А╨╛╤И╨╡╨╜╨╜╤Л╨╡ ╤Г ╨┐╨╛╨┤╨╝╨╡╨╜╤С╨╜╨╜╨╛╨│╨╛ scene_changer, ╨▓ ╨┐╨╛╤А╤П╨┤╨║╨╡ ╨▓╤Л╨╖╨╛╨▓╨░.
+var _lobby_changes: PackedStringArray = []
+
+
+## ╨Ч╨░╨┐╨╕╤Б╤Л╨▓╨░╤О╤Й╨░╤П ╨╖╨░╨│╨╗╤Г╤И╨║╨░ ╤Б╨╝╨╡╨╜╤Л ╤Б╤Ж╨╡╨╜╤Л: ╤Д╨╕╨║╤Б╨╕╤А╤Г╨╡╤В ╨╖╨░╨┐╤А╨╛╤Б ╨╕ ╨╜╨╕╤З╨╡╨│╨╛ ╨╜╨╡ ╨╝╨╡╨╜╤П╨╡╤В.
+func _fake_scene_changer(path: String) -> void:
+	_lobby_changes.append(path)
+
+
+## ╨б╤В╨░╨▓╨╕╤В ╨┐╤А╨╛╨▒╨╜╤Л╨╣ GameState ╨▓ /root. ╨Ш╨╝╤П "GameState" тАФ ╤З╨░╤Б╤В╤М ╨║╨╛╨╜╤В╤А╨░╨║╤В╨░: ╨╕
+## player.gd, ╨╕ enemy_contact.gd ╨╜╨░╤Е╨╛╨┤╤П╤В ╨╡╨│╨╛ ╨┐╨╛ ╨┐╤Г╤В╨╕ /root/GameState, ╨░ ╨╜╨╡ ╨┐╨╛
+## ╤Б╤Б╤Л╨╗╨║╨╡, ╨┐╨╛╤Н╤В╨╛╨╝╤Г ╨┐╨╡╤А╨╡╨╕╨╝╨╡╨╜╨╛╨▓╨░╨╜╨╕╨╡ ╤Г╨╖╨╗╨░ ╤Б╨╗╨╛╨╝╨░╨╗╨╛ ╨▒╤Л ╨╛╨▒╨╡ ╨┐╤А╨╛╨▓╨╡╤А╨║╨╕.
+func _install_probe_game_state() -> GameState:
+	var gs := _RecordingGameState.new()
+	gs.name = "GameState"
+	gs.scene_changer = _fake_scene_changer
+	root.add_child(gs)
+	_probe_game_state = gs
+	return gs
+
+
+## ╨г╨▒╨╕╤А╨░╨╡╤В ╨┐╤А╨╛╨▒╨╜╤Л╨╣ GameState ╨╕╨╖ /root. ╨Ю╨▒╤П╨╖╨░╤В╨╡╨╗╤М╨╜╨╛ ╨Ф╨Ю ╤Б╨╡╨║╤Ж╨╕╨╣, ╨║╨╛╤В╨╛╤А╤Л╨╝ ╨╜╤Г╨╢╨╡╨╜
+## fallback: ╨╢╨╕╨▓╨╛╨╣ /root/GameState ╨╝╨╡╨╜╤П╨╡╤В ╨║╨╛╨╜╤В╤А╨░╨║╤В ╤Б╨╝╨╡╤А╤В╨╕.
+func _remove_probe_game_state() -> void:
+	if _probe_game_state != null and is_instance_valid(_probe_game_state):
+		_probe_game_state.queue_free()
+	_probe_game_state = null
+	await physics_frame
+
+
+## PackedStringArray vs Array ╨┐╨╛ ╤Б╨╛╨┤╨╡╤А╨╢╨╕╨╝╨╛╨╝╤Г: Godot ╨╜╨╡ ╤Б╤З╨╕╤В╨░╨╡╤В ╨┤╨▓╨░ ╤А╨░╨╖╨╜╤Л╤Е
+## ╨║╨╛╨╜╤В╨╡╨╣╨╜╨╡╤А╨░ ╤А╨░╨▓╨╜╤Л╨╝╨╕, ╨┐╨╛╤Н╤В╨╛╨╝╤Г `packed == ["death"]` ╨▒╤Л╨╗╨╛ ╨▒╤Л false ╨┤╨░╨╢╨╡ ╨┐╤А╨╕
+## ╤Б╨╛╨▓╨┐╨░╨┤╨╡╨╜╨╕╨╕ ╤Б╨╛╨┤╨╡╤А╨╢╨╕╨╝╨╛╨│╨╛.
+func _packed_strings_eq(packed: PackedStringArray, expected: Array) -> bool:
+	if packed.size() != expected.size():
+		return false
+	for i in packed.size():
+		if packed[i] != expected[i]:
+			return false
+	return true
+
+
 # --------------------------------------------------------------------------
 # Task 5: ╨┐╤А╨╛╨▓╨╛╨┤╨║╨░ ╤В╨╕╤А╨░
 # --------------------------------------------------------------------------
 
 ## ╨Я╨░╤Г╨╖╨░ ╨┐╨╛╤Б╨╗╨╡ bake ╨┐╨╡╤А╨╡╨┤ ╨┐╨╡╤А╨▓╤Л╨╝ ╨╖╨░╨╝╨╡╤А╨╛╨╝. ╨Ъ╨░╤А╤В╨░ ╨╜╨░╨▓╨╕╨│╨░╤Ж╨╕╨╕ ╨╛╨▒╨╜╨╛╨▓╨╗╤П╨╡╤В╤Б╤П ╨▓ ╨╜╨░╤З╨░╨╗╨╡
 ## ╤Д╨╕╨╖╨╕╤З╨╡╤Б╨║╨╛╨│╨╛ ╤И╨░╨│╨░, ╨░ bake ╤В╨╕╤А╨░ ╨╖╨░╨║╨░╨╜╤З╨╕╨▓╨░╨╡╤В╤Б╤П ╨▓ _ready() ╨║╨╛╤А╨╜╤П ╤Б╤Ж╨╡╨╜╤Л; ╨▒╨╡╨╖
 ## ╤Н╤В╨╕╤Е ╤В╨╕╨║╨╛╨▓ ╨┐╨╡╤А╨▓╤Л╨╣ ╨╖╨░╨┐╤А╨╛╤Б ╨┐╤Г╤В╨╕ ╤Г╤И╤С╨╗ ╨▒╤Л ╨▓ ╨╡╤Й╤С ╨┐╤Г╤Б╤В╤Г╤О ╨║╨░╤А╤В╤Г.
 const _RANGE_SETTLE_TICKS := 10
 ## ╨б╨║╨╛╨╗╤М╨║╨╛ ╨┤╨▓╨╕╨╢╤Г╤Й╨╕╤Е╤Б╤П ╨║╨░╨┤╤А╨╛╨▓ ╨╜╤Г╨╢╨╜╨╛, ╤З╤В╨╛╨▒╤Л ╤Г╤В╨▓╨╡╤А╨╢╨┤╨╡╨╜╨╕╨╡ ┬л╨▓╤А╨░╨│ ╤И╤С╨╗┬╗ ╨╜╨╡ ╨▒╤Л╨╗╨╛ ╨┐╤Г╤Б╤В╤Л╨╝
 ## ╨╜╨░╨▒╨╛╤А╨╛╨╝ ┬л╨┐╤А╨╛╨▓╨╡╤А╤П╤В╤М ╨╜╨╡╤З╨╡╨│╨╛┬╗. ╨Я╨╛╨╗╤Б╨╡╨║╤Г╨╜╨┤╤Л ╨┤╨▓╨╕╨╢╨╡╨╜╨╕╤П тАФ ╤В╨╛╤В ╨╢╨╡ ╨╝╨╕╨╜╨╕╨╝╤Г╨╝, ╤З╤В╨╛ ╤Г
@@ -300,20 +366,26 @@ func _spawn_and_wait(node: Node) -> bool:
 
 
 ## ╨Т╤В╨╛╤А╨╛╨╣ ╤А╨░╨╖╨┤╨╡╨╗: ╨╖╨┤╨╛╤А╨╛╨▓╤М╨╡ ╨╕╨│╤А╨╛╨║╨░ ╨╕ ╨╖╨╛╨╜╨░ ╨╡╨│╨╛ ╤Е╨╕╤В╨▒╨╛╨║╤Б╨░.
 ##
 ## ╨Т╤Б╤С ╤Б╨╛╤Б╤В╨╛╤П╨╜╨╕╨╡ ╤З╨╕╤В╨░╨╡╤В╤Б╤П ╤Б ╨╜╨░╤Б╤В╨╛╤П╤Й╨╡╨│╨╛ ╨╕╨╜╤Б╤В╨░╨╜╤Б╨░ player.tscn. ╨б╨╗╨╛╨╣ ╤Е╨╕╤В╨▒╨╛╨║╤Б╨░
 ## ╨┐╤А╨╛╨▓╨╡╤А╤П╨╡╤В╤Б╤П ╨╕ ╨╜╨░ ╨┤╨╡╤Д╨╛╨╗╤В╨╜╨╛╨╝ Hurtbox.new() тАФ ╤Н╤В╨╛ ╨║╨╛╨╜╤В╤А╨░╨║╤В ╨д╨░╨╖╤Л 1 ╨┤╨╗╤П ╨╝╨╕╤И╨╡╨╜╨╡╨╣ ╨╕
 ## ╨▓╤А╨░╨│╨╛╨▓, ╨║╨╛╤В╨╛╤А╤Л╨╣ ╨╜╨╛╨▓╨░╤П ╨╜╨░╤Б╤В╤А╨╛╨╣╨║╨░ ╨╖╨╛╨╜╤Л ╨╛╨▒╤П╨╖╨░╨╜╨░ ╤Б╨╛╤Е╤А╨░╨╜╨╕╤В╤М, ╨░ ╨╜╨╡ ╨╖╨░╨╝╨╡╨╜╨╕╤В╤М.
 func _test_player_health() -> void:
 	print("-- ╨Ч╨┤╨╛╤А╨╛╨▓╤М╨╡ ╨╕╨│╤А╨╛╨║╨░ (Task 2)")
 
+	# Fallback-╨║╨╛╨╜╤В╤А╨░╨║╤В ╤Б╨╝╨╡╤А╤В╨╕: ╨▒╨╡╨╖ /root/GameState ╤Б╨╝╨╡╤А╤В╤М ╨╛╨▒╤П╨╖╨░╨╜╨░ ╨▓╨╡╤А╨╜╤Г╤В╤М ╨╕╨│╤А╨╛╨║╨░
+	# ╨╜╨░ ╤В╨╛╤З╨║╤Г ╨┐╨╛╤П╨▓╨╗╨╡╨╜╨╕╤П ╤Б ╨┐╨╛╨╗╨╜╤Л╨╝ ╨╖╨┤╨╛╤А╨╛╨▓╤М╨╡╨╝ (╤Б╨╝. Phase 3 Task 5). ╨Я╤А╨╛╨▓╨╡╤А╨║╨░ ╨╕╨╝╨╡╨╡╤В
+	# ╤Б╨╝╤Л╤Б╨╗ ╤В╨╛╨╗╤М╨║╨╛ ╨┐╨╛╨║╨░ GameState ╨▓ root ╨╜╨╡╤В.
+	_check(root.get_node_or_null("GameState") == null,
+		"precondition: ╨▓ /root ╨╜╨╡╤В GameState тАФ ╤Б╨╝╨╡╤А╤В╤М ╨╜╨╕╨╢╨╡ ╨╕╨┤╤С╤В ╨┐╨╛ fallback-╨▓╨╡╤В╨║╨╡ (╤А╨╡╤Б╨┐╨░╨▓╨╜ ╨╜╨░ ╨╝╨╡╤Б╤В╨╡)")
+
 	_died_count = 0
 	_health_at_death = -1.0
 	_alive_at_death = true
 	_health_events.clear()
 
 	var packed: PackedScene = load(_PLAYER_PATH)
 	if packed == null:
 		_bail("cannot load %s" % _PLAYER_PATH)
 		return
 	var player := packed.instantiate()
@@ -397,21 +469,21 @@ func _test_player_health() -> void:
 	# ╤Б╨╝╨╡╤А╤В╤М┬╗ ╤Б╤З╨╕╤В╨░╤О╤В ╨╛╤В 100 HP, ╨░ ╨┐╤А╨╛╨▓╨╡╤А╨║╨░ ╨┐╤А╨╛╨▓╨╛╨┤╨║╨╕ ╤Г╨╢╨╡ ╤Б╤К╨╡╨┤╨░╨╡╤В 10 HP. ╨Ю╨▒╨╡
 	# ╨┐╨╛╤Б╨╗╨╡╨┤╨╛╨▓╨░╤В╨╡╨╗╤М╨╜╨╛╤Б╤В╨╕ ╨╜╨░ ╨╛╨┤╨╜╨╛╨╝ ╨╕╨│╤А╨╛╨║╨╡ ╨╜╨╡ ╤Б╤Е╨╛╨┤╤П╤В╤Б╤П, ╨┐╨╛╤Н╤В╨╛╨╝╤Г ╤Б╨╜╨░╤З╨░╨╗╨░ ╨╕╨┤╤С╤В
 	# ╨┐╨╛╨╗╨╜╤Л╨╣ ╤Ж╨╕╨║╨╗ ╤Г╤А╨╛╨╜╨░ ╨┤╨╛ ╤Б╨╝╨╡╤А╤В╨╕, ╨░ ╨┐╤А╨╛╨▓╨╛╨┤╨║╨░ ╨┐╤А╨╛╨▓╨╡╤А╤П╨╡╤В╤Б╤П ╨╜╨░ ╤В╨╛╨╗╤М╨║╨╛ ╤З╤В╨╛
 	# ╨▓╨╛╤Б╤Б╤В╨░╨╜╨╛╨▓╨╗╨╡╨╜╨╜╨╛╨╝ ╨╕╨│╤А╨╛╨║╨╡ тАФ ╨╡╤С ╤Г╤В╨▓╨╡╤А╨╢╨┤╨╡╨╜╨╕╨╡ (100 - 10 = 90) ╨╛╤В ╤А╨╡╤Б╨┐╨░╨▓╨╜╨░ ╨╜╨╡
 	# ╨╖╨░╨▓╨╕╤Б╨╕╤В.
 	player.call("take_damage", 90.0)
 	_check(_alive(player), "╨┤╨╡╨▓╤П╤В╨╛╨╡ ╨┐╨╛╨┐╨░╨┤╨░╨╜╨╕╨╡ ╨╜╨╡ ╤Г╨▒╨╕╨▓╨░╨╡╤В ╨╕╨│╤А╨╛╨║╨░")
 	_check(_near(_health(player), 10.0), "╨┐╨╛╤Б╨╗╨╡ ╨┤╨╡╨▓╤П╤В╨╕ ╤В╨╕╨║╨╛╨▓ ╨╛╤Б╤В╨░╤С╤В╤Б╤П 10 ╨╖╨┤╨╛╤А╨╛╨▓╤М╤П",
 		"(got %.4f)" % _health(player))
 
-	print("-- ╨┤╨╡╤Б╤П╤В╨╛╨╡ ╨┐╨╛╨┐╨░╨┤╨░╨╜╨╕╨╡: ╤Б╨╝╨╡╤А╤В╤М ╨╕ ╨╜╨╡╨╝╨╡╨┤╨╗╨╡╨╜╨╜╤Л╨╣ ╤А╨╡╤Б╨┐╨░╨▓╨╜")
+	print("-- ╨┤╨╡╤Б╤П╤В╨╛╨╡ ╨┐╨╛╨┐╨░╨┤╨░╨╜╨╕╨╡: ╤Б╨╝╨╡╤А╤В╤М ╨╕ ╨╜╨╡╨╝╨╡╨┤╨╗╨╡╨╜╨╜╤Л╨╣ ╤А╨╡╤Б╨┐╨░╨▓╨╜ (fallback ╨▒╨╡╨╖ GameState)")
 	player.call("take_damage", 10.0)
 	_check(_died_count == 1, "╤Б╨╕╨│╨╜╨░╨╗ died ╤А╨╛╨▓╨╜╨╛ ╨╛╨┤╨╕╨╜", "(got %d)" % _died_count)
 	_check(not _alive_at_death, "╨▓ ╨╝╨╛╨╝╨╡╨╜╤В ╤Б╨╕╨│╨╜╨░╨╗╨░ died ╨╕╨│╤А╨╛╨║ ╤Г╨╢╨╡ ╨╝╤С╤А╤В╨▓ (is_alive() == false)",
 		"(got %s)" % _alive_at_death)
 	_check(_near(_health_at_death, 0.0), "╨▓ ╨╝╨╛╨╝╨╡╨╜╤В ╤Б╨╕╨│╨╜╨░╨╗╨░ died ╨╖╨┤╨╛╤А╨╛╨▓╤М╨╡ ╤А╨░╨▓╨╜╨╛ 0.0",
 		"(got %.4f)" % _health_at_death)
 	_check(_near(_health(player), 100.0), "╨┐╨╛╤Б╨╗╨╡ ╤Б╨╝╨╡╤А╤В╨╕ 100.0 (╤А╨╡╤Б╨┐╨░╨▓╨╜ ╨▓╨╛╤Б╤Б╤В╨░╨╜╨╛╨▓╨╕╨╗ ╨╖╨┤╨╛╤А╨╛╨▓╤М╨╡)",
 		"(got %.4f)" % _health(player))
 	_check(_alive(player), "╨┐╨╛╤Б╨╗╨╡ ╤Б╨╝╨╡╤А╤В╨╕ ╨╕╨│╤А╨╛╨║ ╤Б╨╜╨╛╨▓╨░ ╨╢╨╕╨▓")
 
@@ -463,20 +535,143 @@ func _health_api_ready(player: Node) -> bool:
 ## ╨Ш╤Й╨╡╤В ╨┐╨╡╤А╨▓╨╛╨╡ ╤Б╨╛╨▒╤Л╤В╨╕╨╡ health_changed ╤Б ╤В╨░╨║╨╕╨╝ ╨╖╨╜╨░╤З╨╡╨╜╨╕╨╡╨╝ ╨╖╨┤╨╛╤А╨╛╨▓╤М╤П. ╨Ю╤В╤Б╤Г╤В╤Б╤В╨▓╨╕╨╡
 ## ╤Б╨╛╨▒╤Л╤В╨╕╤П ╨▓╨╛╨╖╨▓╤А╨░╤Й╨░╨╡╤В (-1.0, -1.0): ╨┐╨░╤А╨░, ╨║╨╛╤В╨╛╤А╤Г╤О ╨╜╨╡ ╤Б ╤З╨╡╨╝ ╤Б╤А╨░╨▓╨╜╨╕╤В╤М, ╨╕
 ## _check() ╨╜╨░ ╨╜╨╡╨╣ ╤З╨╡╤Б╤В╨╜╨╛ ╨┐╨░╨┤╨░╨╡╤В.
 func _find_health_event(value: float) -> Vector2:
 	for event in _health_events:
 		if _near(event.x, value):
 			return event
 	return Vector2(-1.0, -1.0)
 
 
+## ╨б╨╝╨╡╤А╤В╤М ╨┐╤А╨╕ ╨╢╨╕╨▓╨╛╨╝ GameState: ╨▓╨╛╨╖╨▓╤А╨░╤В ╨▓ ╨╗╨╛╨▒╨▒╨╕ ╨┐╤А╨╕╤З╨╕╨╜╨╛╨╣ "death", ╨░ ╨╜╨╡ ╤А╨╡╤Б╨┐╨░╨▓╨╜ ╨╜╨░
+## ╨╝╨╡╤Б╤В╨╡. ╨Ю╤В╤Б╤Г╤В╤Б╤В╨▓╨╕╨╡ ╤А╨╡╤Б╨┐╨░╨▓╨╜╨░ ╨╜╨░╨▒╨╗╤О╨┤╨░╨╡╤В╤Б╤П ╨┐╨╛ ╤Б╨╛╤Б╤В╨╛╤П╨╜╨╕╤О ╨╕╨│╤А╨╛╨║╨░: ╨╡╤Б╨╗╨╕ ╨▒╤Л
+## `_respawn(true)` ╨╛╤В╤А╨░╨▒╨╛╤В╨░╨╗, ╨╖╨┤╨╛╤А╨╛╨▓╤М╨╡ ╨▓╨╡╤А╨╜╤Г╨╗╨╛╤Б╤М ╨▒╤Л ╨║ max_health, ╨░ ╨╕╨│╤А╨╛╨║ ╤Б╨╜╨╛╨▓╨░
+## ╤Б╤В╨░╨╗ ╨▒╤Л ╨╢╨╕╨▓╤Л╨╝ тАФ ╨╛╨▒╨░ ╨┐╤А╨╕╨╖╨╜╨░╨║╨░ ╨╛╨▒╤П╨╖╨░╨╜╤Л ╨╛╤Б╤В╨░╤В╤М╤Б╤П ╨┐╤А╨╡╨╢╨╜╨╕╨╝╨╕.
+func _test_death_returns_to_lobby() -> void:
+	print("-- ╤Б╨╝╨╡╤А╤В╤М тЖТ ╨╗╨╛╨▒╨▒╨╕ ╨┐╤А╨╕ ╨╢╨╕╨▓╨╛╨╝ GameState (Phase 3 Task 5)")
+
+	_check(root.get_node_or_null("GameState") == null,
+		"precondition: ╨┤╨╛ ╤Г╤Б╤В╨░╨╜╨╛╨▓╨║╨╕ GameState ╨▓ /root ╨╡╨│╨╛ ╨╜╨╡╤В тАФ ╤Б╨╝╨╡╤А╤В╤М ╨╜╨╕╨╢╨╡ ╨┐╨╛╨╣╨┤╤С╤В ╨┐╨╛ ╨╜╨╛╨▓╨╛╨╝╤Г ╨║╨╛╨╜╤В╤А╨░╨║╤В╤Г")
+
+	var world := _new_world()
+	_add_floor(world)
+	var packed: PackedScene = load(_PLAYER_PATH)
+	if packed == null:
+		_bail("cannot load %s for the death contract test" % _PLAYER_PATH)
+		return
+	var player := packed.instantiate()
+	if not await _spawn_in(world, player, Vector3(0.0, 0.0, 0.0)):
+		_bail("%s never became node-ready for the death contract test" % _PLAYER_PATH)
+		return
+
+	_lobby_changes.clear()
+	var gs := _install_probe_game_state()
+	var spy := gs as _RecordingGameState
+	await physics_frame
+	_check(root.get_node_or_null("GameState") == gs,
+		"precondition: ╨┐╤А╨╛╨▒╨╜╤Л╨╣ GameState ╤А╨╡╨╖╨╛╨╗╨▓╨╕╤В╤Б╤П ╨║╨░╨║ /root/GameState")
+
+	_died_count = 0
+	_health_at_death = -1.0
+	_alive_at_death = true
+	player.died.connect(_on_player_died.bind(player))
+	var max_health := float(player.get("max_health"))
+	player.call("take_damage", max_health)
+
+	_check(_died_count == 1, "╤Б╨╝╨╡╤А╤В╤М ╨╕╤Б╨┐╤Г╤Б╨║╨░╨╡╤В died ╤А╨╛╨▓╨╜╨╛ ╨╛╨┤╨╕╨╜ ╤А╨░╨╖", "(got %d)" % _died_count)
+	_check(_near(_health_at_death, 0.0), "╨▓ ╨╝╨╛╨╝╨╡╨╜╤В ╤Б╨╕╨│╨╜╨░╨╗╨░ died ╨╖╨┤╨╛╤А╨╛╨▓╤М╨╡ ╨╕╨│╤А╨╛╨║╨░ ╤А╨░╨▓╨╜╨╛ 0.0",
+		"(got %.4f)" % _health_at_death)
+	_check(not _alive_at_death, "╨▓ ╨╝╨╛╨╝╨╡╨╜╤В ╤Б╨╕╨│╨╜╨░╨╗╨░ died ╨╕╨│╤А╨╛╨║ ╤Г╨╢╨╡ ╨╝╤С╤А╤В╨▓")
+	_check(spy != null and _packed_strings_eq(spy.lobby_reasons, ["death"]),
+		"╤Б╨╝╨╡╤А╤В╤М ╨▓╨╛╨╖╨▓╤А╨░╤Й╨░╨╡╤В ╨▓ ╨╗╨╛╨▒╨▒╨╕ ╤Б ╨┐╤А╨╕╤З╨╕╨╜╨╛╨╣ \"death\"",
+		"(╨┐╨╛╨╗╤Г╤З╨╡╨╜╨╛ %s)" % ("╨╜╨╡╤В ╨┐╤А╨╛╨▒╨╜╨╛╨│╨╛ GameState" if spy == null else str(spy.lobby_reasons)))
+	_check(_packed_strings_eq(_lobby_changes, ["res://lobby.tscn"]),
+		"╤Б╨╝╨╡╤А╤В╤М ╨┐╤А╨╛╤Б╨╕╤В ╤Г scene_changer ╤А╨╛╨▓╨╜╨╛ res://lobby.tscn",
+		"(╨┐╨╛╨╗╤Г╤З╨╡╨╜╨╛ %s)" % str(_lobby_changes))
+	_check(_near(_health(player), 0.0),
+		"╤Б╨╝╨╡╤А╤В╤М ╨Э╨Х ╤А╨╡╤Б╨┐╨░╨▓╨╜╨╕╤В ╨╜╨░ ╨╝╨╡╤Б╤В╨╡: ╨╖╨┤╨╛╤А╨╛╨▓╤М╨╡ ╨╛╤Б╤В╨░╤С╤В╤Б╤П 0.0, ╨░ ╨╜╨╡ max_health",
+		"(got %.4f, max_health %.4f)" % [_health(player), max_health])
+	_check(not _alive(player), "╤Б╨╝╨╡╤А╤В╤М ╨Э╨Х ╤А╨╡╤Б╨┐╨░╨▓╨╜╨╕╤В ╨╜╨░ ╨╝╨╡╤Б╤В╨╡: ╨╕╨│╤А╨╛╨║ ╨╛╤Б╤В╨░╤С╤В╤Б╤П ╨╝╤С╤А╤В╨▓╤Л╨╝")
+
+	player.queue_free()
+	await physics_frame
+	await _remove_probe_game_state()
+	_check(root.get_node_or_null("GameState") == null,
+		"╨┐╨╛╤Б╨╗╨╡ ╤Б╨╡╨║╤Ж╨╕╨╕ ╨┐╤А╨╛╨▒╨╜╤Л╨╣ GameState ╤Г╨▒╤А╨░╨╜ ╨╕╨╖ /root тАФ fallback ╤Б╨╜╨╛╨▓╨░ ╨┤╨╛╤Б╤В╤Г╨┐╨╡╨╜")
+	world.queue_free()
+	await physics_frame
+
+
+## ╨г╨▒╨╕╨╣╤Б╤В╨▓╨╛ ╨▓╤А╨░╨│╨░ ╨╜╨░╤З╨╕╤Б╨╗╤П╨╡╤В ╤А╨╛╨▓╨╜╨╛ POINTS_PER_KILL ╨╛╤З╨║╨╛╨▓ ╤З╨╡╤А╨╡╨╖ GameState ╨╕
+## ╤А╨╛╨▓╨╜╨╛ ╨╛╨┤╨╕╨╜ ╤А╨░╨╖.
+func _test_kill_awards_points() -> void:
+	print("-- ╨╛╤З╨║╨╕ ╨╖╨░ ╤Г╨▒╨╕╨╣╤Б╤В╨▓╨╛ ╨▓╤А╨░╨│╨░ (Phase 3 Task 5)")
+
+	_check(root.get_node_or_null("GameState") == null,
+		"precondition: ╨┤╨╛ ╤Г╤Б╤В╨░╨╜╨╛╨▓╨║╨╕ GameState ╨▓ /root ╨╡╨│╨╛ ╨╜╨╡╤В")
+
+	var world := _new_world()
+	_add_floor(world)
+	var enemy_packed: PackedScene = load(_ENEMY_PATH)
+	if enemy_packed == null:
+		_bail("cannot load %s for the kill-points test" % _ENEMY_PATH)
+		return
+	var player_packed: PackedScene = load(_PLAYER_PATH)
+	if player_packed == null:
+		_bail("cannot load %s for the kill-points test" % _PLAYER_PATH)
+		return
+	# ╨Ш╨│╤А╨╛╨║ ╨▓ ╨╝╨╕╤А╨╡ тАФ ╨╜╨╡ ╤Г╨║╤А╨░╤И╨╡╨╜╨╕╨╡: ╨▓╤А╨░╨│ ╨╕╤Й╨╡╤В ╤Ж╨╡╨╗╤М ╨┐╨╛ ╨│╤А╤Г╨┐╨┐╨╡ "player", ╨╕ ╨▒╨╡╨╖ ╨╜╨╡╤С
+	# ╤Б╨╡╨║╤Ж╨╕╤П ╨┐╤А╨╛╨▓╨╡╤А╤П╨╗╨░ ╨▒╤Л ╨╛╨┤╨╕╨╜╨╛╤З╨╜╤Л╨╣ ╤Г╨╖╨╡╨╗, ╨░ ╨╜╨╡ ╤Г╨▒╨╕╨╣╤Б╤В╨▓╨╛ ╨▓ ╨▒╨╛╤О.
+	var player := player_packed.instantiate()
+	if not await _spawn_in(world, player, Vector3(0.0, 0.0, 0.0)):
+		_bail("%s never became node-ready for the kill-points test" % _PLAYER_PATH)
+		return
+	var enemy := enemy_packed.instantiate()
+	if not await _spawn_in(world, enemy, Vector3(6.0, 0.0, 0.0)):
+		_bail("%s never became node-ready for the kill-points test" % _ENEMY_PATH)
+		return
+
+	_lobby_changes.clear()
+	var gs := _install_probe_game_state()
+	await physics_frame
+	_check(root.get_node_or_null("GameState") == gs,
+		"precondition: ╨┐╤А╨╛╨▒╨╜╤Л╨╣ GameState ╤А╨╡╨╖╨╛╨╗╨▓╨╕╤В╤Б╤П ╨║╨░╨║ /root/GameState")
+	_check(gs.points == 0, "precondition: ╤Б╤З╤С╤В ╨╜╨░╤З╨╕╨╜╨░╨╡╤В╤Б╤П ╤Б ╨╜╤Г╨╗╤П", "(got %d)" % gs.points)
+
+	var data := enemy.get("data") as EnemyData
+	if data == null:
+		_bail("the enemy in the kill-points test carries no EnemyData")
+		return
+	_enemy_died_count = 0
+	_enemy_health_at_death = -1.0
+	_enemy_alive_at_death = true
+	enemy.died.connect(_on_enemy_died.bind(enemy))
+
+	enemy.call("take_damage", float(data.max_health))
+
+	_check(_enemy_died_count == 1, "╨▓╤А╨░╨│ ╤Г╨╝╨╕╤А╨░╨╡╤В ╤А╨╛╨▓╨╜╨╛ ╨╛╨┤╨╕╨╜ ╤А╨░╨╖, died ╤А╨╛╨▓╨╜╨╛ ╨╛╨┤╨╕╨╜",
+		"(got %d)" % _enemy_died_count)
+	_check(gs.points == gs.POINTS_PER_KILL,
+		"╤Г╨▒╨╕╨╣╤Б╤В╨▓╨╛ ╨▓╤А╨░╨│╨░ ╨╜╨░╤З╨╕╤Б╨╗╤П╨╡╤В ╤А╨╛╨▓╨╜╨╛ POINTS_PER_KILL ╨╛╤З╨║╨╛╨▓",
+		"(points %d, POINTS_PER_KILL %d)" % [gs.points, gs.POINTS_PER_KILL])
+	_check(gs.points == 10, "╨╛╤З╨║╨╛╨▓ ╤А╨╛╨▓╨╜╨╛ 10", "(got %d)" % gs.points)
+	# ╨Я╨╛╨▓╤В╨╛╤А╨╜╤Л╨╣ ╤Г╤А╨╛╨╜ ╨┐╨╛ ╨╝╤С╤А╤В╨▓╨╛╨╝╤Г ╨▓╤А╨░╨│╤Г ╨╜╨╡ ╨╜╨░╤З╨╕╤Б╨╗╤П╨╡╤В ╨╛╤З╨║╨╕ ╨▓╤В╨╛╤А╨╛╨╣ ╤А╨░╨╖: ╤Б╨╝╨╡╤А╤В╤М
+	# ╨╜╨░╨▒╨╗╤О╨┤╨░╨╡╤В╤Б╤П ╤А╨╛╨▓╨╜╨╛ ╨╛╨┤╨╕╨╜ ╤А╨░╨╖ (╤Б╨╝. _die() ╨▓ enemy_contact.gd).
+	enemy.call("take_damage", float(data.max_health))
+	_check(gs.points == 10, "╤Г╤А╨╛╨╜ ╨┐╨╛ ╨╝╤С╤А╤В╨▓╨╛╨╝╤Г ╨▓╤А╨░╨│╤Г ╨╜╨╡ ╨╜╨░╤З╨╕╤Б╨╗╤П╨╡╤В ╨╛╤З╨║╨╕ ╨┐╨╛╨▓╤В╨╛╤А╨╜╨╛",
+		"(got %d)" % gs.points)
+
+	await _remove_probe_game_state()
+	world.queue_free()
+	await physics_frame
+
+
 # --------------------------------------------------------------------------
 # Task 3: ╨║╨╛╨╜╤В╨░╨║╤В╨╜╤Л╨╣ ╨▓╤А╨░╨│
 # --------------------------------------------------------------------------
 
 ## ╨в╤А╨╡╤В╨╕╨╣ ╤А╨░╨╖╨┤╨╡╨╗: ╨▓╤А╨░╨│ ╤Ж╨╡╨╗╨╕╨║╨╛╨╝ ╨╕╨╖ ╤Б╨▓╨╛╨╡╨╣ ╤Б╤Ж╨╡╨╜╤Л.
 ##
 ## ╨з╤В╨╛ ╨│╤А╤Г╨╖╨╕╤В╤Б╤П ╨╕╨╖ ╤Б╤Ж╨╡╨╜╤Л, ╨░ ╤З╤В╨╛ ╤Б╨╛╨▒╨╕╤А╨░╨╡╤В╤Б╤П ╨║╨╛╨┤╨╛╨╝, ╤А╨░╨╖╨╝╨╡╤З╨╡╨╜╨╛ ╨╖╨┤╨╡╤Б╤М ╨╜╨░╨╝╨╡╤А╨╡╨╜╨╜╨╛.
 ## ╨б╤Ж╨╡╨╜╨░ `enemy_contact.tscn` тАФ ╤Н╤В╨╛ ╨┐╤А╨╡╨┤╨╝╨╡╤В ╨┐╤А╨╛╨▓╨╡╤А╨║╨╕: ╨╕╨╝╨╡╨╜╨╜╨╛ ╨▓ ╨╜╨╡╨╣ ╤Е╤А╨░╨╜╤П╤В╤Б╤П
 ## ╤Б╤Б╤Л╨╗╨║╨░ ╨╜╨░ ╨┤╨░╨╜╨╜╤Л╨╡, ╤Б╨╗╨╛╨╕ ╤Е╨╕╤В╨▒╨╛╨║╤Б╨░ ╨╕ ╨║╨░╨┐╤Б╤Г╨╗╨░, ╨╕ ╤Е╨░╤А╨╜╨╡╤Б╤Б, ╤Б╨╛╨▒╤А╨░╨▓╤И╨╕╨╣ ╨▒╤Л ╤В╨╛╨│╨╛ ╨╢╨╡
 ## ╨▓╤А╨░╨│╨░ ╨╕╨╖ ╤Г╨╖╨╗╨╛╨▓ ╨║╨╛╨┤╨░, ╨╛╤Б╤В╨░╨╗╤Б╤П ╨▒╤Л ╨╖╨╡╨╗╤С╨╜╤Л╨╝ ╨╜╨░ ╤Б╤Ж╨╡╨╜╨╡ ╨▒╨╡╨╖ ╤Е╨╕╤В╨▒╨╛╨║╤Б╨░ ╨▓╨╛╨╛╨▒╤Й╨╡.
@@ -1739,22 +1934,40 @@ func _hurtbox_reach(shape: Shape3D) -> float:
 	if shape is CylinderShape3D:
 		return (shape as CylinderShape3D).radius
 	if shape is SphereShape3D:
 		return (shape as SphereShape3D).radius
 	if shape is BoxShape3D:
 		var size := (shape as BoxShape3D).size
 		return 0.5 * minf(size.x, minf(size.y, size.z))
 	return -1.0
 
 
+## The engine registers GameState/SaveSystem as project autoloads
+## (project.godot, Task 6) and installs nodes of those names under /root even in
+## --script mode. The whole harness relies on /root/GameState being ABSENT
+## (fallback death contract) or on a probe it installs itself; the autoload would
+## shadow the probe (Godot renames the later node when the name is taken) and
+## hand player.gd the real change_scene_to_file, which would swap in lobby.tscn
+## and add a second group-"player" node. Drop them first, so /root/GameState
+## means what the harness says it means. Immediate free, not queue_free: the
+## name must be free before the probe is added.
+func _drop_autoloads() -> void:
+	for autoload_name in ["GameState", "SaveSystem"]:
+		var node := root.get_node_or_null(autoload_name)
+		if node != null:
+			root.remove_child(node)
+			node.free()
+
+
 func _initialize() -> void:
 	print("=== enemies ===")
+	_drop_autoloads()
 
 	print("-- %s must load as an EnemyData" % _CONTACT_PATH)
 	var res: Resource = load(_CONTACT_PATH)
 	if res == null:
 		_bail("cannot load %s" % _CONTACT_PATH)
 		return
 	var script_res := res.get_script() as Script
 	_check(res is EnemyData, "contact.tres is an EnemyData",
 		"(script=%s)" % ("none" if script_res == null else script_res.resource_path))
 	var data := res as EnemyData
@@ -1782,21 +1995,23 @@ func _initialize() -> void:
 	_check(_is_valid_rejects({"max_health": 0.0}),
 		"a zero max health is rejected")
 	_check(_is_valid_rejects({"contact_damage": 0.0}),
 		"a zero contact damage is rejected")
 	_check(_is_valid_rejects({"move_speed": 0.0}),
 		"a zero move speed is rejected")
 	_check(_is_valid_rejects({"spawn_interval": 0.0}),
 		"a zero spawn interval is rejected")
 
 	await _test_player_health()
+	await _test_death_returns_to_lobby()
 	await _test_contact_enemy()
+	await _test_kill_awards_points()
 	await _test_enemy_navigation()
 	await _test_range_scene_wiring()
 
 	if _bailed:
 		# _bail() ╤Г╨╢╨╡ ╨╜╨░╨┐╨╡╤З╨░╤В╨░╨╗ ╤Б╨▓╨╛╨┤╨║╤Г ╨╕ ╨╖╨░╨┐╤А╨╛╤Б╨╕╨╗ quit(1). ╨Т╤В╨╛╤А╨╛╨╣ quit() ╨╖╨┤╨╡╤Б╤М
 		# ╨┐╨╡╤А╨╡╨╖╨░╨┐╨╕╤Б╨░╨╗ ╨▒╤Л ╨║╨╛╨┤ ╨▓╨╛╨╖╨▓╤А╨░╤В╨░ ╨╜╤Г╨╗╤С╨╝, ╨╕ FATAL ╨┐╤А╨╛╤З╨╕╤В╨░╨╗╨╕ ╨▒╤Л ╨║╨░╨║ PASS.
 		quit(1)
 		return
 	_finish()
 	quit(1 if _failures.size() > 0 else 0)

=== NEW FILE (full): lobby.tscn ===
[gd_scene load_steps=28 format=3 uid="uid://l0bby5c7n2v4m"]

[ext_resource type="PackedScene" path="res://player.tscn" id="1_player"]
[ext_resource type="Script" path="res://scripts/range_target.gd" id="2_target_script"]
[ext_resource type="Script" path="res://scripts/hurtbox.gd" id="3_hurtbox_script"]
[ext_resource type="Script" path="res://scripts/shop_point.gd" id="4_shop_script"]
[ext_resource type="Script" path="res://scripts/door_point.gd" id="5_door_script"]

[sub_resource type="ProceduralSkyMaterial" id="ProceduralSkyMaterial_lobby"]
sky_top_color = Color(0.083611436, 0.55883366, 0.7163719, 1)
sky_horizon_color = Color(0.620054, 0.7175465, 0.7465719, 1)
ground_bottom_color = Color(0.24614578, 0.16089359, 0.11945697, 1)
ground_horizon_color = Color(0.620054, 0.7175465, 0.7465719, 1)

[sub_resource type="Sky" id="Sky_lobby"]
sky_material = SubResource("ProceduralSkyMaterial_lobby")

[sub_resource type="Environment" id="Environment_lobby"]
background_mode = 2
background_energy_multiplier = 0.5
sky = SubResource("Sky_lobby")

[sub_resource type="BoxMesh" id="BoxMesh_floor"]
size = Vector3(12, 1, 20)

[sub_resource type="BoxShape3D" id="BoxShape3D_floor"]
size = Vector3(12, 1, 20)

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_floor"]
albedo_color = Color(0.8217887, 0.82178867, 0.82178867, 1)
metallic_specular = 0.0

[sub_resource type="BoxMesh" id="BoxMesh_wall_back"]
size = Vector3(12, 4, 1)

[sub_resource type="BoxShape3D" id="BoxShape3D_wall_back"]
size = Vector3(12, 4, 1)

[sub_resource type="BoxMesh" id="BoxMesh_wall_side"]
size = Vector3(1, 4, 20)

[sub_resource type="BoxShape3D" id="BoxShape3D_wall_side"]
size = Vector3(1, 4, 20)

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_wall"]
albedo_color = Color(0.588, 0.643, 0.686, 1)
metallic_specular = 0.0

[sub_resource type="BoxMesh" id="BoxMesh_target"]
size = Vector3(1, 2, 0.6)

[sub_resource type="BoxShape3D" id="BoxShape3D_target"]
size = Vector3(1, 2, 0.6)

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_target_near"]
albedo_color = Color(0.878, 0.376, 0.216, 1)
metallic_specular = 0.0

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_target_mid"]
albedo_color = Color(0.298, 0.643, 0.325, 1)
metallic_specular = 0.0

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_target_far"]
albedo_color = Color(0.239, 0.451, 0.831, 1)
metallic_specular = 0.0

[sub_resource type="BoxMesh" id="BoxMesh_shop"]
size = Vector3(1, 1.5, 1)

[sub_resource type="BoxShape3D" id="BoxShape3D_shop"]
size = Vector3(1.6, 2, 1.6)

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_shop"]
albedo_color = Color(0.949, 0.686, 0.192, 1)
metallic_specular = 0.0
emission_enabled = true
emission = Color(0.949, 0.686, 0.192, 1)
emission_energy_multiplier = 0.4

[sub_resource type="BoxMesh" id="BoxMesh_door"]
size = Vector3(1.6, 2.8, 0.2)

[sub_resource type="BoxShape3D" id="BoxShape3D_door"]
size = Vector3(1.8, 3, 0.8)

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_door"]
albedo_color = Color(0.478, 0.294, 0.157, 1)
metallic_specular = 0.0

; Р›РѕР±Р±Рё вЂ” РіР»Р°РІРЅР°СЏ СЃС†РµРЅР° (project.godot [application] run/main_scene). РљРѕРјРЅР°С‚Р°
; Р±РµР· РЅР°РІРјРµС€Р° Рё Р±РµР· РІСЂР°РіР°: РЅР°РІРјРµС€ РЅСѓР¶РµРЅ С‚РѕР»СЊРєРѕ Р±РѕСЋ, Рё РµРіРѕ РѕС‚СЃСѓС‚СЃС‚РІРёРµ Р·РґРµСЃСЊ
; РѕР·РЅР°С‡Р°РµС‚, С‡С‚Рѕ lobby.gd С‚РѕР¶Рµ РЅРµ РЅСѓР¶РµРЅ. Р’СЃС‘ Р¶РёРІРѕРµ РІ РєРѕРјРЅР°С‚Рµ вЂ” РґРІРµСЂРё Рё РІРёС‚СЂРёРЅР°
; РёР· scripts/, РѕРЅРё СЃР°РјРё СЃС‚Р°РІСЏС‚ СЃРµР±Рµ СЃР»РѕР№ 6 Рё РіСЂСѓРїРїСѓ "interactable" РІ _ready().
;
; РўСЂРё РјРёС€РµРЅРё вЂ” С‚РµСЃС‚-СЃС‚РµРЅРґ, РїРѕРІС‚РѕСЂСЏСЋС‰РёР№ С‚РёСЂ: РїРѕРїР°РґР°РЅРёРµ РґРѕР»Р¶РЅРѕ Р±С‹С‚СЊ РІРёРґРЅРѕ РІ С‚РѕС‚
; Р¶Рµ РјРёРі, С‡С‚Рѕ Рё РІ range.tscn, РЅРµ РѕС‚РїСЂР°РІР»СЏСЏ РёРіСЂРѕРєР° РІ Р±РѕР№. Р”РёСЃС‚Р°РЅС†РёРё РѕС‚ СЃРїР°РІРЅР°
; (0, 0, 0): 5 / 8 / 12 Рј (СЃРј. РЅРёР¶Рµ Сѓ РєР°Р¶РґРѕР№ РјРёС€РµРЅРё).
[node name="Lobby" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_lobby")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.707107, -0.408248, 0.57735, 0, 0.707107, 0.707107, -0.707107, -0.5, 0.5, 0, 10, 0)
shadow_enabled = true

; РџРѕР» 12 x 20, РІРµСЂС…РЅСЏСЏ РіСЂР°РЅСЊ РЅР° y = 0 (С†РµРЅС‚СЂ РЅР° y = -0.5). РРіСЂРѕРє СЃС‚РѕРёС‚ РЅР° РЅСѓР»Рµ,
; РїРѕСЌС‚РѕРјСѓ РІРµСЂС€РёРЅР° РµРіРѕ РєР°РїСЃСѓР»С‹ 1.8 Рј РѕРєР°Р·С‹РІР°РµС‚СЃСЏ СЂРѕРІРЅРѕ РЅР° РїРѕРІРµСЂС…РЅРѕСЃС‚Рё.
[node name="Floor" type="StaticBody3D" parent="."]
position = Vector3(0, -0.5, -8)
collision_layer = 1

[node name="Mesh" type="MeshInstance3D" parent="Floor"]
mesh = SubResource("BoxMesh_floor")
surface_material_override/0 = SubResource("StandardMaterial3D_floor")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Floor"]
shape = SubResource("BoxShape3D_floor")

; Р”Р°Р»СЊРЅСЏСЏ СЃС‚РµРЅР°, РєСѓРґР° РІРµРґС‘С‚ РґРІРµСЂСЊ. Р’РЅСѓС‚СЂРµРЅРЅСЏСЏ РіСЂР°РЅСЊ РЅР° z = -17.5.
[node name="BackWall" type="StaticBody3D" parent="."]
position = Vector3(0, 2, -18)

[node name="Mesh" type="MeshInstance3D" parent="BackWall"]
mesh = SubResource("BoxMesh_wall_back")
surface_material_override/0 = SubResource("StandardMaterial3D_wall")

[node name="CollisionShape3D" type="CollisionShape3D" parent="BackWall"]
shape = SubResource("BoxShape3D_wall_back")

[node name="LeftWall" type="StaticBody3D" parent="."]
position = Vector3(-6, 2, -8)

[node name="Mesh" type="MeshInstance3D" parent="LeftWall"]
mesh = SubResource("BoxMesh_wall_side")
surface_material_override/0 = SubResource("StandardMaterial3D_wall")

[node name="CollisionShape3D" type="CollisionShape3D" parent="LeftWall"]
shape = SubResource("BoxShape3D_wall_side")

[node name="RightWall" type="StaticBody3D" parent="."]
position = Vector3(6, 2, -8)

[node name="Mesh" type="MeshInstance3D" parent="RightWall"]
mesh = SubResource("BoxMesh_wall_side")
surface_material_override/0 = SubResource("StandardMaterial3D_wall")

[node name="CollisionShape3D" type="CollisionShape3D" parent="RightWall"]
shape = SubResource("BoxShape3D_wall_side")

; Р’РёС‚СЂРёРЅР°: 5 Рј РѕС‚ СЃРїР°РІРЅР° Сѓ РїСЂР°РІРѕР№ СЃС‚РµРЅС‹. РРіСЂРѕРє РїРѕРґС…РѕРґРёС‚, E РїРѕРєСѓРїР°РµС‚ Р°РІС‚РѕРјР°С‚
; С‡РµСЂРµР· GameState (СЃРј. scripts/shop_point.gd). РњРµС€ Рё С‚СЂРёРіРіРµСЂ вЂ” С‡С‚РѕР±С‹ С‚РѕС‡РєР° Р±С‹Р»Р°
; РІРёРґРЅР° Рё РµС‘ overlap С‡С‚Рѕ-С‚Рѕ Р·РЅР°С‡РёР»; СЃР»РѕР№ Рё РіСЂСѓРїРїР° РїСЂРёС…РѕРґСЏС‚ РёР· СЃРєСЂРёРїС‚Р° РІ _ready.
[node name="ShopPoint" type="Area3D" parent="."]
position = Vector3(5, 0, 0)
script = ExtResource("4_shop_script")
weapon_id = "auto"

[node name="Mesh" type="MeshInstance3D" parent="ShopPoint"]
position = Vector3(0, 0.75, 0)
mesh = SubResource("BoxMesh_shop")
surface_material_override/0 = SubResource("StandardMaterial3D_shop")

[node name="CollisionShape3D" type="CollisionShape3D" parent="ShopPoint"]
position = Vector3(0, 1, 0)
shape = SubResource("BoxShape3D_shop")

; Р”РІРµСЂСЊ В«РџРµСЂРІР°СЏ Р»РѕРєР°С†РёСЏВ» РЅР° РґР°Р»СЊРЅРµР№ СЃС‚РµРЅРµ: РІСЂРµРјРµРЅРЅРѕ РІРµРґС‘С‚ РІ range.tscn С‡РµСЂРµР·
; GameState.enter_location("range") (СЃРј. scripts/door_point.gd).
[node name="DoorPoint" type="Area3D" parent="."]
position = Vector3(0, 0, -17.5)
script = ExtResource("5_door_script")
location_id = "range"

[node name="Mesh" type="MeshInstance3D" parent="DoorPoint"]
position = Vector3(0, 1.4, 0.15)
mesh = SubResource("BoxMesh_door")
surface_material_override/0 = SubResource("StandardMaterial3D_door")

[node name="CollisionShape3D" type="CollisionShape3D" parent="DoorPoint"]
position = Vector3(0, 1.5, 0.4)
shape = SubResource("BoxShape3D_door")

; РўРµСЃС‚-СЃС‚РµРЅРґ: С‚СЂРё РјРёС€РµРЅРё РЅР° 5 / 8 / 12 Рј РѕС‚ СЃРїР°РІРЅР° (0, 0, 0). РќР°СЃС‚СЂРѕР№РєР° РѕРґРёРЅ РІ
; РѕРґРёРЅ РєР°Рє РІ range.tscn: С‚РµР»Рѕ СЃР»РѕСЏ 4, С…РёС‚Р±РѕРєСЃ zone 0 (Р·РЅР°С‡РёС‚ СЃР»РѕР№ 4 РІ _ready),
; СЂРµР°РєС†РёСЏ РЅР° РїРѕРїР°РґР°РЅРёРµ вЂ” РІСЃРїС‹С€РєР° С†РІРµС‚Р° (scripts/range_target.gd). РЎРјРµС‰РµРЅРёСЏ РїРѕ x
; СЂР°Р·РЅРѕСЃСЏС‚ РјРёС€РµРЅРё, С‡С‚РѕР±С‹ РґР°Р»СЊРЅСЏСЏ РЅРµ СЃС‚РѕСЏР»Р° Р·Р° Р±Р»РёР¶РЅРµР№.
[node name="TargetNear" type="StaticBody3D" parent="."]
position = Vector3(0, 0, -5)
collision_layer = 4
collision_mask = 1
script = ExtResource("2_target_script")

[node name="Mesh" type="MeshInstance3D" parent="TargetNear"]
position = Vector3(0, 1, 0)
mesh = SubResource("BoxMesh_target")
surface_material_override/0 = SubResource("StandardMaterial3D_target_near")

[node name="CollisionShape3D" type="CollisionShape3D" parent="TargetNear"]
position = Vector3(0, 1, 0)
shape = SubResource("BoxShape3D_target")

[node name="Hurtbox" type="Area3D" parent="TargetNear"]
position = Vector3(0, 1, 0)
script = ExtResource("3_hurtbox_script")

[node name="CollisionShape3D" type="CollisionShape3D" parent="TargetNear/Hurtbox"]
shape = SubResource("BoxShape3D_target")

[node name="TargetMid" type="StaticBody3D" parent="."]
position = Vector3(-3, 0, -7.416)
collision_layer = 4
collision_mask = 1
script = ExtResource("2_target_script")

[node name="Mesh" type="MeshInstance3D" parent="TargetMid"]
position = Vector3(0, 1, 0)
mesh = SubResource("BoxMesh_target")
surface_material_override/0 = SubResource("StandardMaterial3D_target_mid")

[node name="CollisionShape3D" type="CollisionShape3D" parent="TargetMid"]
position = Vector3(0, 1, 0)
shape = SubResource("BoxShape3D_target")

[node name="Hurtbox" type="Area3D" parent="TargetMid"]
position = Vector3(0, 1, 0)
script = ExtResource("3_hurtbox_script")

[node name="CollisionShape3D" type="CollisionShape3D" parent="TargetMid/Hurtbox"]
shape = SubResource("BoxShape3D_target")

[node name="TargetFar" type="StaticBody3D" parent="."]
position = Vector3(4, 0, -11.314)
collision_layer = 4
collision_mask = 1
script = ExtResource("2_target_script")

[node name="Mesh" type="MeshInstance3D" parent="TargetFar"]
position = Vector3(0, 1, 0)
mesh = SubResource("BoxMesh_target")
surface_material_override/0 = SubResource("StandardMaterial3D_target_far")

[node name="CollisionShape3D" type="CollisionShape3D" parent="TargetFar"]
position = Vector3(0, 1, 0)
shape = SubResource("BoxShape3D_target")

[node name="Hurtbox" type="Area3D" parent="TargetFar"]
position = Vector3(0, 1, 0)
script = ExtResource("3_hurtbox_script")

[node name="CollisionShape3D" type="CollisionShape3D" parent="TargetFar/Hurtbox"]
shape = SubResource("BoxShape3D_target")

[node name="Player" parent="." instance=ExtResource("1_player")]


=== UNTRACKED FILE (full, T6 change = _drop_autoloads): tests/progression.gd ===
extends SceneTree

## Progression harness for VibeFPS (Phase 3, lobby track A): points, buying and
## equipping weapons, unlocked locations, scene transitions and the autosave
## round-trip through SaveSystem.
##
## The SaveSystem autoload does not exist yet (a later task wires it into
## project.godot), so the harness builds one by hand at user://progression_test.json
## -- the same isolation tests/save.gd uses, so the production user://save.json is
## never touched. Scene transitions go through an injected fake changer: headless
## has no window to swap scenes in, and the production scenes must not be loaded
## out from under the harness.
##
## The main instance (`_gs`) walks the whole progression. A second, clean-slate
## instance (`_roundtrip`) is used for the disk round-trip check: the brief fixes
## the expected value after award_points(50) at 50 points, which only holds from
## a fresh state. The main instance has already spent down to 10 points by then,
## so reusing it would make the same operation 60 and tie the round-trip check to
## the purchase arithmetic. Isolating it keeps both numbers exactly what the
## brief states.
##
## Run: godot --headless --path . --script res://tests/progression.gd
##      .\tools\run_checks.ps1 progression

## Isolated path every interaction uses. user://save.json is never touched.
const _TMP_PATH := "user://progression_test.json"

var _failures: PackedStringArray = []
var _checks := 0

var _save: SaveSystem
var _gs: GameState
## Clean-slate instance for the autosave round-trip (see the file header).
var _roundtrip: GameState
## Paths handed to the fake scene changer, in call order. No scene is actually
## swapped -- the fake only records what it was asked for.
var _changed_to: PackedStringArray = []


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


## Fake scene changer: records the requested path and does nothing else. A real
## change_scene_to_file would tear down this very SceneTree under the harness.
func _fake_changer(path: String) -> void:
	_changed_to.append(path)


## PackedStringArray vs Array comparison by contents. Godot does not treat the
## two container types as equal, so a plain `owned == ["pistol"]` would be false
## even when the contents match.
func _packed_eq(packed: PackedStringArray, expected: Array) -> bool:
	if packed.size() != expected.size():
		return false
	for i in packed.size():
		if packed[i] != expected[i]:
			return false
	return true


func _cleanup() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_TMP_PATH))


## The engine registers GameState/SaveSystem as project autoloads
## (project.godot, Task 6) and installs nodes of those names under /root even in
## --script mode. Left in place they would shadow the harness's own nodes of the
## same name (Godot renames the later one, so /root/SaveSystem would resolve to
## the autoload writing user://save.json) and hand GameState the real
## change_scene_to_file. Drop them first, so the harness owns /root/GameState and
## /root/SaveSystem exactly as it did before the autoloads existed. Immediate
## free, not queue_free: the names must be free before the nodes below are added.
func _drop_autoloads() -> void:
	for autoload_name in ["GameState", "SaveSystem"]:
		var node := root.get_node_or_null(autoload_name)
		if node != null:
			root.remove_child(node)
			node.free()


func _initialize() -> void:
	print("=== VibeFPS progression test ===")
	_drop_autoloads()
	# Clean sheet: a leftover save from an interrupted run must not be restored
	# into the state under test.
	_cleanup()

	_save = SaveSystem.new()
	# The name is what makes /root/SaveSystem resolve for GameState's autosave.
	_save.name = "SaveSystem"
	_save.save_path = _TMP_PATH
	root.add_child(_save)

	_gs = GameState.new()
	# Injected before add_child, so GameState._ready() must not overwrite it.
	_gs.scene_changer = _fake_changer
	root.add_child(_gs)
	await physics_frame

	_test_initial_state()
	_test_award_points()
	_test_afford()
	_test_buy_weapon()
	_test_buy_owned_again()
	_test_buy_missing()
	_test_equip()
	_test_enter_location()
	_test_return_to_lobby()
	await _test_autosave_roundtrip()

	_save.clear_save()
	_cleanup()

	print("=== RESULT: %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)
	quit(1 if _failures.size() > 0 else 0)


func _test_initial_state() -> void:
	print("-- start: a fresh game starts with the pistol and the range")
	_check(_gs.points == 0, "points start at 0", "(got %d)" % _gs.points)
	_check(_packed_eq(_gs.owned_weapons, ["pistol"]),
		"only the pistol is owned", "(got %s)" % _gs.owned_weapons)
	_check(_gs.equipped_weapon_id == "pistol", "the pistol is equipped",
		"(got \"%s\")" % _gs.equipped_weapon_id)
	_check(_packed_eq(_gs.unlocked_locations, ["range"]),
		"only the range is unlocked", "(got %s)" % _gs.unlocked_locations)


func _test_award_points() -> void:
	print("-- award_points: adds, ignores negatives")
	_gs.award_points(10)
	_check(_gs.points == 10, "award_points(10) adds 10", "(got %d)" % _gs.points)
	_gs.award_points(-5)
	_check(_gs.points == 10, "award_points(-5) is ignored, not deducted",
		"(got %d)" % _gs.points)


func _test_afford() -> void:
	print("-- can_afford: the auto costs 300")
	_check(_gs.weapon_price("auto") == 300,
		"weapon_price(\"auto\") reads 300 from auto.tres",
		"(got %d)" % _gs.weapon_price("auto"))
	_check(not _gs.can_afford(300), "300 points cannot afford the 300 auto")
	_gs.award_points(300)
	_check(_gs.can_afford(300), "after award_points(300) the auto is affordable")


func _test_buy_weapon() -> void:
	print("-- buy_weapon: deducts the price, owns and equips")
	var bought := _gs.buy_weapon("auto")
	_check(bought, "buy_weapon(\"auto\") succeeds when affordable")
	_check(_gs.points == 10, "the 300 price was deducted (310 -> 10)",
		"(got %d)" % _gs.points)
	_check("auto" in _gs.owned_weapons, "\"auto\" is now owned",
		"(got %s)" % _gs.owned_weapons)
	_check(_gs.equipped_weapon_id == "auto", "and it is equipped",
		"(got \"%s\")" % _gs.equipped_weapon_id)


func _test_buy_owned_again() -> void:
	print("-- buy_weapon on an owned weapon: equips only, no second charge")
	var again := _gs.buy_weapon("auto")
	_check(again, "buying an already-owned weapon returns true")
	_check(_gs.points == 10, "and does not charge twice",
		"(got %d)" % _gs.points)
	_check(_gs.owned_weapons.size() == 2,
		"the weapon is not owned twice", "(got %s)" % _gs.owned_weapons)


## A weapon with no .tres reports price 0, but that must not make it buyable as
## a free item: "no resource" is a refusal, fixed here before the implementation
## is read.
func _test_buy_missing() -> void:
	print("-- buy_weapon(\"nope\"): a missing resource is not for sale")
	_check(_gs.weapon_price("nope") == 0,
		"weapon_price(\"nope\") falls back to 0",
		"(got %d)" % _gs.weapon_price("nope"))
	var bought := _gs.buy_weapon("nope")
	_check(not bought, "buy_weapon refuses a weapon with no .tres")
	_check(not ("nope" in _gs.owned_weapons), "and does not add it to the bag",
		"(got %s)" % _gs.owned_weapons)


func _test_equip() -> void:
	print("-- equip_weapon: only owned weapons")
	_check(_gs.equip_weapon("pistol"), "equipping the owned pistol returns true")
	_check(_gs.equipped_weapon_id == "pistol", "the pistol is equipped again",
		"(got \"%s\")" % _gs.equipped_weapon_id)
	_check(_gs.equip_weapon("auto"), "equipping the owned auto returns true")
	_check(_gs.equipped_weapon_id == "auto", "the auto is equipped",
		"(got \"%s\")" % _gs.equipped_weapon_id)
	_check(not _gs.equip_weapon("nope"), "equipping an unowned weapon is refused")
	_check(_gs.equipped_weapon_id == "auto",
		"and does not change the equipped weapon",
		"(got \"%s\")" % _gs.equipped_weapon_id)


func _test_enter_location() -> void:
	print("-- enter_location: unlocked ids only, through the injected changer")
	var entered := _gs.enter_location("range")
	_check(entered, "entering the unlocked range succeeds")
	_check(_packed_eq(_changed_to, ["res://range.tscn"]),
		"the changer was asked for res://range.tscn", "(got %s)" % _changed_to)
	var before := _changed_to.size()
	_check(not _gs.enter_location("secret"), "a locked location is refused")
	_check(_changed_to.size() == before,
		"and no scene change was requested", "(got %s)" % _changed_to)


func _test_return_to_lobby() -> void:
	print("-- return_to_lobby: back to the lobby through the changer")
	_gs.return_to_lobby("death")
	_check(_packed_eq(_changed_to, ["res://range.tscn", "res://lobby.tscn"]),
		"the changer was then asked for res://lobby.tscn",
		"(got %s)" % _changed_to)


func _test_autosave_roundtrip() -> void:
	print("-- autosave: mutations land on disk, and a fresh state reads back")
	# The buy and equip above must already be on disk (autosave after every
	# mutator): points 10, auto equipped.
	var disk := _save.load_state()
	_check(int(disk.get("points", -1)) == 10,
		"autosave after buy/equip persisted points == 10",
		"(got %s)" % disk.get("points"))
	_check(disk.get("equipped_weapon_id") == "auto",
		"autosave persisted the equipped weapon",
		"(got %s)" % disk.get("equipped_weapon_id"))

	# Clean-slate round-trip: award_points(50) on a fresh state, then read the
	# value back from disk. The brief fixes this number at 50.
	_save.clear_save()
	_roundtrip = GameState.new()
	root.add_child(_roundtrip)
	await physics_frame
	_roundtrip.award_points(50)
	await physics_frame
	var loaded := _save.load_state()
	_check(int(loaded.get("points", -1)) == 50,
		"award_points(50) is on disk as points == 50",
		"(got %s)" % loaded.get("points"))
	_check(loaded.get("equipped_weapon_id") == "pistol",
		"and the persisted equipped weapon is correct",
		"(got %s)" % loaded.get("equipped_weapon_id"))


=== UNTRACKED FILE (full, T6 change = _drop_autoloads): tests/interact.gd ===
extends SceneTree

## Interaction harness for VibeFPS (Phase 3, lobby track A): the ShopPoint and
## DoorPoint interactables, the player's nearest_interactable() reach pick, and
## the E (interact) route through the input gate.
##
## The SaveSystem autoload does not exist yet (a later task wires it into
## project.godot), so the harness builds one by hand at
## user://interact_test.json -- the same isolation tests/progression.gd uses, so
## the production user://save.json is never touched. Scene transitions go
## through an injected fake changer: headless has no window to swap scenes in,
## and the production scenes must not be loaded out from under the harness.
##
## The player is the shipped player.tscn instantiated on the root, with a probe
## script answering the gate with an explicit mouse mode -- headless cannot
## capture the cursor (Input.mouse_mode stays VISIBLE), exactly as
## tests/movement.gd does. Interact lives in player.gd's _unhandled_input, so it
## is driven with a parsed key event plus Input.flush_buffered_events():
## Input.action_press alone never reaches _unhandled_input (tests/movement.gd
## pins the same rule for jump), and an InputEventAction pressed while the
## action is already pressed is deduplicated before it reaches the tree -- which
## would make the second press in the gate check arrive nowhere. The key event
## is the honest shape of the input anyway: input_actions.gd pins interact to
## the physical E key.
##
## Run: godot --headless --path . --script res://tests/interact.gd
##      .\tools\run_checks.ps1 interact


## Stand-in for player.gd, used only by this harness.
class _PlayerProbe extends "res://player.gd":
	## Mouse mode the gate is evaluated against instead of Input.mouse_mode.
	var gate_mouse_mode: int = Input.MOUSE_MODE_CAPTURED

	func _mouse_mode_for_play_input() -> int:
		return gate_mouse_mode


## Records what ShopPoint announces. The signal is the observable the gate check
## needs: a second "purchase" of an already-owned weapon only equips, so it
## changes no points and leaves the equipped id where it was -- without the
## signal a gated press and an ungated one would look identical.
class _ShopLog extends RefCounted:
	var ok_values: Array[bool] = []

	func _on_interacted(ok: bool) -> void:
		ok_values.append(ok)


## Isolated path every interaction uses. user://save.json is never touched.
const _TMP_PATH := "user://interact_test.json"
const _PLAYER_SCENE := "res://player.tscn"
const _SHOP_SCRIPT := "res://scripts/shop_point.gd"
const _DOOR_SCRIPT := "res://scripts/door_point.gd"

## The reach the design fixes, restated here so a silent retune to 2.5 -- the
## value the brief explicitly overrules (R2: the shop at 3.0 m must be found,
## the door at 6.0 m must not) -- cannot turn this harness into a check of a
## different number.
const _EXPECTED_RANGE := 3.5
## The shops's stand-in price is whatever GameState reads from auto.tres; the
## points the harness grants match it so the arithmetic below is exact.
const _AUTO_PRICE := 300

var _failures: PackedStringArray = []
var _checks := 0

var _save: SaveSystem
var _gs: GameState
var _shop: ShopPoint
var _door: DoorPoint
var _player: CharacterBody3D
var _shop_log: _ShopLog
## Paths handed to the fake scene changer, in call order. No scene is actually
## swapped -- the fake only records what it was asked for.
var _changed_to: PackedStringArray = []


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


func _finish() -> void:
	print("=== RESULT: %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)


## Fake scene changer: records the requested path and does nothing else. A real
## change_scene_to_file would tear down this very SceneTree under the harness.
func _fake_changer(path: String) -> void:
	_changed_to.append(path)


## PackedStringArray vs Array comparison by contents. Godot does not treat the
## two container types as equal, so a plain `owned == ["pistol"]` would be false
## even when the contents match.
func _packed_eq(packed: PackedStringArray, expected: Array) -> bool:
	if packed.size() != expected.size():
		return false
	for i in packed.size():
		if packed[i] != expected[i]:
			return false
	return true


## Dispatchable key event bound to the interact action. The gate check uses this
## instead of InputEventAction on purpose: an InputEventAction pressed while the
## action is already pressed is deduplicated before it reaches the tree, so the
## second press in a row would silently arrive nowhere. A key event has no such
## dedup, and it is the honest shape of the input anyway -- input_actions.gd pins
## interact to the physical E key.
func _interact_key_event(pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.keycode = KEY_E
	ev.pressed = pressed
	return ev


## The hint string an @export carries ("Node3D", "WeaponData"...), a marker of an
## object-typed export. Plain String exports carry no hint, so the type check
## below reads the property's declared Variant.Type instead.
func _property_hint(node: Object, property_name: String) -> String:
	for entry in node.get_property_list():
		if String(entry.get("name", "")) == property_name:
			return String(entry.get("hint_string", ""))
	return "<missing>"


## The declared Variant.Type of an export, straight from get_property_list().
func _property_type(node: Object, property_name: String) -> Variant.Type:
	for entry in node.get_property_list():
		if String(entry.get("name", "")) == property_name:
			return entry.get("type", TYPE_NIL)
	return TYPE_NIL


func _cleanup() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_TMP_PATH))


## The engine registers GameState/SaveSystem as project autoloads
## (project.godot, Task 6) and installs nodes of those names under /root even in
## --script mode. Left in place they would shadow the harness's own nodes of the
## same name (Godot renames the later one, so /root/GameState would resolve to
## the autoload, which reads user://save.json at _ready and would restore points
## from an unrelated file) and ShopPoint/DoorPoint would talk to it instead.
## Drop them first, so the harness owns /root/GameState and /root/SaveSystem
## exactly as it did before the autoloads existed. Immediate free, not
## queue_free: the names must be free before the nodes below are added.
func _drop_autoloads() -> void:
	for autoload_name in ["GameState", "SaveSystem"]:
		var node := root.get_node_or_null(autoload_name)
		if node != null:
			root.remove_child(node)
			node.free()


# --------------------------------------------------------------------------
# world builders
# --------------------------------------------------------------------------

## A floor under the player so the physics ticks the gate check awaits cannot
## quietly drop it out of the shop's reach. Top face at y = 0, where the
## player capsule's bottom sits (1.8 height centred at 0.9 in player.tscn).
func _new_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	root.add_child(floor_body)


# --------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------

func _initialize() -> void:
	print("=== VibeFPS interact test ===")
	_drop_autoloads()
	# Clean sheet: a leftover save from an interrupted run must not be restored
	# into the state under test.
	_cleanup()

	_save = SaveSystem.new()
	# The name is what makes /root/SaveSystem resolve for GameState's autosave.
	_save.name = "SaveSystem"
	_save.save_path = _TMP_PATH
	root.add_child(_save)

	_gs = GameState.new()
	# The name is what makes /root/GameState resolve for ShopPoint/DoorPoint.
	_gs.name = "GameState"
	# Injected before add_child, so GameState._ready() must not overwrite it.
	_gs.scene_changer = _fake_changer
	root.add_child(_gs)

	_new_floor()

	# The two interactables are built before the player, so the player's first
	# nearest_interactable() already sees both.
	_shop = ShopPoint.new()
	_shop.weapon_id = "auto"
	_shop.position = Vector3(0.0, 0.0, -3.0)
	root.add_child(_shop)

	_door = DoorPoint.new()
	_door.location_id = "range"
	_door.position = Vector3(0.0, 0.0, -6.0)
	root.add_child(_door)

	var packed: PackedScene = load(_PLAYER_SCENE)
	if packed == null:
		print("FATAL: cannot load %s" % _PLAYER_SCENE)
		_finish()
		quit(1)
		return
	_player = packed.instantiate() as CharacterBody3D
	if _player == null:
		print("FATAL: %s does not instantiate to a CharacterBody3D" % _PLAYER_SCENE)
		_finish()
		quit(1)
		return
	# Swapped before the node enters the tree, so @onready and _ready run on the
	# probe script. Everything under test is the real player.gd; only the mouse
	# mode the gate reads comes from the harness.
	_player.set_script(_PlayerProbe)
	_player.position = Vector3(0.0, 0.0, 0.0)
	root.add_child(_player)

	_shop_log = _ShopLog.new()
	_shop.interacted.connect(_shop_log._on_interacted)

	# Let every _ready run (group join, collision layers, GameState restore).
	await physics_frame

	_test_contracts()
	_test_shop_purchase()
	_test_door_transition()
	_test_nearest_interactable()
	await _test_input_gate()

	_save.clear_save()
	_cleanup()

	_finish()
	quit(1 if _failures.size() > 0 else 0)


# --------------------------------------------------------------------------
# checks
# --------------------------------------------------------------------------

## The references later tasks bind to: a renamed class, export, signal or layer
## is a silent break for lobby.tscn and for the interaction itself.
func _test_contracts() -> void:
	print("-- contracts: the classes, exports, signals, layers and group")
	var shop_script := load(_SHOP_SCRIPT) as Script
	_check(shop_script != null, "shop_point.gd loads")
	if shop_script == null:
		return
	_check(shop_script.get_global_name() == "ShopPoint",
		"shop_point.gd declares class_name ShopPoint",
		"(got \"%s\")" % shop_script.get_global_name())
	_check(shop_script.get_instance_base_type() == "Area3D",
		"ShopPoint extends Area3D", "(got %s)" % shop_script.get_instance_base_type())
	_check(_shop.has_method("interact"), "ShopPoint exposes interact()")
	_check(_shop.has_signal("interacted"), "ShopPoint exposes the interacted signal")
	_check(_property_type(_shop, "weapon_id") == TYPE_STRING,
		"weapon_id is a String export", "(got type %s)" % str(_property_type(_shop, "weapon_id")))
	_check(int(_shop.collision_layer) == 1 << 5,
		"ShopPoint lives on layer 6 (interactable)", "(got %d)" % int(_shop.collision_layer))
	_check(int(_shop.collision_mask) == 1 << 1,
		"and its mask is the player layer", "(got %d)" % int(_shop.collision_mask))
	_check(_shop.monitoring, "ShopPoint monitors overlaps")
	_check(_shop.is_in_group("interactable"), "ShopPoint joins the interactable group")

	var door_script := load(_DOOR_SCRIPT) as Script
	_check(door_script != null, "door_point.gd loads")
	if door_script == null:
		return
	_check(door_script.get_global_name() == "DoorPoint",
		"door_point.gd declares class_name DoorPoint",
		"(got \"%s\")" % door_script.get_global_name())
	_check(door_script.get_instance_base_type() == "Area3D",
		"DoorPoint extends Area3D", "(got %s)" % door_script.get_instance_base_type())
	_check(_door.has_method("interact"), "DoorPoint exposes interact()")
	_check(_property_type(_door, "location_id") == TYPE_STRING,
		"location_id is a String export", "(got type %s)" % str(_property_type(_door, "location_id")))
	_check(int(_door.collision_layer) == 1 << 5,
		"DoorPoint lives on layer 6 (interactable)", "(got %d)" % int(_door.collision_layer))
	_check(int(_door.collision_mask) == 1 << 1,
		"and its mask is the player layer", "(got %d)" % int(_door.collision_mask))
	_check(_door.monitoring, "DoorPoint monitors overlaps")
	_check(_door.is_in_group("interactable"), "DoorPoint joins the interactable group")


func _test_shop_purchase() -> void:
	print("-- shop: refused without points, bought with them")
	_check(_gs.points == 0, "precondition: the player starts with no points",
		"(got %d)" % _gs.points)
	var refused := _shop.interact(_player)
	_check(not refused, "the shop refuses the auto without points")
	_check(_packed_eq(_gs.owned_weapons, ["pistol"]),
		"and does not hand it over", "(got %s)" % _gs.owned_weapons)
	_check(_gs.points == 0, "and charges nothing", "(got %d)" % _gs.points)
	_check(_shop_log.ok_values.size() == 1 and _shop_log.ok_values[0] == false,
		"the refused sale is announced as a refusal",
		"(got %s)" % str(_shop_log.ok_values))

	_gs.award_points(_AUTO_PRICE)
	var bought := _shop.interact(_player)
	_check(bought, "the shop sells the %d auto once the player can afford it" % _AUTO_PRICE)
	_check("auto" in _gs.owned_weapons, "the auto is now owned", "(got %s)" % _gs.owned_weapons)
	_check(_gs.equipped_weapon_id == "auto", "and equipped",
		"(got \"%s\")" % _gs.equipped_weapon_id)
	_check(_gs.points == 0, "the price was deducted", "(got %d)" % _gs.points)
	_check(_shop_log.ok_values.size() == 2 and _shop_log.ok_values[1] == true,
		"the sale is announced as a success", "(got %s)" % str(_shop_log.ok_values))


func _test_door_transition() -> void:
	print("-- door: entering the range goes through the scene changer")
	var entered := _door.interact(_player)
	_check(entered, "the door enters the unlocked range")
	_check(_changed_to.size() > 0 and _changed_to[_changed_to.size() - 1] == "res://range.tscn",
		"the changer was asked for res://range.tscn", "(got %s)" % _changed_to)


## The reach the brief overrules 2.5 with (R2): a shop at 3.0 m is inside 3.5 m
## and a door at 6.0 m is outside it, so a 2.5 m range or a 6.0 m one both fail
## this pair.
func _test_nearest_interactable() -> void:
	print("-- reach: the nearest interactable within %.1f m, and nothing beyond" % _EXPECTED_RANGE)
	_player.global_position = Vector3(0.0, 0.0, 0.0)
	var nearest: Node = _player.call("nearest_interactable")
	_check(nearest == _shop,
		"the shop at 3.0 m is found (the range is 3.5, not 2.5)",
		"(got %s)" % ("null" if nearest == null else nearest.name))

	_shop.position = Vector3(0.0, 0.0, -10.0)
	nearest = _player.call("nearest_interactable")
	_check(nearest == null,
		"with the shop at 10 m and the door at 6 m, nothing is in reach",
		"(got %s)" % ("null" if nearest == null else nearest.name))
	# Put the shop back: the gate check below needs a target an ungated press
	# can actually reach.
	_shop.position = Vector3(0.0, 0.0, -3.0)


## Interact is play input: it must not be a way around a free cursor. With the
## cursor free the same press has to do nothing at all, and capturing it has to
## be the only thing that changes.
func _test_input_gate() -> void:
	print("-- input gate: interact does not get around the cursor being free")
	_player.global_position = Vector3(0.0, 0.0, 0.0)
	var before := _shop_log.ok_values.size()

	_player.set("gate_mouse_mode", Input.MOUSE_MODE_VISIBLE)
	Input.parse_input_event(_interact_key_event(true))
	# Synchronous delivery, exactly as tests/movement.gd does for jump: Godot
	# otherwise accumulates parsed events and flushes them only on the next main
	# loop iteration, which would let the assertions race the delivery.
	Input.flush_buffered_events()
	await physics_frame
	_check(_shop_log.ok_values.size() == before,
		"a press with the cursor free reaches neither the shop nor its signal",
		"(got %d signals)" % (_shop_log.ok_values.size() - before))
	_check(_gs.points == 0, "and spends no points",
		"(got %d)" % _gs.points)
	_check(_gs.equipped_weapon_id == "auto",
		"and leaves the equipped weapon alone", "(got \"%s\")" % _gs.equipped_weapon_id)

	# A real press returns through a release: the second press is a new press,
	# not a repeat of the first one.
	_player.set("gate_mouse_mode", Input.MOUSE_MODE_CAPTURED)
	Input.parse_input_event(_interact_key_event(false))
	Input.flush_buffered_events()
	await physics_frame
	Input.parse_input_event(_interact_key_event(true))
	Input.flush_buffered_events()
	await physics_frame
	_check(_shop_log.ok_values.size() == before + 1,
		"the same press reaches the shop once the cursor is captured",
		"(got %d signals)" % (_shop_log.ok_values.size() - before))
	if _shop_log.ok_values.size() == before + 1:
		_check(_shop_log.ok_values[before] == true,
			"and reports the second purchase as a success")

	# The second purchase of an owned weapon is an equip, not a charge.
	_check(_gs.equipped_weapon_id == "auto",
		"the second purchase only equips: auto stays equipped",
		"(got \"%s\")" % _gs.equipped_weapon_id)
	_check(_gs.points == 0, "and it charged nothing",
		"(got %d)" % _gs.points)

