# 生肖内容定义：
# - 描述 12 生肖之一在生肖盘上的固定槽位（order 0-11，鼠→猪）。
# - 纯数据，没有玩法逻辑；玩法（当年生肖 / 本命年 / 奖励格）走 ZodiacService。
# - 与其它 *Definition 一样由 ContentRegistry 在启动时按 id 索引。
class_name ZodiacDefinition
extends Resource

@export var id: String = ""
# l10n key, 例如 "content.zodiac.rat.name"
@export var display_name: String = ""
# 0-11，鼠=0, 牛=1, ..., 猪=11
@export var order: int = 0

func get_display_name() -> String:
	return L10n.text(display_name, id)
