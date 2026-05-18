# 生命阶段服务：
# - 输入：7 个 LifeStageDef（由 ContentRegistry.life_stages 提供）。
# - 输出：年龄 → 当前阶段；暮年（order=6）判定。
# - 阶段按 start_age 排序，stage_for_age 取"年龄 >= start_age 的最大阶段"。
# - 暮年起，无论年龄多大都还在暮年，直到寿命耗尽（endless 由 RunScreen 处理）。
class_name LifeStageService
extends RefCounted

const STAGE_COUNT := 7
const TWILIGHT_ORDER := 6

var _by_order: Array = []
var _sorted_by_age: Array = []

func _init(stages: Array = []) -> void:
	_by_order.resize(STAGE_COUNT)
	for s in stages:
		if s == null:
			continue
		var idx: int = int(s.order)
		if idx < 0 or idx >= STAGE_COUNT:
			push_error("LifeStageDef.order 越界: %s (id=%s)" % [idx, s.id])
			continue
		if _by_order[idx] != null:
			push_error("阶段 order %d 重复：%s vs %s" % [idx, _by_order[idx].id, s.id])
			continue
		_by_order[idx] = s
	# 复制非空项并按 start_age 升序，供 stage_for_age 查找。
	_sorted_by_age = []
	for s in _by_order:
		if s != null:
			_sorted_by_age.append(s)
	_sorted_by_age.sort_custom(func(a, b): return int(a.start_age) < int(b.start_age))

func stage_for_age(age: int):
	if _sorted_by_age.is_empty():
		return null
	var matched = null
	for s in _sorted_by_age:
		if age >= int(s.start_age):
			matched = s
		else:
			break
	return matched

func is_twilight(age: int) -> bool:
	var s = stage_for_age(age)
	if s == null:
		return false
	return int(s.order) == TWILIGHT_ORDER

func get_by_order(order: int):
	if order < 0 or order >= STAGE_COUNT:
		return null
	return _by_order[order]
