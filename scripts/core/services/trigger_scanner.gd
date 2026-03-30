# 棋盘扫描助手：
# - 提供邻接、行列、标签统计等基础扫描接口，给更高层的结算/事件规则复用。
# - 这个类本身不做打分，不做状态推进，只把 `BoardService` 的数据变成更方便消费的查询结果。
# - 未来如果把 `_build_snapshot_from_board()` 拆出来，这个类会是最直接的底层依赖之一。
# - 典型联动：传入 `BoardService`，输出 `Vector2i` 列表或 tag 统计字典。
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
