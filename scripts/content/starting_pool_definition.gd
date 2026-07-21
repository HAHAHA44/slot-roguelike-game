# 起始 token 池定义（M1）：
# - 一条人生出生时手里有哪些「人生碎片」。RunScreen 在 begin_run 时把 token_ids
#   拷进 RunSession.token_pool，之后每年洗牌投盘。
# - token_ids 允许重复：重复份数就是权重，4 张勤勉比 1 张祖荫常见得多。
#   同一个 id 出现多次也是同生肖联动的燃料（两张同乡才能互相共鸣）。
# - 池子大小不必等于 12：多于 12 时每年抽 12 张，少于 12 时剩下的槽留空。
#   M1 先做成静态池；M3 事件经济接管后池子才会在一生中增减。
# - 放在 content/run_start/ 而不是写死在 RunScreen 里——池子构成是 M1 质量门要
#   反复调的旋钮，调内容不该改代码。
class_name StartingPoolDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var token_ids: PackedStringArray = PackedStringArray()

func get_display_name() -> String:
	return L10n.text(display_name, id)

func size() -> int:
	return token_ids.size()
