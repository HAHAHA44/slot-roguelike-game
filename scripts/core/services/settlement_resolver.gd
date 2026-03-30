# 结算解析器：
# - 对外暴露 `resolve_board(board, registry)`，内部先构建 RunSnapshot，再按 phase 展开成 SettlementReport。
# - `build_snapshot(board, registry)` 也作为公开方法，供 EventDraftService 等只需要快照的调用方使用。
# - 它是纯规则层：不碰 UI，不直接改 RunSession，具备保护阈值避免死循环。
class_name SettlementResolver
extends RefCounted

const PHASES: Array[String] = [
	"base_output",
	"adjacency",
	"row_column",
	"conditional",
	"copy_amplify",
	"cleanup",
]

const MAX_ITERATION_DEPTH := 16
const MAX_TRIGGER_COUNT_PER_TOKEN := 8
const EMPTY_TOKEN_ID := "empty_token"

# ---------------------------------------------------------------------------
# 公开 API
# ---------------------------------------------------------------------------

func resolve_board(board: BoardService, registry: ContentRegistry) -> SettlementReport:
	var snapshot := build_snapshot(board, registry)
	return resolve(snapshot)

func build_snapshot(board: BoardService, registry: ContentRegistry) -> RunSnapshot:
	var tokens_in_order: Array = []
	var board_tags: Dictionary = {}

	for row in board.height:
		for column in board.width:
			var pos := Vector2i(column, row)
			if board.has_token(pos):
				var token = board.get_token(pos)
				tokens_in_order.append(token)
				for tag in token.tags:
					board_tags[tag] = int(board_tags.get(tag, 0)) + 1

	var phase_effects: Dictionary = {}
	phase_effects["board_tags"] = board_tags

	# base_output：每个非空 token 贡献 base_value 分
	var base_effects: Array = []
	for token in tokens_in_order:
		if token.definition_id == EMPTY_TOKEN_ID:
			continue
		var definition: TokenDefinition = registry.tokens.get(token.definition_id)
		var base_val: int = definition.base_value if definition else 1
		base_effects.append(_make_effect(token.definition_id, "base_output", base_val))
	if base_effects.size() > 0:
		phase_effects["base_output"] = base_effects

	phase_effects["cleanup"] = [_make_effect("system", "cleanup", 0)]

	return RunSnapshot.new(phase_effects)

func resolve(snapshot: RunSnapshot) -> SettlementReport:
	var report := SettlementReport.new()
	var sequence_index := 0
	var trigger_counts: Dictionary = {}

	report.phases = PHASES.duplicate()

	for phase in PHASES:
		var phase_steps: Array = snapshot.get_phase_effects(phase)
		for effect in phase_steps:
			if sequence_index >= MAX_ITERATION_DEPTH:
				report.warnings.append("settlement stopped at MAX_ITERATION_DEPTH")
				return report

			var source_token := String(effect.get("source_token", ""))
			var trigger_count := int(trigger_counts.get(source_token, 0))
			if trigger_count >= MAX_TRIGGER_COUNT_PER_TOKEN:
				report.warnings.append("token %s exceeded MAX_TRIGGER_COUNT_PER_TOKEN" % source_token)
				continue

			trigger_counts[source_token] = trigger_count + 1

			var step := SettlementStep.new(
				sequence_index,
				source_token,
				phase,
				int(effect.get("score_delta", 0)),
				String(effect.get("target_token", "")),
				String(effect.get("message_key", "")),
			)
			report.steps.append(step)
			report.total_score_delta += step.score_delta
			sequence_index += 1

	if report.steps.size() < _count_requested_steps(snapshot):
		report.warnings.append("settlement stopped early because a trigger limit was hit")

	return report

# ---------------------------------------------------------------------------
# 私有辅助
# ---------------------------------------------------------------------------

func _make_effect(source_token: String, phase_name: String, score_delta: int) -> Dictionary:
	return {
		"source_token": source_token,
		"target_token": source_token,
		"score_delta": score_delta,
		"message_key": phase_name,
	}

func _count_requested_steps(snapshot: RunSnapshot) -> int:
	var total := 0
	for phase in PHASES:
		total += snapshot.get_phase_effects(phase).size()
	return total
