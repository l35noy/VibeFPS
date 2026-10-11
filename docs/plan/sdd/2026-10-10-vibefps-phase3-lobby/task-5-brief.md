# Task 5 Brief: Смерть → лобби + очки за убийство (трек A, после Task 3 и Task 4)

Проект VibeFPS (Godot 4.7.2 stable, GDScript, Jolt). Рабочий каталог: `E:\projects\VibeFPS`.
Фаза 3 «Лобби». Готово: GameState (T3 — `return_to_lobby(reason)`, `award_points(amount)`, `POINTS_PER_KILL`), взаимодействие (T4). Твоя задача — сменить контракт смерти игрока (был респавн на месте → теперь возврат в лобби) и начислять очки за убийство врага.

**Contract (обязательно):**
- НЕ коммитить; никаких субагентов; проверки — только `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 <фильтр>` (Godot headless; напрямую godot не запускать).
- В рабочем дереве НЕзакоммиченные чужие правки — НЕ откатывать, НЕ трогать: `scripts/enemy_contact.gd` имеет DOC-CLEANUP-правки (только комментарии, одобрены) — работаешь ПОВЕРХ; `player.gd` имеет владельческую правку (новая строка в конце) — работаешь поверх. Обе — твои файлы на изменение.
- Полный отчёт: `C:\Users\serhio\.opencode\plan\sdd\2026-10-10-vibefps-phase3-lobby\task-5-report.md`; финальное сообщение — короткий статус.
- Кириллица в файлах — UTF-8 (норма).

## Files
- Modify: `scripts/player.gd` (`take_damage`: смерть → `return_to_lobby`, fallback `_respawn(true)`)
- Modify: `scripts/enemy_contact.gd` (смерть врага → `award_points(POINTS_PER_KILL)`)
- Modify: `tests/enemies.gd` (РЕГРЕССИЯ: секции респавна игрока; новый ассерт начисления очков)

## Потребляемые интерфейсы (Task 3 — читать scripts/game_state.gd)
`GameState`: `return_to_lobby(reason: String) -> void`, `award_points(amount: int) -> void`, `POINTS_PER_KILL := 10`. Получение: `get_node_or_null("/root/GameState")` — null-safe.

Текущий контракт смерти (читать перед правкой): `player.gd::take_damage` при летальном уроне испускает `died.emit()` и вызывает `_respawn(true)` (≈ строки 104-107). `_respawn(restore_health)` — респавн на точке появления; падение за карту (`fall_limit`) — респавн БЕЗ восстановления здоровья (контракт не меняется!).

## Step 1: Контракт смерти в `player.gd`
После `died.emit()`:
```gdscript
var gs := get_node_or_null("/root/GameState") as GameState
if gs != null:
    gs.return_to_lobby("death")
else:
    _respawn(true)  # fallback: headless-проверки и сцены без автозагрузки
```
Комментарий на русском о контракте «смерть возвращает в лобби» (Фаза 3) и fallback для тестов. НЕ трогать ветку падения за карту.

## Step 2: Обновить регрессионные секции `tests/enemies.gd`
Найти секции, проверяющие смерть игрока и «смерть лечит респавном» (≈ строки 290-410: «Здоровье игрока», включая мутацию `_respawn(false)`). Правки:
- тесты «смерть → `_respawn(true)`» переписать: добавить в root пробный `GameState` (с подменённым `scene_changer`), смерть вызывает `return_to_lobby("death")` — проверить reason и что `_respawn` НЕ вызывался (здоровье не восстановлено смертью сама по себе);
- поведение БЕЗ GameState: смерть → прежний респавн на месте (fallback) — сохранить прежние ассерты в ОТДЕЛЬНОЙ секции с прекондишеном «GameState в root нет»;
- «падение за карту не лечит» — контракт не менялся, НЕ трогать.
Отчёт обязан перечислить изменённые строки файла.

## Step 3: Очки за убийство врага (`enemy_contact.gd`)
В обработчике смерти врага (там, где обесцвечивание/`queue_free`, ровно один раз): 
```gdscript
var gs := get_node_or_null("/root/GameState")
if gs != null:
    gs.award_points(int(gs.POINTS_PER_KILL))
```
null-safe, однократно (смерть строго один раз).
В `tests/enemies.gd` — секция «очки за убийство»: мир с врагом + игроком + `GameState` в root (с подменённым scene_changer); убить врага (как в существующих секциях смерти врага, ≈ строки 580-640); `points == 10`.

## Step 4: Прогнать `enemies` — PASS (с регрессией)
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies` → PASS.
Затем полный сьют `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1` → 0 failed.

## TDD Evidence (в отчёте)
RED (изменённая секция под новый контракт падает на старом коде: смерть без GameState/без вызова return_to_lobby) → GREEN → мутация (например, временно вернуть `_respawn(true)` вместо вызова `return_to_lobby` при живом GameState → секция краснеет). Команды + выводы.

## Инварианты проекта (не ломать)
- Падение за карту — респавн на месте без восстановления здоровья (не менять).
- `died.emit()` — строго один раз за смерть и ДО респавна/перехода.
- Враговые данные/сцены не менять (кроме начисления очков при смерти).
- Очки НЕ теряются при смерти (только начисляются).
- Существующие сьюты movement/weapon/projectile/auto_weapon остаются зелёными.