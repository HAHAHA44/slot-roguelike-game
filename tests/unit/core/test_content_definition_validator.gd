extends GutTest

func test_validator_rejects_empty_id() -> void:
	var validator_script := load("res://scripts/content/content_definition_validator.gd")
	var token_definition_script := load("res://scripts/content/token_definition.gd")

	assert_not_null(validator_script)
	assert_not_null(token_definition_script)
	if validator_script == null or token_definition_script == null:
		return

	var validator = validator_script.new()
	var definition = token_definition_script.new()

	definition.name = "Broken Token"
	definition.rarity = "Common"
	definition.type = "Engine"
	definition.tags = PackedStringArray(["Grow"])

	var errors = validator.validate_definition(definition, {})

	assert_true(errors.any(func(message: String) -> bool: return message.contains("id")))

func test_validator_rejects_duplicate_ids() -> void:
	var validator_script := load("res://scripts/content/content_definition_validator.gd")
	var token_definition_script := load("res://scripts/content/token_definition.gd")

	assert_not_null(validator_script)
	assert_not_null(token_definition_script)
	if validator_script == null or token_definition_script == null:
		return

	var validator = validator_script.new()
	var definition = token_definition_script.new()

	definition.id = "pulse_seed"
	definition.name = "Duplicate Pulse Seed"
	definition.rarity = "Common"
	definition.type = "Engine"
	definition.tags = PackedStringArray(["Grow"])

	var errors = validator.validate_definition(definition, {"pulse_seed": true})

	assert_true(errors.any(func(message: String) -> bool: return message.contains("duplicate")))

func test_validator_rejects_unknown_token_rarity() -> void:
	var validator_script := load("res://scripts/content/content_definition_validator.gd")
	var token_definition_script := load("res://scripts/content/token_definition.gd")

	assert_not_null(validator_script)
	assert_not_null(token_definition_script)
	if validator_script == null or token_definition_script == null:
		return

	var validator = validator_script.new()
	var definition = token_definition_script.new()

	definition.id = "oddity"
	definition.name = "Oddity"
	definition.rarity = "Mythic"
	definition.type = "Engine"
	definition.tags = PackedStringArray(["Wild"])

	var errors = validator.validate_definition(definition, {})

	assert_true(errors.any(func(message: String) -> bool: return message.contains("rarity")))
