# 运行修正器：
# - 把英雄和难度资源转成“运行时可消费的修正数据”，供事件草案和合约惩罚使用。
# - 它不直接改资源文件，只返回修改后的字典，保证内容资源本身保持静态。
# - 典型联动：`RunScreen` 从 `ContentRegistry` 取 hero / difficulty，再交给这里生成 modifiers，之后传给 `EventDraftService` 和 `ContractService`。
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
