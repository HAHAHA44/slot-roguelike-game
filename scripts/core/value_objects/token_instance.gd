class_name TokenInstance
extends RefCounted

var definition_id: String
var tags: PackedStringArray
var state: Dictionary

func _init(initial_definition_id: String = "", initial_tags: PackedStringArray = PackedStringArray(), initial_state: Dictionary = {}) -> void:
	definition_id = initial_definition_id
	tags = initial_tags
	state = initial_state.duplicate(true)

func to_dict() -> Dictionary:
	return {
		"definition_id": definition_id,
		"tags": tags,
		"state": state.duplicate(true),
	}

