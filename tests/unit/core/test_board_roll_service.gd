extends GutTest

func test_round_pool_is_filled_with_empty_tokens_to_board_capacity() -> void:
	var service := BoardRollService.new()
	var rolled := service.build_round_pool(["pulse_seed", "relay_prism"], 25, "empty_token", RandomNumberGenerator.new())
	assert_eq(rolled.size(), 25)
	assert_eq(rolled.count("empty_token"), 23)

func test_board_roll_preserves_exact_token_counts() -> void:
	var service := BoardRollService.new()
	var rolled := service.build_round_pool(["pulse_seed", "pulse_seed", "relay_prism"], 5, "empty_token", RandomNumberGenerator.new())
	assert_eq(rolled.count("pulse_seed"), 2)
	assert_eq(rolled.count("relay_prism"), 1)
	assert_eq(rolled.count("empty_token"), 2)

func test_round_pool_size_equals_capacity_when_pool_is_empty() -> void:
	var service := BoardRollService.new()
	var rolled := service.build_round_pool([], 25, "empty_token", RandomNumberGenerator.new())
	assert_eq(rolled.size(), 25)
	assert_eq(rolled.count("empty_token"), 25)

func test_round_pool_does_not_truncate_when_pool_equals_capacity() -> void:
	var pool: Array = []
	for _i in 25:
		pool.append("pulse_seed")
	var service := BoardRollService.new()
	var rolled := service.build_round_pool(pool, 25, "empty_token", RandomNumberGenerator.new())
	assert_eq(rolled.size(), 25)
	assert_eq(rolled.count("pulse_seed"), 25)
	assert_eq(rolled.count("empty_token"), 0)

func test_pool_to_board_map_maps_index_to_row_major_position() -> void:
	var service := BoardRollService.new()
	var pool := ["a", "b", "c", "d", "e", "f"]
	var board_map := service.pool_to_board_map(pool, 3)
	assert_eq(board_map[Vector2i(0, 0)], "a")
	assert_eq(board_map[Vector2i(1, 0)], "b")
	assert_eq(board_map[Vector2i(2, 0)], "c")
	assert_eq(board_map[Vector2i(0, 1)], "d")
	assert_eq(board_map[Vector2i(1, 1)], "e")
	assert_eq(board_map[Vector2i(2, 1)], "f")
