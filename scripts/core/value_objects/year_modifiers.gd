# 一年的全部结算修正，汇总成一个不可变载体：
# - 来源有四处：当年生肖的年度规则、六维属性、持有的道具、本命年加成。
#   它们全部折算成同一组旋钮，SettlementService 只认这个对象，不认来源。
# - 这样做的理由是可调试：玩家问「今年为什么炸这么大」，答案是一组具体的百分比，
#   而不是散落在四个服务里的隐形乘区。UI 也能照着这些字段逐条列出。
# - 由 YearModifierService 构建；构建后不再改。
class_name YearModifiers
extends RefCounted

# -- 进盘时（cascade 开始前，作用于初始分） ----------------------------------
# 全场每格 +N。
var all_base_bonus: int = 0
# 基础分 ≤ threshold 的碎片额外 +bonus（鼠·囤积）。threshold ≤ 0 表示不生效。
var low_base_threshold: int = 0
var low_base_bonus: int = 0
# ≥2 星的碎片初始分 +p%（虎·威势）。
var star_percent: int = 0
# 指定领域的碎片初始分 +p%（鸡·司晨）。
var domain: String = ""
var domain_percent: int = 0
# 偶数槽位 +p%（狗·守夜）。
var even_slot_percent: int = 0

# -- cascade 中（作用于 effect 的每一次加成） --------------------------------
# 「加自身分」类 effect ×(1+p%)（牛·厚积）。
var self_percent: int = 0
# 同生肖联动 ×(1+p%)（蛇·蜕变 / 智力 / 本命年）。
var zodiac_percent: int = 0
# 邻接联动 ×(1+p%)（兔·敏行 / 敏捷）。
var neighbor_percent: int = 0
# 邻接联动半径 +N（马·奔走）。
var neighbor_radius_bonus: int = 0

# -- cascade 后（作用于最终分） ----------------------------------------------
# 结算后最高分的那格 +p%（龙·腾达）。
var highest_percent: int = 0
# 结算后最低分的那格 +p%（羊·守拙）。
var lowest_percent: int = 0
# 每累计一次连击给全场 +p%（猴·机变）。
var chain_percent: int = 0
# 年收益总额 ×(1+p%)，道具乘区的落点。
var settle_percent: int = 0

# 玩家可读的逐条说明（UI 用）。构建时由 YearModifierService 填。
var notes: Array = []

# 用于 UI / 日志：把非零旋钮列成一行行文本。
func describe_lines() -> Array:
	return notes.duplicate()
