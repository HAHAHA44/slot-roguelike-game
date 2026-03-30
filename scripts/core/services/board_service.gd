# 棋盘数据服务：
# - 维护 5x5 棋盘上的占格、放置、替换、删除和坐标查询。
# - 它只管“格子里有什么”，不管 token 怎么生成、怎么得分、怎么进事件。
# - `RunScreen` 用它来落子和清空棋盘，`TriggerScanner` 也会借助它做邻接/行列查询。
# - 这个类是纯数据结构层，适合单元测试，避免把棋盘规则写进 UI。
class_name BoardService
extends RefCounted

var width: int
var height: int
var _cells: Dictionary = {}

func _init(initial_width: int = 0, initial_height: int = 0) -> void:
	width = initial_width
	height = initial_height

func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func get_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var offsets: Array[Vector2i] = [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
	]

	for offset in offsets:
		var candidate := pos + offset
		if is_in_bounds(candidate):
			neighbors.append(candidate)

	return neighbors

func place_token(pos: Vector2i, token: TokenInstance) -> bool:
	if not is_in_bounds(pos) or has_token(pos):
		return false

	_cells[pos] = token
	return true

func replace_token(pos: Vector2i, token: TokenInstance) -> bool:
	if not is_in_bounds(pos) or not has_token(pos):
		return false

	_cells[pos] = token
	return true

func remove_token(pos: Vector2i):
	if not has_token(pos):
		return null

	var token = _cells[pos]
	_cells.erase(pos)
	return token

func get_token(pos: Vector2i):
	return _cells.get(pos)

func has_token(pos: Vector2i) -> bool:
	return _cells.has(pos)

func snapshot() -> Dictionary:
	return {
		"width": width,
		"height": height,
		"tokens": _cells.duplicate(),
	}

func get_row_positions(row: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	if row < 0 or row >= height:
		return positions

	for column in width:
		positions.append(Vector2i(column, row))

	return positions

func get_column_positions(column: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	if column < 0 or column >= width:
		return positions

	for row in height:
		positions.append(Vector2i(column, row))

	return positions
