class_name EventDefinition
extends Resource

const ALLOWED_TYPES := ["instant", "lasting", "crisis"]

@export var id: String = ""
@export var name: String = ""
@export var type: String = "instant"
@export var tags_affected: PackedStringArray = PackedStringArray()
@export var duration: int = 0
@export var contract_template: Dictionary = {}
@export var reward_bundle: Dictionary = {}
@export var penalty_bundle: Dictionary = {}

