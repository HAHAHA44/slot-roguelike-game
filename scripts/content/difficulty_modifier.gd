# 难度修正规则定义：
# - 表示一个难度层级或 ascension 层级对事件权重、惩罚倍率等参数的调整。
# - 只是配置容器，具体怎么解释这些字段由 `RunModifierService` 和 `EventDraftService` 决定。
# - 典型联动：`ContentRegistry` 载入 `.tres` 后，`RunScreen` 会把当前难度传给 `RunModifierService`，再影响事件草案与惩罚计算。
class_name DifficultyModifier
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var modifiers: Dictionary = {}

func get_display_name() -> String:
	return L10n.text(name, id)

func get_display_description() -> String:
	return L10n.text(description)
