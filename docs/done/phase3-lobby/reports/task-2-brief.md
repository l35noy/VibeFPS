> **Назначение:** Бриф задачи фазы.

# Task 2 Brief: Автомат + след снаряда из данных (трек A)

Проект VibeFPS (Godot 4.7.2 stable, GDScript, Jolt). Рабочий каталог: `E:\projects\VibeFPS`.
Фаза 3 «Лобби»: после SaveSystem (Task 1, готов) добавляем ВТОРОЕ оружие — автоматический пистолет «Auto» — и делаем визуал снаряда управляемым данными оружия. Это задача про оружейную подсистему, GameState/покупки — позже (Task 3/4).

**Contract (обязательно):**
- НЕ коммитить (`git add`/`commit` не делать) — коммитит владелец.
- Никаких субагентов — вся работа сам; ревью делает контроллер после отчёта.
- Проверки — ТОЛЬКО командой: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 <фильтр>` (Godot headless; напрямую godot не запускать).
- В рабочем дереве НЕзакоммиченные чужие правки — НЕ откатывать, НЕ трогать:
  - `scripts/pistol.gd`, `tests/weapon.gd` — правки DOC-CLEANUP (только комментарии, одобрены владельцем) — работаешь ПОВЕРХ них;
  - `pistol.tscn` — ресейв владельца (в заголовке `uid="uid://cbccmghaa3ltg"`, у узлов `unique_id=`, transform-формат) — это ТЕКУЩАЯ база: `auto.tscn` делаешь по образцу текущего рабочего состояния `pistol.tscn`, не по HEAD.
- Полный отчёт писать в `C:\Users\serhio\.opencode\plan\sdd\2026-10-10-vibefps-phase3-lobby\task-2-report.md`; в финальном сообщении — короткий статус.
- Кириллица в файлах — UTF-8 (норма); console PowerShell может моджибакетить кириллицу — только отображение.

## Files
- Modify: `scripts/weapon_data.gd` (+`price`)
- Modify: `tests/weapon_data.gd` (+пин `price == 0` у пистолета)
- Create: `data/weapons/auto.tres`
- Create: `auto.tscn`
- Modify: `scripts/projectile.gd` (+`radius`/`color`)
- Modify: `scripts/pistol.gd` (передача radius/color в снаряд)
- Create: `tests/auto_weapon.gd`
- Modify: `tools/run_checks.ps1` (`$Tests` += `"auto_weapon"` после `"weapon"`)

## Interfaces (что уже есть — читать файлы)
- `WeaponData` (scripts/weapon_data.gd): поля `display_name`, `damage`, `rounds_per_minute` (интервал = 60/rpm), `magazine_size`, `reload_time`, `projectile_speed`, `projectile_radius`, `projectile_lifetime`, `projectile_color`, методы `seconds_between_shots() -> float`, `is_valid() -> bool`.
- `Pistol` (scripts/pistol.gd): скрипт-владелец оружия; `data: WeaponData`, `projectile_scene: PackedScene`, метод `_instantiate_projectile()` — создаёт снаряд (`_spawn_point()`/`_muzzle()`, устанавливает `bullet.speed/damage/lifetime`). Авто-огонь удержанием УЖЕ реализован. `reset_for_scene_change()` — полный магазин при смене сцены.
- `Projectile` (scripts/projectile.gd): `launch(direction)`, поля `speed/damage/lifetime`; метод `_setup_trail()` сейчас использует ЛИТЕРАЛЫ (SphereMesh r=0.08 и материал).
- Тестовый паттерн (tests/weapon.gd): `_PistolProbe` (gate_mouse_mode → CAPTURED), `_Log`, `_new_pistol_from_scene()`, пробный мир с полом — ЗАИМСТВОВАТЬ для `tests/auto_weapon.gd`.

## Производимые интерфейсы (точные значения — ВРЕМЕННЫЙ баланс владельца, комментировать)
- `WeaponData`: новый `@export var price: int = 0  # Очки за покупку; 0 = стартовое бесплатное (pistol)`.
- `Projectile`: новые `@export var radius: float = 0.08`, `@export var color: Color = Color(0.15, 0.15, 0.15)`; `_setup_trail()` использует `radius` и `color` вместо литералов.
- `data/weapons/auto.tres` (формат как `pistol.tres`):
  `display_name="Auto"`, `damage=15.0`, `rounds_per_minute=300.0`, `magazine_size=36`, `reload_time=1.6`, `projectile_speed=70.0`, `projectile_radius=0.06`, `projectile_lifetime=3.0`, `projectile_color=Color(0.95, 0.75, 0.15)`, `price=300`. Всё помечено как временный баланс владельца 2026-10-10.
- `auto.tscn`: копия структуры `pistol.tscn` (текущего рабочего состояния): root Node3D + узлы мешей + `Muzzle` Marker3D `(0, 0, -0.18)`; скрипт `pistol.gd`; `data = auto.tres`; `projectile_scene = res://projectile.tscn`; `fire_rate_source` НЕ задавать (фолбэк на камеру — как у пистолета); материалы корпуса — контрастные (тёмно-синий корпус, жёлто-оранжевые вставки/целик), `uid` в заголовке сгенерировать по образцу текущего pistol.tscn.

## Step 1: `price` в WeaponData + пин в tests/weapon_data.gd
В `weapon_data.gd` после `display_name`: `@export var price: int = 0  # Очки за покупку; 0 = стартовое бесплатное (pistol)`.
В `tests/weapon_data.gd` — ассерт `loaded_tres.price == 0` для `pistol.tres`.

## Step 2: Прогнать `weapon_data` — зелёный (поле с дефолтом ничего не ломает)
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 weapon_data` → PASS.

## Step 3: Создать `data/weapons/auto.tres`
Значения из «Производимые интерфейсы» (дословно). Числа — временные (комментарий в .tres в формате, принятом в pistol.tres).

## Step 4: Создать `auto.tscn`
По образцу ТЕКУЩЕГО pistol.tscn (см. Contract). Та же структура узлов и скрипт `pistol.gd`, `data = auto.tres`, контрастные материалы.

## Step 5: `Projectile.radius`/`color` + передача из `pistol.gd`
В `projectile.gd`: два экспорта (см. «Производимые интерфейсы»); `_setup_trail()` использует их вместо литералов r=0.08 и дефолтного материала.
В `pistol.gd::_instantiate_projectile()` после установки `bullet.speed/damage/lifetime` (по образцу строк 291-295): передать `bullet.radius = data.projectile_radius` и `bullet.color = data.projectile_color` (если `projectile is Projectile`).

## Step 6: `tests/auto_weapon.gd` + `$Tests`
Каркас по образцу `tests/weapon.gd` (`_PistolProbe` с gate_mouse_mode, `_Log`, `_new_pistol_from_scene` — заимствовать паттерн). Проверки:
- загрузка `auto.tres`: `is_valid()`, `seconds_between_shots()` ≈ 0.2, `magazine_size == 36`, `damage == 15.0`, `price == 300`;
- `auto.tscn` инстанцируется, `Muzzle` существует, `data == auto.tres`;
- выстрел сцены: `Input.action_press("fire")` после взведения (освобождение кнопки в начале) → `fired` один раз;
- на интервале 0.2 с снаряд стартует из `Muzzle` и летит со `speed == 70.0`;
- снаряд автомата несёт `radius == 0.06` и `color == auto.tres.projectile_color` (достать инстанс снаряда из пробного мира; поля `Projectile` читаются).
В `tools/run_checks.ps1` в `$Tests` после `"weapon"` добавить `"auto_weapon"`.

## Step 7: Прогнать `auto_weapon`, затем полный сьют
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 auto_weapon` → PASS.
Затем полный: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1` → 0 failed (старые сьюты не задеты: дефолты полей).

## TDD Evidence (в отчёте)
RED (где возможно: для price-пина RED не обязателен — дефолт не падает; обязателен для auto_weapon: файла нет → FAIL) → GREEN → мутация: например, временно убрать передачу `bullet.radius`/`bullet.color` в `pistol.gd` → тест снаряда краснеет → вернуть → зелёный. Каждая: команда + вывод.

## Инварианты проекта (не ломать)
- Снаряд: хитбокс ≥ 0.5 м, урон стакается без i-frames; `projectile` маска слоёв не меняется.
- Поведение пистолета НЕ меняется тестами: дефолты новых полей (radius 0.08, color дефолт) должны давать прежний визуал/поведение.
- `tests/projectile.gd`, `tests/weapon.gd` (существующие) остаются зелёными без правок.