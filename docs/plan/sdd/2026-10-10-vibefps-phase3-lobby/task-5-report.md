# Task 5 Report: Смерть → лобби + очки за убийство (трек A)

**Status:** DONE
**Date:** 2026-10-10
**Project:** VibeFPS (Godot 4.7.2 stable, GDScript, Jolt)

## What I implemented

### 1. `player.gd` — смена контракта смерти (fallback-safe)
`take_damage()` при летальном уроне больше не делает безусловный `_respawn(true)`.
После `died.emit()`:
```gdscript
var gs := get_node_or_null("/root/GameState") as GameState
if gs != null:
    gs.return_to_lobby("death")
else:
    _respawn(true)  # fallback: headless-проверки и сцены без автозагрузки
```
- `died.emit()` остаётся строго один раз и **до** перехода/респавна.
- Сцена без `/root/GameState` (headless, сцены без автозагрузки) сохраняет прежний
  контракт — респавн на месте с восстановлением здоровья.
- Ветка падения за карту (`_physics_process` → `_respawn()` без флага) **не тронута**.
- Каст `as GameState` вместо голого Variant — по образцу `scripts/door_point.gd` и
  `scripts/shop_point.gd` (единственный существующий паттерн доступа к GameState);
  так вызов не является динамическим обращением к неизвестному члену `Node`.
- Обновлён doc-комментарий `_respawn(restore_health)` (флаг теперь принадлежит только
  fallback-ветке; поведение не изменилось).
- Комментарий на русском о контракте Фазы 3 и fallback для тестов добавлен.

### 2. `scripts/enemy_contact.gd` — очки за убийство
В `_die()` (единственное место смерти врага, вызывается ровно один раз — защищено
`is_alive()` в `take_damage` и `_dying` в контактных обработчиках), после `died.emit()`:
```gdscript
var gs := get_node_or_null("/root/GameState") as GameState
if gs != null:
    gs.award_points(int(gs.POINTS_PER_KILL))
```
- Null-safe, однократно. Без GameState враг умирает как прежде, очки не считаются.
- Враговые данные/сцены не менялись.

### 3. `tests/enemies.gd` — регрессия и новые секции
- Новая инфраструктура (Phase 3 Task 5): внутренний класс `_RecordingGameState
  extends GameState` (записывает `reason` в `return_to_lobby`, вызывает `super`),
  переменные `_probe_game_state` / `_lobby_changes`, fake `_fake_scene_changer`,
  хелперы `_install_probe_game_state()` / `_remove_probe_game_state()` /
  `_packed_strings_eq()`.
- Новая секция `_test_death_returns_to_lobby()`: с живым `/root/GameState` смерть
  вызывает `return_to_lobby("death")` (проверены **reason** и путь
  `res://lobby.tscn`), а `_respawn` **не вызывался** (наблюдаемый след: здоровье
  осталось 0.0, игрок остался мёртв). После секции пробный GameState убран из root.
- Новая секция `_test_kill_awards_points()`: мир с врагом + игроком + GameState,
  убийство врага → `points == POINTS_PER_KILL == 10`, повторный урон по мёртвому
  врагу не начисляет второй раз.
- Существующая секция fallback: `_test_player_health()` получила прекондишен
  «в `/root` нет GameState», заголовок смерти переименован в
  «смерть и немедленный респавн (fallback без GameState)»; прежние ассерты
  (здоровье восстановлено до 100.0, игрок снова жив) сохранены.
- «Падение за карту не лечит» в этом файле отсутствует (оно живёт в
  `tests/integrity.gd::_test_fall_recovery` и не менялось) — не трогал.

## TDD Evidence

### RED (сначала — тесты, старый код)
Команда: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies`
Вывод (ключевое):
```
enemies        FAIL  (exit code 1)
    === RESULT: 180 checks, 7 failed ===
      [FAIL] смерть возвращает в лобби с причиной "death" (получено [])
      [FAIL] смерть просит у scene_changer ровно res://lobby.tscn (получено [])
      [FAIL] смерть НЕ респавнит на месте: здоровье остаётся 0.0, а не max_health (got 100.0000, max_health 100.0000)
      [FAIL] смерть НЕ респавнит на месте: игрок остаётся мёртвым
      [FAIL] убийство врага начисляет ровно POINTS_PER_KILL очков (points 0, POINTS_PER_KILL 10)
      [FAIL] очков ровно 10 (got 0)
      [FAIL] урон по мёртвому врагу не начисляет очки повторно (got 0)
RESULT: 0 passed, 1 failed, 0 skipped
```
Ровно 7 новых ассертов красные (4 смерть → лобби, 3 очки); остальные 173 зелёные.

### GREEN (после правки player.gd + enemy_contact.gd)
```
importing project (class cache missing or stale) ...
enemies        PASS
RESULT: 1 passed, 0 failed, 0 skipped
```

### Мутация A — при живом GameState вернуть `_respawn(true)` вместо `return_to_lobby`
Временно: `if gs != null: _respawn(true)  # MUTATION`.
```
enemies        FAIL  (exit code 1)
    === RESULT: 180 checks, 4 failed ===
      FAILURE: смерть возвращает в лобби с причиной "death" (получено [])
      FAILURE: смерть просит у scene_changer ровно res://lobby.tscn (получено [])
      FAILURE: смерть НЕ респавнит на месте: здоровье остаётся 0.0, а не max_health (got 100.0000, max_health 100.0000)
      FAILURE: смерть НЕ респавнит на месте: игрок остаётся мёртвым
RESULT: 0 passed, 1 failed, 0 skipped
```
Покраснели ровно 4 ассерта секции смерти. Откат возвращён к оригиналу.

### Мутация B — убрать начисление очков в `_die()`
Временно: `if gs != null: pass  # MUTATION`.
```
enemies        FAIL  (exit code 1)
    === RESULT: 180 checks, 3 failed ===
      FAILURE: убийство врага начисляет ровно POINTS_PER_KILL очков (points 0, POINTS_PER_KILL 10)
      FAILURE: очков ровно 10 (got 0)
      FAILURE: урон по мёртвому врагу не начисляет очки повторно (got 0)
RESULT: 0 passed, 1 failed, 0 skipped
```
Покраснели ровно 3 ассерта секции очков. Откат возвращён к оригиналу.

### Восстановление после мутаций
```
enemies        PASS
RESULT: 1 passed, 0 failed, 0 skipped
```

### Полный сьют (один раз, в конце)
Команда: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1`
```
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

## Files changed

| File | Change |
|------|--------|
| `player.gd` | `take_damage`: death branch → `return_to_lobby("death")` / fallback `_respawn(true)`; комментарий контракта; правка doc-комментария `_respawn`. (Остальные показанные в `git diff` правки — `_INTERACT_RANGE`/`_try_interact`/`nearest_interactable` — чужие, Task 4, не тронуты.) |
| `scripts/enemy_contact.gd` | `_die()`: начисление `award_points(POINTS_PER_KILL)` под null-safe GameState. (Правки комментариев вверху файла — DOC-CLEANUP, не тронуты.) |
| `tests/enemies.gd` | Новая инфраструктура + 2 секции + прекондишен fallback |
| `.uid` | Не генерировались (пути существующих скриптов не менялись; `git status` новых `player.gd.uid` / `enemy_contact.gd.uid` / `enemies.gd.uid` не показывает) |

### Изменённые строки `tests/enemies.gd`
Новые/изменённые регионы (итоговые номера строк в файле):

- **166–171** — новый класс `_RecordingGameState extends GameState` (запись `lobby_reasons`, вызов `super`).
- **177** — новый `var _probe_game_state: GameState = null`.
- **179** — новый `var _lobby_changes: PackedStringArray = []`.
- **183–184** — новый `_fake_scene_changer(path)`.
- **190–196** — новый `_install_probe_game_state()`.
- **201–205** — новый `_remove_probe_game_state()` (queue_free + await).
- **211–217** — новый хелпер `_packed_strings_eq()`.
- **377–380** — добавлен прекондишен в `_test_player_health()`: в `/root` нет GameState.
- **479** — переименован заголовок: «десятое попадание: смерть и немедленный респавн (fallback без GameState)».
- **545–600** — новая секция `_test_death_returns_to_lobby()` (7 ассертов).
- **602–665** — новая секция `_test_kill_awards_points()` (5 ассертов).
- **1987** — `await _test_death_returns_to_lobby()` добавлен в `_initialize()`.
- **1989** — `await _test_kill_awards_points()` добавлен в `_initialize()`.

## Self-review findings / Concerns

- **Инварианты проверены:** `died.emit()` один раз и до перехода; падение за карту не
  менялось; враговые данные/сцены не трогались; очки при смерти только начисляются
  (смерть игрока GameState.points не читает/не пишет); полный сьют зелёный, включая
  movement/weapon/projectile/auto_weapon/integrity.
- **Reason проверяется через подкласс, а не через `scene_changer`.** `return_to_lobby`
  не передаёт `reason` в `scene_changer` (GameState зовёт его только с путём сцены),
  поэтому «смерть просит лобби» и «смерть просит лобби по причине `death`» — разные
  утверждения. Чтобы выполнить требование брифа «проверить reason», `_RecordingGameState`
  переопределяет `return_to_lobby`, пишет reason и вызывает `super` (который идёт в
  подменённый `scene_changer`). Так проверяются обе вещи: reason == "death" и путь
  `res://lobby.tscn`. Без этого reason был бы непроверяем в принципе.
- **Нет утечки пробного GameState между секциями.** `_remove_probe_game_state()` делает
  `queue_free` + `await physics_frame`, после чего секция явно проверяет, что
  `/root/GameState` снова null. Это критично: fallback-секция смерти и проверки врага
  (`_test_contact_enemy`, `_test_enemy_contact_tick`) обязаны видеть пустой root.
- **`_test_player_health` намеренно оставлен fallback-секцией без GameState.** Его
  цикл «касаний до смерти» и «десятое попадание» опираются на fallback-респавн; новый
  контракт с GameState вынесен в отдельную функцию с собственным инстансом игрока,
  потому что с живым GameState игрок после смерти остаётся мёртв и не может продолжать
  предыдущую цепочку ассертов.
- **Сон на `super.return_to_lobby`:** реализация `GameState.return_to_lobby` имеет
  `@warning_ignore("unused_parameter")` — переопределение и `super`-вызов работают,
  предупреждений нет.
- **Путь к `player.gd`.** Бриф называет файл `scripts/player.gd`, фактически он лежит
  в корне проекта (`E:\projects\VibeFPS\player.gd`; `scripts/player.gd` не существует).
  Правил фактический файл.
