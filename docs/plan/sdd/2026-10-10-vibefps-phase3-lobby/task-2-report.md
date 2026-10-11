# Task 2 Report: Автомат + след снаряда из данных (трек A)

- План: `C:\Users\serhio\.opencode\plan\2026-10-10-vibefps-phase3-lobby-plan.md`
- Брифинг: `...\task-2-brief.md`
- Репо: `E:\projects\VibeFPS`, HEAD `b7ad7c50d0db3be39419cf146ae905aed592448b`
- Исполнитель: сам (без субагентов). Ревью — контроллер.
- Статус: **DONE** (изменения не закоммичены, владелец коммитит сам)
- Инвариант T2→T3 соблюдён: `WeaponData.price` добавлен и работает; GameState/покупки не трогал.

## 1. Что сделано

### 1.1 `WeaponData.price` (scripts/weapon_data.gd)
После `display_name` добавлено:
```gdscript
@export var price: int = 0  # Очки за покупку; 0 = стартовое бесплатное (pistol)
```
Дефолт `0` = стартовое оружие бесплатно; покупное (auto) задаёт цену в своём `.tres`.

### 1.2 Пин цены в tests/weapon_data.gd
Добавлен ассерт `data.price == 0` для `pistol.tres` (который price не задаёт → проверяется дефолт скрипта). Отделён комментарием от блока конкретных значений pistol.tres.

### 1.3 `data/weapons/auto.tres` (новый)
Данные автомата ровно по брифу, с кириллическим `;`-комментарием «временный баланс владельца 2026-10-10»:

| поле | значение |
|---|---|
| display_name | `"Auto"` |
| damage | `15.0` |
| rounds_per_minute | `300.0` (интервал 0.2 с) |
| magazine_size | `36` |
| reload_time | `1.6` |
| projectile_speed | `70.0` |
| projectile_radius | `0.06` |
| projectile_lifetime | `3.0` |
| projectile_color | `Color(0.95, 0.75, 0.15, 1)` |
| price | `300` |

### 1.4 `auto.tscn` (новый)
Структура повторяет ТЕКУЩЕЕ (пересохранённое владельцем) состояние `pistol.tscn`: `Node3D` + `Frame`/`Grip`/`FrontSight` (MeshInstance3D) + `Muzzle` (Marker3D на `(0, 0, -0.18)`). Скрипт — `pistol.gd`, `data = auto.tres`, `projectile_scene = res://projectile.tscn`, **`fire_rate_source` не задан** (фолбэк на камеру, как у пистолета). Заголовок с `uid="uid://c9fj2nkq5vt3m"`, у узлов `unique_id`, transform-формат — как в текущем `pistol.tscn`.

Материалы контрастные: корпус/рукоять — тёмно-синие (`Color(0.12,0.16,0.36)` / `Color(0.08,0.11,0.28)`), целик — жёлто-оранжевый (`Color(1,0.62,0.12)`).

### 1.5 `Projectile.radius`/`color` + data-driven `_setup_trail()` (scripts/projectile.gd)
Новые экспорты с дефолтами, сохраняющими прежний визуал:
```gdscript
@export var radius: float = 0.08
@export var color: Color = Color(0.15, 0.15, 0.15)
```
`_setup_trail()` переведён с литералов на эти поля:
- радиус меша `sphere.radius = radius`, `sphere.height = radius * 2.0`;
- цвет материала `trail_color = color; trail_color.a = _TRAIL_PEAK_ALPHA; mat.albedo_color = trail_color`.

Сцена может дать свою заготовку шлейфа (узел `Trail` с мешем и материалом), но геометрия/цвет приводятся к данным оружия **локальной копией** (`duplicate()`) через guard `resource_local_to_scene`. Причина: `SphereMesh`/`StandardMaterial3D` из `.tscn` — ресурсы, общие для всех инстансов сцены; без копии правка радиуса/цвета в `_setup_trail()` у одного снаряда перекрасила бы след у всех. Это прямо защищает инвариант «поведение/визуал пистолета не меняется».

Заодно удалена ставшая ненужной константа `_TRAIL_COLOR` и обновлён doc-комментарий метода. Логика `if is_zero_approx(mat.albedo_color.a)` заменена на безусловную установку альфы (теперь она всегда известна из data).

### 1.6 Передача radius/color (scripts/pistol.gd)
В `_instantiate_projectile()` рядом с `speed/damage/lifetime`:
```gdscript
bullet.radius = data.projectile_radius
bullet.color = data.projectile_color
```
Правка документации метода расширена: «урон, скорость пули и внешний вид снаряда». DOC-CLEANUP-правки владельца не откатывались — работа шла поверх.

### 1.7 `tests/auto_weapon.gd` (новый) + `tools/run_checks.ps1`
Каркас заимствован у `tests/weapon.gd`: `_PistolProbe` (override `_mouse_mode_for_play_input()` → CAPTURED, т.к. headless не берёт курсор), `_Log`, `_new_world()`, `_new_eye()`, `_new_pistol_from_scene()` (геометрия сцены ПЕРЕНОСИТСЯ на probe, чтобы под тестом был реальный `Muzzle` из `auto.tscn`). Используется настоящий `res://projectile.tscn` (а не пересобранная в памяти сцена) — именно его шлейф и проверяется на data-driven.

Проверки (4 группы):
1. **data-контракт**: `is_valid()`, `display_name`, `seconds_between_shots()≈0.2`, `magazine_size==36`, `damage==15.0`, `price==300`, `projectile_speed==70`, `projectile_radius==0.06`, `projectile_color` жёлтый.
2. **scene-контракт**: `auto.tscn` грузится/инстанцируется, `data==auto.tres`, `projectile_scene==projectile.tscn`, `fire_rate_source==null`, `Muzzle` есть и стоит впереди.
3. **shot через реальный input-путь**: удержание `fire` → ровно один выстрел, −1 патрон; снаряд под камерой, стартовал от высоты ствола (не из глаза), несёт speed/damage/radius/color из data; **у узла `Trail` радиус сферы == `bullet.radius`** и rgb материала == `data.projectile_color`; снаряд летит вдоль forward камеры.
4. **rate limit**: первый выстрел разрешён, второй в тот же миг — отказ, следующий — не раньше 0.2 с (`>= 0.15`, `<= 0.55`) и не по кадрам; всего 2 выстрела.

В `$Tests` добавлено `"auto_weapon"` сразу после `"weapon"`.

## 2. TDD-доказательства

Все команды — только разрешённой формой:
`powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 <фильтр>`.

### 2.1 RED (`tests/auto_weapon.gd` существует, реализация ещё литеральная)

RED снят на этапе, когда `Projectile.radius/color` уже объявлены, но `_setup_trail()` ещё использует литералы (r=0.08, серый `_TRAIL_COLOR`), а `pistol.gd` ещё не передаёт поля. Runner на PASS глушит вывод, поэтому RED-прогон брался напрямую по `[FAIL]`-строкам чека; результат:

```
=== RESULT: 39 checks, 3 failed ===
  FAILURE: the projectile carries the auto's radius from the data (got 0.0800)
  FAILURE: the projectile carries the auto's color from the data (got ..., want ...)
  FAILURE: the trail sphere has the data radius, so the visual follows auto.tres
```

Runner по фильтру `auto_weapon` сообщал `FAIL (exit code 1)`.

> Замечание к брифу: ожидаемое «файла нет → FAIL» буквально недостижимо — `run_checks.ps1` (строки 150-155) отдаёт отсутствующий `tests\<name>.gd` как `[SKIP]`, не `[FAIL]` (это задокументировано в самом скрипте). RED поэтому доказан на уровне ассертов, а не «файл отсутствует».

### 2.2 GREEN

После всех правок:
```
powershell ... .\tools\run_checks.ps1 auto_weapon
auto_weapon    PASS
RESULT: 1 passed, 0 failed, 0 skipped
```

### 2.3 Мутация

Временно убраны две строки передачи в `pistol.gd::_instantiate_projectile()`:
```gdscript
bullet.radius = data.projectile_radius
bullet.color = data.projectile_color
```
→ тот же прогон `auto_weapon` вернул те же 3 `[FAIL]` (radius 0.08, цвет по умолчанию, серый материал шлейфа), `FAIL (exit code 1)`. Строки возвращены → снова `PASS`.

Это подтверждает, что зелёный цвет теста держится именно на передачи данных в снаряд, а не на совпадении дефолтов.

### 2.4 Пин цены
Для `tests/weapon_data.gd` отдельный RED не снимался: брифом он не обязателен, а `price` с дефолтом `0` совпадает с `pistol.tres`, который поле не задаёт — ассерт проходит сразу (это проверка дефолта, не поведения). `weapon_data` зелёный (см. полный прогон).

## 3. Верификация (полный сьют)

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
progression    [SKIP]  (tests\progression.gd not present)

RESULT: 11 passed, 0 failed, 2 skipped
```

`waves`/`progression` — SKIP: файлов нет (по плану их создаёт Task 3/6), не регрессия. Старые сьюты не задеты: дефолты новых полей дают прежний визуал/поведение пистолета.

## 4. Изменённые/созданные файлы

Изменены (моя часть):
- `scripts/weapon_data.gd` — `price`
- `tests/weapon_data.gd` — пин `price == 0`
- `scripts/projectile.gd` — `radius`/`color` + data-driven `_setup_trail()`, удалён `_TRAIL_COLOR`
- `scripts/pistol.gd` — передача radius/color (+ комментарий); DOC-CLEANUP-правки владельца сохранены
- `tools/run_checks.ps1` — `"auto_weapon"` в `$Tests`

Созданы:
- `data/weapons/auto.tres`
- `auto.tscn`
- `tests/auto_weapon.gd`
- `tests/auto_weapon.gd.uid` (`uid://b8ovbq7puhxu2`) — сгенерирован движком при прогоне; по конвенции репо .uid включать в коммит

Не трогал (пред-существующие правки дерева): `pistol.tscn`, `player.gd`, `project.godot`, `CHECKLIST.md`, `PROJECT.md`, `scripts/enemy_contact.gd`, `tests/weapon.gd`, `scripts/save_system.gd(+.uid)`, `tests/save.gd(+.uid)`.

## 5. Self-review — находки

1. **Мутация общего ресурса .tscn (важно).** Первая версия `_setup_trail()` мутировала `SphereMesh`/`StandardMaterial3D`, пришедшие из `projectile.tscn`; это общий ресурс на все инстансы, и цвет автомата протёк бы на пистолет. Исправлено дублированием через guard `resource_local_to_scene`. Именно это и ловит проверка «trail radius == bullet.radius» в паре с дефолтным пистолетом.
2. **Emission шлейфа.** `_setup_trail()` управляет только `albedo_color`; в `projectile.tscn` у материала включена серая эмиссия. То есть rgb следа автомата соответствует данным, но собственное свечение остаётся серым. Не блокирует (бриф требует `albedo`/цвет, а не emission), но если нужен полностью жёлтый отсвет — это отдельная правка `projectile.tscn`, вне объёма Task 2. Отмечено для контроллера.
3. **Ассерт сферы на `bullet.radius`, а не на литерал 0.06.** Сделано намеренно: так визуал связан с данными, а не с магическим числом; проверку самих данных (radius==0.06) держит data-контракт. Двойное покрытие без дублирования смысла.
4. **line 268 в `_test_scene_contract`**: `barrel.position.z < -0.1` — проверяется, что Muzzle впереди; конкретное `-0.18` пиннит data-контракт значения через `_EXPECTED` не здесь; значение берётся сценой. Достаточно для «ствол впереди».
5. **`_WAIT_CAP_SECONDS`/tolerance**: тайминги меряются по `Time.get_ticks_msec()` с потолком 15 с и широким окном (0.15-0.55 при номинале 0.2) — headless-джиттер не флапает, а сломанный интервал (напр. кадровый счётчик) падает.

## 6. Замечания/риски для контроллера

- **Баланс — временный** (комментарий в `auto.tres`). Любая правка чисел должна ронять `tests/auto_weapon.gd` (он хранит ожидаемые значения отдельными константами) — это и есть контракт витрины витрин.
- **Task 1 leftovers** (`save_system.*`, `save.gd` + их `.uid`) остаются в дереве незакоммиченными — не моя зона, но напоминаю, что владельцу их тоже коммитить.
- `.uid` для `auto.tscn`/`auto.tres` движок не создаёт (это сцены, uid в заголовке `auto.tscn` я задал вручную: `uid://c9fj2nkq5vt3m`). `auto.tres` uid не имеет — как и `pistol.tres`, это норма для `.tres`-ресурса без UID в проекте.
- Коммиты **не** делались; всё оставлено в рабочем дереве.
