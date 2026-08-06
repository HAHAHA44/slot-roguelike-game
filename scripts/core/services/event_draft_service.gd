# 年末事件抽取服务（双层）：
#
#   流水年（每年）  —— 一行金句，不阻塞，pick_flavor()
#   转折年（约 20%）—— 弹窗做选择，should_trigger() 命中后 draft_event()
#
# 精神力同时控制两件事，这是 fun-axes P3 的落点：
#   ① 转折年的**触发密度**（低精神更频繁 —— 日子越难，事越多）
#   ② 恶性/致死事件的**权重**（低精神才抽得到致死）
# 于是「低精神 = 死亡轮盘开启」在数值上有两重含义，压力是复合的。
#
# 纯 RefCounted：数据进（事件表 + 阶段 + 精神档），数据出（选中的定义）。
class_name EventDraftService
extends RefCounted

# 各精神档下，一年是转折年的概率。
# 低精神档差不多每三年一次大事，高精神档八年才一次——日子好过时人生是平静的。
const TRIGGER_CHANCE := {
	"high": 0.12,
	"mid": 0.20,
	"low": 0.32,
}
# 本命年必定是转折年：12 年一遇的大喜大悲，不该被概率吃掉。
const BIRTH_YEAR_ALWAYS_TRIGGERS := true

func should_trigger(bucket: String, is_birth_year: bool = false) -> bool:
	if is_birth_year and BIRTH_YEAR_ALWAYS_TRIGGERS:
		return true
	return randf() < float(TRIGGER_CHANCE.get(bucket, 0.2))

# 抽一个转折年事件。抽不到（池子被过滤空了）返回 null。
func draft_event(events: Dictionary, stage_id: String, bucket: String,
		zodiac_id: String, is_birth_year: bool):
	var candidates := _candidates(events, stage_id, bucket, zodiac_id, is_birth_year)
	if candidates.is_empty():
		return null
	var total: float = 0.0
	for entry in candidates:
		total += float(entry["weight"])
	if total <= 0.0:
		return null
	var roll: float = randf() * total
	for entry in candidates:
		roll -= float(entry["weight"])
		if roll <= 0.0:
			return entry["def"]
	return candidates[candidates.size() - 1]["def"]

# 明牌概率提示：返回 {"benign": %, "neutral": %, "malign": %, "lethal": %}。
# fun-axes 要求「让玩家做明牌风险评估，不要黑箱」，所以这个数直接上 UI。
func outcome_odds(events: Dictionary, stage_id: String, bucket: String,
		zodiac_id: String, is_birth_year: bool) -> Dictionary:
	var odds := {"benign": 0.0, "neutral": 0.0, "malign": 0.0, "lethal": 0.0}
	var candidates := _candidates(events, stage_id, bucket, zodiac_id, is_birth_year)
	var total: float = 0.0
	for entry in candidates:
		total += float(entry["weight"])
	if total <= 0.0:
		return odds
	for entry in candidates:
		var kind := String(entry["def"].kind)
		if not odds.has(kind):
			continue
		odds[kind] += float(entry["weight"]) / total * 100.0
	return odds

func _candidates(events: Dictionary, stage_id: String, bucket: String,
		zodiac_id: String, is_birth_year: bool) -> Array:
	var result: Array = []
	var ids: Array = events.keys()
	ids.sort()  # 稳定顺序，保证同 seed 可复现
	for event_id in ids:
		var def = events[event_id]
		if def == null:
			continue
		# 本命年事件池独占：本命年只抽本命年事件，平年抽不到它们。
		if bool(def.birth_year_only) != is_birth_year:
			continue
		if not String(def.stage_id).is_empty() and String(def.stage_id) != stage_id:
			continue
		if not String(def.zodiac_id).is_empty() and String(def.zodiac_id) != zodiac_id:
			continue
		var weight: float = def.weight_for(bucket)
		if weight <= 0.0:
			continue
		result.append({"def": def, "weight": weight})
	return result

# 流水年金句。抽不到返回 null（内容缺失时年度日志少一行，不影响流程）。
func pick_flavor(flavor_lines: Dictionary, stage_id: String, bucket: String):
	var candidates: Array = []
	var total: float = 0.0
	var ids: Array = flavor_lines.keys()
	ids.sort()
	for line_id in ids:
		var def = flavor_lines[line_id]
		if def == null:
			continue
		if not String(def.stage_id).is_empty() and String(def.stage_id) != stage_id:
			continue
		if not String(def.spirit_bucket).is_empty() and String(def.spirit_bucket) != bucket:
			continue
		var weight: float = maxf(float(def.weight), 0.0)
		if weight <= 0.0:
			continue
		candidates.append({"def": def, "weight": weight})
		total += weight
	if candidates.is_empty() or total <= 0.0:
		return null
	var roll: float = randf() * total
	for entry in candidates:
		roll -= float(entry["weight"])
		if roll <= 0.0:
			return entry["def"]
	return candidates[candidates.size() - 1]["def"]
