# 事件内容定义：
# - 描述一次事件草案的基础数据，包括类型、主标签、稳定性、权重、描述、合约模板、奖励包和惩罚包。
# - `EventDraftService` 会读取这些字段，结合棋盘标签、英雄修正和难度修正来决定三选一结果。
# - `ContractService` 会使用 `contract_template`、`reward_bundle`、`penalty_bundle` 生成并推进合约。
# - 所以这个类本身只是内容结构，真正的规则不在这里写。
class_name EventDefinition
extends Resource

const ALLOWED_TYPES := ["instant", "lasting", "crisis"]
const ALLOWED_STABILITIES := ["stable", "risky", "volatile"]

@export var id: String = ""
@export var name: String = ""
@export var type: String = "instant"
@export var primary_tag: String = ""
@export var stability: String = "stable"
@export var weight: float = 1.0
@export_multiline var description: String = ""
@export var tags_affected: PackedStringArray = PackedStringArray()
@export var duration: int = 0
@export var contract_template: Dictionary = {}
@export var reward_bundle: Dictionary = {}
@export var penalty_bundle: Dictionary = {}

# M2+ life-sim 字段（旧 contract/bundle 字段保留至 M7 抛光清理）：
# - sanity_weights：{"high"/"mid"/"low" -> float}，EventDraftService 按当前精神档抽权。
# - lethal_flag：true = 死亡事件，仅在 low sanity 段非零权重。
# - effects：事件结算时按序执行的 ScriptableEffect 列表（M3 EventResolverService 消费）。
# - karma_delta：本事件对当局 karma 的贡献（M6 KarmaService 累加）。
@export var sanity_weights: Dictionary = {}
@export var lethal_flag: bool = false
@export var effects: Array[ScriptableEffect] = []
@export var karma_delta: int = 0

func get_display_name() -> String:
	return L10n.text(name, id)

func get_display_description() -> String:
	return L10n.text(description)
