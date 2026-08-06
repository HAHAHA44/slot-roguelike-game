# CardInstance 契约：碎片实例 = definition_id + 星级。
# 星级倍率有可计算的下限（合成会空出格子，由补位碎片顶上），本文件把那条推导钉住——
# 数值被随手调低时，测试会指出「这样合成就不划算了」。
extends GutTest

const CardInstanceScript := preload("res://scripts/core/value_objects/card_instance.gd")

func test_defaults_to_one_star() -> void:
	var card = CardInstanceScript.new("abacus")
	assert_eq(card.star, 1)
	assert_almost_eq(card.multiplier(), 1.0, 0.001)
	assert_false(card.is_max_star())

func test_star_is_clamped_into_range() -> void:
	assert_eq(CardInstanceScript.new("x", 0).star, 1, "0 星不存在")
	assert_eq(CardInstanceScript.new("x", 99).star, CardInstanceScript.MAX_STAR)

func test_max_star_is_three() -> void:
	var card = CardInstanceScript.new("x", 3)
	assert_true(card.is_max_star(), "满星才有资格传承")

func test_two_star_beats_the_three_cards_it_consumed() -> void:
	# 三张一星（各占一格）合成一张二星，空出的两格由「凡庸」（base 1）顶上。
	# 所以二星倍率必须 > (3 - 2×1/base) …… 以 base=3 算下限约 2.33。
	assert_gt(CardInstanceScript.STAR_MULTIPLIER[1], 2.33,
		"二星倍率低于这个数，三合一就是净亏，玩家不该被机制惩罚")

func test_max_star_beats_the_six_cards_it_consumed() -> void:
	# 六张一星 → 一张满星 + 五格凡庸，下限约 4.33。
	assert_gt(CardInstanceScript.STAR_MULTIPLIER[2], 4.33,
		"满星倍率低于这个数，专精就不如摊大饼")

func test_max_star_is_meaningfully_better_than_two_star() -> void:
	# 满星达成率只有约 40%（一阶段），回报必须明显拉开档次，
	# 否则玩家没有理由把第二个二星也投进去。
	assert_gt(CardInstanceScript.STAR_MULTIPLIER[2] / CardInstanceScript.STAR_MULTIPLIER[1], 2.0)

func test_duplicate_card_is_a_separate_object() -> void:
	var card = CardInstanceScript.new("abacus", 2)
	var copy = card.duplicate_card()
	copy.star = 3
	assert_eq(card.star, 2, "副本不该与原件共享状态")
	assert_eq(copy.definition_id, "abacus")

func test_roundtrip() -> void:
	var card = CardInstanceScript.new("piggy_bank", 2)
	var restored = CardInstanceScript.from_dict(card.to_dict())
	assert_eq(restored.definition_id, "piggy_bank")
	assert_eq(restored.star, 2)

func test_make_many_builds_one_star_cards() -> void:
	var cards: Array = CardInstanceScript.make_many(["a", "b", "c"])
	assert_eq(cards.size(), 3)
	for card in cards:
		assert_eq(card.star, 1)

func test_make_many_can_set_star() -> void:
	var cards: Array = CardInstanceScript.make_many(["a"], 2)
	assert_eq(cards[0].star, 2)
