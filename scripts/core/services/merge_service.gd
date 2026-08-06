# 升星合成服务：
# - 三张同名一星 → 一张二星；两张同名二星 → 一张满星。见 CONTEXT.md「升星」。
# - 自动触发（自走棋惯例）：玩家一拿到第三张，合成当场发生，不需要点确认。
#   理由是这里没有「先不合」的策略空间——合成永远不亏（星级倍率的下限就是按
#   「补回空出的格子」定的，见 card_instance.gd），做成手动只是多一次点击。
# - 合成会让持有的碎片总数变少，空出的命盘格由投盘时的「凡庸」补位。这是设计好的代价：
#   「摊大饼还是集中」由此成为每阶段的真实取舍。
# - 纯数据：进 session，出合成事件列表（供 UI 弹提示）。
class_name MergeService
extends RefCounted

const CardInstanceScript := preload("res://scripts/core/value_objects/card_instance.gd")

# 合成到下一星级需要几张。索引 = 当前星级 - 1；满星那一档没有下一级，填 0。
const COST_TO_NEXT := [3, 2, 0]

# 反复扫描直到没有可合成的组合，返回
# [{"definition_id","from_star","to_star","consumed"}, ...]。
# 为什么要循环：三张一星合出的二星可能与手上已有的二星再凑成满星，
# 一趟扫描会漏掉这条链。
func auto_merge(session) -> Array:
	if session == null:
		push_error("MergeService.auto_merge: session 为 null")
		return []
	var events: Array = []
	while true:
		var event := _merge_once(session)
		if event.is_empty():
			break
		events.append(event)
	return events

# 找出一组可合成的碎片并就地合成。找不到返回空字典。
func _merge_once(session) -> Dictionary:
	# 按 (definition_id, star) 分组，记下每张牌在哪个容器的哪个下标。
	var groups: Dictionary = {}
	_collect(session.board_cards, "board", groups)
	_collect(session.bench_cards, "bench", groups)

	for key in groups:
		var entries: Array = groups[key]
		var star: int = int(entries[0]["card"].star)
		if star >= CardInstanceScript.MAX_STAR:
			continue
		var cost: int = COST_TO_NEXT[star - 1]
		if cost <= 0 or entries.size() < cost:
			continue
		var consumed: Array = entries.slice(0, cost)
		var definition_id := String(entries[0]["card"].definition_id)
		# 合成品放在被消耗的第一张所在的位置：如果那张在命盘上，升星后还在命盘上，
		# 玩家不用重新配阵。全在行囊则留在行囊。
		var host: Dictionary = consumed[0]
		_remove_all(session, consumed)
		var merged := CardInstanceScript.new(definition_id, star + 1)
		_reinsert(session, host["container"], merged)
		return {
			"definition_id": definition_id,
			"from_star": star,
			"to_star": star + 1,
			"consumed": cost,
		}
	return {}

func _collect(cards: Array, container: String, groups: Dictionary) -> void:
	for i in cards.size():
		var card = cards[i]
		if card == null:
			continue
		var key := "%s#%d" % [card.definition_id, card.star]
		if not groups.has(key):
			groups[key] = []
		groups[key].append({"card": card, "container": container, "index": i})

# 按下标从大到小删，避免删前面的把后面的下标顶掉。
func _remove_all(session, entries: Array) -> void:
	var board_indices: Array = []
	var bench_indices: Array = []
	for entry in entries:
		if String(entry["container"]) == "board":
			board_indices.append(int(entry["index"]))
		else:
			bench_indices.append(int(entry["index"]))
	board_indices.sort()
	board_indices.reverse()
	bench_indices.sort()
	bench_indices.reverse()
	for i in board_indices:
		session.board_cards.remove_at(i)
	for i in bench_indices:
		session.bench_cards.remove_at(i)

# 合成品优先回到它原来的容器；那边满了就退到另一个；两边都满则丢弃
# （理论上不会发生：合成永远净减少牌数，至少空出一格）。
func _reinsert(session, container: String, card) -> void:
	if container == "board" and not session.board_is_full():
		session.board_cards.append(card)
		return
	if container == "bench" and not session.bench_is_full():
		session.bench_cards.append(card)
		return
	if not session.board_is_full():
		session.board_cards.append(card)
	elif not session.bench_is_full():
		session.bench_cards.append(card)
	else:
		push_error("MergeService: 合成品无处安放（命盘与行囊都满），已丢弃 %s" % card.definition_id)

# 玩家手上还差几张就能把这个 id 升到下一星（UI 显示「2/3」用）。
# 返回 {"star": 当前最低可合星级, "have": n, "need": m}；不可合成返回空字典。
func progress_for(session, definition_id: String) -> Dictionary:
	if session == null:
		return {}
	var counts: Dictionary = {}
	for card in session.all_cards():
		if card == null or String(card.definition_id) != definition_id:
			continue
		var star := int(card.star)
		counts[star] = int(counts.get(star, 0)) + 1
	for star in [1, 2]:
		if not counts.has(star):
			continue
		var cost: int = COST_TO_NEXT[star - 1]
		if cost <= 0:
			continue
		return {"star": star, "have": int(counts[star]), "need": cost}
	return {}
