# Task 1 Review Package — SaveSystem
Base: b7ad7c5 (project policy: no commits by implementers — package shows working-tree state of task files)

---
## Task files (git status)
?? scripts/save_system.gd
?? scripts/save_system.gd.uid
?? tests/save.gd
?? tests/save.gd.uid

---
## scripts/save_system.gd (NEW, full)
class_name SaveSystem
extends Node

## Autosave of the game state to a JSON file under user://.
##
## Phase 3, Track B: this script will be registered as a project autoload of the
## form *res://scripts/save_system.gd in project.godot (a later task); until
## then the tests instantiate it manually against an isolated path.

@export var save_path: String = "user://save.json"


## Serializes the payload to JSON and writes it to save_path.
## Returns false when the file cannot be opened or the write reports an error,
## so callers never mistake a failed save for a successful one.
func save(payload: Dictionary) -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	var err := file.get_error()
	file.close()
	return err == OK


## Reads save_path back as a Dictionary. A missing or unreadable file, a file
## whose content is not valid JSON, or valid JSON that is not an object all
## come back as {} вЂ” a load must never crash the caller over a bad save file.
func load_state() -> Dictionary:
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


## Deletes the save file. A missing file is a non-event.
func clear_save() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


## True when a save file currently exists at save_path.
func has_save() -> bool:
	return FileAccess.file_exists(save_path)

---
## tests/save.gd (NEW, full)
extends SceneTree

## SaveSystem harness for VibeFPS.
## Exercises SaveSystem against an isolated user:// path (save_test.json) so the
## production save file (user://save.json) is never touched: no save on a clean
## start, a save/load round-trip, clear_save(), a load from a missing file, a
## load from a corrupted file, and a write that must fail (path is a directory).
## Run: godot --headless --path . --script res://tests/save.gd
##      .\tools\run_checks.ps1 save

## Isolated path every test interaction uses. The production path
## (user://save.json) is intentionally never touched by this harness.
const _TMP_PATH := "user://save_test.json"
## A directory in user:// whose path save() must refuse to write to.
const _TMP_DIR := "user://save_test_dir"

var _failures: PackedStringArray = []
var _warnings: PackedStringArray = []
var _checks := 0
var _save: SaveSystem


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


## Clean sheet before and after the run: neither the test file nor the test
## directory may survive into a later run. Removing a path that does not exist
## is a non-event (remove_absolute just reports an error, which we ignore).
func _cleanup() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_TMP_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_TMP_DIR))


## Overwrites the test path with arbitrary text (malformed JSON or valid JSON
## of a non-object shape) to exercise load-time resilience.
func _write_file(text: String) -> void:
	var file := FileAccess.open(_TMP_PATH, FileAccess.WRITE)
	if file == null:
		_warn("cannot open %s to write test content" % _TMP_PATH)
		return
	file.store_string(text)
	file.close()


func _initialize() -> void:
	print("=== save system test ===")
	_cleanup()

	_save = SaveSystem.new()
	_save.save_path = _TMP_PATH
	root.add_child(_save)
	await physics_frame

	var payload := { "points": 42, "equipped": "auto" }

	_check(not _save.has_save(), "no save on a clean start")

	var saved := _save.save(payload)
	_check(saved, "save() accepts a payload and reports success")
	await physics_frame
	_check(_save.has_save(), "has_save() is true after save()")

	var loaded := _save.load_state()
	# Whole-dictionary == is intentionally not used: Godot's JSON.parse_string
	# reads every number back as a float ("points" comes back 42.0), and
	# Dictionary equality is type-strict, so `loaded == { "points": 42, ... }`
	# would be false even though the value round-trips correctly. Value-level
	# comparison is the behavior being tested here.
	_check(loaded.size() == payload.size(),
		"load_state() returns the same number of keys as saved", "(got %s)" % loaded)
	# .get() with a fallback, not [] indexing: a regression that drops a key must
	# surface as a plain [FAIL] here, not as a runtime error that aborts the
	# harness (_initialize never reaches quit(), and Godot idles until the
	# runner's 120 s timeout kills the check).
	_check(loaded.get("points") == payload["points"],
		"load_state() round-trips the points value",
		"(got %s, expected %s)" % [loaded.get("points"), payload["points"]])
	_check(loaded.get("equipped") == payload["equipped"],
		"load_state() round-trips the equipped value",
		"(got %s)" % loaded.get("equipped"))

	_save.clear_save()
	await physics_frame
	_check(not _save.has_save(), "has_save() is false after clear_save()")
	_check(_save.load_state() == {},
		"load_state() on a missing file returns an empty dict")

	_write_file("{ not valid json")
	await physics_frame
	_check(_save.load_state() == {},
		"load_state() on a corrupted file returns an empty dict without crashing")

	# "{ not valid json" fails to parse at all (JSON.parse_string -> null, which
	# a `-> Dictionary` return silently coerces to {}). The `is Dictionary` guard
	# in load_state() is only load-bearing when the JSON parses but has a
	# non-object shape, so that case is exercised too.
	_write_file("[1, 2, 3]")
	await physics_frame
	_check(_save.load_state() == {},
		"load_state() on valid JSON that is not an object returns an empty dict")

	await _test_unwritable_path()

	_save.clear_save()
	_cleanup()

	print("=== RESULT: %d checks, %d failed, %d warnings ===" % [
		_checks, _failures.size(), _warnings.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)
	quit(1 if _failures.size() > 0 else 0)


## save() must not pretend a write succeeded when the path points at a
## directory that can never be written as a file.
func _test_unwritable_path() -> void:
	print("-- save() against an unwritable path (a directory) must fail cleanly")
	var status := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_TMP_DIR))
	if status != OK:
		_warn("cannot create %s (error %d)" % [_TMP_DIR, status])
		return
	_save.save_path = _TMP_DIR
	await physics_frame
	_check(not _save.save({ "points": 1 }),
		"save() returns false when the path is a directory")
	_save.save_path = _TMP_PATH

---
## .uid files
uid://fxwykttvq851
uid://bii2j1bfmlxbi
