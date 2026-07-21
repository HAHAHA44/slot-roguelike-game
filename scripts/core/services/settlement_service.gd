# cascade 结算服务（M1 核心 —— 整个游戏的爽感主轴）：
#
# 算法是 min-score-first（幸运房东式多米诺）：
#   1. 每个占用槽位的 current_score 初始化为 token 的 base_score
#   2. 反复挑「尚未结算、当前分数最低」的槽位结算，同分取槽位索引小的（保证可复现）
#   3. 结算 = 依次执行该 token 的 effects，effect 可以改任意槽位的分（含已结算的）
#   4. 全部结算完 → 年收益 = Σ 各槽当前分数
#
# 为什么是最低分先结算：低分 token 先跑，它们的加成会落到还没结算的高分 token 上，
# 于是分数在 cascade 后段滚雪球式膨胀 —— 这正是 fun-axes P2「数字必须能炸破天」要的形状。
# 反过来（高分先）会让加成落在已经定型的 token 上，曲线是平的。
#
# 已结算的 token 仍然可以被后来者改分，只是不会再次触发 effect。这让"最后一个 token
# 反手把全场拉起来"成为可能，是 P1 慢镜头收尾的素材。
#
# 服务是 RefCounted、无场景依赖：数据进（ring board + token 表），数据出（CascadeReport）。
class_name SettlementService
extends RefCounted

const CascadeContextScript := preload("res://scripts/core/effects/cascade_context.gd")

# id -> TokenDefinition。由调用方从 ContentRegistry.tokens 传入。
var _tokens: Dictionary = {}

func _init(tokens: Dictionary = {}) -> void:
	_tokens = tokens

# 结算一整盘，返回当年 CascadeReport。同一 service 可重复调用，不残留上一次的状态。
func settle(ring_board) -> CascadeReport:
	var warnings: Array = []
	if ring_board == null:
		warnings.append("SettlementService.settle: ring_board 为 null")
		return CascadeReport.new([], 0, 0, warnings)

	var ring_size: int = ring_board.RING_SIZE
	var scores: Array = []
	var pending: Array = []
	scores.resize(ring_size)
	for i in ring_size:
		scores[i] = 0

	for slot in ring_board.occupied_slots():
		var slot_index: int = int(slot)
		var token_id: String = ring_board.token_at(slot_index)
		var def = _tokens.get(token_id, null)
		if def == null:
			warnings.append("未知 token id「%s」（slot %d），跳过结算" % [token_id, slot_index])
			continue
		scores[slot_index] = int(def.base_score)
		pending.append(slot_index)

	var context = CascadeContextScript.new(ring_board, _tokens, scores)
	var steps: Array = []
	var chain_count: int = 0

	while not pending.is_empty():
		var next_slot: int = _pick_lowest_score_slot(pending, scores)
		pending.erase(next_slot)

		var token_id: String = ring_board.token_at(next_slot)
		var def = _tokens[token_id]
		var score_before: int = int(scores[next_slot])

		context.begin_token(next_slot, token_id)
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

	var total: int = 0
	for slot in ring_board.occupied_slots():
		total += int(scores[int(slot)])

	return CascadeReport.new(steps, total, chain_count, warnings)

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
