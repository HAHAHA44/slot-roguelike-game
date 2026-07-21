extends GutTest

func test_registry_loads_seed_tokens() -> void:
	var registry_script := load("res://autoload/content_registry.gd")

	assert_not_null(registry_script)
	if registry_script == null:
		return

	var registry = registry_script.new()

	registry.load_all()

	# M1 的 5 个人生模拟 token + 1 个补位 token（凡庸）；5×5 四元素 token 已删除。
	assert_eq(registry.tokens.size(), 6)

	# M1 起始 token 池
	assert_true(registry.starting_pools.has("default_pool"), "应加载默认起始 token 池")
	var pool = registry.starting_pools.get("default_pool")
	assert_not_null(pool)
	assert_eq(pool.token_ids.size(), 12, "默认池应有 12 张，正好铺满 12 格 ring")
	for token_id in pool.token_ids:
		assert_true(registry.tokens.has(String(token_id)),
			"起始池引用的 token「%s」必须存在于 content/tokens/" % token_id)

	# 补位 token 的存在性只有在全量加载后才查得到（单资源校验器看不见别的 .tres）。
	assert_false(String(pool.filler_token_id).is_empty(), "默认池应配了补位 token")
	assert_true(registry.tokens.has(String(pool.filler_token_id)),
		"补位 token「%s」必须存在于 content/tokens/" % pool.filler_token_id)
	assert_gt(pool.delete_charges, 0, "默认池应给玩家若干次删牌机会")

	# 补位 token 是「什么都没发生的一年」：有分但不该带联动，
	# 否则删牌反而会凭空多出联动，删牌的取舍就假了。
	var filler = registry.tokens.get(String(pool.filler_token_id))
	assert_eq(filler.effects.size(), 0, "补位 token 不该有联动 effect")
	assert_true(String(filler.zodiac_affinity).is_empty(), "补位 token 不该有生肖共鸣")

	# 12 生肖（鼠–猪）
	assert_eq(registry.zodiacs.size(), 12, "应加载 12 生肖")
	assert_true(registry.zodiacs.has("rat"))
	assert_true(registry.zodiacs.has("pig"))
	var dragon = registry.zodiacs.get("dragon")
	assert_not_null(dragon)
	assert_eq(int(dragon.order), 4)
