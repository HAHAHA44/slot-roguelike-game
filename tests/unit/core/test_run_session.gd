# RunSession 字段契约：
# - 旧 5x5 字段（current_turn / current_score / phase_index / phase_target / token_pool / token_cursor /
#   active_modifiers / operation_history）由 reward_offer / event_draft 等遗留服务测试覆盖，这里不再重复。
# - 本文件锁定 M0 新增的人生模拟字段及其 to_dict / from_dict 往返。
extends GutTest

const RunSessionScript := preload("res://autoload/run_session.gd")

func test_defaults_for_life_sim_fields() -> void:
	var session: RunSession = RunSessionScript.new()
	assert_eq(session.age, 0, "age 默认 0")
	assert_eq(session.lifespan, 0, "lifespan 默认 0（由出生流程设置）")
	assert_eq(session.sanity, 50, "sanity 默认 50（中段）")
	assert_eq(session.zodiac_birth, "", "zodiac_birth 默认空（由出生流程设置）")
	assert_eq(session.stage_idx, 0, "stage_idx 默认 0（童年）")
	assert_eq(session.karma_in_run, 0, "karma_in_run 默认 0")
	assert_true(session.stats is Dictionary, "stats 必须是 Dictionary")
	assert_true(session.stats.is_empty(), "stats 默认空")

func test_to_dict_includes_life_sim_fields() -> void:
	var session: RunSession = RunSessionScript.new()
	session.age = 17
	session.lifespan = 82
	session.sanity = 35
	session.zodiac_birth = "tiger"
	session.stage_idx = 1
	session.karma_in_run = -3
	session.stats = {"int": 4, "body": 2, "charm": 1, "wealth": 0}
	var data := session.to_dict()
	assert_eq(int(data.get("age", -1)), 17)
	assert_eq(int(data.get("lifespan", -1)), 82)
	assert_eq(int(data.get("sanity", -1)), 35)
	assert_eq(String(data.get("zodiac_birth", "")), "tiger")
	assert_eq(int(data.get("stage_idx", -1)), 1)
	assert_eq(int(data.get("karma_in_run", -99)), -3)
	assert_eq(data.get("stats", {}).get("int", -1), 4)

func test_from_dict_roundtrips_life_sim_fields() -> void:
	var original: RunSession = RunSessionScript.new()
	original.age = 60
	original.lifespan = 95
	original.sanity = 12
	original.zodiac_birth = "snake"
	original.stage_idx = 5
	original.karma_in_run = 12
	original.stats = {"int": 9, "body": 1, "charm": 5, "wealth": 7}
	var restored := RunSessionScript.from_dict(original.to_dict())
	assert_eq(restored.age, 60)
	assert_eq(restored.lifespan, 95)
	assert_eq(restored.sanity, 12)
	assert_eq(restored.zodiac_birth, "snake")
	assert_eq(restored.stage_idx, 5)
	assert_eq(restored.karma_in_run, 12)
	assert_eq(restored.stats, {"int": 9, "body": 1, "charm": 5, "wealth": 7})

func test_sanity_clamps_at_construction_bounds() -> void:
	# RunSession 自身不做约束（约束属于 SanityService 的领域），
	# 但 from_dict 必须接受 0/100 边界值不报错。
	var data := {
		"schema_version": 1,
		"age": 0,
		"sanity": 0,
		"lifespan": 0,
		"zodiac_birth": "",
		"stage_idx": 0,
		"karma_in_run": 0,
		"stats": {},
	}
	var s := RunSessionScript.from_dict(data)
	assert_eq(s.sanity, 0)
	data["sanity"] = 100
	var s2 := RunSessionScript.from_dict(data)
	assert_eq(s2.sanity, 100)

func test_stats_dict_is_independent_after_roundtrip() -> void:
	var session: RunSession = RunSessionScript.new()
	session.stats = {"int": 1}
	var restored := RunSessionScript.from_dict(session.to_dict())
	restored.stats["int"] = 999
	assert_eq(session.stats["int"], 1, "from_dict 必须深拷贝 stats，不共享引用")
