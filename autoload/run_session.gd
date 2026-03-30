# 本局运行状态：
# - 保存一局游戏里需要跨回合保留的数据，例如分数、回合数、token 池、操作历史、激活的合约修正。
# - `token_pool` 是 bag-roll 的核心数据结构，表示“持久 token 池”，不是单个下一张 token。
# - `pool_*` 系列方法是新循环使用的多重集合接口；`get_active_token_id()` / `token_cursor` 主要给调试手动放置路径使用。
# - `to_dict()` / `from_dict()` 用于存档、回放和测试重建。
# - 典型联动：`RewardOfferService` 改 `token_pool`，`RunScreen` 读 `current_turn/current_score/active_modifiers`，存档系统序列化整个对象。
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

# -- bag-roll pool helpers (concrete multiset, duplicates allowed) ------------

# Append one concrete entry to the pool (duplicates allowed).
func pool_add(token_id: String) -> void:
	token_pool.append(token_id)

# Remove one entry with the given id. Returns true if an entry was removed.
func pool_remove(token_id: String) -> bool:
	var idx := token_pool.find(token_id)
	if idx == -1:
		return false
	token_pool.remove_at(idx)
	return true

# Count how many entries with this id are in the pool.
func pool_count(token_id: String) -> int:
	return token_pool.count(token_id)

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

