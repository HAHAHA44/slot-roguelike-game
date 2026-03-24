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

func _count_requested_steps(snapshot: RunSnapshot) -> int:
	var total := 0
	for phase in PHASES:
		total += snapshot.get_phase_effects(phase).size()
	return total
