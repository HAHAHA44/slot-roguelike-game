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

