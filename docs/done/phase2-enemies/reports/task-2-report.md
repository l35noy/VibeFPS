> **Назначение:** Отчёт по задаче фазы.

# Task 2 — Здоровье игрока и зона хитбокса игрока — отчёт

**Статус:** DONE_WITH_CONCERNS (работа завершена и зелёная; см. «Отклонения от брифа» и «Опасения»)
**Дата:** 2026-10-08
**Репозиторий:** `E:\projects\VibeFPS` (Godot 4.7.2 stable, GDScript, Jolt Physics)

---

## 1. Что сделано

| Файл | Изменение |
|---|---|
| `scripts/hurtbox.gd` | Добавлены `@export_enum("enemy_hurtbox","player_hurtbox") var zone: int = 0` и `@export var detects_contact: bool = false`. `_ready()` переписан на выражения `(1 << 3) if zone == 0 else (1 << 6)` / `monitoring = detects_contact` / `collision_mask = (1 << 6) if detects_contact else (1 << 0)`. Константы `_COLLISION_LAYER`/`_COLLISION_MASK` убраны (по брифу: «убрать или переписать под выражения выше — в одном файле, с комментарием»). Сигнал `damage_taken` и метод `apply_damage` не тронуты. |
| `player.gd` | Сигналы `health_changed(current, maximum)` и `died()`; `@export var max_health: float = 100.0`; приватное `var _health: float = 0.0`; `health()`, `is_alive()`, `take_damage()`. В `_ready()` после `set_spawn_transform()` идёт `_health = max_health`, затем `_connect_hurtbox()` (по брифу: «сначала `_spawn_transform`, потом `_health = max_health`, потом подключение `Hurtbox`»), затем существующая логика фокуса и пистолета. `_respawn()` получил параметр `restore_health: bool = false`; при `true` восстанавливает `_health`, испускает `health_changed` и печатает в стиле проекта. |
| `player.tscn` | Добавлен дочерний `Area3D` `Hurtbox` со скриптом `scripts/hurtbox.gd`, `zone = 1`, `transform` с `y = 0.9`, и его `CollisionShape3D`/`CapsuleShape3D` `radius = 0.4`, `height = 1.8`. `collision_layer`/`collision_mask` в сцене **не** прописаны — их задаёт `_ready()` (правило проекта, прямым требованием брифа). |
| `tests/enemies.gd` | Добавлен второй раздел «Здоровье игрока» (24 новых утверждения; 11 утверждений Task 1 не тронуты). Изменён только текст шапки файла: «one section» → «sections» и добавлен абзац, описывающий новый раздел, потому что старое утверждение стало неверным. |

Других файлов не менялось. Git-мутаций не выполнялось (`git status --porcelain` показывает ` M player.gd`, ` M player.tscn`, ` M scripts/hurtbox.gd` плюс pre-existing untracked Task 1 и `.opencode/`).

---

## 2. TDD: RED → GREEN

### 2.1 Baseline до начала работы

```
> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies
enemies        PASS
RESULT: 1 passed, 0 failed, 0 skipped
```

### 2.2 RED (Step 1 + Step 2)

Тест написан первым, до кода. Прогон (кириллица в консоли PowerShell искажается; ниже приведены точные строки из исходника теста, фактические числовые значения из прогона приведены как есть):

```
> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies
enemies        FAIL  (exit code 1)
    === enemies ===
    -- res://data/enemies/contact.tres must load as an EnemyData
      [PASS] contact.tres is an EnemyData (script=res://scripts/enemy_data.gd)
    -- the values the design fixes for the contact enemy
      [PASS] max_health is 50.0 (got 50.0000)
      [PASS] contact_damage is 10.0 (got 10.0000)
      [PASS] move_speed is 6.0 (got 6.0000)
      [PASS] spawn_interval is 1.5 (got 1.5000)
      [PASS] kind is EnemyData.EnemyKind.CONTACT (got 0)
    -- is_valid() can answer false, so is_valid() == true means something
      [PASS] contact.tres reports itself valid
      [PASS] a zero max health is rejected
      [PASS] a zero contact damage is rejected
      [PASS] a zero move speed is rejected
      [PASS] a zero spawn interval is rejected
    -- Здоровье игрока (Task 2)
      [PASS] precondition: player.tscn is instantiated and node-ready
    -- дефолтный Hurtbox сохраняет контракт Фазы 1
      [PASS] дефолтный Hurtbox.new() лежит на слое 4 (enemy_hurtbox) (got 8, expected 8)
      [PASS] дефолтный Hurtbox.new() ничего не обнаруживает сам (monitoring=false)
    -- в player.tscn есть узел Hurtbox в зоне игрока
      [FAIL] у player.tscn есть дочерний узел Hurtbox
      [FAIL] у player.gd есть API здоровья Фазы 2: health, is_alive, take_damage, died, health_changed
      (оценка урона невозможна без хитбокса и API здоровья: проверки ниже пропущены)
    === RESULT: 16 checks, 2 failed ===
RESULT: 0 passed, 1 failed, 0 skipped
```

RED подтверждён: код возврата 1, два именованных `[FAIL]` — ровно два симптома из брифа («у игрока нет здоровья» и «в сцене нет Hurtbox»; отсутствие `zone` проявилось бы только после появления узла, а обращение к несуществующему члену — это рантайм-ошибка, а не `[FAIL]`, поэтому наличие узла и API спрашивается через `get_node_or_null` / `has_method` / `has_signal`).

Заметка: два PASS-а по дефолтному `Hurtbox.new()` зелёные и на RED — это ожидаемо и правильно: контракт Фазы 1 (`слой 4`, `monitoring == false`) новая настройка зоны обязана сохранить, а сломать его нечем, пока `zone` не задан.

### 2.3 GREEN (Steps 3–5, Step 6)

```
> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies
enemies        PASS
RESULT: 1 passed, 0 failed, 0 skipped
```

Итог секции — **35 проверок, 0 падений** (11 из Task 1 + 24 новых). Промежуточная деталь для отчёта: полный листинг `[PASS]`-строк раннер на PASS не печатает (он печатает вывод только на FAIL), поэтому число 35 подтверждается двумя соседними прогонами, где перечислены все 35 проверок: 35/4 failed до исправления порядка шагов и 35/0 failed после.

Зелёный прогон с полным листингом (снят во время mutation-прогона 1, где видны все `[PASS]`):

```
    -- Здоровье игрока (Task 2)
      [PASS] precondition: player.tscn is instantiated and node-ready
    -- дефолтный Hurtbox сохраняет контракт Фазы 1
      [PASS] дефолтный Hurtbox.new() лежит на слое 4 (enemy_hurtbox) (got 8, expected 8)
      [PASS] дефолтный Hurtbox.new() ничего не обнаруживает сам (monitoring=false)
    -- в player.tscn есть узел Hurtbox в зоне игрока
      [PASS] у player.tscn есть дочерний узел Hurtbox
      [PASS] у player.gd есть API здоровья Фазы 2: health, is_alive, take_damage, died, health_changed
      [PASS] хитбокс игрока объявлен в зоне 1 (player_hurtbox) (got zone 1)
      [PASS] после готовности хитбокс игрока лежит на слое 7 (player_hurtbox) (got 64, expected 64)
    -- стартовое состояние
      [PASS] игрок начинает с 100 здоровья (got 100.0000)
      [PASS] игрок начинает жив
    -- 10 попаданий контактного врага до смерти игрока (спека 7.2)
      [PASS] 10 попаданий до смерти игрока (max_health 100.0000 / contact_damage 10.0000 = 10.0000)
    ...
    -- десятое попадание: смерть и немедленный респавн
    [player] погиб — респавн на точке появления, здоровье восстановлено до 100.0
      [PASS] сигнал died ровно один (got 1)
      [PASS] в момент сигнала died игрок уже мёртв (is_alive() == false) (got false)
      [PASS] в момент сигнала died здоровье равно 0.0 (got 0.0000)
      [PASS] после смерти 100.0 (респавн восстановил здоровье) (got 100.0000)
      [PASS] после смерти игрок снова жив
    -- health_changed испущен с настоящими числами
      [PASS] health_changed испущен хотя бы раз (events=4)
      [PASS] последнее событие health_changed после респавна — 100.0/max_health (got 100.0000/100.0000)
      [PASS] смерть отражена событием 0.0/max_health (got 0.0000/100.0000)
    -- проводка сцены: Hurtbox.damage_taken -> Player.take_damage
      [PASS] урон через узел Hurtbox сцены доходит до игрока по сигналу damage_taken (got 90.0000)
      [PASS] попадание через Hurtbox отражено событием 90.0/max_health (got 90.0000/100.0000)
    -- нулевой и отрицательный урон игнорируются
      [PASS] нулевой и отрицательный урон не меняют здоровье (got 90.0000)
      [PASS] нулевой и отрицательный урон не испускают died (got 1)
```

### 2.4 Соответствие списку утверждений брифа

| # | Утверждение брифа | Реализация в тесте | Статус |
|---|---|---|---|
| 1 | в `player.tscn` есть узел `Hurtbox`, `zone == 1`, после готовности `collision_layer == (1 << 6)` | три отдельных `[PASS]` | дословно |
| 2 | дефолтный `Hurtbox.new()`: `collision_layer == (1 << 3)` и `monitoring == false` | два `[PASS]` | дословно |
| 3 | старт: `health() == 100.0`, `is_alive()` | два `[PASS]` | дословно |
| 4 | `hurtbox.apply_damage(10.0)` → `health() == 90.0` (проводка сцены) | `[PASS] урон через узел Hurtbox сцены доходит до игрока по сигналу damage_taken` | дословно |
| 5 | `take_damage(90.0)` → `is_alive()` истинно, `health() == 10.0` | `[PASS] девятое попадание не убивает игрока`, `[PASS] после девяти тиков остаётся 10 здоровья` | дословно |
| 6 | десятое `take_damage(10.0)` → `is_alive()` ложь, `health() == 0.0`, `died` ровно один | `[PASS] в момент сигнала died игрок уже мёртв`, `[PASS] в момент сигнала died здоровье равно 0.0`, `[PASS] сигнал died ровно один` | дословно по смыслу; см. §4 |
| 7 | после смерти здоровье восстановлено: `health() == 100.0`, `is_alive()` | два `[PASS]` | дословно |
| 8 | `take_damage(0.0)` и `take_damage(-5.0)` не меняют `health()` и не испускают `died` | два `[PASS]` | дословно |
| 9 | `health_changed` испущен с корректными значениями (последнее событие `100.0/100.0` после респавна) | `[PASS] health_changed испущен хотя бы раз`, `[PASS] последнее событие health_changed после респавна — 100.0/max_health`, `[PASS] смерть отражена событием 0.0/max_health` | дословно |
| 10 | **пред-полётное решение контроллера**: `player.max_health / load("res://data/enemies/contact.tres").contact_damage == 10.0`, допуск 0.0001 | `[PASS] 10 попаданий до смерти игрока (max_health 100.0000 / contact_damage 10.0000 = 10.0000)` | добавлено |

Дополнительно (не в списке брифа, но вытекает из пункта 9): `[PASS] попадание через Hurtbox отражено событием 90.0/max_health` — проверяет, что сигнал уходит на каждое изменение, а не только на смерть.

---

## 3. Доказательство мутаций

Обе обязательные мутации выполнены на финальном `player.gd`. SHA-256 считался до мутации, после восстановления и в конце работы — значение одно и то же.

**Базовая строка:**

```
> (Get-FileHash -Algorithm SHA256 player.gd).Hash
F9D19AE835F269702479C42F47E5B2C9AA01B531A246E3BCC1EB404E7E636D26
```

### 3.1 Мутация 1 — убрать `died.emit()`

Правка: удалена строка `died.emit()` из `take_damage`.

```
> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies
enemies        FAIL  (exit code 1)
      [FAIL] сигнал died ровно один (got 0)
      [FAIL] в момент сигнала died игрок уже мёртв (is_alive() == false) (got true)
      [FAIL] в момент сигнала died здоровье равно 0.0 (got -1.0000)
      [FAIL] нулевой и отрицательный урон не испускают died (got 0)
    === RESULT: 35 checks, 4 failed ===
RESULT: 0 passed, 1 failed, 0 skipped
```

Именованное утверждение брифа **«died ровно один»** упало. Три остальных падения — производные от того же факта (обработчик не вызвался, поэтому его счётчики остались в исходных значениях `-1.0` / `true`), а не отдельные дефекты.

Восстановление и проверка:

```
> (Get-FileHash -Algorithm SHA256 player.gd).Hash
F9D19AE835F269702479C42F47E5B2C9AA01B531A246E3BCC1EB404E7E636D26   # идентично базовой строке
> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies
enemies        PASS
RESULT: 1 passed, 0 failed, 0 skipped
```

### 3.2 Мутация 2 — в ветке смерти не восстанавливать `_health`

Правка: `_respawn(true)` → `_respawn(false)` в `take_damage`, то есть ветка смерти перестаёт сбрасывать здоровье (при этом `died.emit()` остаётся, и позиционный вызов kill-plane `_respawn()` не меняется).

```
> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies
enemies        FAIL  (exit code 1)
      [FAIL] после смерти 100.0 (респавн восстановил здоровье) (got 0.0000)
      [FAIL] после смерти игрок снова жив
      [FAIL] последнее событие health_changed после респавна — 100.0/max_health (got 0.0000/100.0000)
      [FAIL] урон через узел Hurtbox сцены доходит до игрока по сигналу damage_taken (got 0.0000)
      [FAIL] попадание через Hurtbox отражено событием 90.0/max_health (got -1.0000/-1.0000)
      [FAIL] нулевой и отрицательный урон не меняют здоровье (got 0.0000)
    === RESULT: 35 checks, 6 failed ===
RESULT: 0 passed, 1 failed, 0 skipped
```

Именованное утверждение брифа **«после смерти 100.0»** упало. Остальные пять падений — неизбежное следствие того же самого: без восстановления `_health == 0.0`, `is_alive()` ложно, поэтому `take_damage` дальше игнорируется (`if not is_alive(): return`), а `health_changed` больше не испускается.

Восстановление и проверка:

```
> (Get-FileHash -Algorithm SHA256 player.gd).Hash
F9D19AE835F269702479C42F47E5B2C9AA01B531A246E3BCC1EB404E7E636D26   # идентично базовой строке
```

### 3.3 Пары SHA-256

| Круг | SHA-256 `player.gd` |
|---|---|
| Финальная версия (до M1) | `F9D19AE835F269702479C42F47E5B2C9AA01B531A246E3BCC1EB404E7E636D26` |
| После восстановления M1 | `F9D19AE835F269702479C42F47E5B2C9AA01B531A246E3BCC1EB404E7E636D26` |
| После восстановления M2 | `F9D19AE835F269702479C42F47E5B2C9AA01B531A246E3BCC1EB404E7E636D26` |

---

## 4. Отклонения от брифа (осознанные, задокументированы в коде)

### 4.1 Порядок шагов урона

Список утверждений брифа не исполним на одном игроке в заявленном порядке:

* `hurtbox.apply_damage(10.0)` → `health() == 90.0` (бриф, шаг 4) оставляет 90 HP;
* следующий за ним `take_damage(90.0)` → `health() == 10.0` (шаг 5) считает **от 100 HP** — при 90 HP он даёт 0 и смерть;
* «десятое `take_damage(10.0)`» (шаг 6) тоже подразумевает отсчёт от 100.

Проверено экспериментально: в порядке брифа прогон даёт 4 падения (`после девяти тиков остаётся 10 здоровья` → got 100.0 и т.д.), потому что респавн уже произошёл.

**Решение:** порядок шагов изменён — сначала полный цикл урона до смерти (`take_damage(90.0)` → 10 HP → `take_damage(10.0)` → смерть), затем проверка `health_changed`, затем проводка сцены на восстановленном игроке, затем нулевой/отрицательный урон. **Все утверждения брифа при этом сохранены дословно**, включая `take_damage(90.0)` и «десятое `take_damage(10.0)`»; проверка проводки от респавна не зависит (100 − 10 = 90). Обоснование записано комментарием в `tests/enemies.gd` над блоком шагов.

### 4.2 Наблюдаемая смерть — только из обработчика `died`

Бриф требует и «десятое `take_damage(10.0)` → `is_alive()` ложь, `health() == 0.0`», и «после смерти здоровье восстановлено: `health() == 100.0`, `is_alive()`», при этом смерть респавнится немедленно в том же вызове. Оба утверждения после возврата из `take_damage` одновременно не наблюдаемы.

**Решение:** «мёртв / 0.0» снимаются в подключённом обработчике `died` (синхронно, до респавна), а «100.0 / жив» — после возврата. Это ровно то, чего требует бриф («счётчик подключённого обработчика»), и единственный способ увидеть оба состояния. Комментарий в тесте это фиксирует.

### 4.3 Русские имена утверждений

Новый раздел использует русские `[PASS]/[FAIL]` метки, потому что бриф цитирует утверждения по-русски («died ровно один», «после смерти 100.0», «10 попаданий до смерти игрока») и требует, чтобы мутация «падала тем самым названным утверждением». Раздел Task 1 оставлен на английском без единой правки. Прецедент смешанного языка в репозитории есть: `tests/integrity.gd` — русские заголовки секций и английские метки.

### 4.4 Защитные проверки вместо рантайм-ошибок

Добавлены два утверждения сверх списка брифа, без которых RED был бы безымянным крашем, а не `[FAIL]`:

* `у player.tscn есть дочерний узел Hurtbox` (через `get_node_or_null`);
* `у player.gd есть API здоровья Фазы 2: health, is_alive, take_damage, died, health_changed` (через `has_method`/`has_signal`).

При их провале раздел печатает пояснение и выходит, а не падает с трассировкой.

---

## 5. Полный прогон

```
> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1
smoke          PASS
movement       PASS
input_actions  PASS
input_gate     PASS
weapon_data    PASS
integrity      PASS
weapon         PASS
projectile     PASS
enemies        PASS
waves          [SKIP]  (tests\waves.gd not present)
save           [SKIP]  (tests\save.gd not present)
progression    [SKIP]  (tests\progression.gd not present)

RESULT: 9 passed, 0 failed, 3 skipped
```

`movement` и `integrity` не сломались: добавление `Hurtbox` в `player.tscn` не меняет ни слои тела игрока (`collision_layer = 2`, `collision_mask = 1` в сцене не тронуты), ни набор проверяемых ими узлов (ни `smoke.gd`, ни `integrity.gd`, ни `movement.gd` не перечисляют точный состав детей `Player`).

**Расхождение с ожиданием из задания.** Задание ожидало «10 passed / 0 failed / 3 skipped», бриф ожидал «9 checks (8 старых + enemies), 0 failed». Фактически 9, и это правильно: в `$Tests` раннера 12 имён, из них 9 файлов существуют (`smoke`, `movement`, `input_actions`, `input_gate`, `weapon_data`, `integrity`, `weapon`, `projectile`, `enemies`) и 3 ещё не написаны (`waves`, `save`, `progression`). `tests/enemies.gd` уже был в списке до Task 2, поэтому он не добавляет счётчик — «10» в задании это off-by-one. Ничего не обходил и не подгонял.

---

## 6. Самопроверка диффа

Что проверено и что осталось:

1. **`scripts/hurtbox.gd`** — сигнал `damage_taken` и тело `apply_damage` побайтово не изменились (`damage_taken.emit(amount * damage_multiplier)`); изменён только хвостовой перевод строки (файл теперь заканчивается `\n`, раньше не заканчивался). Дефолты `zone = 0` / `detects_contact = false` дают Phase-1 поведение побайтово: слой 8, маска 1, `monitoring = false`. Это подтверждено зелёными PASS-ами по `Hurtbox.new()`.
2. **`player.tscn`** — `collision_layer`/`collision_mask` у `Hurtbox` в сцене отсутствуют, как требовал бриф. Файл по-прежнему без завершающего перевода строки (сохранён исходный стиль).
3. **`player.gd`** — контракт, который проверяет `tests/movement.gd::_test_player_source_contract`, не сломан: `ui_cancel` не появился, ветки `InputEventMouseButton` нет, `InputGate.is_play_input_allowed(` ≥ 2, `_mouse_mode_for_play_input() -> int` ровно 1. Подтверждено `movement PASS`.
4. **`_respawn()`** — kill-plane вызывает `_respawn()` без аргумента, то есть `restore_health == false`, и падение за карту не лечит игрока. Это отдельное дизайнерское решение (обосновано комментарием в коде): бриф не оговаривает, должен ли kill-plane сбрасывать здоровье, и «прыжок в пропасть = бесплатное лечение» — явно не то поведение, которого хочет игра.
5. **GDScript-ловушки, найденные и обойдённые по пути** (не оставили следов в коде): `with` — зарезервированное ключевое слово (`_respawn(with_health_reset := true)` → Parse Error: *Expected closing ")" after call arguments*), поэтому параметр называется `restore_health` и передаётся позиционно `_respawn(true)`.
6. **Порядок в `_ready()`** — ровно как в брифе: `set_spawn_transform()` → `_health = max_health` → `_connect_hurtbox()` → существующая логика фокуса и пистолета.
7. **`_connect_hurtbox()`** — с проверкой `is_connected`, по той же причине, по которой её имеет `_connect_focus_recapture()` (повторный вход в сцену иначе падает на «signal already connected»).
8. **Сцена без хитбокса не падает** — `get_node_or_null` + проверка, симметрично существующему `Pistol` (требование брифа).
9. **Что я НЕ делал:** не трогал `collision_layer`/`collision_mask` тела игрока, `Pistol`, `Camera3D`, `main.tscn`, `project.godot`, `tools/run_checks.ps1`, `scripts/enemy_data.gd`, `data/enemies/contact.tres`, секцию Task 1 в `tests/enemies.gd`. Git-команд, меняющих репозиторий, не выполнял.
10. **Известная хрупкость, не исправленная сознательно:** в `tests/enemies.gd` после ранних `return` (например, при `hurtbox == null`) уже созданные `player`/`plain` не удаляются через `queue_free()`. На результат прогона это не влияет (процесс сразу завершается), но при расширении файла третьим разделом это стоит учесть.

---

## 7. Опасения / вопросы к владельцу

1. **Порядок шагов в брифе (§4.1) — нужно подтверждение.** Я счёл, что перестановка шагов при дословном сохранении всех утверждений лучше, чем подгонять числа урона. Если контроллер ожидал, например, `take_damage(80.0)` вместо `take_damage(90.0)`, или два инстанса игрока, — это правка одного блока в `tests/enemies.gd`, не реализации.
2. **Немедленный респавн при смерти.** Реализовано по брифу, но это заметное игровое решение: в Фазе 2 смерть игрока и респавн в ту же секунду неотличимы от 100 HP без видимой полосы здоровья. Подписчик `died` в Фазе 4 сможет показать экран поражения, но для этого сигнал придётся слушать с задержкой в кадр.
3. **`health_changed` не испускается в `_ready()`.** Инициализация `_health = max_health` молчаливая, как того требует бриф. Полоса здоровья, появившаяся позже и читающая `health()` при старте, увидит корректные 100 — но любой подписчик, ожидающий первое событие «здоровье изменено», его не получит.
4. **Смешанные языки в `tests/enemies.gd`** (§4.3) — если это не приемлемо для ревью, метки надо переименовать в английские, и тогда ссылки в брифе на «died ровно один» / «после смерти 100.0» перестанут совпадать дословно.
5. **Замечание инфраструктуры, вне моего диффа:** файл `task-2-brief.md` физически сохранён в mojibake (UTF-8-текст, где русские буквы записаны как результат прохода через Windows-1251). Чтобы прочитать его, пришлось восстанавливать кодировку скриптом. Ничего не менял и не перезаписывал, но остальные брифы/планы, вероятно, поражены тем же, и `read`-инструмент показывает их нечитаемо.

---

## 8. Итог

* Реализовано: `zone`/`detects_contact` в `Hurtbox`, здоровье/сигналы/`take_damage` в `player.gd`, узел `Hurtbox` в `player.tscn`, раздел «Здоровье игрока» из 24 утверждений в `tests/enemies.gd` (включая пред-полётное утверждение «10 попаданий до смерти игрока»).
* TDD соблюдён: RED (`16 checks, 2 failed`, код 1) → реализация → GREEN (`35 checks, 0 failed`).
* Обе обязательные мутации доказаны, каждая падает ровно на названном в брифе утверждении; `player.gd` восстановлен побайтово, SHA-256 совпадает до/после каждого круга и финально равен `F9D19AE835F269702479C42F47E5B2C9AA01B531A246E3BCC1EB404E7E636D26`.
* Полный прогон: **9 passed, 0 failed, 3 skipped**.
* Git-мутаций не выполнялось; рабочее дерево оставлено unstaged.
