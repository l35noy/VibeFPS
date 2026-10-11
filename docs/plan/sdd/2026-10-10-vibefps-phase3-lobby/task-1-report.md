# Task 1 Report: SaveSystem — автозагрузка сохранения (трек B)

**Status:** DONE_WITH_CONCERNS
**Проверка:** `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 save` — финальный прогон: `save PASS`, `RESULT: 1 passed, 0 failed, 0 skipped`, exit 0.

## Что реализовано

`scripts/save_system.gd` — `class_name SaveSystem`, `extends Node`, ровно по контракту брифа:
- `@export var save_path: String = "user://save.json"`
- `func save(payload: Dictionary) -> bool` — `FileAccess.open(save_path, WRITE)`; неудача открытия → `false`; `store_string(JSON.stringify(payload))` + `get_error()` → при ошибке `false`; `close()`.
- `func load_state() -> Dictionary` — `FileAccess.open(save_path, READ)`; `null` (нет файла/нечитаем) → `{}`; `JSON.parse_string(...)`; `parsed if parsed is Dictionary else {}` (невалидный JSON или JSON-не-объект → `{}`).
- `func clear_save() -> void` — `DirAccess.remove_absolute(...)`; отсутствующий файл — не событие.
- `func has_save() -> bool` — `FileAccess.file_exists(save_path)`.
- `_init()` диск не трогает (не определён). Автозагрузка в `project.godot` НЕ регистрировалась (Task 6).

`tests/save.gd` — каркас по образцу `tests/smoke.gd` (`extends SceneTree`, `_check(ok, label, detail)`, `quit(1 if _failures.size() > 0 else 0)`). Инстанс `SaveSystem.new()` создаётся в `_initialize()`, `save_path = _TMP_PATH` (`user://save_test.json`), `root.add_child(_save)`, между обращениями к диску — `await physics_frame`. Боевой путь `user://save.json` в тесте не используется. В начале и в конце — очистка (`_cleanup()` удаляет тестовый файл и тестовую директорию; финальный `_save.clear_save()`). Все 7 пунктов брифа покрыты (см. ниже). Итог: 11 checks.

## TDD Evidence

### RED (до реализации)
Команда:
```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 save
```
Вывод (релевантно):
```
importing project (class cache missing or stale) ...
save           FAIL  (exit code 1)
    SCRIPT ERROR: Parse Error: Could not find type "SaveSystem" in the current scope.
       at: GDScript::reload (res://tests/save.gd:20)
    SCRIPT ERROR: Parse Error: Cannot infer the type of "saved" variable because the value doesn't have a set type.
    ...
RESULT: 0 passed, 1 failed, 0 skipped
```
Почему ожидался: тест ссылается на `SaveSystem`, которого ещё нет — FAIL закономерен (экзит-код 1; ошибки вывода типов `saved`/`loaded` — следствие неизвестного класса, ушли сами после реализации).

### GREEN
Команда (финальная структура):
```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 save
```
Вывод:
```
importing project (class cache missing or stale) ...
save           PASS

RESULT: 1 passed, 0 failed, 0 skipped
```
(exit 0; 11/11 checks прошли, включая: отсутствие сейва на чистом старте; `save(...)==true` + `has_save()==true`; round-trip значений; `clear_save()` → `has_save()==false`; `load_state()` на отсутствующем файле → `{}`; повреждённый `"{ not valid json"` → `{}` без падения; валидный JSON не-объектной формы `"[1, 2, 3]"` → `{}`; `save()` на пути-директории → `false`.)

Важное уточнение по ходу: первый заход на GREEN дал FAIL по round-trip — Godot 4.7.2 `JSON.parse_string` читает `42` как float `42.0`, а `Dictionary` equality по-типово-строгая, поэтому `loaded == { "points": 42, ... }` ложно даже при корректном round-trip. Это поведение движка, не баг реализации. Заменил на проверку значений (`.get()` + числовое сравнение) — с комментарием в тесте.

### Мутация (Step 5 брифа) — ОТКЛОНЕНИЕ от ожидаемого результата, задокументировано
Мутация «убрать ветку обработки ошибки парсинга» в `load_state()`:
```gdscript
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed  # вместо: parsed if parsed is Dictionary else {}
```
Команда: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 save`
Результат: **остался GREEN** (`save PASS`, exit 0) — тест 6 не покраснел.

Диагностика механизма (временная, в тест добавлен print + принудительный FAIL для вывода; ПОЛНОСТЬЮ откачено):
```
DIAG under mutation: load_state()={  } type=Dictionary
SCRIPT ERROR: Trying to return a value of type "Nil" from a function whose return type is "Dictionary".
SCRIPT ERROR: Trying to return a value of type "Array" from a function whose return type is "Dictionary".
```
Вывод: в Godot 4.7.2 типизированный возврат `-> Dictionary` сам коэрсит не-Dictionary значения (`null`, `Array`) в `{}` (с нефатальным SCRIPT ERROR на stderr), т.е. **защита от повреждённого файла на этом движке обеспечена типом возврата, а не веткой `is Dictionary`** — «убрать ветку» через API не наблюдаемо, ожидаемый по брифу RED в принципе не достижим. Это находка для контроллера (см. Concerns).

Чтобы мутация всё же была продемонстрирована красной и тест реально охранял поведение `load_state()`, я:
1) расширил повреждённый-кейс случаем «валидный JSON не-объектной формы» (`"[1, 2, 3]"`) — единственный кейс, где ветка `is Dictionary` реально нагружена;
2) перевёл проверки round-trip на `.get()` — пропавший ключ даёт чистый `[FAIL]`, а не фатальную ошибку.

Демонстрационная мутация (наблюдаемая регрессия формы: `load_state()` возвращает только `points`):
```
save           FAIL  (exit code 1)
      [FAIL] load_state() returns the same number of keys as saved (got { "points": 42.0 })
      [FAIL] load_state() round-trips the equipped value (got <null>)
    === RESULT: 11 checks, 2 failed, 0 warnings ===
RESULT: 0 passed, 1 failed, 0 skipped
```
→ Возврат истинной реализации → повторный прогон:
```
save           PASS
RESULT: 1 passed, 0 failed, 0 skipped
```

Побочная находка по пути: первый заход этой мутации (до hardened `.get()`) дал фатальную `SCRIPT ERROR: Invalid access to property or key 'equipped'` → `_initialize()` обрывался до `quit()` → Godot висел до 120-секундного таймаута (`save FAIL (timed out after 120 s)`). Ошибки «invalid key access» на этом движке фатальны (в отличие от ошибок типа возврата). Хардненинг теста устранил риск зависания.

## Files changed
- `scripts/save_system.gd` — новый.
- `tests/save.gd` — новый.
- `scripts/save_system.gd.uid`, `tests/save.gd.uid` — сгенерированы движком во время импорта (репозиторий хранит `.uid` для всех остальных скриптов; владельцу включить в коммит).
- Чужие незакоммиченные правки (`CHECKLIST.md`, `PROJECT.md`, `pistol.tscn`, `player.gd`, `project.godot`, `scripts/enemy_contact.gd`, `scripts/pistol.gd`, `tests/weapon.gd`) не тронуты. Коммитов не делал.
- `project.godot` не менялся (автозагрузка — Task 6).

## Self-review findings
- Контракт брифа соблюдён полностью: интерфейс, сигнатуры, семантика записи (`open`-fail → false, `store_string`+`get_error`), `user://save_test.json` изолирован, прод-путь не задет, очистка после прогона (в `user://` не осталось `save_test.json`/`save_test_dir`).
- YAGNI: без лишнего API (нет создания родительских директорий, нет `flush`, нет автозагрузки — по брифу).
- Тест проверяет поведение, а не внутренности: round-trip значений, пустота на отсутствующем/повреждённом/не-объектном файле, неуспешная запись.
- Два осознанных отклонения от «буквы» брифа (с комментариями в коде): value-level сравнение round-trip вместо цело-словарного `==`; дополнительный кейс не-объектного JSON + `.get()` вместо `[]`.
- Вывод без шума в PASS-прогонах (у runner детали видны только при FAIL).

## Concerns
1. **Step 5 брифа на Godot 4.7.2 не воспроизводится буквально**: «убрать ветку обработки ошибки парсинга → тест 6 краснеет» не выполнимо — типизированный возврат `-> Dictionary` + нефатальные runtime-ошибки коэрсят `null`/`Array` в `{}`, т.е. движок сам является защитой, ветка `is Dictionary` через API не наблюдаема. Доказательства: 2 зелёных мутационных прогона + диагностический вывод (`DIAG ... type=Dictionary`, SCRIPT ERROR на возврат Nil/Array). Вместо неё продемонстрирован красный на наблюдаемой мутации формы `load_state()`. Рекомендация: в последующих задачах не полагаться на «мутацию → красный» через удаление обработчиков внутри типизированных функций.
2. **Строка шума на stderr при тесте повреждённого файла**: движок печатает `ERROR: Parse JSON failed. Error at line 0: Expected key` (это неотъемлемо от `JSON.parse_string` на заведомо битом файле; в PASS-прогонах не видна, на результат не влияет).
3. **Фатальные runtime-ошибки GDScript могут вешать весь чек** до 120-секундного таймаута вместо быстрого FAIL (наблюдалось на `invalid key access`). В тесте это закрыто `.get()`; в других сьютах стоит иметь в виду.
4. `.uid`-файлы сгенерированы движком — владельцу включить в коммит (по конвенции репозитория).