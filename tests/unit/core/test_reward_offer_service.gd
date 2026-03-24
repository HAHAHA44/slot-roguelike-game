extends GutTest

func test_turn_offer_contains_add_remove_random() -> void:
	var reward_offer_service_script := load("res://scripts/core/services/reward_offer_service.gd")
	var run_session_script := load("res://autoload/run_session.gd")

	assert_not_null(reward_offer_service_script)
	assert_not_null(run_session_script)
	if reward_offer_service_script == null or run_session_script == null:
		return

	var offers = reward_offer_service_script.new().build_turn_offer(run_session_script.new())

	assert_eq(offers.map(func(item: Dictionary): return item["kind"]), ["add_token", "remove_token", "random_token"])

func test_run_session_round_trips_via_dict() -> void:
	var run_session_script := load("res://autoload/run_session.gd")

	assert_not_null(run_session_script)
	if run_session_script == null:
		return

	var session = run_session_script.new()
	session.current_turn = 3
	session.phase_index = 1
	session.phase_target = 25
	session.current_score = 11
	session.operation_history = [
		{"kind": "add_token", "token_id": "pulse_seed"}
	]
	session.active_modifiers = [
		{"kind": "hero_bias", "value": "Insight"}
	]

	var restored = run_session_script.from_dict(session.to_dict())

	assert_eq(restored.schema_version, 1)
	assert_eq(restored.current_turn, 3)
	assert_eq(restored.phase_index, 1)
	assert_eq(restored.phase_target, 25)
	assert_eq(restored.current_score, 11)
	assert_eq(restored.operation_history.size(), 1)
	assert_eq(restored.active_modifiers.size(), 1)
