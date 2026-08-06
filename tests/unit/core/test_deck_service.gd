# DeckService 契约：命盘（12）/ 行囊（6）的增删换，以及阶段边界的清空与传承。
#
# 阶段边界是整个游戏最重的一次状态变更：一星散牌全清，满星者按 legacy_into 进化成
# 传承物，升过星的（star > 1）原样留下（ADR-0003 及其 2026-08 修订）。
extends GutTest

const DeckServiceScript := preload("res://scripts/core/services/deck_service.gd")
const RunSessionScript := preload("res://autoload/run_session.gd")
const CardInstanceScript := preload("res://scripts/core/value_objects/card_instance.gd")

var _service
var _session
var _tokens: Dictionary

func before_each() -> void:
	_service = DeckServiceScript.new()
	_session = RunSessionScript.new()
	_tokens = {}

func _token(id: String, stage_id: String, domain: String, legacy_into: String = "",
		is_legacy: bool = false) -> void:
	var def := TokenDefinition.new()
	def.id = id
	def.name = id
	def.stage_id = stage_id
	def.domain = domain
	def.legacy_into = legacy_into
	def.is_legacy = is_legacy
	def.draft_weight = 0.0 if is_legacy else 1.0
	_tokens[id] = def

func _ids_on_board() -> Array:
	var result: Array = []
	for card in _session.board_cards:
		result.append(String(card.definition_id))
	result.sort()
	return result

# -- 获得 --------------------------------------------------------------------

func test_acquire_fills_board_first_then_bench() -> void:
	for i in 12:
		assert_true(_service.acquire(_session, "t%d" % i))
	assert_eq(_session.board_cards.size(), 12)
	assert_true(_service.acquire(_session, "extra"))
	assert_eq(_session.bench_cards.size(), 1, "命盘满了才溢到行囊")

func test_acquire_fails_when_everything_is_full() -> void:
	for i in 18:
		_service.acquire(_session, "t%d" % i)
	assert_false(_service.has_room(_session))
	assert_false(_service.acquire(_session, "one_more"), "18 格满了就是拿不下")

func test_acquire_rejects_empty_id() -> void:
	assert_false(_service.acquire(_session, ""))

func test_acquire_can_set_star() -> void:
	_service.acquire(_session, "abacus", 2)
	assert_eq(_session.board_cards[0].star, 2, "家世好的人一出生就有二星的东西")

# -- 调阵 --------------------------------------------------------------------

func test_swap_exchanges_board_and_bench() -> void:
	_service.acquire(_session, "on_board")
	for i in 12:
		_service.acquire(_session, "filler%d" % i)   # 挤满命盘，第 13 张进行囊
	var bench_id := String(_session.bench_cards[0].definition_id)
	assert_true(_service.swap(_session, 0, 0))
	assert_eq(String(_session.board_cards[0].definition_id), bench_id)
	assert_eq(String(_session.bench_cards[0].definition_id), "on_board")

func test_swap_rejects_bad_indices() -> void:
	_service.acquire(_session, "a")
	assert_false(_service.swap(_session, 0, 0), "行囊是空的，换不了")
	assert_false(_service.swap(_session, 99, 0))

func test_promote_moves_bench_card_up_when_board_has_room() -> void:
	for i in 12:
		_service.acquire(_session, "b%d" % i)
	_service.acquire(_session, "waiting")          # 进了行囊
	_service.discard_board(_session, 0)            # 命盘空出一格
	assert_true(_service.promote(_session, 0))
	assert_eq(_session.bench_cards.size(), 0)
	assert_true(_ids_on_board().has("waiting"))

func test_promote_fails_when_board_is_full() -> void:
	for i in 13:
		_service.acquire(_session, "b%d" % i)
	assert_false(_service.promote(_session, 0), "命盘满时只能 swap，不能 promote")

func test_demote_moves_board_card_to_bench() -> void:
	_service.acquire(_session, "a")
	assert_true(_service.demote(_session, 0))
	assert_eq(_session.board_cards.size(), 0)
	assert_eq(_session.bench_cards.size(), 1)

func test_demote_fails_when_bench_is_full() -> void:
	for i in 18:
		_service.acquire(_session, "b%d" % i)
	assert_false(_service.demote(_session, 0))

# -- 阶段边界 ----------------------------------------------------------------

func test_end_stage_clears_one_star_cards_only() -> void:
	_token("crayon", "childhood", "art", "legacy_art_1")
	_token("legacy_art_1", "", "art", "legacy_art_2", true)
	_session.board_cards.append(CardInstanceScript.new("crayon", 1))
	_session.board_cards.append(CardInstanceScript.new("crayon", 2))
	var ascensions: Array = _service.end_stage(_session, _tokens)
	assert_eq(ascensions.size(), 0, "没练满就没有传承")
	assert_eq(_ids_on_board(), ["crayon"], "一星散牌带不走，升过星的留下")
	assert_eq(int(_session.board_cards[0].star), 2, "留下的是那张二星，不是被清掉的一星")

func test_upgraded_cards_survive_the_stage_wipe() -> void:
	# 二星是三张牌换来的。让它在阶段边界上蒸发，等于逼玩家在阶段末停手不合。
	_token("crayon", "childhood", "art", "legacy_art_1")
	_token("playmate", "childhood", "social", "legacy_social_1")
	_session.board_cards.append(CardInstanceScript.new("crayon", 2))
	_session.board_cards.append(CardInstanceScript.new("playmate", 1))
	_service.end_stage(_session, _tokens)
	assert_eq(_ids_on_board(), ["crayon"])

func test_max_star_that_cannot_ascend_is_kept_not_dropped() -> void:
	# 满星但同领域已封顶：升不了格，但它仍然是升过星的，不该被顺手丢掉。
	_token("solo_show", "midlife", "art", "legacy_art_1")
	_token("legacy_art_3", "", "art", "", true)
	_session.legacy_domains["art"] = 3
	_session.board_cards.append(CardInstanceScript.new("legacy_art_3", 1))
	_session.board_cards.append(CardInstanceScript.new("solo_show", 3))
	var ascensions: Array = _service.end_stage(_session, _tokens)
	assert_eq(ascensions.size(), 0, "封顶后不再产出")
	assert_eq(_ids_on_board(), ["legacy_art_3", "solo_show"], "升不了格也留得下")

func test_carried_cards_yield_to_legacies_when_capacity_runs_out() -> void:
	# 命盘 12 + 行囊 6 装不下时，先挤掉的必须是最弱的当期二星，不是传承物。
	_token("legacy_art_1", "", "art", "", true)
	_token("weak", "childhood", "art", "")
	_token("strong", "childhood", "art", "")
	_tokens["weak"].base_score = 2
	_tokens["strong"].base_score = 30
	_session.board_cards.append(CardInstanceScript.new("legacy_art_1", 1))
	for _i in 20:
		_session.board_cards.append(CardInstanceScript.new("weak", 2))
	_session.board_cards.append(CardInstanceScript.new("strong", 2))
	_service.end_stage(_session, _tokens)
	var all_ids: Array = []
	for card in _session.all_cards():
		all_ids.append(String(card.definition_id))
	assert_eq(_session.total_card_count(), 18, "命盘 12 + 行囊 6 就是上限")
	assert_true(all_ids.has("legacy_art_1"), "传承物是骨干，最后才被挤")
	assert_true(all_ids.has("strong"), "同为二星，进盘分高的先留")

func test_end_stage_ascends_max_star_card() -> void:
	_token("crayon", "childhood", "art", "legacy_art_1")
	_token("legacy_art_1", "", "art", "legacy_art_2", true)
	_session.board_cards.append(CardInstanceScript.new("crayon", 3))
	var ascensions: Array = _service.end_stage(_session, _tokens)
	assert_eq(ascensions.size(), 1)
	assert_eq(String(ascensions[0]["into"]), "legacy_art_1")
	assert_eq(int(ascensions[0]["ring"]), 1)
	assert_eq(_ids_on_board(), ["legacy_art_1"], "满星者进化成传承物留在命盘")
	assert_eq(int(_session.legacy_domains["art"]), 1)

func test_legacy_cards_survive_later_stages() -> void:
	_token("legacy_art_1", "", "art", "legacy_art_2", true)
	_session.board_cards.append(CardInstanceScript.new("legacy_art_1", 1))
	_service.end_stage(_session, _tokens)
	assert_eq(_ids_on_board(), ["legacy_art_1"], "传承物不属于任何阶段，不会被清空带走")

func test_second_ascension_upgrades_the_existing_legacy() -> void:
	# 链式进化：同领域的第二次建树不是再来一件一环，而是把手上那件升格。
	# 否则一条领域线会在命盘上占越来越多格。
	_token("sketchbook", "adolescence", "art", "legacy_art_1")
	_token("legacy_art_1", "", "art", "legacy_art_2", true)
	_token("legacy_art_2", "", "art", "legacy_art_3", true)
	_session.legacy_domains["art"] = 1
	_session.board_cards.append(CardInstanceScript.new("legacy_art_1", 1))
	_session.board_cards.append(CardInstanceScript.new("sketchbook", 3))
	var ascensions: Array = _service.end_stage(_session, _tokens)
	assert_eq(_ids_on_board(), ["legacy_art_2"], "一条领域线永远只占一格，越走越粗")
	assert_eq(int(ascensions[0]["ring"]), 2)
	assert_eq(int(_session.legacy_domains["art"]), 2)

func test_chain_stops_at_the_capped_ring() -> void:
	# 三环封顶：再建树也不产出新东西，也不该退回去新起一条一环链。
	_token("solo_show", "midlife", "art", "legacy_art_1")
	_token("legacy_art_3", "", "art", "", true)
	_session.legacy_domains["art"] = 3
	_session.board_cards.append(CardInstanceScript.new("legacy_art_3", 1))
	_session.board_cards.append(CardInstanceScript.new("solo_show", 3))
	var ascensions: Array = _service.end_stage(_session, _tokens)
	assert_eq(ascensions.size(), 0, "封顶后不再产出")
	assert_false(_ids_on_board().has("legacy_art_1"), "不该多出一件一环传承物")

func test_one_stage_advances_a_domain_by_at_most_one_ring() -> void:
	# 同一阶段两张同领域满星，也只前进一环——不然一个阶段就能走完整条链。
	_token("crayon", "childhood", "art", "legacy_art_1")
	_token("nursery_song", "childhood", "art", "legacy_art_1")
	_token("legacy_art_1", "", "art", "legacy_art_2", true)
	_session.board_cards.append(CardInstanceScript.new("crayon", 3))
	_session.board_cards.append(CardInstanceScript.new("nursery_song", 3))
	var ascensions: Array = _service.end_stage(_session, _tokens)
	assert_eq(ascensions.size(), 1)
	assert_eq(int(_session.legacy_domains["art"]), 1)
	assert_eq(_ids_on_board(), ["legacy_art_1", "nursery_song"],
		"没轮到升格的那张满星留在手上，等下个阶段再建树")

func test_different_domains_ascend_independently() -> void:
	_token("crayon", "childhood", "art", "legacy_art_1")
	_token("running", "childhood", "sport", "legacy_sport_1")
	_token("legacy_art_1", "", "art", "", true)
	_token("legacy_sport_1", "", "sport", "", true)
	_session.board_cards.append(CardInstanceScript.new("crayon", 3))
	_session.board_cards.append(CardInstanceScript.new("running", 3))
	var ascensions: Array = _service.end_stage(_session, _tokens)
	assert_eq(ascensions.size(), 2, "两个领域各建各的树")
	assert_eq(_ids_on_board(), ["legacy_art_1", "legacy_sport_1"])

func test_acquire_and_swap_reject_null_session() -> void:
	assert_false(_service.acquire(null, "abacus"))
	assert_false(_service.swap(null, 0, 0))
	assert_false(_service.has_room(null))
