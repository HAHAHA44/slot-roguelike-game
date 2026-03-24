class_name HeroDefinition
extends Resource

const ALLOWED_ATTRIBUTES := ["Insight", "Resolve", "Flux", "Greed"]

@export var id: String = ""
@export var name: String = ""
@export var starting_passive: String = ""
@export var attribute_bias: String = ""
@export var event_weight_modifiers: Dictionary = {}

