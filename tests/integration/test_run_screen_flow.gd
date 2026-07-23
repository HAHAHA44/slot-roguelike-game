# M0 集成测试：人生模拟 yearly loop 跑得通。
#
# 历史：本文件原先有 17 个测试覆盖 5×5 bag-roll 流程（offer → event → roll → settle
# → settlement_result → offer），已随 M0 RunScreen 改装一并退役。如需考古，去 git
# history（2026-05-18 之前的版本）。
extends GutTest

const RunScreenScene := preload("res://scenes/run/run_screen.tscn")

func _spawn(autoplay: bool):
	var scene = RunScreenScene.instantiate()
	scene.autoplay_on_ready = autoplay
	add_child_autofree(scene)
	await get_tree().process_frame
	return scene

# 关键质量门：stub yearly loop 能从出生跑到自然死，每年日志格式正确。
func test_smoke_yearly_loop_alive() -> void:
	var scene = await _spawn(true)
	assert_false(scene.is_alive(), "lifespan=80 应该跑完自然死")
	assert_eq(scene.get_current_age(), 80, "自然死时 age 等于 lifespan")
	var log_entries: Array = scene.get_yearly_log()
	# 1 行出生 + 80 行年记录 + 1 行自然死 = 82 行
	assert_eq(log_entries.size(), 82, "应有 82 条日志（出生 + 80 年 + 自然死）")
	assert_true(log_entries[0].begins_with("出生："), "首行是出生")
	assert_true(log_entries[1].begins_with("年 0："), "第二行是年 0")
	assert_true(log_entries[-1].begins_with("自然死"), "末行是自然死")

# 手动步进控制能用：测试可在 12 年后停下，断言生肖循环。
func test_step_year_advances_age_and_logs_zodiac() -> void:
	var scene = await _spawn(false)
	scene.begin_run("tiger", 80)
	assert_eq(scene.get_current_age(), 0)
	for i in 12:
		scene.step_year()
	assert_eq(scene.get_current_age(), 12, "12 步应推进到年 12")
	var entries: Array = scene.get_yearly_log()
	# 第 0 行是出生，年 0..年 11 各一行
	assert_true(entries[1].contains("生肖 rat"), "年 0 是鼠")
	assert_true(entries[3].contains("生肖 tiger"), "年 2 是虎")
	assert_true(entries[3].contains("本命年命中: true"), "tiger 出生 + 年 2 应命中本命年")
	assert_true(entries[1].contains("本命年命中: false"), "年 0 不是本命年")

# 寿命到顶后 step_year 不再推进。
func test_step_year_noop_after_death() -> void:
	var scene = await _spawn(false)
	scene.begin_run("rat", 3)
	for i in 5:
		scene.step_year()
	assert_false(scene.is_alive())
	# 寿命 3 → 跑 3 年到 age=3 自然死；额外的 step 不应推进 age
	assert_eq(scene.get_current_age(), 3)
	assert_true(scene.get_yearly_log()[-1].begins_with("自然死"))

# M1 投盘：每年从起始 token 池洗牌投满 12 格。
# 顺序是随机的，所以只断言结构（12 格都有 token、且都来自池子），不断言具体排布。
func test_board_populates_from_starting_pool() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	scene.step_year()
	var board = scene.get_ring_board()
	var pool: Array = scene.run_session.token_pool
	assert_eq(pool.size(), 12, "默认起始池应有 12 张人生碎片")
	for slot in 12:
		var token_id: String = board.token_at(slot)
		assert_false(token_id.is_empty(), "slot %d 应有 token" % slot)
		assert_has(pool, token_id, "slot %d 的 token「%s」应来自起始池" % [slot, token_id])

# 投盘每年重洗：连续两年的排布不应恒等（12 张里有重复，偶然相同是可能的，
# 所以跑 8 年只要出现过一次不同就算通过）。
func test_board_reshuffles_each_year() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	var seen: Dictionary = {}
	for i in 8:
		scene.step_year()
		var board = scene.get_ring_board()
		var layout: Array = []
		for slot in 12:
			layout.append(board.token_at(slot))
		seen["-".join(layout)] = true
	assert_gt(seen.size(), 1, "8 年应至少出现两种不同的投盘排布")

# M1 的核心回归：cascade 真的产出分数，不再是 stub 的 0。
func test_cascade_produces_score_and_chains() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	scene.step_year()
	var report = scene.get_last_cascade_report()
	assert_not_null(report, "结算后应有 CascadeReport")
	assert_eq(report.warnings.size(), 0,
		"起始池里的 token id 都应能在 content/tokens/ 找到（有 warning 说明池子里有错 id）")
	assert_eq(report.steps.size(), 12, "12 格应各结算一次")
	assert_gt(report.total_score, 0, "年收益应为正，而不是 stub 的 0")
	assert_gt(report.chain_count, 0, "默认池含挚友 / 同乡 / 贵人 / 祖荫，应产生联动")

# -- M1 背包 ------------------------------------------------------------------

# 背包按钮开合面板，面板列出的就是当前池子。
func test_backpack_opens_and_lists_the_pool() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	var panel = scene.get_backpack_panel()
	assert_false(panel.is_open(), "默认应是关着的")
	panel.open(scene.run_session.token_pool, scene.get_delete_charges())
	assert_true(panel.is_open())
	assert_eq(panel.get_node("%TokenList").item_count, 12, "面板应列出池中全部 12 张")

# 起始删牌次数来自起始池定义，不是代码里的常量。
func test_delete_charges_come_from_starting_pool() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	assert_eq(scene.get_delete_charges(), 5, "默认池给 5 次删牌机会")

# 删牌走完整回路：面板发信号 → 服务改池子 → 池子少一张、次数少一次。
func test_delete_request_shrinks_pool_and_spends_charge() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	var panel = scene.get_backpack_panel()
	panel.open(scene.run_session.token_pool, scene.get_delete_charges())
	panel.get_node("%TokenList").select(0)
	panel.delete_requested.emit(0)
	assert_eq(scene.run_session.token_pool.size(), 11, "删掉一张后池子剩 11")
	assert_eq(scene.get_delete_charges(), 4, "删一张扣一次")

# 次数用尽后删不动：第 6 次请求应被服务挡下，池子不再缩。
func test_delete_stops_after_charges_run_out() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	for i in 6:
		scene.get_backpack_panel().delete_requested.emit(0)
	assert_eq(scene.get_delete_charges(), 0)
	assert_eq(scene.run_session.token_pool.size(), 7, "12 张只删得掉 5 张")

# 任务 3 的核心：池子不足 12 张时，剩余槽位由补位 token 顶上，盘面永远是满的。
func test_short_pool_fills_board_with_filler_token() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	var filler: String = scene.get_filler_token_id()
	assert_false(filler.is_empty(), "起始池应配了补位 token")
	for i in 3:
		scene.get_backpack_panel().delete_requested.emit(0)
	scene.step_year()
	var board = scene.get_ring_board()
	var filler_count: int = 0
	for slot in 12:
		assert_false(board.token_at(slot).is_empty(), "slot %d 不该是空的" % slot)
		if board.token_at(slot) == filler:
			filler_count += 1
	assert_eq(filler_count, 3, "删掉 3 张 → 3 格补位 token")

# 补位 token 必须是 registry 认得的正式 token，否则 cascade 会吐 warning、这 3 格白给。
func test_filler_token_settles_without_warnings() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	for i in 5:
		scene.get_backpack_panel().delete_requested.emit(0)
	scene.step_year()
	var report = scene.get_last_cascade_report()
	assert_eq(report.warnings.size(), 0, "补位 token 应能被 SettlementService 正常结算")
	assert_eq(report.steps.size(), 12, "补位后 12 格仍应各结算一次")

# -- C3 六维属性 + 开局 Buff（接线进 RunScreen） -------------------------------

const _PHYSICAL_KEYS := ["str", "int", "agi", "end"]
const _ALL_STAT_KEYS := ["str", "int", "agi", "end", "spr", "luck"]

func _physical_sum(scene) -> int:
	var total := 0
	for key in _PHYSICAL_KEYS:
		total += int(scene.run_session.stats.get(key, 0))
	return total

# 出生把 10 点分配到六维（婴儿起点）。
func test_begin_run_allocates_ten_attribute_points() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	var total := 0
	for key in _ALL_STAT_KEYS:
		total += int(scene.run_session.stats.get(key, 0))
	assert_eq(total, 10, "出生应把 10 点分配到六维")

# 40 岁前每年前 4 维 +1：跑 N 年前 4 维总和恰好 +N（漂移 <40 必命中，确定性）。
func test_physical_attributes_climb_one_per_year_before_forty() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 120)
	var base := _physical_sum(scene)
	for i in 20:
		scene.step_year()
	assert_eq(_physical_sum(scene), base + 20, "40 岁前每年前 4 维 +1")

# 40 岁起每年前 4 维 -1：先累到 40 岁的峰值，再跑 15 年应恰好 -15。
func test_physical_attributes_decline_after_forty() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 120)
	for i in 40:
		scene.step_year()
	var peak := _physical_sum(scene)
	for i in 15:
		scene.step_year()
	assert_eq(_physical_sum(scene), peak - 15, "40 岁起每年前 4 维 -1")

# 运气整局恒定：出生分配后，跨过 40 岁漂移也不动运气。
func test_luck_is_constant_across_the_run() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 120)
	var luck0: int = int(scene.run_session.stats.get("luck", 0))
	for i in 50:
		scene.step_year()
	assert_eq(int(scene.run_session.stats.get("luck", 0)), luck0, "运气整局不变")

# 开局各携带至多 2 个 Buff / Debuff。
func test_begin_run_carries_at_most_two_of_each() -> void:
	var scene = await _spawn(false)
	scene.begin_run("dragon", 80)
	assert_lte(scene.run_session.active_buffs.size(), 2, "buff ≤ 2")
	assert_lte(scene.run_session.active_debuffs.size(), 2, "debuff ≤ 2")
