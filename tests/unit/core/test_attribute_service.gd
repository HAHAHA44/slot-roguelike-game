# AttributeService 契约：
# - 出生把 10 点分配到六维；40 岁前后年度漂移 ±1 只落在前 4 维；
#   运气整局恒定、精神力不随年龄漂移、属性永不为负。
# 断言不变量（总和 / 落点 / 非负）而非具体随机值，与 test_board_reshuffles_each_year 同风格。
extends GutTest

const AttributeServiceScript := preload("res://scripts/core/services/attribute_service.gd")
const RunSessionScript := preload("res://autoload/run_session.gd")

var _service

func before_each() -> void:
	_service = AttributeServiceScript.new()

func _new_session():
	return RunSessionScript.new()

func _sum(session) -> int:
	var total := 0
	for key in AttributeServiceScript.ORDERED_KEYS:
		total += _service.get_value(session, key)
	return total

func test_roll_initial_distributes_ten_points_over_six_keys() -> void:
	var session = _new_session()
	_service.roll_initial(session)
	assert_eq(_sum(session), AttributeServiceScript.INITIAL_POINTS, "六维总和应恰为 10")
	for key in AttributeServiceScript.ORDERED_KEYS:
		assert_true(session.stats.has(key), "应有键 %s" % key)
		assert_gte(_service.get_value(session, key), 0, "%s 不应为负" % key)

func test_drift_before_forty_adds_one_to_physical_only() -> void:
	var session = _new_session()
	_service.roll_initial(session)
	var luck_before: int = _service.get_value(session, AttributeServiceScript.LUCK_KEY)
	var spirit_before: int = _service.get_value(session, AttributeServiceScript.SPIRIT_KEY)
	var before := _sum(session)
	var result: Dictionary = _service.apply_yearly_drift(session, 20)
	assert_eq(_sum(session), before + 1, "<40 漂移应让总和 +1")
	assert_eq(int(result["delta"]), 1)
	assert_has(AttributeServiceScript.PHYSICAL_KEYS, result["key"], "只加前 4 维")
	assert_eq(_service.get_value(session, AttributeServiceScript.LUCK_KEY), luck_before, "运气不动")
	assert_eq(_service.get_value(session, AttributeServiceScript.SPIRIT_KEY), spirit_before,
		"精神力不随年龄漂移")

func test_drift_at_forty_subtracts_one_from_physical() -> void:
	var session = _new_session()
	# 手动铺一个前 4 维都有值的局面，保证有得减。
	for pkey in AttributeServiceScript.PHYSICAL_KEYS:
		session.stats[pkey] = 3
	session.stats[AttributeServiceScript.LUCK_KEY] = 2
	var before := _sum(session)
	var result: Dictionary = _service.apply_yearly_drift(session, 40)
	assert_eq(_sum(session), before - 1, ">=40 漂移应让总和 -1")
	assert_eq(int(result["delta"]), -1)
	assert_has(AttributeServiceScript.PHYSICAL_KEYS, result["key"])

func test_drift_noop_when_physical_all_zero() -> void:
	var session = _new_session()
	for key in AttributeServiceScript.ORDERED_KEYS:
		session.stats[key] = 0
	session.stats[AttributeServiceScript.LUCK_KEY] = 5  # 运气有值也不该被减
	var result: Dictionary = _service.apply_yearly_drift(session, 60)
	assert_eq(result.size(), 0, "前 4 维全 0 时应 no-op")
	for pkey in AttributeServiceScript.PHYSICAL_KEYS:
		assert_eq(_service.get_value(session, pkey), 0)
	assert_eq(_service.get_value(session, AttributeServiceScript.LUCK_KEY), 5, "运气不被漂移碰")

func test_long_decline_stays_nonnegative() -> void:
	var session = _new_session()
	_service.roll_initial(session)
	for i in 50:
		_service.apply_yearly_drift(session, 40 + i)
	for key in AttributeServiceScript.ORDERED_KEYS:
		assert_gte(_service.get_value(session, key), 0, "%s 长期衰减后仍不应为负" % key)
