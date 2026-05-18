extends GutTest

func test_registry_loads_seed_tokens() -> void:
	var registry_script := load("res://autoload/content_registry.gd")

	assert_not_null(registry_script)
	if registry_script == null:
		return

	var registry = registry_script.new()

	registry.load_all()

	# 4 elements × 4 rarities + empty_token
	assert_eq(registry.tokens.size(), 17)

	# 12 生肖（鼠–猪）
	assert_eq(registry.zodiacs.size(), 12, "应加载 12 生肖")
	assert_true(registry.zodiacs.has("rat"))
	assert_true(registry.zodiacs.has("pig"))
	var dragon = registry.zodiacs.get("dragon")
	assert_not_null(dragon)
	assert_eq(int(dragon.order), 4)
