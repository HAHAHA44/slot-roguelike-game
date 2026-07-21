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
