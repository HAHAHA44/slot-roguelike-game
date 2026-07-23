# BuffService 契约：
# - 开局各抽 0–2 个 buff / debuff，id 来自对应池、不重复、写回 session。
# - 运气补正：运气越高，统计上 buff 越多、debuff 越少。
# 概率项断言用多轮统计（300 次）而非单次，避免偶发抖动。
extends GutTest

const BuffServiceScript := preload("res://scripts/core/services/buff_service.gd")
const RunSessionScript := preload("res://autoload/run_session.gd")

const BUFF_POOL := ["b1", "b2", "b3", "b4"]
const DEBUFF_POOL := ["d1", "d2", "d3", "d4"]

var _service

func before_each() -> void:
	_service = BuffServiceScript.new()

func _new_session():
	return RunSessionScript.new()

func _unique_count(arr: Array) -> int:
	var seen := {}
	for x in arr:
		seen[x] = true
	return seen.size()

func test_roll_stays_within_bounds_and_pool() -> void:
	var session = _new_session()
	var result: Dictionary = _service.roll(session, 5, BUFF_POOL, DEBUFF_POOL)
	var buffs: Array = result["buffs"]
	var debuffs: Array = result["debuffs"]
	assert_between(buffs.size(), 0, BuffServiceScript.MAX_PER_POLARITY, "buff 数应在 0–2")
	assert_between(debuffs.size(), 0, BuffServiceScript.MAX_PER_POLARITY, "debuff 数应在 0–2")
	for buff_id in buffs:
		assert_has(BUFF_POOL, buff_id, "buff 应来自池")
	for debuff_id in debuffs:
		assert_has(DEBUFF_POOL, debuff_id, "debuff 应来自池")
	assert_eq(_unique_count(buffs), buffs.size(), "buff 不重复")
	assert_eq(_unique_count(debuffs), debuffs.size(), "debuff 不重复")
	assert_eq(session.active_buffs, buffs, "写回 session.active_buffs")
	assert_eq(session.active_debuffs, debuffs, "写回 session.active_debuffs")

func test_empty_pools_yield_empty() -> void:
	var session = _new_session()
	var result: Dictionary = _service.roll(session, 100, [], [])
	assert_eq((result["buffs"] as Array).size(), 0)
	assert_eq((result["debuffs"] as Array).size(), 0)

func test_high_luck_biases_toward_buffs() -> void:
	var buff_total := 0
	var debuff_total := 0
	for _i in 300:
		var r: Dictionary = _service.roll(null, 20, BUFF_POOL, DEBUFF_POOL)
		buff_total += (r["buffs"] as Array).size()
		debuff_total += (r["debuffs"] as Array).size()
	assert_gt(buff_total, debuff_total, "高运气应带更多 buff、更少 debuff")

func test_higher_luck_raises_buff_count() -> void:
	var low_total := 0
	var high_total := 0
	for _i in 300:
		var low_roll: Dictionary = _service.roll(null, 0, BUFF_POOL, DEBUFF_POOL)
		var high_roll: Dictionary = _service.roll(null, 20, BUFF_POOL, DEBUFF_POOL)
		low_total += (low_roll["buffs"] as Array).size()
		high_total += (high_roll["buffs"] as Array).size()
	assert_gt(high_total, low_total, "运气越高，buff 总数越多")
