# 人生碎片内容定义：
# - 一张碎片「是什么」：显示名、稀有度、领域、基础分、联动效果、生肖共鸣。
# - 碎片**归属于人生阶段**（stage_id）：幼年有幼年的碎片，阶段结束时清空，
#   唯有满星者按 legacy_into 进化成传承物带进下一阶段。见 ADR-0003。
# - 纯数据。投盘、结算、合成、抽取的规则分别在 RingBoardService / SettlementService /
#   MergeService / DraftService 里，这里一条逻辑都不写。
class_name TokenDefinition
extends Resource

const ALLOWED_RARITIES := ["Common", "Uncommon", "Rare", "Legendary"]

@export var id: String = ""
# l10n key
@export var name: String = ""
@export var description: String = ""
@export var rarity: String = "Common"
@export var tags: PackedStringArray = PackedStringArray()

# 领域：体育 / 学业 / 艺术 / 人情 / 财富…（见 CONTEXT.md「领域」）。
# 传承链沿领域延伸，投注池也按玩家已建树的领域加权。""=无领域（如补位碎片「凡庸」）。
@export var domain: String = ""

# 归属的人生阶段 id（对应 LifeStageDef.id）。""=不属于任何阶段，
# 即「跨阶段碎片」：补位碎片与传承物走这条路，不会被阶段清空。
@export var stage_id: String = ""

# 满星后进化成哪张碎片的 id（""=不可传承）。传承链就是靠这个字段一环扣一环。
@export var legacy_into: String = ""

# true = 本身就是传承物。传承物不进投注池、不被阶段清空、可再度被同领域满星升格。
@export var is_legacy: bool = false

# 进投注池的相对权重。0 = 不进投注池（补位碎片、传承物）。
@export var draft_weight: float = 1.0

# cascade 进盘时的初始分。
@export var base_score: int = 0
# cascade 触发时按序执行的效果。
@export var effects: Array[ScriptableEffect] = []
# 与该碎片共鸣的生肖 id（""=无共鸣，不参与同生肖联动）。
@export var zodiac_affinity: String = ""

func get_display_name() -> String:
	return L10n.text(name, name)

func get_display_description() -> String:
	return L10n.text(description, description)

func get_display_rarity() -> String:
	return L10n.rarity_name(rarity)

func get_display_domain() -> String:
	if domain.is_empty():
		return L10n.text("ui.domain.none", "无领域")
	return L10n.text("ui.domain.%s" % domain, domain)

func get_display_tags() -> PackedStringArray:
	var translated_tags := PackedStringArray()
	for tag in tags:
		translated_tags.append(L10n.tag_name(tag))
	return translated_tags

# 可被抽到吗（补位碎片与传承物都不进投注池）。
func is_draftable() -> bool:
	return draft_weight > 0.0 and not is_legacy

func can_ascend() -> bool:
	return not legacy_into.is_empty()
