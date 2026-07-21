# effect：改邻居的分（M1 两种联动模式之一 —— 邻接联动，UI 画蓝线）。
# - radius 沿 ring 双向取邻居，0 和 11 相邻（RingBoardService.neighbors 保证 ring 拓扑）。
# - 计分 = amount（定额）＋ 邻居当前分的 percent%。两者可以只用一个：
#   * 纯 amount → 平加，与排布无关
#   * 纯 percent → 纯放大，低分邻居收益小，高分邻居收益大
#   * 两者兼有 → 「先垫一手再放大」，此时结算顺序会改变结果（先加后乘 ≠ 先乘后加），
#     这正是 min-score-first 想要的：早结算的低分 token 更可能被后面的乘区反复放大。
# - 空槽和不在 registry 里的 token 会被跳过，不算命中。
# - amount 可以为负：把邻居压低会让它更早结算，是刻意的节奏工具，不是 bug。
class_name ModifyNeighbor
extends ScriptableEffect

@export var amount: int = 0
@export var percent: int = 0
@export var radius: int = 1

func execute(context) -> void:
	if context == null or (amount == 0 and percent == 0):
		return
	for target_slot in context.neighbors(radius):
		var slot_index := int(target_slot)
		var delta: int = context.scaled_delta(slot_index, amount, percent)
		context.link(slot_index, delta, CascadeContext.KIND_ADJACENT)
