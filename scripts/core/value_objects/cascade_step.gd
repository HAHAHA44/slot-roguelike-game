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
# 本步的全部联动 link：[{slot: int, delta: int, kind: String}, ...]。
# UI 靠它逐条画连线——同一个 step 可能同时产生同生肖（红线）和邻接（蓝线），
# 例如「祖荫」同时挂 TriggerZodiacChain 和 ModifyNeighbor。只看 chain_kind 会丢线。
var chain_links: Array
# 本步的主联动类型（第一条 link 的 kind）："" / "zodiac" / "adjacent"。
# 只用于摘要展示（日志行、banner 配色）；画线一律走 chain_links。
var chain_kind: String
# 本步结束后的累计 chain 数，UI 靠它驱动连击 banner（3 连起常驻计数，5/10/20/50 升档）。
var chain_count_after: int

func _init(
	step_index: int = 0,
	step_slot: int = -1,
	step_token_id: String = "",
	before: int = 0,
	after: int = 0,
	affected: Array = [],
	links: Array = [],
	kind: String = "",
	chain_after: int = 0
) -> void:
	sequence_index = step_index
	slot = step_slot
	token_id = step_token_id
	score_before = before
	score_after = after
	affected_slots = affected
	chain_links = links
	chain_kind = kind
	chain_count_after = chain_after

# 本步出现过的联动类型集合，去重、保持首次出现顺序。UI 用它决定要画哪几种颜色的线。
func chain_kinds() -> Array:
	var result: Array = []
	for link in chain_links:
		var kind := String(link.get("kind", ""))
		if kind.is_empty() or result.has(kind):
			continue
		result.append(kind)
	return result
