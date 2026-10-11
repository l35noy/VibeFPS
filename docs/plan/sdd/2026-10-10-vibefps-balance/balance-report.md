# Task BALANCE — отчёт

**Итог:** тестовые пины пересчитаны под новый баланс данных владельца, `project.godot` возвращён
до байта к HEAD `7a4b13d`. Полный сьют — **9 passed / 0 failed / 3 skipped**.
Git-мутаций не делалось: `git add`/`commit` не выполнялись, всё в рабочем дереве.

Проверки запускались только через
`powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 <filter>`.

---

## 1. RED — что было красное до правок

Файлы: `tests/weapon_data.gd`, `tests/weapon.gd`, `tests/enemies.gd`, `project.godot`.
Игровой код (`scripts/*.gd`, `*.tscn`, `data/*.tres`, `tools/run_checks.ps1`, `player.gd`) не
трогался ни разу.

### `weapon_data` — 20 проверок, 6 фейлов

| # | Имя падавшего ассерта |
|---|---|
| 1 | `rounds_per_minute is 120.0 (got 150.0000)` |
| 2 | `magazine_size is 10 (got 18)` |
| 3 | `projectile_speed is 40.0 (got 70.0000)` |
| 4 | `projectile_lifetime is 3.0 (got 4.0000)` |
| 5 | `seconds_between_shots() is 0.5 s at 120 rpm (got 0.400000, tol 0.0001)` |
| 6 | `a full magazine is 5.0 s of continuous fire (computed 7.200000 from magazine_size=18 and 0.400000 s per shot)` |

### `weapon` — 150 проверок, 26 фейлов

| # | Имя падавшего ассерта |
|---|---|
| 1 | `a fresh pistol starts with a full magazine (got 18 of 10)` |
| 2 | `the magazine lost exactly one round (got 17)` |
| 3 | `magazine_changed carries the new count and the capacity (got [(17, 18)])` |
| 4 | `the projectile takes its speed from the weapon data (got 70.0 m/s)` |
| 5 | `the projectile takes its lifetime from the weapon data (got 4.0 s)` |
| 6 | `and it kept every round (got 18)` |
| 7 | `costing exactly one round (got 17)` |
| 8 | `the magazine is empty (got 8)` |
| 9 | `can_fire() is false on an empty magazine` |
| 10 | `the refused shot left the magazine at 0 (got 8)` |
| 11 | `a held fire button spends no rounds while the magazine is empty (got 18)` |
| 12 | `the magazine is full again (got 18)` |
| 13 | `magazine_changed announced the refilled magazine (got [(17, 18), …, (0, 18), (18, 18)])` |
| 14 | `and that press cost exactly one round (got 17)` |
| 15 | `precondition: nine rounds are left (got 17)` |
| 16 | `the reload refilled the magazine (got 18)` |
| 17 | `precondition: the shipped data asks for one shot per 0.5 s (got 0.4000 s)` |
| 18 | `the refused second shot cost no round (got 17)` |
| 19 | `the second shot waited at least the full interval (waited 0.405 s, want >= 0.45 s)` |
| 20 | `the gated pistol kept every round (got 18)` |
| 21 | `exactly one round was spent by the ungated press (got 17)` |
| 22 | `the magazine is untouched (got 18)` |
| 23 | `precondition: the magazine is partly spent (got 17)` |
| 24 | `the magazine is full again after a scene change (got 18)` |
| 25 | `the reset is announced, so a HUD is not left showing a stale count (got [(17, 18), (18, 18)])` |
| 26 | `the round is still in the magazine: instantiate first, decrement after (got 18 of 10)` |

Секции SHOOT-регрессий (`trajectory:`, `start point:`, `startup:`, фолбэк-ветка)
в RED были зелёными и остались нетронутыми — включая наблюдение
`worst sideways drift 0.0000 m, forward travel 34.417 m over 60 physics ticks`.

### `enemies` — 160 проверок, 14 фейлов

| # | Имя падавшего ассерта | Числа из RED |
|---|---|---|
| 1 | `max_health is 50.0 (got 60.0000)` | |
| 2 | `contact_damage is 10.0 (got 30.0000)` | |
| 3 | `move_speed is 6.0 (got 2.0000)` | |
| 4 | `10 попаданий до смерти игрока (max_health 100.0000 / contact_damage 30.0000 = 3.3333)` | |
| 5 | `max_health данных врага равен 50.0 (got 60.0000)` | |
| 6 | `contact_damage данных врага равен 10.0 (got 30.0000)` | |
| 7 | `враг начинает с 50 здоровья (data.max_health) (got 60.0000)` | |
| 8 | `после одного попадания у врага 20 здоровья (50 - 30) (got 30.0000)` | |
| 9 | `за 3 с враг сократил дистанцию до цели более чем вдвое` | `10.000 -> 5.406 м из 10.000` |
| 10 | `враг дошёл до другой стороны стены (z > 1.0): путь вёл вокруг, а не упирался в стену` | |
| 11 | `враг остановился у цели: дистанция ≤ target_desired_distance + 0.1` | `5.4063 при пороге 0.6000` |
| 12 | `после остановки не дрейфует: за 0.5 с дистанция не изменилась` | `5.4063 -> 4.4758, допуск 0.02` |
| 13 | `за 3.0 с враг сократил дистанцию до игрока более чем вдвое` | `21.378 -> 15.447 м` |
| 14 | `враг из тира дошёл до игрока и нанёс контактный урон — здоровье игрока упало` | `за 720 тиков (6.0 с) ни одного тика; HP игрока 100.0 из 100.0` |

Прочее в RED: `smoke`, `movement`, `input_actions`, `input_gate`, `integrity`, `projectile` — PASS.

---

## 2. Таблица правок

Номера строк — в итоговых файлах (`file:line`).

### `tests/weapon_data.gd`

| Строка | Было | Стало | Почему |
|---|---|---|---|
| 13 | `hardcoded to return 0.5` | `... 0.4` | Комментарий описывал ту же производную величину, что и ассерт ниже. |
| 32 | `_EXPECTED_BURST_SECONDS := 5.0` (10 × 0.5) | `:= 7.2` (18 × 0.4) | Инвариант длины очереди пересчитан под новый магазин и темп; сама формула `magazine_size * seconds_between_shots()` осталась и по-прежнему читает оба поля из ресурса. |
| 102 | `rounds_per_minute == 120.0` | `== 150.0` | Пин данных пистолета. |
| 104 | `magazine_size == 10` | `== 18` | То же. |
| 107 | `projectile_speed == 40.0` | `== 70.0` | То же. |
| 111 | `projectile_lifetime == 3.0` | `== 4.0` | То же. |
| 129 | `seconds_between_shots() is 0.5 s at 120 rpm` | `is 0.4 s at 150 rpm` | Производная от rpm; отрицательная половина (60 rpm → 1.0 с) осталась и по-прежнему отличает деление от константы. |
| 156 | `10 rounds at one shot per 0.5 s` | `18 rounds at one shot per 0.4 s` | Комментарий к формуле бурста. |

### `tests/weapon.gd`

| Строка | Было | Стало | Почему |
|---|---|---|---|
| 80 | `_EXPECTED_MAGAZINE := 10` | `:= 18` | Пин ёмкости магазина. |
| 82 | `_EXPECTED_INTERVAL := 0.5` | `:= 0.4` | Пин интервала (60/150). |
| 83 | `_EXPECTED_PROJECTILE_SPEED := 40.0` | `:= 70.0` | Пин скорости снаряда. |
| 85 | `_EXPECTED_LIFETIME := 3.0` | `:= 4.0` | Пин времени жизни снаряда. |
| 509 | `Vector2i(9, 10)` | `Vector2i(_EXPECTED_MAGAZINE - 1, _EXPECTED_MAGAZINE)` | Пара «новый счёт / ёмкость» бралась из двух зашитых чисел; теперь из той же константы ёмкости, что и остальной набор. |
| 805 | `-- ten rounds, the empty magazine…` / «the eleventh try_fire() is refused» / «no eleventh round…» | `-- full magazine, the empty magazine…` / «the try_fire() past the last round» / «no round past the last one» | Порядковые слова привязаны к числу 10. Сами ожидания (`fired >= _EXPECTED_MAGAZINE`) уже были производными. |
| 842 | `Vector2i(10, 10)` | `Vector2i(_EXPECTED_MAGAZINE, _EXPECTED_MAGAZINE)` | То же, что 509. |
| 872 | `precondition: nine rounds are left` | `precondition: a partly spent magazine is left` | «Девять» было зашито в текст ассерта. |
| 872–890 | комментарий «девять патронов… лимит истекает через 0.5 с» + `(got %d shots, the rate limit expired 0.5 s into the reload)` | комментарий про «пока в магазине есть патроны» + значение из `_EXPECTED_INTERVAL` | Числа в тексте ассерта разъехались с балансом; диапазон остался тем же (0.6 с > 0.4 с). |
| 936, 942 | `-- rate limit: the interval is the data's 0.5 s…`, `one shot per 0.5 s` | текст строится из `_EXPECTED_INTERVAL` | Ассерт остался тем же (`is_equal_approx(_data.seconds_between_shots(), _EXPECTED_INTERVAL)`), изменилось только число в тексте. |
| 1059 | `Vector2i(10, 10)` | `Vector2i(_EXPECTED_MAGAZINE, _EXPECTED_MAGAZINE)` | То же, что 509/842. |

`_EXPECTED_RELOAD_TIME := 1.2` и `_EXPECTED_DAMAGE := 30.0` не менялись — баланс их не тронул.
Замеры в секциях не менялись: `reload took 1.207 s`, `second shot after 0.405 s`,
пределы `_TIMER_TOLERANCE`/`_TIMER_EPSILON` покрывают новый интервал 0.4 с с запасом.

### `tests/enemies.gd` — пины данных

| Строка | Было | Стало | Почему |
|---|---|---|---|
| 1769 | `max_health == 50.0` | `== 60.0` | Пин данных контактного врага. |
| 1770 | `contact_damage == 10.0` | `== 30.0` | То же. |
| 1771 | `move_speed == 6.0` | `== 2.0` | То же. |
| 1765–1768 | комментарий `Design spec 7.3: the contact enemy has 50 health and 10 contact damage` | `Design spec 7.3 as rebalanced: … 60 health and 30 contact damage` | Комментарий утверждал о 50/10. |
| 526 | `max_health данных врага равен 50.0` | `== 60.0` | Дубль пина на инстансе сцены (данные читаются из `enemy_contact.tscn`, а не из файла напрямую). |
| 528 | `contact_damage данных врага равен 10.0` | `== 30.0` | То же. |
| 588 | `враг начинает с 50 здоровья (data.max_health)` + проверка `== 50.0` | `враг начинает с data.max_health здоровья` + `_near(_enemy_health(enemy), data.max_health)` | Потолок и так запинен строкой 526; здесь утверждается, что сцена берёт ИМЕННО его. Сцена без `data` читала бы дефолт скрипта (50) и выглядела бы целой. |
| 617 | — | `var bullet_damage := bullet.damage` (до `free()`) | Урон снаряда читается до исчезновения узла. |
| 626 | `после одного попадания у врага 20 здоровья (50 - 30)` + `== 20.0` | `после одного попадания у врага data.max_health - урон снаряда` + `_near(..., data.max_health - bullet_damage)` | Два зашитых числа заменены производными: потолок из данных врага, урон из настоящего `projectile.tscn`. Смена урона в `pistol.tres` теперь валит ассерт, а не молча едет вместе с ним. |

### `tests/enemies.gd` — инвариант «касаний до смерти игрока» (Task 2)

Строки 359–392. Было:

```gdscript
var hits_to_death := float(player.get("max_health")) / contact.contact_damage
_check(absf(hits_to_death - 10.0) < _HEALTH_EPS, "10 попаданий до смерти игрока", …)
```

Стало (`tests/enemies.gd:372`):

```gdscript
var player_max_health := float(player.get("max_health"))
var hits_to_death := int(ceil(player_max_health / contact.contact_damage))
… player.call("take_damage", contact.contact_damage) × hits_to_death …
_check(_died_count == 1 and survived == hits_to_death - 1,
    "игрок гибнет ровно на %d-м касании контактного врага (ceil(max_health / contact_damage))", …)
```

Почему так: «10» было и хардкодом, и проверкой неверной арифметики — при 100/30 частное
равно 3.3333, и `== 10.0` краснело на исправных данных. Число теперь **выводится** из тех же
двух величин, по которым игрока в игре ранят, и проверяется **поведением**: настоящий
`player.tscn` получает `data.contact_damage` выведенное число раз и обязан дожить до
последнего касания и умереть ровно на нём (при 100/30 это 4 — и 4-е убивает). Ассерт
остаётся фальсифицируемым в обе стороны: подмена константы урона, потолка или поведения
`take_damage()` валит его. Перед следующей подсекцией (проводкой `Hurtbox → take_damage`)
счётчики сигналов сброшены (строка 389): смерть уже произошла, респавн вернул 100 HP, но
`died` за это наблюдение успело сработать один раз — иначе «died ровно один» ниже посчитал
бы две смерти.

### `tests/enemies.gd` — пересчитанные навигационные метрики (Task 4 и Task 5)

| Строка | Было | Стало | Почему |
|---|---|---|---|
| 102–104 | `const _NAV_OBSERVE_TICKS := 360` | удалён | Окно было выбрано («3 с, как требует бриф»), а не выведено: при 6 м/с оно успевало, при 2 м/с — нет. |
| 106 | — | `const _NAV_PASS_X := _NAV_WALL_MAX_X + 0.75` | Единственный проход в тестовом мире — торец стены плюс отступ радиуса агента, который закладывает запекание навмеша (0.75 м по умолчанию). Наблюдение в RED это подтвердило: `следующая точка пути (2.75, 0.5, 0.0)`. |
| 110 | — | `const _NAV_ROUTE_SAFETY := 1.25` | Запас в четверть маршрута на то, что ломается не тик, а навмеш: сглаживание Recast срезает углы, первые кадры агент тратит на построение пути. |
| 116 | — | `const _NAV_DESIGN_SPEED := 2.0` | Скорость **баланса**, под которую считается окно. Не `data.move_speed`: если окно выводить из поля данных, «враг прошёл маршрут» становится тавтологией — любая скорость дала бы зелёный результат, потому что окно подстроилось бы под неё. |
| 121 | — | `const _NAV_ARRIVAL_MARGIN := 0.1` | Допуск на границе окна: половина тика при 2 м/с — 0.008 м, плюс сантиметры округления сетки. Строгая стоп-дистанция без допуска осталась отдельным ассертом ниже. |
| 1237, 1241 | — | `_route_length()`, `_route_ticks()` | Маршрут = ломаная `start → угол → target`; окно = `ceil(маршрут / _NAV_DESIGN_SPEED × 1.25 × 120)`. Число выводится и печатается, его можно проверить глазами. |
| 1103–1108 | — | `_check(_near(move_speed, _NAV_DESIGN_SPEED), "move_speed данных равен скорости баланса 2.0 м/с…")` | Пин, который делает пересчётное окно осмысленным: смена скорости в `contact.tres` видна здесь, а не подгоняет проверку молча. |
| 1136–1156 | `for i in _NAV_OBSERVE_TICKS` | `for i in observe_ticks` + счётчик `arrived_at` | Окно пришло из `_route_ticks`; номер тика прихода попадает в текст ассерта. |
| 1182–1187 | `end_distance < start_distance * 0.5` — «за 3 с враг сократил дистанцию более чем вдвое» | `end_distance <= stop_limit + _NAV_ARRIVAL_MARGIN` — «за окно в 7.13 с (11.41 м маршрута при 2.0 м/с) враг прошёл весь маршрут» | «Вдвое за 3 с» было утверждением о **скорости**, а не о маршруте: при 2 м/с исправный враг его не выполняет (RED: `10.000 -> 5.406`). Теперь утверждение о маршруте — дошёл до стоп-дистанции агента, взятой из сцены. |
| 157–160 | `const _RANGE_OBSERVE_TICKS := 360` | удалён | Та же история в тире (RED: `21.378 -> 15.447`). |
| 163–168 | `const _RANGE_APPROACH_RATIO := 0.5` | удалён | Порог «вдвое» в тире заменён тем же правилом прихода. |
| 176–177 | `_RANGE_CONTACT_TICKS := 720` («враг идёт 6 м/с… ~3.5 с») | `_RANGE_CONTACT_INTERVAL := 1.0`, `_RANGE_CONTACT_TICKS := 300` | Окно прохода и окно ожидания касания — разные величины: первое считается из маршрута, второе из каденции (`contact_interval = 1.0 с`, проверено выше). 2.5 с — один интервал с запасом. |
| 1606–1613 | `for i in _RANGE_OBSERVE_TICKS` | `range_ticks := ceil(дистанция / 2.0 × 1.25 × 120)` + печать | Тот же `_NAV_DESIGN_SPEED` и тот же запас, но длиной маршрута служит замеренная дистанция до игрока: угол обхода задан мишенями тира, а не харнессом. |
| 1615–1645 | контакт ждали отдельным окном после прохода | первый тик контакта ищется **внутри** окна прохода (`first_contact_tick`) | «Дошёл и ударил» — одно наблюдение. Два окна оставляли щель, в которой враг мог дойти, ударить и разойтись, а проверка об этом не узнала бы. |
| 1653 | `end_distance < settle_distance * 0.5` | `end_distance <= stop_at + _NAV_ARRIVAL_MARGIN` | Как в мировом мире: утверждение о маршруте, а не о скорости. |
| 1658 | `contact_tick >= 0` в отдельном окне | `first_contact_tick >= 0` внутри окна прохода | Тот же смысл, но наблюдение больше не зависит от «хватит ли отдельного окна». |
| 1671–1684 | `враг из тира дошёл до игрока и нанёс контактный урон` (после прохода) | `после прихода тики контакта продолжаются: окно в 2.5 с перекрывает каденцию 1.0 с` | Наблюдение дополняет предыдущее: тики не разовые, а по каденции, и длятся после прихода. |

Секция Task 3 с 7.5-пробой (`_test_enemy_contact_tick`, 13 тиков по 7.5, 14-й убивает) не
трогалась: она работает на собственных данных сценария и в RED была зелёной. Все её
ожидания по-прежнему выводятся из данных.

---

## 3. Обоснование пересчитанных метрик (числа)

**Навигационный мир Task 4.** Геометрия: пол 40×40, стена `x ∈ [-20, 2]`, `|z| < 1`, враг
стартует в `(0, 0, -5)`, цель в `(0, 0, 5)`. Прямая пересекает стену, обход — только за
торцом `x = 2`, а навмеш ведёт по коридору `x = 2.75` (это и видно в RED: «следующая точка
пути (2.75, 0.5, 0.0)»).

```
маршрут = |(2.75, 0, 0) - (0, 0, -5)| + |(0, 0, 5) - (2.75, 0, 0)|
        = 2 * sqrt(2.75^2 + 5^2) = 2 * 5.7064 = 11.41 м
время  = 11.41 / 2.0 = 5.71 с      окно = 5.71 * 1.25 = 7.13 с = 856 тиков
```

Факт зелёного прогона (замер с заведомо ложным порогом, диагностический прогон):
`10.000 -> 0.493 м`, **приход на тике 652 из 856** (5.43 с), то есть запас окна — 204 тика
(31 %). Запас складывается из двух независимых вещей: сглаживание Recast срезает углы и
реальный путь (652 тика × 2 м/с = 10.87 м) **короче** выведенной ломаной 11.41 м, плюс
четверть `_NAV_ROUTE_SAFETY`. «Более чем вдвое» при 2 м/с было недостижимо в принципе: за 3 с
враг физически проходит 6 м пути, из которых в сближение идёт меньше (путь идёт по диагонали
к углу стены) — RED это и показал: 4.59 м из 6 м.

**Тир Task 5.** Замеренная дистанция враг→игрок = 21.378 м (враг в `(9, 0, -19.5)`, игрок в
начале координат). Прямая — нижняя оценка пути: три мишени стоят между ними, навмеш ведёт
вокруг, и выводить этот угол из геометрии сцены означало бы дублировать сцену в проверке.

```
время = 21.378 / 2.0 = 10.69 с      окно = 10.69 * 1.25 = 13.37 с = 1604 тика
```

Факт зелёного прогона: `21.378 -> 0.486 м`, первый тик контакта на тике **1245**, тиков за
окно 3, HP игрока 10.0 в конце. Запас окна до прихода — ~22 % плюс то, что реальный путь
длиннее прямой. Стоп-дистанция агента в тире 0.5 м, радиус контакта хитбоксов 0.8 м, то есть
касание приходит **раньше** стопа — на тике 1245 против ~1250.

**Контакт Task 5 после прихода.** Каденция — дефолт `contact_interval = 1.0 с`
(проверено выше ассертом), окно 2.5 с = один интервал с запасом; факт: следующий тик на кадре
2 из 300. Прежние 720 тиков (6 с) обслуживали не каденцию, а время прохода — при 6 м/с. Окно
прохода и окно ожидания касания теперь считаются по разным правилам и не склеены.

**Стоимость времени.** `enemies` с новыми окнами идёт **26.1 с** на этой машине при
`_CheckTimeoutMs = 120000` — запас ~4.6×.

---

## 4. Мутации (каждая: сломать → прогон → пойманный ассерт → восстановить побайтово)

Проверка целостности после каждого восстановления — SHA-256 файла до == после, плюс
повторный зелёный прогон того же фильтра.

### (a) `data/weapons/pistol.tres`: `rounds_per_minute = 150.0` → `120.0`

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 weapon_data
```

Краснеет (3):

* `rounds_per_minute is 150.0 (got 120.0000)` — **пин данных, цель мутации**
* `seconds_between_shots() is 0.4 s at 150 rpm (got 0.500000, tol 0.0001)`
* `a full magazine is 7.2 s of continuous fire (computed 9.000000 from magazine_size=18 and 0.500000 s per shot)`

SHA-256 `pistol.tres` до `6562EF39…A8C1D7` = после `6562EF39…A8C1D7`; повторный
`… run_checks.ps1 weapon_data` → `RESULT: 1 passed, 0 failed, 0 skipped`.

### (b) `data/weapons/pistol.tres`: `magazine_size = 18` → `10`

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 weapon
```

Краснеет 23 ассерта в `weapon` (23 из 26 «старых» фейлов RED — те же имена) и 2 в
`weapon_data`. Первая пара:

* `a fresh pistol starts with a full magazine (got 10 of 18)` — **пин ёмкости, цель мутации**
* `the magazine lost exactly one round (got 9)`
* … `the round is still in the magazine: instantiate first, decrement after (got 10 of 18)`
* `weapon_data`: `magazine_size is 18 (got 10)`, `a full magazine is 7.2 s of continuous fire (computed 4.000000 …)`

SHA-256 `pistol.tres` до = после `6562EF39…A8C1D7`; повторный `… run_checks.ps1 weapon` →
`RESULT: 2 passed, 0 failed, 0 skipped`.

### (c) `data/enemies/contact.tres`: `contact_damage = 30.0` → `10.0`

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies
```

Краснеет (2):

* `contact_damage is 30.0 (got 10.0000)` — **пин данных**
* `contact_damage данных врага равен 30.0 (got 10.0000)` — **пин на инстансе сцены**

Производный инвариант касаний остался зелёным — и это правильное поведение: он выводит
число из данных, поэтому при уроне 10.0 сам выводит 10 и сам же требует, чтобы игрок умер
именно на десятом касании. Ассерт не зашит на 4; его несёт пин данных, который здесь и
краснеет.

SHA-256 `contact.tres` до `4A87A92B…EBCF95` = после `4A87A92B…EBCF95`; повторный
`… run_checks.ps1 enemies` → `RESULT: 1 passed, 0 failed, 0 skipped`.

### (d) `data/enemies/contact.tres`: `move_speed = 2.0` → `6.0`

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies
```

Краснеет (2):

* `move_speed is 2.0 (got 6.0000)` — **пин данных**
* `move_speed данных равен скорости баланса 2.0 м/с: под неё выведены окно и пороги маршрута (got 6.0000)` — **пересчитанная навигационная метрика, цель мутации**

Без второго ассерта пересчётное окно было бы тавтологией: при 6 м/с враг прошёл бы тот же
маршрут ещё быстрее и «дошёл» осталось бы зелёным на любой скорости. Именно он делает
мутацию (d) наблюдаемой на навигации, а не только на пине.

SHA-256 `contact.tres` до = после `4A87A92B…EBCF95`; повторный `… run_checks.ps1 enemies` →
`RESULT: 1 passed, 0 failed, 0 skipped`.

### (e) `tests/enemies.gd`: `_NAV_ROUTE_SAFETY := 1.25` → `0.315` (окно срезано до прежних ~3 с)

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies
```

Краснеет 7, и первыми идут именно пересчитанные ассерты:

* `за окно в 1.80 с (11.41 м маршрута при 2.0 м/с) враг прошёл весь маршрут: дистанция до цели не больше стоп-дистанции агента (10.000 -> 7.344 м из 10.000; стоп-дистанция 0.600 м, допуск 0.10 м; дошёл на тике -1 из 216)` — **пересчитанная навигационная метрика, цель мутации**
* `враг дошёл до другой стороны стены (z > 1.0): путь вел вокруг, а не упирался в стену`
* `враг остановился у цели: дистанция ≤ target_desired_distance + 0.1 (7.3436 при пороге 0.6000)`
* `после остановки не дрейфует: за 0.5 с дистанция не изменилась (7.3436 -> 6.5505, допуск 0.02)`
* `за окно в 3.38 с (21.38 м маршрута при 2.0 м/с) враг тира дошёл до игрока (21.378 -> 14.704 м; … дошёл на тике -1 из 405)` — **пересчитанная метрика тира**
* `враг из тира ДОХОДИТ до игрока и нанёс контактный урон — здоровье игрока упало (за 405 тиков (3.38 с) ни одного тика; …)`
* `после прихода тики контакта продолжаются: окно в 2.5 с перекрывает каденцию 1.0 с (за 300 тиков ни одного тика; …)`

SHA-256 `tests/enemies.gd` до `3CF3A0DB…CCC2A8` = после `3CF3A0DB…CCC2A8`; повторный
`… run_checks.ps1 enemies` → `RESULT: 1 passed, 0 failed, 0 skipped`.

*(Первый прогон этой мутации делался до нормализации переводов строк в `tests/enemies.gd`,
SHA тогда был `B5617B9E…EAAE`; после нормализации (раздел 6) мутация прогнана повторно,
пара SHA выше — итоговая. Набор красных ассертов совпал.)*

---

## 5. Полный сьюит

```
smoke          PASS
movement       PASS
input_actions  PASS
input_gate     PASS
weapon_data    PASS
integrity      PASS
weapon         PASS
projectile     PASS
enemies        PASS
waves          [SKIP]  (tests\waves.gd not present)
save           [SKIP]  (tests\save.gd not present)
progression    [SKIP]  (tests\progression.gd not present)

RESULT: 9 passed, 0 failed, 3 skipped
```

Число проверок: `weapon_data` 20, `weapon` 150, `enemies` 162 (было 160; +1 пин скорости
баланса, +1 «тики контакта продолжаются»).

### `project.godot`

Возвращены ровно три ключа §1A с комментариями, порядок как в HEAD:

* `[application]` после `config/icon`: `; Без жёсткого ограничения кадров…` + `run/max_fps=0`
* `[display]` после `window/stretch/aspect`: `; Синхронизация кадров с монитором…` + `window/vsync/vsync_mode=1`
* `[rendering]` после `anti_aliasing/quality/msaa_3d`: `; Масштаб 3D-буфера 1.0…` + `scaling_3d/scale=1.0`

Проверка до байта:

```
git diff -- project.godot                  → пусто (0 строк)
git rev-parse 7a4b13d:project.godot        → e8c1ab3be45c72883afd479af55c3bc7ec0a6781
git hash-object project.godot              → e8c1ab3be45c72883afd479af55c3bc7ec0a6781
```

Итоговые SHA-256 изменённых файлов:

| Файл | SHA-256 |
|---|---|
| `tests/weapon_data.gd` | `5810311289040AE13B9B0567597C08E6FF9A756EE9BE02CF7910DDF9FADAE516` |
| `tests/weapon.gd` | `A7F0172D459774D4BA2891557BC0689A299CCEDAC244E077A5689B812B0764D8` |
| `tests/enemies.gd` | `3CF3A0DBA4DF3DA4F62B891514E5E080A4D41BF9B25B5F7C02EBA9D2D0CCC2A8` |
| `project.godot` | `8ACABDCF5AEC30CDB9DF217AB8F9F61FFD50A83DAFD99C091DE2EB946F0B0683` |
| `data/weapons/pistol.tres` (не менялся) | `6562EF398C57FE71295FE397E9CF2217B4B80C8B91DCDE97C538192EE3A8C1D7` |
| `data/enemies/contact.tres` (не менялся) | `4A87A92B0518AFDA3FBFBA6530C948E8F5CD707C68141BAB38632E9784EBCF95` |

---

## 6. Замечания и риски

1. **Устаревшие числа в запрещённых секциях `tests/weapon.gd`.** `_TRAJECTORY_TICKS`
   (строка 100) по-прежнему пишет «At the shipped 120 Hz and 40 m/s that is half a second and
   20 m of flight», а комментарий внутри секции trajectory (строка 626) — «Half a second at
   40 m/s is ~20 m». После ребаланса это ~35 м; фактический замер в RED — 34.417 м. Сами
   константы и ассерты трогать запрещено, и они зелёные (дрейф 0.0000 м при допуске 0.05 м).
   То же в секции startup: `_NO_SHOT_WATCH_SECONDS` (строка 115) — «Twice the 0.5 s rate
   limit», теперь интервал 0.4 с. Правка — однострочная, когда владелец разрешит.
2. **Комментарии игрового кода устарели относительно данных.** `scripts/enemy_contact.gd`
   (строки 62–63, 274–277, 303–305) и шапка `scripts/enemy_data.gd` продолжают называть
   50 HP / 10 урона / 6 м/с. Файлы вне моего владения и под мой запрет — не трогал.
3. **`scripts/pistol.gd` в рабочем дереве изменён владельцем** (комментарий к
   `fire_rate_source`), и `tests/weapon.gd` несёт его незакоммиченные правки SHOOT-фикса
   (`_new_aim_source`, `_TRAJECTORY_MIN_TRAVEL`, `_settle_fire_released`). Мои правки в этом
   же файле — только пины и тексты ассертов; чужие изменения не тронуты. При коммите оба
   изменения попадут в один файл — стоит знать.
4. **`tests/enemies.gd` был единственным CRLF-файлом в репозитории** (1802 CRLF / 0 LF)
   при `core.autocrlf=true` и `.gitattributes` c `eol: lf`. Нормализован до LF побайтовой
   правкой (только удаление 0x0D, кодировка не тронута). Git-блоб не изменился:
   `git hash-object` до и после — `bc5607749b22e287eee3fddd2db33533332202ae`, диф —
   195 вставок / 71 удаление как и до нормализации. Если владелец предпочитает CRLF в
   рабочем дереве — файл вернётся к CRLF при сохранении из редактора, на коммит это не
   влияет.
5. **`CHECKLIST.md` менялся параллельно, не мной** (mtime 2026-10-10 23:05 UTC, в момент
   моих прогонов). Правки в нём как раз описывают задачу BALANCE и ожидаемые
   `9 passed / 0 failed / 3 skipped`. Я файл не трогал: он не входит в мой список. В нём же
   стоит «Набор `enemies`: 159 проверок» — фактическое число теперь **162** (пересчёт
   чисел в чеклисте — работа владельца, я туда не лез).
6. **Секция Task 5 разрослась.** Окно прохода (1604 тика) и учёт первого тика контакта
   внутри него — самый крупный дифф задачи. Альтернатива (отдельное окно ожидания
   прихода) оставлена в виде одного ассерта «после прихода тики контакта продолжаются»,
   чтобы не потерять проверку каденции.
7. **Время прогона `enemies` выросло** до 26.1 с (было ~14 с) из-за выведенных окон. Лимит
   раннера — 120 с на проверку; запас 4.6×. Дальнейшее удлинение окон (например, если
   владелец снизит `move_speed` ещё сильнее) упрётся в этот лимит раньше, чем в логику.
