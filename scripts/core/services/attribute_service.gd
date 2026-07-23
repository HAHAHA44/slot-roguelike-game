# 六维局内属性服务（预留）：
# - 六维：力量 str / 智力 int / 敏捷 agi / 耐力 end / 精神力 spr / 运气 luck。
#   存在 RunSession.stats（Dictionary<String,int>）里，键见 ORDERED_KEYS。
# - 出生（婴儿）时把 INITIAL_POINTS 点随机撒到六维；40 岁前每年随机 +1 到前 4 维，
#   40 岁起每年随机 -1（同前 4 维）。精神力 / 运气不随年龄漂移，运气整局恒定。
# - 本批只做「数据 + 增减规则」：属性对 cascade / 死亡 / 事件的具体加成留到后续
#   （对齐 dev-plan M4 的 StatService scaling），这里只搭骨架。
# - 纯 RefCounted，数据进数据出；随机用全局 randi()，与 RunScreen 的 _start_next_life 一致。
class_name AttributeService
extends RefCounted

const StatServiceScript := preload("res://scripts/core/services/stat_service.gd")

# 六维固定顺序（UI 展示 / 出生分配都按这个序）。
const ORDERED_KEYS := ["str", "int", "agi", "end", "spr", "luck"]
# 会随年龄漂移的「前 4 维」：力量 / 智力 / 敏捷 / 耐力。
const PHYSICAL_KEYS := ["str", "int", "agi", "end"]
const LUCK_KEY := "luck"
const SPIRIT_KEY := "spr"
# 出生随机分配的总点数。
const INITIAL_POINTS := 10
# 漂移转折年龄：< 此年龄每年 +1，>= 每年 -1。
const DRIFT_TURNING_AGE := 40

var _stats := StatServiceScript.new()

# 出生：六维清零后把 INITIAL_POINTS 点逐点随机撒到六维（多项分布）。
# 某一维可能分到 0，这是有意的——初始差异越大越有「投胎」味。
func roll_initial(session) -> void:
	if session == null:
		push_error("AttributeService.roll_initial: session 为 null")
		return
	for key in ORDERED_KEYS:
		_stats.set_value(session, key, 0)
	for _i in INITIAL_POINTS:
		var key: String = ORDERED_KEYS[randi() % ORDERED_KEYS.size()]
		_stats.add(session, key, 1)

# 年度漂移：< 40 随机一个前 4 维 +1；>= 40 随机一个「当前 >0」的前 4 维 -1（钳到 ≥0）。
# 精神力 / 运气不参与年龄漂移；运气整局恒定。
# 返回 {"key","delta"} 供 UI 闪一下；前 4 维全 0 无处可减时返回空 {}。
# 注意：本方法不写 RunScreen 的年度日志（会破坏 smoke test 的行数断言），只回结果。
func apply_yearly_drift(session, age: int) -> Dictionary:
	if session == null:
		push_error("AttributeService.apply_yearly_drift: session 为 null")
		return {}
	if age < DRIFT_TURNING_AGE:
		var up_key: String = PHYSICAL_KEYS[randi() % PHYSICAL_KEYS.size()]
		_stats.add(session, up_key, 1)
		return {"key": up_key, "delta": 1}
	# 40 岁起：只从当前 >0 的前 4 维里减，避免出现负数。
	var candidates: Array = []
	for key in PHYSICAL_KEYS:
		if _stats.get_value(session, key) > 0:
			candidates.append(key)
	if candidates.is_empty():
		return {}
	var down_key: String = candidates[randi() % candidates.size()]
	_stats.add(session, down_key, -1)
	return {"key": down_key, "delta": -1}

# 便捷读：按固定顺序返回 [{"key","value"}, ...]，UI 用来列六维。
func ordered_values(session) -> Array:
	var result: Array = []
	for key in ORDERED_KEYS:
		result.append({"key": key, "value": _stats.get_value(session, key)})
	return result

func get_value(session, key: String) -> int:
	return _stats.get_value(session, key)
