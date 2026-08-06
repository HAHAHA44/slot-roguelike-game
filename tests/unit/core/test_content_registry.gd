# ContentRegistry 加载 + 跨资源引用完整性。
#
# 这里的断言分两类：
#   ① 数量下限 —— 内容被误删时立刻红（不写死精确值，铺量时不用天天改测试）
#   ② 引用完整性 —— 一张碎片的 legacy_into、起始池的 filler、事件的奖励 id
#      是否都真的存在。单资源校验器看不见别的 .tres，只有全量加载后才查得出，
#      所以这类检查只能放在这里。
extends GutTest

var _registry

func before_each() -> void:
	_registry = load("res://autoload/content_registry.gd").new()
	_registry.load_all()

# -- 数量下限 ----------------------------------------------------------------

func test_loads_all_content_categories() -> void:
	assert_gt(_registry.tokens.size(), 90, "七个阶段 × 12 张 + 传承物 + 补位")
	assert_eq(_registry.zodiacs.size(), 12, "应加载 12 生肖")
	assert_eq(_registry.life_stages.size(), 7, "应加载 7 个人生阶段")
	assert_gt(_registry.items.size(), 15, "道具")
	assert_gt(_registry.events.size(), 30, "转折年事件")
	assert_gt(_registry.flavor_lines.size(), 100, "流水年金句")
	assert_eq(_registry.buffs.size(), 8, "开局 Buff/Debuff")

# -- 生肖年度规则 ------------------------------------------------------------

func test_every_zodiac_carries_a_yearly_rule() -> void:
	# 缺一条规则，那一年生肖盘就退回装饰（ADR-0002 明令禁止）。
	for zodiac_id in _registry.zodiacs:
		var def = _registry.zodiacs[zodiac_id]
		assert_false(String(def.rule_name).strip_edges().is_empty(),
			"生肖「%s」没有年度规则" % zodiac_id)

func test_zodiac_orders_are_zero_to_eleven_without_gaps() -> void:
	var seen: Array = []
	for zodiac_id in _registry.zodiacs:
		seen.append(int(_registry.zodiacs[zodiac_id].order))
	seen.sort()
	assert_eq(seen, range(12), "12 生肖的 order 必须是 0–11 且不重不漏")

# -- 阶段分池 ----------------------------------------------------------------

func test_every_stage_has_a_draftable_pool() -> void:
	# 某个阶段一张可抽碎片都没有的话，那 12 年的三选一会全空。
	for stage_id in _registry.life_stages:
		var pool: Array = _registry.tokens_for_stage(String(stage_id))
		assert_gt(pool.size(), 8, "阶段「%s」的投注池太小（%d 张）" % [stage_id, pool.size()])

func test_draftable_tokens_declare_a_stage() -> void:
	for token_id in _registry.tokens:
		var def = _registry.tokens[token_id]
		if def.is_draftable():
			assert_false(String(def.stage_id).is_empty(),
				"可抽碎片「%s」必须归属某个阶段，否则它永远不会出现" % token_id)

func test_stage_ids_on_tokens_all_exist() -> void:
	for token_id in _registry.tokens:
		var def = _registry.tokens[token_id]
		var stage_id := String(def.stage_id)
		if stage_id.is_empty():
			continue
		assert_true(_registry.life_stages.has(stage_id),
			"碎片「%s」指向不存在的阶段「%s」" % [token_id, stage_id])

# -- 传承链完整性 ------------------------------------------------------------

func test_legacy_targets_all_exist() -> void:
	for token_id in _registry.tokens:
		var def = _registry.tokens[token_id]
		if not def.can_ascend():
			continue
		assert_true(_registry.tokens.has(String(def.legacy_into)),
			"碎片「%s」的传承目标「%s」不存在" % [token_id, def.legacy_into])

func test_legacy_tokens_are_not_draftable_and_stageless() -> void:
	for token_id in _registry.tokens:
		var def = _registry.tokens[token_id]
		if not def.is_legacy:
			continue
		assert_false(def.is_draftable(), "传承物「%s」不该能被抽到" % token_id)
		assert_true(String(def.stage_id).is_empty(),
			"传承物「%s」不该归属阶段，否则会被阶段清空带走" % token_id)

func test_legacy_chains_terminate_within_three_rings() -> void:
	# 链长封顶三环是内容量的闸门；成环或超长都会让传承无限膨胀。
	for token_id in _registry.tokens:
		var def = _registry.tokens[token_id]
		if not def.is_legacy:
			continue
		var hops := 0
		var cursor = def
		while cursor != null and cursor.can_ascend() and hops < 10:
			cursor = _registry.tokens.get(String(cursor.legacy_into), null)
			hops += 1
		assert_lt(hops, 3, "从传承物「%s」出发的链太长（%d 环）" % [token_id, hops])

# -- 起始命盘 ----------------------------------------------------------------

func test_starting_pool_references_existing_tokens() -> void:
	assert_true(_registry.starting_pools.has("default_pool"), "应加载默认起始命盘")
	var pool = _registry.starting_pools.get("default_pool")
	for token_id in pool.token_ids:
		assert_true(_registry.tokens.has(String(token_id)),
			"起始命盘引用的碎片「%s」不存在" % token_id)
	assert_true(_registry.tokens.has(String(pool.filler_token_id)),
		"补位碎片「%s」不存在" % pool.filler_token_id)

func test_filler_token_is_inert() -> void:
	# 补位碎片是「什么都没发生的一格」：有分但不带联动，
	# 否则命盘越空反而越容易连击，「摊大饼 vs 集中」的取舍就假了。
	var pool = _registry.starting_pools.get("default_pool")
	var filler = _registry.tokens.get(String(pool.filler_token_id))
	assert_eq(filler.effects.size(), 0, "补位碎片不该有联动 effect")
	assert_true(String(filler.zodiac_affinity).is_empty(), "补位碎片不该有生肖共鸣")
	assert_false(filler.is_draftable(), "补位碎片不该出现在投注池里")

# -- 事件引用完整性 ----------------------------------------------------------

func test_event_rewards_reference_existing_content() -> void:
	for event_id in _registry.events:
		var def = _registry.events[event_id]
		if not String(def.stage_id).is_empty():
			assert_true(_registry.life_stages.has(String(def.stage_id)),
				"事件「%s」指向不存在的阶段" % event_id)
		for choice in def.choices:
			if not String(choice.card_reward).is_empty():
				assert_true(_registry.tokens.has(String(choice.card_reward)),
					"事件「%s」发放不存在的碎片「%s」" % [event_id, choice.card_reward])
			if not String(choice.item_reward).is_empty():
				assert_true(_registry.items.has(String(choice.item_reward)),
					"事件「%s」发放不存在的道具「%s」" % [event_id, choice.item_reward])

func test_lethal_events_exist_and_only_in_low_spirit() -> void:
	var lethal_count := 0
	for event_id in _registry.events:
		var def = _registry.events[event_id]
		if not def.is_lethal():
			continue
		lethal_count += 1
		assert_eq(def.weight_for("high"), 0.0, "致死事件「%s」不该出现在高精神档" % event_id)
		assert_eq(def.weight_for("mid"), 0.0, "致死事件「%s」不该出现在中精神档" % event_id)
		assert_gt(def.weight_for("low"), 0.0, "致死事件「%s」在低精神档也没权重，等于永不触发" % event_id)
	assert_gt(lethal_count, 0, "至少要有一个致死事件，否则只能寿终")

# -- Buff 引用完整性 ---------------------------------------------------------

func test_buff_extra_cards_exist() -> void:
	for buff_id in _registry.buffs:
		var def = _registry.buffs[buff_id]
		if String(def.extra_card).is_empty():
			continue
		assert_true(_registry.tokens.has(String(def.extra_card)),
			"Buff「%s」发放不存在的碎片「%s」" % [buff_id, def.extra_card])

func test_buffs_split_into_both_polarities() -> void:
	var buffs := 0
	var debuffs := 0
	for buff_id in _registry.buffs:
		if _registry.buffs[buff_id].is_buff():
			buffs += 1
		else:
			debuffs += 1
	assert_gt(buffs, 0, "得有增益可抽")
	assert_gt(debuffs, 0, "得有减益可抽")
