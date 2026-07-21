# cascade 结算报告（M1）：
# - SettlementService.settle() 的输出，一年一份。只读模型，不回写规则。
# - total_score 是当年年收益（Σ 各槽结算后分数），M3 起换算成 token / item / 属性奖励。
# - chain_count 是当年累计联动次数；fun-axes 的连击 banner 阈值是 3 / 5 / 7 / 12。
# - steps 供 UI 逐条回放；严禁"瞬时结算然后弹个总分"（fun-axes P1）。
class_name CascadeReport
extends RefCounted

var steps: Array
var total_score: int
var chain_count: int
var warnings: Array

func _init(
	report_steps: Array = [],
	score: int = 0,
	chains: int = 0,
	report_warnings: Array = []
) -> void:
	steps = report_steps
	total_score = score
	chain_count = chains
	warnings = report_warnings
