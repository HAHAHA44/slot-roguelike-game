# KarmaService 契约：
# - add_to_run 累加 session.karma_in_run，返回新值
# - consume 返回当前 karma_in_run 快照并把字段清零
# - current 只读查询，不 mutate
extends GutTest

const KarmaServiceScript := preload("res://scripts/core/services/karma_service.gd")
const RunSessionScript := preload("res://autoload/run_session.gd")

func _make_service():
	return KarmaServiceScript.new()

func _make_session():
	return RunSessionScript.new()

func test_add_to_run_accumulates_positive() -> void:
	var session = _make_session()
	var svc = _make_service()
	assert_eq(svc.add_to_run(session, 5), 5)
	assert_eq(svc.add_to_run(session, 3), 8)

func test_add_to_run_handles_negative_delta() -> void:
	var session = _make_session()
	var svc = _make_service()
	svc.add_to_run(session, 10)
	assert_eq(svc.add_to_run(session, -15), -5)

func test_add_to_run_mutates_session_field() -> void:
	var session = _make_session()
	_make_service().add_to_run(session, 7)
	assert_eq(session.karma_in_run, 7)

func test_consume_returns_current_and_clears() -> void:
	var session = _make_session()
	var svc = _make_service()
	svc.add_to_run(session, 42)
	assert_eq(svc.consume(session), 42)
	assert_eq(session.karma_in_run, 0, "consume 后字段清零，转世起点干净")

func test_consume_on_fresh_session_returns_zero() -> void:
	var session = _make_session()
	assert_eq(_make_service().consume(session), 0)

func test_current_is_readonly() -> void:
	var session = _make_session()
	session.karma_in_run = 13
	var svc = _make_service()
	assert_eq(svc.current(session), 13)
	assert_eq(session.karma_in_run, 13, "current 不 mutate")

func test_default_karma_in_run_is_zero() -> void:
	var session = _make_session()
	assert_eq(_make_service().current(session), 0)
