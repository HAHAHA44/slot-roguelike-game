# 集成测试：整条人生跑得通，且成长闭环真的闭合。
#
# 「跑得通」只是底线。这一轮改动的赌注是**年与年之间会不一样**，所以本文件的重点是
# 那条闭环的每一环都真的在动：抽牌 → 合成 → 投盘 → cascade → 购买力 → 阶段考核 → 传承。
# 任何一环断了，游戏会退回「12 个一模一样的年份」，那正是这轮要修的问题。
extends GutTest

const RunScreenScene := preload("res://scenes/run/run_screen.tscn")
const CardInstanceScript := preload("res://scripts/core/value_objects/card_instance.gd")
const SpiritServiceScript := preload("res://scripts/core/services/spirit_service.gd")

func _spawn(autoplay: bool):
	var scene = RunScreenScene.instantiate()
	scene.autoplay_on_ready = autoplay
	add_child_autofree(scene)
	await get_tree().process_frame
	return scene

# 结构性断言（阶段推进、命盘增长、门槛曲线…）不该被随机致死事件打断。
# 致死事件只在低精神档出现，所以把精神力顶满就等于关掉死亡轮盘，
# 而这不影响被测的那条闭环——死亡本身另有专门的测试覆盖。
func _step_safe(scene, years: int) -> void:
	for _i in years:
		if not scene.is_alive():
			break
		scene.run_session.set_stat("spr", SpiritServiceScript.MAX_VALUE)
		scene.step_year()

func _log_contains(scene, needle: String) -> bool:
	for line in scene.get_yearly_log():
		if String(line).contains(needle):
			return true
	return false

# -- smoke：出生跑到死 -------------------------------------------------------

# 关键质量门：一条人生能从出生自动跑到收场，不卡死、不报错。
func test_smoke_yearly_loop_runs_to_death() -> void:
	var scene = await _spawn(true)
	assert_false(scene.is_alive(), "autoplay 应该一路跑到这条人生结束")
	assert_gt(scene.get_current_age(), 0, "至少活过一年")
	assert_lte(scene.get_current_age(), 110, "不该超过寿命上限")
	var log_entries: Array = scene.get_yearly_log()
	assert_true(String(log_entries[0]).begins_with("出生："), "首行是出生")
	assert_gt(log_entries.size(), 20, "一条人生应留下足够的年度记录")

func test_death_is_recorded_with_a_cause() -> void:
	var scene = await _spawn(true)
	assert_ne(scene.run_session.death_cause, "", "死了就该有死因")
	assert_true(scene.run_session.death_cause in ["natural", "lethal_event"])

func test_step_year_is_noop_after_death() -> void:
	var scene = await _spawn(false)
	scene.begin_run("rat", 3)
	# 出生 Buff 会改寿命（体格强健 +5 / 体弱多病 −8），所以按**实际**寿命跑，
	# 不能拿传进去的那个数当结论。
	var lifespan: int = scene.run_session.lifespan
	for _i in lifespan + 3:
		scene.step_year()
	assert_false(scene.is_alive(), "活过寿命就该收场")
	var age_at_death: int = scene.get_current_age()
	scene.step_year()
	scene.step_year()
	assert_eq(scene.get_current_age(), age_at_death, "死后再点也不动")

# -- 出生态 ------------------------------------------------------------------

func test_birth_deals_starting_cards_and_rolls_stats() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	assert_gt(scene.run_session.board_cards.size(), 0, "出生应发几张起始碎片")
	assert_lt(scene.run_session.board_cards.size(), 12, "但远不该发满——早年靠抽")
	var total := 0
	for key in ["str", "int", "agi", "end", "spr", "luck"]:
		total += scene.run_session.stat(key)
	assert_gt(total, 10, "六维出生分配 + 精神力基线")

func test_birth_buffs_are_settled_immediately() -> void:
	# 开局 Buff 是出生条件，出生瞬间就该结算完，不是常驻被动。
	var scene = await _spawn(false)
	for _try in 12:
		scene.begin_run("dragon", 80)
		if not scene.run_session.active_buffs.is_empty():
			assert_true(_log_contains(scene, "投胎携带"), "带了 Buff 就该写进出生叙述")
			return
	pass_test("这几次都没抽到 Buff（概率允许），不算失败")

# -- 三选一 + 合成 -----------------------------------------------------------

func test_each_year_offers_three_cards() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	scene._year_draft(false)
	assert_eq(scene.get_current_offer().size(), 3, "每年摆三张候选")

func test_offer_only_contains_current_stage_cards() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	var stage_id: String = scene.get_stage_id()
	scene._year_draft(false)
	for definition_id in scene.get_current_offer():
		var def = scene._content_registry.tokens.get(String(definition_id))
		assert_eq(String(def.stage_id), stage_id, "投注池只装当前阶段的碎片")

func test_deck_grows_over_the_first_stage() -> void:
	# 这是整轮改动的核心断言：命盘会长大，所以年与年之间不一样。
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	var start_count: int = scene.run_session.total_card_count()
	_step_safe(scene, 10)
	assert_gt(scene.run_session.total_card_count(), start_count,
		"十年下来碎片总数应该涨了——不涨就说明成长闭环断了")

func test_merges_happen_within_a_life() -> void:
	# 投注池对已持有碎片加权，十几年下来应该总能凑出至少一次升星。
	# 只看一个阶段内（11 年，跨阶段会清空），因为合成必须在碎片被清掉之前发生。
	var scene = await _spawn(false)
	var merged := false
	for _attempt in 3:
		scene.begin_run("dragon", 110)
		_step_safe(scene, 11)
		for card in scene.run_session.all_cards():
			if int(card.star) > 1:
				merged = true
				break
		if merged:
			break
	assert_true(merged, "加权投注池应该让一个阶段内至少合成一次，否则三合一是死机制")

# -- cascade -----------------------------------------------------------------

func test_cascade_produces_score_and_fills_the_board() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	scene.step_year()
	var report = scene.get_last_cascade_report()
	assert_not_null(report)
	assert_eq(report.warnings.size(), 0, "有 warning 说明盘上有 registry 认不出的碎片")
	assert_eq(report.steps.size(), 12, "12 格应各结算一次（不足的由补位碎片顶上）")
	assert_gt(report.total_score, 0, "年收益应为正")

func test_board_reshuffles_between_years() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	var layouts: Dictionary = {}
	for _year in 8:
		scene.run_session.set_stat("spr", SpiritServiceScript.MAX_VALUE)
		scene.step_year()
		var layout: Array = []
		for slot in 12:
			layout.append(scene.get_ring_board().token_at(slot))
		layouts["-".join(layout)] = true
	assert_gt(layouts.size(), 1, "排布每年重洗")

func test_income_grows_across_a_life() -> void:
	# fun-axes P2：早期三位数、后期爆炸。曲线是平的就说明滚雪球没接上。
	var scene = await _spawn(false)
	scene.begin_run("dragon", 110)
	var early := 0
	for _year in 3:
		scene.run_session.set_stat("spr", SpiritServiceScript.MAX_VALUE)
		scene.step_year()
		early = max(early, int(scene.get_last_cascade_report().total_score))
	var late := 0
	for _year in 45:
		if not scene.is_alive():
			break
		scene.run_session.set_stat("spr", SpiritServiceScript.MAX_VALUE)
		scene.step_year()
		late = max(late, int(scene.get_last_cascade_report().total_score))
	assert_gt(late, early * 3, "四十几年后的峰值收益应远高于头三年")

# -- 生肖年度规则 ------------------------------------------------------------

func test_yearly_rule_is_named_in_the_log() -> void:
	# 生肖第一次真正承重（ADR-0002）：规则名进日志，玩家才知道今年按什么算。
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	scene.step_year()
	assert_true(_log_contains(scene, "·"), "年度日志应带上当年生肖规则名")

func test_birth_year_is_flagged() -> void:
	var scene = await _spawn(false)
	scene.begin_run("rat", 80)   # 鼠年 = 第 0 年，出生即本命年
	scene.step_year()
	assert_true(_log_contains(scene, "本命年"), "本命年该被标出来")

# -- 经济 --------------------------------------------------------------------

func test_income_converts_into_purchasing_power() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	scene._year_draft(true)
	scene._year_cascade()
	assert_gt(scene.run_session.purchasing_power, 0.0, "年收益必须换算成购买力")

func test_shop_stock_is_offered_and_purchases_stick() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 110)
	_step_safe(scene, 30)
	assert_gt(scene.run_session.owned_items.size(), 0,
		"三十年下来自动策略应该买到过道具——买不到说明经济曲线错配")

# -- 阶段边界 ----------------------------------------------------------------

func test_stage_advances_every_twelve_years() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 110)
	assert_eq(scene.get_stage_order(), 0)
	_step_safe(scene, 12)
	assert_eq(scene.get_stage_order(), 1, "12 年 = 一个阶段 = 一次生肖轮回")
	_step_safe(scene, 12)
	assert_eq(scene.get_stage_order(), 2)

func test_stage_review_runs_at_the_boundary() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 110)
	_step_safe(scene, 12)
	assert_true(_log_contains(scene, "阶段考核"), "阶段末应该考核年收益")

func test_stage_boundary_clears_current_stage_cards() -> void:
	# 童年的东西一样也带不走，除非练到满星（ADR-0003）。
	var scene = await _spawn(false)
	scene.begin_run("dragon", 110)
	_step_safe(scene, 11)
	var before: int = scene.run_session.total_card_count()
	assert_gt(before, 0)
	_step_safe(scene, 1)   # 第 12 年结束，跨阶段
	assert_lt(scene.run_session.total_card_count(), before, "当期碎片应被清空")

func test_threshold_climbs_with_the_stage() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 110)
	var first: int = scene.get_stage_threshold()
	_step_safe(scene, 24)
	assert_gt(scene.get_stage_threshold(), first, "门槛随阶段指数上涨")

# -- 传承 --------------------------------------------------------------------

func test_max_star_card_ascends_into_a_legacy() -> void:
	# 直接把一张满星碎片塞进命盘再跨阶段，验证传承这一环真的接着。
	var scene = await _spawn(false)
	scene.begin_run("dragon", 110)
	var ascendable := ""
	for token_id in scene._content_registry.tokens:
		var def = scene._content_registry.tokens[token_id]
		if String(def.stage_id) == "childhood" and def.can_ascend():
			ascendable = String(token_id)
			break
	assert_ne(ascendable, "", "童年阶段应该有可传承的碎片")
	scene.run_session.board_cards.append(CardInstanceScript.new(ascendable, 3))
	_step_safe(scene, 12)
	assert_true(_log_contains(scene, "传承"), "满星者应该进化成传承物")
	var has_legacy := false
	for card in scene.run_session.all_cards():
		var def = scene._content_registry.tokens.get(String(card.definition_id))
		if def != null and def.is_legacy:
			has_legacy = true
	assert_true(has_legacy, "传承物应该留在命盘上")

# -- 事件 --------------------------------------------------------------------

func test_flavor_lines_appear_every_year() -> void:
	# 流水年金句是叙事密度的来源，而且零时间成本。
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	var before: int = scene.get_yearly_log().size()
	scene.step_year()
	assert_gt(scene.get_yearly_log().size() - before, 1,
		"一年除了结算行还该滚一行金句")

func test_low_spirit_makes_turning_points_common() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 110)
	scene.run_session.set_stat("spr", 0)
	assert_eq(scene.get_spirit_bucket(), "low")
	var events := 0
	for _year in 40:
		scene._year_event(true)
		if _log_contains(scene, "·"):
			events += 1
	assert_gt(events, 0, "低精神档应该频繁出转折年——死亡轮盘要真的开着")

# -- UI 面板 -----------------------------------------------------------------

func test_deck_panel_lists_board_and_bench() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	var panel = scene.get_deck_panel()
	assert_false(panel.is_open(), "默认关着")
	panel.open(scene.run_session)
	assert_true(panel.is_open())
	panel.close()
	assert_false(panel.is_open())

func test_deck_panel_swap_moves_cards() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	# 造一个「命盘满 + 行囊有牌」的局面，才谈得上对换。
	while not scene.run_session.board_is_full():
		scene.run_session.board_cards.append(CardInstanceScript.new("mundane"))
	scene.run_session.bench_cards.append(CardInstanceScript.new("piggy_bank"))
	scene.get_deck_panel().swap_requested.emit(0, 0)
	assert_eq(String(scene.run_session.board_cards[0].definition_id), "piggy_bank",
		"行囊那张应该换上了命盘")

# -- 玩家交互路径 ------------------------------------------------------------
#
# 下面两条走的是**协程 + 模态信号**那条路，autoplay 和其它测试都不经过它。
# 它曾经因为「lambda 按值捕获局部变量」而死循环——同步路径全绿也照样漏掉，
# 所以这条路必须有自己的回归测试。

func test_draft_modal_choice_is_applied() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	scene._year_draft(false)
	var before: int = scene.run_session.total_card_count()
	scene._await_draft_choice()          # 协程：停在等信号处
	await get_tree().process_frame
	assert_true(scene.get_modal_panel().is_open(), "该弹出三选一")
	scene.get_modal_panel().chosen.emit(0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(scene.run_session.total_card_count(), before + 1, "选了就该拿到那张牌")
	assert_false(scene.get_modal_panel().is_open(), "选完模态该关掉")

func test_draft_modal_skip_takes_nothing() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	scene._year_draft(false)
	var before: int = scene.run_session.total_card_count()
	scene._await_draft_choice()
	await get_tree().process_frame
	scene.get_modal_panel().skipped.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(scene.run_session.total_card_count(), before, "「都不要」是免费的")
	assert_false(scene.get_modal_panel().is_open())

func test_shop_panel_opens_with_stock() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	scene.run_session.purchasing_power = 5.0
	scene._year_shop(false)
	var panel = scene.get_shop_panel()
	panel.open(scene.get_current_stock(), scene.run_session.purchasing_power)
	assert_true(panel.is_open())
	assert_gt(panel.stock_size(), 0, "货架不该是空的")
	panel.close()
