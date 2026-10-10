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
## come back as {} — a load must never crash the caller over a bad save file.
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
