class_name ContractService
extends RefCounted

func build_contract(event_data) -> Dictionary:
	var normalized := _normalize_event(event_data)
	var template: Dictionary = normalized.get("contract_template", {})

	return {
		"id": "%s_contract" % normalized.get("id", "event"),
		"event_id": normalized.get("id", ""),
		"event_name": normalized.get("name", ""),
		"goal_type": template.get("goal_type", "reach_score"),
		"goal_value": int(template.get("goal_value", 10)),
		"turns_remaining": int(template.get("turns_remaining", 3)),
		"reward_bundle": normalized.get("reward_bundle", {}).duplicate(true),
		"penalty_bundle": normalized.get("penalty_bundle", {}).duplicate(true),
		"ends_run_on_failure": false,
	}

func summarize_contract(contract: Dictionary) -> String:
	return "Goal %s %s in %s turns | Reward %+d | Penalty -%d" % [
		contract.get("goal_type", "reach_score"),
		contract.get("goal_value", 0),
		contract.get("turns_remaining", 0),
		int(contract.get("reward_bundle", {}).get("score_bonus", 0)),
		int(contract.get("penalty_bundle", {}).get("score_penalty", 0)),
	]

func _normalize_event(event_data) -> Dictionary:
	if event_data is Dictionary:
		return event_data
	if event_data is EventDefinition:
		return {
			"id": event_data.id,
			"name": event_data.name,
			"contract_template": event_data.contract_template.duplicate(true),
			"reward_bundle": event_data.reward_bundle.duplicate(true),
			"penalty_bundle": event_data.penalty_bundle.duplicate(true),
		}
	return {}
