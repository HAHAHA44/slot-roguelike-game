class_name EventDefinition
extends Resource

const ALLOWED_TYPES := ["instant", "lasting", "crisis"]
const ALLOWED_STABILITIES := ["stable", "risky", "volatile"]

@export var id: String = ""
@export var name: String = ""
@export var type: String = "instant"
@export var primary_tag: String = ""
@export var stability: String = "stable"
@export var weight: float = 1.0
@export_multiline var description: String = ""
@export var tags_affected: PackedStringArray = PackedStringArray()
@export var duration: int = 0
@export var contract_template: Dictionary = {}
@export var reward_bundle: Dictionary = {}
@export var penalty_bundle: Dictionary = {}
