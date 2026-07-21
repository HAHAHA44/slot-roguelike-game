extends GutTest

func test_registry_loads_seed_tokens() -> void:
	var registry_script := load("res://autoload/content_registry.gd")

	assert_not_null(registry_script)
	if registry_script == null:
		return

	var registry = registry_script.new()

	registry.load_all()

	# 只剩 M1 的 5 个人生模拟 token；5×5 四元素 token 和 empty_token 已删除。
	assert_eq(registry.tokens.size(), 5)

	# M1 起始 token 池
	assert_true(registry.starting_pools.has("default_pool"), "应加载默认起始 token 池")
	var pool = registry.starting_pools.get("default_pool")
	assert_not_null(pool)
	assert_eq(pool.token_ids.size(), 12, "默认池应有 12 张，正好铺满 12 格 ring")
	for token_id in pool.token_ids:
		assert_true(registry.tokens.has(String(token_id)),
			"起始池引用的 token「%s」必须存在于 content/tokens/" % token_id)

	# 12 生肖（鼠–猪）
	assert_eq(registry.zodiacs.size(), 12, "应加载 12 生肖")
	assert_true(registry.zodiacs.has("rat"))
	assert_true(registry.zodiacs.has("pig"))
	var dragon = registry.zodiacs.get("dragon")
	assert_not_null(dragon)
	assert_eq(int(dragon.order), 4)
