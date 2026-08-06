# 开局 Buff/Debuff 内容定义：
# - 出生时按运气抽取，**只在出生瞬间结算一次**——它们是出生条件（家世、体质、运数），
#   不是常驻被动。「家境优渥」不该每年再触发一次。见 CONTEXT.md。
# - 因此效果全是**改开局参数**：六维初值、寿命、起始命盘、起始购买力。
# - 做成一次性还有第二个理由：它是 M6 转世的天然接口。宿命值高 → 好 buff 抽取权重高，
#   PRD 里「出生家庭品级随 karma 偏置」这句话的落点就是这里，届时只需改抽取权重。
# - 第三个理由是认知负担：8 条常驻被动 × 85 年，玩家永远搞不清今年为什么炸了或没炸。
class_name BuffDefinition
extends Resource

const ALLOWED_POLARITIES := ["buff", "debuff"]

@export var id: String = ""
# l10n key
@export var display_name: String = ""
@export var description: String = ""
# "buff"=增益 / "debuff"=减益。BuffService 按它分两池抽取。
@export var polarity: String = "buff"
# 抽取权重（同极性池内的相对概率）。
@export var weight: float = 1.0
@export var tags: PackedStringArray = PackedStringArray()

# -- 出生时施加的效果 --------------------------------------------------------
# 六维增减：{stat_key -> delta}，例如 {"end": 3}。
@export var stat_deltas: Dictionary = {}
# 寿命增减（年）。
@export var lifespan_delta: int = 0
# 额外送一张碎片（definition id，""=不送）。
@export var extra_card: String = ""
# 送出的碎片星级。家世好的人一出生就有二星的东西。
@export var extra_card_star: int = 1
# 起始购买力加成（单位=阶段门槛的倍数）。「家境优渥」的落点。
@export var purchasing_power_bonus: float = 0.0

func get_display_name() -> String:
	return L10n.text(display_name, display_name)

func get_display_description() -> String:
	if description.is_empty():
		return ""
	return L10n.text(description, description)

func is_buff() -> bool:
	return polarity == "buff"
