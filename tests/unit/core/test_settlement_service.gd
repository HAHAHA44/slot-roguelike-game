# M1 单测：cascade 结算主循环。
#
# 覆盖 dev-plan T1.5 点名的 5 个场景：空盘 / 单 token / 同生肖联动 / 邻接联动 /
# 全场 12 连，外加 min-score-first 选择顺序这个核心正确性断言。
#
# token 定义在测试内用代码构造（不走 .tres），这样测试自包含、不依赖 content/ 的内容变动。
extends GutTest

const SettlementServiceScript := preload("res://scripts/core/services/settlement_service.gd")
const RingBoardServiceScript := preload("res://scripts/core/services/ring_board_service.gd")
const AddSelfScoreScript := preload("res://scripts/core/effects/add_self_score.gd")
const ModifyNeighborScript := preload("res://scripts/core/effects/modify_neighbor.gd")
const TriggerZodiacChainScript := preload("res://scripts/core/effects/trigger_zodiac_chain.gd")

# -- helpers -----------------------------------------------------------------

func _make_token(id: String, base_score: int, effects: Array = [], zodiac_affinity: String = "") -> TokenDefinition:
	var def := TokenDefinition.new()
	def.id = id
	def.base_score = base_score
	def.zodiac_affinity = zodiac_affinity
	var typed: Array[ScriptableEffect] = []
	for e in effects:
		typed.append(e)
	def.effects = typed
	return def

func _registry(defs: Array) -> Dictionary:
	var result: Dictionary = {}
	for d in defs:
		result[d.id] = d
	return result

func _board(placements: Dictionary) -> RingBoardService:
	var board := RingBoardServiceScript.new()
	for slot in placements.keys():
		board.place(int(slot), String(placements[slot]))
	return board

# -- 空盘 --------------------------------------------------------------------

func test_empty_board_yields_zero_and_no_steps() -> void:
	var service = SettlementServiceScript.new(_registry([]))
	var report = service.settle(_board({}))
	assert_eq(report.total_score, 0, "空盘年收益应为 0")
	assert_eq(report.steps.size(), 0, "空盘不应产生 cascade step")
	assert_eq(report.chain_count, 0, "空盘不应有联动")

# -- 单 token ----------------------------------------------------------------

func test_single_token_settles_at_base_score() -> void:
	var defs := _registry([_make_token("plain", 5)])
	var service = SettlementServiceScript.new(defs)
	var report = service.settle(_board({0: "plain"}))
	assert_eq(report.total_score, 5, "单 token 年收益 = base_score")
	assert_eq(report.steps.size(), 1, "应恰好结算一次")
	assert_eq(report.steps[0].slot, 0, "结算的应是 slot 0")
	assert_eq(report.steps[0].score_after, 5, "结算后分数 = 5")
	assert_eq(report.chain_count, 0, "无 effect 不产生联动")

func test_add_self_score_effect_raises_own_score() -> void:
	var effect = AddSelfScoreScript.new()
	effect.amount = 7
	var defs := _registry([_make_token("grower", 3, [effect])])
	var service = SettlementServiceScript.new(defs)
	var report = service.settle(_board({4: "grower"}))
	assert_eq(report.total_score, 10, "3 base + 7 self = 10")
	assert_eq(report.steps[0].score_after, 10, "step 记录结算后的分数")

# -- min-score-first 顺序 ----------------------------------------------------

func test_settles_lowest_score_first() -> void:
	var defs := _registry([
		_make_token("low", 1),
		_make_token("mid", 5),
		_make_token("high", 9),
	])
	var service = SettlementServiceScript.new(defs)
	var report = service.settle(_board({0: "high", 1: "low", 2: "mid"}))
	var order: Array = []
	for step in report.steps:
		order.append(step.token_id)
	assert_eq(order, ["low", "mid", "high"], "应按 current_score 升序结算")

func test_ties_break_by_lowest_slot_index() -> void:
	var defs := _registry([_make_token("same", 2)])
	var service = SettlementServiceScript.new(defs)
	var report = service.settle(_board({7: "same", 2: "same", 5: "same"}))
	var slots: Array = []
	for step in report.steps:
		slots.append(step.slot)
	assert_eq(slots, [2, 5, 7], "同分时按槽位索引升序，保证结算可复现")

func test_effect_can_reorder_later_settlement() -> void:
	# slot 0 先结算（base 1），把 slot 1 从 8 拉到 -2，于是 slot 1 反超 slot 2（base 4）先结算。
	var pusher = ModifyNeighborScript.new()
	pusher.amount = -10
	pusher.radius = 1
	var defs := _registry([
		_make_token("pusher", 1, [pusher]),
		_make_token("heavy", 8),
		_make_token("light", 4),
	])
	var service = SettlementServiceScript.new(defs)
	var report = service.settle(_board({0: "pusher", 1: "heavy", 2: "light"}))
	var order: Array = []
	for step in report.steps:
		order.append(step.token_id)
	assert_eq(order, ["pusher", "heavy", "light"],
		"effect 改分后应影响后续结算顺序（heavy 被压到 -2，先于 light 的 4）")

# -- 邻接联动 ----------------------------------------------------------------

func test_adjacency_chain_boosts_both_neighbors() -> void:
	var effect = ModifyNeighborScript.new()
	effect.amount = 10
	effect.radius = 1
	var defs := _registry([
		_make_token("hub", 1, [effect]),
		_make_token("plain", 2),
	])
	var service = SettlementServiceScript.new(defs)
	# hub 在 slot 0，邻居是 slot 11 和 slot 1。
	var report = service.settle(_board({0: "hub", 1: "plain", 11: "plain"}))
	assert_eq(report.total_score, 1 + 12 + 12, "hub 1 + 两个邻居各 2+10")
	assert_eq(report.chain_count, 1, "一次邻接联动记 1 次 chain")
	assert_eq(report.steps[0].chain_kind, "adjacent", "首步应标记为邻接联动")
	assert_eq(report.steps[0].affected_slots, [11, 1], "受影响槽位按 ring 顺序返回")

func test_adjacency_chain_wraps_around_ring() -> void:
	var effect = ModifyNeighborScript.new()
	effect.amount = 5
	effect.radius = 1
	var defs := _registry([
		_make_token("hub", 1, [effect]),
		_make_token("plain", 0),
	])
	var service = SettlementServiceScript.new(defs)
	# slot 11 的邻居应绕回 slot 0，验证 ring 拓扑而不是线性数组。
	var report = service.settle(_board({11: "hub", 0: "plain"}))
	assert_eq(report.total_score, 1 + 5, "slot 11 的邻居包含 slot 0")

func test_adjacency_chain_ignores_empty_neighbors() -> void:
	var effect = ModifyNeighborScript.new()
	effect.amount = 10
	effect.radius = 1
	var defs := _registry([_make_token("lonely", 3, [effect])])
	var service = SettlementServiceScript.new(defs)
	var report = service.settle(_board({6: "lonely"}))
	assert_eq(report.total_score, 3, "邻居都是空槽，不应加分")
	assert_eq(report.chain_count, 0, "没打到任何目标不记 chain")

# -- 同生肖联动 --------------------------------------------------------------

func test_zodiac_chain_hits_same_affinity_only() -> void:
	var effect = TriggerZodiacChainScript.new()
	effect.amount = 100
	var defs := _registry([
		_make_token("rat_hub", 1, [effect], "rat"),
		_make_token("rat_kin", 2, [], "rat"),
		_make_token("ox_other", 2, [], "ox"),
	])
	var service = SettlementServiceScript.new(defs)
	var report = service.settle(_board({0: "rat_hub", 5: "rat_kin", 9: "ox_other"}))
	assert_eq(report.total_score, 1 + 102 + 2, "只有同为 rat 的 token 吃到加成")
	assert_eq(report.chain_count, 1, "一次同生肖联动")
	assert_eq(report.steps[0].chain_kind, "zodiac", "首步应标记为同生肖联动")

func test_zodiac_chain_skips_tokens_without_affinity() -> void:
	var effect = TriggerZodiacChainScript.new()
	effect.amount = 50
	var defs := _registry([
		_make_token("blank_hub", 1, [effect], ""),
		_make_token("blank_kin", 2, [], ""),
	])
	var service = SettlementServiceScript.new(defs)
	var report = service.settle(_board({0: "blank_hub", 3: "blank_kin"}))
	assert_eq(report.total_score, 3, "空 affinity 不应互相联动（否则无属性 token 会全场共鸣）")
	assert_eq(report.chain_count, 0, "空 affinity 不记 chain")

# -- 全场 12 连 --------------------------------------------------------------

func test_full_board_twelve_tokens_all_settle() -> void:
	var defs := _registry([_make_token("unit", 1)])
	var service = SettlementServiceScript.new(defs)
	var placements: Dictionary = {}
	for slot in 12:
		placements[slot] = "unit"
	var report = service.settle(_board(placements))
	assert_eq(report.steps.size(), 12, "12 格全满应产生 12 个 step")
	assert_eq(report.total_score, 12, "每格 1 分")
	var seen: Dictionary = {}
	for step in report.steps:
		seen[step.slot] = true
	assert_eq(seen.size(), 12, "每个槽位应恰好结算一次")

func test_full_board_zodiac_chain_accumulates_chain_count() -> void:
	var effect = TriggerZodiacChainScript.new()
	effect.amount = 1
	var defs := _registry([_make_token("kin", 1, [effect], "rat")])
	var service = SettlementServiceScript.new(defs)
	var placements: Dictionary = {}
	for slot in 12:
		placements[slot] = "kin"
	var report = service.settle(_board(placements))
	assert_eq(report.chain_count, 12, "12 个同生肖 token 各触发一次联动")
	assert_eq(report.steps[11].chain_count_after, 12, "最后一步的累计 chain 应为 12")

# -- 健壮性 ------------------------------------------------------------------

func test_unknown_token_id_is_skipped_with_warning() -> void:
	var defs := _registry([_make_token("known", 4)])
	var service = SettlementServiceScript.new(defs)
	var report = service.settle(_board({0: "known", 1: "ghost"}))
	assert_eq(report.total_score, 4, "未知 token id 不参与结算")
	assert_eq(report.steps.size(), 1, "未知 token 不产生 step")
	assert_eq(report.warnings.size(), 1, "未知 token 应留下一条 warning")

func test_settle_is_repeatable_without_state_leak() -> void:
	var effect = AddSelfScoreScript.new()
	effect.amount = 2
	var defs := _registry([_make_token("grower", 1, [effect])])
	var service = SettlementServiceScript.new(defs)
	var board := _board({0: "grower"})
	var first = service.settle(board)
	var second = service.settle(board)
	assert_eq(first.total_score, second.total_score,
		"同一 service 重复结算同一盘面应得到相同结果（不得残留上一年的分数）")
