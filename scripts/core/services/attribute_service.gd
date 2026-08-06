# 六维局内属性服务：
# - 六维：力量 str / 智力 int / 敏捷 agi / 耐力 end / 精神力 spr / 运气 luck。
#   存在 RunSession.stats（Dictionary<String,int>）里，键见 ORDERED_KEYS。
# - 出生把 INITIAL_POINTS 点随机撒到六维；40 岁前每年随机 +1 到前 4 维，
#   40 岁起每年随机 -1（同前 4 维）。精神力 / 运气不随年龄漂移，运气整局恒定。
#
# 前四维的总和因此是一条**帐篷曲线**：出生约 7 点 → 40 岁约 47 点峰值 → 晚年跌回近 0。
# 而每一维各自强化一类 cascade 效果（力量→自增 / 智力→同生肖 / 敏捷→邻接 / 耐力→基础分，
# 见 YearModifierService），所以这条曲线的游戏含义是：**壮年是全局强度巅峰，
# 晚年 cascade 靠 build 硬撑而不是靠属性**。这个人生形状是免费的——曲线本来就在跑。
#
# 属性随机漂移、玩家不能选方向：build 方向有相当部分是「投胎 + 天意」，只能顺势而为。
# 这是刻意的，不是没做完。
class_name AttributeService
extends RefCounted

const StatServiceScript := preload("res://scripts/core/services/stat_service.gd")
const SpiritServiceScript := preload("res://scripts/core/services/spirit_service.gd")

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

# 出生：六维清零后把 INITIAL_POINTS 点逐点随机撒到六维（多项分布），
# 再给精神力补上出生基线。某一维可能分到 0，这是有意的——初始差异越大越有「投胎」味。
#
# 精神力为什么要补基线：六维每维期望才 1.7 点，若不补，所有人一出生就落在「低精神」档，
# 死亡轮盘从童年就开着。基线的含义是「一个人不会生下来就精神崩溃」。
# 数值与阈值都在 SpiritService，这里只负责施加。
func roll_initial(session) -> void:
	if session == null:
		push_error("AttributeService.roll_initial: session 为 null")
		return
	for key in ORDERED_KEYS:
		_stats.set_value(session, key, 0)
	for _i in INITIAL_POINTS:
		var key: String = ORDERED_KEYS[randi() % ORDERED_KEYS.size()]
		_stats.add(session, key, 1)
	_stats.add(session, SPIRIT_KEY, SpiritServiceScript.BIRTH_BASELINE)

# 年度漂移：< 40 随机一个前 4 维 +1；>= 40 随机一个「当前 >0」的前 4 维 -1（钳到 ≥0）。
# 精神力 / 运气不参与年龄漂移；运气整局恒定。
# 返回 {"key","delta"} 供 UI 闪一下；前 4 维全 0 无处可减时返回空 {}。
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
