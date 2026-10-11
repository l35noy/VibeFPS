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
