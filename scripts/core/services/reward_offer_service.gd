class_name RewardOfferService
extends RefCounted

func build_turn_offer(run_session: RunSession, content_registry: ContentRegistry) -> Array[Dictionary]:
	var unlockable_ids := _unlockable_token_ids(run_session, content_registry)
	var all_token_ids := _ordered_token_ids(content_registry)
	var add_token_id := _pick_token_id(unlockable_ids if not unlockable_ids.is_empty() else all_token_ids, run_session.current_turn + run_session.phase_index)
	var random_token_id := _pick_token_id(all_token_ids, (run_session.current_turn * 2) + run_session.phase_index + 1)
	var removable_token_id := _pick_removable_token_id(run_session)

	return [
		{
			"kind": "add_token",
			"phase_index": run_session.phase_index,
			"token_id": add_token_id,
			"token_candidates": unlockable_ids.duplicate(),
			"weight_profile": {"rarity": "weighted", "tags": "open"},
		},
		{
			"kind": "remove_token",
			"phase_index": run_session.phase_index,
			"token_id": removable_token_id,
			"weight_profile": {"rarity": "none", "tags": "cleanup"},
		},
		{
			"kind": "random_token",
			"phase_index": run_session.phase_index,
			"token_id": random_token_id,
			"token_candidates": all_token_ids.duplicate(),
			"weight_profile": {"rarity": "weighted", "tags": "phase_biased"},
		},
	]

func apply_offer(run_session: RunSession, offer: Dictionary) -> Dictionary:
	var resolution := {
		"kind": String(offer.get("kind", "")),
		"token_id": String(offer.get("token_id", "")),
		"changed": false,
		"active_token_id": run_session.get_active_token_id(),
	}

	match resolution["kind"]:
		"add_token", "random_token":
			var token_id := String(resolution["token_id"])
			var changed := run_session.add_token_to_pool(token_id)
			run_session.focus_token(token_id)
			resolution["changed"] = changed or run_session.get_active_token_id() == token_id
		"remove_token":
			var target_token_id := String(resolution["token_id"])
			if target_token_id.is_empty():
				target_token_id = _pick_removable_token_id(run_session)
				resolution["token_id"] = target_token_id
			resolution["changed"] = run_session.remove_token_from_pool(target_token_id)

	resolution["active_token_id"] = run_session.get_active_token_id()
	return resolution

func _ordered_token_ids(content_registry: ContentRegistry) -> Array[String]:
	var weighted_entries: Array[Dictionary] = []
	for token_id in content_registry.tokens.keys():
		var definition: TokenDefinition = content_registry.tokens[token_id]
		weighted_entries.append({
			"id": String(token_id),
			"weight": float(definition.spawn_rules.get("weight", 0.0)),
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

func _pick_token_id(candidate_ids: Array[String], seed_value: int) -> String:
	if candidate_ids.is_empty():
		return ""
	return candidate_ids[posmod(seed_value, candidate_ids.size())]

func _pick_removable_token_id(run_session: RunSession) -> String:
	if run_session.token_pool.size() <= 1:
		return ""
	var active_token_id := run_session.get_active_token_id()
	if active_token_id != RunSession.DEFAULT_TOKEN_ID:
		return active_token_id
	for token_id in run_session.token_pool:
		if token_id != RunSession.DEFAULT_TOKEN_ID:
			return token_id
	return ""
