# 事件草案服务：
# - 根据当前棋盘、英雄偏向和难度修正，从内容池里挑出 3 个事件候选。
# - 它读的是“结算快照”和“修正字典”，不直接读 UI，也不直接操作合约。
# - 排序规则把棋盘标签、英雄 modifiers、难度 modifiers 都折算进 event score，然后挑前 3 个，并保证至少有 1 个 stable 选项。
# - 典型联动：`RunScreen` 在 reward 之后、event_draft 状态里调用它，结果再交给事件按钮 UI。
class_name EventDraftService
extends RefCounted

var _events: Array = []

func _init(event_source = null) -> void:
	_events = _normalize_event_source(event_source)

func build_offer(run_snapshot: RunSnapshot, hero_modifiers: Dictionary = {}, difficulty_modifiers: Dictionary = {}) -> Dictionary:
	var board_tags: Dictionary = run_snapshot.phase_effects.get("board_tags", {})
	var weighted_events: Array[Dictionary] = []

	for entry in _events:
		var event_data := _normalize_event(entry)
		if event_data.is_empty():
			continue

		var score := float(event_data.get("weight", 1.0))
		score += float(board_tags.get(event_data.get("primary_tag", ""), 0)) * 2.0
		score += float(hero_modifiers.get(event_data.get("primary_tag", ""), 0.0))
		score += float(difficulty_modifiers.get(event_data.get("primary_tag", ""), 0.0))
		event_data["score"] = score
		weighted_events.append(event_data)

	weighted_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(a["score"], b["score"]):
			if a["stability"] == b["stability"]:
				return String(a["id"]) < String(b["id"])
			return a["stability"] == "stable"
		return a["score"] > b["score"]
	)

	var options: Array[Dictionary] = []
	for event_data in weighted_events:
		options.append(event_data)
		if options.size() == 3:
			break

	if not options.any(func(event_data: Dictionary): return event_data.get("stability", "") == "stable"):
		for event_data in weighted_events:
			if event_data.get("stability", "") != "stable":
				continue
			if options.any(func(existing: Dictionary): return existing.get("id", "") == event_data.get("id", "")):
				continue
			if options.is_empty():
				options.append(event_data)
			else:
				options[options.size() - 1] = event_data
			break

	return {
		"options": options,
		"board_tags": board_tags.duplicate(true),
	}

func _normalize_event_source(event_source) -> Array:
	if event_source == null:
		return []
	if event_source is Array:
		return event_source
	if event_source is ContentRegistry:
		return event_source.events.values()
	if typeof(event_source) == TYPE_DICTIONARY and event_source.has("events"):
		return event_source["events"]
	return []

func _normalize_event(entry) -> Dictionary:
	if entry is Dictionary:
		return entry.duplicate(true)
	if entry is EventDefinition:
		return {
			"id": entry.id,
			"name": entry.name,
			"type": entry.type,
			"primary_tag": entry.primary_tag,
			"stability": entry.stability,
			"weight": entry.weight,
			"description": entry.description,
			"reward_bundle": entry.reward_bundle.duplicate(true),
			"penalty_bundle": entry.penalty_bundle.duplicate(true),
			"contract_template": entry.contract_template.duplicate(true),
		}
	return {}
