class_name TokenInstance
extends RefCounted

const SCHEMA_VERSION := 1

var definition_id: String
var tags: PackedStringArray
var state: Dictionary

func _init(initial_definition_id: String = "", initial_tags: PackedStringArray = PackedStringArray(), initial_state: Dictionary = {}) -> void:
	definition_id = initial_definition_id
	tags = initial_tags
	state = initial_state.duplicate(true)

func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"definition_id": definition_id,
		"tags": tags,
		"state": state.duplicate(true),
	}

static func from_dict(data: Dictionary) -> TokenInstance:
	return TokenInstance.new(
		String(data.get("definition_id", "")),
		data.get("tags", PackedStringArray()),
		data.get("state", {}),
	)
