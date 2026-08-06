# 道具内容定义：
# - 道具**不上盘、不参与 cascade**，它提供的是乘区（fun-axes P2：物品用乘法，加法归碎片）。
# - 用年收益在每年的商店购买，**跨阶段累积不清空**——碎片每 12 年洗牌重来，
#   道具是你真正攒下来的东西。这两条时间尺度的分工是整套经济的骨架。
# - 效果统一折算成 YearModifiers 的旋钮（见 YearModifierService.apply_items）。
#   为什么不用 ScriptableEffect：道具的作用是「今年整盘按什么倍率算」，
#   它没有触发时机也没有目标，做成 effect 只会多一层空壳。
# - 标价单位是**阶段门槛的倍数**，不是绝对数字（见 EconomyService 的相对计价）。
class_name ItemDefinition
extends Resource

const ALLOWED_RARITIES := ["Common", "Uncommon", "Rare", "Legendary"]

@export var id: String = ""
# l10n key
@export var name: String = ""
@export var description: String = ""
@export var rarity: String = "Common"
# 领域。与碎片同一套取值；未来的配方合成靠它配对（v1 不做，见设计文档 Q23）。
@export var domain: String = ""

# 售价，单位 = 阶段门槛的倍数。0.5 表示「半年好收成」。
@export var price: float = 0.5
# 最早在第几个人生阶段上架（0=童年）。强力道具后期才出现，构成内容梯度。
@export var min_stage_order: int = 0
# 同一件道具最多持有几份。1 = 唯一。
@export var max_stack: int = 1
# 进商店候选池的相对权重。
@export var shop_weight: float = 1.0

# -- 乘区（全部折进 YearModifiers） ------------------------------------------
# 年收益总额 +p%。最通用的一档，也是「乘法」的主力。
@export var settle_percent: int = 0
# 「加自身分」类效果 +p%。
@export var self_percent: int = 0
# 同生肖联动 +p%。
@export var zodiac_percent: int = 0
# 邻接联动 +p%。
@export var neighbor_percent: int = 0
# 全场每格进盘 +N（少数「垫基数」型道具用）。
@export var all_base_bonus: int = 0
# 指定领域的碎片进盘 +p%（与 domain 配合，做「专精流」道具）。
@export var domain_percent: int = 0

func get_display_name() -> String:
	return L10n.text(name, name)

func get_display_description() -> String:
	return L10n.text(description, description)

func get_display_rarity() -> String:
	return L10n.rarity_name(rarity)

# 一句话机制说明，从字段现算，不写死在文案里（调数值时说明自动跟着变）。
func describe_effect() -> String:
	var parts: Array[String] = []
	if settle_percent != 0:
		parts.append(L10n.format_text("item.effect.settle", {"percent": settle_percent},
			"年收益 +%d%%" % settle_percent))
	if self_percent != 0:
		parts.append(L10n.format_text("item.effect.self", {"percent": self_percent},
			"自增效果 +%d%%" % self_percent))
	if zodiac_percent != 0:
		parts.append(L10n.format_text("item.effect.zodiac", {"percent": zodiac_percent},
			"同生肖联动 +%d%%" % zodiac_percent))
	if neighbor_percent != 0:
		parts.append(L10n.format_text("item.effect.neighbor", {"percent": neighbor_percent},
			"邻接联动 +%d%%" % neighbor_percent))
	if all_base_bonus != 0:
		parts.append(L10n.format_text("item.effect.all_base", {"amount": all_base_bonus},
			"全场每格 +%d" % all_base_bonus))
	if domain_percent != 0 and not domain.is_empty():
		var domain_name := L10n.text("ui.domain.%s" % domain, domain)
		parts.append(L10n.format_text("item.effect.domain",
			{"domain": domain_name, "percent": domain_percent},
			"%s 碎片 +%d%%" % [domain_name, domain_percent]))
	if parts.is_empty():
		return L10n.text("item.effect.none", "无乘区")
	return "，".join(parts)
