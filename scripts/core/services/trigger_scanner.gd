class_name TriggerScanner
extends RefCounted

func get_neighbors(board: BoardService, pos: Vector2i) -> Array[Vector2i]:
	return board.get_neighbors(pos)

func get_row_positions(board: BoardService, row: int) -> Array[Vector2i]:
	return board.get_row_positions(row)

func get_column_positions(board: BoardService, column: int) -> Array[Vector2i]:
	return board.get_column_positions(column)

func count_tags(board_snapshot: Dictionary) -> Dictionary:
	var tag_counts: Dictionary = {}
	var tokens: Dictionary = board_snapshot.get("tokens", {})

	for token in tokens.values():
		for tag in token.tags:
			tag_counts[tag] = int(tag_counts.get(tag, 0)) + 1

	return tag_counts
