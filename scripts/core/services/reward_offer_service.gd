# 奖励选择服务：
# - 负责生成回合结束后的三选一 token 奖励，并把选中的 token 添加到 `RunSession.token_pool`。
# - 每次出三个不重复的 token 候选，优先从"尚未拥有的"池中挑，候选为空时从全量 token 池补充。
# - 它同时读取 `ContentRegistry` 来决定可选 token，读取 `RunSession` 来知道当前回合和当前池状态。
# - 典型联动：`RunScreen` 在 `offer_choice` 状态生成按钮，在玩家点按钮后把选择交给这里执行。
class_name RewardOfferService
extends RefCounted

func build_turn_offer(run_session: RunSession, content_registry: ContentRegistry) -> Array[Dictionary]:
	var candidate_ids := _unlockable_token_ids(run_session, content_registry)
	if candidate_ids.is_empty():
		candidate_ids = _ordered_token_ids(content_registry)

	var base_seed := run_session.current_turn * 100 + run_session.phase_index
	var picked := _pick_distinct_token_ids(candidate_ids, 3, base_seed)

	var offers: Array[Dictionary] = []
	for token_id in picked:
		offers.append({
			"kind": "add_token",
			"phase_index": run_session.phase_index,
			"token_id": token_id,
			"token_candidates": candidate_ids.duplicate(),
			"weight_profile": {"rarity": "weighted", "tags": "open"},
		})
	return offers

func apply_offer(run_session: RunSession, offer: Dictionary) -> Dictionary:
	var resolution := {
		"kind": String(offer.get("kind", "")),
		"token_id": String(offer.get("token_id", "")),
		"changed": false,
		"active_token_id": run_session.get_active_token_id(),
	}

	match resolution["kind"]:
		"add_token":
			var token_id := String(resolution["token_id"])
			if not token_id.is_empty():
				run_session.pool_add(token_id)
				run_session.focus_token(token_id)
				resolution["changed"] = true

	resolution["active_token_id"] = run_session.get_active_token_id()
	return resolution

func _ordered_token_ids(content_registry: ContentRegistry) -> Array[String]:
	var weighted_entries: Array[Dictionary] = []
	for token_id in content_registry.tokens.keys():
		var definition: TokenDefinition = content_registry.tokens[token_id]
		var weight := float(definition.spawn_rules.get("weight", 0.0))
		if weight <= 0.0:
			continue
		weighted_entries.append({
			"id": String(token_id),
			"weight": weight,
		})

	weighted_entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if left["weight"] == right["weight"]:
			return left["id"] < right["id"]
		return left["weight"] > right["weight"]
	)

	var ordered_ids: Array[String] = []
	for entry in weighted_entries:
		ordered_ids.append(String(entry["id"]))
	return ordered_ids

func _unlockable_token_ids(run_session: RunSession, content_registry: ContentRegistry) -> Array[String]:
	var candidate_ids: Array[String] = []
	for token_id in _ordered_token_ids(content_registry):
		if not run_session.token_pool.has(token_id):
			candidate_ids.append(token_id)
	return candidate_ids

func _pick_distinct_token_ids(candidate_ids: Array[String], count: int, seed_value: int) -> Array[String]:
	if candidate_ids.is_empty():
		return []
	var result: Array[String] = []
	var size := candidate_ids.size()
	var start := posmod(seed_value, size)
	for i in size:
		if result.size() >= count:
			break
		result.append(candidate_ids[posmod(start + i, size)])
	return result
