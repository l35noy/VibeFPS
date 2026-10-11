> **Назначение:** Протокол работ фазы (прогресс/контрольная точка).

# SDD ledger — plan: C:\Users\serhio\.opencode\plan\2026-10-10-vibefps-phase3-lobby-plan.md

Проект: VibeFPS (`E:\projects\VibeFPS`, Godot 4.7.2, GDScript). HEAD: `b7ad7c50d0db3be39419cf146ae905aed592448b`.
Владелец: serhio. **Коммиты — только владелец** (исполнители НЕ коммитят).

## Адаптации процесса
- **R4**: Работаем БЕЗ worktree, прямо в рабочем дереве на main — конвенция всех фаз проекта (0-2), владелец коммитит сам. SDD-воркспейс (вне репо, конвенция фаз 1/2): `C:\Users\serhio\.opencode\plan\sdd\2026-10-10-vibefps-phase3-lobby\`.
- **R7**: Review-пакеты — не через коммиты (их нет), а через `git diff -U10 -- <файлы задачи>` против HEAD `b7ad7c5`, с пометкой пред-существующих правок дерева.
- **R6**: `model` у subagent НЕ задаю — документация инструмента запрещает без явного запроса владельца; наследуется модель сессии.

## Состояние дерева (вход)
8 незакоммиченных файлов — все известные, НЕ откатывать (R5):
- Владельческие правки: `pistol.tscn` (ресейв: uid/unique_id/transform-формат), `player.gd` (новая строка в конце), `project.godot` (удалены §1A-ключи max_fps/vsync/scaling с комментариями)
- DOC-CLEANUP (одобрен, ждёт коммита): `scripts/enemy_contact.gd`, `scripts/pistol.gd`, `tests/weapon.gd` — только комментарии
- Правка документов: `PROJECT.md`, `CHECKLIST.md`

Спека подтверждена grep: §7.5 очки 10/50/500 (строки 247-249), §9 «да: лобби ∥ сохранение» (строка 280).

## Pre-flight scan (конфликты плана)
| Пара/задача | Интерфейс/файл | Находка |
|---|---|---|
| T1→T3 | `SaveSystem.save/load_state/clear_save` | сигнатуры T1 = потребление T3. Чисто. |
| T2→T3 | `WeaponData.price` | T2 добавляет, T3 читает; порядок T2<T3. Чисто. |
| T3→T4 | GameState API | buy/equip/enter/return/award совпадают. Чисто. |
| T4+T5 | `player.gd` | обе правят → последовательно (в плане уже так). Чисто. |
| T2+T5 | `pistol.gd` vs `enemy_contact.gd` | пересечения файлов нет. Чисто. |
| T1+T2 | `run_checks.ps1` | трогает только T2. Чисто. |
| T6 | `project.godot`/`smoke.gd` | только T6. Чисто. |
| T4 само | `_INTERACT_RANGE 2.5` vs тест «shop на дистанции 3.0 → shop» | КОНФЛИКТ → R2 |
| T3 само | scene_changer default в `_init()` vs `get_tree()` может быть null | КОНФЛИКТ → R3 |
| план | «Task1 ∥ Task2 параллельно» vs SDD-скилл + гонка .godot-кэша | КОНФЛИКТ → R1 |

## Rulings (все)
- **R1**: Задачи 1 и 2 — ПОСЛЕДОВАТЕЛЬНО (1→2), не параллельно: скилл SDD «Never dispatch multiple implementation subagents in parallel»; плюс дисциплина одного Godot-процесса (run_checks делает `--import`; гонка на `.godot`-кэше в Windows). Цена ошибки: +~30-60 мин стены.
- **R8** (Task 1): Мутация Step 5 в буквальном виде (убрать ветку `is Dictionary` в `load_state()`) нефальсифицируема на Godot 4.7.2: типизированный возврат `-> Dictionary` сам коэрсит `null`/`Array` в `{}` с нефатальной SCRIPT ERROR. Принято: красный доказан наблюдаемой мутацией формы (`load_state()` → только `points`: 2 `[FAIL]`); тест расширен кейсом «валидный JSON не-объекта», round-trip через `.get()` (фатальный invalid key access вешает чек до 120s — хардненинг обязан). Цена ошибки: тест чуть менее прямо доказывает «повреждённый → {}», но поведение покрыто кейсами 5/6/7.
- **R9** (Task 1, план-мандатеный Important от ревьюера): при тесте повреждённого файла движок печатает `ERROR: Parse JSON failed` на stderr (неотъемлемо от предписанного брифом `JSON.parse_string` на намеренно битом входе). Решено: ПРИНЯТЬ шум — тест обязан подавать битый JSON, это ожидаемое поведение тестирования, а не дефект кода; runner скрывает детали на PASS, практически вреда нет. Альтернатива (instance API `parse()` без печати) нарушила бы явное указание брифа. Цена: строка на stderr, если когда-нибудь покажут PASS-детали.
- **R12** (Task 6, план-мандатное противоречие): бриф требовал `GameState="*res://scripts/game_state.gd"` И `class_name GameState` — в Godot взаимоисключающе (`*` регистрирует глобальную константу до загрузки скриптов → `Class "GameState" hides an autoload singleton` → автозагрузка не создаётся). Принято отклонение исполнителя: автозагрузки БЕЗ `*`. Ревьюер подтвердил по исходникам `Main::start()`: узел добавляется в `/root` независимо от `*`; `*` влияет лишь на глобальную константу. Прод-код обращается только по пути `/root/GameState` → ничего не потеряно; `class_name` остаётся типом для тестов. Цена ошибки: если владелец захочет буквальный `*` — придётся отказаться от `class_name` и переписать тесты T3-T5 (запрещено брифом). АЛЬТЕРНАТИВА на будущее: реестр автозагрузок без `*` — рабочая норма.
- **R13** (Task 6, R10-фикс): эмпирически ПОДТВЕРЖДЕНО, что движок инстанцирует автозагрузки и в `--script`-режиме; они перехватывали `/root/GameState`/`SaveSystem` у тестовых инстансов T3-T5 (переименование узлов → автосейв в прод `user://save.json`, `player.gd` получал настоящий `change_scene_to_file`) — 58 падений. Принят паттерн «удалить автозагрузку из root» (`_drop_autoloads()`: remove_child + немедленный free, т.к. имена нужны до add_child) — разрешён брифом, смысл проверок не изменён. Побочно созданный продакшн `user://save.json` удалён; после финального прогона отсутствует. Цена ошибки: нет (тесты T3-T5 проходят).
- **R14** (Task 6, флак `tests/movement.gd`): изредка падает 1 ассерт доставки `Input.parse_input_event`+`flush_buffered_events`; исполнитель доказал независимость (10/10 в изоляции и с автозагрузками, и без). Не дефект Task 6 — зафиксировано как известный флак (кандидат на стабилизацию в Фазе 5/6).
- **R10** (Task 6, КОРРЕКЦИЯ pre-flight-скана): скан пометил T6×прочие как «чисто», но регистрация автозагрузок `GameState`/`SaveSystem` в Task 6 может перекрыть тестовые инстансы Tasks 3-5: тесты добавляют свой узел в `root`, а прод-код ищет `/root/GameState` → резолвится в автозагрузку, проверки разъедутся. Решено: Task 6 эмпирически проверяет поведение автозагрузок в `--script`; при поломке — приводит затронутые тесты к robust-паттерну (брать существующий /root-инстанс, иначе создавать; явно выставлять `save_path`/`scene_changer`), не меняя смысл проверок. Карта владения Task 6 расширена: тесты progression/interact/enemies — условно на правку. Цена ошибки: если автозагрузки в `--script` отсутствуют — правки не нужны, трудозатрат ноль; если есть, но не заметить — красный полный сьют на Task 6.
- **R11** (Task 3): бриф был внутренне противоречив — (а) «`scene_changer` присваивать безусловно в `_ready()`» против (б) «тест инъектит заглушку ДО `add_child`». Принято решение исполнителя: guard `if not scene_changer.is_valid()` (инъекция не затирается; глобальный контракт = «дефолт в `_ready()`, не `_init()`» соблюдён). Также арифметическая неточность брифа в автосейв-круге (`award_points(50)`→`points==50` при уже накопленных 10) разрешена чистым `_roundtrip`-инстансом с отдельной проверкой персиста основного — оба числа брифа проверены осмысленно, не подгонка. Ревьюер подтвердил оба как ✅. Цена ошибки: нет.
- **R2**: `_INTERACT_RANGE := 3.5` вместо 2.5 — тест плана ожидает shop на 3.0 м найденным (дверь на 6.0 — нет); 3.5 сохраняет координаты теста. Цена ошибки: радиус чуть щедрый (косметика).
- **R3**: scene_changer по умолчанию — присваивание в `_ready()`, НЕ в `_init()`: при `GameState.new()` + `add_child` (тесты без автозагрузки) `get_tree()` в `_init()` = null. Цена ошибки: тривиальна.
- **R5**: пред-существующие правки дерева не входят в задачи; исполнители работают поверх, не откатывая.
- **R6/R7/R4**: см. «Адаптации процесса».

## Todo
- [x] Task 1: SaveSystem + `tests/save.gd` (трек B) — review clean
- [x] Task 2: Автомат (трек A) — review clean
- [x] Task 3: GameState + `tests/progression.gd` — review clean
- [x] Task 4: Взаимодействие (ShopPoint/DoorPoint/player `_try_interact`) — review clean
- [x] Task 5: Смерть → лобби + очки за убийство (регрессия enemies.gd) — review clean
- [x] Task 6: `lobby.tscn` + autoload + main_scene + smoke-секция — review clean
- [x] Task 7: Падение с высоты = смерть → лобби — implementer done (review pending)
- [x] Task 8: Ручная перезарядка (R, любая раскладка) + старт 300 очков — implementer done (review pending); часть «300» пересмотрена в Task 9
- [x] Task 9: HUD на персонаже + сигнал очков + возврат старта к 0 с разовой выдачей 300 — implementer done (review pending)
- [ ] Task 10: Инвентарь (клавиша I, кнопки+мышь) + смена оружия у игрока — implementer in progress

## Решения владельца (после Task 8)
- HUD/интерфейс — прикрепить К ПЕРСОНАЖУ (виден в любой сцене с игроком).
- 300 очков — РАЗОВО для теста (не постоянный старт): старт по умолчанию 0 + временная помеченная выдача.
- Инвентарь — панель с КНОПКАМИ, выбор МЫШЬЮ, клавиша I (физическая), доступен везде.
- Своп оружия у игрока — ДЕЛАЕМ (Task 10): выбранное купленное оружие реально в руках.

## Задачи
### Task 1: SaveSystem — complete
- Implementer: ses_eda9a4f4bffeiGozubVlPKiMDY (DONE_WITH_CONCERNS → concerns решены: R8, R9)
- Reviewer: ses_eda88842effeTklToGxrADBkTq — Spec ✅, Approved (1 Important план-мандатеный → R9; 4 Minor)
- Minor (deferred, на финальное ревью): (a) комментарий tests/save.gd:163-166 «ветка is Dictionary нагружена» неточен (Array тоже коэрсится) — переформулировать; (b) `_test_unwritable_path` при неудаче create_dir — `_warn` вместо `_check(true)`; (c) `save()` без `flush()` — замечание на будущее для трека B (disk-full вскрывается на flush/close); (d) типовая точность int/float round-trip не утверждается (42.0==42) — намеренно.
- Files: scripts/save_system.gd(+.uid), tests/save.gd(+.uid) — новые, НЕ закоммичены (владельцу включить .uid в коммит по конвенции репо).

### Task 2: Автомат — complete
- Implementer: ses_eda83bd91ffeZAk2zPi1oVtizF (DONE)
- Reviewer: ses_eda6f2323ffeHtXPVfxVIOQdjK — Spec ✅, Approved (0 Critical/Important; 6 Minor)
- НАХОДКА ИСПОЛНИТЕЛЯ (ценная): `SphereMesh`/`StandardMaterial3D` из `.tscn` — общие sub-ресурсы; мутация их в `_setup_trail()` красила бы все снаряды. Закрыто `duplicate()` + guard `resource_local_to_scene` (`scripts/projectile.gd`).
- Minor (deferred, на финальное ревью): (a) emission шлейфа остаётся серым (`projectile.tscn` energy 2.5) — насыщенность жёлтого падает; (b) соунд-фикс общего ресурса НЕ покрыт тестом (нужен кейс «два снаряда с разными данными»); (c) `_setup_trail()` теперь навязывает SphereMesh и перезатирает albedo/α — контракт сузился; (d) `duplicate()` не защёлкивает флаг local-to-scene (не идемпотентно, сейчас безвредно); (e) `auto.tscn` Grip без наклона/FrontSight на доли мм — отличия от пистолета; (f) рукописный uid `uid://c9fj2nkq5vt3m` (движок не регистрировал).
- Files: `scripts/weapon_data.gd`, `tests/weapon_data.gd`, `scripts/projectile.gd`, `scripts/pistol.gd`, `tools/run_checks.ps1` (M); `data/weapons/auto.tres`, `auto.tscn`, `tests/auto_weapon.gd`(+.uid) (new) — НЕ закоммичены.

### Task 3: GameState — complete
- Implementer: ses_eda6bf0d7ffejQ8DQIa5MH7anq (DONE_WITH_CONCERNS → resolved: R11)
- Reviewer: ses_eda6639b4ffewLxl366vI1lnbR — Spec ✅, Approved (0 Critical/Important; 5 Minor)
- Minor (deferred, на финальное ревью): (a) `_restore` не гарантирует инвариант `equipped ∈ owned` при битом сейве; (b) непустой/частичный словарь в `_restore` сквозным тестом не покрыт (код корректен, регресс не поймать); (c) `_roundtrip`-инстанс усложняет тест (защитимо); (d) результат `ss.save()` игнорируется — тихий провал автосейва; (e) ожидаемый шум stderr от `load(".../nope.tres")` — приемлем (R9-аналог).
- Files: `scripts/game_state.gd`(+.uid), `tests/progression.gd`(+.uid) — новые, НЕ закоммичены.

### Task 4: Взаимодействие — complete
- Implementer: ses_eda6463a0ffeWqBakzHuFgn8zY (DONE)
- Reviewer: ses_eda5644b6ffeMTS275lDdgm4J0 — Spec ✅, Approved (0 Critical/Important; 4 Minor)
- Reviewer подтвердил: R2 закреплён двусторонне (shop на 3.0 найден / door 6.0 и shop 10.0 — null); гейт-тест честный (реальный key-event маршрут через `_unhandled_input`, а не обход); фильтр `is Node3D` безопаснее брифа; маска снаряда не тронута (слой 6 не добавлен).
- Minor (deferred, на финальное ревью): (a) мёртвый хелпер `tests/interact.gd:129-134 _property_hint()` — удалить (противоречит YAGNI-заявлению отчёта); (b) в отчёте не отмечена чужая правка `run_checks.ps1` (`auto_weapon` — от Task 2) и прогнана лишь одна мутация из двух; (c) формулировка про dedup `InputEventAction` подана как установленный факт движка — смягчить (проектный пин: action_press не доходит, см. `movement.gd:538-539`); (d) путь `gs == null → false` в `interact()` не покрыт тестом (брифом не требовался).
- ПРОЦЕДУРНОЕ: при сборке вспомогательных пакетов (историч.) проверять полноту diff.
- Files: `scripts/shop_point.gd`(+.uid), `scripts/door_point.gd`(+.uid), `tests/interact.gd`(+.uid) (new); `scripts/player.gd`, `tools/run_checks.ps1` (M) — НЕ закоммичены.

### Task 5: Смерть → лобби + очки — complete
- Implementer: ses_eda502dadffeq2kkj5VHwun3Hw (DONE)
- Reviewer: ses_eda488938ffeNc3v3gi7eZKXah — Spec ✅, Approved (0 Critical/Important; 3 Minor)
- Reviewer подтвердил: однократность начисления (единственный `_die()`/`died.emit()`), подход `_RecordingGameState extends GameState` с `super` ЛЕГИТИМЕН (реальная цепочка player→GameState→scene_changer исполняется; перехватывается лишь факт/причина вызова), изоляция пробного GameState строгая (install до add_child для guard в `_ready`, remove+await, precondition-null). Evidence 7/4/3 сходится с кодом.
- Minor (deferred): (a) проверка не вызывает `_respawn(false)` в тесте напрямую — суждение теста ограничено наблюдаемыми факторами; (b) в секции очков отсутствует проверка очистки временных инстансов (отмечено ревьюером); (c) использование ссылки на `GameState` в тесте обосновано контекстом.
- ПРОЦЕДУРНОЕ: бриф ошибочно указывал `scripts/player.gd`; фактически файл в корне (`player.gd`). Исправлено исполнителем; впредь в брифингах писать корневой путь.
- Files: `player.gd`, `scripts/enemy_contact.gd`, `tests/enemies.gd` (M) — НЕ закоммичены.

### Task 6: lobby.tscn + автозагрузки + main_scene — complete
- Implementer: ses_eda467eb4ffdvlzIIiUp1YOTi3 (DONE_WITH_CONCERNS → resolved: R12)
- Reviewer: ses_eda1352b9ffeMp9pOAgigmuFZ3 — Spec ✅, Approved (0 Critical/Important; 5 Minor)
- Реализовано: `lobby.tscn` (комната 12×20, пол слой 1 верх y=0, 3 стены, ShopPoint `auto`/слой 6, DoorPoint `range`/слой 6, 3 мишени range_target+Hurtbox zone 0 на 5/8/12 м, Player на (0,0,0), uid `uid://l0bby5c7n2v4m`); `project.godot` `[autoload]` (без `*` — R12) + `run/main_scene` → lobby; `tests/smoke.gd` +секция лобби.
- Ключевое (R12): автозагрузки БЕЗ `*`; ревьюер подтвердил по исходникам движка `Main::start()`, что узел создаётся в `/root` независимо от `*`, и что прод-код ходит только по пути `/root/...`.
- R10-фикс (R13): `_drop_autoloads()` в tests/progression.gd, tests/interact.gd, tests/enemies.gd.
- Minor (deferred, на финальное ревью): (a) `_drop_autoloads()` продублирован 3× (standalone SceneTree — приемлемо); (b) нет автотеста, проверяющего само наличие автозагрузок в рабочей сцене (регрессия «удалили `[autoload]`» не ловится) — тестовый пробел; (c) у лобби нет передней стены (открыт край z=+2) — косметика; (d) ShopPoint (5,0,0) слегка врезается в правую стену — косметика; (e) smoke не закрепляет дистанции мишеней 5/8/12 (брифом не требовалось).
- Files: `lobby.tscn` (new); `project.godot`, `tests/smoke.gd`, `tests/enemies.gd`, `tests/progression.gd`, `tests/interact.gd` (M) — НЕ закоммичены.
- **ВЛАДЕЛЕЦ ПОСЛЕ РЕВЬЮ**: правка `lobby.tscn` — поправлены меш и коллизия двери (владельческая, вне задач и ревью; учесть при финальном сквозном ревью/v2 пакета).

### Финальное сквозное ревью: (в работе)