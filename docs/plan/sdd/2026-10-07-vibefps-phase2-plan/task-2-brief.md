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

  Состояние `_health`, инициализация `max_health` в `_ready()`; **в `_ready()` узел `Hurtbox` (имя `Hurtbox`) подключается: `hurtbox.damage_taken.connect(take_damage)`** — это проводка сцены, её проверяет Task 2 (настоящим инстанцированием `player.tscn`). Смерть: `_health = 0`, `died.emit()` **один раз** (дальше `is_alive()` блокирует повтор), затем немедленный респавн: `global_transform = _spawn_transform`, `velocity = Vector3.ZERO`, `_health = max_health`, `health_changed.emit(...)`, `print(...)` в стиле проекта. Респавн при смерти — контракт до Фазы 4 (см. глобальное решение 6).

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
