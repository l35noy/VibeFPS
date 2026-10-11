# VibeFPS — Фаза 2: Здоровье, урон, контактный враг, навигация — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Сделать так, чтобы у игрока и врага было здоровье, враг получал урон от снарядов, приближался через навигацию, наносил контактный урон и умирал, теряя цвет — и чтобы каждое из этих свойств было доказано падающей проверкой.

**Architecture:** Здоровье живёт у владельца (игрок, враг), не в `Hurtbox` — хитбокс по контракту Фазы 1 только сообщает `damage_taken`. Данные врага — `EnemyData` (Resource, как `WeaponData`). Враг — `CharacterBody3D` + `NavigationAgent3D` со спековым раскладом слоёв. Всё, что проверяемо headless, проверяется headless; проверки сцен грузят сцены, а не собирают мир из кода (главный урок Фазы 1).

**Tech Stack:** Godot 4.7.2 stable (`E:\Godot\Godot_v4.7.2-stable_win64.exe`), GDScript, Jolt Physics, NavigationServer3D (работает headless), PowerShell.

**Spec:** `~/.opencode/plan/2026-10-07-vibefps-foundation-design.md` — разделы 6.2 (EnemyData), 6.3 (слои коллизий), 7.2 (игрок: 100 HP, контактный урон 10), 7.3 (враги), 11 (критерий приёмки Фазы 2: «враг получает урон, приближается через навигацию, наносит контактный урон, умирает и теряет цвет»).

**Предыдущая фаза:** Фаза 1 закрыта + fix-up. 8 проверок зелёные (movement 68 ассертов, integrity 21), каждая новая проверка доказана мутацией с SHA-256.

**Область этой фазы — по таблице фаз спеки (§9), а не по слитому описанию из HANDOFF:** контактный враг и здоровье. Летающий враг, босс, спавн-волны, сцена локации — Фаза 4 (спека §9: фазы 2 и 4 разделены; HANDOFF описал их слитно, спека утверждена и является источником).

## Глобальные решения по открытым вопросам (из HANDOFF §9, приняты здесь)

1. **Минимальная ширина хитбокса ≥ 0.5 м — правило проекта.** `Area3D`-детект дискретный: при 40 м/с и 120 Гц снаряд пролетает ⅓ м за тик, тоньше — пролетается между отсчётами, `ShapeCast3D` запрещён спекой. Капсула контактного врага 0.8 м — проходит. Проверка габаритов хитбоксов сцены — в Task 5.
2. **Авторитетный объём попадания — хитбокс, не тело.** Тело врага (слой 3) в маске снаряда не состоит (спека §6.3) — уже так и проверено. Тело — только движение и геометрия.
3. **Урон стакается.** Каждый снаряд — одно событие `damage_taken`, два снаряда — двойной урон. Никаких i-frames не вводится (YAGNI; решение за владельцем врага, если понадобится — Фаза 4).
4. **Контактный тик: 10 урона раз в 1.0 с** непрерывного контакта (`@export`, тесты уменьшают). Спека даёт «10 попаданий до смерти», но не даёт каденцию — без тика враг убивал бы за один кадр.
5. **Скорость контактного врага — 6.0 м/с** (спека не даёт). Быстрее ходьбы (5.0), медленнее спринта (9.0): спринт спасает, ходьба — нет. Балансировка — Фаза 6.
6. **Смерть игрока → респавн с полным HP** (до Фазы 3, где смерть станет возвратом в лобби). Иначе смерть = вечный game-over без лобби.
7. **Маска тела игрока остаётся 1** (не `1|7` из спеки): слой 7 — Area3D, `move_and_slide` с областями не работает, бит бесполезен; integrity-чек уже защищает `mask == 1`. Отклонение от спеки зафиксировано здесь, осознанно.

## Global Constraints

- Godot: `E:\Godot\Godot_v4.7.2-stable_win64.exe`. Путь хранится только в `tools/run_checks.ps1`. Других копий не создавать.
- Каждая проверка — отдельный `tests/*.gd`, наследующий `SceneTree`, завершающийся `quit(0)`/`quit(1)`.
- Критерий готовности: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1` → код 0. Голый `.\tools\run_checks.ps1` не работает (политика по умолчанию; все области `Undefined`).
- **Коммиты делает только партнёр.** Ни контроллер, ни субагенты не выполняют `git commit`, `git add` и прочие git-мутации.
- **Каждая проверка обязана быть доказана способной падать.** Мутация обязательна в каждой задаче: сломать код, увидеть красное, восстановить побайтово (SHA-256 до и после), увидеть зелёное.
- **Проверка сцен грузит сцену.** Скриптовый тест, собирающий мир из кода, валидирует скрипт, а не проводку сцены — это два бага Фазы 1, дошедшие до зелёного состояния. Всё, что живёт в `.tscn`, проверяется через `load()`/инстанцирование сцены.
- `_ready()` не синхронный: ждать `is_node_ready()`, кадры — через ожидание, не через чтение сразу после `add_child`.
- Headless не захватывает курсор. Проверкам, которым нужно движение игрока, — шов `player.gd::_mouse_mode_for_play_input()` через подкласс (сделано в `movement.gd`/`integrity.gd`); второй способ не изобретать. Симуляция врага шов не требует.
- `collision_layer`/`collision_mask` в коде и в `.tscn` — БИТМАСКА: слой N = `1 << (N - 1)`. «Маска 1|7» из спеки означает слои 1 и 7 = `(1 << 0) | (1 << 6)`, а НЕ целое 7. Проект уже горел на этой ошибке (ledger, 14-я коррекция).
- Для чтения вывода Godot напрямую — `Start-Process` с `-RedirectStandardOutput`/`-RedirectStandardError`; `2>&1` в PowerShell 5.1 ненадёжен.
- Несвязанные изменения запрещены.

## Review Focus

Что спека подразумевает, но ни одна задача не покрывает массово:

1. **Два снаряда в одного врага в один кадр, второй попадает в уже мёртвого.** Ожидание: смерть ровно одна, ошибок в консоли нет, `died` не испускается дважды. → Task 3, `tests/enemies.gd`.
2. **Враг без запечённого навмеша.** Проверка «движется к игроку» будет зелёной, пока враг стоит с пустым путём. Ожидание: после bake полигонов > 0, и дистанция до цели реально уменьшается. → Task 4, `tests/enemies.gd`.
3. **Хитбокс тоньше ⅓ м.** Снаряд пролетает его между тиками, попадание не регистрируется, проверка попадания при этом зелёная. Ожидание: габариты каждого хитбокса сцены ≥ 0.5 м. → Task 5, `tests/enemies.gd` (секция wiring).
4. **Граница смерти игрока: 9 тиков × 10 = жив, 10-й = смерть ровно на нуле**, респавн с полным HP, сигнал `died` один. → Task 2, `tests/enemies.gd`.
5. **Esc не останавливает мир:** pause-системы нет, враг продолжает наносить урон при свободном курсоре. Это не баг и не чинится молча — зафиксировать наблюдением в ручной проверке Task 5, решение (пауза) принадлежит Фазе 5 (экраны).

## Карта владения файлами

Фаза 2 последовательна (спека §9: параллелизма нет): все задачи пишут в `tests/enemies.gd`.

| Задача | Файлы во владении |
|---|---|
| 1 | `scripts/enemy_data.gd`, `data/enemies/contact.tres`, `tests/enemies.gd` (создание) |
| 2 | `scripts/hurtbox.gd`, `player.gd`, `player.tscn`, `tests/enemies.gd` |
| 3 | `scripts/enemy_contact.gd`, `enemy_contact.tscn`, `tests/enemies.gd` |
| 4 | `scripts/enemy_contact.gd`, `enemy_contact.tscn`, `tests/enemies.gd` |
| 5 | `range.tscn`, `scripts/range_scene.gd`, `tests/enemies.gd` |

`$Tests` в `tools/run_checks.ps1` трогать не нужно: `enemies` объявлен в Фазе 0 и сейчас даёт `[SKIP]` — появление файла включит проверку автоматически.

---

### Task 1: EnemyData — ресурс характеристик врага

**Files:**
- Create: `scripts/enemy_data.gd`
- Create: `data/enemies/contact.tres`
- Create: `tests/enemies.gd`

**Interfaces:**
- Produces: `class_name EnemyData extends Resource`:

```gdscript
class_name EnemyData
extends Resource

## Тип врага. CONTACT — эта фаза; FLYING и BOSS объявлены сейчас, потому что
## типы перечислены в спеке §6.2, а добавление значения в enum позже сломает
## сохранения и проверки, читающие тип.
enum EnemyKind { CONTACT, FLYING, BOSS }

@export var display_name: String = "Enemy"
@export var max_health: float = 50.0
## Контактный урон за один тик контакта (каденция — у врага, не здесь).
@export var contact_damage: float = 10.0
@export var move_speed: float = 6.0
## Интервал между спавнами в секундах — для Фазы 4; поле здесь, чтобы данные
## были полными с первого дня (спека §6.2).
@export var spawn_interval: float = 1.5
@export var color: Color = Color(0.8, 0.25, 0.25)
@export var kind: EnemyKind = EnemyKind.CONTACT
```

- Produces: `func is_valid() -> bool` → `max_health > 0.0 and contact_damage > 0.0 and move_speed > 0.0 and spawn_interval > 0.0`
- Produces: `data/enemies/contact.tres` — `EnemyData`: `display_name = "Contact"`, `max_health = 50.0`, `contact_damage = 10.0`, `move_speed = 6.0`, `spawn_interval = 1.5`, `color = Color(0.8, 0.25, 0.25)`, `kind = EnemyKind.CONTACT`.

- [ ] **Step 1: Написать падающую проверку `tests/enemies.gd`**

Первый файл проверки фазы. Наследует `SceneTree`, структура и стиль — как в `tests/weapon_data.gd` (секция, `[PASS]`/`[FAIL]` на каждое утверждение, счётчик, `quit(1)` при любом падении).

Секция «EnemyData», утверждения (каждое способно упасть):
- `load("res://data/enemies/contact.tres")` загружается и `is EnemyData`
- `max_health == 50.0`, `contact_damage == 10.0`, `move_speed == 6.0`, `spawn_interval == 1.5`
- `kind == EnemyData.EnemyKind.CONTACT`
- `is_valid()` истинна
- инвариант из спеки §7.2/§7.3, вычисленный из полей: `max_health / contact_damage == 10.0` («10 попаданий до смерти») с допуском 0.0001 — связка здоровья и урона не разъедется молча при правке баланса в одном из полей

- [ ] **Step 2: Убедиться, что проверка падает**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies`
Expected: `enemies FAIL` — файла `enemy_data.gd` нет, ошибка парсинга/загрузки, код 1.

- [ ] **Step 3: Создать `scripts/enemy_data.gd`**

Содержимое — блок Produces выше, копируется дословно, плюс `is_valid()`.

- [ ] **Step 4: Создать `data/enemies/contact.tres`**

Формат — как `data/weapons/pistol.tres`:

```
[gd_resource type="Resource" script_class="EnemyData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/enemy_data.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
display_name = "Contact"
max_health = 50.0
contact_damage = 10.0
move_speed = 6.0
spawn_interval = 1.5
color = Color(0.8, 0.25, 0.25, 1)
kind = 0
```

- [ ] **Step 5: Прогнать и доказать падаемость**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies`
Expected: `enemies PASS`, код 0.

Мутация: в `.tres` `contact_damage = 10.0` → `5.0`, прогнать — падает именно инвариант «10 попаданий» (и `contact_damage == 10.0`). Вернуть, SHA-256 `.tres` до/после совпадает, снова зелёное.

---

### Task 2: Здоровье игрока и зона хитбокса игрока

**Files:**
- Modify: `scripts/hurtbox.gd`
- Modify: `player.gd`
- Modify: `player.tscn`
- Modify: `tests/enemies.gd`

**Interfaces:**
- Consumes: `Hurtbox` из Фазы 1 (контракт `damage_taken(amount)` сохраняется).
- Produces: `Hurtbox` получает две настройки, **дефолты сохраняют поведение Фазы 1** (существующие инстансы ничего не настраивают):

```gdscript
## Зона: 0 = enemy_hurtbox (слой 4), 1 = player_hurtbox (слой 7).
@export_enum("enemy_hurtbox", "player_hurtbox") var zone: int = 0
## true — хитбокс сам ищет пересечения (нужно врагу для контактного урона);
## false — чистая цель, как в Фазе 1.
@export var detects_contact: bool = false
```

  `_ready()`: `collision_layer = (1 << 3) if zone == 0 else (1 << 6)`; `monitoring = detects_contact`; `collision_mask = (1 << 6) if detects_contact else (1 << 0)`. Смысл маски при детекте: слой 7 — ловим хитбокс игрока; миру хитбокс-обнаружитель не нужен (`area_entered` и так не ловит StaticBody3D). Поля `_COLLISION_LAYER`/`_COLLISION_MASK` убрать или переписать под выражения выше — в одном файле, с комментарием.

- Produces: `player.gd`:

```gdscript
signal health_changed(current: float, maximum: float)
signal died()

@export var max_health: float = 100.0

func health() -> float
func is_alive() -> bool
func take_damage(amount: float) -> void   # amount <= 0 — игнор; <= 0 после вычитания — смерть
```

  Состояние `_health`, инициализация `max_health` в `_ready()`; **в `_ready()` узел `Hurtbox` (имя `Hurtbox`) подключается: `hurtbox.damage_taken.connect(take_damage)`** — это проводка сцены, её проверяет Task 2 (настоящим инстанцированием `player.tscn`). Смерть: `_health = 0`, `died.emit()` **один раз** (дальше `is_alive()` блокирует повтор), затем немедленный респавн: `global_transform = _spawn_transform`, `velocity = Vector3.ZERO`, `_health = max_health`, `health_changed.emit(...)`, `print(...)` в стиле проекта. Респавн при смерти — контракт до Фазы 3 (см. глобальное решение 6).

- Produces: `player.tscn` — дочерний узел `Hurtbox` (скрипт `hurtbox.gd`), с `CollisionShape3D`/`CapsuleShape3D` `radius = 0.4`, `height = 1.8`, смещение `y = 0.9` — тот же объём, что тело игрока (0.8 м ≥ 0.5 м — правило ширины). `zone = 1` (player_hurtbox), `detects_contact = false` (детект — на стороне врага, спека §6.3: маску включает враг).

- [ ] **Step 1: Написать падающие проверки (секция «Здоровье игрока» в `tests/enemies.gd`)**

Проверки грузят **сцену**, а не строят мир из кода: `load("res://player.tscn").instantiate()`, ждать `is_node_ready()`.

Утверждения:
- в `player.tscn` есть узел `Hurtbox`, его `zone == 1` и после готовности `collision_layer == (1 << 6)` — регресс-щит слоя игрока
- дефолтный `Hurtbox.new()` (без настроек) имеет `collision_layer == (1 << 3)` и `monitoring == false` — защита контракта Фазы 1 для мишеней и врагов
- старт: `health() == 100.0`, `is_alive()`
- проводка сцены: `player.hurtbox.apply_damage` не публичный путь — вместо него проверка через `Hurtbox`-узел игрока: `hurtbox.apply_damage(10.0)` → `health() == 90.0` (доказывает `damage_taken → take_damage`, а не только сам метод)
- `take_damage(90.0)` → `is_alive()` истинно, `health() == 10.0` (граница 9 тиков)
- десятое `take_damage(10.0)` → `is_alive()` ложь, `health() == 0.0`, сигнал `died` ровно **один** (счётчик подключённого обработчика)
- после смерти здоровье восстановлено: `health() == 100.0`, `is_alive()` (респавн-контракт)
- `take_damage(0.0)` и `take_damage(-5.0)` не меняют `health()` и не испускают `died`
- `health_changed` испущен с корректными значениями (последнее событие `100.0/100.0` после респавна)

- [ ] **Step 2: Убедиться, что проверки падают**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies`
Expected: FAIL — у `Hurtbox` нет `zone`, у игрока нет здоровья, код 1.

- [ ] **Step 3: Изменить `scripts/hurtbox.gd`**

Добавить `zone` и `detects_contact` по блоку Produces; переписать `_ready()` слои/маски; обновить doc-комментарии (почему маска при детекте — слой 7, почему дефолт — поведение Фазы 1). Сигнал `damage_taken` и `apply_damage` не меняются.

- [ ] **Step 4: Изменить `player.gd`**

Поле/сигналы/функции — блок Produces. Порядок в `_ready()`: сначала `_spawn_transform`, потом `_health = max_health`, потом подключение `Hurtbox` (через `get_node_or_null("Hurtbox")` с проверкой — сцены без хитбокса не должны падать, как сейчас с `Pistol`), потом существующая логика. `take_damage` при смерти вызывает респавн той же веткой, что и kill-plane (`_respawn()`), но со сбросом здоровья; сигнал `died` — строго до восстановления.

- [ ] **Step 5: Добавить узел `Hurtbox` в `player.tscn`**

Состав и `zone = 1` — блок Produces. `collision_layer` в сцене НЕ прописывать — его задаёт `_ready()` скрипта (правило проекта: слой и логика в одном файле).

- [ ] **Step 6: Прогнать и доказать падаемость**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies`
Expected: PASS, код 0.

Две обязательные мутации:
- в `player.gd` убрать `died.emit()` → утверждение «died ровно один» падает;
- в `player.gd` в ветке смерти не восстанавливать `_health` → утверждение «после смерти 100.0» падает.
SHA-256 `player.gd` до/после каждого круга — идентично.

Затем контрольный полный прогон: `...\run_checks.ps1` → `8 passed, 0 failed, 0 skipped`? Нет: `enemies` теперь исполняется, ожидаемый итог — **9 checks (8 старых + enemies), 0 failed**, `enemies` в PASS. Если `movement`/`integrity` упали — разобраться до продолжения (добавление `Hurtbox` в `player.tscn` не должно их ломать; ломает — значит сцена ожидала точный состав детей, это ожидание нужно понять, а не обойти).

---

### Task 3: Контактный враг — здоровье, урон, смерть, контактный тик

**Files:**
- Create: `scripts/enemy_contact.gd`
- Create: `enemy_contact.tscn`
- Modify: `tests/enemies.gd`

**Interfaces:**
- Consumes: `EnemyData` (Task 1), `Hurtbox.zone/detects_contact` (Task 2), спека §6.3 (слои), группа игрока.
- Produces: игрок в `_ready()` входит в группу `"player"` (`add_to_group("player")`) — враг находит цель через `get_tree().get_first_node_in_group("player")`, без назначения путей в сценах.
- Produces: `class_name ContactEnemy extends CharacterBody3D`:

```gdscript
signal health_changed(current: float, maximum: float)
signal died()

@export var data: EnemyData
## Каденция контактного урона, сек. Глобальное решение 4: спека фиксирует
## урон (10), но не каденцию; без тика враг убивал бы за один проход.
@export var contact_interval: float = 1.0

func health() -> float
func is_alive() -> bool
func take_damage(amount: float) -> void
```

  Структура сцены `enemy_contact.tscn`:
  - `ContactEnemy` (корень, скрипт, `data = ExtResource(data/enemies/contact.tres)`)
  - `CollisionShape3D` — `CapsuleShape3D` `radius = 0.4`, `height = 1.8`, `y = 0.9`
  - `Hurtbox` — дочерний, `zone = 0` (дефолт), `detects_contact = true`, `CollisionShape3D` той же капсулы (0.8 м ≥ 0.5 м)
  - `Mesh` (`MeshInstance3D`) — `CapsuleMesh` `radius = 0.4`, `height = 1.8`, `y = 0.9`, материал **дублируется в `_ready()`** (урок `range_target.gd`: общий SubResource перекрасил бы всех врагов)
  - `NavigationAgent3D` — добавляется в Task 4; в этой задаче его отсутствие допустимо, но сцену Task 4 будет дополнять тот же владелец-цепочка

  Слои **в `_ready()`, не в сцене** (правило проекта), с точными выражениями:
  - тело: `collision_layer = 1 << 2` (слой 3 `enemy_body`), `collision_mask = (1 << 0) | (1 << 2)` (слои 1 и 3: мир + свои; **игрока в маске нет** — враг проходит сквозь тело игрока, контакт ловится хитбоксами, спека §6.3)
  - хитбокс настраивает сам себя через `detects_contact` (Task 2)

  Поведение:
  - `take_damage` — как у игрока, но смерть: `died` один раз → материал меша обесцвечивается к `Color(0.5, 0.5, 0.5)` («умирает и теряет цвет» — критерий приёмки §11), тело и хитбокс выключаются (`collision_layer = 0`, `set_deferred("monitoring", false)`, `set_physics_process(false)`), через 0.2 с (счётчик в `_physics_process`) — `queue_free()`. Задержка нужна, чтобы цвет смерти был наблюдаемым.
  - контакт: `_on_hurtbox_area_entered(area)` — если `area` из группы... нет: если `area` — `Hurtbox` с `zone == 1` (хитбокс игрока), немедленный тик `player.take_damage(data.contact_damage)` + запуск аккумулятора; каждый `_physics_process` при активном контакте: `acc += delta`, при `acc >= contact_interval` — тик, `acc -= interval`. `area_exited` — остановить аккумулятор. Цель для движения (Task 4) — группа `"player"`.
  - `data == null` или `not data.is_valid()` → `push_error` и выключение обработки: невалидный враг не должен убивать проверку делением на ноль.

- [ ] **Step 1: Написать падающие проверки (секция «Контактный враг» в `tests/enemies.gd`)**

Всё грузится из сцены: `load("res://enemy_contact.tscn").instantiate()` + `is_node_ready()`; мир вокруг — программно, как в `tests/projectile.gd` (пол, стена), но сам враг — из сцены.

Утверждения:
- сцена грузится, корень `is ContactEnemy`, `data` — `EnemyData` с `max_health == 50.0`
- проводка слоёв сцены: тело `collision_layer == (1 << 2)`, `collision_mask == ((1 << 0) | (1 << 2))`; хитбокс-узел: `zone == 0`, после готовности `collision_layer == (1 << 3)`, `monitoring == true`, `collision_mask == (1 << 6)`
- старт: `health() == 50.0`, `is_alive()`
- **сквозная проводка через снаряд** (не `apply_damage` напрямую!): инстанцировать `projectile.tscn`, `launch()` по направлению на врага, ждать попадания → `health() == 20.0`. Второй снаряд → `died` ровно один, `is_alive()` ложь. Это проверка проводки «снаряд → слои → хитбокс → враг», которую `tests/projectile.gd` (мир из кода) проверить не может.
- **два снаряда, одна цель, один кадр**: два `Projectile` c одинаковой позиции/направления, обработать кадр — `died` счётчик ≤ 1, после второго `health() >= 0.0` (Review Focus 1)
- **урон по мёртвому**: после смерти `take_damage(30.0)` → `died` не испускается повторно, ошибок в консоли нет (счёт `[FAIL]`-маркеров в выводе)
- **контактный тик**: выставить `contact_interval = 0.1` (экспорт), поставить врага внахлёст на `Hurtbox` игрока (`zone == 1`, из `player.tscn` или программно с корректным `zone = 1`), ждать физкадров: первый тик — сразу при входе, затем ~0.1 с; игрок ровно на границе: 9 тиков × 10 → жив (`health() == 10.0`), десятый → смерть и респавн игрока (контракт Task 2). Тестовый урон берётся из `data.contact_damage`, не захардкожен
- контакт прекращается: увести врага (`area_exited`, симулируется позицией) → тики останавливаются, здоровье не убывает

- [ ] **Step 2: Убедиться, что проверки падают**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies`
Expected: FAIL — файла/класса нет, код 1.

- [ ] **Step 3: Создать `scripts/enemy_contact.gd`**

Всё по блоку Produces: слои с точными выражениями, `take_damage`/смерть с обесцвечиванием и отложенным `queue_free`, контактный тик с аккумулятором, валидация `data`, группа `player` в игрока (правка `player.gd` — **одна строка** `add_to_group("player")` в `_ready()`; это единственная правка чужого файла, задокументируй её в отчёте).

- [ ] **Step 4: Создать `enemy_contact.tscn`**

Состав — блок Produces, дословно. `uid` движок сгенерирует при импорте. `data` назначить `ExtResource` на `res://data/enemies/contact.tres`.

- [ ] **Step 5: Прогнать и доказать падаемость**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies`
Expected: PASS, код 0.

Три обязательные мутации:
- в `enemy_contact.gd` в ветке смерти убрать обесцвечивание → падает проверка «теряет цвет» (добавь её в секцию: после смерти `mesh.material_override.albedo_color` близка к серому, допуск 0.01 — на материалах из Task 3);
- в `_on_hurtbox_area_entered` убрать немедленный первый тик → падает «первый тик при входе»;
- счётчик `died`-сигнала оставить без гварда `is_alive()` → падает «died ровно один».
SHA-256 каждого изменённого файла до/после — идентично.

---

### Task 4: Навигация — враг идёт к игроку через NavigationAgent3D

**Files:**
- Modify: `scripts/enemy_contact.gd`
- Modify: `enemy_contact.tscn`
- Modify: `tests/enemies.gd`

**Interfaces:**
- Consumes: `ContactEnemy` из Task 3, группа `"player"`.
- Produces: дочерний `NavigationAgent3D` в `enemy_contact.tscn` (`path_desired_distance = 0.5`, `target_desired_distance = 1.0` — дефолты движка приемлемы, задать явно для читаемости). В `ContactEnemy`:

```gdscript
## Следующая точка пути к игроку. Направление — к "player"; цель меняется
## каждый тик, поэтому stale-путь пересчитывается сам.
func next_path_direction() -> Vector3   # Vector3.ZERO — если пути нет
```

  `_physics_process` врага: если `is_alive()` и цель найдена → `agent.target_position = target.global_position`, `dir = next_path_direction()`, `velocity.x/z = dir * data.move_speed` (при `dir != ZERO`), иначе обнулить; гравитация — как у игрока (`is_on_floor` / `_gravity`); `move_and_slide()`.

- Produces: правило bake (спека §12: «агент, меняющий геометрию, обязан перестроить навмеш»): навмеш запекается **рантаймом** — в тестовом мире и в `range.tscn` вызовом `region.bake_navigation_mesh(false)` (синхронный, до начала физики), с проверкой `region.navigation_mesh.get_polygon_count() > 0` после. Полигонов нет — мир обязан упасть проверкой, а не пройти молча (Review Focus 2).

- [ ] **Step 1: Написать падающие проверки (секция «Навигация» в `tests/enemies.gd`)**

Мир программно: пол (`StaticBody3D`, слой 1, `BoxShape3D` + `MeshInstance3D` для bake-парсинга), `NavigationRegion3D` **над полом** (пол — потомок региона; режим `ROOT_NODE_CHILDREN` по умолчанию), стена-препятствие между врагом и целью, цель — узел в группе `"player"` (достаточно `Node3D` с позицией; группу проверяем реальным `player.tscn` отдельно в Task 2). Bake синхронно, затем физкадры для синхронизации карты.

Утверждения:
- bake успешен: `navigation_mesh.get_polygon_count() > 0` (Review Focus 2: навмеш без полигонов = пустой путь = враг стоит, тест «шёл» зелёный)
- враг, стоящий за стеной от цели, за 3 с симуляции **сокращает дистанцию** не менее чем на 50% (путь идёт вокруг, не сквозь — дистанция меряется каждый физкадр, последнее значение < 50% исходного)
- во время движения `velocity` по горизонтали равен `data.move_speed` (допуск 0.01) — враг не ползёт и не ускоряется сверх данных
- враг останавливается у цели: дистанция ≤ `target_desired_distance + 0.1`, дальше не дрейфует (сравнить через 0.5 с)
- враг без `NavigationAgent3D` невозможен — грузится сцена, а не скрипт: утверждение `enemy.navigation_agent is NavigationAgent3D` на инстансе сцены

- [ ] **Step 2: Убедиться, что проверки падают**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies`
Expected: FAIL — навигации ещё нет, враг стоит, дистанция не сокращается, код 1.

- [ ] **Step 3: Добавить `NavigationAgent3D` в `enemy_contact.tscn`**

Настройки — блок Produces.

- [ ] **Step 4: Реализовать навигацию в `scripts/enemy_contact.gd`**

`@onready var _agent: NavigationAgent3D = $NavigationAgent3D` (с проверкой `get_node_or_null` — сцена может быть без агента, тогда поведение = стоит, с `push_warning`). `next_path_direction()` — из `get_next_path_position()` относительно `global_position`; нулевой/пустой путь → `Vector3.ZERO`. Остальное — блок Produces. Гравитацию и `move_and_slide()` — в том же `_physics_process`, порядок: гравитация → цель → направление → velocity → `move_and_slide`.

- [ ] **Step 5: Прогнать и доказать падаемость**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies`
Expected: PASS, код 0.

Две обязательные мутации:
- в `next_path_direction()` всегда `return Vector3.ZERO` → падает «дистанция сокращается на 50%» (враг стоит);
- в `_physics_process` умножить скорость на `0.5` → падает «velocity == move_speed».
SHA-256 до/после — идентично.

Полный прогон: `...\run_checks.ps1` → 0 failed. Особо проверить `integrity`: он грузит `main.tscn` и не должен заметить изменений врага — упал, значит пересёкся с чем-то неожиданным, разобраться.

---

### Task 5: Связывание — враг в тире, проверка проводки сцены, ручная игра

**Files:**
- Modify: `range.tscn`
- Create: `scripts/range_scene.gd`
- Modify: `tests/enemies.gd`

**Interfaces:**
- Consumes: `ContactEnemy` (Task 3–4), `Hurtbox.zone` (Task 2).
- Produces: `range.tscn` получает: `NavigationRegion3D` (пол тира — его потомок), корень сцены со скриптом `scripts/range_scene.gd` (`_ready()`: синхронный bake + `push_error` при `polygon_count == 0`), один `ContactEnemy` в дальнем углу (не ближе 4 м от игрока), `data` — дефолтный `contact.tres`.
- Produces: секция «Проводка сцены» в `tests/enemies.gd` — регресс-щит Фазы 2 (аналог урока с `range.tscn` из HANDOFF §8: «у тира нет проверки»).

- [ ] **Step 1: Написать падающие проверки секции «Проводка сцены»**

`load("res://range.tscn")`, инстанцирование, `is_node_ready()`.

Утверждения:
- все три мишени: тело `collision_layer == (1 << 2)` (слой 3 — битмаска, не 4!), хитбокс тела мишени... хитбокс-узел каждой мишени: `collision_layer == (1 << 3)` (слой 4) — **закрывает открытый пункт HANDOFF §8 «у range.tscn нет проверки»**
- враг в сцене присутствует, `is ContactEnemy`, тело `collision_layer == (1 << 2)` и маска `((1 << 0) | (1 << 2))`, хитбокс `monitoring == true`
- игрок в сцене: `Hurtbox` `collision_layer == (1 << 6)`
- **правило ширины (глобальное решение 1)**: для каждого `Hurtbox` в `range.tscn` (мишени, враг, игрок) габариты его `CollisionShape3D.shape`: `CapsuleShape3D.radius * 2 >= 0.5` или `BoxShape3D.size` по минимальной оси `>= 0.5`. Иначе — FAIL с именем узла.
- bake тира: у `NavigationRegion3D` `navigation_mesh.get_polygon_count() > 0`

- [ ] **Step 2: Убедиться, что проверки падают**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies`
Expected: FAIL — врага/навмеша в тире нет, код 1.

- [ ] **Step 3: Добавить `NavigationRegion3D` и `ContactEnemy` в `range.tscn`, создать `scripts/range_scene.gd`**

Геометрия тира не меняется (пол, стены, мишени — нет). Скрипт корня: bake, см. Produces. Стиль комментариев — русский, «почему».

- [ ] **Step 4: Прогнать все проверки**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1`
Expected: 0 failed, все включённые проверки PASS (`smoke`, `movement`, `input_actions`, `input_gate`, `weapon_data`, `integrity`, `weapon`, `projectile`, `enemies`), 3 SKIP. Если `smoke` упал — он смотрит на `range.tscn`; выяснить, что именно ожидал (список детей? позиции?), и решить осознанно: если он жёстко перечисляет детей — поправить smoke на новую реальность, это правка проверки, а не обход.

- [ ] **Step 5: Мутация финальной секции**

В `range.tscn` у мишени временно `collision_layer = 1` (бит слоя 1) → «тело мишени слой 3» падает. SHA-256 `range.tscn` до/после — идентично. Вернуть.

- [ ] **Step 6: Ручная проверка — её не заменит ни один автотест**

Запустить игру и наблюдать (в отчёте — что именно видено, не «всё работает»):
1. Враг в дальнем углу виден, красноватый, стоит.
2. Игрок подходит — враг **идёт к игроку, обходя стены/мишени** (навигация, не скольжение по прямой).
3. Контакт: враг касается — здоровье игрока падает на 10 примерно раз в секунду (следить по консоли, HUD нет).
4. Два выстрела в врага (30+30 > 50): на втором враг **обесцвечивается** и исчезает через ~0.2 с.
5. Сто попаданий не надо: встать в контакт на 10 тиков — смерть, респавн на старте с полным 100 HP.
6. Esc отпускает курсор — **враг продолжает наносить урон** (Review Focus 5: pause-системы нет). Зафиксировать наблюдением, не чинить.
7. Мишени тира по-прежнему реагируют на выстрелы (вспышка), ни одна не перекрасилась от врага (урок дублирования материалов).

---

## Завершение Фазы 2

Фаза закрыта, когда:

- `run_checks.ps1` → код 0; все проверки, включая `enemies`, PASS; 3 SKIP (waves, save, progression).
- Каждая задача доказала падаемость своих проверок мутацией с SHA-256 до/после, записанной в отчёте.
- Ручная проверка Task 5 выполнена, результат описан наблюдениями.
- Спека §11, критерий Фазы 2: «враг получает урон, приближается через навигацию, наносит контактный урон, умирает и теряет цвет» — каждое из четырёх подтверждено: сквозным тестом через снаряд, секцией навигации, секцией контактного тика, проверкой цвета смерти.
- `CHECKLIST.md` обновлён по факту: отмечены пункты про здоровье/врагов/урон, «Известные проблемы» пополнены новыми, если появились (например, наблюдение про Esc из Task 5), «Исправлено» — если что-то из старого закрыто этой фазой. Правила проекта: по факту, не по плану.
- Ledger дополнен: решения этого плана (каденция тика, скорость 6.0, правило ширины 0.5 м, респавн-контракт, отклонение маски игрока от спеки), инциденты, мутации.

## Что дальше

Фаза 3 (спека §9): лобби — зона отдыха с полным восстановлением здоровья, покупками оружия и улучшений, очками и дверями/порталами локаций (`GameState` / `SaveSystem` / `Sfx` из §6.1, слой `interactable` — слой 6, пустует под двери и точки покупки), сохранение прогресса (`tests/save.gd`, `tests/progression.gd` из §4.4). Фаза 4 (спека §9): летающий враг (`EnemyKind.FLYING` уже в данных), босс с `damage_multiplier ×2` (контракт `Hurtbox` готов с Фазы 1), спавн-волны (`spawn_interval` уже в данных) и сцена первой локации — без тёмного старта. `range.tscn` приходит в локацию или заменяется — решение Фазы 4; проверка его проводки (Task 5) переезжает вместе с ним.
