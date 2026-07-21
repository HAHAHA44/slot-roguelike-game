# cascade 单步结算记录（M1）：
# - 一个 token 从"被选中结算"到"结算完毕"这一步的完整快照，UI 层按 sequence_index
#   顺序回放（fun-axes P1：token 之间必须有 300–500ms 微停顿，玩家要看见多米诺）。
# - 不可变：构造一次就不再改。分数变化已经发生在 SettlementService 内部，这里只记录结果。
# - affected_slots / chain_kind 直接服务于连线高亮（同生肖红线 / 邻接蓝线）。
# - 与旧 5×5 的 SettlementStep 并存但无关系；那个是 25 格分阶段结算的记录，M7 清理。
class_name CascadeStep
extends RefCounted

var sequence_index: int
var slot: int
var token_id: String
# 该 token 本步结算前后的自身分数。score_after - score_before 不等于 effect 加的总量，
# 因为它可能在更早的步骤里已被别的 token 改过分。
var score_before: int
var score_after: int
# 本步 effect 打到的其他槽位，按 effect 产生顺序排列（空 = 没触发联动）。
var affected_slots: Array
# 联动类型，取本步第一条 link 的 kind："" / "zodiac" / "adjacent"。
var chain_kind: String
# 本步结束后的累计 chain 数，UI 靠它决定何时弹连击 banner（3 / 5 / 7 / 12）。
var chain_count_after: int

func _init(
	step_index: int = 0,
	step_slot: int = -1,
	step_token_id: String = "",
	before: int = 0,
	after: int = 0,
	affected: Array = [],
	kind: String = "",
	chain_after: int = 0
) -> void:
	sequence_index = step_index
	slot = step_slot
	token_id = step_token_id
	score_before = before
	score_after = after
	affected_slots = affected
	chain_kind = kind
	chain_count_after = chain_after
