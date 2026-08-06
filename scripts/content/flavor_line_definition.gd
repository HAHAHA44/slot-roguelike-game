# 流水年金句内容定义：
# - 一行字，无交互，不阻塞 cascade 节奏——大多数年份只有这个。
# - 它是《人生重开模拟器》那种叙事密度的来源，而且**零时间成本**：
#   金句和 cascade 动画并行滚在年度日志里，不占每年 8 秒预算的任何一秒。
# - 因此文案要求只有一条：要画面，不要信息量。
#   「你在街角捡到一张皱巴巴的钞票」而不是「你获得 100 元」。
# - 纯装饰，不改任何游戏状态。要改状态的是转折年事件（EventDefinition）。
class_name FlavorLineDefinition
extends Resource

@export var id: String = ""
# l10n key，正文本身。
@export var text: String = ""
# 限定人生阶段（对应 LifeStageDef.id）；""=任何阶段。
@export var stage_id: String = ""
# 限定精神档（"high"/"mid"/"low"）；""=不限。
# 低精神档的金句该阴郁，高精神档的该明亮——这是最便宜的情绪反馈。
@export var spirit_bucket: String = ""
@export var weight: float = 1.0

func get_display_text() -> String:
	return L10n.text(text, text)
