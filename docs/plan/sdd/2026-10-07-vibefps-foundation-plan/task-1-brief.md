### Task 1: Единая точка запуска проверок

**Files:**
- Create: `tools/run_checks.ps1`
- Create: `docs/superpowers/specs/2026-10-07-vibefps-foundation-design.md` (копия спеки из `~/.opencode/plan/`)
- Create: `docs/superpowers/plans/2026-10-07-vibefps-foundation.md` (копия этого плана)

**Interfaces:**
- Consumes: существующий `tests/headless_smoke.gd`, запускаемый как `godot --headless --path . --script res://tests/headless_smoke.gd`, завершающийся `quit(0)` при успехе.
- Produces: команда `.\tools\run_checks.ps1 [<фильтр>]` с кодом возврата 0 (все проверки зелёные) или 1 (хотя бы одна упала). Фильтр — подстрока имени файла без `.gd`, регистронезависимый; пустой фильтр = все проверки.

- [ ] **Step 1: Создать `tools/run_checks.ps1` со списком проверок**

Список `$Tests` — упорядоченный массив имён файлов **без** `.gd`. Первым идёт `smoke`, последним — `progression`: порядок значим, потому что `smoke` отвечает за целостность сцены и должен падать раньше остальных. Файлы, отсутствующие на диске, выводятся как `[SKIP]`, а не как падение, — иначе список нельзя расширять по мере добавления фаз.

```powershell
$GodotBin = "E:\Godot\Godot_v4.7.2-stable_win64.exe"
$Tests = @("smoke", "movement", "input_actions", "input_gate", "integrity",
           "weapon", "projectile", "enemies", "waves", "save", "progression")
```

- [ ] **Step 2: Реализовать тело скрипта**

Поведение, которое шаг фиксирует:

- `$Filter = $args[0]`, если передан. Тест участвует в прогоне, если `$Filter` пуст **или** имя теста содержит `$Filter` как подстроку без учёта регистра.
- Перед прогоном проверяется наличие `$GodotBin`; при отсутствии скрипт печатает путь и завершается кодом 1, ничего не запуская.
- Каждый тест запускается из корня репозитория: `& $GodotBin --headless --path . --script "res://tests/$name.gd"`. Вывод движка (`--headless` пишет в stderr) перенаправляется в `$Output`, чтобы `[FAIL]`-строки теста не терялись; при провале `$Output` печатается целиком.
- Код возврата теста (`$LASTEXITCODE`) определяет статус. `0` = `PASS`, иначе `FAIL`. Отсутствующий файл = `SKIP`.
- В конце печатается строка вида `RESULT: <PASS> passed, <FAIL> failed, <SKIP> skipped`, и скрипт завершается кодом 1, если `FAIL` > 0.

- [ ] **Step 3: Прогнать скрипт на текущем состоянии репозитория**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1`
Expected: `RESULT: 0 passed, 0 failed, 11 skipped`, код возврата 0.

Все 11 имён в `$Tests` дают `SKIP` — на этом шаге ни один из перечисленных
файлов ещё не существует. Существующий `tests/headless_smoke.gd` в список не
входит: его удаляет Task 2, а задачи 2–7 создают `smoke`, `movement`,
`input_actions`, `input_gate`, `integrity` и остальные. Это ожидаемо:
критерий SKIP-семантики в том, что отсутствующий файл не считается ни
успехом, ни провалом. Первый реально исполняемый прогон появится в Task 2.

- [ ] **Step 4: Проверить фильтр**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 smok`
Expected: только тест `smoke` в таблице, тот же результат, код 0.

- [ ] **Step 5: Скопировать спеку и план в репозиторий**

Создать `docs/superpowers/specs/` и `docs/superpowers/plans/`. Скопировать спеку из `C:\Users\serhio\.opencode\plan\2026-10-07-vibefps-foundation-design.md` в `docs/superpowers/specs/2026-10-07-vibefps-foundation-design.md`. Скопировать этот план из `C:\Users\serhio\.opencode\plan\2026-10-07-vibefps-foundation-plan.md` в `docs/superpowers/plans/2026-10-07-vibefps-foundation.md`.

- [ ] **Step 6: Закоммитить**

```bash
git add tools/run_checks.ps1 docs/
git commit -m "build: add single-command test runner and design docs"
```

---

