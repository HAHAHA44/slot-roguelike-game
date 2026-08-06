# 转折年事件内容定义：
# - 事件分两层（见 CONTEXT.md）：**流水年**只滚一行金句不阻塞（FlavorLineDefinition），
#   **转折年**才弹窗要玩家做选择——就是本类。约 15–25% 的年份是转折年。
# - 转折年稀缺是刻意的：每年都弹的窗玩家会瞎点，一年一次的窗玩家才会认真读。
#   也只有这样，85 年的时间预算才装得下（见 growth-loop-design 第 Q9 条）。
# - 抽取权重按**精神档**（high/mid/low）分三档给，低精神档才抽得到恶性与致死事件。
# - 文案规格（fun-axes）：正文 ≤ 2 句，选项 ≤ 4 个、每个 ≤ 1 句，要金句感不要段落感。
class_name EventDefinition
extends Resource

# 事件的性质，只用于 UI 配色与明牌概率提示的分组。
const ALLOWED_KINDS := ["benign", "neutral", "malign", "lethal"]

@export var id: String = ""
# l10n key
@export var name: String = ""
@export var description: String = ""
@export var kind: String = "neutral"

# 限定人生阶段（对应 LifeStageDef.id）；""=任何阶段都可能出现。
@export var stage_id: String = ""
# 限定当年生肖（对应 ZodiacDefinition.id）；""=不限。
@export var zodiac_id: String = ""
# 仅在本命年出现。本命年事件池更极端（大喜大悲）。
@export var birth_year_only: bool = false

# 三档精神力下的相对抽取权重：{"high": f, "mid": f, "low": f}。缺档按 0 处理。
# 良性事件高精神 5×/中 1×/低 0.2×；恶性反过来；致死只在低档非零。
@export var spirit_weights: Dictionary = {}

# 玩家的选项（1–4 个）。空数组表示纯叙事事件，UI 给一个「知道了」。
@export var choices: Array[EventChoice] = []

# 无论选哪个都累加的宿命值。
@export var karma_delta: int = 0

func get_display_name() -> String:
	return L10n.text(name, name)

func get_display_description() -> String:
	return L10n.text(description, description)

func is_lethal() -> bool:
	return kind == "lethal"

func weight_for(bucket: String) -> float:
	return float(spirit_weights.get(bucket, 0.0))
