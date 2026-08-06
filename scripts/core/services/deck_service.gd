# 牌堆服务：命盘（12）与行囊（6）的增删换，以及阶段边界的清空与传承。
#
# 阶段边界是这个游戏最重的一次状态变更。一张当期碎片能不能活过去，只看两条：
#   1. 满星且可传承 → 按 legacy_into 进化成传承物（同领域每阶段只升一环）。
#   2. **升过星（star > 1）→ 原样留下。** 合成花掉了三张牌，那份投入不该在
#      阶段边界上凭空蒸发；只有一星的散牌才是「童年的东西带不走」的那部分。
# 传承物本身不属于任何阶段（stage_id 为空、is_legacy 为真），不受清空影响，一路陪到死。
#
# 见 ADR-0003（第 2 条是它的修订：原案是「唯满星者传承」，二星一并清空）。
#
# 纯 RefCounted：进 session + 碎片表，出结果结构，不碰场景。
class_name DeckService
extends RefCounted

const CardInstanceScript := preload("res://scripts/core/value_objects/card_instance.gd")

# -- 获得 / 丢弃 -------------------------------------------------------------

# 拿一张新碎片。优先进命盘，命盘满了进行囊，都满则失败（调用方应先让玩家弃牌）。
func acquire(session, definition_id: String, star: int = 1) -> bool:
	if session == null or definition_id.is_empty():
		return false
	var card = CardInstanceScript.new(definition_id, star)
	if not session.board_is_full():
		session.board_cards.append(card)
		return true
	if not session.bench_is_full():
		session.bench_cards.append(card)
		return true
	return false

func has_room(session) -> bool:
	if session == null:
		return false
	return not session.board_is_full() or not session.bench_is_full()

func discard_board(session, index: int) -> bool:
	if session == null or index < 0 or index >= session.board_cards.size():
		return false
	session.board_cards.remove_at(index)
	return true

func discard_bench(session, index: int) -> bool:
	if session == null or index < 0 or index >= session.bench_cards.size():
		return false
	session.bench_cards.remove_at(index)
	return true

# -- 调阵 --------------------------------------------------------------------

# 命盘第 board_index 张与行囊第 bench_index 张对换。这是行囊每年的主要用途：
# 看明年的年度规则，把对路的碎片换上盘。免费、不限次，但只在投盘前可操作
# （投盘后还能改，等于让玩家看到结果再反悔）。
func swap(session, board_index: int, bench_index: int) -> bool:
	if session == null:
		return false
	if board_index < 0 or board_index >= session.board_cards.size():
		return false
	if bench_index < 0 or bench_index >= session.bench_cards.size():
		return false
	var tmp = session.board_cards[board_index]
	session.board_cards[board_index] = session.bench_cards[bench_index]
	session.bench_cards[bench_index] = tmp
	return true

# 把行囊某张直接移上命盘（命盘有空位时）。没空位请用 swap。
func promote(session, bench_index: int) -> bool:
	if session == null or session.board_is_full():
		return false
	if bench_index < 0 or bench_index >= session.bench_cards.size():
		return false
	session.board_cards.append(session.bench_cards[bench_index])
	session.bench_cards.remove_at(bench_index)
	return true

# 把命盘某张收回行囊（行囊有空位时）。
func demote(session, board_index: int) -> bool:
	if session == null or session.bench_is_full():
		return false
	if board_index < 0 or board_index >= session.board_cards.size():
		return false
	session.bench_cards.append(session.board_cards[board_index])
	session.board_cards.remove_at(board_index)
	return true

# -- 阶段边界 ----------------------------------------------------------------

# 阶段结束：满星者进化成传承物，升过星的原样留下，一星散牌清空。
# 返回 [{"from","into","domain","ring"}, ...]，供 UI 播「你在这个领域有所建树」。
#
# 链式进化的实现：**同领域的第二次建树不是再来一件一环传承物，而是把手上那件升格**。
# 所以一条领域线在命盘上永远只占一格，越走越粗；三环封顶后再建树不再产出新东西
# （链长上限是内容量的闸门，见 growth-loop-design 第 Q22 条）。
# 同一个阶段里同领域有多张满星也只算一环——一个阶段只能在一个领域前进一步。
# 没能升格的那张满星（同领域已建过树 / 传承目标缺失）不会被顺手丢掉，按第 2 条留下。
func end_stage(session, tokens: Dictionary) -> Array:
	if session == null:
		push_error("DeckService.end_stage: session 为 null")
		return []
	var kept: Array = []
	var ascending: Dictionary = {}   # domain -> {"def","card"}，该领域触发传承的那张
	# 升过星、但没进传承通道的当期碎片。放到最后再并进 kept，
	# 这样容量不够时先挤掉的是它们，而不是传承物这条人生的骨干。
	var carried: Array = []
	for card in session.all_cards():
		if card == null:
			continue
		var def = tokens.get(String(card.definition_id), null)
		if def == null:
			continue
		# 跨阶段碎片（传承物、补位碎片）不受清空影响。
		if String(def.stage_id).is_empty():
			kept.append(card)
			continue
		if card.is_max_star() and def.can_ascend() and not ascending.has(String(def.domain)):
			ascending[String(def.domain)] = {"def": def, "card": card}
			continue
		if int(card.star) > 1:
			carried.append(card)

	var ascensions: Array = []
	for domain in ascending:
		var source = ascending[domain]["def"]
		var existing_index := _find_ascendable_legacy(kept, tokens, String(domain))
		var into := ""
		if existing_index >= 0:
			var existing_def = tokens.get(String(kept[existing_index].definition_id), null)
			into = String(existing_def.legacy_into)
		else:
			# 该领域已有封顶的传承物时，不再新起一环一的链（否则会出现两条并行的同领域线）。
			if _has_legacy_of_domain(kept, tokens, String(domain)):
				carried.append(ascending[domain]["card"])
				continue
			into = String(source.legacy_into)
		if into.is_empty() or not tokens.has(into):
			push_error("传承目标碎片「%s」不存在（来自 %s）" % [into, source.id])
			carried.append(ascending[domain]["card"])
			continue
		var ring: int = int(session.legacy_domains.get(domain, 0)) + 1
		if not String(domain).is_empty():
			session.legacy_domains[domain] = ring
		if existing_index >= 0:
			kept[existing_index] = CardInstanceScript.new(into, 1)
		else:
			kept.append(CardInstanceScript.new(into, 1))
		ascensions.append({"from": String(source.id), "into": into,
			"domain": String(domain), "ring": ring})

	# 强的排前面：命盘 12 + 行囊 6 装不下时，被挤掉的应该是最弱的那几张，
	# 而不是碰巧排在后面的那几张。
	carried.sort_custom(func(a, b): return _carried_rank(a, tokens) > _carried_rank(b, tokens))
	kept.append_array(carried)

	# 传承物回到命盘（它们是这条人生的骨干），溢出的放行囊。
	session.board_cards = []
	session.bench_cards = []
	for card in kept:
		if not session.board_is_full():
			session.board_cards.append(card)
		elif not session.bench_is_full():
			session.bench_cards.append(card)
	return ascensions

# 排序权重：先看星级，同星看进盘分。只用于容量不够时决定谁被挤掉。
func _carried_rank(card, tokens: Dictionary) -> float:
	var def = tokens.get(String(card.definition_id), null)
	var base: float = float(def.base_score) if def != null else 0.0
	return float(card.star) * 1000.0 + base

# 手上该领域那件还能再升格的传承物在 kept 里的下标；没有返回 -1。
func _find_ascendable_legacy(kept: Array, tokens: Dictionary, domain: String) -> int:
	for i in kept.size():
		var def = tokens.get(String(kept[i].definition_id), null)
		if def == null or not def.is_legacy:
			continue
		if String(def.domain) == domain and def.can_ascend():
			return i
	return -1

func _has_legacy_of_domain(kept: Array, tokens: Dictionary, domain: String) -> bool:
	for card in kept:
		var def = tokens.get(String(card.definition_id), null)
		if def != null and def.is_legacy and String(def.domain) == domain:
			return true
	return false
