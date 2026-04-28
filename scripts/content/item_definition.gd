# 道具内容定义：
# - 描述一件道具的基础内容：名称、描述、效果类型和效果数据。
# - effect_type = "passive"：道具留在道具栏中，每次结算时持续生效。
# - effect_type = "instant"：拾起时立即生效，不进入道具栏。
# - effect_data 结构由 effect_type 决定：
#   - passive: {"element": "fire"|"water"|"earth"|"wind"} → 该元素每个 token 计分 +1
#   - instant upgrade: {"action": "upgrade_random"} → 随机升级一个 token 到更高稀有度
#   - instant delete: {"action": "delete_random", "count": 2} → 随机删除 N 个 token
# - 典型联动：ContentRegistry 加载，EventDraftService 分发，SettlementResolver 结算被动效果。
class_name ItemDefinition
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var effect_type: String = "passive"   # "passive" | "instant"
@export var effect_data: Dictionary = {}

func get_display_name() -> String:
	return L10n.text(name, id)

func get_display_description() -> String:
	return L10n.text(description)
