extends GutTest

func test_ascension_raises_crisis_bias_and_lowers_stable_quality() -> void:
	var service_script := load("res://scripts/core/services/run_modifier_service.gd")
	var difficulty := load("res://content/difficulty/ascension_2.tres")

	assert_not_null(service_script)
	assert_not_null(difficulty)
	if service_script == null or difficulty == null:
		return

	var service = service_script.new()
	var weights: Dictionary = service.apply_difficulty_to_event_weights(
		{"crisis": 1.0, "stable": 1.0},
		difficulty
	)

	assert_gt(weights["crisis"], 1.0)
	assert_lt(weights["stable"], 1.0)
