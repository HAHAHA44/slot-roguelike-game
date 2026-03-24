extends GutTest

func test_cardinal_neighbors_on_5x5_board() -> void:
	var board_service_script := load("res://scripts/core/services/board_service.gd")

	assert_not_null(board_service_script)
	if board_service_script == null:
		return

	var board = board_service_script.new(5, 5)

	assert_eq(board.get_neighbors(Vector2i(2, 2)).size(), 4)

func test_corner_has_two_neighbors() -> void:
	var board_service_script := load("res://scripts/core/services/board_service.gd")

	assert_not_null(board_service_script)
	if board_service_script == null:
		return

	var board = board_service_script.new(5, 5)

	assert_eq(board.get_neighbors(Vector2i(0, 0)).size(), 2)

func test_place_replace_and_remove_token() -> void:
	var board_service_script := load("res://scripts/core/services/board_service.gd")
	var token_instance_script := load("res://scripts/core/value_objects/token_instance.gd")

	assert_not_null(board_service_script)
	assert_not_null(token_instance_script)
	if board_service_script == null or token_instance_script == null:
		return

	var board = board_service_script.new(5, 5)
	var seed_token = token_instance_script.new("pulse_seed", PackedStringArray(["Grow"]))
	var prism = token_instance_script.new("relay_prism", PackedStringArray(["Link"]))

	assert_true(board.place_token(Vector2i(1, 1), seed_token))
	assert_eq(board.get_token(Vector2i(1, 1)).definition_id, "pulse_seed")
	assert_false(board.place_token(Vector2i(1, 1), prism))
	assert_true(board.replace_token(Vector2i(1, 1), prism))
	assert_eq(board.get_token(Vector2i(1, 1)).definition_id, "relay_prism")
	assert_eq(board.remove_token(Vector2i(1, 1)).definition_id, "relay_prism")
	assert_null(board.get_token(Vector2i(1, 1)))
