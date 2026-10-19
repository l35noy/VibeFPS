extends SceneTree

## Inventory harness for VibeFPS (Phase 3, Task 10): the on-player inventory panel
## (physical I, buttons + mouse) and the player's weapon swap.
##
## Two subjects, because the task joins them: pressing a button asks GameState to
## equip and the player must actually hold the new weapon. The panel section binds
## a real GameState to a loaded ui.tscn and reads the buttons it builds; the swap
## section loads player.tscn and drives GameState.equip_weapon, checking the node
## in the player's hand. Both are cheaper and more honest against the real classes
## than against hand-built fakes, and neither touches user://save.json: the
## SaveSystem autoload is dropped, so GameState's autosave has nowhere to write.
##
## Run: godot --headless --path . --script res://tests/inventory.gd
##      .\tools\run_checks.ps1 inventory

const _UI_SCENE := "res://ui/ui.tscn"
const _PLAYER_SCENE := "res://entities/player/player.tscn"

var _failures: PackedStringArray = []
var _checks := 0


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


## The engine installs the GameState/SaveSystem autoloads under /root even in
## --script mode. Drop them first (immediate free, before the names are reused):
## the harness then owns /root/GameState, and the real SaveSystem cannot write
## user://save.json behind the checks. Same contract as tests/progression.gd and
## tests/interact.gd.
func _drop_autoloads() -> void:
	for autoload_name in ["GameState", "SaveSystem"]:
		var node := root.get_node_or_null(autoload_name)
		if node != null:
			root.remove_child(node)
			node.free()


## A real GameState under the name /root/GameState resolves for the panel and the
## player. No SaveSystem exists, so every autosave is a no-op.
func _make_game_state() -> GameState:
	var gs := GameState.new()
	gs.name = "GameState"
	root.add_child(gs)
	return gs


## A dispatchable key event for the inventory action. The physical code matches
## project.godot (I is 73); keycode is set too, mirroring tests/interact.gd, so the
## event is a faithful press and not a stand-in for one.
func _inventory_key_event(pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_I
	ev.keycode = KEY_I
	ev.pressed = pressed
	return ev


## The button whose label starts with `prefix`, or null. The equipped marker is a
## suffix, so starts_with finds the button whatever its mark state.
func _button_with(list: Node, prefix: String) -> Button:
	for child in list.get_children():
		if child is Button and (child as Button).text.begins_with(prefix):
			return child
	return null


func _texts(list: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for child in list.get_children():
		if child is Button:
			out.append((child as Button).text)
	return out


## display_name of the weapon held, straight from its data. null when there is no
## weapon or no data.
func _held_name(weapon: Node) -> String:
	if weapon == null:
		return "<none>"
	var data := weapon.get("data") as Resource
	if data == null:
		return "<no data>"
	return str(data.get("display_name"))


func _initialize() -> void:
	print("=== VibeFPS inventory test ===")
	_drop_autoloads()
	await _test_panel_buttons()
	await _test_selection_equips_and_closes()
	await _test_toggle_action()
	await _test_null_safety()
	await _test_weapon_swap()

	print("=== RESULT: %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)
	quit(1 if _failures.size() > 0 else 0)


## One button per owned weapon, labelled with the weapon's display_name, the
## equipped one marked. A weapon with no .tres falls back to its id.
func _test_panel_buttons() -> void:
	print("-- buttons: one per owned weapon, labelled and marked")
	var gs := _make_game_state()
	await physics_frame
	gs.owned_weapons = PackedStringArray(["pistol", "auto", "ghost"])
	gs.equipped_weapon_id = "pistol"

	var ui := (load(_UI_SCENE) as PackedScene).instantiate()
	root.add_child(ui)
	await physics_frame

	var panel := ui.get_node_or_null("InventoryPanel")
	_check(panel != null, "ui.tscn carries an InventoryPanel")
	if panel == null:
		ui.queue_free()
		gs.queue_free()
		await physics_frame
		return
	_check(panel.has_method("open") and panel.has_method("close"),
		"InventoryPanel runs inventory.gd")
	panel.call("bind", gs)
	panel.call("open")

	var list := panel.get_node_or_null("List")
	_check(list != null, "the panel has a List container")
	if list != null:
		_check(list.get_child_count() == 3, "one button per owned weapon",
			"(got %d)" % list.get_child_count())
		var texts := _texts(list)
		_check("Pistol" in texts, "the pistol button uses WeaponData.display_name",
			"(got %s)" % texts)
		_check("Auto" in texts, "the auto button uses WeaponData.display_name",
			"(got %s)" % texts)
		_check("ghost" in texts, "a weapon with no .tres falls back to its id",
			"(got %s)" % texts)
		var pistol_button := _button_with(list, "Pistol")
		_check(pistol_button != null and "✓" in pistol_button.text,
			"the equipped weapon is marked",
			"(got %s)" % (pistol_button.text if pistol_button != null else "<missing>"))
		var auto_button := _button_with(list, "Auto")
		_check(auto_button != null and not ("✓" in auto_button.text),
			"an owned but unequipped weapon is not marked",
			"(got %s)" % (auto_button.text if auto_button != null else "<missing>"))

	ui.queue_free()
	gs.queue_free()
	await physics_frame


## A click equips through GameState and closes the panel.
func _test_selection_equips_and_closes() -> void:
	print("-- selection: a click equips and closes")
	var gs := _make_game_state()
	await physics_frame
	gs.owned_weapons = PackedStringArray(["pistol", "auto"])
	gs.equipped_weapon_id = "pistol"

	var ui := (load(_UI_SCENE) as PackedScene).instantiate()
	root.add_child(ui)
	await physics_frame
	var panel := ui.get_node_or_null("InventoryPanel")
	var list := panel.get_node_or_null("List")
	panel.call("bind", gs)
	panel.call("open")
	_check(bool(panel.call("is_open")), "the panel is open before the click")

	var auto_button := _button_with(list, "Auto")
	_check(auto_button != null, "the auto button exists")
	if auto_button != null:
		auto_button.pressed.emit()
	_check(gs.equipped_weapon_id == "auto",
		"the click equips the weapon through GameState",
		"(got %s)" % gs.equipped_weapon_id)
	_check(not bool(panel.call("is_open")) and not panel.visible,
		"and the panel closes")

	ui.queue_free()
	gs.queue_free()
	await physics_frame


## The inventory action toggles the panel: press once opens, press again closes.
## It runs from _unhandled_input and is deliberately not gated by InputGate, so a
## press with the cursor in any mode reaches it.
func _test_toggle_action() -> void:
	print("-- input: pressing I toggles the panel")
	var gs := _make_game_state()
	await physics_frame
	gs.owned_weapons = PackedStringArray(["pistol"])
	gs.equipped_weapon_id = "pistol"

	var ui := (load(_UI_SCENE) as PackedScene).instantiate()
	root.add_child(ui)
	await physics_frame
	var panel := ui.get_node_or_null("InventoryPanel")
	panel.call("bind", gs)
	_check(not bool(panel.call("is_open")) and not panel.visible,
		"the panel starts hidden")

	Input.parse_input_event(_inventory_key_event(true))
	Input.flush_buffered_events()
	await physics_frame
	_check(bool(panel.call("is_open")) and panel.visible,
		"pressing I opens the panel")

	# A real press returns through a release, so the second press is a new edge.
	Input.parse_input_event(_inventory_key_event(false))
	Input.flush_buffered_events()
	await physics_frame
	Input.parse_input_event(_inventory_key_event(true))
	Input.flush_buffered_events()
	await physics_frame
	_check(not panel.call("is_open") and not panel.visible,
		"pressing I again closes it")

	ui.queue_free()
	gs.queue_free()
	await physics_frame


## No GameState: the panel opens empty, and a player keeps its scene's pistol.
func _test_null_safety() -> void:
	print("-- null safety: no GameState")
	root.get_node_or_null("GameState") # sanity: nothing lingers between sections

	var ui := (load(_UI_SCENE) as PackedScene).instantiate()
	root.add_child(ui)
	await physics_frame
	var panel := ui.get_node_or_null("InventoryPanel")
	_check(panel != null, "the panel exists without a GameState")
	panel.call("bind", null)
	panel.call("open")
	_check(panel.call("is_open"), "the panel opens without a GameState")
	var list := panel.get_node_or_null("List")
	_check(list != null and list.get_child_count() == 0,
		"and shows no buttons",
		"(got %d)" % (list.get_child_count() if list != null else -1))
	panel.call("close")

	var player := (load(_PLAYER_SCENE) as PackedScene).instantiate()
	root.add_child(player)
	await physics_frame
	var weapon: Node = player.call("current_weapon")
	_check(weapon != null, "the player still holds a weapon without a GameState")
	_check(_held_name(weapon) == "Pistol",
		"and it is the scene's default pistol",
		"(got %s)" % _held_name(weapon))

	player.queue_free()
	ui.queue_free()
	await physics_frame


## GameState says which weapon is equipped; the player must hold exactly that
## weapon, in the same hand slot, and swap back on request.
func _test_weapon_swap() -> void:
	print("-- weapon swap: the player holds the equipped weapon")
	var gs := _make_game_state()
	await physics_frame
	gs.owned_weapons = PackedStringArray(["pistol", "auto"])
	gs.equipped_weapon_id = "pistol"

	var player := (load(_PLAYER_SCENE) as PackedScene).instantiate()
	root.add_child(player)
	await physics_frame

	var start: Node = player.call("current_weapon")
	_check(start != null, "the player holds a weapon on ready")
	_check(_held_name(start) == "Pistol", "the pistol is held when it is equipped",
		"(got %s)" % _held_name(start))
	_check(start != null and start.scene_file_path == "res://weapons/pistol/pistol.tscn",
		"and it comes from the pistol scene",
		"(got %s)" % ("<none>" if start == null else start.scene_file_path))
	var hand_position := (start as Node3D).position if start is Node3D else Vector3.ZERO

	gs.equip_weapon("auto")
	await physics_frame
	var swapped: Node = player.call("current_weapon")
	_check(swapped != null, "a weapon is still held after equipping the auto")
	_check(swapped != start, "the slot node was replaced, not the same instance")
	_check(_held_name(swapped) == "Auto", "the auto's own data is now in hand",
		"(got %s)" % _held_name(swapped))
	_check(swapped != null and swapped.scene_file_path == "res://weapons/auto/auto.tscn",
		"the auto scene occupies the slot",
		"(got %s)" % ("<none>" if swapped == null else swapped.scene_file_path))
	_check(swapped != null and swapped.name == "Pistol",
		"the new weapon keeps the slot name so it stays findable")
	if swapped is Node3D:
		_check((swapped as Node3D).position.is_equal_approx(hand_position),
			"the hand transform is preserved across the swap",
			"(got %s, expected %s)" % [(swapped as Node3D).position, hand_position])

	gs.equip_weapon("pistol")
	await physics_frame
	var back: Node = player.call("current_weapon")
	_check(_held_name(back) == "Pistol", "equipping the pistol again swaps back",
		"(got %s)" % _held_name(back))

	player.queue_free()
	gs.queue_free()
	await physics_frame
