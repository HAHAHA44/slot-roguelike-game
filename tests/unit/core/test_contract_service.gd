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
