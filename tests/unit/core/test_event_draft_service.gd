# EventDraftService 契约：双层事件（流水年金句 / 转折年弹窗）。
#
# 精神力在这里控制两件事，这是 fun-axes P3 的落点：
#   ① 转折年的触发密度（日子越难，事越多）
#   ② 恶性/致死事件的权重（低精神才抽得到致死）
extends GutTest

const EventDraftServiceScript := preload("res://scripts/core/services/event_draft_service.gd")

var _service
var _events: Dictionary
var _flavor: Dictionary

func before_each() -> void:
	_service = EventDraftServiceScript.new()
	_events = {}
	_flavor = {}

func _event(id: String, kind: String, weights: Dictionary, stage_id: String = "",
		birth_year: bool = false, zodiac_id: String = "") -> void:
	var def := EventDefinition.new()
	def.id = id
	def.name = id
	def.kind = kind
	def.spirit_weights = weights
	def.stage_id = stage_id
	def.birth_year_only = birth_year
	def.zodiac_id = zodiac_id
	_events[id] = def

func _flavor_line(id: String, stage_id: String = "", bucket: String = "") -> void:
	var def := FlavorLineDefinition.new()
	def.id = id
	def.text = id
	def.stage_id = stage_id
	def.spirit_bucket = bucket
	def.weight = 1.0
	_flavor[id] = def

# -- 触发密度 ----------------------------------------------------------------

func test_low_spirit_triggers_more_often_than_high() -> void:
	assert_gt(EventDraftServiceScript.TRIGGER_CHANCE["low"],
		EventDraftServiceScript.TRIGGER_CHANCE["high"],
		"低精神档该更常出事——这是死亡轮盘的第一重含义")

func test_trigger_rate_matches_configured_chance() -> void:
	var hits := 0
	var trials := 2000
	for _try in trials:
		if _service.should_trigger("mid", false):
			hits += 1
	var rate: float = float(hits) / float(trials)
	assert_almost_eq(rate, float(EventDraftServiceScript.TRIGGER_CHANCE["mid"]), 0.05)

func test_trigger_rate_stays_inside_the_time_budget() -> void:
	# 每年 8 秒的预算里，转折年弹窗一次要 10–15 秒。三档都超过 40% 的话，
	# 一局会远超 30 分钟（见 growth-loop-design 第 Q9 条）。
	for bucket in ["high", "mid", "low"]:
		assert_lt(float(EventDraftServiceScript.TRIGGER_CHANCE[bucket]), 0.4,
			"「%s」档的转折年太密，时间预算装不下" % bucket)

func test_birth_year_always_triggers() -> void:
	for _try in 20:
		assert_true(_service.should_trigger("high", true), "12 年一遇的大事不该被概率吃掉")

# -- 精神档加权 --------------------------------------------------------------

func test_benign_dominates_at_high_spirit() -> void:
	_event("good", "benign", {"high": 5.0, "mid": 1.0, "low": 0.2})
	_event("bad", "malign", {"high": 0.1, "mid": 1.0, "low": 5.0})
	var odds: Dictionary = _service.outcome_odds(_events, "childhood", "high", "rat", false)
	assert_gt(float(odds["benign"]), float(odds["malign"]))

func test_malign_dominates_at_low_spirit() -> void:
	_event("good", "benign", {"high": 5.0, "mid": 1.0, "low": 0.2})
	_event("bad", "malign", {"high": 0.1, "mid": 1.0, "low": 5.0})
	var odds: Dictionary = _service.outcome_odds(_events, "childhood", "low", "rat", false)
	assert_gt(float(odds["malign"]), float(odds["benign"]))

func test_lethal_is_impossible_outside_low_spirit() -> void:
	_event("die", "lethal", {"low": 2.0})
	assert_eq(float(_service.outcome_odds(_events, "", "high", "rat", false)["lethal"]), 0.0)
	assert_eq(float(_service.outcome_odds(_events, "", "mid", "rat", false)["lethal"]), 0.0)
	assert_gt(float(_service.outcome_odds(_events, "", "low", "rat", false)["lethal"]), 0.0)

func test_odds_sum_to_one_hundred() -> void:
	# 明牌概率提示直接用这个数上 UI，合计不是 100 就会露馅。
	_event("good", "benign", {"mid": 3.0})
	_event("meh", "neutral", {"mid": 2.0})
	_event("bad", "malign", {"mid": 1.0})
	var odds: Dictionary = _service.outcome_odds(_events, "", "mid", "rat", false)
	var total := 0.0
	for kind in odds:
		total += float(odds[kind])
	assert_almost_eq(total, 100.0, 0.01)

# -- 过滤 --------------------------------------------------------------------

func test_stage_filter_is_respected() -> void:
	_event("kid_only", "neutral", {"mid": 1.0}, "childhood")
	assert_null(_service.draft_event(_events, "twilight", "mid", "rat", false))
	assert_not_null(_service.draft_event(_events, "childhood", "mid", "rat", false))

func test_stageless_events_appear_anywhere() -> void:
	_event("generic", "neutral", {"mid": 1.0}, "")
	assert_not_null(_service.draft_event(_events, "twilight", "mid", "rat", false))

func test_birth_year_pool_is_exclusive_both_ways() -> void:
	# 本命年独占池：本命年只抽本命年事件，平年抽不到它们。
	_event("normal", "neutral", {"mid": 1.0})
	_event("special", "benign", {"mid": 1.0}, "", true)
	assert_eq(String(_service.draft_event(_events, "", "mid", "rat", true).id), "special")
	assert_eq(String(_service.draft_event(_events, "", "mid", "rat", false).id), "normal")

func test_zodiac_filter_is_respected() -> void:
	_event("dragon_only", "neutral", {"mid": 1.0}, "", false, "dragon")
	assert_null(_service.draft_event(_events, "", "mid", "rat", false))
	assert_not_null(_service.draft_event(_events, "", "mid", "dragon", false))

func test_zero_weight_events_are_never_drafted() -> void:
	_event("silent", "neutral", {"high": 1.0})
	assert_null(_service.draft_event(_events, "", "low", "rat", false))

func test_empty_pool_returns_null() -> void:
	assert_null(_service.draft_event(_events, "", "mid", "rat", false))

# -- 流水年金句 --------------------------------------------------------------

func test_flavor_respects_stage_and_bucket() -> void:
	_flavor_line("kid_low", "childhood", "low")
	_flavor_line("old_high", "twilight", "high")
	assert_eq(String(_service.pick_flavor(_flavor, "childhood", "low").id), "kid_low")
	assert_eq(String(_service.pick_flavor(_flavor, "twilight", "high").id), "old_high")

func test_flavor_wildcards_match_anything() -> void:
	_flavor_line("anywhere", "", "")
	assert_not_null(_service.pick_flavor(_flavor, "prime", "mid"))

func test_flavor_returns_null_when_nothing_matches() -> void:
	_flavor_line("kid_only", "childhood", "")
	assert_null(_service.pick_flavor(_flavor, "twilight", "mid"))

func test_flavor_pool_is_empty_safe() -> void:
	assert_null(_service.pick_flavor({}, "childhood", "mid"))
