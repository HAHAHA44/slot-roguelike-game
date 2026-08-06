# 生肖内容定义：
# - 描述 12 生肖之一在生肖盘上的固定槽位（order 0-11，鼠→猪）。
# - **它还携带一条年度规则**：这个生肖轮值的那一年，整盘按什么规矩算。
#   12 条互不相同、12 年一轮，是玩家提前调整行囊的理由，也是生肖盘唯一的承重结构。
#   见 ADR-0002。
# - 规则做成一组具名旋钮而不是 12 个 effect 子类：规则作用于「整盘」而非某张碎片，
#   effect 那套（有目标、有触发时机）套不上；而具名字段能被 YearModifierService
#   一次性折算成 YearModifiers，调参时所有生肖的强度在同一张表里可比。
# - 纯数据，没有玩法逻辑；查询走 ZodiacService，折算走 YearModifierService。
class_name ZodiacDefinition
extends Resource

@export var id: String = ""
# l10n key, 例如 "content.zodiac.rat.name"
@export var display_name: String = ""
# 0-11，鼠=0, 牛=1, ..., 猪=11
@export var order: int = 0

# -- 年度规则 ----------------------------------------------------------------
# 规则的名字与说明（l10n key）。例如「鼠·囤积」。
@export var rule_name: String = ""
@export var rule_description: String = ""

# 进盘类：基础分 ≤ 阈值的碎片额外 +bonus（鼠·囤积）。阈值 ≤0 表示不启用。
@export var rule_low_base_threshold: int = 0
@export var rule_low_base_bonus: int = 0
# 进盘类：全场每格 +N（猪·丰足）。
@export var rule_all_base_bonus: int = 0
# 进盘类：≥2 星的碎片 +p%（虎·威势）。
@export var rule_star_percent: int = 0
# 进盘类：指定领域的碎片 +p%（鸡·司晨）。
@export var rule_domain: String = ""
@export var rule_domain_percent: int = 0
# 进盘类：偶数槽位 +p%（狗·守夜）。
@export var rule_even_slot_percent: int = 0

# cascade 类：「加自身分」效果 +p%（牛·厚积）。
@export var rule_self_percent: int = 0
# cascade 类：同生肖联动 +p%（蛇·蜕变）。
@export var rule_zodiac_percent: int = 0
# cascade 类：邻接联动 +p%（兔·敏行）。
@export var rule_neighbor_percent: int = 0
# cascade 类：邻接联动半径 +N（马·奔走）。
@export var rule_neighbor_radius_bonus: int = 0

# 收尾类：结算后最高分那格 +p%（龙·腾达）。
@export var rule_highest_percent: int = 0
# 收尾类：结算后最低分那格 +p%（羊·守拙）。
@export var rule_lowest_percent: int = 0
# 收尾类：每累计一次连击给全场 +p%（猴·机变）。
@export var rule_chain_percent: int = 0

func get_display_name() -> String:
	return L10n.text(display_name, display_name)

func get_rule_name() -> String:
	if rule_name.is_empty():
		return ""
	return L10n.text(rule_name, rule_name)

func get_rule_description() -> String:
	if rule_description.is_empty():
		return ""
	return L10n.text(rule_description, rule_description)
