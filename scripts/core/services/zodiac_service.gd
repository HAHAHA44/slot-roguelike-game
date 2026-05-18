# 生肖服务：
# - 输入：12 个 ZodiacDefinition（由 ContentRegistry 提供）。
# - 输出：当年生肖 / 本命年判定 / 奖励格槽位。
# - 纯数据查询，无 scene 依赖；由 RunScreen 在 _ready 中 new() 一份持有。
# - 假设：12 生肖按 order 0-11 排列；年 N 的生肖 = order N mod 12。
class_name ZodiacService
extends RefCounted

const RING_SIZE := 12

var _by_order: Array = []
var _by_id: Dictionary = {}

func _init(zodiacs: Array = []) -> void:
	_by_order.resize(RING_SIZE)
	for z in zodiacs:
		if z == null:
			continue
		var idx: int = int(z.order)
		if idx < 0 or idx >= RING_SIZE:
			push_error("ZodiacDefinition.order 越界: %s (id=%s)" % [idx, z.id])
			continue
		if _by_order[idx] != null:
			push_error("生肖 order %d 重复：%s vs %s" % [idx, _by_order[idx].id, z.id])
			continue
		_by_order[idx] = z
		_by_id[String(z.id)] = z

func current_year_zodiac(year: int):
	var idx := posmod(year, RING_SIZE)
	return _by_order[idx]

func is_birth_year(year: int, zodiac_birth_id: String) -> bool:
	if zodiac_birth_id.is_empty():
		return false
	var current = current_year_zodiac(year)
	if current == null:
		return false
	return String(current.id) == zodiac_birth_id

func reward_slot_index(year: int) -> int:
	return posmod(year, RING_SIZE)

func get_by_id(zodiac_id: String):
	return _by_id.get(zodiac_id)

func get_by_order(idx: int):
	if idx < 0 or idx >= RING_SIZE:
		return null
	return _by_order[idx]
