# 局外成长服务：
# - 根据一局运行结果，维护长期解锁状态，例如新英雄、元节点或 meta 内容。
# - 它的输入应该是“跑完一局后的结果数据”，输出是“哪些 meta 节点现在可用”。
# - 配合 `SaveService` 可以把这些解锁结果持久化到存档中。
# - 它不参与单局回合结算，只处理局外进度。
class_name MetaProgressionService
extends RefCounted

var unlock_definitions: Dictionary = {}
var unlocked_ids: Dictionary = {}

func _init(definitions: Array = []) -> void:
	for definition in definitions:
		if definition == null:
			continue
		unlock_definitions[definition.id] = definition

func apply_run_result(run_result: Dictionary) -> void:
	if not bool(run_result.get("victory", false)):
		return

	for unlock_id in run_result.get("unlock_ids", []):
		if unlock_definitions.has(unlock_id):
			unlocked_ids[unlock_id] = true

func is_unlocked(unlock_id: String) -> bool:
	return bool(unlocked_ids.get(unlock_id, false))

func unlocked_list() -> Array[String]:
	var result: Array[String] = []
	for unlock_id in unlocked_ids.keys():
		result.append(String(unlock_id))
	result.sort()
	return result

func to_dict() -> Dictionary:
	return {
		"unlocked_ids": unlocked_list(),
	}

static func from_dict(data: Dictionary, definitions: Array = []) -> MetaProgressionService:
	var service := MetaProgressionService.new(definitions)
	for unlock_id in data.get("unlocked_ids", []):
		service.unlocked_ids[String(unlock_id)] = true
	return service
