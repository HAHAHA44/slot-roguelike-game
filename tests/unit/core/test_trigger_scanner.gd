extends GutTest

func test_scanner_counts_tags_on_board() -> void:
	var board_service_script := load("res://scripts/core/services/board_service.gd")
	var trigger_scanner_script := load("res://scripts/core/services/trigger_scanner.gd")
	var token_instance_script := load("res://scripts/core/value_objects/token_instance.gd")

	assert_not_null(board_service_script)
	assert_not_null(trigger_scanner_script)
	assert_not_null(token_instance_script)
	if board_service_script == null or trigger_scanner_script == null or token_instance_script == null:
		return

	var board = board_service_script.new(5, 5)
	var scanner = trigger_scanner_script.new()

	board.place_token(Vector2i(1, 1), token_instance_script.new("pulse_seed", PackedStringArray(["Grow", "Charge"])))
	board.place_token(Vector2i(2, 1), token_instance_script.new("relay_prism", PackedStringArray(["Link"])))
	board.place_token(Vector2i(3, 1), token_instance_script.new("wild_signal", PackedStringArray(["Wild", "Grow"])))

	var tag_counts = scanner.count_tags(board.snapshot())

	assert_eq(tag_counts["Grow"], 2)
	assert_eq(tag_counts["Link"], 1)
	assert_eq(tag_counts["Wild"], 1)

func test_scanner_returns_row_and_column_positions() -> void:
	var board_service_script := load("res://scripts/core/services/board_service.gd")
	var trigger_scanner_script := load("res://scripts/core/services/trigger_scanner.gd")

	assert_not_null(board_service_script)
	assert_not_null(trigger_scanner_script)
	if board_service_script == null or trigger_scanner_script == null:
		return

	var board = board_service_script.new(5, 5)
	var scanner = trigger_scanner_script.new()

	assert_eq(scanner.get_row_positions(board, 2).size(), 5)
	assert_eq(scanner.get_column_positions(board, 3).size(), 5)
