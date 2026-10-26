extends SceneTree

## VibeFPS Master E2E Test Suite (Tiers 1–4)
## Главный раннер E2E-тестов. Запускает изолированно каждый уровень в отдельном процессе.
## Запуск: godot --headless --path . --script res://tests/e2e/e2e_suite.gd

const TIERS := [
	{
		"id": "Tier 1",
		"name": "Feature Coverage (R1–R7)",
		"script": "res://tests/e2e/test_tier1_features.gd"
	},
	{
		"id": "Tier 2",
		"name": "Boundary & Corner Cases (R1–R7)",
		"script": "res://tests/e2e/test_tier2_boundaries.gd"
	},
	{
		"id": "Tier 3",
		"name": "Cross-Feature Combinations (Pairwise)",
		"script": "res://tests/e2e/test_tier3_cross_feature.gd"
	},
	{
		"id": "Tier 4",
		"name": "Real-World Application Scenarios",
		"script": "res://tests/e2e/test_tier4_scenarios.gd"
	}
]


func _initialize() -> void:
	print("================================================================================")
	print("               VIBEFPS COMPREHENSIVE E2E TEST SUITE (TIERS 1–4)                ")
	print("================================================================================")

	var godot_bin: String = OS.get_executable_path()
	var is_strict: bool = false
	for arg in OS.get_cmdline_user_args():
		if arg == "--strict":
			is_strict = true

	var total_checks: int = 0
	var total_passes: int = 0
	var total_skips: int = 0
	var total_fails: int = 0
	var tier_summaries: Array[Dictionary] = []

	for tier_info in TIERS:
		var tier_id: String = tier_info["id"]
		var tier_name: String = tier_info["name"]
		var script_path: String = tier_info["script"]

		print("\n>>> Запуск %s: %s ..." % [tier_id, tier_name])

		var output: Array = []
		var args: PackedStringArray = ["--headless", "--path", ".", "--script", script_path]
		var exit_code: int = OS.execute(godot_bin, args, output, true)

		var stdout_text: String = output[0] if output.size() > 0 else ""
		print(stdout_text)

		var tier_checks: int = 0
		var tier_passes: int = 0
		var tier_skips: int = 0
		var tier_fails: int = 0

		for line in stdout_text.split("\n"):
			var trimmed: String = line.strip_edges()
			if trimmed.begins_with("[PASS]"):
				tier_passes += 1
				tier_checks += 1
			elif trimmed.begins_with("[FAIL]"):
				tier_fails += 1
				tier_checks += 1
			elif trimmed.begins_with("[SKIP]"):
				tier_skips += 1
				tier_checks += 1

		if exit_code != 0 and tier_fails == 0:
			tier_fails += 1
			tier_checks += 1

		if is_strict and tier_skips > 0:
			tier_fails += tier_skips
			tier_skips = 0

		total_checks += tier_checks
		total_passes += tier_passes
		total_skips += tier_skips
		total_fails += tier_fails

		tier_summaries.append({
			"id": tier_id,
			"name": tier_name,
			"checks": tier_checks,
			"passes": tier_passes,
			"skips": tier_skips,
			"fails": tier_fails,
			"code": exit_code
		})

	# Итоговая сводка
	print("\n================================================================================")
	print("                         СВОДНЫЙ ОТЧЕТ E2E-ТЕСТИРОВАНИЯ                         ")
	print("================================================================================")
	print("%-8s | %-40s | %-6s | %-6s | %-6s | %-6s" % ["УРОВЕНЬ", "ОПИСАНИЕ", "ВСЕГО", "PASS", "SKIP", "FAIL"])
	print("--------------------------------------------------------------------------------")
	for s in tier_summaries:
		print("%-8s | %-40s | %-6d | %-6d | %-6d | %-6d" % [
			s["id"], s["name"], s["checks"], s["passes"], s["skips"], s["fails"]
		])
	print("--------------------------------------------------------------------------------")
	print("%-8s | %-40s | %-6d | %-6d | %-6d | %-6d" % [
		"ИТОГО", "Все уровни E2E", total_checks, total_passes, total_skips, total_fails
	])
	print("================================================================================")

	if total_fails > 0:
		print("РЕЗУЛЬТАТ: ОБНАРУЖЕНЫ СБОИ ТЕСТОВ (FAIL: %d)" % total_fails)
		quit(1)
	else:
		print("РЕЗУЛЬТАТ: ВСЕ ТЕСТЫ ВЫПОЛНЕНЫ УСПЕШНО (ПРОЙДЕНО: %d, ОЖИДАЕТ ВЕХ: %d)" % [total_passes, total_skips])
		quit(0)
