extends SceneTree

## Проверка SaveSystem для VibeFPS.
## Тестирует SaveSystem на изолированном пути (user://save_test.json), не затрагивая
## основной файл сохранений (user://save.json): проверка чистого старта,
## цикл сохранения/загрузки, clear_save(), чтение отсутствующего файла,
## обработка повреждённого JSON и отказ при попытке записи в каталог.
## Запуск: godot --headless --path . --script res://tests/save.gd
##         .\tools\run_checks.ps1 save

## Изолированный путь для тестов.
const _TMP_PATH := "user://save_test.json"
## Каталог в user://, в который save() обязан отказаться записывать файл.
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


## Очистка временных файлов до и после прогона теста.
func _cleanup() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_TMP_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_TMP_DIR))


## Записывает в тестовый файл произвольный текст (невалидный JSON или массив вместо объекта).
func _write_file(text: String) -> void:
	var file := FileAccess.open(_TMP_PATH, FileAccess.WRITE)
	if file == null:
		_warn("не удалось открыть %s для записи тестовых данных" % _TMP_PATH)
		return
	file.store_string(text)
	file.close()


func _initialize() -> void:
	print("=== Проверка системы сохранений (SaveSystem) ===")
	_cleanup()

	_save = SaveSystem.new()
	_save.save_path = _TMP_PATH
	root.add_child(_save)
	await physics_frame

	var payload := { "points": 42, "equipped": "auto" }

	_check(not _save.has_save(), "при чистом старте сохранение отсутствует")

	var saved := _save.save(payload)
	_check(saved, "save() принимает payload и сообщает об успехе")
	await physics_frame
	_check(_save.has_save(), "has_save() возвращает true после save()")

	var loaded := _save.load_state()
	# Прямое равенство словарей не используется: JSON.parse_string возвращает числа как float (42.0),
	# поэтому сравниваем значения по ключам.
	_check(loaded.size() == payload.size(),
		"load_state() возвращает то же количество ключей, что и сохранено", "(получено %s)" % loaded)
	_check(loaded.get("points") == payload["points"],
		"load_state() корректно восстанавливает очки",
		"(получено %s, ожидалось %s)" % [loaded.get("points"), payload["points"]])
	_check(loaded.get("equipped") == payload["equipped"],
		"load_state() корректно восстанавливает экипированное оружие",
		"(получено %s)" % loaded.get("equipped"))

	_save.clear_save()
	await physics_frame
	_check(not _save.has_save(), "has_save() возвращает false после clear_save()")
	_check(_save.load_state() == {},
		"load_state() при отсутствии файла возвращает пустой словарь")

	_write_file("{ not valid json")
	await physics_frame
	_check(_save.load_state() == {},
		"load_state() при повреждённом JSON возвращает пустой словарь без вылета")

	_write_file("[1, 2, 3]")
	await physics_frame
	_check(_save.load_state() == {},
		"load_state() при валидном JSON не-объекте возвращает пустой словарь")

	await _test_unwritable_path()

	_save.clear_save()
	_cleanup()

	print("=== РЕЗУЛЬТАТ: %d проверок, %d провалено, %d предупреждений ===" % [
		_checks, _failures.size(), _warnings.size()])
	for f in _failures:
		print("  ОШИБКА: %s" % f)
	quit(1 if _failures.size() > 0 else 0)


## save() не должен притворяться успешным, если путь указывает на каталог.
func _test_unwritable_path() -> void:
	print("-- save() в недоступный путь (каталог) должен возвращать отказ")
	var status := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_TMP_DIR))
	if status != OK:
		_warn("не удалось создать %s (ошибка %d)" % [_TMP_DIR, status])
		return
	_save.save_path = _TMP_DIR
	await physics_frame
	_check(not _save.save({ "points": 1 }),
		"save() возвращает false, если путь является каталогом")
	_save.save_path = _TMP_PATH