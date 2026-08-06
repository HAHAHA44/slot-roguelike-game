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
	definition.stage_id = "childhood"
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

	definition.id = "fire_common"
	definition.name = "Duplicate Pulse Seed"
	definition.rarity = "Common"
	definition.stage_id = "childhood"
	definition.tags = PackedStringArray(["Grow"])

	var errors = validator.validate_definition(definition, {"fire_common": true})

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
	definition.stage_id = "childhood"
	definition.tags = PackedStringArray(["Wild"])

	var errors = validator.validate_definition(definition, {})

	assert_true(errors.any(func(message: String) -> bool: return message.contains("rarity")))

func test_validator_requires_stage_for_draftable_token() -> void:
	# 可抽碎片不声明阶段 = 它永远不会出现在任何投注池里（分池是三合一成立的前提）。
	var validator = load("res://scripts/content/content_definition_validator.gd").new()
	var definition = load("res://scripts/content/token_definition.gd").new()
	definition.id = "stray"
	definition.name = "野碎片"
	definition.rarity = "Common"
	definition.draft_weight = 1.0
	definition.stage_id = ""

	var errors = validator.validate_definition(definition, {})

	assert_true(errors.any(func(message: String) -> bool: return message.contains("stage_id")))

func test_validator_rejects_draftable_legacy_token() -> void:
	# 传承物能被抽到的话，玩家可以绕过「练满星」直接拿走它。
	var validator = load("res://scripts/content/content_definition_validator.gd").new()
	var definition = load("res://scripts/content/token_definition.gd").new()
	definition.id = "legacy_leak"
	definition.name = "漏网传承"
	definition.rarity = "Legendary"
	definition.is_legacy = true
	definition.draft_weight = 1.0

	var errors = validator.validate_definition(definition, {})

	assert_true(errors.any(func(message: String) -> bool: return message.contains("draft_weight")))

func test_validator_rejects_lethal_event_outside_low_spirit() -> void:
	# 致死事件泄漏到中/高精神档 = 玩家在状态很好的年份莫名暴毙。
	# 这条必须在加载期就拦下，而不是等玩家遇到。
	var validator = load("res://scripts/content/content_definition_validator.gd").new()
	var definition = load("res://scripts/content/event_definition.gd").new()
	definition.id = "bad_lethal"
	definition.name = "越界致死"
	definition.kind = "lethal"
	definition.spirit_weights = {"high": 1.0, "low": 1.0}

	var errors = validator.validate_definition(definition, {})

	assert_true(errors.any(func(message: String) -> bool: return message.contains("lethal")))

func test_validator_rejects_zodiac_without_yearly_rule() -> void:
	var validator = load("res://scripts/content/content_definition_validator.gd").new()
	var definition = load("res://scripts/content/zodiac_definition.gd").new()
	definition.id = "rat"
	definition.display_name = "鼠"
	definition.order = 0
	definition.rule_name = ""

	var errors = validator.validate_definition(definition, {})

	assert_true(errors.any(func(message: String) -> bool: return message.contains("rule_name")))
