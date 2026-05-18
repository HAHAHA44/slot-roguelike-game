# ZodiacService 契约：
# - 12 生肖按固定顺序（鼠=0, 牛=1, ..., 猪=11）排列在生肖盘上
# - current_year_zodiac(year): 第 year 年的生肖（year mod 12 → 对应 order）
# - is_birth_year(year, zodiac_birth_id): 当年生肖 == 本命生肖
# - reward_slot_index(year): 流动奖励格的槽位 = year mod 12
extends GutTest

const ZodiacDefScript := preload("res://scripts/content/zodiac_definition.gd")
const ZodiacServiceScript := preload("res://scripts/core/services/zodiac_service.gd")

const ZODIAC_ORDER := ["rat", "ox", "tiger", "rabbit", "dragon", "snake",
	"horse", "goat", "monkey", "rooster", "dog", "pig"]

func _make_zodiacs() -> Array:
	var arr: Array = []
	for i in ZODIAC_ORDER.size():
		var z = ZodiacDefScript.new()
		z.id = ZODIAC_ORDER[i]
		z.display_name = "content.zodiac.%s.name" % ZODIAC_ORDER[i]
		z.order = i
		arr.append(z)
	return arr

func _make_service():
	return ZodiacServiceScript.new(_make_zodiacs())

func test_current_year_zodiac_starts_at_rat_for_year_zero() -> void:
	var svc = _make_service()
	assert_eq(svc.current_year_zodiac(0).id, "rat")

func test_current_year_zodiac_cycles_through_12_in_order() -> void:
	var svc = _make_service()
	for i in 12:
		assert_eq(svc.current_year_zodiac(i).id, ZODIAC_ORDER[i],
			"year %d 应当对应 %s" % [i, ZODIAC_ORDER[i]])

func test_current_year_zodiac_wraps_after_year_11() -> void:
	var svc = _make_service()
	assert_eq(svc.current_year_zodiac(12).id, "rat", "年 12 回到鼠")
	assert_eq(svc.current_year_zodiac(13).id, "ox", "年 13 = 牛")
	assert_eq(svc.current_year_zodiac(83).id, ZODIAC_ORDER[83 % 12])

func test_is_birth_year_true_when_current_matches_birth() -> void:
	var svc = _make_service()
	# 虎 = order 2，年 2 / 14 / 26 ... 都应是本命年
	assert_true(svc.is_birth_year(2, "tiger"))
	assert_true(svc.is_birth_year(14, "tiger"))
	assert_true(svc.is_birth_year(26, "tiger"))

func test_is_birth_year_false_when_current_differs() -> void:
	var svc = _make_service()
	assert_false(svc.is_birth_year(0, "tiger"))
	assert_false(svc.is_birth_year(3, "tiger"))

func test_is_birth_year_false_for_unknown_zodiac_id() -> void:
	var svc = _make_service()
	assert_false(svc.is_birth_year(0, ""))
	assert_false(svc.is_birth_year(0, "not_a_zodiac"))

func test_reward_slot_index_equals_year_mod_12() -> void:
	var svc = _make_service()
	assert_eq(svc.reward_slot_index(0), 0)
	assert_eq(svc.reward_slot_index(5), 5)
	assert_eq(svc.reward_slot_index(11), 11)
	assert_eq(svc.reward_slot_index(12), 0)
	assert_eq(svc.reward_slot_index(83), 83 % 12)

func test_get_by_id_returns_zodiac_or_null() -> void:
	var svc = _make_service()
	var z = svc.get_by_id("dragon")
	assert_not_null(z)
	assert_eq(z.order, 4)
	assert_null(svc.get_by_id("phoenix"))

func test_service_requires_all_12_zodiacs_with_unique_orders() -> void:
	# 少一个或重复 order 都应该让构造函数报错（push_error），但服务仍构造成功，
	# 这里只验证：少了一只就拿不到那只
	var partial: Array = []
	for i in 6:
		var z = ZodiacDefScript.new()
		z.id = ZODIAC_ORDER[i]
		z.order = i
		partial.append(z)
	var svc := ZodiacServiceScript.new(partial)
	assert_null(svc.get_by_id("pig"), "未加载的生肖查询应为 null")
