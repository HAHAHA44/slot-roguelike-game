# 开局 Buff/Debuff 服务：抽取 + 出生时一次性施加。
# - 开局随机携带 0–2 个 Buff 和 0–2 个 Debuff，命中概率受运气补正：
#   运气越高 → 越可能多拿 Buff、少拿 Debuff。
# - 运气来源是局内六维的运气维。局外 meta 运气是 M6 转世闭环的事，届时改从 meta 读。
# - roll() 只决定「带哪些」，apply() 才真正改开局参数。分两步是因为 UI 要先展示
#   「你投胎带了什么」，再看它把你的人生改成什么样。
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

# 把已抽到的 Buff/Debuff 一次性施加到 session 上。出生时调一次，此后不再触发。
# deck_service 用来发额外碎片；不传则跳过那一类效果。
# 返回人话摘要（每条一行），供出生叙述使用。
func apply(session, definitions: Dictionary, deck_service = null) -> Array:
	var notes: Array = []
	if session == null:
		push_error("BuffService.apply: session 为 null")
		return notes
	var all_ids: Array = []
	all_ids.append_array(session.active_buffs)
	all_ids.append_array(session.active_debuffs)
	for buff_id in all_ids:
		var def = definitions.get(String(buff_id), null)
		if def == null:
			push_error("BuffService.apply: 找不到 Buff 定义「%s」" % buff_id)
			continue
		for key in def.stat_deltas:
			var delta := int(def.stat_deltas[key])
			if delta != 0:
				session.set_stat(String(key), maxi(0, session.stat(String(key)) + delta))
		if int(def.lifespan_delta) != 0:
			session.lifespan = maxi(1, int(session.lifespan) + int(def.lifespan_delta))
		if float(def.purchasing_power_bonus) != 0.0:
			session.purchasing_power += float(def.purchasing_power_bonus)
		if not String(def.extra_card).is_empty() and deck_service != null:
			deck_service.acquire(session, String(def.extra_card), int(def.extra_card_star))
		notes.append(def.get_display_name())
	return notes

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
