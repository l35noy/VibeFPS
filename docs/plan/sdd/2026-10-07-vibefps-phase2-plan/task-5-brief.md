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
