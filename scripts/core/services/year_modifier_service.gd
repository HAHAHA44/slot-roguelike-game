# 年度修正汇总服务：把四路来源折算成一个 YearModifiers。
#
#   当年生肖的年度规则  →  今年整盘按什么规矩算（ADR-0002）
#   六维属性            →  这个人现在多强（前四维的帐篷曲线 = 壮年是强度巅峰）
#   持有的道具          →  这些年攒下了什么乘区
#   本命年              →  12 年一遇的同生肖共鸣爆发
#
# 全部折进同一组旋钮的好处是可解释：玩家问「今年为什么炸这么大」，
# notes 里就是逐条答案，而不是散落在四个服务里的隐形乘区。
#
# 各路修正之间一律**加法叠加**（百分比相加），不是连乘。连乘会让四个来源指数耦合，
# 调一个数牵动其余三个，平衡表没法维护。
class_name YearModifierService
extends RefCounted

const YearModifiersScript := preload("res://scripts/core/value_objects/year_modifiers.gd")
const AttributeServiceScript := preload("res://scripts/core/services/attribute_service.gd")

# 每点属性给对应通道加多少百分比。前四维 40 岁前每年 +1、峰值约 11–13 点，
# 于是壮年大约是 +33%～+39%，明显但不至于压过 build 本身。
const STAT_PERCENT_PER_POINT := 3
# 耐力换算成「全场每格 +N」的比率（每 2 点耐力 +1 分）。
const END_POINTS_PER_BASE := 2
# 本命年：同生肖联动翻倍 + 年收益 ×1.5（fun-axes「本命年高风险高回报」）。
const BIRTH_YEAR_ZODIAC_PERCENT := 100
const BIRTH_YEAR_SETTLE_PERCENT := 50

# 构建当年的修正。zodiac_def 为 null 时跳过年度规则（测试路径用）。
func build(session, zodiac_def, is_birth_year: bool, items: Dictionary) -> YearModifiers:
	var mods := YearModifiersScript.new()
	_apply_zodiac_rule(mods, zodiac_def)
	_apply_stats(mods, session)
	_apply_items(mods, session, items)
	_apply_birth_year(mods, is_birth_year)
	return mods

# -- 生肖年度规则 ------------------------------------------------------------

func _apply_zodiac_rule(mods, zodiac_def) -> void:
	if zodiac_def == null:
		return
	mods.low_base_threshold = int(zodiac_def.rule_low_base_threshold)
	mods.low_base_bonus = int(zodiac_def.rule_low_base_bonus)
	mods.all_base_bonus += int(zodiac_def.rule_all_base_bonus)
	mods.star_percent += int(zodiac_def.rule_star_percent)
	mods.even_slot_percent += int(zodiac_def.rule_even_slot_percent)
	mods.self_percent += int(zodiac_def.rule_self_percent)
	mods.zodiac_percent += int(zodiac_def.rule_zodiac_percent)
	mods.neighbor_percent += int(zodiac_def.rule_neighbor_percent)
	mods.neighbor_radius_bonus += int(zodiac_def.rule_neighbor_radius_bonus)
	mods.highest_percent += int(zodiac_def.rule_highest_percent)
	mods.lowest_percent += int(zodiac_def.rule_lowest_percent)
	mods.chain_percent += int(zodiac_def.rule_chain_percent)
	# 领域加成来自生肖时，领域名也由生肖指定；道具那边会二次覆盖（见 _apply_items）。
	if int(zodiac_def.rule_domain_percent) != 0 and not String(zodiac_def.rule_domain).is_empty():
		mods.domain = String(zodiac_def.rule_domain)
		mods.domain_percent += int(zodiac_def.rule_domain_percent)
	var rule_name := String(zodiac_def.get_rule_name())
	if not rule_name.is_empty():
		mods.notes.append(rule_name)

# -- 六维 --------------------------------------------------------------------

# 力量→自增效果、智力→同生肖联动、敏捷→邻接联动、耐力→全场基础分。
# 精神力走事件系统，运气走抽取与商店，都不在 cascade 里。
func _apply_stats(mods, session) -> void:
	if session == null:
		return
	var strength: int = session.stat("str")
	var intellect: int = session.stat("int")
	var agility: int = session.stat("agi")
	var endurance: int = session.stat("end")
	mods.self_percent += strength * STAT_PERCENT_PER_POINT
	mods.zodiac_percent += intellect * STAT_PERCENT_PER_POINT
	mods.neighbor_percent += agility * STAT_PERCENT_PER_POINT
	@warning_ignore("integer_division")
	var endurance_bonus: int = endurance / END_POINTS_PER_BASE
	mods.all_base_bonus += endurance_bonus
	if strength + intellect + agility + endurance > 0:
		mods.notes.append(L10n.format_text("ui.year.mods.stats",
			{"str": strength, "int": intellect, "agi": agility, "end": endurance},
			"六维：力%d 智%d 敏%d 耐%d" % [strength, intellect, agility, endurance]))

# -- 道具 --------------------------------------------------------------------

# 道具按持有份数线性叠加（同一件买两份就是两倍加成）。
func _apply_items(mods, session, items: Dictionary) -> void:
	if session == null or items.is_empty():
		return
	for item_id in session.owned_items:
		var def = items.get(String(item_id), null)
		if def == null:
			continue
		var count: int = int(session.owned_items[item_id])
		if count <= 0:
			continue
		mods.settle_percent += int(def.settle_percent) * count
		mods.self_percent += int(def.self_percent) * count
		mods.zodiac_percent += int(def.zodiac_percent) * count
		mods.neighbor_percent += int(def.neighbor_percent) * count
		mods.all_base_bonus += int(def.all_base_bonus) * count
		if int(def.domain_percent) != 0 and not String(def.domain).is_empty():
			# 生肖与道具指定了不同领域时，道具优先——道具是玩家花钱选的，
			# 生肖是轮到的。让玩家的选择压过随机，是这个游戏一贯的取向。
			mods.domain = String(def.domain)
			mods.domain_percent += int(def.domain_percent) * count
	if not session.owned_items.is_empty():
		mods.notes.append(L10n.format_text("ui.year.mods.items",
			{"count": session.owned_items.size()},
			"道具 %d 件" % session.owned_items.size()))

# -- 本命年 ------------------------------------------------------------------

func _apply_birth_year(mods, is_birth_year: bool) -> void:
	if not is_birth_year:
		return
	mods.zodiac_percent += BIRTH_YEAR_ZODIAC_PERCENT
	mods.settle_percent += BIRTH_YEAR_SETTLE_PERCENT
	mods.notes.append(L10n.text("ui.year.mods.birth_year", "本命年：同生肖联动翻倍，年收益 ×1.5"))
