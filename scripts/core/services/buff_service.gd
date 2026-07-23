# Buff/Debuff 开局抽取服务（预留）：
# - 开局随机携带 0–2 个 Buff 和 0–2 个 Debuff，抽取概率受运气值补正：
#   运气越高 → 越可能多拿 Buff、少拿 Debuff。
# - 运气来源：本批用局内「运气」属性（AttributeService 分配的那一维）。
#   局外 meta 运气是 M6 转世闭环的事，届时改从 meta 读；这里先接局内运气。
# - 只决定「带哪些」，Buff 的实际效果留到后续设计。纯 RefCounted，随机用全局 randf/shuffle。
class_name BuffService
extends RefCounted

# 每种极性最多带几个。
const MAX_PER_POLARITY := 2
# 命中概率基线 + 每点运气的补正；clamp 到 [MIN,MAX] 防极端运气把概率推到 0/1。
const BASE_CHANCE := 0.35
const LUCK_STEP := 0.06
const CHANCE_MIN := 0.05
const CHANCE_MAX := 0.9

# 抽取并写入 session.active_buffs / session.active_debuffs。
# buff_pool / debuff_pool 是候选 id 数组（RunScreen 从 ContentRegistry 按 polarity 分好）。
# 返回 {"buffs":[...], "debuffs":[...]}。
func roll(session, luck: int, buff_pool: Array, debuff_pool: Array) -> Dictionary:
	var buff_chance := clampf(BASE_CHANCE + float(luck) * LUCK_STEP, CHANCE_MIN, CHANCE_MAX)
	var debuff_chance := clampf(BASE_CHANCE - float(luck) * LUCK_STEP, CHANCE_MIN, CHANCE_MAX)
	var buffs := _draw(buff_pool, buff_chance)
	var debuffs := _draw(debuff_pool, debuff_chance)
	if session != null:
		session.active_buffs = buffs.duplicate()
		session.active_debuffs = debuffs.duplicate()
	return {"buffs": buffs, "debuffs": debuffs}

# 从池里抽 0..MAX_PER_POLARITY 个不重复 id：MAX 个「槽」各按 chance 独立命中，
# 命中几个就从洗好的池里取前几个；池不足时按池大小封顶。
func _draw(pool: Array, chance: float) -> Array[String]:
	var result: Array[String] = []
	if pool.is_empty():
		return result
	var hits := 0
	for _slot in MAX_PER_POLARITY:
		if randf() < chance:
			hits += 1
	hits = mini(hits, pool.size())
	if hits <= 0:
		return result
	var shuffled := pool.duplicate()
	shuffled.shuffle()
	for i in hits:
		result.append(String(shuffled[i]))
	return result
