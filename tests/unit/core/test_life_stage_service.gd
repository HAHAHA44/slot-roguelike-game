# LifeStageService 契约：
# - 7 阶段：童年(0) / 少年(12) / 青年(24) / 壮年(36) / 中年(48) / 老年(60) / 暮年(72)
# - stage_for_age(age) 返回 age >= start_age 的最大阶段
# - 年龄超过 72 一直在暮年（endless 直到死，由 RunScreen 处理）
# - get_by_order 按 order 0-6 取阶段
extends GutTest

const LifeStageServiceScript := preload("res://scripts/core/services/life_stage_service.gd")
const LifeStageDefScript := preload("res://scripts/content/life_stage_definition.gd")

const STAGES := [
	{"id": "childhood", "order": 0, "start_age": 0},
	{"id": "adolescence", "order": 1, "start_age": 12},
	{"id": "youth", "order": 2, "start_age": 24},
	{"id": "prime", "order": 3, "start_age": 36},
	{"id": "midlife", "order": 4, "start_age": 48},
	{"id": "senior", "order": 5, "start_age": 60},
	{"id": "twilight", "order": 6, "start_age": 72},
]

func _make_stages() -> Array:
	var arr: Array = []
	for s in STAGES:
		var def = LifeStageDefScript.new()
		def.id = s["id"]
		def.display_name = "content.life_stage.%s.name" % s["id"]
		def.order = s["order"]
		def.start_age = s["start_age"]
		arr.append(def)
	return arr

func _make_service():
	return LifeStageServiceScript.new(_make_stages())

func test_stage_for_age_zero_is_childhood() -> void:
	assert_eq(_make_service().stage_for_age(0).id, "childhood")

func test_stage_for_age_eleven_still_childhood() -> void:
	assert_eq(_make_service().stage_for_age(11).id, "childhood")

func test_stage_for_age_twelve_is_adolescence() -> void:
	assert_eq(_make_service().stage_for_age(12).id, "adolescence")

func test_stage_for_age_each_boundary() -> void:
	var svc = _make_service()
	assert_eq(svc.stage_for_age(24).id, "youth")
	assert_eq(svc.stage_for_age(36).id, "prime")
	assert_eq(svc.stage_for_age(48).id, "midlife")
	assert_eq(svc.stage_for_age(60).id, "senior")
	assert_eq(svc.stage_for_age(72).id, "twilight")

func test_stage_for_age_in_middle_of_range() -> void:
	var svc = _make_service()
	assert_eq(svc.stage_for_age(30).id, "youth")
	assert_eq(svc.stage_for_age(55).id, "midlife")
	assert_eq(svc.stage_for_age(65).id, "senior")

func test_stage_for_age_stays_twilight_when_very_old() -> void:
	var svc = _make_service()
	assert_eq(svc.stage_for_age(100).id, "twilight")
	assert_eq(svc.stage_for_age(200).id, "twilight", "endless 至寿命耗尽，stage 不再前进")

func test_is_twilight_only_true_at_or_above_seventy_two() -> void:
	var svc = _make_service()
	assert_false(svc.is_twilight(71))
	assert_true(svc.is_twilight(72))
	assert_true(svc.is_twilight(120))

func test_get_by_order_returns_correct_stage() -> void:
	var svc = _make_service()
	assert_eq(svc.get_by_order(0).id, "childhood")
	assert_eq(svc.get_by_order(6).id, "twilight")

func test_get_by_order_returns_null_for_out_of_range() -> void:
	var svc = _make_service()
	assert_null(svc.get_by_order(-1))
	assert_null(svc.get_by_order(7))

func test_negative_age_before_first_stage_returns_null() -> void:
	# 安全网：年龄 < 0 时没有匹配阶段（理论上不该出现，但保险起见）
	var svc = _make_service()
	assert_null(svc.stage_for_age(-1))

func test_partial_stage_set_still_resolves() -> void:
	# 只放前 3 阶段，看 stage_for_age 是否仍返回最近匹配
	var partial: Array = _make_stages().slice(0, 3)  # childhood / adolescence / youth
	var svc = LifeStageServiceScript.new(partial)
	assert_eq(svc.stage_for_age(50).id, "youth", "未加载的阶段不存在时，回退最近一个")
