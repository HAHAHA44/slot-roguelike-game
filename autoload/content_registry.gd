class_name ContentRegistry
extends RefCounted

const TOKEN_PATH := "res://content/tokens"

var tokens: Dictionary = {}
var validator := ContentDefinitionValidator.new()

func load_all() -> void:
	tokens.clear()
	_load_resources_from_dir(TOKEN_PATH, tokens)

func _load_resources_from_dir(dir_path: String, target_index: Dictionary) -> void:
	var directory := DirAccess.open(dir_path)
	if directory == null:
		push_error("Failed to open content directory: %s" % dir_path)
		return

	directory.list_dir_begin()
	while true:
		var file_name := directory.get_next()
		if file_name.is_empty():
			break
		if directory.current_is_dir():
			continue
		if not file_name.ends_with(".tres"):
			continue

		var resource_path := "%s/%s" % [dir_path, file_name]
		var resource := load(resource_path)
		if resource == null:
			push_error("Failed to load content resource: %s" % resource_path)
			continue

		var errors := validator.validate_definition(resource, target_index)
		if not errors.is_empty():
			push_error("Invalid content resource %s: %s" % [resource_path, "; ".join(errors)])
			continue

		target_index[resource.id] = resource
	directory.list_dir_end()

