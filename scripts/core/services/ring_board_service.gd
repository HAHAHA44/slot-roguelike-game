# 12 格生肖盘 board 服务（M0+ 新流程主用）：
# - 12 个固定槽位（slot 0-11），ring 拓扑（0 和 11 相邻）。
# - 只存"哪个槽放了哪个 token id"，不关心 token 长什么样、得多少分、有什么 effect。
# - 由 RunScreen 在每年开始时 clear_all + place 12 次填满；SettlementService 读取 + 走 cascade。
# - API：place / token_at / clear / clear_all / occupied_slots / neighbors。`token_at` 而不是 `get`，
#   因为 `get` 是 Object 的内置方法（属性查询），重写会冲突。
# - 与老 BoardService（5×5 Vector2i 接口）并存，等 M1+ 老 settlement/event/reward 服务退役后再合并/重命名。
class_name RingBoardService
extends RefCounted

const RING_SIZE := 12

var _slots: PackedStringArray = PackedStringArray()

func _init() -> void:
	_slots.resize(RING_SIZE)
	# PackedStringArray.resize 默认填空串，显式初始化以防引擎实现差异
	for i in RING_SIZE:
		_slots[i] = ""

func _is_in_range(slot: int) -> bool:
	return slot >= 0 and slot < RING_SIZE

func place(slot: int, token_id: String) -> bool:
	if not _is_in_range(slot):
		return false
	_slots[slot] = token_id
	return true

func token_at(slot: int) -> String:
	if not _is_in_range(slot):
		return ""
	return _slots[slot]

func clear(slot: int) -> bool:
	if not _is_in_range(slot) or _slots[slot].is_empty():
		return false
	_slots[slot] = ""
	return true

func clear_all() -> void:
	for i in RING_SIZE:
		_slots[i] = ""

# 洗牌投盘：把 token_ids 打乱后铺满 12 格。
# - 多于 12 张：只投前 12 张（洗过牌，所以每年投上来的子集不同）。
# - 少于 12 张：剩余槽位填 filler_token_id。玩家删牌后池子会缩水，
#   补位 token 让「少一张」在盘上有具体形状，而不是一个看不懂的空洞。
# - filler_token_id 为空串时剩余槽位留空，SettlementService 会跳过空槽。
func fill_from_pool(token_ids: Array, filler_token_id: String = "") -> void:
	var shuffled: Array = token_ids.duplicate()
	shuffled.shuffle()
	for slot in RING_SIZE:
		if slot < shuffled.size():
			_slots[slot] = String(shuffled[slot])
		else:
			_slots[slot] = filler_token_id

func occupied_slots() -> Array:
	var result: Array = []
	for i in RING_SIZE:
		if not _slots[i].is_empty():
			result.append(i)
	return result

# 返回 slot 在 ring 上半径 radius 内的邻居（不含自身），按 offset 升序排列：
# 例如 neighbors(0, 2) → [10, 11, 1, 2]（依次是 offset -2, -1, +1, +2）。
# radius 上限为 RING_SIZE / 2 = 6；radius==6 时 -6 与 +6 会指向同一槽位，去重。
func neighbors(slot: int, radius: int = 1) -> Array:
	if not _is_in_range(slot):
		return []
	@warning_ignore("integer_division")
	var max_radius: int = RING_SIZE / 2
	@warning_ignore("shadowed_variable_base_class")
	var r: int = clampi(radius, 0, max_radius)
	if r == 0:
		return []
	var result: Array = []
	var seen: Dictionary = {}
	for offset in range(-r, r + 1):
		if offset == 0:
			continue
		var n: int = posmod(slot + offset, RING_SIZE)
		if seen.has(n):
			continue
		seen[n] = true
		result.append(n)
	return result
