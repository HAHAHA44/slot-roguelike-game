# 经济服务：阶段门槛与购买力。
#
# 核心是**相对计价**（ADR 之外的关键决策，见 growth-loop-design 第 Q7 条）：
# 年收益会因为 percent 复利指数增长，任何固定标价的商店到中后期都会变成「全都买得起」。
# 解法是让阶段门槛这个数兼两职——既是考核线，也是**计价基准**：
#
#     购买力 = 年收益 / 当前阶段门槛
#     道具标价以「几个基准」计，不以绝对数字计
#
# 于是绝对数字可以炸到七位（fun-axes P2），而购买力全程大致恒定，
# 且只需要调**一条**曲线。玩家赢在 build 不在钱包——这是 Balatro 的 ante 缩放模型。
#
# 由此自动得到两条反馈：
#   build 成型 → 收益增速超过门槛增速 → 购买力上升 → 更快成型
#   build 拉胯 → 收益跟不上门槛 → 买不起 → 更跟不上（死亡螺旋，紧张感的来源）
class_name EconomyService
extends RefCounted

# 童年阶段的门槛。12 年后命盘刚铺满一星碎片，年收益大致落在这个量级。
const BASE_THRESHOLD := 120.0
# 每进一个人生阶段门槛乘多少。3.0 意味着七个阶段跨越约 3^6 ≈ 729 倍，
# 配合星级（最高 7×）、传承物与道具乘区，暮年七位数是够得着的。
const STAGE_GROWTH := 3.0
# 购买力上限：防止某一年爆炸性 cascade 让玩家一次性买空商店。
# 这不是分数封顶（fun-axes 禁止那个），封的是**兑换率**，年收益本身不受限。
const MAX_PURCHASING_POWER := 6.0

func threshold_for_stage(stage_order: int) -> int:
	var order: int = maxi(stage_order, 0)
	return int(round(BASE_THRESHOLD * pow(STAGE_GROWTH, float(order))))

# 当年收益换算成购买力。门槛非正时退化为 0，避免除零。
func purchasing_power(income: int, threshold: int) -> float:
	if threshold <= 0:
		return 0.0
	return minf(float(income) / float(threshold), MAX_PURCHASING_POWER)

# 阶段考核：用该阶段**最后一年**的年收益对门槛，而不是 12 年累计。
# 累计会奖励「活得久」，最后一年才反映 build 强度；而且命盘在阶段末最满，
# 语义上就是「这十二年练出的成果」。
func stage_review(session, stage_order: int) -> Dictionary:
	var threshold := threshold_for_stage(stage_order)
	var final_income: int = 0
	if session != null and not session.stage_income.is_empty():
		final_income = int(session.stage_income[session.stage_income.size() - 1])
	return {
		"threshold": threshold,
		"income": final_income,
		"passed": final_income >= threshold,
		"ratio": float(final_income) / float(threshold) if threshold > 0 else 0.0,
	}
