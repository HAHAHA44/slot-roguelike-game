class_name L10n
extends RefCounted

static func text(key: String, fallback: String = "") -> String:
	var normalized_key := key.strip_edges()
	if normalized_key.is_empty():
		return fallback

	var translated := String(TranslationServer.translate(normalized_key))
	if translated == normalized_key and not fallback.is_empty():
		return fallback
	return translated

static func format_text(key: String, params: Dictionary, fallback: String = "") -> String:
	return text(key, fallback).format(params)

static func rarity_name(rarity: String) -> String:
	return text("label.rarity.%s" % _normalize_key(rarity), rarity)

static func token_type_name(type_name: String) -> String:
	return text("label.token_type.%s" % _normalize_key(type_name), type_name)

static func tag_name(tag: String) -> String:
	return text("label.tag.%s" % _normalize_key(tag), tag)

static func phase_name(phase: String) -> String:
	return text("settlement.phase.%s" % _normalize_key(phase), _humanize_identifier(phase))

static func state_name(state_name: String) -> String:
	return text("state.%s" % _normalize_key(state_name), _humanize_identifier(state_name))

static func mode_name(mode_name: String) -> String:
	return text("mode.%s" % _normalize_key(mode_name), _humanize_identifier(mode_name))

static func contract_goal_name(goal_type: String) -> String:
	return text("contract.goal.%s" % _normalize_key(goal_type), _humanize_identifier(goal_type))

static func _normalize_key(value: String) -> String:
	return value.strip_edges().replace(" ", "_").replace("-", "_").to_lower()

static func _humanize_identifier(value: String) -> String:
	return value.strip_edges().replace("_", " ").capitalize()
