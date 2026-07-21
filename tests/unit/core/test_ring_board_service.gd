# RingBoardService 契约（M0+ 12 格生肖盘）：
# - 12 槽位 ring（slot 0-11）
# - place(slot, token_id) 占格；同槽再 place 覆盖
# - get(slot) 返回占用的 token_id（空 → "")
# - clear(slot) 释放；clear_all() 清空
# - occupied_slots() 返回已占槽位
# - neighbors(slot, radius=1) ring 拓扑邻居（0 的邻居是 11 和 1）
extends GutTest

const RingBoardServiceScript := preload("res://scripts/core/services/ring_board_service.gd")

func _make():
	return RingBoardServiceScript.new()

func test_new_board_is_empty() -> void:
	var b = _make()
	assert_eq(b.occupied_slots().size(), 0)
	for slot in 12:
		assert_eq(b.token_at(slot), "")

func test_place_and_get() -> void:
	var b = _make()
	assert_true(b.place(3, "tiger"))
	assert_eq(b.token_at(3), "tiger")
	assert_eq(b.token_at(2), "")

func test_place_rejects_out_of_range_slot() -> void:
	var b = _make()
	assert_false(b.place(-1, "x"))
	assert_false(b.place(12, "x"))
	assert_eq(b.occupied_slots().size(), 0)

func test_place_overwrites_existing() -> void:
	var b = _make()
	b.place(5, "snake")
	assert_true(b.place(5, "dragon"))
	assert_eq(b.token_at(5), "dragon")

func test_clear_releases_slot() -> void:
	var b = _make()
	b.place(7, "goat")
	assert_true(b.clear(7))
	assert_eq(b.token_at(7), "")
	assert_false(b.clear(7), "重复 clear 返回 false")

func test_clear_all_empties_board() -> void:
	var b = _make()
	b.place(0, "rat")
	b.place(11, "pig")
	b.clear_all()
	assert_eq(b.occupied_slots().size(), 0)

func test_occupied_slots_returns_sorted_indices() -> void:
	var b = _make()
	b.place(7, "goat")
	b.place(2, "tiger")
	b.place(11, "pig")
	assert_eq(b.occupied_slots(), [2, 7, 11])

func test_neighbors_radius_1_in_middle() -> void:
	var b = _make()
	assert_eq(b.neighbors(5, 1), [4, 6])

func test_neighbors_wraps_at_zero() -> void:
	var b = _make()
	assert_eq(b.neighbors(0, 1), [11, 1])

func test_neighbors_wraps_at_eleven() -> void:
	var b = _make()
	assert_eq(b.neighbors(11, 1), [10, 0])

func test_neighbors_radius_2_includes_two_each_side() -> void:
	var b = _make()
	assert_eq(b.neighbors(5, 2), [3, 4, 6, 7])
	assert_eq(b.neighbors(0, 2), [10, 11, 1, 2])

func test_neighbors_radius_clamped_to_ring_size() -> void:
	# radius >= 6 会覆盖整个 ring（除自身），上限按 RING/2 = 6 处理
	var b = _make()
	var n6 = b.neighbors(5, 6)
	assert_eq(n6.size(), 11, "radius 6 应返回除自身外的 11 个槽位")
	assert_false(n6.has(5))

func test_neighbors_rejects_out_of_range_slot() -> void:
	var b = _make()
	assert_eq(b.neighbors(-1, 1), [])
	assert_eq(b.neighbors(12, 1), [])

# -- fill_from_pool（M1 投盘 + 补位） -----------------------------------------

func test_fill_from_pool_exactly_twelve_uses_every_entry() -> void:
	var b = _make()
	var pool: Array = []
	for i in 12:
		pool.append("t%d" % i)
	b.fill_from_pool(pool, "mundane")
	var placed: Array = []
	for slot in 12:
		placed.append(b.token_at(slot))
	placed.sort()
	pool.sort()
	assert_eq(placed, pool, "12 张正好铺满，每张都该上盘（顺序被洗过，比排序后的集合）")

# 玩家删牌后池子缩水，空出来的槽位由补位 token 顶上。
func test_fill_from_pool_pads_short_pool_with_filler() -> void:
	var b = _make()
	b.fill_from_pool(["a", "b", "c"], "mundane")
	var filler_count: int = 0
	for slot in 12:
		if b.token_at(slot) == "mundane":
			filler_count += 1
	assert_eq(filler_count, 9, "3 张真牌 + 9 张补位 = 12 格")

func test_fill_from_pool_empty_filler_leaves_slots_blank() -> void:
	var b = _make()
	b.fill_from_pool(["a", "b"], "")
	assert_eq(b.occupied_slots().size(), 2, "补位 id 为空时剩余槽位留空")

func test_fill_from_pool_empty_pool_is_all_filler() -> void:
	var b = _make()
	b.fill_from_pool([], "mundane")
	assert_eq(b.occupied_slots().size(), 12)
	assert_eq(b.token_at(0), "mundane")

func test_fill_from_pool_larger_pool_takes_twelve() -> void:
	var b = _make()
	var pool: Array = []
	for i in 20:
		pool.append("t%d" % i)
	b.fill_from_pool(pool, "mundane")
	assert_eq(b.occupied_slots().size(), 12)
	for slot in 12:
		assert_ne(b.token_at(slot), "mundane", "池子够大时不该出现补位 token")

func test_fill_from_pool_overwrites_previous_layout() -> void:
	var b = _make()
	b.place(0, "stale")
	b.fill_from_pool(["a"], "mundane")
	assert_ne(b.token_at(0), "stale", "投盘应整盘覆盖，不留上一年的残留")

# 洗牌是「不改动传入数组」的：RunScreen 递进来的是 RunSession.token_pool 本体。
func test_fill_from_pool_does_not_mutate_caller_array() -> void:
	var b = _make()
	var pool: Array = ["a", "b", "c"]
	b.fill_from_pool(pool, "mundane")
	assert_eq(pool, ["a", "b", "c"], "洗牌不该打乱调用方的池子")
