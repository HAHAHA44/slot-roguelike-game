# 起始命盘定义：
# - 一条人生**出生时**手里有哪几张碎片。绝大多数碎片靠每年的三选一慢慢攒，
#   所以这里只放很少的几张——童年头几年命盘几乎全是「凡庸」是有意的，
#   那正是「早期三位数」曲线的起点（ADR-0003）。
# - token_ids 允许重复：重复份数直接推进合成进度。
# - filler_token_id 是命盘不满 12 张时补空位的碎片，必填——空槽会让盘面出现看不懂的洞。
# - 放在 content/run_start/ 而不是写死在 RunScreen 里：起始构成是要反复调的旋钮，
#   调内容不该改代码。
class_name StartingPoolDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var token_ids: PackedStringArray = PackedStringArray()
@export var filler_token_id: String = ""

func get_display_name() -> String:
	return L10n.text(display_name, display_name)

func size() -> int:
	return token_ids.size()
