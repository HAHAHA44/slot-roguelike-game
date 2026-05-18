# AgeService 契约：
# - advance(session) 把 session.age++，返回新值
# - is_natural_death(session) 在 age >= lifespan 且 lifespan>0 时返回 true
# - lifespan=0 视为未设定 → 永远不自然死
extends GutTest

const AgeServiceScript := preload("res://scripts/core/services/age_service.gd")
const RunSessionScript := preload("res://autoload/run_session.gd")

func _make_service():
	return AgeServiceScript.new()

func _make_session():
	return RunSessionScript.new()

func test_advance_increments_age_by_one() -> void:
	var session = _make_session()
	session.age = 10
	_make_service().advance(session)
	assert_eq(session.age, 11)

func test_advance_returns_new_age() -> void:
	var session = _make_session()
	session.age = 0
	assert_eq(_make_service().advance(session), 1)

func test_advance_from_zero_is_one() -> void:
	var session = _make_session()
	assert_eq(_make_service().advance(session), 1)

func test_is_natural_death_true_when_age_equals_lifespan() -> void:
	var session = _make_session()
	session.age = 80
	session.lifespan = 80
	assert_true(_make_service().is_natural_death(session))

func test_is_natural_death_true_when_age_exceeds_lifespan() -> void:
	var session = _make_session()
	session.age = 100
	session.lifespan = 80
	assert_true(_make_service().is_natural_death(session))

func test_is_natural_death_false_below_lifespan() -> void:
	var session = _make_session()
	session.age = 79
	session.lifespan = 80
	assert_false(_make_service().is_natural_death(session))

func test_is_natural_death_false_when_lifespan_is_zero() -> void:
	var session = _make_session()
	session.age = 999
	session.lifespan = 0
	assert_false(_make_service().is_natural_death(session), "lifespan=0 视为未设定，永不自然死")

func test_is_natural_death_false_when_lifespan_negative() -> void:
	var session = _make_session()
	session.age = 50
	session.lifespan = -1
	assert_false(_make_service().is_natural_death(session))
