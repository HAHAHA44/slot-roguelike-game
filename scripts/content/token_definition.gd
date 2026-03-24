class_name TokenDefinition
extends Resource

const ALLOWED_RARITIES := ["Common", "Uncommon", "Rare", "Legendary"]

@export var id: String = ""
@export var name: String = ""
@export var rarity: String = "Common"
@export var type: String = ""
@export var tags: PackedStringArray = PackedStringArray()
@export var base_value: int = 0
@export var trigger_rules: Dictionary = {}
@export var state_fields: Dictionary = {}
@export var spawn_rules: Dictionary = {}
@export var remove_rules: Dictionary = {}

