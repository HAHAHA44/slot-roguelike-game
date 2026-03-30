# 存档服务：
# - 负责把单个存档槽读写成 JSON 文件，提供最基础的持久化能力。
# - 目前是轻量实现，适合原型阶段；后续如果需要多槽、版本迁移、加密或云同步，可以在这里扩展。
# - 它不理解游戏规则，只处理“路径、读写、解析、错误处理”。
# - 典型联动：`MetaProgressionService` / `RunSession` / 未来的 meta screen 都可以先把状态转成 `Dictionary`，再交给这里保存。
class_name SaveService
extends RefCounted

const SAVE_PREFIX := "user://reelbound_"
const SAVE_SUFFIX := ".json"

func save_slot(slot_id: String, data: Dictionary) -> bool:
	var file := FileAccess.open(_slot_path(slot_id), FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save slot for writing: %s" % slot_id)
		return false

	file.store_string(JSON.stringify(data))
	return true

func load_slot(slot_id: String) -> Dictionary:
	var path := _slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open save slot for reading: %s" % slot_id)
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func delete_slot(slot_id: String) -> void:
	var path := _slot_path(slot_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func has_slot(slot_id: String) -> bool:
	return FileAccess.file_exists(_slot_path(slot_id))

func _slot_path(slot_id: String) -> String:
	return "%s%s%s" % [SAVE_PREFIX, slot_id, SAVE_SUFFIX]
