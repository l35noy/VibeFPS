> **Назначение:** Бриф задачи фазы.

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
