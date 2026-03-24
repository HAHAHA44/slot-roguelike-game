class_name RunSession
extends RefCounted

const SCHEMA_VERSION := 1

var schema_version: int = SCHEMA_VERSION
var current_turn: int = 1
var phase_index: int = 0
var phase_target: int = 10
var current_score: int = 0
var operation_history: Array = []
var active_modifiers: Array = []

func to_dict() -> Dictionary:
	return {
		"schema_version": schema_version,
		"current_turn": current_turn,
		"phase_index": phase_index,
		"phase_target": phase_target,
		"current_score": current_score,
		"operation_history": operation_history.duplicate(true),
		"active_modifiers": active_modifiers.duplicate(true),
	}

static func from_dict(data: Dictionary) -> RunSession:
	var session := RunSession.new()
	session.schema_version = int(data.get("schema_version", SCHEMA_VERSION))
	session.current_turn = int(data.get("current_turn", 1))
	session.phase_index = int(data.get("phase_index", 0))
	session.phase_target = int(data.get("phase_target", 10))
	session.current_score = int(data.get("current_score", 0))
	session.operation_history = data.get("operation_history", []).duplicate(true)
	session.active_modifiers = data.get("active_modifiers", []).duplicate(true)
	return session

