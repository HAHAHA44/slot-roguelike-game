# Token 内容定义：
# - 描述棋盘上一个 token 的基础内容，包括显示名、稀有度、类型、标签、基础数值，以及 spawn/remove 规则。
# - `RewardOfferService` 读取 `spawn_rules.weight` 决定奖励候选。
# - `BoardRollService` 只关心 token 的 `id`，真正的结算、标签和状态字段会在 `RunScreen` 组装 token 实例时一起带入。
# - `empty_token` 也是一个正式的 `TokenDefinition`，不是 UI 占位符。
class_name TokenDefinition
extends Resource

const ALLOWED_RARITIES := ["Common", "Uncommon", "Rare", "Legendary"]

@export var id: String = ""
@export var name: String = ""
@export var rarity: String = "Common"
@export var type: String = ""
@export var tags: PackedStringArray = PackedStringArray()
@export var base_value: int = 0
@export var trigger_rules: Dictionary = {}
@export var state_fields: Dictionary = {}
@export var spawn_rules: Dictionary = {}
@export var remove_rules: Dictionary = {}
