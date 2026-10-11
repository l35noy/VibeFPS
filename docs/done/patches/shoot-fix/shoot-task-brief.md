> **Назначение:** Бриф разовой мини-работы (патча).

# Task SHOOT: снаряд из ствола + фикс траектории (SHOOT-1) и выстрел на старте (SHOOT-2)

> **For agentic workers:** implements this task in the VibeFPS project. Follow every step. No git mutations — owner commits. TDD: red → green, then mutation proof.

**Goal:** Снаряд пистолета вылетает из ствола (Muzzle-точка), летит прямо независимо от поворота камеры/движения игрока после выстрела; пистолет не стреляет при залипшей LMB на кадре 0.
**Architecture:** два независимых дефекта в `scripts/pistol.gd`, чинятся раздельно в одной задаче: (1) спавн/родительство снаряда — через отдельный Muzzle-узел + `top_level` для отвязки от трансформа родителя; (2) выстрел — arming-защёлка для первого нажатия LMB.
**Tech Stack:** Godot 4.7.2, GDScript, PowerShell (нет bash). Проверки: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1`.

## Root cause (доказано расследованием, read-only, не переоткрывать)

### SHOOT-1 — снаряд «приклеен» к камере
- `pistol.gd:82-83` level-поллинг `Input.is_action_pressed("fire")` → `try_fire()` → `_instantiate_projectile()` (`pistol.gd:225-249`).
- `_muzzle()` (`pistol.gd:208-216`): `fire_rate_source` null в игре → `get_viewport().get_camera_3d()` → **камера**. Фолбэк намеренный, пинуется `tests/weapon.gd:337-343`.
- `pistol.gd:246`: `direction := -muzzle.global_transform.basis.z` — читается **один раз** в момент выстрела (направление прицеливания от камеры — намеренно: пистолет довёрнут +0.1 rad yaw / -0.05 rad pitch относительно камеры, `player.tscn:40`).
- `pistol.gd:247`: `muzzle.add_child(projectile)` — **родитель = камера**.
- `projectile.gd:88`: `global_position += _direction * (speed * delta)`; `_direction` пишется один раз (`projectile.gd:79`), больше нигде не читается камера/трансформ — **projectile.gd корректен**, баг целиком в `pistol.gd:247`.
- Механизм: у Node3D мировой трансформ = `parent.global * local` и пересчитывается при движении родителя; запись `global_position` у привязанной ноды лишь пересчитывает `local.origin`; между тиками мировая позиция снаряда искажается трансформом родителя (`C(k+1)·C(k)⁻¹·P_k`). Поворот камеры на 0.05 rad (25 px мыши) = боковой увод 0.5 м на снаряде в 10 м — **каждый тик**. Ходьба/стрейф резинят снаряд, респавн телепортирует. Промахи/попадания тоже гнутся (Area3D overlap по глобальному трансформу).

### SHOOT-2 — выстрел без ввода на старте
- `pistol.gd:82`: level-запрос `is_action_pressed` без edge-требования и без «взведённости»; мышь захватывается до первого `_process` (`player.gd:51`); cooldown/reload стартуют с 0.0 → любой остаточный бит LMB на кадре 0 = один выстрел.
- Общего корня с SHOOT-1 **нет** (пространственный vs временно́й дефект; общий только файл и запах «live state as instantaneous truth»).
- Edge-only фикс (только `is_action_just_pressed`) **нельзя**: ломает пинанное held-button поведение (`tests/weapon.gd:672-695`). Нужна arming-защёлка.

## Global constraints (binding)

1. Godot-бинарь живёт только в `tools/run_checks.ps1` — читать оттуда; проверки только через `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 <filter>`.
2. **Никогда** `git commit`/`git add`/любые git-мутации — коммитит владелец.
3. TDD: сначала падающий тест (RED), потом фикс (GREEN). Мутационные доказательства обязательны: SHA-256 до/после побайтово идентичен; после каждой мутации проверка падает на **именованном** ассерте, после восстановления — зелено.
4. Русские «почему»-комментарии в игровых скриптах.
5. Битмаски не трогать. `player.gd`, `player.tscn`, `scripts/projectile.gd`, `scripts/enemy_contact.gd`, `scripts/range_scene.gd`, `project.godot`, `tools/run_checks.ps1` — **не трогать**.
6. Проверки: до работы `weapon` и `projectile` зелёные (эталон); после — те же + изменённые.

## Files

- Modify: `scripts/pistol.gd` (`_muzzle()` :208-216, `_instantiate_projectile()` :225-249, `try_fire()`/`can_fire()` при необходимости, `_ready()` :62-65, `_process()` :82-83, `reset_for_scene_change()` :180-184)
- Modify: `pistol.tscn` (добавить Muzzle `Marker3D` ребёнком Pistol)
- Modify: `tests/weapon.gd` (новые регрессии SHOOT-1 и SHOOT-2; правки пинанных хелперов при необходимости)
- Modify: `tests/enemies.gd` — ТОЛЬКО один ассерт проводки: в `_test_range_scene_wiring`/секции «Проводка сцены» добавить `pistol.get_node_or_null("Muzzle") != null` (шаг 2.4). Больше ничего.

## Interfaces

### SHOOT-1 — фикс

1. **`pistol.tscn`**: новый узел `Muzzle` типа `Marker3D`, ребёнок корня Pistol, позиция `(0, 0, -0.18)` — точка ствола (Frame `BoxMesh(0.05, 0.09, 0.3)` по центру, FrontSight на `(0, 0.062, -0.15)`; -0.18 = чуть за дульную кромку). Русский «почему»-комментарий нельзя в .tscn — продублируй rationale в `pistol.gd` возле `_spawn_point()`.
2. **`scripts/pistol.gd`** — разделить две роли `_muzzle()`:
   - **Прицеливание (направление)** — остаётся `_muzzle()` как есть (`fire_rate_source` → camera → self), семантика `-global_transform.basis.z` сохраняется: прицел от камеры, ~5.7°-смещения не вводить.
   - **Точка старта** — новый метод, например `_spawn_point() -> Node3D`: `get_node_or_null("Muzzle")` если есть → иначе `_muzzle()` (сохраняет фолбэк-цепочку для headless и существующих тестов) → иначе `self`. Если Muzzle-узла нет и это не тестовый харнесс — `push_warning` по конвенции проекта (`enemy_contact.gd:126`): «[pistol] нет Muzzle — снаряд стартует из камеры». (Предупреждение не должно спамить в существующих тестах: проверь, какие харнессы создают пистолет без «Muzzle», и либо добавь туда узел, либо предупреждай только когда `fire_rate_source == null`.)
   - **`_instantiate_projectile()`**: порядок строго:
     - `var muzzle := _muzzle()` (родитель для жизненного цикла и направление);
     - `var spawn := _spawn_point()` (точка старта);
     - `muzzle.add_child(projectile)` — родитель НЕ меняется (снаряд остаётся ребёнком для `queue_free`/сигналов; хелпер `_live_projectiles(muzzle)` в тестах перебирает `muzzle.get_children()` и должен продолжать работать);
     - `projectile.set_as_top_level(true)` — **отвязка от трансформа родителя** (это и есть фикс; без этого поворот камеры гнёт траекторию);
     - `projectile.global_position = spawn.global_position` — старт из ствола (после `set_as_top_level`, чтобы писать абсолютную мировую позицию);
     - `projectile.call("launch", -muzzle.global_transform.basis.z)` — направление от камеры, один раз.
   - Русский «почему»-комментарий в `_instantiate_projectile()`: объяснить механизм (мировой трансформ привязанной ноды = родительский × локальный; `global_position +=` перепривязывает локальную точку каждый кадр; `set_as_top_level(true)` отвязывает).

### SHOOT-2 — фикс

1. **`scripts/pistol.gd`**: arming-защёлка. Добавить `var _armed := false`; в `_ready()` оставить false; в `_process()` перед/вместе с fire-поллингом:
   - если `not _armed and not Input.is_action_pressed("fire")` → `_armed = true` (первое наблюдаемое отпускание взводит);
   - если `_armed and Input.is_action_pressed("fire")` → `try_fire()`.
   - `reset_for_scene_change()` (`pistol.gd:180-184`) → `_armed = false` (переход сцена→сцена не наследует залипшую кнопку).
   - Русский «почему»-комментарий: LMB может быть зажат на физическом уровне при входе в дерево (окно активации, ос) — один level-поллинг без взвода даёт выстрел без ввода.
   - Уровневое поведение (удержание = стрельба) сохраняется после первого взвода — пинанные тесты `tests/weapon.gd:672-695` остаются зелёными.
2. Если какой-то существующий тест стреляет первым же `action_press` без предшествующего release — адаптировать его (добавить `Input.action_release("fire")` + кадр перед первым нажатием) и задокументировать в отчёте. Это не ослабление: реальный первый выстрел всегда после отпускания.

## Steps

### Step 1: RED — регрессия SHOOT-1 (искривление траектории)

В `tests/weapon.gd`, рядом с `_test_shot_follows_fire_source` (:442-464), новый тест:

- Харнесс: пистолет с `fire_rate_source` = нода-прицел (переиспользовать `_new_muzzle`), НО прицел-нода должна быть ребёнком вращающейся/движущейся ноды (Pivot). Замысел: после выстрела родительская цепочка прицела поворачивается/сдвигается — снаряд обязан лететь прямо.
- Минимальный сценарий: `world → Pivot(Node3D) → muzzle(Node3D)`; пистолет на `_new_pistol(world, data, muzzle, ..)`. Выстрел (`Input.action_release("fire")` заранее; затем `action_press`). Дождаться появления снаряда (`_live_projectiles(muzzle)` — работает, т.к. родитель снаряда = muzzle). Затем зафиксировать стартовую позицию, повернуть Pivot: `pivot.rotation.y = deg_to_rad(45.0)`, сдвинуть `pivot.position = Vector3(2.0, 0.0, 0.0)`. Прогнать ~60 физических кадров (переиспользовать идиому ожидания из соседних тестов, напр. `_await_until`/кадры), сэмплируя позицию каждого кадра (или хотя бы конечную): накопленное боковое/вертикальное отклонение от прямой `start + _direction * speed * t` ≤ `_EPS`-масштаб (учесть реальный шаг 1/3 м при 40 м/с и 120 Гц; `_EPS` в этом файле 0.001 — подбери допуск под солвер, но жёсткий: цель — поймать увод 0.5 м/тик, допуск в районе сантиметров максимум).
- Ассерт должен падать на текущем коде (снаряд ребёнок muzzle → искривляется при повороте Pivot).

### Step 2: RED — регрессия SHOOT-1 (старт из ствола) + пин проводки

2.1. В `tests/weapon.gd` новый тест: пистолет с Muzzle-нодой (`Marker3D` на позиции ствола) и прицел-камерой в другом месте (реальный `Camera3D` `current = true`, отдельный от `fire_rate_source`); выстрел; ассерты:
   - `bullet.global_position == muzzle.global_position` (старт из ствола, а не из камеры) — с допуском;
   - `bullet.get_parent() == прицел-нода` (родительская схема не сломана, снаряд живёт там же) — либо, если в харнессе родитель иной, документируй;
   - направление: `moved.normalized().dot(-camera.global_transform.basis.z) > 0.99` (направление всё ещё от камеры/прицела — не из Muzzle).
   - Фолбэк-ветка: без Muzzle-ноды и `fire_rate_source = null` снаряд стартует из камеры (фолбэк-цепочка жива — не сломать `:337-343`).
2.2. Проверить: существующие пины не ослаблены и не сломаны (`:337-343` тип/null fire_rate_source, `:432-435` направление = -Z источника, `_live_projectiles` :207-212 работает, held-button :672-695). Любые необходимые правки харнесса — минимальны и задокументированы.
2.3. Проверка: `... .\tools\run_checks.ps1 weapon` и `... projectile` — новые тесты красные, старые зелёные (кроме задокументированных адаптаций).
2.4. В `tests/enemies.gd`, секция «Проводка сцены» (`_test_range_scene_wiring`, ~:1333): добавить ассерт `pistol.get_node_or_null("Muzzle") != null` с русским «почему». Проверка: `... .\tools\run_checks.ps1 enemies` — красный, пока в `pistol.tscn` нет Muzzle.

### Step 3: RED — регрессия SHOOT-2 (выстрел без ввода)

В `tests/weapon.gd`, рядом с `_test_starting_magazine` (:367-385), паттерн (обязательно `_PistolProbe` с `gate_mouse_mode = MOUSE_MODE_CAPTURED`, иначе headless-гейт закрыт и тест зелёный по неверной причине):

- `Input.action_press("fire")` **до** создания пистолета (LMB уже зажат при входе в дерево);
- создать пистолет/мир (`_new_pistol`), `_watch`, ждать ~1 c реальных кадров;
- `_check(log.fired == 0, "оружие, вошедшее в дерево с зажатым fire, не стреляет", ...)`;
- `Input.action_release("fire")`; `Input.action_press("fire")` — настоящее свежее нажатие; ждать `log.fired > 0`; `_check(.., "и оно стреляет на следующее реальное нажатие", ...)`; `Input.action_release("fire")`.

### Step 4: GREEN — реализация

Выполнить оба фикса (Interfaces выше). Затем:

- `... run_checks.ps1 weapon` — все зелёные (старые + новые);
- `... run_checks.ps1 projectile` — зелёные;
- `... run_checks.ps1 enemies` — зелёные (включая новый пин проводки);
- полный `... run_checks.ps1` — **9 passed / 0 failed / 3 skipped** (ожидание; иное — разбирайся).

### Step 5: Мутационные доказательства (обязательно, по одному разу на мутацию)

Для каждой: ломай → `run_checks.ps1 weapon` (или нужный фильтр) → зафиксируй **именованный** падающий ассерт → восстанови побайтово → SHA-256 до/после идентичен → снова зелено.

- (a) **SHOOT-1 путь:** убрать `set_as_top_level(true)` → регрессия привязки (Step 1) краснеет;
- (b) **SHOOT-1 старт:** `_spawn_point()` принудительно вернуть `_muzzle()` (старт из камеры) → регрессия «старт из ствола» (Step 2.1) краснеет;
- (c) **SHOOT-2:** убрать защёлку (`_process` снова стреляет при `is_action_pressed` без `_armed`) → регрессия «вошло в дерево с зажатым fire» (Step 3) краснеет;
- (d) **Проводка:** убрать Muzzle из `pistol.tscn` → пин проводки (Step 2.4) краснеет (если Step 2.1 фолбэк-ветка не пересекается — проверь).

## Submission

Полный отчёт в `C:\Users\serhio\.opencode\plan\sdd\2026-10-09-vibefps-shoot-fix\shoot-report.md`:

- реализация (что и почему, оба фикса, разделение `_muzzle()`/`_spawn_point()`, top_level, защёлка);
- TDD-доказательства: RED-выводы (имена падающих ассертов), GREEN-выводы;
- мутации: команды, имена падающих ассертов, SHA-256 пары (свой файл до/после);
- полный пред- и пост-состояния `weapon`/`projectile`/`enemies`/suite;
- изменённые файлы; адаптации тестового харнесса (если были) с обоснованием;
- self-review: дифф, YAGNI, dead code;
- concerns.

Ответ — только (≤15 строк):
**Status:** DONE|DONE_WITH_CONCERNS|BLOCKED|NEEDS_CONTEXT; файлы; строка по тестам; concerns; путь отчёта.

## Constraints recap

- Не трогать: `player.gd`, `player.tscn`, `scripts/projectile.gd`, `scripts/enemy_contact.gd`, `scripts/range_scene.gd`, `project.godot`, `tools/run_checks.ps1`, `scripts/hurtbox.gd`.
- Без git-мутаций. Без субагентов. Проверки только через `run_checks.ps1`. Русские «почему»-комментарии.