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
