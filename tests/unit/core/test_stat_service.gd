# StatService 契约：
# - session.stats 是任意 key → int 的字典
# - add 累加并返回新值；缺省 key 视为 0
# - set_value 覆盖（不累加）
# - soft_gate 本批二值占位：>= threshold 返 1.0，否则 0.0（M4 改平滑）
extends GutTest

const StatServiceScript := preload("res://scripts/core/services/stat_service.gd")
const RunSessionScript := preload("res://autoload/run_session.gd")

func _make_service():
	return StatServiceScript.new()

func _make_session():
	return RunSessionScript.new()

func test_get_value_returns_zero_for_unknown_key() -> void:
	var session = _make_session()
	assert_eq(_make_service().get_value(session, "int"), 0)

func test_add_creates_key_when_missing() -> void:
	var session = _make_session()
	assert_eq(_make_service().add(session, "int", 5), 5)
	assert_eq(int(session.stats["int"]), 5)

func test_add_accumulates_existing_key() -> void:
	var session = _make_session()
	session.stats["body"] = 3
	assert_eq(_make_service().add(session, "body", 4), 7)

func test_add_handles_negative_delta() -> void:
	var session = _make_session()
	session.stats["charm"] = 10
	assert_eq(_make_service().add(session, "charm", -7), 3)

func test_set_value_overwrites_not_adds() -> void:
	var session = _make_session()
	session.stats["wealth"] = 100
	_make_service().set_value(session, "wealth", 25)
	assert_eq(int(session.stats["wealth"]), 25)

func test_soft_gate_returns_one_when_meeting_threshold() -> void:
	var session = _make_session()
	session.stats["int"] = 10
	assert_eq(_make_service().soft_gate(session, "int", 10), 1.0)

func test_soft_gate_returns_one_when_exceeding_threshold() -> void:
	var session = _make_session()
	session.stats["int"] = 15
	assert_eq(_make_service().soft_gate(session, "int", 10), 1.0)

func test_soft_gate_returns_zero_when_below_threshold() -> void:
	var session = _make_session()
	session.stats["int"] = 5
	assert_eq(_make_service().soft_gate(session, "int", 10), 0.0)

func test_soft_gate_treats_missing_key_as_zero() -> void:
	var session = _make_session()
	assert_eq(_make_service().soft_gate(session, "ghost", 1), 0.0)
