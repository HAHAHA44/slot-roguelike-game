# cascade 结算服务（整个游戏的爽感主轴）：
#
# 一年分三段跑：
#   进盘   —— 每格初始分 = base_score × 星级倍率，再吃当年的「进盘类」修正
#   cascade —— 反复挑「未结算、当前分最低」的槽位触发其 effects（min-score-first）
#   收尾   —— 最高/最低格加成、连击总加成、道具全局乘区，最后求和 = 年收益
#
# 为什么是最低分先结算：低分碎片先跑，它们的加成会落到还没结算的高分碎片上，
# 于是分数在 cascade 后段滚雪球式膨胀 —— 这正是 fun-axes P2「数字必须能炸破天」要的形状。
# 反过来（高分先）会让加成落在已经定型的碎片上，曲线是平的。
#
# 已结算的碎片仍然可以被后来者改分，只是不会再次触发 effect。这让"最后一张碎片
# 反手把全场拉起来"成为可能，是 P1 慢镜头收尾的素材。
#
# 服务是 RefCounted、无场景依赖：数据进（ring board + 碎片表 + 当年修正），
# 数据出（CascadeReport）。
class_name SettlementService
extends RefCounted

const CascadeContextScript := preload("res://scripts/core/effects/cascade_context.gd")
const YearModifiersScript := preload("res://scripts/core/value_objects/year_modifiers.gd")

# id -> TokenDefinition。由调用方从 ContentRegistry.tokens 传入。
var _tokens: Dictionary = {}

func _init(tokens: Dictionary = {}) -> void:
	_tokens = tokens

# 结算一整盘，返回当年 CascadeReport。同一 service 可重复调用，不残留上一次的状态。
# modifiers 为 null 时按「无任何修正」跑（早期测试与 stub 路径用）。
func settle(ring_board, modifiers = null) -> CascadeReport:
	var warnings: Array = []
	if ring_board == null:
		warnings.append("SettlementService.settle: ring_board 为 null")
		return CascadeReport.new([], 0, 0, warnings)

	var mods = modifiers if modifiers != null else YearModifiersScript.new()
	var ring_size: int = ring_board.RING_SIZE
	var scores: Array = []
	var pending: Array = []
	scores.resize(ring_size)
	for i in ring_size:
		scores[i] = 0

	# -- 进盘 -----------------------------------------------------------------
	for slot in ring_board.occupied_slots():
		var slot_index: int = int(slot)
		var token_id: String = ring_board.token_at(slot_index)
		var def = _tokens.get(token_id, null)
		if def == null:
			warnings.append("未知碎片 id「%s」（slot %d），跳过结算" % [token_id, slot_index])
			continue
		scores[slot_index] = _entry_score(def, ring_board.card_at(slot_index), slot_index, mods)
		pending.append(slot_index)

	var context = CascadeContextScript.new(ring_board, _tokens, scores, mods)
	var steps: Array = []
	var chain_count: int = 0

	# -- cascade --------------------------------------------------------------
	while not pending.is_empty():
		var next_slot: int = _pick_lowest_score_slot(pending, scores)
		pending.erase(next_slot)

		var token_id: String = ring_board.token_at(next_slot)
		var def = _tokens[token_id]
		var card = ring_board.card_at(next_slot)
		var score_before: int = int(scores[next_slot])

		context.begin_card(next_slot, token_id, card.multiplier() if card != null else 1.0)
		for effect in def.effects:
			if effect == null:
				continue
			context.begin_effect()
			effect.execute(context)
			# 一个 effect 命中 ≥1 个目标就记 1 次 chain（不是每个目标记一次）。
			if context.effect_hit():
				chain_count += 1

		var links: Array = context.step_links().duplicate()
		var affected: Array = []
		var chain_kind: String = ""
		for link in links:
			affected.append(int(link["slot"]))
			if chain_kind.is_empty():
				chain_kind = String(link["kind"])

		steps.append(CascadeStep.new(
			steps.size(),
			next_slot,
			token_id,
			score_before,
			int(scores[next_slot]),
			affected,
			links,
			chain_kind,
			chain_count
		))

	# -- 收尾 -----------------------------------------------------------------
	var settled: Array = ring_board.occupied_slots()
	_apply_extreme_bonus(scores, settled, mods)
	_apply_chain_bonus(scores, settled, chain_count, mods)

	var total: int = 0
	for slot in settled:
		total += int(scores[int(slot)])
	total = roundi(float(total) * (1.0 + float(mods.settle_percent) / 100.0))

	return CascadeReport.new(steps, total, chain_count, warnings)

# 进盘分：基础分 × 星级，再依次吃「囤积 / 全场 / 星级 / 领域 / 偶数槽」五类进盘修正。
# 全部是加法叠加而非连乘——进盘阶段就开始连乘会让年度规则之间产生指数耦合，
# 调一个数会牵动另外四个，那种平衡表没法维护。
func _entry_score(def, card, slot_index: int, mods) -> int:
	var base: float = float(def.base_score) * (card.multiplier() if card != null else 1.0)
	var percent: int = 0
	if int(mods.star_percent) != 0 and card != null and int(card.star) >= 2:
		percent += int(mods.star_percent)
	if int(mods.domain_percent) != 0 and not String(mods.domain).is_empty() \
			and String(def.domain) == String(mods.domain):
		percent += int(mods.domain_percent)
	if int(mods.even_slot_percent) != 0 and slot_index % 2 == 0:
		percent += int(mods.even_slot_percent)
	var score: int = roundi(base * (1.0 + float(percent) / 100.0))
	score += int(mods.all_base_bonus)
	# 囤积类规则看的是碎片**定义**的基础分，不是乘过星级的分——
	# 否则把小碎片升星反而会让它掉出「便宜牌」的范围，玩家会觉得被惩罚了。
	if int(mods.low_base_threshold) > 0 and int(def.base_score) <= int(mods.low_base_threshold):
		score += int(mods.low_base_bonus)
	return score

# 龙·腾达 / 羊·守拙：结算完毕后给最高 / 最低的那一格追加百分比。
# 同分时取槽位小的，保证可复现。
func _apply_extreme_bonus(scores: Array, settled: Array, mods) -> void:
	if settled.is_empty():
		return
	if int(mods.highest_percent) != 0:
		var top: int = int(settled[0])
		for slot in settled:
			if int(scores[int(slot)]) > int(scores[top]):
				top = int(slot)
		scores[top] = int(scores[top]) + roundi(float(scores[top]) * float(mods.highest_percent) / 100.0)
	if int(mods.lowest_percent) != 0:
		var bottom: int = int(settled[0])
		for slot in settled:
			if int(scores[int(slot)]) < int(scores[bottom]):
				bottom = int(slot)
		scores[bottom] = int(scores[bottom]) + roundi(float(scores[bottom]) * float(mods.lowest_percent) / 100.0)

# 猴·机变：每累计一次连击给全场 +p%。连击多的年份收益非线性上翘，
# 是「联动流」build 的专属回报。
func _apply_chain_bonus(scores: Array, settled: Array, chain_count: int, mods) -> void:
	if int(mods.chain_percent) == 0 or chain_count <= 0:
		return
	var factor: float = 1.0 + float(chain_count) * float(mods.chain_percent) / 100.0
	for slot in settled:
		var i: int = int(slot)
		scores[i] = roundi(float(scores[i]) * factor)

# 最低分优先；同分取槽位索引最小的，保证同一盘面每次结算顺序一致（测试可断言、回放可复现）。
func _pick_lowest_score_slot(pending: Array, scores: Array) -> int:
	var best_slot: int = int(pending[0])
	var best_score: int = int(scores[best_slot])
	for candidate in pending:
		var slot_index: int = int(candidate)
		var score: int = int(scores[slot_index])
		if score < best_score or (score == best_score and slot_index < best_slot):
			best_slot = slot_index
			best_score = score
	return best_slot
