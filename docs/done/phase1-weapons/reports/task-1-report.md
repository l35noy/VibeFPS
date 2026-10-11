> **Назначение:** Отчёт по задаче фазы.

# Task 1 — WeaponData: ресурс характеристик оружия

**Статус: DONE**

Фаза 1, задача 1 из 5. Репозиторий `E:\projects\VibeFPS`, Godot 4.7.2 stable, Jolt Physics.

**Коммит и staging не выполнялись.** `git add` и `git commit` не вызывались ни разу.
HEAD остался на `11541c8`, `git diff --cached` пуст. Всё в рабочем дереве, unstaged.

---

## 1. Созданные и изменённые файлы

| Файл | Действие |
|---|---|
| `scripts/weapon_data.gd` | создан (40 строк) |
| `data/weapons/pistol.tres` | создан (14 строк) |
| `tests/weapon_data.gd` | создан (162 строки) |
| `tools/run_checks.ps1` | изменена **одна строка** — только массив `$Tests` |
| `scripts/weapon_data.gd.uid`, `tests/weapon_data.gd.uid` | созданы самим Godot при `--import` (см. §7) |

Изменение в `tools/run_checks.ps1` целиком:

```diff
-$Tests = @("smoke", "movement", "input_actions", "input_gate", "integrity",
+$Tests = @("smoke", "movement", "input_actions", "input_gate", "weapon_data", "integrity",
            "weapon", "projectile", "enemies", "waves", "save", "progression")
```

`"weapon_data"` вставлен сразу после `"input_gate"`. Порядок остальных не тронут,
`weapon` и `projectile` не дублировались, ничего не удалено.

`git status --short` на момент завершения:

```
 M tools/run_checks.ps1
?? data/
?? scripts/weapon_data.gd
?? scripts/weapon_data.gd.uid
?? tests/weapon_data.gd
?? tests/weapon_data.gd.uid
```

`git diff --cached --name-only` — пусто.

---

## 2. `scripts/weapon_data.gd` — итоговое содержимое

Поля скопированы дословно из блока Produces плана (имена, типы, значения по
умолчанию, комментарии `rounds_per_minute` и `projectile_color`). Документация
`projectile_speed` дополнена по требованию Step 3.

```gdscript
class_name WeaponData
extends Resource

## Характеристики оружия как данные.
##
## Одно оружие — один ресурс, одна структура полей. Поведение (магазин,
## перезарядка, огонь) живёт в скрипте оружия, а не здесь: ресурс ничего не
## знает про узлы сцены, поэтому его можно проверить headless, не строя мир.

@export var display_name: String = "Weapon"
@export var damage: float = 30.0
## Выстрелов в минуту. Интервал между выстрелами = 60 / rounds_per_minute.
@export var rounds_per_minute: float = 120.0
@export var magazine_size: int = 10
@export var reload_time: float = 1.2
## Скорость снаряда в м/с. Конечная скорость обязательна: игрок и враг могут
## уклоняться. На 40 м/с снаряд пистолета пролетает 15 м за 0.375 с, и это
## окно, за которое цель успевает отойти. Это игровое правило из PROJECT.md
## §9.8, а не техническая деталь: мгновенный (хитскан) выстрел это окно
## убирает, и уклонение становится невозможным.
@export var projectile_speed: float = 40.0
@export var projectile_radius: float = 0.08
@export var projectile_lifetime: float = 3.0
## Цвет снаряда и шлейфа. Геометрический стиль: контрастная геометрия.
@export var projectile_color: Color = Color(0.15, 0.15, 0.15)


## Интервал между выстрелами в секундах. Производное от rounds_per_minute,
## поэтому не хранится вторым числом, которое может разъехаться с первым.
func seconds_between_shots() -> float:
	return 60.0 / rounds_per_minute


## Пригодны ли данные к стрельбе. Оружие спрашивает это до выстрела, а не
## падает на делении на ноль: rounds_per_minute == 0 сделала бы
## seconds_between_shots() бесконечной, magazine_size == 0 — вечной
## перезарядкой без патронов.
func is_valid() -> bool:
	return rounds_per_minute > 0.0 and magazine_size > 0 \
		and reload_time > 0.0 and damage > 0.0 and projectile_speed > 0.0
```

Тела обоих методов — посимвольно из плана (включая перенос строки через `\`).

---

## 3. `data/weapons/pistol.tres` — итоговое содержимое

Дословно из плана, Step 4. Ничего не добавлено и не убрано.

```
[gd_resource type="Resource" script_class="WeaponData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/weapon_data.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
display_name = "Pistol"
damage = 30.0
rounds_per_minute = 120.0
magazine_size = 10
reload_time = 1.2
projectile_speed = 40.0
projectile_radius = 0.08
projectile_lifetime = 3.0
```

`projectile_color` в `.tres` намеренно не записан: планом он не задан, поэтому
берётся дефолт из скрипта, и проверка фиксирует именно дефолт.

---

## 4. `tests/weapon_data.gd` — итоговое содержимое

Отдельный `SceneTree`-скрипт, `quit(0)` / `quit(1)`. Хелпер `_check` **продублирован**
из остальных харнессов (не выносился в общий модуль) — намеренно, так же как в
`smoke.gd` / `input_gate.gd` / `integrity.gd`, чтобы каждый файл запускался сам по себе.
Ничего не инстанцируется как узел сцены: только `load()` ресурса и
`WeaponData.new()` для негативных проб.

```gdscript
extends SceneTree

## Weapon data harness for VibeFPS.
##
## Reads res://data/weapons/pistol.tres through load() and asks it the same
## questions the weapon script will ask in Phase 1 Task 3: what are the
## numbers, what does the derived fire interval come out as, and does the
## resource consider itself usable. Nothing is instantiated as a scene node --
## this is data, and a data check that had to build a world in order to read a
## number would be testing the world instead.
##
## Every assertion below names the edit that turns it red. The negative halves
## are asserted too, not only the green ones: seconds_between_shots() is asked
## to follow a *changed* fire rate, and is_valid() is asked to reject each
## degenerate value in turn. Without those, a method hardcoded to return 0.5
## and true would sail through a check that only ever saw the good resource.
##
## Run: godot --headless --path . --script res://tests/weapon_data.gd
##      .\tools\run_checks.ps1 weapon_data

const _PISTOL_PATH := "res://data/weapons/pistol.tres"

## The fire interval is a division, so it is compared with a tolerance rather
## than for exact equality.
const _EPS := 0.0001

## The design fixes the pistol at 120 rounds per minute with 10 rounds in the
## magazine. 120 rpm is one shot every 0.5 s, so a full magazine is 5 s of
## continuous fire. The assertion recomputes that from the resource's own
## fields instead of reading a hardcoded constant, so a future balance edit
## that changes the fire rate or the magazine size alone cannot pass unnoticed.
const _EXPECTED_BURST_SECONDS := 5.0

var _failures: PackedStringArray = []
var _checks := 0


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


func _close(got: float, want: float) -> bool:
	return absf(got - want) <= _EPS


## Builds a throwaway WeaponData with one field overwritten, so the derived
## methods can be asked a question the shipped resource never asks.
func _probe(overrides: Dictionary) -> WeaponData:
	var probe := WeaponData.new()
	for key in overrides:
		probe.set(key, overrides[key])
	return probe


## Must come back true only when is_valid() really rejects the degenerate
## value, which is what makes "is_valid() is true" on pistol.tres meaningful.
func _is_valid_rejects(overrides: Dictionary) -> bool:
	return not _probe(overrides).is_valid()


func _finish() -> void:
	print("=== RESULT: %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)


## Ends the run on a precondition the rest of the check cannot be evaluated
## against. Without this the field assertions below would dereference a null
## resource and the runner would report a crash instead of a named failure.
func _bail(reason: String) -> void:
	print("FATAL: %s" % reason)
	_finish()
	quit(1)


func _initialize() -> void:
	print("=== weapon data ===")

	print("-- %s must load as a WeaponData" % _PISTOL_PATH)
	var res: Resource = load(_PISTOL_PATH)
	if res == null:
		_bail("cannot load %s" % _PISTOL_PATH)
		return
	var script_res := res.get_script() as Script
	_check(res is WeaponData, "pistol.tres is a WeaponData",
		"(script=%s)" % ("none" if script_res == null else script_res.resource_path))
	var data := res as WeaponData
	if data == null:
		_bail("pistol.tres is not a WeaponData, the field checks below would be meaningless")
		return

	print("-- the values the design fixes for the pistol")
	# Each of these turns red on a single field edit in pistol.tres.
	_check(data.display_name == "Pistol", "display_name is \"Pistol\"",
		"(got \"%s\")" % data.display_name)
	_check(data.damage == 30.0, "damage is 30.0", "(got %.4f)" % data.damage)
	_check(data.rounds_per_minute == 120.0, "rounds_per_minute is 120.0",
		"(got %.4f)" % data.rounds_per_minute)
	_check(data.magazine_size == 10, "magazine_size is 10",
		"(got %d)" % data.magazine_size)
	_check(data.reload_time == 1.2, "reload_time is 1.2", "(got %.4f)" % data.reload_time)
	_check(data.projectile_speed == 40.0, "projectile_speed is 40.0",
		"(got %.4f)" % data.projectile_speed)
	_check(data.projectile_radius == 0.08, "projectile_radius is 0.08",
		"(got %.4f)" % data.projectile_radius)
	_check(data.projectile_lifetime == 3.0, "projectile_lifetime is 3.0",
		"(got %.4f)" % data.projectile_lifetime)
	# Not written in pistol.tres, so this pins the script's own default: it is
	# what Task 5 feeds into the projectile material, and nothing else in the
	# project would notice a change to it.
	_check(data.projectile_color == Color(0.15, 0.15, 0.15),
		"projectile_color is the script default Color(0.15, 0.15, 0.15)",
		"(got %s)" % data.projectile_color)

	# PROJECT.md 9.8 makes this a game rule rather than a technical detail: a
	# hitscan weapon would remove the dodge window the bullet travel creates.
	_check(data.projectile_speed > 0.0 and is_finite(data.projectile_speed),
		"projectile speed is finite and non-zero, so the bullet travels and can be dodged",
		"(%.1f m/s; a pistol round covers 15 m in %.3f s)" % [
			data.projectile_speed, 15.0 / data.projectile_speed])

	print("-- derived fire interval")
	_check(_close(data.seconds_between_shots(), 0.5),
		"seconds_between_shots() is 0.5 s at 120 rpm", "(got %.6f, tol %.4f)" % [
			data.seconds_between_shots(), _EPS])
	# The half above could also be satisfied by a method that always returns
	# 0.5. Halving the fire rate must halve the interval, which a constant
	# cannot do.
	_check(_close(_probe({"rounds_per_minute": 60.0}).seconds_between_shots(), 1.0),
		"seconds_between_shots() follows the fire rate, it is not a constant",
		"(60 rpm -> %.6f s)" % _probe({"rounds_per_minute": 60.0}).seconds_between_shots())

	print("-- is_valid() can answer false, so is_valid() == true means something")
	_check(data.is_valid(), "pistol.tres reports itself valid")
	# One assertion per term of is_valid()'s condition: dropping any single
	# term from the implementation turns exactly this one red.
	_check(_is_valid_rejects({"rounds_per_minute": 0.0}),
		"a zero fire rate is rejected")
	_check(_is_valid_rejects({"magazine_size": 0}),
		"an empty magazine capacity is rejected")
	_check(_is_valid_rejects({"reload_time": 0.0}),
		"a zero reload time is rejected")
	_check(_is_valid_rejects({"damage": 0.0}),
		"zero damage is rejected")
	_check(_is_valid_rejects({"projectile_speed": 0.0}),
		"a zero projectile speed is rejected")

	print("-- burst length invariant")
	# magazine_size * seconds_between_shots(): 10 rounds at one shot per 0.5 s.
	var burst := float(data.magazine_size) * data.seconds_between_shots()
	_check(_close(burst, _EXPECTED_BURST_SECONDS),
		"a full magazine is %.1f s of continuous fire" % _EXPECTED_BURST_SECONDS,
		"(computed %.6f from magazine_size=%d and %.6f s per shot)" % [
			burst, data.magazine_size, data.seconds_between_shots()])

	_finish()
	quit(1 if _failures.size() > 0 else 0)
```

Отступы — табы, переводы строк — LF (CR = 0 во всех трёх новых файлах, как и в
существующих `.gd`; `.gitattributes` требует `eol=lf`).

---

## 5. Список утверждений: 20 штук, и что ловит каждое

| # | Утверждение | Что превращает его в красное |
|---|---|---|
| 1 | `pistol.tres is a WeaponData` | удаление `scripts/weapon_data.gd`; `script =` в `.tres`; замена скрипта на другой ресурс |
| 2 | `display_name is "Pistol"` | правка `display_name` в `.tres` |
| 3 | `damage is 30.0` | `damage = 31.0` в `.tres` (**доказано, §6**) |
| 4 | `rounds_per_minute is 120.0` | `rounds_per_minute` в `.tres` |
| 5 | `magazine_size is 10` | `magazine_size = 12` в `.tres` (**доказано, §6**) |
| 6 | `reload_time is 1.2` | `reload_time` в `.tres` |
| 7 | `projectile_speed is 40.0` | `projectile_speed` в `.tres` (в т.ч. 0 → хитскан) |
| 8 | `projectile_radius is 0.08` | `projectile_radius` в `.tres` |
| 9 | `projectile_lifetime is 3.0` | `projectile_lifetime` в `.tres` |
| 10 | `projectile_color` = дефолт `Color(0.15,0.15,0.15)` | смена дефолта в `weapon_data.gd` (в `.tres` его нет, иначе ничего бы не поймало) |
| 11 | скорость конечна и не нулевая | `projectile_speed = 0.0` или `inf` — ловит превращение оружия в хитскан |
| 12 | `seconds_between_shots()` = 0.5 при 120 rpm | смена `rounds_per_minute` в `.tres`, изменение формулы |
| 13 | `seconds_between_shots()` следует за скорострельностью (60 rpm → 1.0 с) | `return 60.0 / rounds_per_minute`, заменённый на константу (**доказано, §6**) |
| 14 | `pistol.tres reports itself valid` | любое из пяти полей обнулено в `.tres` |
| 15 | нулевая скорострельность отвергается | удаление `rounds_per_minute > 0.0 and` из `is_valid()` |
| 16 | нулевой магазин отвергается | удаление `magazine_size > 0 and` |
| 17 | нулевая перезарядка отвергается | удаление `reload_time > 0.0 and` |
| 18 | нулевой урон отвергается | удаление `damage > 0.0 and` (**доказано, §6**) |
| 19 | нулевая скорость снаряда отвергается | удаление `and projectile_speed > 0.0` |
| 20 | полный магазин = 5.0 с непрерывной стрельбы | смена `magazine_size` **или** `rounds_per_minute` по отдельности: величина пересчитывается из полей ресурса (**доказано, §6**: `magazine_size = 12` → 6.0 с) |

Утверждения 11 и 13–19 — негативные половины. Без них набор 1–12, 14, 20
проходил бы и для метода, который возвращает жёстко зашитые `0.5` и `true`.
Именно поэтому «падает на 13-й» и «падает на 18-й» — это отдельные доказательства,
а не пересказ §6.

Что проверка **намеренно не** утверждает: значения дефолтов у свежего
`WeaponData.new()` (кроме используемых как база для проб). Дефолты — часть
интерфейса, но балансировка Фазы 2 может их менять, и тогда краснеет проверка
без реальной поломки. Значения, важные для игры, зафиксированы на ресурсе
(2–9), а дефолт, который иначе никем не используется (10), — отдельно.

---

## 6. Прогоны: оба падающих и оба проходящих

Все запуски — `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1`,
как требует брифа (голый `.\tools\run_checks.ps1` на этой машине не работает,
политика выполнения Restricted).

### 6.0 Падение A — проверка написана, ни скрипта, ни ресурса

`run_checks.ps1 weapon_data` → **FAIL, код 1**

```
weapon_data    FAIL  (exit code 1)
    Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
    SCRIPT ERROR: Parse Error: Could not find type "WeaponData" in the current scope.
       at: GDScript::reload (res://tests/weapon_data.gd:53)
    SCRIPT ERROR: Parse Error: Identifier "WeaponData" not declared in the current scope.
       at: GDScript::reload (res://tests/weapon_data.gd:54)
    SCRIPT ERROR: Parse Error: Cannot infer the type of "probe" variable because the value doesn't have a set type.
       at: GDScript::reload (res://tests/weapon_data.gd:54)
    SCRIPT ERROR: Parse Error: Could not find type "WeaponData" in the current scope.
       at: GDScript::reload (res://tests/weapon_data.gd:90)
    SCRIPT ERROR: Parse Error: Could not find type "WeaponData" in the current scope.
       at: GDScript::reload (res://tests/weapon_data.gd:92)
    SCRIPT ERROR: Parse Error: Cannot infer the type of "data" variable because the value doesn't have a set type.
       at: GDScript::reload (res://tests/weapon_data.gd:92)
    SCRIPT ERROR: Parse Error: Cannot infer the type of "burst" variable because the value doesn't have a set type.
       at: GDScript::reload (res://tests/weapon_data.gd:155)
    ERROR: Failed to load script "res://tests/weapon_data.gd" with error "Parse error".
       at: load (modules/gdscript/gdscript_resource_format.cpp:46)

RESULT: 0 passed, 1 failed, 0 skipped
EXITCODE=1
```

Падение по причине, отличной от ожидаемой планом: скрипт ещё не создан, поэтому
`class_name WeaponData` не зарегистрирован в `.godot/global_script_class_cache.cfg`
и парсер падает раньше, чем доходит до строки с `load()`. Это важно: **проверка
падает и на этапе парсинга**, а не молча проходит. Чтобы получить падение
именно по отсутствию ресурса, скрипт был создан, а кэш классов обновлён прогоном
`--import`, и проверка запущена снова при всё ещё отсутствующем `.tres`:

### 6.1 Падение B — скрипт есть, `pistol.tres` ещё нет (ожидаемое планом)

`run_checks.ps1 weapon_data` → **FAIL, код 1**

```
weapon_data    FAIL  (exit code 1)
    Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
    === weapon data ===
    -- res://data/weapons/pistol.tres must load as a WeaponData
    FATAL: cannot load res://data/weapons/pistol.tres
    === RESULT: 0 checks, 0 failed ===
    ERROR: Cannot open file 'res://data/weapons/pistol.tres'.
       at: load (scene/resources/resource_format_text.cpp:1442)
    GDScript backtrace (most recent call first):
           [0] _initialize (res://tests/weapon_data.gd:85)
    ERROR: Failed loading resource: res://data/weapons/pistol.tres.
       at: _load (core/io/resource_loader.cpp:317)
    GDScript backtrace (most recent call first):
           [0] _initialize (res://tests/weapon_data.gd:85)

RESULT: 0 passed, 1 failed, 0 skipped
EXITCODE=1
```

Ровно то, что предсказывает Step 2: `FATAL`, код 1, без краша интерпретатора.

### 6.2 Прохождение A — ресурс создан

`run_checks.ps1 weapon_data` → **PASS, код 0**, `RESULT: 1 passed, 0 failed, 0 skipped`.

Полный набор сразу после этого (и повторно в самом конце работы, §6.7):

```
smoke          PASS
movement       PASS
input_actions  PASS
input_gate     PASS
weapon_data    PASS
integrity      PASS
weapon         [SKIP]  (tests\weapon.gd not present)
projectile     [SKIP]  (tests\projectile.gd not present)
enemies        [SKIP]  (tests\enemies.gd not present)
waves          [SKIP]  (tests\waves.gd not present)
save           [SKIP]  (tests\save.gd not present)
progression    [SKIP]  (tests\progression.gd not present)

RESULT: 6 passed, 0 failed, 6 skipped
EXITCODE=0
```

`[WARN]` — 0 вхождений, `[FAIL]` — 0 вхождений (проверено подсчётом regex по
перехваченному выводу).

### 6.3 Мутация 1 — `damage` 30.0 → 31.0

Хэши до мутации:
`pistol.tres` = `5D06218768E8D7B3F302ECAC5DFA7BEA3AFD00600A28719AC809A522258B4154`

Первый прогон с мутацией дал нужное падение, **но вскрыл дефект в самой
проверке**: в строке с допуском использовался формат `%g`, которого GDScript не
поддерживает. Стока не отрисовалась, напечаталась как есть и вызвала
`ERROR: String formatting error: unsupported format character.` Проверку это не
сломало (логика утверждения была верной, красным стало нужное), но оставлять
ошибку движка в выводе нельзя. Исправлено на `%.4f`, после чего прогон повторён.

Чистый прогон с мутацией → **FAIL, код 1**:

```
      [FAIL] damage is 30.0 (got 31.0000)
      ...
      [PASS] seconds_between_shots() is 0.5 s at 120 rpm (got 0.500000, tol 0.0001)
      [PASS] seconds_between_shots() follows the fire rate, it is not a constant (60 rpm -> 1.000000 s)
      ...
      === RESULT: 20 checks, 1 failed ===
      FAILURE: damage is 30.0 (got 31.0000)

RESULT: 0 passed, 1 failed, 0 skipped
EXITCODE=1
```

Ровно одно красное утверждение, именно то, которое должно. Восстановлено →
`pistol.tres` = `5D06218768E8D7B3F302ECAC5DFA7BEA3AFD00600A28719AC809A522258B4154`
**побайтово совпал**, прогон снова зелёный (код 0).

### 6.4 Мутация 2 — `magazine_size` 10 → 12

**FAIL, код 1**, и красных сразу два — независимых:

```
      [FAIL] magazine_size is 10 (got 12)
      ...
      [FAIL] a full magazine is 5.0 s of continuous fire (computed 6.000000 from magazine_size=12 and 0.500000 s per shot)
      === RESULT: 20 checks, 2 failed ===
        FAILURE: magazine_size is 10 (got 12)
        FAILURE: a full magazine is 5.0 s of continuous fire (computed 6.000000 from magazine_size=12 and 0.500000 s per shot)

RESULT: 0 passed, 1 failed, 0 skipped
EXITCODE=1
```

Это и есть доказательство, что инвариант длины очереди действительно
**вычисляется из полей**, а не повторяет `magazine_size == 10`: `12 * 0.5 = 6.0`
считается самим ресурсом. Восстановлено побайтово (тот же SHA-256), снова зелёное.

### 6.5 Мутация 3 — из `is_valid()` убран член `damage > 0.0`

Правка в `scripts/weapon_data.gd`, а не в данных — чтобы доказать, что
негативные утверждения 15–19 не зелёные по построению.

**FAIL, код 1**, ровно одно красное:

```
      [FAIL] zero damage is rejected
      === RESULT: 20 checks, 1 failed ===
      FAILURE: zero damage is rejected

RESULT: 0 passed, 1 failed, 0 skipped
EXITCODE=1
```

Остальные четыре «отвергается» остались зелёными — по одному члену на
утверждение. Восстановлено побайтово: `scripts/weapon_data.gd` =
`D7D0A4C024261C6AAFA5DA4D3A91F6D58F4DF3EC6D13C7BA96776ACC1A2F4026`.

### 6.6 Мутация 4 — `seconds_between_shots()` зашита на `return 0.5`

Самая показательная мутация: она имитирует ровно тот дефект, ради которого
существует утверждение 13.

**FAIL, код 1**:

```
      [PASS] seconds_between_shots() is 0.5 s at 120 rpm (got 0.500000, tol 0.0001)
      [FAIL] seconds_between_shots() follows the fire rate, it is not a constant (60 rpm -> 0.500000 s)
      ...
      [PASS] a full magazine is 5.0 s of continuous fire (computed 5.000000 from magazine_size=10 and 0.500000 s per shot)
      === RESULT: 20 checks, 1 failed ===
      FAILURE: seconds_between_shots() follows the fire rate, it is not a constant (60 rpm -> 0.500000 s)

RESULT: 0 passed, 1 failed, 0 skipped
EXITCODE=1
```

Утверждение 12 осталось зелёным — константа его удовлетворяет. Красным стало
только 13. Восстановлено побайтово (тот же SHA-256 скрипта).

### 6.7 Прохождение B — финальное состояние

Хэши всех трёх файлов после всех мутаций и восстановлений:

```
data/weapons/pistol.tres   5D06218768E8D7B3F302ECAC5DFA7BEA3AFD00600A28719AC809A522258B4154
scripts/weapon_data.gd     D7D0A4C024261C6AAFA5DA4D3A91F6D58F4DF3EC6D13C7BA96776ACC1A2F4026
tests/weapon_data.gd       291AB23C0DE2D56E7E2847F85114699F2E2F1AE7F7D42A61AEDBC5B6D5D0C56A
```

(Хэш теста отличается от первоначального только из-за исправления `%g` → `%.4f`;
он зафиксирован после исправления и с тех пор не менялся.)

Полный набор → `RESULT: 6 passed, 0 failed, 6 skipped`, код 0, `[WARN]` — 0.

---

## 7. Прямой запуск tests/weapon_data.gd через Godot

`2>&1` в PowerShell 5.1 не используется. `Start-Process` с
`-RedirectStandardOutput` / `-RedirectStandardError` во временный каталог,
`.Handle` захвачен до выхода, `WaitForExit(120000)` + параметрический
`WaitForExit()` для EOF.

`godot --headless --path . --script res://tests/weapon_data.gd` → **код 0**,
stderr пуст, stdout:

```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

=== weapon data ===
-- res://data/weapons/pistol.tres must load as a WeaponData
  [PASS] pistol.tres is a WeaponData (script=res://scripts/weapon_data.gd)
-- the values the design fixes for the pistol
  [PASS] display_name is "Pistol" (got "Pistol")
  [PASS] damage is 30.0 (got 30.0000)
  [PASS] rounds_per_minute is 120.0 (got 120.0000)
  [PASS] magazine_size is 10 (got 10)
  [PASS] reload_time is 1.2 (got 1.2000)
  [PASS] projectile_speed is 40.0 (got 40.0000)
  [PASS] projectile_radius is 0.08 (got 0.0800)
  [PASS] projectile_lifetime is 3.0 (got 3.0000)
  [PASS] projectile_color is the script default Color(0.15, 0.15, 0.15) (got (0.15, 0.15, 0.15, 1.0))
  [PASS] projectile speed is finite and non-zero, so the bullet travels and can be dodged (40.0 m/s; a pistol round covers 15 m in 0.375 s)
-- derived fire interval
  [PASS] seconds_between_shots() is 0.5 s at 120 rpm (got 0.500000, tol 0.0001)
  [PASS] seconds_between_shots() follows the fire rate, it is not a constant (60 rpm -> 1.000000 s)
-- is_valid() can answer false, so is_valid() == true means something
  [PASS] pistol.tres reports itself valid 
  [PASS] a zero fire rate is rejected 
  [PASS] an empty magazine capacity is rejected 
  [PASS] a zero reload time is rejected 
  [PASS] zero damage is rejected 
  [PASS] a zero projectile speed is rejected 
-- burst length invariant
  [PASS] a full magazine is 5.0 s of continuous fire (computed 5.000000 from magazine_size=10 and 0.500000 s per shot)
=== RESULT: 20 checks, 0 failed ===

===== STDERR =====
(пусто)
```

---

## 8. Решения там, где бриф оставлял открытым

1. **Добавление `weapon_data` в `$Tests` сделано до первого падающего прогона.**
   План требует увидеть падение на шаге 2, а добавляет имя в `$Tests` на шаге 6 —
   при его буквальном порядке фильтр `weapon_data` на шаге 2 не нашёл бы ни одного
   имени и напечатал `RESULT: 0 passed, 0 failed, 0 skipped` с кодом 0. Имя
   добавлено сразу, чтобы падение действительно было падением.

2. **Добавлены утверждения сверх обязательного минимума** (обязательными были 7
   значений + загрузка + производные + инвариант; здесь 20). Добавлены:
   `projectile_radius`, `projectile_lifetime` — они есть в списке значений
   `.tres` в плане; `projectile_color` — фиксирует дефолт скрипта, который
   `.tres` не задаёт и который до Task 5 больше никто не использует;
   «скорость конечна» — переносит игровое правило из PROJECT.md §9.8 в
   утверждение; и пять негативных проверок `is_valid()` плюс проверка
   производности интервала. Без негативных половин утверждения
   `is_valid() == true` и `seconds_between_shots() == 0.5` проходили бы и для
   заглушек — см. мутации 3 и 4, которые именно их и ловят.

3. **`_bail()` вместо инлайнового `quit(1)` после FATAL.** В `smoke.gd` при
   нечитаемом ресурсе вызывается `quit(1)` до печати сводки. Здесь сводка
   печатается и при аварийном выходе, чтобы «0 checks, 0 failed» не выглядело
   как «проверка прошла, утверждений просто не было». Хелпер `_check` при этом
   продублирован из существующих харнессов без изменений — как и требовалось.

4. **`weapon_data` добавлен между `input_gate` и `integrity`.** Ровно то, что
   просили. Побочный эффект: `integrity` — самая долгая проверка набора, и
   `weapon_data` теперь стоит перед ней, а не в конце. На результат не влияет.

5. **`script_class="WeaponData"` и `path=` без `uid=` в `.tres`** — так в плане,
   так и записано. Godot 4.7 грузит ресурс по пути без проблем; проверено
   фактическим прогоном.

6. **Дефект, найденный собственной проверкой и исправленный:** неподдерживаемый
   формат `%g` в строке детали. Описан в §6.3. Это была ошибка в моём коде, а не
   в данных, и она вылезла только потому, что мутационный прогон печатает весь
   список утверждений, а не только итог.

---

## 9. Что важно знать Tasks 2–5 (не блокер, но ловушка)

`run_checks.ps1` запускает `--import` **только когда файла кэша классов нет
вообще** (свежий клон). На машине, где `.godot/global_script_class_cache.cfg`
уже существует, новый `class_name` в него не попадает, пока импорт не
прогнать вручную. Проверка, ссылающаяся на свежий класс, до этого момента падает
на этапе парсинга, а не на своих утверждениях.

В этой задаче обойдено одним ручным прогоном:

```
E:\Godot\Godot_v4.7.2-stable_win64.exe --headless --path . --import
```

после чего кэш содержит `InputGate` и `WeaponData`. Ничего в `run_checks.ps1`
кроме `$Tests` не менялось, как и было указано.

**Tasks 2 и 3 добавят `Hurtbox`, `Projectile` и `Pistol`.** Их проверки
ссылаются на эти имена, поэтому после создания каждого такого скрипта нужно
один раз прогнать `--import`, иначе проверка упадёт с `Parse Error`, а не с
своим `[FAIL]`. Ранжированный список теперь выглядит так:

```
smoke, movement, input_actions, input_gate, weapon_data, integrity,
weapon, projectile, enemies, waves, save, progression
```

---

## 10. Git

```
 M tools/run_checks.ps1
?? data/
?? scripts/weapon_data.gd
?? scripts/weapon_data.gd.uid
?? tests/weapon_data.gd
?? tests/weapon_data.gd.uid
```

`git diff --cached --name-only` — пусто, `git log -1` — `11541c8` (не менялся).
**`git add` и `git commit` не выполнялись.** Проект-владелец коммитит сам.

Два файла `.uid` созданы не мной: их сгенерировал сам Godot при `--import`
(`scripts/weapon_data.gd.uid` → `uid://cs6ut023jdyh0`,
`tests/weapon_data.gd.uid` → `uid://bn66g7uuskt8m`). Вручную я их не создавал и
не удалял. Это соответствует конвенции репозитория: у каждого существующего
`.gd` есть отслеживаемый `.uid`, поэтому их нужно взять вместе с новыми
скриптами при коммите.

---

## 11. Доработка `run_checks.ps1`: импорт не только при отсутствующем кэше

**Статус: DONE.** Отдельный целевой фикс поверх §1–10, по просьбе контроллера.
Ничего, кроме блока импорта в `tools/run_checks.ps1`, не менялось.

### 11.1 Дефект

`run_checks.ps1` запускал `--import` только когда
`.godot\global_script_class_cache.cfg` **отсутствовал**. Кэш устаревает и не
исчезая: после добавления нового `class_name` файл на месте, класс в него не
попал, и любой скрипт, ссылающийся на этот класс, умирает на этапе парсинга:

```
SCRIPT ERROR: Parse Error: Could not find type "WeaponData" in the current scope.
```

Раннер честно отчитывается `weapon_data FAIL (exit code 1)`, но это падение
чужих рук: проверка не может сказать, что с ней не так, потому что не дошла ни
до одного утверждения. Ровно тот режим, который проект всё это время вычищал.
`Hurtbox`, `Projectile` и `Pistol` в задачах 2 и 3 попали бы ровно в него.

### 11.2 Что изменено

Один блок, на прежнем месте: после проверки наличия движка, до цикла по
`$Tests`. Разница — условие импорта и одно сообщение.

```diff
     $classCache = Join-Path $RepoRoot '.godot\global_script_class_cache.cfg'
-    if (-not (Test-Path -LiteralPath $classCache -PathType Leaf)) {
-        Write-Output "importing project (global class cache missing) ..."
+    $cacheFile = Get-Item -LiteralPath $classCache -ErrorAction SilentlyContinue
+    ...поиск самого свежего исходника...
+    $needsImport = $null -eq $cacheFile -or
+        ($null -ne $newestSource -and $newestSource.LastWriteTimeUtc -gt $cacheFile.LastWriteTimeUtc)
+    if ($needsImport) {
+        Write-Output "importing project (class cache missing or stale) ..."
         & $GodotBin --headless --path . --import | Out-Null
     }
```

Прежний комментарий дополнен: теперь он описывает и устаревший кэш, а не только
отсутствующий, и объясняет, почему устаревание опаснее отсутствия. Формулировка
сообщения изменена на «missing or stale», потому что теперь срабатывают оба
случая. Ветка «кэша нет вообще» не удалена, а стала первым дизъюнктом
`$needsImport`.

Не тронуто (проверено `git diff -U1`: два хунка, `$Tests` — из §1, и этот блок):
`$Tests` и его порядок, `$CheckTimeoutMs`, логика таймаута и kill, кэширование
`.Handle`, уникальные имена временных файлов, маркер `(?m)[FAIL]` с
односторонним переходом PASS→FAIL, поведение SKIP, сообщение об отсутствующем
Godot, формат строки `RESULT`.

### 11.3 Подход и одна вынужденная поправка к брифу

Правило устаревания взято из брифа дословно: кэш устарел, если его нет **или**
он старше любого исходника. Отличается только реализация сканирования, и
незначительно — по двум причинам, обе измерены.

**1. `-Include` вместе с `-LiteralPath` не фильтрует.** Код из брифа на этой машине
(Windows PowerShell 5.1) вернул **все 172 файла репозитория**, а самым свежим
оказался `project.godot`:

| Вариант | Объектов | Время | Самый свежий |
|---|---|---|---|
| `-LiteralPath … -Include *.gd,*.tscn,*.tres` (из брифа) | 172 | 23 мс | `project.godot` |
| Отсечение по расширению явно | 14 | 16 мс | `scripts/weapon_data.gd` |

То есть фильтр молча превращался в «любой файл репозитория»: правка
`CHECKLIST.md` или `.gitattributes` считалась поводом для двухсекундного
импорта, а настоящий класс он всё равно находил — по счастливому совпадению,
потому что `project.godot` менялся позже скриптов. Поэтому `-Include` заменён
на явную проверку `$_.Extension -in '.gd', '.tscn', '.tres'`.

**2. `.godot` отсекается по каталогу, а не по содержимому.** Сейчас в `.godot`
136 файлов из 172, и это доля будет расти вместе с импортируемыми ассетами
(сейчас это `.import` для `main.tscn` и `player.tscn`). Исключение после обхода
ничего не экономит — обход уже состоялся. Поэтому корневые элементы репозитория
берутся без рекурсии, `.godot` отбрасывается по имени, и рекурсия идёт только по
оставшимся путям:

```powershell
$sourceRoots = @(Get-ChildItem -LiteralPath $RepoRoot -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne '.godot' } |
    Select-Object -ExpandProperty FullName)
```

`.git` в обход не попадает и сам — у него установлен скрытый атрибут, а
`Get-ChildItem` без `-Force` скрытые каталоги не рекурсирует (проверено: 0
совпадений). Один проход, `.godot` не читается совсем.

**3. Страховка на пустой массив путей.** `Get-ChildItem -LiteralPath @()` —
терминирующая ошибка привязки параметра, а `$ErrorActionPreference = 'Stop`, то
есть раннер упал бы со стектрейсом PowerShell и **без строки `RESULT`**. Пока в
корне есть `project.godot`, ветка недостижима, но это единственная точка входа ко
всем проверкам, поэтому добавлена проверка `$sourceRoots.Count -gt 0`.

**4. `LastWriteTimeUtc`, а не `LastWriteTime`.** Обе стороны сравнения берутся у
движка, который мог пережить переход на летнее время; локальное настенное время
такое сравнение переживает не всегда.

Итоговая цена решения — 16 мс против 26 с полного прогона набора: это
незаметно. Выигрыш не в миллисекундах сегодня, а в том, что `.godot` не
раздувает сканирование по мере добавления ассетов.

### 11.4 Проверки

Все запуски — `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1`
(политика выполнения Restricted). Время — полный прогон вместе с шестью
процессами Godot.

**V1. Устаревший кэш (тот самый сломанный случай).** Кэш сохранён в
`%TEMP%\opencode`, в него записано `[]`, и его `LastWriteTimeUtc` отмотан на час
назад — так выглядит кэш, написанный до появления `scripts/weapon_data.gd`:
содержимое устарело, и файл старше исходника.

```
CACHE   mtime(utc)=2026-10-07 01:58:04Z content=<[]>
NEWEST  mtime(utc)=2026-10-07 02:51:49Z E:\projects\VibeFPS\scripts\weapon_data.gd
```

```
importing project (class cache missing or stale) ...
smoke          PASS
movement       PASS
input_actions  PASS
input_gate     PASS
weapon_data    PASS
integrity      PASS
weapon         [SKIP]  (tests\weapon.gd not present)
projectile     [SKIP]  (tests\projectile.gd not present)
enemies        [SKIP]  (tests\enemies.gd not present)
waves          [SKIP]  (tests\waves.gd not present)
save           [SKIP]  (tests\save.gd not present)
progression    [SKIP]  (tests\progression.gd not present)

RESULT: 6 passed, 0 failed, 6 skipped
ELAPSED_MS=26084
EXITCODE=0
```

Строка импорта на месте, `weapon_data` больше не умирает на парсинге. После
импорта кэш содержит `InputGate` и `WeaponData` (338 байт,
`mtime=2026-10-07 02:58:08Z`).

**V2. Тёплый кэш (сразу после V1).** Импорта быть не должно, зелень — обязана.

```
smoke          PASS
movement       PASS
input_actions  PASS
input_gate     PASS
weapon_data    PASS
integrity      PASS
... 6 SKIP ...

RESULT: 6 passed, 0 failed, 6 skipped
ELAPSED_MS=24250
EXITCODE=0
IMPORT_LINE_PRESENT=False
```

Разница V1 − V2 = **1.83 с** — это и есть цена импорта, которую раннер больше не
платит на каждом запуске.

**V3. Регрессии (после восстановления кэша из резервной копии).**

```
RESULT: 6 passed, 0 failed, 6 skipped
ELAPSED_MS=24270
EXITCODE=0
IMPORT_LINE_PRESENT=False  WARN_COUNT=0  FAIL_MARKERS=0
```

`smoke`, `movement`, `input_actions`, `input_gate`, `weapon_data`, `integrity` —
все PASS, `[WARN]` — 0 вхождений, `[FAIL]` — 0 вхождений.

**V4 (сверх брифа). Старая ветка «кэша нет вообще».** Файл кэша убран, запуск с
фильтром `input_gate`:

```
importing project (class cache missing or stale) ...
input_gate     PASS

RESULT: 1 passed, 0 failed, 0 skipped
EXITCODE=0
```

Ветка холодного клона жива. Время не замерялось.

### 11.5 Граница правила, найденная при проверке

Правило «новее, чем кэш» по mtime не ловит один случай: **кэш новее всех
исходников, но не содержит нужного класса**. Проверено намеренно — в кэш записано
`[]` текущим временем, то есть он «свежий»:

```
weapon_data    FAIL  (exit code 1)
    SCRIPT ERROR: Parse Error: Could not find type "WeaponData" in the current scope.
       at: GDScript::reload (res://tests/weapon_data.gd:53)
```

Класс в кэш попадает только импортом, а импорт запускается после того, как
исходник уже создан, поэтому из нормальной работы этот случай не возникает: он
достижим только если записать кэш руками. Именно поэтому в V1 пришлось отмотать
mtime кэша назад — **шаг 1 проверки в брифе, взятый буквально (записать `[]` и
сразу запустить), не сработал бы**: `Set-Content` делает кэс самым свежим файлом
репозитория, и mtime-правило решило бы, что импорт не нужен.

Ловить это дороже: пришлось бы прочитывать все `.gd` и искать в них `class_name`,
чтобы сравнить с содержимым кэша, — то есть читать весь исходный текст на
каждом запуске вместо метаданных. Эта цена в брифе не была согласована, поэтому
правило оставлено ровно таким, как задано, а граница задокументирована здесь.

### 11.6 Что изменилось для Tasks 2 и 3

Предупреждение §9 («`run_checks.ps1` запускает `--import` только когда файла кэша
классов нет вообще… после создания каждого такого скрипта нужно один раз прогнать
`--import` вручную») **больше не действует**. Ручной прогон

```
E:\Godot\Godot_v4.7.2-stable_win64.exe --headless --path . --import
```

после создания `Hurtbox`, `Projectile` и `Pistol` больше не требуется: раннер
сам увидит, что исходник новее кэша, и переимпортирует до запуска проверок.
Если импорт всё же понадобится руками — это будет означать, что исходник был
изменён с сохранением времени (инструмент, откатывающий mtime, или `git checkout`
старой ревизии с сохранённой датой), и о таком случае стоит написать сюда.

### 11.7 Git

```
 M tools/run_checks.ps1
?? data/
?? scripts/weapon_data.gd
?? scripts/weapon_data.gd.uid
?? tests/weapon_data.gd
?? tests/weapon_data.gd.uid
```

`git diff --cached --name-only` — пусто, `git log -1` — `11541c8`, не менялся.
**`git add` и `git commit` не выполнялись.** Изменение осталось unstaged в
рабочем дереве; коммитит проект-владелец. Изменён ровно один файл —
`tools/run_checks.ps1` (`git diff --stat`: `46 insertions(+), 7 deletions(-)`,
два хунка, второй — правка `$Tests` из §1 этого же отчёта).
