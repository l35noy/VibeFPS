# Task 9 — отчёт: откат старта 0, сигнал очков, HUD на персонаже

**Статус:** DONE (не закоммичено — коммитит владелец).
**Дата:** 2026-10-10
**Проект:** VibeFPS (Godot 4.7.2 stable, GDScript, Jolt)

> Примечание: файла брифа `task-9-brief.md` в каталоге плана нет
> (`C:\Users\serhio\.opencode\plan\sdd\2026-10-10-vibefps-phase3-lobby\`
> содержит брифы/отчёты только по задачи 1–8). Требования взяты из постановки
> задачи (сообщение субагенту), она воспроизведена дословно по пунктам ниже.

## Что сделано

### A. Старт 0 (откат Task 8) + временная выдача 300

- **`scripts/game_state.gd`**: удалена `const STARTING_POINTS := 300`, `points`
  снова `= 0`. Значение Task 8 откатано полностью.
- **Откат правок Task 8 «под 300» в тестах** (смысл возвращён к нулевому старту):
  - `tests/progression.gd`: `_test_initial_state` — снова `points start at 0`;
    `_test_award_points` — `10`; `_test_afford` — снова
    `300 cannot afford` / `award_points(300)` / `affordable`; round-trip —
    снова `== 50`. Шапка файла приведена к прежнему смыслу.
  - `tests/interact.gd`: убраны подстановки `_gs.points = 0` из
    `_test_shop_purchase` / `_test_input_gate`; прежние `points == 0` снова
    опираются на нулевой старт.
  - `tests/enemies.gd`: `_test_kill_awards_points` — снова `счёт начинается с
    нуля`, `очков ровно 10`, и «урон по мёртвому не начисляет повторно» = `10`.
  - Эти три файла после отката **побайтово совпадают с HEAD** (`git diff` по ним
    пуст) — правок Task 8, кроме 300-связанных, в них не было.
- **Ручная перезарядка Task 8 НЕ откатывалась**: `tests/weapon.gd` и
  `tests/input_actions.gd`, `project.godot` (действие `reload`),
  `scripts/pistol.gd` не трогались.
- **Временная выдача 300** (`scripts/game_state.gd`, явно помечена
  `# TEMP(dev...)`):
  - `const _TEMP_DEV_STARTING_POINTS := 300`, флаг `_temp_dev_grant_done`;
  - `_apply_temp_dev_starting_points()` вызывается из `_ready()` после
    восстановления сейва, выдаёт **один раз за сессию**;
  - гейт `DisplayServer.get_name() == "headless"` → в headless-прогоне выдача
    не срабатывает: класс-дефолт остаётся 0, тесты не затронуты, автосейв не
    зовётся и `user://save.json` не создаётся;
  - `points` не понижается: если восстановленный сейв уже `>= 300`, выдача
    ничего не меняет (`max`-семантика);
  - выдача испускает `points_changed`, т.к. это изменение `points`.
  - Автосейв при выдаче намеренно НЕ вызывается: минимум побочных эффектов.

### B. Сигнал очков

- **`scripts/game_state.gd`**: `signal points_changed(points: int)`, эмитится
  при любом изменении `points` — в `award_points()`, `buy_weapon()` (после
  списания), `_restore()` (при восстановлении из сейва) и в TEMP-выдаче.
  Автосейв не менялся (`_autosave()` как был).

### C. HUD на персонаже

- **Новые `ui.tscn` + `scripts/ui.gd`** (`CanvasLayer`), прикреплены ребёнком к
  `player.tscn` (узел `UI`, `instance=ExtResource("5_ui")`; `load_steps` 6→7).
  Элементы:
  - слева внизу — `HealthLabel` (`HP N%`) и `HealthBar` (`ProgressBar`);
  - справа внизу — `AmmoLabel` (число патронов);
  - справа вверху — `PointsLabel` (число очков).
- Источники — сигналы: здоровье `player.health_changed`, патроны
  `weapon.magazine_changed`, очки `GameState.points_changed`.
- **Тестируемость**: метод `bind(player, weapon, game_state)` отделён от
  `_ready()` (которая вычисляет источники из окружения) и вызывается из неё;
  тест впрыскивает фейки. Повторный `bind()` снимает прежние подписки.
  Null-safe через `has_signal`/`has_method`/`is_instance_valid`: нет игрока,
  оружия или GameState — HUD молчит и не падает.
- **Интерфейс под Task 10** (`player.gd`): `signal weapon_changed(weapon: Node)`,
  эмитится при готовности игрока, и accessor `current_weapon() -> Node`. HUD
  пере-привязывает счётчик патронов по `weapon_changed`. Сам своп оружия
  (Task 10) не делался.
- **Стартовое состояние HUD**: `player.gd::_ready()` теперь испускает
  `health_changed` и `weapon_changed` после установки состояния. Это нужно,
  потому что HUD — ребёнок и его `_ready()` выполняется раньше родителя
  (жизнеспособность без пустого первого кадра). Проверено, что это не ломает
  `tests/enemies.gd` (там `health_changed` подключается уже после спавна, а
  `died`-контракт не задет).

## TDD: красный → зелёный

**Красный** (написан `tests/ui.gd`, `ui` добавлен в `$Tests`, `ui.tscn` ещё нет):

```
run_checks.ps1 ui
ui             FAIL  (exit code 1)
    -- ui.tscn contract
      [FAIL] res://ui.tscn loads
    -- player.tscn wiring: the HUD rides the player and starts filled
      [PASS] player.gd exposes current_weapon()
      [PASS] player.gd exposes the weapon_changed signal
      [PASS] current_weapon() answers with the Pistol node (got Pistol)
      [PASS] weapon_changed fired once with the pistol on ready (got 1 events)
      [FAIL] player.tscn carries a UI CanvasLayer child
    === RESULT: 7 checks, 2 failed ===
```

**Зелёный** (после `ui.tscn`, `scripts/ui.gd`, `player.tscn`, `player.gd`):

```
run_checks.ps1 ui
ui             PASS
RESULT: 1 passed, 0 failed, 0 skipped
```

## Проверки

Единственная санкционированная проверка — `tools\run_checks.ps1`. Godot
напрямую не запускался.

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1
smoke          PASS
movement       PASS
input_actions  PASS
input_gate     PASS
weapon_data    PASS
integrity      PASS
weapon         PASS
auto_weapon    PASS
projectile     PASS
enemies        PASS
waves          [SKIP]  (tests\waves.gd not present)
save           PASS
progression    PASS
interact       PASS
ui             PASS

RESULT: 14 passed, 0 failed, 1 skipped
```

**`user://save.json` в тест-прогоне НЕ создаётся.** У владельца файл уже
существовал (`C:\Users\serhio\AppData\Roaming\Godot\app_userdata\VibeFPS\save.json`),
поэтому «не создан» доказывалось явно: файл временно убран в сторону, прогнан
полный сьют, наличие проверено (`NOT CREATED (OK)`), затем оригинал возвращён
на место. Восстановление подтверждено.

**`ui` добавлен в `$Tests`** `tools/run_checks.ps1` (15-й элемент, подстрока
`ui` не пересекается с другими именами). Отдельный прогон `run_checks.ps1 ui`
даёт `1 passed, 0 failed, 0 skipped`.

## Инварианты

- `range.tscn` / `range_scene.gd` не менялись.
- Прямого `change_scene_to_file` вне `GameState` не добавлено (новый код
  смены сцены не трогал; `ui.gd`/`player.gd` его не вызывают).
- Автосейв/восстановление роунд-трипят как прежде (`progression`, `save` PASS).
- Изменены только разрешённые файлы. `project.godot`, `scripts/pistol.gd`,
  `tests/input_actions.gd`, `tests/weapon.gd`, `tests/integrity.gd` были
  модифицированы ДО этой задачи (Task 8 + WIP владельца) — не трогались.

## Файлы

- Modify: `scripts/game_state.gd`, `player.gd`, `player.tscn`,
  `tests/progression.gd`, `tests/interact.gd`, `tests/enemies.gd`,
  `tools/run_checks.ps1`, `CHECKLIST.md`.
- New: `ui.tscn`, `scripts/ui.gd` (+ `.uid`), `tests/ui.gd` (+ `.uid`).
- `tests/progression.gd`, `tests/interact.gd`, `tests/enemies.gd` после отката
  совпадают с HEAD.

## Оставшиеся неопределённости / замечания

- **Бриф-файла нет** — требования взяты из постановки задачи (см. врезку
  сверху). Если файл появится позже, стоит сверить нумерацию строк
  `tests/interact.gd` (в постановке `:310,:316,:327,:379,:404`) — откат
  выполнен по фактическому `git diff`, а не по номерам строк.
- **Временная выдача 300 не наблюдается автопроверками** by design: она
  отключена в headless. Это dev-удобство владельца; проверка возможна только
  запуском игры. Блок помечен `# TEMP(dev...)` и убирается отдельной задачей.
- **HUD перезарядку не показывает** — только число патронов. Пункт чеклиста
  «Отображать состояние магазина и перезарядки оружия» оставлен открытым
  (см. `CHECKLIST.md` §4A).
- **Оговорка §3B остаётся**: в fallback-ветке (без `/root/GameState`) респавн
  испускает `0/100` и `100/100` в одном кадре, поэтому полоса смерти 0 не
  покажет. Экран смерти (отдельная задача) обязан учитывать порядок; в проде
  смерть уходит в лобби через GameState, и здоровье остаётся 0.
- **`points_changed` при `equip_weapon`** не эмитится: очки не меняются
  (экипировка уже купленного бесплатна) — это осознанно.
