extends SceneTree

## HUD harness for VibeFPS (Phase 3, Task 9): the on-player CanvasLayer that
## shows the player's health, the current weapon's magazine and the score.
##
## The three sources are faked, so the harness pins the HUD's own behaviour --
## formatting, signal wiring, re-binding on a weapon swap and null-safety -- and
## does not depend on player.gd, pistol.gd or GameState internals. A separate
## section loads the real player.tscn and checks the shipped wiring (the UI
## child, current_weapon() and weapon_changed), which is the part a fake cannot
## stand in for.
##
## Run: godot --headless --path . --script res://tests/ui.gd
##      .\tools\run_checks.ps1 ui

const _UI_SCENE := "res://ui.tscn"
const _PLAYER_SCENE := "res://player.tscn"

var _failures: PackedStringArray = []
var _checks := 0


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


## Stand-in for player.gd: only the surface the HUD is allowed to read --
## `health_changed`, `weapon_changed`, `health()` and a `max_health` property.
class _FakePlayer extends Node:
	signal health_changed(current: float, maximum: float)
	signal weapon_changed(weapon: Node)

	var max_health: float = 100.0
	var _health: float = 100.0
	var _weapon: Node = null

	func health() -> float:
		return _health

	func current_weapon() -> Node:
		return _weapon

	func report_health(current: float, maximum: float) -> void:
		_health = current
		max_health = maximum
		health_changed.emit(current, maximum)

	func equip(weapon: Node) -> void:
		_weapon = weapon
		weapon_changed.emit(weapon)


## Stand-in for the weapon: `magazine_changed` plus `current_mag()`.
class _FakeWeapon extends Node:
	signal magazine_changed(current: int, capacity: int)

	var _mag: int = 0

	func current_mag() -> int:
		return _mag

	func report_magazine(current: int, capacity: int) -> void:
		_mag = current
		magazine_changed.emit(current, capacity)


## Stand-in for GameState: `points_changed` plus the `points` field.
class _FakeGameState extends Node:
	signal points_changed(points: int)

	var points: int = 0

	func report_points(value: int) -> void:
		points = value
		points_changed.emit(value)


func _label_text(ui: Node, node_name: String) -> String:
	var label := ui.get_node_or_null(node_name) as Label
	return label.text if label != null else "<missing>"


func _bar_value(ui: Node, node_name: String) -> float:
	var bar := ui.get_node_or_null(node_name) as ProgressBar
	return bar.value if bar != null else -1.0


func _bar_max(ui: Node, node_name: String) -> float:
	var bar := ui.get_node_or_null(node_name) as ProgressBar
	return bar.max_value if bar != null else -1.0


func _initialize() -> void:
	print("=== VibeFPS UI (HUD) test ===")
	await _test_scene_contract()
	await _test_player_wiring()
	await _test_binding()
	await _test_weapon_changed_rebinds()
	await _test_null_safety()

	print("=== RESULT: %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)
	quit(1 if _failures.size() > 0 else 0)


## The stable shape later tasks bind to: the scene loads, its root is a
## CanvasLayer running ui.gd, and the four named elements exist with the right
## types. A rename or a missing node would make every other section meaningless.
func _test_scene_contract() -> void:
	print("-- ui.tscn contract")
	var packed: PackedScene = load(_UI_SCENE)
	_check(packed != null, "res://ui.tscn loads")
	if packed == null:
		return
	var ui := packed.instantiate()
	_check(ui is CanvasLayer, "the ui.tscn root is a CanvasLayer",
		"(got %s)" % ("null" if ui == null else ui.get_class()))
	if ui == null:
		return
	root.add_child(ui)
	await physics_frame
	_check(ui.has_method("bind"), "ui.gd exposes bind(player, weapon, game_state)")
	_check(ui.get_node_or_null("HealthLabel") is Label, "HealthLabel is a Label")
	_check(ui.get_node_or_null("HealthBar") is ProgressBar, "HealthBar is a ProgressBar")
	_check(ui.get_node_or_null("AmmoLabel") is Label, "AmmoLabel is a Label")
	_check(ui.get_node_or_null("PointsLabel") is Label, "PointsLabel is a Label")
	ui.queue_free()
	await physics_frame


## The shipped player.tscn wiring: the HUD hangs off the player, the player
## exposes current_weapon()/weapon_changed, and the HUD is filled on spawn
## without anyone polling it.
func _test_player_wiring() -> void:
	print("-- player.tscn wiring: the HUD rides the player and starts filled")
	var packed: PackedScene = load(_PLAYER_SCENE)
	_check(packed != null, "res://player.tscn loads")
	if packed == null:
		return
	var player := packed.instantiate()
	if player == null:
		_check(false, "player.tscn instantiates")
		return
	# Connect before entering the tree, so the _ready emit is observed: the
	# contract is "emits when ready", which an after-the-fact connect misses.
	var seen_weapons: Array = []
	player.weapon_changed.connect(func(weapon: Node) -> void: seen_weapons.append(weapon))
	root.add_child(player)
	await physics_frame

	_check(player.has_method("current_weapon"),
		"player.gd exposes current_weapon()")
	_check(player.has_signal("weapon_changed"),
		"player.gd exposes the weapon_changed signal")
	var pistol := player.get_node_or_null("Pistol")
	_check(player.current_weapon() == pistol,
		"current_weapon() answers with the Pistol node",
		"(got %s)" % ("null" if player.current_weapon() == null else player.current_weapon().name))
	_check(seen_weapons.size() >= 1 and seen_weapons[0] == pistol,
		"weapon_changed fired once with the pistol on ready",
		"(got %d events)" % seen_weapons.size())

	var hud := player.get_node_or_null("UI")
	_check(hud != null and hud is CanvasLayer,
		"player.tscn carries a UI CanvasLayer child")
	if hud != null:
		_check(hud.has_method("bind"), "the player's UI runs ui.gd")
		# The player emits health_changed/weapon_changed in _ready, and the HUD
		# is a child (its _ready runs first), so it is already subscribed.
		_check(_label_text(hud, "HealthLabel") == "HP 100%",
			"the HUD health label starts full",
			"(got %s)" % _label_text(hud, "HealthLabel"))
		var ammo_expected := str(pistol.current_mag()) if pistol != null else "<none>"
		_check(_label_text(hud, "AmmoLabel") == ammo_expected,
			"the HUD ammo label starts at the loaded magazine",
			"(got %s, expected %s)" % [_label_text(hud, "AmmoLabel"), ammo_expected])
	player.queue_free()
	await physics_frame


## bind() populates from the sources on the spot and then follows their signals.
func _test_binding() -> void:
	print("-- binding: health, ammo and points follow their signals")
	var packed: PackedScene = load(_UI_SCENE)
	if packed == null:
		_check(false, "res://ui.tscn loads (binding)")
		return
	var ui := packed.instantiate()
	root.add_child(ui)
	await physics_frame

	var player := _FakePlayer.new()
	var weapon := _FakeWeapon.new()
	var gs := _FakeGameState.new()
	root.add_child(player)
	root.add_child(weapon)
	root.add_child(gs)

	player.report_health(75.0, 100.0)
	player.equip(weapon)
	weapon.report_magazine(12, 18)
	gs.report_points(300)

	ui.call("bind", player, weapon, gs)
	_check(_label_text(ui, "HealthLabel") == "HP 75%",
		"bind() reads the current health on the spot",
		"(got %s)" % _label_text(ui, "HealthLabel"))
	_check(_bar_value(ui, "HealthBar") == 75.0 and _bar_max(ui, "HealthBar") == 100.0,
		"bind() sets the health bar to current/max",
		"(got %.1f/%.1f)" % [_bar_value(ui, "HealthBar"), _bar_max(ui, "HealthBar")])
	_check(_label_text(ui, "AmmoLabel") == "12",
		"bind() reads the current magazine on the spot",
		"(got %s)" % _label_text(ui, "AmmoLabel"))
	_check(_label_text(ui, "PointsLabel") == "300",
		"bind() reads the current points on the spot",
		"(got %s)" % _label_text(ui, "PointsLabel"))

	player.report_health(40.0, 100.0)
	_check(_label_text(ui, "HealthLabel") == "HP 40%",
		"health_changed moves the label")
	_check(_bar_value(ui, "HealthBar") == 40.0, "and the bar")

	weapon.report_magazine(5, 18)
	_check(_label_text(ui, "AmmoLabel") == "5", "magazine_changed moves the ammo counter")

	gs.report_points(250)
	_check(_label_text(ui, "PointsLabel") == "250", "points_changed moves the score")

	ui.queue_free()
	player.queue_free()
	weapon.queue_free()
	gs.queue_free()
	await physics_frame


## The Task 10 seam: a weapon swap on the player must re-point the ammo counter,
## leaving the old weapon unable to drive it.
func _test_weapon_changed_rebinds() -> void:
	print("-- weapon_changed re-binds the ammo counter to the new weapon")
	var packed: PackedScene = load(_UI_SCENE)
	if packed == null:
		_check(false, "res://ui.tscn loads (weapon_changed)")
		return
	var ui := packed.instantiate()
	root.add_child(ui)
	await physics_frame

	var player := _FakePlayer.new()
	var first := _FakeWeapon.new()
	var second := _FakeWeapon.new()
	root.add_child(player)
	root.add_child(first)
	root.add_child(second)
	first.report_magazine(18, 18)
	second.report_magazine(7, 30)

	ui.call("bind", player, first, null)
	_check(_label_text(ui, "AmmoLabel") == "18",
		"ammo starts at the bound weapon", "(got %s)" % _label_text(ui, "AmmoLabel"))

	player.equip(second)
	_check(_label_text(ui, "AmmoLabel") == "7",
		"weapon_changed re-binds ammo to the new weapon",
		"(got %s)" % _label_text(ui, "AmmoLabel"))

	first.report_magazine(1, 18)
	_check(_label_text(ui, "AmmoLabel") == "7",
		"the old weapon no longer drives the counter",
		"(got %s)" % _label_text(ui, "AmmoLabel"))
	second.report_magazine(2, 30)
	_check(_label_text(ui, "AmmoLabel") == "2",
		"and the new weapon does", "(got %s)" % _label_text(ui, "AmmoLabel"))

	ui.queue_free()
	player.queue_free()
	first.queue_free()
	second.queue_free()
	await physics_frame


## No GameState, no weapon, no player: the HUD must stay silent and keep a
## usable face rather than erroring on a missing source.
func _test_null_safety() -> void:
	print("-- null safety: no player, no weapon, no game state")
	var packed: PackedScene = load(_UI_SCENE)
	if packed == null:
		_check(false, "res://ui.tscn loads (null safety)")
		return
	var ui := packed.instantiate()
	root.add_child(ui)
	await physics_frame

	ui.call("bind", null, null, null)
	_check(true, "bind(null, null, null) returns without error")

	# A plain node has none of the HUD's sources; binding it must be just as quiet.
	var plain := Node.new()
	root.add_child(plain)
	ui.call("bind", plain, null, null)
	_check(true, "binding a source-less node is silent")

	# Rebinding back to nulls after real sources must not leave stale wiring.
	var weapon := _FakeWeapon.new()
	weapon.report_magazine(9, 18)
	root.add_child(weapon)
	ui.call("bind", null, weapon, null)
	_check(_label_text(ui, "AmmoLabel") == "9", "a weapon alone is enough for ammo")
	ui.call("bind", null, null, null)
	weapon.report_magazine(3, 18)
	_check(_label_text(ui, "AmmoLabel") == "9",
		"after unbinding, the old weapon no longer drives the counter",
		"(got %s)" % _label_text(ui, "AmmoLabel"))

	ui.queue_free()
	plain.queue_free()
	weapon.queue_free()
	await physics_frame
