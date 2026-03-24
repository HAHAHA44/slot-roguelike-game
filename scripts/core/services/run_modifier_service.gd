class_name RunModifierService
extends RefCounted

func apply_hero_to_penalty(hero_definition: HeroDefinition, penalty_bundle: Dictionary) -> Dictionary:
	var adjusted := penalty_bundle.duplicate(true)
	var multiplier := float(hero_definition.event_weight_modifiers.get("crisis_penalty_multiplier", 1.0))
	if adjusted.has("score_penalty"):
		adjusted["score_penalty"] = int(round(int(adjusted["score_penalty"]) * multiplier))
	return adjusted

func apply_difficulty_to_event_weights(weights: Dictionary, difficulty_modifier: DifficultyModifier) -> Dictionary:
	var adjusted := weights.duplicate(true)
	var modifiers: Dictionary = difficulty_modifier.modifiers
	adjusted["crisis"] = float(adjusted.get("crisis", 1.0)) + float(modifiers.get("crisis_weight_bonus", 0.0))
	adjusted["stable"] = float(adjusted.get("stable", 1.0)) * float(modifiers.get("stable_weight_multiplier", 1.0))
	return adjusted

func hero_tag_modifiers(hero_definition: HeroDefinition) -> Dictionary:
	var modifiers := hero_definition.event_weight_modifiers.duplicate(true)
	modifiers.erase("crisis_penalty_multiplier")
	return modifiers

func difficulty_tag_modifiers(difficulty_modifier: DifficultyModifier) -> Dictionary:
	var modifiers: Dictionary = difficulty_modifier.modifiers
	return {
		"crisis": float(modifiers.get("crisis_weight_bonus", 0.0)),
		"stable": float(modifiers.get("stable_weight_multiplier", 1.0)),
		"quality_penalty": float(modifiers.get("quality_penalty", 0.0)),
	}
