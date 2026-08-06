# SpiritService 契约：精神力是六维之一（stats["spr"]），不是独立状态条。
# 它分三档，同时控制转折年密度与恶性/致死事件权重。
extends GutTest

const SpiritServiceScript := preload("res://scripts/core/services/spirit_service.gd")
const RunSessionScript := preload("res://autoload/run_session.gd")

var _service
var _session

func before_each() -> void:
	_service = SpiritServiceScript.new()
	_session = RunSessionScript.new()

func test_reads_from_the_six_stat_dictionary() -> void:
	# 并轨的核心：没有 session.sanity 这个字段了，精神力就住在六维里。
	_session.set_stat("spr", 7)
	assert_eq(_service.value(_session), 7)

func test_buckets_split_high_mid_low() -> void:
	assert_eq(_service.bucket_of(SpiritServiceScript.MAX_VALUE), "high")
	assert_eq(_service.bucket_of(SpiritServiceScript.DEFAULT_LOW), "low")
	assert_eq(_service.bucket_of(SpiritServiceScript.DEFAULT_LOW + 1), "mid")
	assert_eq(_service.bucket_of(SpiritServiceScript.DEFAULT_HIGH), "high")

func test_birth_baseline_lands_in_mid_or_better() -> void:
	# 若不给出生基线，六维每维期望才 1.7 点，所有人一出生就在「低精神」档，
	# 死亡轮盘从童年就开着。这条断言锁住那个修正。
	assert_ne(_service.bucket_of(SpiritServiceScript.BIRTH_BASELINE), "low",
		"出生基线必须让新生儿脱离低精神档")

func test_add_clamps_to_range() -> void:
	_service.set_value(_session, SpiritServiceScript.MAX_VALUE)
	assert_eq(_service.add(_session, 5), SpiritServiceScript.MAX_VALUE, "不该超上限")
	_service.set_value(_session, 1)
	assert_eq(_service.add(_session, -10), SpiritServiceScript.MIN_VALUE, "不该跌破 0")

func test_add_writes_back_into_stats() -> void:
	_service.set_value(_session, 5)
	_service.add(_session, 2)
	assert_eq(_session.stat("spr"), 7, "改动必须落到六维上，UI 才看得到")

func test_set_value_clamps() -> void:
	assert_eq(_service.set_value(_session, 999), SpiritServiceScript.MAX_VALUE)
	assert_eq(_service.set_value(_session, -999), SpiritServiceScript.MIN_VALUE)

func test_bucket_of_session_matches_value() -> void:
	_service.set_value(_session, SpiritServiceScript.DEFAULT_LOW)
	assert_eq(_service.bucket(_session), "low")

func test_misconfigured_thresholds_fall_back_to_defaults() -> void:
	var service = SpiritServiceScript.new(2, 8)   # high <= low
	assert_eq(service.high_threshold(), SpiritServiceScript.DEFAULT_HIGH)
	assert_eq(service.low_threshold(), SpiritServiceScript.DEFAULT_LOW)

func test_null_session_reads_zero() -> void:
	assert_eq(_service.value(null), 0)
