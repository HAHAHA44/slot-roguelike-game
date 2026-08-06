# RunSession 字段契约：
# - 命盘 / 行囊装 CardInstance（带星级），不是裸 id。
# - 精神力是六维之一（stats["spr"]），没有独立的 sanity 字段——旧的那条状态条已并轨。
# - to_dict / from_dict 必须往返所有字段，且深拷贝（存档不能与运行时共享引用）。
extends GutTest

const RunSessionScript := preload("res://autoload/run_session.gd")
const CardInstanceScript := preload("res://scripts/core/value_objects/card_instance.gd")

func test_defaults() -> void:
	var session = RunSessionScript.new()
	assert_eq(session.age, 0, "age 默认 0")
	assert_eq(session.lifespan, 0, "lifespan 默认 0（由出生流程设置）")
	assert_eq(session.zodiac_birth, "", "zodiac_birth 默认空")
	assert_eq(session.stage_idx, 0, "stage_idx 默认 0（童年）")
	assert_eq(session.karma_in_run, 0)
	assert_eq(session.death_cause, "", "还活着时 death_cause 为空")
	assert_true(session.board_cards.is_empty(), "命盘默认空")
	assert_true(session.bench_cards.is_empty(), "行囊默认空")
	assert_true(session.stats.is_empty(), "六维默认空")

func test_capacities_are_twelve_and_six() -> void:
	assert_eq(RunSessionScript.BOARD_CAPACITY, 12, "命盘恒 12 格（硬约束）")
	assert_eq(RunSessionScript.BENCH_CAPACITY, 6, "行囊 6 格")

func test_board_is_full_at_capacity() -> void:
	var session = RunSessionScript.new()
	for i in RunSessionScript.BOARD_CAPACITY:
		assert_false(session.board_is_full(), "第 %d 张之前命盘不该满" % i)
		session.board_cards.append(CardInstanceScript.new("x"))
	assert_true(session.board_is_full(), "12 张后命盘满")

func test_all_cards_covers_board_and_bench() -> void:
	var session = RunSessionScript.new()
	session.board_cards.append(CardInstanceScript.new("a"))
	session.bench_cards.append(CardInstanceScript.new("b"))
	assert_eq(session.total_card_count(), 2)
	var ids: Array = []
	for card in session.all_cards():
		ids.append(card.definition_id)
	assert_has(ids, "a")
	assert_has(ids, "b")

func test_stat_accessors() -> void:
	var session = RunSessionScript.new()
	assert_eq(session.stat("spr"), 0, "未设置的维返回 0 而不是报错")
	session.set_stat("spr", 7)
	assert_eq(session.stat("spr"), 7)

func test_roundtrip_preserves_everything() -> void:
	var original = RunSessionScript.new()
	original.age = 60
	original.lifespan = 95
	original.stage_idx = 5
	original.zodiac_birth = "snake"
	original.board_cards.append(CardInstanceScript.new("piggy_bank", 2))
	original.bench_cards.append(CardInstanceScript.new("playmate", 1))
	original.stats = {"str": 9, "spr": 6, "luck": 3}
	original.stage_income = [120, 380]
	original.owned_items = {"lucky_charm": 2}
	original.purchasing_power = 1.25
	original.legacy_domains = {"sport": 2}
	original.karma_in_run = 12
	original.death_cause = "natural"

	var restored = RunSessionScript.from_dict(original.to_dict())
	assert_eq(restored.age, 60)
	assert_eq(restored.lifespan, 95)
	assert_eq(restored.stage_idx, 5)
	assert_eq(restored.zodiac_birth, "snake")
	assert_eq(restored.board_cards.size(), 1)
	assert_eq(restored.board_cards[0].definition_id, "piggy_bank")
	assert_eq(restored.board_cards[0].star, 2, "星级必须跟着往返，否则读档会掉星")
	assert_eq(restored.bench_cards.size(), 1)
	assert_eq(restored.stats, {"str": 9, "spr": 6, "luck": 3})
	assert_eq(restored.stage_income, [120, 380])
	assert_eq(restored.owned_items, {"lucky_charm": 2})
	assert_almost_eq(restored.purchasing_power, 1.25, 0.001)
	assert_eq(restored.legacy_domains, {"sport": 2})
	assert_eq(restored.karma_in_run, 12)
	assert_eq(restored.death_cause, "natural")

func test_roundtrip_deep_copies_collections() -> void:
	var session = RunSessionScript.new()
	session.stats = {"str": 1}
	session.owned_items = {"lucky_charm": 1}
	var restored = RunSessionScript.from_dict(session.to_dict())
	restored.stats["str"] = 999
	restored.owned_items["lucky_charm"] = 999
	assert_eq(session.stats["str"], 1, "from_dict 必须深拷贝 stats")
	assert_eq(session.owned_items["lucky_charm"], 1, "from_dict 必须深拷贝 owned_items")

func test_roundtrip_rebuilds_card_objects_not_dicts() -> void:
	var session = RunSessionScript.new()
	session.board_cards.append(CardInstanceScript.new("abacus", 3))
	var restored = RunSessionScript.from_dict(session.to_dict())
	# 存档里存的是字典，读回来必须是 CardInstance——否则结算时 multiplier() 会崩。
	assert_almost_eq(restored.board_cards[0].multiplier(), 7.0, 0.001)
	assert_true(restored.board_cards[0].is_max_star())
