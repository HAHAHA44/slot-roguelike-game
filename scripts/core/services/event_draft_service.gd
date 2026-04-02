# 事件服务：
# - 每轮奖励结算后，50% 概率触发事件；若触发，三种事件各 1/3 概率。
# - 事件1 copy_token：从 token_pool 随机复制（新增）一个 token（玩家从 picker 选）。
# - 事件2 delete_token：从 token_pool 随机删除一个 token（玩家从 picker 选）。
# - 事件3 item：从注册表随机选一件道具发放；
#     - passive 道具：加入道具栏，结算时持续生效。
#     - instant 道具：拾起时立即执行效果（upgrade_random / delete_random），不进道具栏。
# - build_event 返回描述事件内容的字典；apply_event 负责执行实际效果。
# - 典型联动：RunScreen 在 offer_choice 之后调用 build_event，在玩家确认后调用 apply_event。
class_name EventDraftService
extends RefCounted

const EMPTY_TOKEN_ID := "empty_token"
const RARITY_ORDER := ["Common", "Uncommon", "Rare", "Legendary"]

var _content_registry = null

func _init(content_registry = null) -> void:
	_content_registry = content_registry

# 根据 seed_value 决定本轮事件内容，返回描述事件的字典。
# 返回字段：event_type, title, description, token_id（可为空）, token_name（可为空）
func build_event(run_session: RunSession, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	# 50% 概率无事件
	if rng.randf() >= 0.5:
		return _no_event()

	# 三种事件各 1/3
	match rng.randi_range(0, 2):
		0:
			return _copy_token_event(run_session)
		1:
			return _delete_token_event(run_session)
		_:
			return _item_event(rng)

# 执行事件效果（在玩家确认后调用）。
func apply_event(run_session: RunSession, event: Dictionary) -> void:
	match String(event.get("event_type", "")):
		"copy_token":
			var token_id := String(event.get("token_id", ""))
			if not token_id.is_empty():
				run_session.pool_add(token_id)
		"delete_token":
			var token_id := String(event.get("token_id", ""))
			if not token_id.is_empty():
				run_session.pool_remove(token_id)
		"item":
			var item_def = event.get("item_def")
			if item_def == null:
				return
			if String(item_def.effect_type) == "instant":
				_apply_instant_item(run_session, item_def, event)

# ---------------------------------------------------------------------------
# 私有构建辅助
# ---------------------------------------------------------------------------

func _no_event() -> Dictionary:
	return {
		"event_type": "no_event",
		"title": "今日无事",
		"description": "风平浪静，继续前进。",
		"token_id": "",
		"token_name": "",
	}

func _item_event(rng: RandomNumberGenerator) -> Dictionary:
	if _content_registry == null or _content_registry.items.is_empty():
		return _no_event()

	var item_ids: Array = _content_registry.items.keys()
	var picked_id: String = item_ids[rng.randi() % item_ids.size()]
	var item_def: ItemDefinition = _content_registry.items[picked_id]

	return {
		"event_type": "item",
		"title": "获得道具：%s" % item_def.name,
		"description": item_def.description,
		"token_id": "",
		"token_name": "",
		"item_id": item_def.id,
		"item_effect_type": item_def.effect_type,
		"item_def": item_def,
	}

func _copy_token_event(run_session: RunSession) -> Dictionary:
	var eligible := _eligible_pool_tokens(run_session)
	if eligible.is_empty():
		return _no_event()
	return {
		"event_type": "copy_token",
		"title": "复制 Token",
		"description": "选择一个背包中的 Token 进行复制。",
		"token_id": "",
		"token_name": "",
		"needs_token_pick": true,
		"eligible_tokens": eligible,
	}

func _delete_token_event(run_session: RunSession) -> Dictionary:
	var eligible := _eligible_pool_tokens(run_session)
	if eligible.size() <= 1:
		return _no_event()
	return {
		"event_type": "delete_token",
		"title": "删除 Token",
		"description": "选择一个背包中的 Token 将其删除。",
		"token_id": "",
		"token_name": "",
		"needs_token_pick": true,
		"eligible_tokens": eligible,
	}

# ---------------------------------------------------------------------------
# 即时道具效果
# ---------------------------------------------------------------------------

func _apply_instant_item(run_session: RunSession, item_def: ItemDefinition, event: Dictionary) -> void:
	var action := String(item_def.effect_data.get("action", ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = run_session.current_turn * 7919 + run_session.current_score * 31

	match action:
		"upgrade_random":
			_apply_upgrade_random(run_session, rng)
		"delete_random":
			var count := int(item_def.effect_data.get("count", 1))
			_apply_delete_random(run_session, rng, count)

func _apply_upgrade_random(run_session: RunSession, rng: RandomNumberGenerator) -> void:
	# 收集可升级的 token（非传说稀有度，且下一稀有度版本存在于注册表中）
	var upgradable: Array[String] = []
	for token_id in run_session.token_pool:
		if token_id == EMPTY_TOKEN_ID:
			continue
		var def: TokenDefinition = _content_registry.tokens.get(token_id) if _content_registry else null
		if def == null:
			continue
		var next_id := _find_next_rarity_token(def)
		if not next_id.is_empty():
			upgradable.append(token_id)

	if upgradable.is_empty():
		return

	var chosen_id: String = upgradable[rng.randi() % upgradable.size()]
	var chosen_def: TokenDefinition = _content_registry.tokens.get(chosen_id)
	var next_id := _find_next_rarity_token(chosen_def)

	run_session.pool_remove(chosen_id)
	run_session.pool_add(next_id)

func _apply_delete_random(run_session: RunSession, rng: RandomNumberGenerator, count: int) -> void:
	for _i in count:
		# 过滤掉 empty_token
		var eligible: Array[String] = []
		for token_id in run_session.token_pool:
			if token_id != EMPTY_TOKEN_ID:
				eligible.append(token_id)
		if eligible.is_empty():
			break
		var chosen: String = eligible[rng.randi() % eligible.size()]
		run_session.pool_remove(chosen)

# 给定一个 TokenDefinition，在注册表中查找同 type、下一稀有度的 token id；找不到返回空字符串。
func _find_next_rarity_token(def: TokenDefinition) -> String:
	if _content_registry == null:
		return ""
	var current_rarity_idx := RARITY_ORDER.find(def.rarity)
	if current_rarity_idx < 0 or current_rarity_idx >= RARITY_ORDER.size() - 1:
		return ""  # 已是 Legendary 或未知稀有度
	var next_rarity: String = RARITY_ORDER[current_rarity_idx + 1]
	for token_id in _content_registry.tokens.keys():
		var candidate: TokenDefinition = _content_registry.tokens[token_id]
		if candidate.type == def.type and candidate.rarity == next_rarity:
			return candidate.id
	return ""

# ---------------------------------------------------------------------------
# 工具方法
# ---------------------------------------------------------------------------

# 返回 pool 中去重后的非空 token id 列表。
func _eligible_pool_tokens(run_session: RunSession) -> Array[String]:
	var seen: Dictionary = {}
	var result: Array[String] = []
	for token_id in run_session.token_pool:
		if token_id == EMPTY_TOKEN_ID or seen.has(token_id):
			continue
		seen[token_id] = true
		result.append(token_id)
	return result

func _get_token_name(token_id: String) -> String:
	if _content_registry == null:
		return token_id
	var def: TokenDefinition = _content_registry.tokens.get(token_id)
	return def.name if def else token_id
