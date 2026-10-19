class_name SaveSystem
extends Node

## Автосохранение состояния игры в JSON-файл по пути user://.
##
## Фаза 3, Трек B: скрипт зарегистрирован как автозагрузка проекта
## (*res://core/save_system.gd в project.godot); в тестах может инстанцироваться
## изолированно с переопределённым путём save_path.

@export var save_path: String = "user://save.json"

## Количество успешных синхронных записей на диск.
## Используется для мониторинга I/O и тестирования дебаунса/батчинга.
var save_count: int = 0


## Сериализует переданный словарь payload в JSON и записывает в save_path.
## Возвращает false при невозможности открыть файл или ошибке записи,
## чтобы вызывающий код не принял неудачное сохранение за успешное.
func save(payload: Dictionary) -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	var err := file.get_error()
	file.close()
	if err == OK:
		save_count += 1
		return true
	return false


## Читает файл save_path и возвращает его содержимое в виде Dictionary.
## Если файл отсутствует, не читается или содержит повреждённый JSON,
## метод безопасно возвращает {} — загрузка никогда не должна аварийно завершать игру.
func load_state() -> Dictionary:
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


## Удаляет файл сохранения. Отсутствие файла не считается ошибкой.
func clear_save() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


## Возвращает true, если файл сохранения существует по пути save_path.
func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## Сбрасывает счётчик успешно выполненных записей на диск.
func reset_save_count() -> void:
	save_count = 0


## Метод принудительного сброса буферов. В синхронной реализации FileAccess
## запись сбрасывается при save(), метод оставлен для обратной совместимости API.
func flush() -> void:
	pass


