# Fix-round SHOOT (completion): перепрогон 4 мутаций против финальных байтов

> Запускается ПОСЛЕ зелёного от BALANCE (сейчас BALANCE владеет tests/weapon.gd, tests/enemies.gd; последовательность обязательна — общий сьюте и общие файлы).

## Контекст

Ревью задачи SHOOT (Spec ✅, Quality Approved) нашло 1 Important: SHA-256 мутационных доказательств для `scripts/pistol.gd` (DFBD46C6…15D) НЕ совпадает с поставленным файлом (был FC00727C…5408). Причина: pistol.gd правился после прогона мутаций (комментарий). Логика фикса признана корректной независимо; требуется пере-заякорить доказательства на финальных байтах.

Первый диспатч fix-round был прерван (aborted) на середине; часть правок уже в дереве и зелёная:
- ✅ pistol.gd: docstring `@export var fire_rate_source` исправлен («Откуда ЦЕЛИТЬСЯ») — было ложное «Откуда выпускать снаряд»;
- ✅ tests/weapon.gd: `_new_muzzle()` → `_new_aim_source()` (переименование по всем вызовам), `_live_projectiles(muzzle)` → `_live_projectiles(parent)`;
- ✅ тест траектории: добавлен precondition «снаряд реально летел» (`_TRAJECTORY_MIN_TRAVEL := 2.0`, ассерт «precondition: the projectile really flew… travell %f m along the line, want > 2.0 m») — зелёный.
- ❌ НЕ выполнено: перепрогон 4 мутаций против финальных байтов + публикация новых хешей + append к отчёту.

## Текущее состояние (после BALANCE — проверить)

- HEAD: 7a4b13d. BALANCE добавит незакоммиченные правки тестов и project.godot (§1A восстановлен) — владелец коммитит после.
- `git status` покажет: tests/weapon_data.gd, tests/weapon.gd, tests/enemies.gd, project.godot (BALANCE) + scripts/pistol.gd, tests/weapon.gd — уже с правками fix-round (видишь overlap: tests/weapon.gd правился ОБОИМИ — финальному состоянию верить только после зелёного BALANCE; не переоткрывай).
- Полный сьюте после BALANCE ожидается 9/0/3.

## Твоя работа (только это)

1. **Проверь**, что перечисленные выше три Minor-правки на месте (строки могут сдвинуться после BALANCE — ищи по именам, не по номерам).
2. **Пере-прогони ВСЕ 4 мутации против текущих финальных байтов** (порядок не важен, изоляция важна):
   - (a) `projectile.set_as_top_level(true)` → `(false)` в `_instantiate_projectile()` → `run_checks.ps1 weapon` → именованный ассерт «the shot flew straight: moving the aim source's parent did not bend it» красный → restore побайтово → SHA-256 до == после → зелёно;
   - (b) `_spawn_point()` принудительно `return _muzzle()` → ассерты «the shot starts at the barrel…» / «and visibly not out of the eye…» красные → restore → hash == → зелёно;
   - (c) защёлка снята (fire по `is_action_pressed` без `_armed`) → «a weapon that entered the tree with fire held does not shoot» (+ «and it kept every round») красные → restore → hash == → зелёно;
   - (d) узел `Muzzle` удалён из `pistol.tscn` → `run_checks.ps1 enemies` → «у Pistol в тире есть узел Muzzle…» красный (и weapon-ассерты маркера) → restore → hash == → зелёно.
   Условия: имена ассертов финальные (после BALANCE они могли переформулироваться ТОЛЬКО вне SHOOT-секций — SHOOT-секции неприкосновенны, названия те же); если имя отличается — используй фактическое падающее имя в отчёте, но убедись, что это та же регрессия.
3. **Публикация хешей**: посчитай SHA-256 финальных `scripts/pistol.gd` и `pistol.tscn` (Get-FileHash -Algorithm SHA256). В отчёте: таблица мутаций с новыми парами до==после + финальный хеш-блок. Хеши до/после каждой мутации обязаны совпадать между собой и с финальным хеш-блоком.
4. **Append к отчёту** `C:\Users\serhio\.opencode\plan\sdd\2026-10-09-vibefps-shoot-fix\shoot-report.md`: секция «Fix round 1 (completion)» — честное признание расхождения (пост-верификационная правка комментариев), три Minor-правки, полный перепрогон (команды, имена, SHA-256 пары), финальный хеш-блок.
5. **Полный сьюте** в конце: 9 passed / 0 failed / 3 skipped.
6. Ответ ≤15 строк: Status; файлы (не менял ни одного финально — только временные мутации и отчёт); строка по тестам; финальные хеши pistol.gd/pistol.tscn; concerns; путь отчёта.

## Constraints (без изменений)

- Не коммитить (владелец). Файлы: трогать ТОЛЬКО временно под мутации (restore обязателен) + отчёт. `tests/enemies.gd` мутация (d) — только чтение проверок. Не трогать: player.*, scripts/projectile.gd, scripts/enemy_contact.gd, scripts/range_scene.gd, scripts/hurtbox.gd, project.godot, tools/run_checks.ps1, data/*.tres. Без субагентов. Проверки только через run_checks.ps1.