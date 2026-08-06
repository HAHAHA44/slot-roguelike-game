# 三选一抽取服务（投注池）：
# - 每年年初摆出 3 张候选，玩家可以**免费跳过**；要拿就得从命盘或行囊弃一张（容量满时）。
# - 候选只来自**当前人生阶段**的碎片池（ADR-0003）：分池是三合一在数学上成立的前提，
#   全局单池铺到 50 种时，一生根本凑不齐同名。
#
# 三张候选的构成是 2 张加权 + 1 张纯随机，这不是配平数字而是两种功能：
#   加权位  —— 偏向玩家已持有的种类与已建树的领域，让「专精」从抽奖变成策略
#   随机位  —— 永远保留一个陌生选项，避免后期候选完全可预测、也给转型留门
#
# 纯 RefCounted，随机走全局 randf/randi，与其它服务一致。
class_name DraftService
extends RefCounted

const OFFER_SIZE := 3
# 三张里有几张走加权（其余为纯随机）。
const WEIGHTED_SLOTS := 2
# 手上已有同名碎片时的权重倍率。这是三合一可行性的主要来源：
# 不加权时一阶段期望只能拿到约 2.75 张同名，连三张一合都够不着。
const OWNED_MULTIPLIER := 2.0
# 已在该领域建过树时的权重倍率，让传承链能续上（连中三环从 6.4% 升到约 15%）。
const LEGACY_DOMAIN_MULTIPLIER := 1.6
# 稀有度基础权重。运气维会把这条曲线整体压平（高运气更容易见到稀有碎片）。
const RARITY_WEIGHT := {
	"Common": 1.0,
	"Uncommon": 0.6,
	"Rare": 0.3,
	"Legendary": 0.12,
}
# 每点运气把稀有碎片的权重抬高多少（相对值）。
const LUCK_RARITY_STEP := 0.04

# 摆出本年的三张候选，返回 definition id 数组（不足 3 种时返回全部，可能少于 3）。
func roll_offer(session, tokens: Dictionary, stage_id: String) -> Array:
	var pool := _stage_pool(tokens, stage_id)
	if pool.is_empty():
		return []
	var luck: int = session.stat("luck") if session != null else 0
	var offer: Array = []

	for i in OFFER_SIZE:
		var candidates := _exclude(pool, offer)
		if candidates.is_empty():
			break
		if i < WEIGHTED_SLOTS:
			offer.append(_pick_weighted(candidates, session, tokens, luck))
		else:
			offer.append(String(candidates[randi() % candidates.size()]))
	return offer

# 当前阶段可抽的碎片 id（跳过补位碎片与传承物）。
func _stage_pool(tokens: Dictionary, stage_id: String) -> Array:
	var pool: Array = []
	for token_id in tokens:
		var def = tokens[token_id]
		if def == null or not def.is_draftable():
			continue
		if String(def.stage_id) != stage_id:
			continue
		pool.append(String(token_id))
	pool.sort()  # 稳定顺序，保证同一 seed 下可复现
	return pool

func _exclude(pool: Array, taken: Array) -> Array:
	var result: Array = []
	for id in pool:
		if not taken.has(id):
			result.append(id)
	return result

# 按权重轮盘赌抽一张。权重 = 稀有度基线 × 定义权重 × 已持有加成 × 领域加成。
func _pick_weighted(candidates: Array, session, tokens: Dictionary, luck: int) -> String:
	var weights: Array = []
	var total: float = 0.0
	for id in candidates:
		var w := _weight_for(String(id), session, tokens, luck)
		weights.append(w)
		total += w
	if total <= 0.0:
		return String(candidates[randi() % candidates.size()])
	var roll: float = randf() * total
	for i in candidates.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			return String(candidates[i])
	return String(candidates[candidates.size() - 1])

func _weight_for(definition_id: String, session, tokens: Dictionary, luck: int) -> float:
	var def = tokens.get(definition_id, null)
	if def == null:
		return 0.0
	var weight: float = float(def.draft_weight)
	weight *= _rarity_weight(String(def.rarity), luck)
	if session != null:
		if _owns(session, definition_id):
			weight *= OWNED_MULTIPLIER
		var domain := String(def.domain)
		if not domain.is_empty() and session.legacy_domains.has(domain):
			weight *= LEGACY_DOMAIN_MULTIPLIER
	return maxf(weight, 0.0)

# 运气把稀有度曲线压平：基线越低（越稀有）被抬得越多，
# 所以高运气主要体现在「更常见到传说」，而不是「常见碎片也变多」。
func _rarity_weight(rarity: String, luck: int) -> float:
	var base: float = float(RARITY_WEIGHT.get(rarity, 1.0))
	var lift: float = float(maxi(luck, 0)) * LUCK_RARITY_STEP * (1.0 - base)
	return clampf(base + lift, 0.01, 1.0)

func _owns(session, definition_id: String) -> bool:
	for card in session.all_cards():
		if card != null and String(card.definition_id) == definition_id:
			return true
	return false
