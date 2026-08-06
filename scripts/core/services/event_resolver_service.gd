# 事件结算服务：把玩家选的那个 EventChoice 变成对 session 的具体改动。
# - 所有后果**立即结算**，不留延迟触发、不做多回合追踪
#   （fun-axes 反模式：严禁 CK3 风的长事件链）。
# - 不判断死活：lethal 只是如实报回去，由 RunScreen 决定这条人生怎么收场。
#   同一个理由，本服务也不写日志——它只改数据，叙述是 UI 的事。
class_name EventResolverService
extends RefCounted

const SpiritServiceScript := preload("res://scripts/core/services/spirit_service.gd")

var _spirit := SpiritServiceScript.new()
var _deck = null

# deck_service 用来发碎片 / 弃碎片；不传则这两类后果被跳过（纯数值事件仍可用）。
func _init(deck_service = null) -> void:
	_deck = deck_service

# 结算一个选项，返回 {"lethal": bool, "notes": Array[String]}。
# notes 是给年度日志的人话摘要，每条一行。
func resolve(session, event, choice_index: int) -> Dictionary:
	var result := {"lethal": false, "notes": []}
	if session == null or event == null:
		return result

	session.karma_in_run += int(event.karma_delta)

	var choice = _choice_at(event, choice_index)
	if choice == null:
		return result

	if int(choice.spirit_delta) != 0:
		_spirit.add(session, int(choice.spirit_delta))
		result["notes"].append(_format_delta("ui.event.note.spirit", "精神力", int(choice.spirit_delta)))

	session.karma_in_run += int(choice.karma_delta)

	for key in choice.stat_deltas:
		var delta := int(choice.stat_deltas[key])
		if delta == 0:
			continue
		session.set_stat(String(key), maxi(0, session.stat(String(key)) + delta))

	if int(choice.lifespan_delta) != 0:
		session.lifespan = maxi(1, int(session.lifespan) + int(choice.lifespan_delta))
		result["notes"].append(_format_delta("ui.event.note.lifespan", "寿命", int(choice.lifespan_delta)))

	if not String(choice.card_reward).is_empty() and _deck != null:
		if _deck.acquire(session, String(choice.card_reward)):
			result["notes"].append(L10n.text("ui.event.note.card", "获得一张人生碎片"))

	if not String(choice.item_reward).is_empty():
		var item_id := String(choice.item_reward)
		session.owned_items[item_id] = int(session.owned_items.get(item_id, 0)) + 1
		result["notes"].append(L10n.text("ui.event.note.item", "获得一件道具"))

	if int(choice.discard_cards) > 0:
		var lost := _discard_random(session, int(choice.discard_cards))
		if lost > 0:
			result["notes"].append(L10n.format_text("ui.event.note.discard", {"count": lost},
				"失去 %d 张人生碎片" % lost))

	result["lethal"] = bool(choice.lethal)
	return result

func _choice_at(event, index: int):
	if event.choices.is_empty():
		return null
	if index < 0 or index >= event.choices.size():
		return null
	return event.choices[index]

# 优先弃命盘（那才是痛的），命盘空了才动行囊。
func _discard_random(session, count: int) -> int:
	var removed := 0
	for _i in count:
		if not session.board_cards.is_empty():
			session.board_cards.remove_at(randi() % session.board_cards.size())
			removed += 1
		elif not session.bench_cards.is_empty():
			session.bench_cards.remove_at(randi() % session.bench_cards.size())
			removed += 1
		else:
			break
	return removed

func _format_delta(key: String, fallback_label: String, delta: int) -> String:
	var sign_text := "+" if delta > 0 else ""
	return L10n.format_text(key, {"delta": "%s%d" % [sign_text, delta]},
		"%s %s%d" % [fallback_label, sign_text, delta])
