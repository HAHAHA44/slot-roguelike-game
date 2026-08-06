# RingBoardService 契约（12 格生肖盘）：
# - 12 个固定槽位，ring 拓扑（0 和 11 相邻）。
# - 每格存 CardInstance（带星级），不是裸 id。
# - 投盘每年洗牌；命盘不满时用补位碎片顶上，盘面永远是满的。
extends GutTest

const RingBoardServiceScript := preload("res://scripts/core/services/ring_board_service.gd")
const CardInstanceScript := preload("res://scripts/core/value_objects/card_instance.gd")

func _board():
	return RingBoardServiceScript.new()

func _cards(ids: Array, star: int = 1) -> Array:
	return CardInstanceScript.make_many(ids, star)

# -- 尺寸与基础读写 ----------------------------------------------------------

func test_ring_size_is_twelve() -> void:
	assert_eq(RingBoardServiceScript.RING_SIZE, 12, "12 格是硬约束，不改")

func test_new_board_is_empty() -> void:
	var board = _board()
	assert_true(board.occupied_slots().is_empty())
	for slot in 12:
		assert_null(board.card_at(slot))
		assert_eq(board.token_at(slot), "")

func test_place_and_read_back() -> void:
	var board = _board()
	assert_true(board.place_card(3, CardInstanceScript.new("abacus", 2)))
	assert_eq(board.token_at(3), "abacus")
	assert_eq(board.star_at(3), 2, "星级必须能读回来——结算要用它算倍率")
	assert_eq(board.occupied_slots(), [3])

func test_place_out_of_range_is_rejected() -> void:
	var board = _board()
	assert_false(board.place_card(-1, CardInstanceScript.new("x")))
	assert_false(board.place_card(12, CardInstanceScript.new("x")))
	assert_true(board.occupied_slots().is_empty())

func test_reading_out_of_range_is_safe() -> void:
	var board = _board()
	assert_null(board.card_at(99), "越界读不该崩，返回 null")
	assert_eq(board.token_at(-5), "")
	assert_eq(board.star_at(99), 0)

func test_clear_and_clear_all() -> void:
	var board = _board()
	board.place_card(0, CardInstanceScript.new("a"))
	board.place_card(1, CardInstanceScript.new("b"))
	assert_true(board.clear(0))
	assert_false(board.clear(0), "已经空的格子再清返回 false")
	assert_eq(board.occupied_slots(), [1])
	board.clear_all()
	assert_true(board.occupied_slots().is_empty())

# -- 投盘 --------------------------------------------------------------------

func test_fill_places_every_card() -> void:
	var board = _board()
	board.fill_from_board_cards(_cards(["a", "b", "c"]), "mundane")
	var ids: Array = []
	for slot in 12:
		ids.append(board.token_at(slot))
	assert_eq(ids.count("a"), 1)
	assert_eq(ids.count("b"), 1)
	assert_eq(ids.count("c"), 1)
	assert_eq(ids.count("mundane"), 9, "剩下 9 格由补位碎片顶上")

func test_fill_preserves_star_levels() -> void:
	var board = _board()
	var cards := [CardInstanceScript.new("abacus", 3)]
	board.fill_from_board_cards(cards, "mundane")
	var found := -1
	for slot in 12:
		if board.token_at(slot) == "abacus":
			found = slot
	assert_gt(found, -1, "碎片应在盘上")
	assert_eq(board.star_at(found), 3, "投盘不能把星级洗掉")

func test_filler_instances_are_not_shared() -> void:
	# 补位碎片是一次性占位；共享同一个对象会让「改一格」变成「改十二格」。
	var board = _board()
	board.fill_from_board_cards([], "mundane")
	var first = board.card_at(0)
	var second = board.card_at(1)
	assert_ne(first.get_instance_id(), second.get_instance_id(), "每格应是独立实例")

func test_fill_without_filler_leaves_holes() -> void:
	var board = _board()
	board.fill_from_board_cards(_cards(["a"]), "")
	assert_eq(board.occupied_slots(), [0], "不给补位碎片时其余槽位留空")

func test_fill_takes_first_twelve_when_over_capacity() -> void:
	var board = _board()
	var many: Array = []
	for i in 20:
		many.append(CardInstanceScript.new("t%d" % i))
	board.fill_from_board_cards(many, "mundane")
	assert_eq(board.occupied_slots().size(), 12, "盘就 12 格，多的上不来")

func test_fill_reshuffles_between_years() -> void:
	# 排布每年重洗——「谁挨着谁」是运气，不是玩家能规划的东西（反模式：手动摆放）。
	var board = _board()
	var cards: Array = _cards(["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l"])
	var layouts: Dictionary = {}
	for _year in 10:
		board.fill_from_board_cards(cards, "mundane")
		var layout: Array = []
		for slot in 12:
			layout.append(board.token_at(slot))
		layouts["-".join(layout)] = true
	assert_gt(layouts.size(), 1, "10 年应至少出现两种不同排布")

# -- 邻接 --------------------------------------------------------------------

func test_neighbors_wrap_around_the_ring() -> void:
	var board = _board()
	assert_eq(board.neighbors(0, 1), [11, 1], "0 和 11 相邻")
	assert_eq(board.neighbors(11, 1), [10, 0])

func test_neighbors_ordered_by_offset() -> void:
	var board = _board()
	assert_eq(board.neighbors(0, 2), [10, 11, 1, 2], "按 offset −2,−1,+1,+2 排列")

func test_neighbors_radius_zero_is_empty() -> void:
	assert_eq(_board().neighbors(5, 0), [])

func test_neighbors_radius_clamped_and_deduped() -> void:
	var board = _board()
	var result: Array = board.neighbors(0, 6)
	assert_eq(result.size(), 11, "半径 6 覆盖除自己外全部 11 格，且 −6/+6 去重")
	assert_false(result.has(0), "邻居不含自己")

func test_neighbors_out_of_range_slot_is_empty() -> void:
	assert_eq(_board().neighbors(99, 1), [])
