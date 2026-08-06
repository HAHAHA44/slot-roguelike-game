# EventResolverService 契约：把玩家选的那个 EventChoice 变成对 session 的具体改动。
# 所有后果立即结算，不留延迟触发（fun-axes 反模式禁止长事件链）。
extends GutTest

const EventResolverServiceScript := preload("res://scripts/core/services/event_resolver_service.gd")
const DeckServiceScript := preload("res://scripts/core/services/deck_service.gd")
const SpiritServiceScript := preload("res://scripts/core/services/spirit_service.gd")
const RunSessionScript := preload("res://autoload/run_session.gd")
const CardInstanceScript := preload("res://scripts/core/value_objects/card_instance.gd")

var _resolver
var _session

func before_each() -> void:
	_resolver = EventResolverServiceScript.new(DeckServiceScript.new())
	_session = RunSessionScript.new()
	_session.lifespan = 80
	_session.set_stat("spr", 10)

func _event(choice_fields: Dictionary, karma: int = 0):
	var def := EventDefinition.new()
	def.id = "ev"
	def.name = "测试事件"
	def.kind = "neutral"
	def.karma_delta = karma
	var choice := EventChoice.new()
	choice.text = "选它"
	for key in choice_fields:
		choice.set(String(key), choice_fields[key])
	def.choices.append(choice)
	return def

# -- 数值后果 ----------------------------------------------------------------

func test_spirit_delta_is_applied() -> void:
	_resolver.resolve(_session, _event({"spirit_delta": -3}), 0)
	assert_eq(_session.stat("spr"), 7)

func test_spirit_delta_is_clamped() -> void:
	_resolver.resolve(_session, _event({"spirit_delta": -999}), 0)
	assert_eq(_session.stat("spr"), SpiritServiceScript.MIN_VALUE)

func test_karma_from_event_and_choice_both_count() -> void:
	_resolver.resolve(_session, _event({"karma_delta": 2}, 1), 0)
	assert_eq(_session.karma_in_run, 3, "事件本身的 karma 和选项的 karma 都要累加")

func test_stat_deltas_apply_and_floor_at_zero() -> void:
	_session.set_stat("str", 1)
	_resolver.resolve(_session, _event({"stat_deltas": {"str": -5}}), 0)
	assert_eq(_session.stat("str"), 0, "属性不该变成负数")

func test_lifespan_delta_applies_and_stays_positive() -> void:
	_resolver.resolve(_session, _event({"lifespan_delta": -5}), 0)
	assert_eq(_session.lifespan, 75)
	_resolver.resolve(_session, _event({"lifespan_delta": -999}), 0)
	assert_gt(_session.lifespan, 0, "寿命不该被事件打到 0 以下")

# -- 奖励 --------------------------------------------------------------------

func test_card_reward_lands_in_the_deck() -> void:
	_resolver.resolve(_session, _event({"card_reward": "abacus"}), 0)
	assert_eq(_session.board_cards.size(), 1)
	assert_eq(String(_session.board_cards[0].definition_id), "abacus")
	assert_eq(_session.board_cards[0].star, 1, "事件给的是机会，练不练得成是玩家的事")

func test_item_reward_is_added() -> void:
	_resolver.resolve(_session, _event({"item_reward": "lucky_charm"}), 0)
	assert_eq(int(_session.owned_items["lucky_charm"]), 1)

func test_card_reward_is_skipped_without_a_deck_service() -> void:
	var bare = EventResolverServiceScript.new(null)
	bare.resolve(_session, _event({"card_reward": "abacus"}), 0)
	assert_eq(_session.board_cards.size(), 0, "没有牌堆服务时安静跳过，不该崩")

# -- 惩罚 --------------------------------------------------------------------

func test_discard_takes_from_the_board_first() -> void:
	# 弃命盘才是痛的；行囊里的牌本来就没上场。
	_session.board_cards.append(CardInstanceScript.new("a"))
	_session.bench_cards.append(CardInstanceScript.new("b"))
	_resolver.resolve(_session, _event({"discard_cards": 1}), 0)
	assert_eq(_session.board_cards.size(), 0)
	assert_eq(_session.bench_cards.size(), 1)

func test_discard_falls_back_to_bench_when_board_is_empty() -> void:
	_session.bench_cards.append(CardInstanceScript.new("b"))
	_resolver.resolve(_session, _event({"discard_cards": 2}), 0)
	assert_eq(_session.bench_cards.size(), 0)

func test_discard_on_empty_deck_is_safe() -> void:
	var result: Dictionary = _resolver.resolve(_session, _event({"discard_cards": 3}), 0)
	assert_false(bool(result["lethal"]))

# -- 致死 --------------------------------------------------------------------

func test_lethal_choice_is_reported_not_executed() -> void:
	# 本服务只如实报回去，怎么收场由 RunScreen 决定。
	var result: Dictionary = _resolver.resolve(_session, _event({"lethal": true}), 0)
	assert_true(bool(result["lethal"]))
	assert_eq(_session.death_cause, "", "结算服务不该自己判死")

func test_non_lethal_choice_reports_false() -> void:
	var result: Dictionary = _resolver.resolve(_session, _event({"spirit_delta": 1}), 0)
	assert_false(bool(result["lethal"]))

# -- 边界 --------------------------------------------------------------------

func test_out_of_range_choice_still_applies_event_karma() -> void:
	var result: Dictionary = _resolver.resolve(_session, _event({"spirit_delta": 5}, 3), 99)
	assert_eq(_session.karma_in_run, 3)
	assert_eq(_session.stat("spr"), 10, "越界的选项不该结算任何选项后果")
	assert_false(bool(result["lethal"]))

func test_null_inputs_are_safe() -> void:
	assert_false(bool(_resolver.resolve(null, _event({}), 0)["lethal"]))
	assert_false(bool(_resolver.resolve(_session, null, 0)["lethal"]))

func test_notes_describe_what_happened() -> void:
	var result: Dictionary = _resolver.resolve(_session,
		_event({"spirit_delta": -2, "item_reward": "lucky_charm"}), 0)
	assert_gt(result["notes"].size(), 1, "年度日志要能说清这一年发生了什么")
