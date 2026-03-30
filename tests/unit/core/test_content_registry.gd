extends GutTest

func test_registry_loads_seed_tokens() -> void:
	var registry_script := load("res://autoload/content_registry.gd")

	assert_not_null(registry_script)
	if registry_script == null:
		return

	var registry = registry_script.new()

	registry.load_all()

	assert_eq(registry.tokens.size(), 7)
