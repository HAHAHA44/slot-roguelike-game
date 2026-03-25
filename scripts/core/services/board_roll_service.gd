class_name BoardRollService
extends RefCounted

# Builds a per-round board from the persistent token pool.
#
# Rules:
#   1. Copy the persistent pool into a temporary round pool.
#   2. Append empty_token_id entries until the round pool reaches board_capacity.
#   3. Shuffle the 25 entries using the provided RNG.
#   4. Return the shuffled round pool (Array of String token IDs).
#
# The caller is responsible for translating the returned flat array into
# board positions (index 0 = Vector2i(0,0), row-major order).

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
