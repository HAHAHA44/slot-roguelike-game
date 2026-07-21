# effect：同生肖联动（M1 两种联动模式之一 —— UI 画红线）。
# - 找盘面上所有与自己 zodiac_affinity 相同的其他 token，各加 amount ＋ 其当前分的 percent%。
# - 同生肖联动天然无视距离，所以纯 amount 时它与排布完全无关；percent 让它至少与
#   「目标此刻被垫到多高」有关——同生肖 token 扎堆先被邻接联动喂肥，再被同生肖乘区
#   一起放大，是滚雪球的主要来源（fun-axes P2）。
# - 空 affinity 不参与：否则所有「无生肖属性」的 token 会全场互相共鸣，
#   同生肖联动就退化成「全场联动」，红线失去意义。
# - 不看槽位对应的生肖，只看 token 自身的 zodiac_affinity 字段——token 可以被投到任意槽。
class_name TriggerZodiacChain
extends ScriptableEffect

@export var amount: int = 0
@export var percent: int = 0

func execute(context) -> void:
	if context == null or (amount == 0 and percent == 0):
		return
	var self_def = context.token_def_at(context.slot)
	if self_def == null:
		return
	var affinity := String(self_def.zodiac_affinity)
	if affinity.is_empty():
		return
	for target_slot in context.occupied_slots():
		var slot_index := int(target_slot)
		var target_def = context.token_def_at(slot_index)
		if target_def == null:
			continue
		if String(target_def.zodiac_affinity) != affinity:
			continue
		var delta: int = context.scaled_delta(slot_index, amount, percent)
		context.link(slot_index, delta, CascadeContext.KIND_ZODIAC)
