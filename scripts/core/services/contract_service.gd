# 合约服务：
# - 把事件数据转成一份可推进的合约，并在每个回合后根据得分推进进度。
# - 负责合约的创建、成功/失败判定、奖励/惩罚分数结算，以及合约文本摘要。
# - 它只处理合约本身，不决定玩家该选哪个事件，也不决定棋盘怎么结算。
# - 典型联动：`RunScreen` 在选事件后调用 `build_contract()`，在每轮结算后调用 `advance_contract()`。
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
		"progress_value": 0,
		"status": "active",
		"resolved": false,
		"reward_bundle": normalized.get("reward_bundle", {}).duplicate(true),
		"penalty_bundle": normalized.get("penalty_bundle", {}).duplicate(true),
		"ends_run_on_failure": false,
	}

func summarize_contract(contract: Dictionary) -> String:
	var status := String(contract.get("status", "active"))
	var goal_name := L10n.contract_goal_name(String(contract.get("goal_type", "reach_score")))
	var goal_value := int(contract.get("goal_value", 0))
	var reward := int(contract.get("reward_bundle", {}).get("score_bonus", 0))
	var penalty := int(contract.get("penalty_bundle", {}).get("score_penalty", 0))
	if status == "success":
		return L10n.format_text("contract.summary.success", {
			"goal": goal_name,
			"value": goal_value,
			"reward": reward,
		})
	if status == "failed":
		return L10n.format_text("contract.summary.failed", {
			"goal": goal_name,
			"value": goal_value,
			"penalty": penalty,
		})

	return L10n.format_text("contract.summary.active", {
		"goal": goal_name,
		"value": goal_value,
		"turns": int(contract.get("turns_remaining", 0)),
		"reward": reward,
		"penalty": penalty,
	})

func advance_contract(contract: Dictionary, turn_result: Dictionary) -> Dictionary:
	var advanced := contract.duplicate(true)
	if advanced.is_empty():
		return advanced
	if String(advanced.get("status", "active")) != "active":
		return advanced

	advanced["progress_value"] = int(advanced.get("progress_value", 0)) + _resolve_progress_delta(advanced, turn_result)
	if int(advanced.get("progress_value", 0)) >= int(advanced.get("goal_value", 0)):
		return resolve_contract_success(advanced)

	advanced["turns_remaining"] = max(0, int(advanced.get("turns_remaining", 0)) - 1)
	if int(advanced.get("turns_remaining", 0)) <= 0:
		return resolve_contract_failure(advanced)

	return advanced

func resolve_contract_success(contract: Dictionary) -> Dictionary:
	var resolved := contract.duplicate(true)
	resolved["status"] = "success"
	resolved["resolved"] = true
	return resolved

func resolve_contract_failure(contract: Dictionary) -> Dictionary:
	var resolved := contract.duplicate(true)
	resolved["status"] = "failed"
	resolved["resolved"] = true
	return resolved

func apply_resolution_score_delta(contract: Dictionary) -> int:
	match String(contract.get("status", "active")):
		"success":
			return int(contract.get("reward_bundle", {}).get("score_bonus", 0))
		"failed":
			return -int(contract.get("penalty_bundle", {}).get("score_penalty", 0))
	return 0

func _resolve_progress_delta(contract: Dictionary, turn_result: Dictionary) -> int:
	match String(contract.get("goal_type", "reach_score")):
		"reach_score":
			return int(turn_result.get("score_gained", 0))
	return 0

func _normalize_event(event_data) -> Dictionary:
	if event_data is Dictionary:
		return event_data
	if event_data is EventDefinition:
		return {
			"id": event_data.id,
			"name": event_data.get_display_name(),
			"contract_template": event_data.contract_template.duplicate(true),
			"reward_bundle": event_data.reward_bundle.duplicate(true),
			"penalty_bundle": event_data.penalty_bundle.duplicate(true),
		}
	return {}
