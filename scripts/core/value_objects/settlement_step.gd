# 单步结算结果：
# - 表示结算过程中某一步的来源 token、所属 phase、分数变化和 UI 文案 key。
# - `RunScreen` 会按 `sequence_index` 顺序把它们写进 settlement log。
# - 这个类不算分，只承载结算过程中的原子事件，便于回放和测试。
class_name SettlementStep
extends RefCounted

var sequence_index: int
var source_token: String
var phase: String
var score_delta: int
var target_token: String
var message_key: String

func _init(step_index: int = 0, source: String = "", step_phase: String = "", delta: int = 0, target: String = "", key: String = "") -> void:
	sequence_index = step_index
	source_token = source
	phase = step_phase
	score_delta = delta
	target_token = target
	message_key = key
