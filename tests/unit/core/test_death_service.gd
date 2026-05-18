# DeathService 契约：
# - build_report 返回 {cause, age, reason} 字典；不 mutate session
# - Cause 枚举 NATURAL=0, LETHAL_EVENT=1
# - cause_name 把枚举值翻成可读字符串（日志 / UI 用）
extends GutTest

const DeathServiceScript := preload("res://scripts/core/services/death_service.gd")
const RunSessionScript := preload("res://autoload/run_session.gd")

func _make_service():
	return DeathServiceScript.new()

func _make_session():
	return RunSessionScript.new()

func test_cause_enum_has_natural_and_lethal_event() -> void:
	assert_eq(DeathServiceScript.Cause.NATURAL, 0)
	assert_eq(DeathServiceScript.Cause.LETHAL_EVENT, 1)

func test_build_report_returns_cause_age_reason() -> void:
	var session = _make_session()
	session.age = 73
	var report := _make_service().build_report(session, DeathServiceScript.Cause.NATURAL, "lifespan_reached")
	assert_eq(report["cause"], DeathServiceScript.Cause.NATURAL)
	assert_eq(report["age"], 73)
	assert_eq(report["reason"], "lifespan_reached")

func test_build_report_default_reason_is_empty_string() -> void:
	var session = _make_session()
	session.age = 42
	var report := _make_service().build_report(session, DeathServiceScript.Cause.LETHAL_EVENT)
	assert_eq(report["reason"], "")

func test_build_report_does_not_mutate_session() -> void:
	var session = _make_session()
	session.age = 50
	session.sanity = 30
	_make_service().build_report(session, DeathServiceScript.Cause.NATURAL, "natural")
	assert_eq(session.age, 50)
	assert_eq(session.sanity, 30)

func test_build_report_handles_null_session() -> void:
	var report := _make_service().build_report(null, DeathServiceScript.Cause.NATURAL)
	assert_eq(report["age"], 0)
	assert_eq(report["cause"], DeathServiceScript.Cause.NATURAL)

func test_cause_name_for_natural() -> void:
	assert_eq(_make_service().cause_name(DeathServiceScript.Cause.NATURAL), "natural")

func test_cause_name_for_lethal_event() -> void:
	assert_eq(_make_service().cause_name(DeathServiceScript.Cause.LETHAL_EVENT), "lethal_event")

func test_cause_name_for_unknown_value() -> void:
	assert_eq(_make_service().cause_name(99), "unknown")
