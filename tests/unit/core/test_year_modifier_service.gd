# YearModifierService 契约：四路来源（生肖年度规则 / 六维 / 道具 / 本命年）
# 折算成一个 YearModifiers。
#
# 关键约束是**加法叠加**：四路之间百分比相加、不连乘。连乘会让来源之间指数耦合，
# 调一个数牵动其余三个，平衡表就没法维护了。
extends GutTest

const YearModifierServiceScript := preload("res://scripts/core/services/year_modifier_service.gd")
const RunSessionScript := preload("res://autoload/run_session.gd")

var _service
var _session

func before_each() -> void:
	_service = YearModifierServiceScript.new()
	_session = RunSessionScript.new()

func _zodiac(rules: Dictionary):
	var def := ZodiacDefinition.new()
	def.id = "test"
	def.display_name = "测"
	def.rule_name = "测·规则"
	for key in rules:
		def.set(String(key), rules[key])
	return def

func _item(id: String, fields: Dictionary) -> Dictionary:
	var def := ItemDefinition.new()
	def.id = id
	def.name = id
	for key in fields:
		def.set(String(key), fields[key])
	return {id: def}

# -- 生肖年度规则 ------------------------------------------------------------

func test_zodiac_rule_maps_onto_modifiers() -> void:
	var mods = _service.build(_session, _zodiac({
		"rule_low_base_threshold": 4, "rule_low_base_bonus": 5,
		"rule_self_percent": 60, "rule_highest_percent": 120,
	}), false, {})
	assert_eq(mods.low_base_threshold, 4)
	assert_eq(mods.low_base_bonus, 5)
	assert_eq(mods.self_percent, 60)
	assert_eq(mods.highest_percent, 120)

func test_null_zodiac_yields_neutral_modifiers() -> void:
	var mods = _service.build(_session, null, false, {})
	assert_eq(mods.self_percent, 0)
	assert_eq(mods.zodiac_percent, 0)
	assert_eq(mods.settle_percent, 0)

func test_rule_name_lands_in_notes_for_ui() -> void:
	var mods = _service.build(_session, _zodiac({}), false, {})
	assert_gt(mods.describe_lines().size(), 0, "玩家要能看到今年按什么规矩算")

# -- 六维 --------------------------------------------------------------------

func test_each_stat_feeds_its_own_channel() -> void:
	_session.set_stat("str", 10)
	_session.set_stat("int", 5)
	_session.set_stat("agi", 2)
	_session.set_stat("end", 8)
	var mods = _service.build(_session, null, false, {})
	var step: int = YearModifierServiceScript.STAT_PERCENT_PER_POINT
	assert_eq(mods.self_percent, 10 * step, "力量 → 自增效果")
	assert_eq(mods.zodiac_percent, 5 * step, "智力 → 同生肖联动")
	assert_eq(mods.neighbor_percent, 2 * step, "敏捷 → 邻接联动")
	@warning_ignore("integer_division")
	var expected_base: int = 8 / YearModifierServiceScript.END_POINTS_PER_BASE
	assert_eq(mods.all_base_bonus, expected_base, "耐力 → 全场基础分")

func test_spirit_and_luck_do_not_touch_cascade() -> void:
	# 精神力走事件系统，运气走抽取与商店。它们进 cascade 会让「今年为什么炸」变得说不清。
	_session.set_stat("spr", 20)
	_session.set_stat("luck", 20)
	var mods = _service.build(_session, null, false, {})
	assert_eq(mods.self_percent, 0)
	assert_eq(mods.zodiac_percent, 0)
	assert_eq(mods.neighbor_percent, 0)
	assert_eq(mods.settle_percent, 0)

# -- 道具 --------------------------------------------------------------------

func test_items_add_their_multipliers() -> void:
	var items := _item("charm", {"settle_percent": 10})
	_session.owned_items["charm"] = 1
	var mods = _service.build(_session, null, false, items)
	assert_eq(mods.settle_percent, 10)

func test_item_stacks_multiply_by_count() -> void:
	var items := _item("charm", {"settle_percent": 10})
	_session.owned_items["charm"] = 3
	var mods = _service.build(_session, null, false, items)
	assert_eq(mods.settle_percent, 30, "同一件买三份就是三倍加成")

func test_unknown_item_id_is_skipped() -> void:
	_session.owned_items["ghost"] = 1
	var mods = _service.build(_session, null, false, {})
	assert_eq(mods.settle_percent, 0)

# -- 本命年 ------------------------------------------------------------------

func test_birth_year_doubles_zodiac_chain_and_lifts_income() -> void:
	var mods = _service.build(_session, null, true, {})
	assert_eq(mods.zodiac_percent, YearModifierServiceScript.BIRTH_YEAR_ZODIAC_PERCENT)
	assert_eq(mods.settle_percent, YearModifierServiceScript.BIRTH_YEAR_SETTLE_PERCENT)

# -- 叠加方式 ----------------------------------------------------------------

func test_sources_stack_additively_not_multiplicatively() -> void:
	# 生肖 +60%、力量 10 点 +30%、道具 +25% → 期望 115%（相加），而不是 1.6×1.3×1.25。
	_session.set_stat("str", 10)
	var items := _item("focus", {"self_percent": 25})
	_session.owned_items["focus"] = 1
	var mods = _service.build(_session, _zodiac({"rule_self_percent": 60}), false, items)
	var expected: int = 60 + 10 * YearModifierServiceScript.STAT_PERCENT_PER_POINT + 25
	assert_eq(mods.self_percent, expected)

func test_item_domain_overrides_zodiac_domain() -> void:
	# 道具是玩家花钱选的，生肖是轮到的。让玩家的选择压过随机。
	var items := _item("study_room", {"domain": "study", "domain_percent": 35})
	_session.owned_items["study_room"] = 1
	var mods = _service.build(_session,
		_zodiac({"rule_domain": "sport", "rule_domain_percent": 60}), false, items)
	assert_eq(mods.domain, "study")
