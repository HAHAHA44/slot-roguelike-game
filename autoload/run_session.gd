class_name RunSession
extends RefCounted

const SCHEMA_VERSION := 1
const DEFAULT_TOKEN_ID := "pulse_seed"

var schema_version: int = SCHEMA_VERSION
var current_turn: int = 1
var phase_index: int = 0
var phase_target: int = 10
var current_score: int = 0
var token_pool: Array[String] = [DEFAULT_TOKEN_ID]
var token_cursor: int = 0
var operation_history: Array = []
var active_modifiers: Array = []

func get_active_token_id() -> String:
	if token_pool.is_empty():
		return DEFAULT_TOKEN_ID
	token_cursor = clampi(token_cursor, 0, token_pool.size() - 1)
	return token_pool[token_cursor]

func focus_token(token_id: String) -> void:
	var index := token_pool.find(token_id)
	if index != -1:
		token_cursor = index

func add_token_to_pool(token_id: String) -> bool:
	if token_id.is_empty():
		return false
	var existing_index := token_pool.find(token_id)
	if existing_index != -1:
		token_cursor = existing_index
		return false
	token_pool.append(token_id)
	token_cursor = token_pool.size() - 1
	return true

func remove_token_from_pool(token_id: String) -> bool:
	if token_pool.size() <= 1:
		return false
	var index := token_pool.find(token_id)
	if index == -1:
		return false
	token_pool.remove_at(index)
	if token_cursor >= token_pool.size():
		token_cursor = token_pool.size() - 1
	token_cursor = max(token_cursor, 0)
	return true

func advance_token_cursor() -> void:
	if token_pool.is_empty():
		token_pool = [DEFAULT_TOKEN_ID]
		token_cursor = 0
		return
	token_cursor = posmod(token_cursor + 1, token_pool.size())

func to_dict() -> Dictionary:
	return {
		"schema_version": schema_version,
		"current_turn": current_turn,
		"phase_index": phase_index,
		"phase_target": phase_target,
		"current_score": current_score,
		"token_pool": token_pool.duplicate(),
		"token_cursor": token_cursor,
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
	session.token_pool = []
	for token_id in data.get("token_pool", [DEFAULT_TOKEN_ID]):
		session.token_pool.append(String(token_id))
	if session.token_pool.is_empty():
		session.token_pool = [DEFAULT_TOKEN_ID]
	session.token_cursor = clampi(int(data.get("token_cursor", 0)), 0, session.token_pool.size() - 1)
	session.operation_history = data.get("operation_history", []).duplicate(true)
	session.active_modifiers = data.get("active_modifiers", []).duplicate(true)
	return session

