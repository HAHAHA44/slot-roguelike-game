# effect：给自己加分（M1 三个基础 effect 之一）。
# - 最简单的一类，不产生联动，纯粹抬高自身 current_score。
# - 存在意义是当"联动的燃料"：cascade 是 min-score-first，自加分会把自己推后结算，
#   于是它更可能吃到别人先打过来的加成（fun-axes P2：effect 必须可堆叠）。
class_name AddSelfScore
extends ScriptableEffect

@export var amount: int = 0

func execute(context) -> void:
	if context == null or amount == 0:
		return
	context.add_self(amount)

func describe() -> String:
	return L10n.format_text("effect.add_self_score", {"amount": amount},
		"自身 +%d" % amount)
