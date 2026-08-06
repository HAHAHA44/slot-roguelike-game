# 内容校验器：
# - 在资源加载阶段检查 `id`、枚举值、重复 ID、空字段等基础问题。
# - 目标是把"内容错误"尽量拦在加载时，而不是把坏数据带进运行时再崩。
# - 它只做结构与约束检查，不判断玩法平衡，也不决定某个资源是否"好玩"。
# - 跨资源引用（如碎片的 legacy_into 指向的碎片是否存在）只能在全量加载后才知道，
#   那类检查在 test_content_registry 里做，不在这里。
class_name ContentDefinitionValidator
extends RefCounted

const ZodiacDefinitionScript := preload("res://scripts/content/zodiac_definition.gd")
const LifeStageDefScript := preload("res://scripts/content/life_stage_definition.gd")
const StartingPoolDefScript := preload("res://scripts/content/starting_pool_definition.gd")
const BuffDefinitionScript := preload("res://scripts/content/buff_definition.gd")
const FlavorLineDefScript := preload("res://scripts/content/flavor_line_definition.gd")

const SPIRIT_BUCKETS := ["high", "mid", "low"]

func validate_definition(definition: Resource, existing_ids: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var definition_id := String(definition.get("id")).strip_edges()

	if definition_id.is_empty():
		errors.append("id must not be empty")
	elif existing_ids.has(definition_id):
		errors.append("duplicate id: %s" % definition_id)

	if definition is TokenDefinition:
		_validate_token_definition(definition, errors)
	elif definition is EventDefinition:
		_validate_event_definition(definition, errors)
	elif definition is FlavorLineDefScript:
		_validate_flavor_line_definition(definition, errors)
	elif definition is HeroDefinition:
		_validate_hero_definition(definition, errors)
	elif definition is DifficultyModifier:
		_validate_difficulty_modifier(definition, errors)
	elif definition is MetaUnlockDefinition:
		_validate_meta_unlock_definition(definition, errors)
	elif definition is AnomalyDefinition:
		_validate_anomaly_definition(definition, errors)
	elif definition is ItemDefinition:
		_validate_item_definition(definition, errors)
	elif definition is ZodiacDefinitionScript:
		_validate_zodiac_definition(definition, errors)
	elif definition is LifeStageDefScript:
		_validate_life_stage_definition(definition, errors)
	elif definition is StartingPoolDefScript:
		_validate_starting_pool_definition(definition, errors)
	elif definition is BuffDefinitionScript:
		_validate_buff_definition(definition, errors)

	return errors

func _validate_token_definition(definition: TokenDefinition, errors: Array[String]) -> void:
	if definition.name.strip_edges().is_empty():
		errors.append("name must not be empty")
	if definition.rarity not in TokenDefinition.ALLOWED_RARITIES:
		errors.append("rarity must be one of %s" % ", ".join(TokenDefinition.ALLOWED_RARITIES))
	if definition.tags == null:
		errors.append("tags must not be null")
	if definition.base_score < 0:
		errors.append("base_score must not be negative")
	if definition.draft_weight < 0.0:
		errors.append("draft_weight must not be negative")
	# 可抽的碎片必须归属某个阶段，否则它永远不会出现在任何投注池里（分池的前提）。
	if definition.is_draftable() and definition.stage_id.strip_edges().is_empty():
		errors.append("draftable token must declare a stage_id")
	# 传承物不该再被抽到，否则玩家可以绕过「练满星」直接拿到它。
	if definition.is_legacy and definition.draft_weight > 0.0:
		errors.append("legacy token must have draft_weight = 0")

func _validate_event_definition(definition: EventDefinition, errors: Array[String]) -> void:
	if definition.name.strip_edges().is_empty():
		errors.append("name must not be empty")
	if definition.kind not in EventDefinition.ALLOWED_KINDS:
		errors.append("kind must be one of %s" % ", ".join(EventDefinition.ALLOWED_KINDS))
	if definition.spirit_weights == null:
		errors.append("spirit_weights must not be null")
		return
	var total_weight: float = 0.0
	for bucket in definition.spirit_weights:
		if String(bucket) not in SPIRIT_BUCKETS:
			errors.append("spirit_weights key must be one of %s" % ", ".join(SPIRIT_BUCKETS))
		total_weight += float(definition.spirit_weights[bucket])
	if total_weight <= 0.0:
		errors.append("spirit_weights must give a positive weight in at least one bucket")
	if definition.choices.size() > 4:
		errors.append("choices must not exceed 4 (fun-axes 规定每事件 ≤ 4 个选项)")
	# 致死事件只许在低精神档出现——这是「死亡轮盘只在垮掉时开启」的硬保证，
	# 内容写错时必须在加载期就拦下，而不是等玩家莫名其妙暴毙。
	if definition.is_lethal():
		if float(definition.spirit_weights.get("high", 0.0)) > 0.0 \
				or float(definition.spirit_weights.get("mid", 0.0)) > 0.0:
			errors.append("lethal event must only have weight in the 'low' spirit bucket")

func _validate_flavor_line_definition(definition, errors: Array[String]) -> void:
	if String(definition.text).strip_edges().is_empty():
		errors.append("text must not be empty")
	if not String(definition.spirit_bucket).is_empty() \
			and String(definition.spirit_bucket) not in SPIRIT_BUCKETS:
		errors.append("spirit_bucket must be empty or one of %s" % ", ".join(SPIRIT_BUCKETS))
	if float(definition.weight) < 0.0:
		errors.append("weight must not be negative")

func _validate_hero_definition(definition: HeroDefinition, errors: Array[String]) -> void:
	if definition.name.strip_edges().is_empty():
		errors.append("name must not be empty")
	if definition.starting_passive.strip_edges().is_empty():
		errors.append("starting_passive must not be empty")
	if definition.attribute_bias not in HeroDefinition.ALLOWED_ATTRIBUTES:
		errors.append("attribute_bias must be one of %s" % ", ".join(HeroDefinition.ALLOWED_ATTRIBUTES))
	if definition.event_weight_modifiers == null:
		errors.append("event_weight_modifiers must not be null")

func _validate_difficulty_modifier(definition: DifficultyModifier, errors: Array[String]) -> void:
	if definition.name.strip_edges().is_empty():
		errors.append("name must not be empty")
	if definition.description.strip_edges().is_empty():
		errors.append("description must not be empty")
	if definition.modifiers == null:
		errors.append("modifiers must not be null")

func _validate_meta_unlock_definition(definition: MetaUnlockDefinition, errors: Array[String]) -> void:
	if definition.name.strip_edges().is_empty():
		errors.append("name must not be empty")
	if definition.unlock_type.strip_edges().is_empty():
		errors.append("unlock_type must not be empty")
	if definition.rewards == null:
		errors.append("rewards must not be null")

func _validate_anomaly_definition(definition: AnomalyDefinition, errors: Array[String]) -> void:
	if definition.name.strip_edges().is_empty():
		errors.append("name must not be empty")
	if definition.anomaly_type.strip_edges().is_empty():
		errors.append("anomaly_type must not be empty")
	if definition.tags == null:
		errors.append("tags must not be null")
	if definition.rules == null:
		errors.append("rules must not be null")

func _validate_item_definition(definition: ItemDefinition, errors: Array[String]) -> void:
	if definition.name.strip_edges().is_empty():
		errors.append("name must not be empty")
	if definition.rarity not in ItemDefinition.ALLOWED_RARITIES:
		errors.append("rarity must be one of %s" % ", ".join(ItemDefinition.ALLOWED_RARITIES))
	if definition.price < 0.0:
		errors.append("price must not be negative")
	if definition.max_stack < 1:
		errors.append("max_stack must be >= 1")
	if definition.min_stage_order < 0:
		errors.append("min_stage_order must be >= 0")

func _validate_zodiac_definition(definition, errors: Array[String]) -> void:
	if definition.display_name.strip_edges().is_empty():
		errors.append("display_name must not be empty")
	if definition.order < 0 or definition.order >= 12:
		errors.append("order must be in [0, 12)")
	# 每个生肖都必须带一条年度规则，否则那一年生肖盘又变回装饰（ADR-0002）。
	if definition.rule_name.strip_edges().is_empty():
		errors.append("rule_name must not be empty (每个生肖都要有年度规则)")

func _validate_life_stage_definition(definition, errors: Array[String]) -> void:
	if definition.display_name.strip_edges().is_empty():
		errors.append("display_name must not be empty")
	if definition.order < 0 or definition.order >= 7:
		errors.append("order must be in [0, 7)")
	if definition.start_age < 0:
		errors.append("start_age must be >= 0")

func _validate_starting_pool_definition(definition, errors: Array[String]) -> void:
	if definition.display_name.strip_edges().is_empty():
		errors.append("display_name must not be empty")
	if definition.filler_token_id.strip_edges().is_empty():
		errors.append("filler_token_id must not be empty (命盘不满时要有东西补位)")
	for token_id in definition.token_ids:
		if String(token_id).strip_edges().is_empty():
			errors.append("token_ids must not contain empty entries")
			break

func _validate_buff_definition(definition, errors: Array[String]) -> void:
	if definition.display_name.strip_edges().is_empty():
		errors.append("display_name must not be empty")
	if definition.polarity not in definition.ALLOWED_POLARITIES:
		errors.append("polarity must be one of %s" % ", ".join(definition.ALLOWED_POLARITIES))
	if definition.stat_deltas == null:
		errors.append("stat_deltas must not be null")
