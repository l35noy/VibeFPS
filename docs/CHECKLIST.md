> **Назначение:** Состояние прохождения: что сделано, что открыто, инварианты, текущие задачи. Канон статуса работ.

# VibeFPS — Checklist

> **Принцип:** маленькая рабочая система → проверка → стабилизация → расширение.
>
> Пункт считается выполненным только после фактической проверки (автотесты или подтверждённый запуск).

---

## Текущий статус: Монохромное архитектурное обновление (R1–R7) завершено

* **Автопрогон тестов:** `19 passed, 0 failed, 0 skipped`.
* **E2E мастер-сьют:** `93 passed, 0 failed, 0 skipped`.
* **Команда запуска проверок:** `pwsh -File .\tools\run_checks.ps1`
* **Команда запуска E2E мастер-сьюта:** `& "E:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/e2e/e2e_suite.gd`

---

## 1. Завершённые фазы

### Фаза 0: Базовый персонаж и фундамент
- [x] Движение WASD, обзор мышью, гравитация, падение.
- [x] Прыжок Space (обработка в `_unhandled_input`), спринт Shift без стамины.
- [x] Восстановление при падении за kill-plane.
- [x] Настройки дисплея: 2560x1440 borderless, V-Sync, физика 120 Гц, сглаживание MSAA 4x.
- [x] Headless-раннер тестов (`tools/run_checks.ps1`) и наборы `smoke`, `movement`, `integrity`, `input_actions`, `input_gate`.

### Фаза 1: Оружие и стрельба
- [x] Ресурс параметров оружия `WeaponData` (`data/weapons/pistol.tres`, `auto.tres`).
- [x] Бесплатный стартовый пистолет ([`pistol.tscn`](file:///e:/projects/VibeFPS/weapons/pistol/pistol.tscn)) и автомат ([`auto.tscn`](file:///e:/projects/VibeFPS/weapons/auto/auto.tscn)).
- [x] Физические геометрические снаряды ([`projectile.tscn`](file:///e:/projects/VibeFPS/weapons/projectile/projectile.tscn)) со скоростью 70 м/с и оптимизированным кэшированием мешей/материалов.
- [x] Магазин, перезарядка, бесконечный боезапас, ограничение скорострельности.
- [x] Гейт ввода ([`InputGate`](file:///e:/projects/VibeFPS/core/input_gate.gd)): стрельба и управление блокируются без захвата курсора.

### Фаза 2: Враги, здоровье и навигация
- [x] Здоровье игрока (100 HP, сигналы `health_changed`, `died`).
- [x] Контактный враг ([`enemy_contact.tscn`](file:///e:/projects/VibeFPS/entities/enemies/contact/enemy_contact.tscn)): 60 HP, урон 30 раз в 1.0 с, скорость 2.0 м/с.
- [x] Хитбоксы и хертбоксы ([`hurtbox.gd`](file:///e:/projects/VibeFPS/entities/common/hurtbox.gd)) с разделением слоев коллизий.
- [x] Навигация по навмешу ([`NavigationAgent3D`](file:///e:/projects/VibeFPS/entities/enemies/contact/enemy_contact.tscn)), навигационные регионы в сценах уровней ([`arena_scene.gd`](file:///e:/projects/VibeFPS/levels/arena_01/arena_scene.gd)).
- [x] Обесцвечивание и удаление врага через 0.2 с после смерти.

### Фаза 3: Лобби, магазин и сохранения
- [x] Главная сцена лобби ([`lobby.tscn`](file:///e:/projects/VibeFPS/levels/lobby/lobby.tscn)).
- [x] Автозагрузка [`GameState`](file:///e:/projects/VibeFPS/core/game_state.gd) — единственный владелец переходов между сценами (`enter_location`, `return_to_lobby`).
- [x] Автозагрузка [`SaveSystem`](file:///e:/projects/VibeFPS/core/save_system.gd) — автосохранение очков, купленного оружия и открытых локаций (`user://save.json`) с дебаунсом 1.5 с и I/O-батчингом.
- [x] Точка магазина ([`shop_point.gd`](file:///e:/projects/VibeFPS/levels/lobby/shop_point.gd)): покупка автомата за 300 очков и смена оружия по клавише E.
- [x] Двери-порталы ([`door_point.gd`](file:///e:/projects/VibeFPS/levels/lobby/door_point.gd)): переход в боевую локацию (арена `arena_01`).
- [x] HUD-интерфейс ([`ui.gd`](file:///e:/projects/VibeFPS/ui/ui.gd)): шкала здоровья (HP), патроны в магазине, индикатор перезарядки (`ReloadLabel`), счёт очков, инвентарь.
- [x] Возврат в лобби при смерти с сохранением накопленного прогресса.

### Фаза 4: Первая локация и полный игровой цикл
- [x] Боевая локация арены ([`arena_01.tscn`](file:///e:/projects/VibeFPS/levels/arena_01/arena_01.tscn)): арена 44x44 м, стены, 4 колонны-укрытия, `NavigationRegion3D`, 4 точки спавна, игрок и портал возврата.
- [x] Менеджер волн ([`wave_manager.gd`](file:///e:/projects/VibeFPS/levels/common/wave_manager.gd)): 4 волны с очередями спавна (1 враг в 1.2 с) и 10-секундной передышкой между волнами 1–3.
- [x] Новый летающий противник ([`flying_enemy.tscn`](file:///e:/projects/VibeFPS/entities/enemies/flying/flying_enemy.tscn)): 40 HP, урон 15, парение на высоте 3 м, удержание дистанции 9 м, прицельная стрельба снарядами.
- [x] Босс локации ([`boss_enemy.tscn`](file:///e:/projects/VibeFPS/entities/enemies/boss/boss_enemy.tscn)): 300 HP, контактный урон 40, веерный залп из 3 снарядов, фаза ярости при HP $\le 50\%$ (ускорение, учащённая стрельба).
- [x] UI волн и босса: номер текущей волны (`WaveLabel`), полоса здоровья босса (`BossBar`), экраны победы (`VictoryPanel`) и поражения (`DefeatPanel`).
- [x] Зачистка локации и награды: +50 очков за завершение каждой волны, +500 очков за полную зачистку, разблокировка следующей двери локации (`arena_02`) в лобби.
- [x] Полный автоматический тестовый сьют волн ([`tests/waves.gd`](file:///e:/projects/VibeFPS/tests/waves.gd)): 59 проверок контрактов данных, врагов, менеджера волн и арены.

### Фаза 5: Монохромное архитектурное обновление (Monochrome Architectural Line Art Update — R1–R7)
- [x] **R1 (Визуальный стиль):** процедурная CAD-сетка на полу и стенах лобби и арены 01 (`cad_grid.gdshader`), Inverted Hull белый матовый материал с чёрным контуром (`inverted_hull_material.tres`).
- [x] **R2 (Реструктуризация локаций):** удалены `levels/range/` и `levels/main/`, активны только `lobby` и `arena_01`, Лобби расширено в зал 28х36 м с 6 колоннами и ровно 2 интерактивными зонами (`DoorPoint` и `ShopPoint`).
- [x] **R3 (Контекстный HUD):** подсказка `[E] <действие>` в радиусе 3.5 м, мгновенное скрытие при открытии модальных окон.
- [x] **R4 (Магазин оружия):** центрированное модальное окно `ShopModal`, группа `modal_ui`, блокировка ввода `InputGate`, 3 карточки с процедурными 2D CAD-чертежами и размерными засечками (пистолет 180 мм, АК-47 870 мм, дробовик 650 мм), 3-состоятельные кнопки («В руках», «Экипировать», «Купить за X очков»), закрытие по Esc/E/CloseButton.
- [x] **R5 (Оружие):** двуствольный дробовик (`shotgun.tres`, `shotgun.gd`, `shotgun.tscn`: залп из 10 дробинок на 70 м/с, 120 урона в упор, 2 патрона, перезарядка 1.1 с, цена 600 очков) и визуальный редизайн АК-47 (`weapons/auto/auto.tscn`).
- [x] **R6 (Контактные враги):** парящий куб 1x1x1 м (`enemy_contact.tscn`, `enemy_contact.gd`), парение 1.0 м, боббинг 0.1 м, вращение Y 1.8 рад/с, отключение левитации и гравитационное падение при гибели на пол y=0.5 м, `tests/floating_cube.gd`.
- [x] **R7 (Баланс волн):** передышка между волнами уменьшена до 5.0 с (`intermission_duration = 5.0` в `wave_manager.gd`).
- [x] **E2E-тестирование:** 93/93 проверки пройдены со 100% успехом (Tier 1: 42, Tier 2: 36, Tier 3: 7, Tier 4: 8).

---

## 2. Закрытый технический долг и оптимизации

- [x] **HUD:** добавлена индикация процесса перезарядки (`ReloadLabel` при `reload_started` / `reload_finished`).
- [x] **Экраны:** реализованы всплывающие панели поражения (`DefeatPanel`) и победы (`VictoryPanel`) с выходом в лобби.
- [x] **Очистка отладочного кода:** удалён временный блок `_apply_temp_dev_starting_points()` из `game_state.gd`.
- [x] **Фокус ввода и мышь:** устранена рассинхронизация захвата курсора при потере/возврате фокуса окна (`focus_entered`) и закрытии инвентаря на Escape (`pause`).
- [x] **Оптимизация навигации:** кэширование игрока в `_cached_player`, адаптивный троттлинг пересчёта пути (100 мс / порог смещения 0.25 м).
- [x] **Оптимизация дискового I/O:** автосохранение `SaveSystem` использует дебаунс 1.5 с и сброс `flush_save()`, исключая зависания при быстрых фрагах.
- [x] **Оптимизация снарядов:** исключено дублирование ресурсов `SphereMesh` и `StandardMaterial3D` при создании следов выстрелов.

---

## 3. Архитектурные инварианты

### 3.1 Слои коллизий (Collision Layers)
| Слой | Имя | Назначение |
|---|---|---|
| 1 | `world` | Статическая геометрия уровня, стены, пол, колонны |
| 2 | `player_body` | Тело игрока (`CharacterBody3D`) |
| 3 | `enemy_body` | Тело врага (`CharacterBody3D`) |
| 4 | `enemy_hurtbox` | Зона получения урона врагом (`Area3D`) |
| 5 | `projectile` | Снаряды оружия (`Area3D`) |
| 6 | `interactable` | Точки взаимодействия (магазин, двери, порталы) |
| 7 | `player_hurtbox` | Зона получения урона игроком (`Area3D`) |

### 3.2 Навигация и физика
- Темп физики: 120 Гц (`physics_ticks_per_second = 120`), Jolt Physics 3D.
- Снаряды: скорость 70 м/с, настраиваемый `target_mask` (слой 4 для снарядов игрока, слой 7 для снарядов врагов).
- Навмеш: `cell_height = 0.25`, bake по геометрии (`geometry_parsed_geometry_type = 1`, `collision_mask = 5`).

### 3.3 Смена сцен и состояние
- Все переходы между сценами осуществляются исключительно через `GameState.enter_location(id)` и `GameState.return_to_lobby(reason)`.
- Управление игрока активно только при захвате мыши: `InputGate.is_play_input_allowed(Input.mouse_mode)`.
