# 转折年事件的一个选项：
# - 一句话文案 + 若干后果。fun-axes 规定「每选项 ≤ 1 句」，所以这里只有一个 text。
# - 后果一律是**立即结算**的具体量，不做延迟触发、不做多回合追踪
#   （fun-axes 反模式明令禁止 CK3 风的长事件链）。
# - lethal = true 的选项会直接终结这条人生。它只出现在致死事件里，
#   而致死事件只在低精神档抽得到。
class_name EventChoice
extends Resource

# l10n key
@export var text: String = ""

# 精神力增减（六维 spr）。
@export var spirit_delta: int = 0
# 宿命值增减，死亡结算时累加。
@export var karma_delta: int = 0
# 六维增减：{stat_key -> delta}，例如 {"str": 1}。
@export var stat_deltas: Dictionary = {}
# 寿命增减（年）。
@export var lifespan_delta: int = 0

# 直接给一张碎片（definition id，""=不给）。星级恒为 1——
# 事件给的是「机会」，练不练得成还是玩家的事。
@export var card_reward: String = ""
# 直接给一件道具（definition id，""=不给）。
@export var item_reward: String = ""
# 随机弃掉命盘上的 N 张碎片（0=不弃）。恶性事件的主要惩罚形态。
@export var discard_cards: int = 0

# 选了它就死。
@export var lethal: bool = false

func get_display_text() -> String:
	return L10n.text(text, text)
