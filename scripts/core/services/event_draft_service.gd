class_name EventDraftService
extends RefCounted

const EMPTY_TOKEN_ID := "empty_token"
const RARITY_ORDER := ["Common", "Uncommon", "Rare", "Legendary"]

var _content_registry = null

func _init(content_registry = null) -> void:
	_content_registry = content_registry

func build_event(run_session: RunSession, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	if rng.randf() >= 0.5:
		return _no_event()

	match rng.randi_range(0, 2):
		0:
			return _copy_token_event(run_session)
		1:
			return _delete_token_event(run_session)
		_:
			return _item_event(rng)

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
				_apply_instant_item(run_session, item_def)

func _no_event() -> Dictionary:
	return {
		"event_type": "no_event",
		"title_key": "event_draft.no_event.title",
		"description_key": "event_draft.no_event.description",
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
		"title_key": "event_draft.item.title",
		"title_params": {"item": item_def.name},
		"description_key": item_def.description,
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
		"title_key": "event_draft.copy_token.title",
		"description_key": "event_draft.copy_token.description",
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
		"title_key": "event_draft.delete_token.title",
		"description_key": "event_draft.delete_token.description",
		"token_id": "",
		"token_name": "",
		"needs_token_pick": true,
		"eligible_tokens": eligible,
	}

func _apply_instant_item(run_session: RunSession, item_def: ItemDefinition) -> void:
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
	var upgradable: Array[String] = []
	var upgradable_next: Dictionary = {}
	for token_id in run_session.token_pool:
		if token_id == EMPTY_TOKEN_ID:
			continue
		var def: TokenDefinition = _content_registry.tokens.get(token_id) if _content_registry else null
		if def == null:
			continue
		var next_id := _find_next_rarity_token(def)
		if not next_id.is_empty():
			upgradable.append(token_id)
			upgradable_next[token_id] = next_id

	if upgradable.is_empty():
		return

	var chosen_id: String = upgradable[rng.randi() % upgradable.size()]
	run_session.pool_remove(chosen_id)
	run_session.pool_add(upgradable_next[chosen_id])

func _apply_delete_random(run_session: RunSession, rng: RandomNumberGenerator, count: int) -> void:
	for _i in count:
		var eligible: Array[String] = []
		for token_id in run_session.token_pool:
			if token_id != EMPTY_TOKEN_ID:
				eligible.append(token_id)
		if eligible.is_empty():
			break
		var chosen: String = eligible[rng.randi() % eligible.size()]
		run_session.pool_remove(chosen)

func _find_next_rarity_token(def: TokenDefinition) -> String:
	if _content_registry == null:
		return ""
	var current_rarity_idx := RARITY_ORDER.find(def.rarity)
	if current_rarity_idx < 0 or current_rarity_idx >= RARITY_ORDER.size() - 1:
		return ""
	var next_rarity: String = RARITY_ORDER[current_rarity_idx + 1]
	for token_id in _content_registry.tokens.keys():
		var candidate: TokenDefinition = _content_registry.tokens[token_id]
		if candidate.type == def.type and candidate.rarity == next_rarity:
			return candidate.id
	return ""

func _eligible_pool_tokens(run_session: RunSession) -> Array[String]:
	var seen: Dictionary = {}
	var result: Array[String] = []
	for token_id in run_session.token_pool:
		if token_id == EMPTY_TOKEN_ID or seen.has(token_id):
			continue
		seen[token_id] = true
		result.append(token_id)
	return result
