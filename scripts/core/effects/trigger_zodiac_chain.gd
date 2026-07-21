# effect：同生肖联动（M1 两种联动模式之一 —— UI 画红线）。
# - 找盘面上所有与自己 zodiac_affinity 相同的其他 token，各加 amount。
# - 空 affinity 不参与：否则所有"无生肖属性"的 token 会全场互相共鸣，
#   同生肖联动就退化成"全场联动"，红线失去意义。
# - 不看槽位对应的生肖，只看 token 自身的 zodiac_affinity 字段——token 可以被投到任意槽。
class_name TriggerZodiacChain
extends ScriptableEffect

@export var amount: int = 0

func execute(context) -> void:
	if context == null or amount == 0:
		return
	var self_def = context.token_def_at(context.slot)
	if self_def == null:
		return
	var affinity := String(self_def.zodiac_affinity)
	if affinity.is_empty():
		return
	for target_slot in context.occupied_slots():
		var target_def = context.token_def_at(int(target_slot))
		if target_def == null:
			continue
		if String(target_def.zodiac_affinity) != affinity:
			continue
		context.link(int(target_slot), amount, CascadeContext.KIND_ZODIAC)
