# Task 7 — отчёт: падение с высоты = смерть → лобби

**Статус:** DONE (не закоммичено — коммитит владелец).
**Дата:** 2026-10-10
**Бриф:** `C:\Users\serhio\.opencode\plan\sdd\2026-10-10-vibefps-phase3-lobby\task-7-brief.md`

## Что сделано

### R7.1 `player.gd`
- Выделен единый переход смерти `_die(reason: String)`: испускает `died` ровно
  один раз, затем `/root/GameState` → `gs.return_to_lobby(reason)`, иначе
  fallback `_respawn(true)`.
- `take_damage` при обнулении здоровья зовёт `_die("death")`; поведение Task 5
  сохранено без изменений (здоровье уже 0, `health_changed(0, max)` испущен до
  `died`).
- Ветка падения в `_physics_process`: при `global_position.y < fall_limit` и
  `is_alive()` игрок получает `_health = 0.0`, испускает
  `health_changed(0, max)`, затем `_die("fall")`.
- **Гейт «ровно один раз»:** вход в ветку падения защищён `is_alive()`. Если
  `scene_changer` подменён заглушкой и сцена не меняется, игрок остаётся ниже
  `fall_limit`, но со нулевым здоровьем — ветка больше не заходит, `died` и
  `return_to_lobby` не повторяются. Если GameState нет, fallback вытаскивает
  игрока на точку появления (выше `fall_limit`) и восстанавливает здоровье.
- Обновлён устаревший комментарий `_respawn`: тезис «падение за карту здоровье
  не восстанавливает» заменён на «падение = смерть; `_respawn` — только
  fallback без GameState». Сигнатура `_respawn(restore_health)` сохранена.

### R7.2 `tests/integrity.gd` (TDD)
- Добавлен `_RecordingGameState extends GameState` (образец —
  `tests/enemies.gd:166-173`): пишет `lobby_reasons` и зовёт подменённый
  `_fake_scene_changer`, который ничего не меняет.
- Добавлен `_drop_autoloads()` (R13): движок ставит `GameState`/`SaveSystem`
  под `/root` даже в `--script`-режиме; без снятия автозагрузок настоящий
  `GameState` заслонил бы заглушку и сменил бы сцену на `lobby.tscn`.
- `_test_fall_recovery` переписан под новый контракт:
  - с заглушкой GameState падение в пустоту `(0,5,40)` просит
    `return_to_lobby("fall")` **ровно один раз** и `res://lobby.tscn` через
    `scene_changer` ровно один раз;
  - `died` **ровно один раз**, в момент сигнала `is_alive() == false` и
    здоровье `0.0`;
  - после гейта игрок проверяется как оставшийся ниже kill-plane (заглушка
    сцену не меняет) и мёртвый — дополнительные 60 кадров падения не дают
    второго вызова;
  - fallback-половина (после снятия заглушки, без `/root/GameState`):
    падение возвращает игрока на точку появления, живого, на полу,
    `died` ровно один раз — сохранён смысл «игрок не падает вечно».
- `_test_kill_plane_quiet_on_edge_fall` не тронут: обычное падение на ~3 м с
  края (выше kill-plane) остаётся обычным падением.

### R7.3 `CHECKLIST.md`
- Раздел 3B (≈ 224-242): запись «Смерть лечит, падение за карту — нет»
  заменена на «Падение за kill-plane — смерть, обычное падение — нет» и
  «Смерть и падение уходят из игры одним переходом» (`_die`, GameState,
  fallback). Оговорка для Фазы 5 уточнена: `0/100 → 100/100` в одном кадре
  теперь только fallback-ветка, в проде смерть в лобби здоровье не
  восстанавливает.
- Раздел «Инварианты» (≈ 640): «игрок никогда не выпадает из мира и всегда
  восстанавливается на точке старта» заменено на «падение за kill-plane —
  смерть → лобби через GameState; без GameState — fallback-респавн, поэтому
  игрок не падает бесконечно».
- `docs/superpowers/*` и отчёты SDD не тронуты.

## Доказательство красный → зелёный

**Красный.** `tests/integrity.gd` (новый) прогнан против ОРИГИНАЛЬНОГО
`player.gd` (новая логика временно снята через `git stash push -- player.gd`,
после прогона восстановлена `git stash pop`):

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 integrity
integrity      FAIL  (exit code 1)
...
[FAIL] падение за kill-plane просит возврат в лобби (y=0.00, kill plane -50.0)
[FAIL] падение возвращает в лобби с причиной "fall" (получено [])
[FAIL] падение просит у scene_changer ровно res://lobby.tscn (получено [])
[FAIL] падение испускает died ровно один раз (got 0)
...
[FAIL] fallback: падение испускает died ровно один раз (got 0)
=== RESULT: 35 checks, 11 failed, 0 warnings ===
RESULT: 0 passed, 1 failed, 0 skipped
```

Старое поведение (`_respawn()` без лечения) телепортировало игрока из-под
kill-plane, поэтому `return_to_lobby`/`died` не вызывались — новые ассерты
покраснели именно на отсутствии нового пути смерти. Негативная половина
(`_test_kill_plane_quiet_on_edge_fall`) прошла и в красном прогоне —
подтверждает, что падение на 3 м и раньше не считалось смертью.

**Зелёный.** После восстановления нового `player.gd`:

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 integrity
integrity      PASS
RESULT: 1 passed, 0 failed, 0 skipped
```

**Полный сьют (финальное состояние всех трёх файлов):**

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

`enemies` (смерть от урона → лобби, Task 5) и `movement` остались зелёными;
`waves` — `[SKIP]`, как и ожидалось.

## Инварианты

- `range.tscn` / `range_scene.gd` не менялись.
- Обычное падение с края (в пределах kill-plane) смертью не считается.
- Игрок не падает вечно: без GameState срабатывает fallback-респавн.
- Прямого `change_scene_to_file` в игровых сценах нет — только GameState.

## Оставшиеся неопределённости

- `_respawn(restore_health = false)` (чистый сброс положения без лечения)
  больше не вызывается из игрового кода: единственный вызов — `_die` с
  `true`. Форма сохранена по требованию брифа как запасная механика; если
  ревью решит, что мёртвая ветка вредна, флаг можно удалить, оставив
  `_respawn()` с восстановлением.
- Оговорка Фазы 5 (HUD «сначала полоса, потом fallback-респавн») остаётся
  открытой: в проде смерть в лобби здоровье не восстанавливает, но headless
  fallback по-прежнему испускает `0/100 → 100/100` в одном кадре.
