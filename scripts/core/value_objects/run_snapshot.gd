class_name RunSnapshot
extends RefCounted

const SCHEMA_VERSION := 1

var phase_effects: Dictionary

func _init(initial_phase_effects: Dictionary = {}) -> void:
	phase_effects = initial_phase_effects.duplicate(true)

func get_phase_effects(phase: String) -> Array:
	return phase_effects.get(phase, [])

func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"phase_effects": phase_effects.duplicate(true),
	}

static func from_dict(data: Dictionary) -> RunSnapshot:
	return RunSnapshot.new(data.get("phase_effects", {}))

