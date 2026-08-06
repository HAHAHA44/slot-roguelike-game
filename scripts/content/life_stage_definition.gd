# 生命阶段内容定义：
# - 描述 7 个人生阶段之一（童年 → 暮年）。
# - 纯数据；玩法（年龄 → 当前阶段查找 / 暮年 endless 判定）走 LifeStageService。
# - 阶段切换叙事文案是 l10n key，叙事 UI 在 M5 接入时消费。
class_name LifeStageDef
extends Resource

@export var id: String = ""
# l10n key, 例如 "content.life_stage.childhood.name"
@export var display_name: String = ""
# 0-6，童年=0, 少年=1, 青年=2, 壮年=3, 中年=4, 老年=5, 暮年=6
@export var order: int = 0
# 该阶段的起始年龄；暮年(order=6)起始 72 之后 endless 循环至寿命耗尽。
@export var start_age: int = 0
# l10n key，阶段开场叙事；空字符串表示无叙事。
@export var narrative: String = ""

func get_display_name() -> String:
	return L10n.text(display_name, display_name)

func get_narrative() -> String:
	if narrative.is_empty():
		return ""
	return L10n.text(narrative, narrative)
