# 英雄内容定义：
# - 描述主角原型及其对事件权重、惩罚倍率等的偏向。
# - 这里不直接执行修正，只保存数据，让 `RunModifierService` 去读取并转成运行时 modifiers。
# - 典型联动：`ContentRegistry` 载入英雄后，`RunScreen` 选择一个英雄资源，再交给 `RunModifierService` 和 `EventDraftService` 使用。
class_name HeroDefinition
extends Resource

const ALLOWED_ATTRIBUTES := ["Insight", "Resolve", "Flux", "Greed"]

@export var id: String = ""
@export var name: String = ""
@export var starting_passive: String = ""
@export var attribute_bias: String = ""
@export var event_weight_modifiers: Dictionary = {}
