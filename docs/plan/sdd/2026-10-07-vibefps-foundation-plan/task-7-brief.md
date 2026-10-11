### Task 7: Тени направленного света

**Files:**
- Modify: `main.tscn` — узел `DirectionalLight3D`

**Interfaces:**
- Consumes: существующий `DirectionalLight3D` в `main.tscn` без теней.
- Produces: `shadow_enabled = true`. Тени включают затенение пола и стен, делая читаемой высоту персонажа над полом и границы платформы при прыжке.

- [ ] **Step 1: Включить тени в `main.tscn`**

В узле `[node name="DirectionalLight3D" …]` добавить строку `shadow_enabled = true`. Больше ничего в узле не менять — `light_energy`, `transform` и прочие настройки остаются как есть.

- [ ] **Step 2: Прогнать автопроверки**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1`
Expected: код 0. Тени не влияют на физику, поэтому все проверки остаются зелёными.

- [ ] **Step 3: Захватить кадры из движка**

Тени — визуальное изменение, поэтому требуется визуальная верификация (`CHECKLIST.md`, правило о визуальных проверках).

Run: `& "E:\Godot\Godot_v4.7.2-stable_win64.exe" --path . --script res://tests/capture.gd`
Expected: в выводе строки `SHOT …` для кадров `spawn`, `jump_rise`, `jump_fall`, записанные в `user://captures`. На кадре `jump_rise` под персонажем должна быть видна тень, отделённая от него по высоте — это доказывает, что тени работают.

- [ ] **Step 4: Закоммитить**

```bash
git add main.tscn   # НЕ КОММИТИТЬ — коммит делает партнёр
```

---

