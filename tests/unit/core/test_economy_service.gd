# EconomyService 契约：阶段门槛 + 购买力（相对计价）。
#
# 这套设计的全部意义是抗通胀：年收益因 percent 复利指数增长，
# 固定标价的商店到中后期必然「全都买得起」。让门槛兼任计价基准之后，
# 绝对数字可以炸到七位，而购买力全程大致恒定。
extends GutTest

const EconomyServiceScript := preload("res://scripts/core/services/economy_service.gd")
const RunSessionScript := preload("res://autoload/run_session.gd")

var _service
var _session

func before_each() -> void:
	_service = EconomyServiceScript.new()
	_session = RunSessionScript.new()

# -- 门槛曲线 ----------------------------------------------------------------

func test_threshold_grows_with_stage() -> void:
	var previous := 0
	for order in 7:
		var threshold: int = _service.threshold_for_stage(order)
		assert_gt(threshold, previous, "阶段 %d 的门槛应高于上一阶段" % order)
		previous = threshold

func test_threshold_growth_is_exponential_not_linear() -> void:
	# 线性门槛会被指数增长的年收益迅速甩开，中后期考核形同虚设。
	var first: int = _service.threshold_for_stage(0)
	var last: int = _service.threshold_for_stage(6)
	assert_gt(float(last) / float(first), 100.0, "七个阶段跨越应在两个数量级以上")

func test_negative_stage_is_clamped() -> void:
	assert_eq(_service.threshold_for_stage(-3), _service.threshold_for_stage(0))

# -- 购买力 ------------------------------------------------------------------

func test_purchasing_power_is_income_over_threshold() -> void:
	assert_almost_eq(_service.purchasing_power(120, 120), 1.0, 0.001)
	assert_almost_eq(_service.purchasing_power(60, 120), 0.5, 0.001)

func test_purchasing_power_stays_flat_as_numbers_explode() -> void:
	# 同样「刚好达标」的一年，在童年和暮年应换到差不多的东西。
	# 这条一红就说明相对计价失效了。
	var early: float = _service.purchasing_power(_service.threshold_for_stage(0),
		_service.threshold_for_stage(0))
	var late: float = _service.purchasing_power(_service.threshold_for_stage(6),
		_service.threshold_for_stage(6))
	assert_almost_eq(early, late, 0.001)

func test_purchasing_power_is_capped() -> void:
	# 封的是兑换率，不是分数本身——fun-axes 禁止分数封顶，不禁止封兑换率。
	var huge: float = _service.purchasing_power(999999999, 100)
	assert_almost_eq(huge, EconomyServiceScript.MAX_PURCHASING_POWER, 0.001)

func test_zero_threshold_does_not_divide_by_zero() -> void:
	assert_almost_eq(_service.purchasing_power(500, 0), 0.0, 0.001)

# -- 阶段考核 ----------------------------------------------------------------

func test_review_uses_the_final_year_not_the_sum() -> void:
	# 用累计会奖励「活得久」；用最后一年才反映 build 强度，
	# 而且命盘在阶段末最满，语义上就是「这十二年练出的成果」。
	_session.stage_income = [10, 10, 10, 999999]
	var review: Dictionary = _service.stage_review(_session, 0)
	assert_eq(int(review["income"]), 999999)
	assert_true(bool(review["passed"]))

func test_review_fails_when_final_year_misses() -> void:
	_session.stage_income = [999999, 1]
	var review: Dictionary = _service.stage_review(_session, 0)
	assert_eq(int(review["income"]), 1, "前面炸得再大也救不了收尾那年")
	assert_false(bool(review["passed"]))

func test_review_on_empty_history_fails_safely() -> void:
	var review: Dictionary = _service.stage_review(_session, 0)
	assert_eq(int(review["income"]), 0)
	assert_false(bool(review["passed"]))

func test_review_reports_ratio_for_ui() -> void:
	var threshold: int = _service.threshold_for_stage(0)
	_session.stage_income = [roundi(float(threshold) * 0.5)]
	var review: Dictionary = _service.stage_review(_session, 0)
	assert_almost_eq(float(review["ratio"]), 0.5, 0.02)

func test_review_handles_null_session() -> void:
	var review: Dictionary = _service.stage_review(null, 0)
	assert_eq(int(review["income"]), 0)
	assert_false(bool(review["passed"]))
