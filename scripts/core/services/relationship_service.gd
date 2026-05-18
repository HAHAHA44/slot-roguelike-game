# NPC 关系服务：
# - RunSession.relationships: {npc_id -> {"kind": String, "score": int}}
# - kind 三类（PRD 第 35 行）：family / friend / lover；不强制白名单，调用方自约束。
# - 善终/孤独死判定（M4）从 total_by_kind 衍生，本服务不直接判断。
class_name RelationshipService
extends RefCounted

const KIND_FAMILY := "family"
const KIND_FRIEND := "friend"
const KIND_LOVER := "lover"

func add_npc(session, npc_id: String, kind: String, initial_score: int = 0) -> void:
	if session == null:
		push_error("RelationshipService.add_npc: session 为 null")
		return
	if npc_id.is_empty():
		push_error("RelationshipService.add_npc: npc_id 为空")
		return
	if kind.is_empty():
		push_error("RelationshipService.add_npc: kind 为空")
		return
	if session.relationships.has(npc_id):
		var existing: Dictionary = session.relationships[npc_id]
		if String(existing.get("kind", "")) != kind:
			push_warning("RelationshipService.add_npc: %s 已存在 (kind=%s)，忽略新 kind=%s" % [npc_id, existing.get("kind"), kind])
		return
	session.relationships[npc_id] = {"kind": kind, "score": initial_score}

func adjust(session, npc_id: String, delta: int) -> int:
	if session == null:
		push_error("RelationshipService.adjust: session 为 null")
		return 0
	if not session.relationships.has(npc_id):
		push_warning("RelationshipService.adjust: 未知 npc %s" % npc_id)
		return 0
	var entry: Dictionary = session.relationships[npc_id]
	var new_score: int = int(entry.get("score", 0)) + delta
	entry["score"] = new_score
	session.relationships[npc_id] = entry
	return new_score

func score_of(session, npc_id: String) -> int:
	if session == null:
		return 0
	if not session.relationships.has(npc_id):
		return 0
	return int(session.relationships[npc_id].get("score", 0))

func kind_of(session, npc_id: String) -> String:
	if session == null:
		return ""
	if not session.relationships.has(npc_id):
		return ""
	return String(session.relationships[npc_id].get("kind", ""))

func list_by_kind(session, kind: String) -> Array:
	var result: Array = []
	if session == null:
		return result
	for npc_id in session.relationships.keys():
		if String(session.relationships[npc_id].get("kind", "")) == kind:
			result.append(npc_id)
	return result

func total_by_kind(session, kind: String) -> int:
	var total: int = 0
	if session == null:
		return total
	for npc_id in session.relationships.keys():
		var entry: Dictionary = session.relationships[npc_id]
		if String(entry.get("kind", "")) == kind:
			total += int(entry.get("score", 0))
	return total
