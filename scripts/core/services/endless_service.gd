class_name EndlessService
extends RefCounted

const BASE_TARGET := 25
const TARGET_STEP := 10

func get_target_for_loop(loop_index: int) -> int:
	var normalized_loop: int = max(loop_index, 1)
	return BASE_TARGET + (normalized_loop - 1) * TARGET_STEP

func apply_anomaly(base_context: Dictionary, anomaly_definition: AnomalyDefinition) -> Dictionary:
	var context := base_context.duplicate(true)
	if anomaly_definition == null:
		return context

	var rules: Dictionary = anomaly_definition.rules
	if rules.has("board_width"):
		context["width"] = int(rules["board_width"])
	if rules.has("board_height"):
		context["height"] = int(rules["board_height"])
	if rules.has("temporary"):
		context["temporary"] = bool(rules["temporary"])
	if rules.has("bonus_columns"):
		context["bonus_columns"] = int(rules["bonus_columns"])
	if rules.has("spawn_shape"):
		context["spawn_shape"] = String(rules["spawn_shape"])
	if rules.has("extra_spawn_count"):
		context["extra_spawn_count"] = int(rules["extra_spawn_count"])
	context["anomaly_id"] = anomaly_definition.id
	context["anomaly_type"] = anomaly_definition.anomaly_type
	return context
