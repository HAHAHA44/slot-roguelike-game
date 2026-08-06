# cascade 执行上下文：
# - SettlementService 在结算每张碎片时构造一次，传给该碎片的每个 ScriptableEffect。
# - effect 通过本对象读盘面 / 改分数，不直接碰 SettlementService 的内部数组。
#
# **所有放大都在这里，effect 里一个乘号都没有。** 这是刻意的：
# 星级（碎片自己多强）、年度规则（今年什么规矩）、六维（这个人多强）、道具（攒了什么）
# 四路修正全部折进 add_self / link / neighbors 三个出口，于是
#   ① 新写一个 effect 不需要知道任何修正的存在
#   ② 想查「今年为什么炸这么大」，答案集中在一个文件里
# 代价是这三个方法比看上去重，读的时候要记得它们不是纯加法。
#
# 区分两种改分：
#   * add_self()  —— 加到正在结算的碎片自己身上，不算联动
#   * link()      —— 打到别的槽位，算一条联动 link，会被记进 chain
# 这个区分就是 chain_count 的定义来源：一个 effect 只要产生了 ≥1 条 link 就记 1 次 chain
# （不是每条 link 记一次，否则满盘同生肖会瞬间刷出上百 chain，连击 banner 失去意义）。
class_name CascadeContext
extends RefCounted

const KIND_ZODIAC := "zodiac"
const KIND_ADJACENT := "adjacent"

# 正在结算的槽位与碎片 id。
var slot: int = -1
var token_id: String = ""

var _board = null
var _tokens: Dictionary = {}
var _scores: Array = []
var _mods = null
# 正在结算的碎片的星级倍率，begin_card 时写入。
var _star_mult: float = 1.0
# 本次 effect 执行产生的 link，SettlementService 在每个 effect 前后读写。
var _effect_links: Array = []
# 本步（可能多个 effect）累计的 link。
var _step_links: Array = []

func _init(board, tokens: Dictionary, scores: Array, modifiers = null) -> void:
	_board = board
	_tokens = tokens
	_scores = scores
	_mods = modifiers

# -- SettlementService 侧接口 ------------------------------------------------

func begin_card(settling_slot: int, settling_token_id: String, star_multiplier: float) -> void:
	slot = settling_slot
	token_id = settling_token_id
	_star_mult = star_multiplier
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

func star_at(target_slot: int) -> int:
	if _board == null:
		return 0
	return _board.star_at(target_slot)

# 盘面上所有"有碎片且该碎片在 registry 里"的槽位，升序。
func occupied_slots() -> Array:
	var result: Array = []
	if _board == null:
		return result
	for s in _board.occupied_slots():
		if token_def_at(int(s)) != null:
			result.append(int(s))
	return result

# 邻居。年度规则「马·奔走」会把半径推大一格，所以这里加 neighbor_radius_bonus。
func neighbors(radius: int = 1) -> Array:
	if _board == null:
		return []
	var bonus: int = int(_mods.neighbor_radius_bonus) if _mods != null else 0
	return _board.neighbors(slot, maxi(1, radius + bonus))

# 联动的统一计分口径：定额 amount ＋ 目标当前分的 percent%。
# 比例部分是 fun-axes P2 的落点——纯加法的联动，总分与排布无关（满盘时每个碎片的
# 邻居数恒定，加法又可交换），于是每年结算结果一模一样。乘上目标当前分之后，
# 「谁挨着谁」和「谁先结算」才开始改变结果，min-score-first 也才有意义。
# 用 roundi 而不是截断，避免小分数时比例部分总是被抹成 0。
func scaled_delta(target_slot: int, amount: int, percent: int) -> int:
	if percent == 0:
		return amount
	var current := score_at(target_slot)
	return amount + roundi(float(current) * float(percent) / 100.0)

# 加到自己身上。不产生 link，不记 chain。
# 乘上星级倍率与「加自身分」类修正（年度规则牛·厚积 / 力量维）。
func add_self(delta: int) -> void:
	if slot < 0 or slot >= _scores.size():
		return
	_scores[slot] = int(_scores[slot]) + _amplify(delta, _percent_for_self())

# 打到别的槽位。产生一条 link → 本 effect 记为"命中"。
# 打到自身或越界会被忽略，避免 effect 写错时自我循环。
# 记进 link 的是**放大后**的 delta，因为 UI 要显示实际打出去的数。
func link(target_slot: int, delta: int, kind: String) -> bool:
	if target_slot < 0 or target_slot >= _scores.size():
		return false
	if target_slot == slot:
		return false
	if token_def_at(target_slot) == null:
		return false
	var final_delta := _amplify(delta, _percent_for_kind(kind))
	_scores[target_slot] = int(_scores[target_slot]) + final_delta
	var record := {"slot": target_slot, "delta": final_delta, "kind": kind}
	_effect_links.append(record)
	_step_links.append(record)
	return true

# -- 放大 --------------------------------------------------------------------

# 星级倍率与百分比修正一起作用于 effect 的原始产出。
# 负数（惩罚型 effect）同样被放大——满星的赌博碎片赔得也更狠，这是有意的对称。
func _amplify(delta: int, percent: int) -> int:
	if delta == 0:
		return 0
	return roundi(float(delta) * _star_mult * (1.0 + float(percent) / 100.0))

func _percent_for_self() -> int:
	return int(_mods.self_percent) if _mods != null else 0

func _percent_for_kind(kind: String) -> int:
	if _mods == null:
		return 0
	if kind == KIND_ZODIAC:
		return int(_mods.zodiac_percent)
	if kind == KIND_ADJACENT:
		return int(_mods.neighbor_percent)
	return 0
