class_name ContentDefinitionValidator
extends RefCounted

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
	elif definition is HeroDefinition:
		_validate_hero_definition(definition, errors)

	return errors

func _validate_token_definition(definition: TokenDefinition, errors: Array[String]) -> void:
	if definition.name.strip_edges().is_empty():
		errors.append("name must not be empty")
	if definition.type.strip_edges().is_empty():
		errors.append("type must not be empty")
	if definition.rarity not in TokenDefinition.ALLOWED_RARITIES:
		errors.append("rarity must be one of %s" % ", ".join(TokenDefinition.ALLOWED_RARITIES))
	if definition.tags == null:
		errors.append("tags must not be null")
	if definition.trigger_rules == null:
		errors.append("trigger_rules must not be null")
	if definition.state_fields == null:
		errors.append("state_fields must not be null")
	if definition.spawn_rules == null:
		errors.append("spawn_rules must not be null")
	if definition.remove_rules == null:
		errors.append("remove_rules must not be null")

func _validate_event_definition(definition: EventDefinition, errors: Array[String]) -> void:
	if definition.name.strip_edges().is_empty():
		errors.append("name must not be empty")
	if definition.type not in EventDefinition.ALLOWED_TYPES:
		errors.append("type must be one of %s" % ", ".join(EventDefinition.ALLOWED_TYPES))
	if definition.tags_affected == null:
		errors.append("tags_affected must not be null")
	if definition.contract_template == null:
		errors.append("contract_template must not be null")
	if definition.reward_bundle == null:
		errors.append("reward_bundle must not be null")
	if definition.penalty_bundle == null:
		errors.append("penalty_bundle must not be null")

func _validate_hero_definition(definition: HeroDefinition, errors: Array[String]) -> void:
	if definition.name.strip_edges().is_empty():
		errors.append("name must not be empty")
	if definition.starting_passive.strip_edges().is_empty():
		errors.append("starting_passive must not be empty")
	if definition.attribute_bias not in HeroDefinition.ALLOWED_ATTRIBUTES:
		errors.append("attribute_bias must be one of %s" % ", ".join(HeroDefinition.ALLOWED_ATTRIBUTES))
	if definition.event_weight_modifiers == null:
		errors.append("event_weight_modifiers must not be null")
