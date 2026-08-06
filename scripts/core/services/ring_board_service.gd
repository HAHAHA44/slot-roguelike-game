# 12 格生肖盘 board 服务：
# - 12 个固定槽位（slot 0-11），ring 拓扑（0 和 11 相邻）。盘的大小是硬约束，不改。
# - 每格存一个 CardInstance（碎片实例，带星级），不是裸 id——升星后同名碎片强度不同。
# - 由 RunScreen 每年 fill_from_board_cards() 填满；SettlementService 读取后走 cascade。
# - `card_at` / `token_at` 并存：前者给结算用（要星级），后者给 UI 用（只要显示名）。
#   方法名不叫 `get`，因为那是 Object 的内置方法，重写会冲突。
class_name RingBoardService
extends RefCounted

const CardInstanceScript := preload("res://scripts/core/value_objects/card_instance.gd")
const RING_SIZE := 12

# 每格一个 CardInstance 或 null（空槽）。
var _slots: Array = []

func _init() -> void:
	_slots.resize(RING_SIZE)
	clear_all()

func _is_in_range(slot: int) -> bool:
	return slot >= 0 and slot < RING_SIZE

func place_card(slot: int, card) -> bool:
	if not _is_in_range(slot):
		return false
	_slots[slot] = card
	return true

func card_at(slot: int):
	if not _is_in_range(slot):
		return null
	return _slots[slot]

func token_at(slot: int) -> String:
	var card = card_at(slot)
	return String(card.definition_id) if card != null else ""

func star_at(slot: int) -> int:
	var card = card_at(slot)
	return int(card.star) if card != null else 0

func clear(slot: int) -> bool:
	if not _is_in_range(slot) or _slots[slot] == null:
		return false
	_slots[slot] = null
	return true

func clear_all() -> void:
	for i in RING_SIZE:
		_slots[i] = null

# 洗牌投盘：把命盘的碎片打乱后铺满 12 格，不足的槽位补上 filler。
# - 命盘容量恒为 12，所以后期正好铺满；玩家还没抽够牌的早年才会用到 filler，
#   于是「童年一片凡庸、壮年满盘皆宝」的成长曲线是容量结构自己长出来的（ADR-0003）。
# - filler 每格都是一个**新实例**：它们是一次性占位，不该共享同一个对象
#   （共享会让「某一格补位碎片升星」这类未来功能一次改十二格）。
# - filler_token_id 为空串时剩余槽位留空，SettlementService 会跳过空槽。
func fill_from_board_cards(cards: Array, filler_token_id: String = "") -> void:
	var shuffled: Array = cards.duplicate()
	shuffled.shuffle()
	for slot in RING_SIZE:
		if slot < shuffled.size():
			_slots[slot] = shuffled[slot]
		elif filler_token_id.is_empty():
			_slots[slot] = null
		else:
			_slots[slot] = CardInstanceScript.new(filler_token_id, 1)

func occupied_slots() -> Array:
	var result: Array = []
	for i in RING_SIZE:
		if _slots[i] != null:
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
