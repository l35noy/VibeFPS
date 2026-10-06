extends SceneTree

## Diagnostics: inspect Environment settings and probe fall-out-of-world behaviour.

func _initialize() -> void:
	print("=== diagnostics ===")
	var packed: PackedScene = load("res://main.tscn")
	var world: Node3D = packed.instantiate()
	root.add_child(world)
	await physics_frame

	var we := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	print("WorldEnvironment node: %s" % ("present" if we else "MISSING"))
	if we != null and we.environment != null:
		var env := we.environment
		print("  background_mode      = %d  (0=ClearColor 1=CustomColor 2=Sky 3=Canvas 4=Keep)" % env.background_mode)
		print("  background_color     = %s" % env.background_color)
		print("  background_energy    = %.3f" % env.background_energy_multiplier)
		print("  sky resource         = %s" % ("set" if env.sky != null else "NULL"))
		if env.sky != null:
			print("  sky.radiance_size    = %s" % env.sky.radiance_size)
			var mat := env.sky.sky_material
			print("  sky_material         = %s" % ("set" if mat != null else "NULL"))
		print("  ambient_light_source = %d  (0=Background 1=Disabled)" % env.ambient_light_source)
		print("  ambient_light_energy = %.3f" % env.ambient_light_energy)
		print("  tonemap_mode         = %d" % env.tonemap_mode)
		print("  ssao_enabled         = %s" % env.ssao_enabled)
		print("  glow_enabled         = %s" % env.glow_enabled)

	var dl := world.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	print("DirectionalLight3D: %s" % ("present" if dl else "MISSING"))
	if dl != null:
		print("  light_energy=%.3f shadow_enabled=%s" % [dl.light_energy, dl.shadow_enabled])

	# fog off?
	if we != null and we.environment != null:
		print("  fog_enabled = %s" % we.environment.fog_enabled)

	# --- fall out of world behaviour ---
	var player := world.get_node("Player") as CharacterBody3D
	print("-- fall-out-of-world probe")
	player.global_position = Vector3(0, 5, 40)
	player.velocity = Vector3.ZERO
	var t := 0.0
	for i in 1200:
		await physics_frame
		t += 1.0 / 120.0
		if player.global_position.y < -200.0:
			print("  fell below y=-200 after %.2fs -> NO recovery, infinite fall" % t)
			break
	print("  after 10s: pos=%s  on_floor=%s" % [player.global_position, player.is_on_floor()])

	# --- mouse uncaptured: does camera still rotate? ---
	print("-- mouse uncaptured look test")
	var cam := player.get_node("Camera3D") as Camera3D
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var yaw0 := player.rotation.y
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(200, 0)
	Input.parse_input_event(ev)
	await physics_frame
	var dyaw := player.rotation.y - yaw0
	print("  mouse_mode=VISIBLE, yaw delta from motion = %.4f" % dyaw)
	print("  -> camera still turns while cursor is free" if absf(dyaw) > 0.0001 else "  -> camera locked while cursor free")

	# --- jump via InputEventAction (gamepad / remap path) ---
	print("-- jump via non-key event")
	player.global_position = Vector3(0, 1, 0)
	player.velocity = Vector3.ZERO
	for i in 60:
		await physics_frame
	var act := InputEventAction.new()
	act.action = "jump"
	act.pressed = true
	Input.parse_input_event(act)
	for i in 12:
		await physics_frame
	print("  on_floor after non-key jump event = %s (false = jump consumed)" % player.is_on_floor())

	print("=== done ===")
	quit()
