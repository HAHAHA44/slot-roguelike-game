# 事件服务：
# - 每轮奖励结算后，50% 概率触发事件；若触发，三种事件各 1/3 概率。
# - 事件1 copy_token：从 token_pool 随机复制（新增）一个 token。
# - 事件2 delete_token：从 token_pool 随机删除一个 token（池内至少保留 1 个时才删）。
# - 事件3 item：占位事件，暂无效果。
# - build_event 返回描述事件内容的字典；apply_event 负责执行实际效果。
# - 典型联动：RunScreen 在 offer_choice 之后调用 build_event，在玩家确认后调用 apply_event。
class_name EventDraftService
extends RefCounted

const EMPTY_TOKEN_ID := "empty_token"

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
			return _copy_token_event(run_session, rng)
		1:
			return _delete_token_event(run_session, rng)
		_:
			return _item_event()

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

func _item_event() -> Dictionary:
	return {
		"event_type": "item",
		"title": "神秘道具",
		"description": "获得一件神秘道具。（功能待开放）",
		"token_id": "",
		"token_name": "",
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
