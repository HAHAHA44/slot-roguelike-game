# 本局运行状态：
# - M0 起进入"人生模拟"语义：每年 = 一格生肖盘转一圈，整局以"死亡"收束。
# - 新字段（人生模拟）：age / lifespan / sanity / zodiac_birth / stage_idx / stats / karma_in_run
# - 旧字段（5×5 bag-roll，文件保留作历史）：current_turn / current_score / phase_index / phase_target /
#   token_pool / token_cursor / operation_history / active_modifiers。
#   这些字段仍被 reward_offer_service / event_draft_service / settlement_resolver 等遗留服务
#   及其单元测试使用；它们会在 M1+ 被新服务取代后再彻底移除。
# - `to_dict()` / `from_dict()` 同时序列化新旧字段；存档新版可读旧字段（缺失时按默认）。
class_name RunSession
extends RefCounted

const SCHEMA_VERSION := 1
const DEFAULT_TOKEN_ID := "fire_common"

# -- 人生模拟字段（M0+，新流程主用） -----------------------------------------
var age: int = 0
var lifespan: int = 0
var sanity: int = 50
var zodiac_birth: String = ""
var stage_idx: int = 0
var stats: Dictionary = {}
var karma_in_run: int = 0
# NPC 关系表：{npc_id: String -> {"kind": String, "score": int}}。
# kind ∈ {"family", "friend", "lover"}；M4 RelationshipService 维护。
var relationships: Dictionary = {}

# -- 5x5 遗留字段（legacy，等 M1+ 替换 settlement/reward/event 时清理） -------
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
	if token_id.is_empty():
		return
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
		# 人生模拟字段
		"age": age,
		"lifespan": lifespan,
		"sanity": sanity,
		"zodiac_birth": zodiac_birth,
		"stage_idx": stage_idx,
		"stats": stats.duplicate(true),
		"karma_in_run": karma_in_run,
		"relationships": relationships.duplicate(true),
		# 5×5 遗留字段
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
	# 人生模拟字段（新存档读得到，旧存档按默认）
	session.age = int(data.get("age", 0))
	session.lifespan = int(data.get("lifespan", 0))
	session.sanity = int(data.get("sanity", 50))
	session.zodiac_birth = String(data.get("zodiac_birth", ""))
	session.stage_idx = int(data.get("stage_idx", 0))
	var incoming_stats = data.get("stats", {})
	if incoming_stats is Dictionary:
		session.stats = (incoming_stats as Dictionary).duplicate(true)
	else:
		session.stats = {}
	session.karma_in_run = int(data.get("karma_in_run", 0))
	var incoming_relationships = data.get("relationships", {})
	if incoming_relationships is Dictionary:
		session.relationships = (incoming_relationships as Dictionary).duplicate(true)
	else:
		session.relationships = {}
	# 5×5 遗留字段
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
