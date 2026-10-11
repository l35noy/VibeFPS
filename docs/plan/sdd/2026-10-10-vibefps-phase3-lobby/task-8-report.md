# Task 8 — отчёт: ручная перезарядка (R) + старт с 300 очков

**Статус:** DONE (не закоммичено — коммитит владелец).
**Дата:** 2026-10-10
**Бриф:** `C:\Users\serhio\.opencode\plan\sdd\2026-10-10-vibefps-phase3-lobby\task-8-brief.md`

Две независимые по логике правки владельца в одной задаче: (A) убрать
автоперезарядку, перезарядка по физической R; (B) старт с 300 очков.
TDD: сначала красный на новое поведение, затем зелёный.

## Что сделано

### A. Ручная перезарядка (R)

- **`project.godot`** — добавлено действие `reload`: `deadzone 0.5`, одно
  событие `InputEventKey` с `keycode = 0` и `physical_keycode = 82` (физическая
  R, `unicode = 114`), той же кодировкой, что остальные layout-independent
  биндинги (`move_*`, `jump`, `pause`, `interact`).
- **`scripts/pistol.gd`**
  - Удалён шаг 4 `_process` (автоперезарядка при пустом магазине).
  - Добавлен `_unhandled_input(event)`: `event.is_action_pressed("reload")` при
    разрешённом игровом вводе (`InputGate.is_play_input_allowed(
    _mouse_mode_for_play_input())`) → `start_reload()`.
  - `start_reload()` не менялся (отказ на полном магазине, запрет перезапуска).
  - Решение №6 в шапке переписано: перезарядку инициирует игрок клавишей R, а
    не пустой магазин; гейт тот же, что у огня.
- **`tests/weapon.gd`**
  - `_test_empty_magazine_and_automatic_reload` переписан в
    `_test_empty_magazine_and_manual_reload` (вызов в `_initialize` обновлён),
    шапка-комментарий и `print` приведены к новому контракту.
  - Новый контракт: после опустошения магазина нажатая кнопка огня отпускается,
    пистолет наблюдается 1.5×`reload_time` — `reload_started == 0`, не
    перезаряжается, магазин пуст (пустой магазин сам НЕ перезаряжается).
  - Добавлена проверка гейта: при `gate_mouse_mode = VISIBLE` разобранное
    событие физической R не запускает перезарядку; после `CAPTURED` то же
    событие запускает ровно один раз.
  - Сохранены проверки: блокировка огня во время перезарядки, длительность
    ~1.2 с, полный магазин после, отсутствие залипшего кулдауна. Добавлен
    хелпер `_reload_key_event(pressed)`.
  - Остальные сценарии перезарядки (`_test_reload_blocks_firing_and_cannot_be_restarted`,
    `_test_full_magazine_has_nothing_to_reload`, `_test_scene_change_reset`) не
    тронуты — они зовут `start_reload()` напрямую.
- **`tests/input_actions.gd`** — добавлены ассерты: действие `reload`
  существует; ≥1 событие; событие — `InputEventKey` с `physical_keycode == 82`;
  `keycode == 0` (только физический код → раскладко-независимо).

### B. Старт с 300 очков

- **`scripts/game_state.gd`** — `const STARTING_POINTS := 300` (с комментарием о
  временном балансе) и `var points: int = STARTING_POINTS`.
- **`tests/progression.gd`**
  - `_test_initial_state`: ожидается `GameState.STARTING_POINTS`.
  - `_test_award_points`: `STARTING_POINTS + 10` после начисления (старт 300).
  - `_test_afford`: граница доступности выставлена явно (`points = 299` → не
    хватает, `points = 310` → хватает) вместо «300 не хватает на 300».
  - `_test_buy_weapon` не тронут: явная подготовка 310 → списание 300 → 10
    теперь обеспечивается `_test_afford` (осталась прежняя арифметика 310→10).
  - Round-trip: ожидается `STARTING_POINTS + 50`; шапка файла обновлена
    (раньше «brief fixes 50», теперь значение выводится из старта).
- **`tests/interact.gd`** — в `_test_shop_purchase` и `_test_input_gate` очки
  выставляются явно в 0 (подготовка), чтобы смысл «не может позволить» /
  «ничего не списано» сохранился при старте 300. Точечные `points == 0`
  остались корректными.
- **`tests/enemies.gd`** — `_test_kill_awards_points`: старт проверяется как
  `STARTING_POINTS`; после убийства `STARTING_POINTS + POINTS_PER_KILL` и
  `STARTING_POINTS + 10`; повторный урон по мёртвому — без изменения.
- **`tests/save.gd`** — проверен: конструирует payload явно (`points: 42`), от
  GameState не зависит. Не тронут.
- **`tests/auto_weapon.gd`** — проверен: автоперезарядка/очки не используются
  (магазин 36, интервал 0.2, только `try_fire`). Не тронут.

## Доказательство красный → зелёный

**Красный** (тесты изменены, реализация ещё старая) — полный сьют:

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1
input_actions  FAIL  (exit code 1)
    [FAIL] action reload exists
    [FAIL] action reload has at least one event
    [FAIL] reload is bound to physical R (82)
    [FAIL] reload uses the physical key code only, so it is layout independent
weapon         FAIL  (exit code 1)
    [FAIL] an empty magazine does NOT start a reload on its own (got 1 reloads)
    [FAIL] the magazine is still empty (got 18)
    [FAIL] R with a free cursor does not start a reload (got 1 reloads)
    [FAIL] the pistol reports itself reloading
    [FAIL] a held fire button spends no rounds while the magazine is empty (got 19)
    [FAIL] the magazine is full again (got 17)
    [FAIL] magazine_changed announced the refilled magazine
enemies        FAIL  (exit code 1)
    SCRIPT ERROR: Parse Error: Cannot find member "STARTING_POINTS" in base "GameState".
progression    FAIL  (exit code 1)
    SCRIPT ERROR: Parse Error: Cannot find member "STARTING_POINTS" in base "GameState".
RESULT: 9 passed, 4 failed, 1 skipped
```

Красный именно на новом поведении: пустой магазин всё ещё перезаряжался сам
(`got 1 reloads`), действия `reload` нет, `STARTING_POINTS` не существует.
`interact` в красном прогоне был PASS — его правка чисто подготовительная
(явное выставление очков), нового наблюдаемого поведения не вводит.

**Зелёный** (после `project.godot`, `pistol.gd`, `game_state.gd`) — полный сьют:

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

RESULT: 13 passed, 0 failed, 1 skipped
```

**Отдельные прогоны (как требует бриф):**

```
run_checks.ps1 weapon       → RESULT: 3 passed, 0 failed, 0 skipped
                              (weapon_data, weapon, auto_weapon — подстрока)
run_checks.ps1 input_actions→ RESULT: 1 passed, 0 failed, 0 skipped
run_checks.ps1 progression  → RESULT: 1 passed, 0 failed, 0 skipped
run_checks.ps1 interact     → RESULT: 1 passed, 0 failed, 0 skipped
run_checks.ps1 enemies      → RESULT: 1 passed, 0 failed, 0 skipped
run_checks.ps1 auto_weapon  → RESULT: 1 passed, 0 failed, 0 skipped
```

## Инварианты

- `range.tscn` / `range_scene.gd` не менялись.
- Прямого `change_scene_to_file` вне `GameState` нет (grep по `scripts/`:
  только `game_state.gd`).
- Автосейв/восстановление роунд-трипят как прежде (`progression` PASS).
- Изменены только 8 разрешённых файлов; `CHECKLIST.md`, `player.gd`,
  `tests/integrity.gd` в рабочем дереве изменены ДО этой задачи (чужой
  незакоммиченный WIP) — не трогались.

## Оставшиеся неопределённости

- **`_unhandled_input` vs `_process`.** Бриф отдавал предпочтение опросу
  `is_action_just_pressed` в `_process`, но разрешал `_unhandled_input`.
  Выбран `_unhandled_input`: в headless разобранное событие доставляется
  синхронно и детерминированно (тот же приём, что у `interact` в `player.gd` и
  в `tests/interact.gd`), тогда как `Input.action_press` не доставляет край
  нажатия в `_unhandled_input`, а `is_action_just_pressed` в `_process` зависит
  от счётчика кадров движка. Гейт `InputGate` сохранён и обязателен.
- **`interact` не был красным** — его адаптация под старт 300 сводится к явной
  подготовке (очки = 0) и не вводит нового наблюдаемого контракта. Проверки
  остались теми же по смыслу.
- **`points == 0` в `tests/interact.gd` (`_test_input_gate`)** остаются слабыми
  по своей природе (нулевой баланс не отличит «списал 0» от «ничего не
  списывал»); оставлены как есть по R10 — смысл проверок не менялся, добавлена
  только явная подготовка. Если ревью захочет усилить, можно выставить
  ненулевой баланс и проверять неизменность, но это уже смена смысла.
- **`weapon` подстрочный фильтр** захватывает также `weapon_data` и
  `auto_weapon` — все зелёные.
