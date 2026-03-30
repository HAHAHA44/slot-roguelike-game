# 结算报告：
# - `SettlementResolver` 的输出对象，记录阶段顺序、逐步结算结果、总分变化和警告信息。
# - UI 层会逐条播放 `steps`，而不是直接跳到最终分数，这样玩家能看见“发生了什么”。
# - 它是“结算结束后的读模型”，只读、不回写规则。
class_name SettlementReport
extends RefCounted

var phases: Array[String] = []
var steps: Array[SettlementStep] = []
var total_score_delta: int = 0
var warnings: Array[String] = []
