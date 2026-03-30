# 回合棋盘生成服务：
# - 负责把 `RunSession.token_pool` 这份持久牌池，展开成本回合的 25 格棋盘输入。
# - 规则很明确：先复制持久池，再用 `empty_token` 补满容量，然后洗牌，最后按棋盘容量截断。
# - 它不关心 UI、不关心结算、不关心奖励，只负责“这一回合板面上应该出现哪些 token”。
# - 返回值是一个扁平数组，`RunScreen` 再把它映射到 `BoardService` 的坐标上。
# - 典型联动：`RunScreen._on_next_turn_pressed()` 先调用它，再把结果写进 `BoardService` 并触发结算。
class_name BoardRollService
extends RefCounted

func build_round_pool(
	persistent_pool: Array,
	board_capacity: int,
	empty_token_id: String,
	rng: RandomNumberGenerator
) -> Array:
	var round_pool: Array = persistent_pool.duplicate()

	while round_pool.size() < board_capacity:
		round_pool.append(empty_token_id)

	_shuffle(round_pool, rng)
	if round_pool.size() > board_capacity:
		round_pool = round_pool.slice(0, board_capacity)
	return round_pool

# Translates a flat round pool into a Dictionary of Vector2i -> token_id,
# using row-major order across a grid of the given width.
func pool_to_board_map(round_pool: Array, board_width: int) -> Dictionary:
	var result: Dictionary = {}
	for index in round_pool.size():
		var col := index % board_width
		var row := index / board_width
		result[Vector2i(col, row)] = String(round_pool[index])
	return result

func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
