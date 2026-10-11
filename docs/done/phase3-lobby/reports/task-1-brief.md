> **Назначение:** Бриф задачи фазы.

# Task 1 Brief: SaveSystem — автозагрузка сохранения (трек B)

Проект VibeFPS (Godot 4.7.2, GDScript, Jolt). Рабочий каталог: `E:\projects\VibeFPS`.
Работаешь над Фазой 3 «Лобби»: последовательно добавляются лобби-сцена, очки, покупки, сохранение. Твоя задача — первая: автосохранение состояния игры.

**Contract (обязательно):**
- НЕ коммитить (`git add`/`commit` не делать) — коммитит владелец.
- Никаких субагентов: вся работа — сам, ревью делает контроллер после отчёта.
- Проверки — ТОЛЬКО командой: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 <фильтр>` (Godot headless; напрямую godot не запускать).
- В рабочем дереве есть незакоммиченные чужие правки (владельца и прошлых задач) — их НЕ откатывать, не трогать; твой дифф — только твои файлы.
- Полный отчёт писать в `C:\Users\serhio\.opencode\plan\sdd\2026-10-10-vibefps-phase3-lobby\task-1-report.md`; в финальном сообщении — короткий статус (Status/тесты/concerns/путь отчёта).
- Кириллица в файлах — UTF-8, это норма; в консоли PowerShell кириллица может отображаться моджибакед — это только отображение.

## Files
- Create: `scripts/save_system.gd`
- Create: `tests/save.gd`
- Modify: `tools/run_checks.ps1` — НЕ нужно (имя `save` уже есть в `$Tests`).

## Interfaces
Produces: `SaveSystem extends Node`:
- `@export var save_path: String = "user://save.json"`
- `func save(payload: Dictionary) -> bool`
- `func load_state() -> Dictionary`
- `func clear_save() -> void`
- `func has_save() -> bool`

Скрипт станет автозагрузкой вида `*res://scripts/save_system.gd` (регистрация в `project.godot` — в Task 6, НЕ сейчас; в тестах инстанцируешь вручную).

## Step 1: Написать падающий тест `tests/save.gd`

Каркас по образцу проекта: `extends SceneTree`, `_initialize()`, `_check(ok, label, detail)`, в конце `quit(1 if _failures.size() > 0 else 0)` (образец: `tests/smoke.gd:14-57` — прочитать).

```gdscript
const _TMP_PATH := "user://save_test.json"
# Перед тестом: удалить файл _TMP_PATH (FileAccess.delete_absolute / DirAccess.remove_absolute) — чистая отправная точка.
# 1) has_save() == false на старте
# 2) save({ "points": 42, "equipped": "auto" }) == true; has_save() == true
# 3) load_state() == { "points": 42, "equipped": "auto" } (полный круг)
# 4) clear_save(); has_save() == false
# 5) load_state() на отсутствующем файле == {} (не крашится)
# 6) ПОВРЕЖДЁННЫЙ файл: записать в _TMP_PATH строку "{ not valid json"; load_state() == {} и тест жив
# 7) save() при невозможности записи (путь на «директорию») == false
```

Инстанс: `var _save := SaveSystem.new(); _save.save_path = _TMP_PATH; root.add_child(_save)` — в `_initialize()` до проверок. В `_initialize()` после ассертов — `_save.clear_save()` cleanup; обработка await: при необходимости ожидай кадры через `await physics_frame` (между ассертами с диском).

## Step 2: Прогнать, убедиться что падает

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 save`
Expected: FAIL.

## Step 3: Реализовать `scripts/save_system.gd`

`class_name SaveSystem`, `extends Node`. JSON: `JSON.stringify` / `JSON.parse_string` (Godot 4: при ошибке возвращает `null` — трактуем как `{}`). Запись: `FileAccess.open(save_path, FileAccess.WRITE)` — неудача открытия → `false`; после записи проверять ошибку (`store_string` + `get_error`) — при ошибке `false`. `_init()` диск НЕ трогает.

## Step 4: Прогнать, убедиться что зелёный

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 save`
Expected: PASS (RESULT: 0 failed, exit 0).

## Step 5: Мутация для доказательства «повреждённый файл не роняет»

Временно убрать ветку обработки ошибки парсинга в `load_state()`, прогнать, вернуть. Expected: тест 6 краснеет; после возврата — снова зелёный. Оба прогона записать в отчёт (команда + вывод).

## TDD Evidence (в отчёте)
RED: команда + релевантный падающий вывод (почему ожидался). GREEN: команда + проходящий вывод. Мутация: команда + красный + возврат + зелёный.

## Инварианты проекта (не ломать)
- Тесты других сьютов не трогать; полный сьют не обязан гоняться в этой задаче, но твои изменения не должны затрагивать чужие файлы.
- `user://save.json` (боевой путь) в тестах не используется — только `user://save_test.json`.