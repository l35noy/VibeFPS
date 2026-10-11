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
## Интервал между спавнами в секундах — для Фазы 3; поле здесь, чтобы данные
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
