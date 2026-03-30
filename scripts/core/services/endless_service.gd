# Endless / 异常服务：
# - 负责标准通关后的后续循环目标、异常上下文和难度递进。
# - 这里是“后期模式”的规则入口，不参与普通回合的核心结算。
# - 当前实现更偏向基础骨架：给出每圈目标、按异常资源调整上下文，供未来的 endless 流程接手。
# - 典型联动：通关后由 UI 或上层流程把 loop_index / anomaly 传进来，生成下一圈的运行目标。
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
