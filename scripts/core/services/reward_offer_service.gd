# 奖励选择服务：
# - 负责生成回合结束后的三选一 token 奖励，并把选中的 token 添加到 `RunSession.token_pool`。
# - 从全量可出现的 token 中按稀有度权重做不放回抽选（所有 token 均可出现，含背包中已有的）。
# - 稀有度权重：Common 4 / Uncommon 3 / Rare 2 / Legendary 1。
# - 典型联动：`RunScreen` 在 `offer_choice` 状态生成按钮，在玩家点按钮后把选择交给这里执行。
class_name RewardOfferService
extends RefCounted

const RARITY_WEIGHTS: Dictionary = {
	"Common":    4.0,
	"Uncommon":  3.0,
	"Rare":      2.0,
	"Legendary": 1.0,
}

func build_turn_offer(run_session: RunSession, content_registry: ContentRegistry) -> Array[Dictionary]:
	var candidate_ids := _eligible_token_ids(content_registry)
	var base_seed := run_session.current_turn * 100 + run_session.phase_index
	var picked := _weighted_sample_without_replacement(candidate_ids, content_registry, 3, base_seed)

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

# 返回所有 spawn_rules.weight > 0 的 token id（含背包中已有的）。
func _eligible_token_ids(content_registry: ContentRegistry) -> Array[String]:
	var ids: Array[String] = []
	for token_id in content_registry.tokens.keys():
		var definition: TokenDefinition = content_registry.tokens[token_id]
		if definition.spawn_rules.get("weight", 0.0) > 0.0:
			ids.append(String(token_id))
	return ids

# 按稀有度权重不放回抽 count 个不重复的 token id。
func _weighted_sample_without_replacement(candidate_ids: Array[String], content_registry: ContentRegistry, count: int, seed_value: int) -> Array[String]:
	if candidate_ids.is_empty():
		return []

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	# 构建含权重的候选池
	var pool: Array[Dictionary] = []
	for token_id in candidate_ids:
		var definition: TokenDefinition = content_registry.tokens.get(token_id)
		if definition == null:
			continue
		var w: float = RARITY_WEIGHTS.get(definition.rarity, 1.0)
		pool.append({"id": token_id, "weight": w})

	var result: Array[String] = []
	for _i in mini(count, pool.size()):
		var total_weight := 0.0
		for entry in pool:
			total_weight += entry["weight"]

		var roll := rng.randf() * total_weight
		var accumulated := 0.0
		for j in pool.size():
			accumulated += pool[j]["weight"]
			if roll <= accumulated:
				result.append(pool[j]["id"])
				pool.remove_at(j)
				break

	return result
