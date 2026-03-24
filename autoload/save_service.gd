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
