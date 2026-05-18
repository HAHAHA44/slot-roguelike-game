# SanityService 契约：
# - 精神力恒在 [0, 100]
# - bucket() 返回 "high"/"mid"/"low"，阈值在 _init 注入，默认 70 / 30
# - add / set_value 直接 mutate RunSession.sanity 并返回钳制后值
extends GutTest

const SanityServiceScript := preload("res://scripts/core/services/sanity_service.gd")
const RunSessionScript := preload("res://autoload/run_session.gd")

func _make_service():
	return SanityServiceScript.new()

func _make_session():
	return RunSessionScript.new()

func test_clamp_value_floors_negative_to_zero() -> void:
	assert_eq(_make_service().clamp_value(-100), 0)

func test_clamp_value_ceils_above_hundred_to_hundred() -> void:
	assert_eq(_make_service().clamp_value(250), 100)

func test_clamp_value_passes_through_in_range() -> void:
	assert_eq(_make_service().clamp_value(42), 42)

func test_bucket_low_at_and_below_threshold() -> void:
	var svc = _make_service()
	assert_eq(svc.bucket(0), "low")
	assert_eq(svc.bucket(30), "low", "30 默认为 low 上界")

func test_bucket_high_at_and_above_threshold() -> void:
	var svc = _make_service()
	assert_eq(svc.bucket(70), "high", "70 默认为 high 下界")
	assert_eq(svc.bucket(100), "high")

func test_bucket_mid_strictly_between() -> void:
	var svc = _make_service()
	assert_eq(svc.bucket(31), "mid")
	assert_eq(svc.bucket(50), "mid")
	assert_eq(svc.bucket(69), "mid")

func test_bucket_clamps_input_before_classifying() -> void:
	var svc = _make_service()
	assert_eq(svc.bucket(-10), "low", "负数先钳到 0 再分档")
	assert_eq(svc.bucket(200), "high", "超 100 先钳到 100 再分档")

func test_custom_thresholds_via_init() -> void:
	var svc = SanityServiceScript.new(80, 20)
	assert_eq(svc.bucket(20), "low")
	assert_eq(svc.bucket(50), "mid")
	assert_eq(svc.bucket(80), "high")

func test_bad_thresholds_fall_back_to_default() -> void:
	# high 应该 > low；倒置时回退到 70 / 30
	var svc = SanityServiceScript.new(20, 80)
	assert_eq(svc.high_threshold(), 70)
	assert_eq(svc.low_threshold(), 30)

func test_add_mutates_session_and_returns_new_value() -> void:
	var session = _make_session()
	session.sanity = 50
	var result := _make_service().add(session, 10)
	assert_eq(session.sanity, 60)
	assert_eq(result, 60)

func test_add_clamps_underflow_at_zero() -> void:
	var session = _make_session()
	session.sanity = 10
	var result := _make_service().add(session, -50)
	assert_eq(session.sanity, 0)
	assert_eq(result, 0)

func test_add_clamps_overflow_at_hundred() -> void:
	var session = _make_session()
	session.sanity = 90
	var result := _make_service().add(session, 50)
	assert_eq(session.sanity, 100)
	assert_eq(result, 100)

func test_set_value_clamps_and_mutates() -> void:
	var session = _make_session()
	var svc = _make_service()
	assert_eq(svc.set_value(session, 150), 100)
	assert_eq(session.sanity, 100)
	assert_eq(svc.set_value(session, -5), 0)
	assert_eq(session.sanity, 0)
