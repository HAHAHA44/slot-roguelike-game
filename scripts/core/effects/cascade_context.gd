# cascade 执行上下文（M1）：
# - SettlementService 在结算每个 token 时构造一次，传给该 token 的每个 ScriptableEffect。
# - effect 通过本对象读盘面 / 改分数，不直接碰 SettlementService 的内部数组。
# - 区分两种改分：
#   * add_self()  —— 加到正在结算的 token 自己身上，不算联动
#   * link()      —— 打到别的槽位，算一条联动 link，会被记进 chain
#   这个区分就是 chain_count 的定义来源：一个 effect 只要产生了 ≥1 条 link 就记 1 次 chain
#   （不是每条 link 记一次，否则满盘同生肖会瞬间刷出上百 chain，连击 banner 失去意义）。
class_name CascadeContext
extends RefCounted

const KIND_ZODIAC := "zodiac"
const KIND_ADJACENT := "adjacent"

# 正在结算的槽位与 token id。
var slot: int = -1
var token_id: String = ""

var _board = null
var _tokens: Dictionary = {}
var _scores: Array = []
# 本次 effect 执行产生的 link，SettlementService 在每个 effect 前后读写。
var _effect_links: Array = []
# 本步（可能多个 effect）累计的 link。
var _step_links: Array = []

func _init(board, tokens: Dictionary, scores: Array) -> void:
	_board = board
	_tokens = tokens
	_scores = scores

# -- SettlementService 侧接口 ------------------------------------------------

func begin_token(settling_slot: int, settling_token_id: String) -> void:
	slot = settling_slot
	token_id = settling_token_id
	_step_links = []

func begin_effect() -> void:
	_effect_links = []

# 本次 effect 是否打中了目标（决定要不要 chain_count++）。
func effect_hit() -> bool:
	return not _effect_links.is_empty()

func step_links() -> Array:
	return _step_links

# -- effect 侧接口 -----------------------------------------------------------

func score_at(target_slot: int) -> int:
	if target_slot < 0 or target_slot >= _scores.size():
		return 0
	return int(_scores[target_slot])

func token_id_at(target_slot: int) -> String:
	if _board == null:
		return ""
	return _board.token_at(target_slot)

func token_def_at(target_slot: int):
	var id := token_id_at(target_slot)
	if id.is_empty():
		return null
	return _tokens.get(id, null)

# 盘面上所有"有 token 且该 token 在 registry 里"的槽位，升序。
func occupied_slots() -> Array:
	var result: Array = []
	if _board == null:
		return result
	for s in _board.occupied_slots():
		if token_def_at(int(s)) != null:
			result.append(int(s))
	return result

func neighbors(radius: int = 1) -> Array:
	if _board == null:
		return []
	return _board.neighbors(slot, radius)

# 联动的统一计分口径：定额 amount ＋ 目标当前分的 percent%。
# 比例部分是 fun-axes P2 的落点——纯加法的联动，总分与排布无关（满盘时每个 token 的
# 邻居数恒定，加法又可交换），于是每年结算结果一模一样。乘上目标当前分之后，
# 「谁挨着谁」和「谁先结算」才开始改变结果，min-score-first 也才有意义。
# 用 roundi 而不是截断，避免小分数时比例部分总是被抹成 0。
func scaled_delta(target_slot: int, amount: int, percent: int) -> int:
	if percent == 0:
		return amount
	var current := score_at(target_slot)
	return amount + roundi(float(current) * float(percent) / 100.0)

# 加到自己身上。不产生 link，不记 chain。
func add_self(delta: int) -> void:
	if slot < 0 or slot >= _scores.size():
		return
	_scores[slot] = int(_scores[slot]) + delta

# 打到别的槽位。产生一条 link → 本 effect 记为"命中"。
# 打到自身或越界会被忽略，避免 effect 写错时自我循环。
func link(target_slot: int, delta: int, kind: String) -> bool:
	if target_slot < 0 or target_slot >= _scores.size():
		return false
	if target_slot == slot:
		return false
	if token_def_at(target_slot) == null:
		return false
	_scores[target_slot] = int(_scores[target_slot]) + delta
	var record := {"slot": target_slot, "delta": delta, "kind": kind}
	_effect_links.append(record)
	_step_links.append(record)
	return true
