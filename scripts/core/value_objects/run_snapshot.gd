class_name RunSnapshot
extends RefCounted

var phase_effects: Dictionary

func _init(initial_phase_effects: Dictionary = {}) -> void:
	phase_effects = initial_phase_effects.duplicate(true)

func get_phase_effects(phase: String) -> Array:
	return phase_effects.get(phase, [])

