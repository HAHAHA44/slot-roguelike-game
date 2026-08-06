# DraftService 契约：三选一投注池。
#
# 最要紧的一条是**加权**：不加权时一阶段（12 次抽取）拿到同名碎片的期望只有 2.75 张，
# 连三张一合都够不着，三合一整套机制就是死的。所以「已持有加倍」不是调味，是前提。
extends GutTest

const DraftServiceScript := preload("res://scripts/core/services/draft_service.gd")
const RunSessionScript := preload("res://autoload/run_session.gd")
const CardInstanceScript := preload("res://scripts/core/value_objects/card_instance.gd")

var _service
var _session
var _tokens: Dictionary

func before_each() -> void:
	_service = DraftServiceScript.new()
	_session = RunSessionScript.new()
	_tokens = {}

func _token(id: String, stage_id: String, rarity: String = "Common",
		domain: String = "", weight: float = 1.0, is_legacy: bool = false) -> void:
	var def := TokenDefinition.new()
	def.id = id
	def.name = id
	def.stage_id = stage_id
	def.rarity = rarity
	def.domain = domain
	def.draft_weight = weight
	def.is_legacy = is_legacy
	_tokens[id] = def

# id 前缀带上阶段名，否则两次调用会互相覆盖（同名 id 后写的赢）。
func _stage_pool(count: int, stage_id: String = "childhood") -> void:
	for i in count:
		_token("%s_t%d" % [stage_id, i], stage_id)

# -- 基本形状 ----------------------------------------------------------------

func test_offer_has_three_distinct_candidates() -> void:
	_stage_pool(8)
	var offer: Array = _service.roll_offer(_session, _tokens, "childhood")
	assert_eq(offer.size(), 3)
	assert_eq(offer.size(), _unique(offer).size(), "三张候选不该重复")

func test_offer_shrinks_when_pool_is_tiny() -> void:
	_stage_pool(2)
	assert_eq(_service.roll_offer(_session, _tokens, "childhood").size(), 2)

func test_empty_pool_yields_empty_offer() -> void:
	assert_eq(_service.roll_offer(_session, _tokens, "childhood").size(), 0)

# -- 阶段分池 ----------------------------------------------------------------

func test_only_current_stage_cards_appear() -> void:
	_stage_pool(6, "childhood")
	_stage_pool(6, "twilight")
	for _try in 30:
		for id in _service.roll_offer(_session, _tokens, "childhood"):
			assert_eq(String(_tokens[id].stage_id), "childhood",
				"投注池只装当前阶段的碎片——分池是三合一成立的前提")

func test_legacy_and_zero_weight_cards_never_appear() -> void:
	_stage_pool(4)
	_token("legacy_art_1", "", "Legendary", "art", 0.0, true)
	_token("mundane", "", "Common", "", 0.0)
	for _try in 30:
		for id in _service.roll_offer(_session, _tokens, "childhood"):
			assert_ne(id, "legacy_art_1", "传承物只能靠练满星换来，不能抽到")
			assert_ne(id, "mundane", "补位碎片不进投注池")

# -- 加权：已持有 ------------------------------------------------------------

func test_owned_cards_show_up_far_more_often() -> void:
	# 这是三合一的命脉。加权失效时本测试会红，而不是等到玩家发现凑不齐星。
	_stage_pool(12)
	_session.board_cards.append(CardInstanceScript.new("childhood_t0"))
	var hits := 0
	var trials := 400
	for _try in trials:
		if _service.roll_offer(_session, _tokens, "childhood").has("childhood_t0"):
			hits += 1
	# 12 种均匀时命中率约 1−(11/12)³ ≈ 23%；已持有加倍后应显著高于它。
	assert_gt(float(hits) / float(trials), 0.30,
		"已持有的碎片没有被加权，凑星会变得不可能")

func test_unowned_cards_still_appear() -> void:
	# 加权不能变成锁死：纯随机位保证永远有陌生选项，也给转型留门。
	_stage_pool(12)
	_session.board_cards.append(CardInstanceScript.new("childhood_t0"))
	var seen: Dictionary = {}
	for _try in 200:
		for id in _service.roll_offer(_session, _tokens, "childhood"):
			seen[id] = true
	assert_gt(seen.size(), 6, "候选不该收敛到只剩已持有的那几张")

# -- 加权：领域传承 ----------------------------------------------------------

func test_legacy_domain_lifts_same_domain_cards() -> void:
	# 传承物反哺投注池，是链式进化从 6.4% 拉到约 15% 的机制。
	for i in 6:
		_token("sport%d" % i, "childhood", "Common", "sport")
	for i in 6:
		_token("study%d" % i, "childhood", "Common", "study")
	_session.legacy_domains["sport"] = 1
	var sport_hits := 0
	var study_hits := 0
	for _try in 300:
		for id in _service.roll_offer(_session, _tokens, "childhood"):
			if String(id).begins_with("sport"):
				sport_hits += 1
			else:
				study_hits += 1
	assert_gt(sport_hits, study_hits, "已建树的领域应该更常出现，链条才接得上")

# -- 稀有度与运气 ------------------------------------------------------------

func test_rare_cards_are_rarer_than_common() -> void:
	for i in 6:
		_token("common%d" % i, "childhood", "Common")
	for i in 6:
		_token("legend%d" % i, "childhood", "Legendary")
	var common_hits := 0
	var legend_hits := 0
	for _try in 300:
		for id in _service.roll_offer(_session, _tokens, "childhood"):
			if String(id).begins_with("common"):
				common_hits += 1
			else:
				legend_hits += 1
	assert_gt(common_hits, legend_hits)

func test_luck_lifts_legendary_odds() -> void:
	for i in 4:
		_token("common%d" % i, "childhood", "Common")
	for i in 4:
		_token("legend%d" % i, "childhood", "Legendary")
	var low_luck: int = _count_legendary(0, 300)
	_session.set_stat("luck", 12)
	var high_luck: int = _count_legendary(12, 300)
	assert_gt(high_luck, low_luck, "运气维应该体现为「更常见到传说」")

func _count_legendary(luck: int, trials: int) -> int:
	_session.set_stat("luck", luck)
	var hits := 0
	for _try in trials:
		for id in _service.roll_offer(_session, _tokens, "childhood"):
			if String(id).begins_with("legend"):
				hits += 1
	return hits

func _unique(values: Array) -> Array:
	var seen: Dictionary = {}
	for v in values:
		seen[v] = true
	return seen.keys()
