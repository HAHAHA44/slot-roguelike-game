extends GutTest

func test_build_contract_creates_target_reward_and_penalty() -> void:
	var service_script := load("res://scripts/core/services/contract_service.gd")

	assert_not_null(service_script)
	if service_script == null:
		return

	var service = service_script.new()
	var contract: Dictionary = service.build_contract({
		"id": "growth_gamble",
		"type": "crisis",
		"contract_template": {
			"goal_type": "reach_score",
			"goal_value": 12,
			"turns_remaining": 3,
		},
		"reward_bundle": {"score_bonus": 4},
		"penalty_bundle": {"score_penalty": 2},
	})

	assert_eq(contract["goal_type"], "reach_score")
	assert_eq(contract["goal_value"], 12)
	assert_eq(contract["turns_remaining"], 3)
	assert_eq(contract["reward_bundle"]["score_bonus"], 4)
	assert_eq(contract["penalty_bundle"]["score_penalty"], 2)
	assert_false(contract.get("ends_run_on_failure", true))
	assert_eq(contract["progress_value"], 0)
	assert_eq(contract["status"], "active")
	assert_false(contract.get("resolved", true))

func test_advance_contract_counts_down_and_keeps_progress() -> void:
	var service_script := load("res://scripts/core/services/contract_service.gd")

	assert_not_null(service_script)
	if service_script == null:
		return

	var service = service_script.new()
	var contract: Dictionary = service.build_contract({
		"id": "growth_gamble",
		"type": "crisis",
		"contract_template": {
			"goal_type": "reach_score",
			"goal_value": 12,
			"turns_remaining": 3,
		},
		"reward_bundle": {"score_bonus": 4},
		"penalty_bundle": {"score_penalty": 2},
	})

	var advanced: Dictionary = service.advance_contract(contract, {"score_gained": 3})

	assert_eq(advanced["turns_remaining"], 2)
	assert_eq(advanced["progress_value"], 3)
	assert_eq(advanced["status"], "active")
	assert_false(advanced.get("resolved", true))

func test_advance_contract_resolves_success_and_returns_reward_delta() -> void:
	var service_script := load("res://scripts/core/services/contract_service.gd")

	assert_not_null(service_script)
	if service_script == null:
		return

	var service = service_script.new()
	var contract: Dictionary = service.build_contract({
		"id": "growth_gamble",
		"type": "crisis",
		"contract_template": {
			"goal_type": "reach_score",
			"goal_value": 12,
			"turns_remaining": 3,
		},
		"reward_bundle": {"score_bonus": 4},
		"penalty_bundle": {"score_penalty": 2},
	})

	var resolved: Dictionary = service.advance_contract(contract, {"score_gained": 12})

	assert_eq(resolved["status"], "success")
	assert_true(resolved.get("resolved", false))
	assert_eq(service.apply_resolution_score_delta(resolved), 4)

func test_advance_contract_resolves_failure_and_returns_penalty_delta() -> void:
	var service_script := load("res://scripts/core/services/contract_service.gd")

	assert_not_null(service_script)
	if service_script == null:
		return

	var service = service_script.new()
	var contract: Dictionary = service.build_contract({
		"id": "growth_gamble",
		"type": "crisis",
		"contract_template": {
			"goal_type": "reach_score",
			"goal_value": 12,
			"turns_remaining": 1,
		},
		"reward_bundle": {"score_bonus": 4},
		"penalty_bundle": {"score_penalty": 2},
	})

	var resolved: Dictionary = service.advance_contract(contract, {"score_gained": 3})

	assert_eq(resolved["status"], "failed")
	assert_true(resolved.get("resolved", false))
	assert_eq(service.apply_resolution_score_delta(resolved), -2)
