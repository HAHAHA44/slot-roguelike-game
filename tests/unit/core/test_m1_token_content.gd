# M1 内容测试：5 个示例 token 的 .tres 能被 ContentRegistry 正常加载，
# 并且挂在上面的 effect 真的会在 cascade 里生效。
#
# 与 test_settlement_service.gd 的分工：那边用代码构造的 token 测算法，
# 这边用真实 .tres 测「schema + 内容 + 服务」这条链没断。
# 断言刻意只咬结构和联动种类，不咬具体数值——数值是 M1 质量门要反复调的，
# 每调一次就红一次的测试会让人不敢调参。
extends GutTest

const ContentRegistryScript := preload("res://autoload/content_registry.gd")
const SettlementServiceScript := preload("res://scripts/core/services/settlement_service.gd")
const RingBoardServiceScript := preload("res://scripts/core/services/ring_board_service.gd")

const M1_TOKEN_IDS := [
	"diligence",
	"close_friend",
	"kinsman",
	"benefactor",
	"ancestral_blessing",
]

var _registry
var _tokens: Dictionary

func before_each() -> void:
	_registry = ContentRegistryScript.new()
	_registry.load_all()
	_tokens = _registry.tokens

# -- 加载 --------------------------------------------------------------------

func test_all_five_m1_tokens_load() -> void:
	for id in M1_TOKEN_IDS:
		assert_true(_tokens.has(id), "token「%s」应能从 content/tokens/ 加载" % id)

func test_m1_tokens_carry_effects() -> void:
	for id in M1_TOKEN_IDS:
		var def = _tokens.get(id, null)
		if def == null:
			continue
		assert_gt(def.effects.size(), 0, "token「%s」应至少挂 1 个 effect" % id)
		for effect in def.effects:
			assert_not_null(effect, "token「%s」的 effect 不应为 null（子资源没存上）" % id)

func test_m1_tokens_have_localized_names() -> void:
	for id in M1_TOKEN_IDS:
		var def = _tokens.get(id, null)
		if def == null:
			continue
		var display: String = def.get_display_name()
		assert_ne(display, def.name,
			"token「%s」的 name key 应能在 messages.csv 里查到译文，而不是回落成 key 本身" % id)

# -- 三种 effect 各自生效 ----------------------------------------------------

func test_diligence_raises_only_itself() -> void:
	var service = SettlementServiceScript.new(_tokens)
	var board = RingBoardServiceScript.new()
	board.place(0, "diligence")
	var report = service.settle(board)
	assert_eq(report.chain_count, 0, "勤勉是纯自加分，不应产生联动")
	assert_gt(report.total_score, int(_tokens["diligence"].base_score),
		"勤勉结算后应高于 base_score")

func test_close_friend_triggers_adjacent_chain() -> void:
	var service = SettlementServiceScript.new(_tokens)
	var board = RingBoardServiceScript.new()
	board.place(0, "close_friend")
	board.place(1, "diligence")
	var report = service.settle(board)
	assert_eq(report.chain_count, 1, "挚友应触发一次邻接联动")
	var kinds: Array = []
	for step in report.steps:
		if not step.chain_kind.is_empty():
			kinds.append(step.chain_kind)
	assert_has(kinds, "adjacent", "联动类型应是 adjacent（UI 画蓝线）")

func test_kinsman_triggers_zodiac_chain_with_its_own_kind() -> void:
	var service = SettlementServiceScript.new(_tokens)
	var board = RingBoardServiceScript.new()
	# 同乡靠盘面上的同生肖成链——两张同乡互相共鸣。
	board.place(0, "kinsman")
	board.place(6, "kinsman")
	var report = service.settle(board)
	assert_eq(report.chain_count, 2, "两张同乡应各触发一次同生肖联动")
	var kinds: Array = []
	for step in report.steps:
		if not step.chain_kind.is_empty():
			kinds.append(step.chain_kind)
	assert_has(kinds, "zodiac", "联动类型应是 zodiac（UI 画红线）")

func test_kinsman_does_not_chain_with_other_zodiac() -> void:
	var service = SettlementServiceScript.new(_tokens)
	var board = RingBoardServiceScript.new()
	# 同乡是 rat，祖荫是 dragon，中间隔开避免邻接联动干扰。
	board.place(0, "kinsman")
	board.place(6, "diligence")
	var report = service.settle(board)
	assert_eq(report.chain_count, 0, "盘面没有第二个 rat，同乡不应触发同生肖联动")

# -- 多 effect 堆叠 ----------------------------------------------------------

func test_benefactor_stacks_self_and_neighbor_effects() -> void:
	var service = SettlementServiceScript.new(_tokens)
	var board = RingBoardServiceScript.new()
	board.place(0, "benefactor")
	board.place(2, "diligence")
	var report = service.settle(board)
	# radius 2 → slot 2 在范围内。自加分不记 chain，邻接记 1。
	assert_eq(report.chain_count, 1, "贵人的自加分不记 chain，邻接记 1 次")
	var benefactor_step = null
	for step in report.steps:
		if step.token_id == "benefactor":
			benefactor_step = step
	assert_not_null(benefactor_step, "应有贵人的结算 step")
	assert_gt(benefactor_step.score_after, benefactor_step.score_before,
		"贵人的自加分应体现在自身分数上")

func test_ancestral_blessing_fires_both_chain_kinds() -> void:
	var service = SettlementServiceScript.new(_tokens)
	var board = RingBoardServiceScript.new()
	# 祖荫（dragon）+ 贵人（dragon）→ 同生肖；祖荫相邻放一张 → 邻接。
	board.place(0, "ancestral_blessing")
	board.place(1, "diligence")
	board.place(6, "benefactor")
	var report = service.settle(board)
	# 祖荫的两个 effect 在同一步里跑完，所以要看 chain_kinds() 而不是 chain_kind。
	var kinds: Dictionary = {}
	for step in report.steps:
		for kind in step.chain_kinds():
			kinds[kind] = true
	assert_true(kinds.has("zodiac"), "祖荫与贵人同为 dragon，应触发同生肖联动")
	assert_true(kinds.has("adjacent"), "祖荫的 ModifyNeighbor 应打到相邻的勤勉")

# -- 全盘 --------------------------------------------------------------------

func test_full_ring_of_m1_tokens_settles_without_warnings() -> void:
	var service = SettlementServiceScript.new(_tokens)
	var board = RingBoardServiceScript.new()
	for slot in 12:
		board.place(slot, String(M1_TOKEN_IDS[slot % M1_TOKEN_IDS.size()]))
	var report = service.settle(board)
	assert_eq(report.warnings.size(), 0, "全部是已知 token，不应有 warning")
	assert_eq(report.steps.size(), 12, "12 格应各结算一次")
	assert_gt(report.total_score, 0, "满盘年收益应为正")
	assert_gt(report.chain_count, 0, "满盘应产生联动")
