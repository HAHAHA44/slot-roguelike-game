# effect：改邻居的分（M1 两种联动模式之一 —— 邻接联动，UI 画蓝线）。
# - radius 沿 ring 双向取邻居，0 和 11 相邻（RingBoardService.neighbors 保证 ring 拓扑）。
# - 空槽和不在 registry 里的 token 会被跳过，不算命中。
# - amount 可以为负：把邻居压低会让它更早结算，是刻意的节奏工具，不是 bug。
class_name ModifyNeighbor
extends ScriptableEffect

@export var amount: int = 0
@export var radius: int = 1

func execute(context) -> void:
	if context == null or amount == 0:
		return
	for target_slot in context.neighbors(radius):
		context.link(int(target_slot), amount, CascadeContext.KIND_ADJACENT)
