extends GutTest

const EXPECTED_PHASES := [
	"base_output",
	"adjacency",
	"row_column",
	"conditional",
	"copy_amplify",
	"cleanup",
]

func test_settlement_order_matches_prd() -> void:
	var resolver_script := load("res://scripts/core/services/settlement_resolver.gd")
	var snapshot_script := load("res://scripts/core/value_objects/run_snapshot.gd")

	assert_not_null(resolver_script)
	assert_not_null(snapshot_script)
	if resolver_script == null or snapshot_script == null:
		return

	var resolver = resolver_script.new()
	var report = resolver.resolve(_fixture_snapshot(snapshot_script))

	assert_eq(report.phases, EXPECTED_PHASES)

func test_sequence_index_is_monotonic_for_ui_playback() -> void:
	var resolver_script := load("res://scripts/core/services/settlement_resolver.gd")
	var snapshot_script := load("res://scripts/core/value_objects/run_snapshot.gd")

	assert_not_null(resolver_script)
	assert_not_null(snapshot_script)
	if resolver_script == null or snapshot_script == null:
		return

	var resolver = resolver_script.new()
	var report = resolver.resolve(_fixture_snapshot(snapshot_script))
	var indices: Array[int] = []

	for step in report.steps:
		indices.append(step.sequence_index)

	assert_eq(indices, [0, 1, 2, 3, 4, 5])

func test_cleanup_phase_runs_last() -> void:
	var resolver_script := load("res://scripts/core/services/settlement_resolver.gd")
	var snapshot_script := load("res://scripts/core/value_objects/run_snapshot.gd")

	assert_not_null(resolver_script)
	assert_not_null(snapshot_script)
	if resolver_script == null or snapshot_script == null:
		return

	var resolver = resolver_script.new()
	var report = resolver.resolve(_fixture_snapshot(snapshot_script))

	assert_eq(report.steps.back().phase, "cleanup")

func test_iteration_limit_adds_warning_and_caps_steps() -> void:
	var resolver_script := load("res://scripts/core/services/settlement_resolver.gd")
	var snapshot_script := load("res://scripts/core/value_objects/run_snapshot.gd")

	assert_not_null(resolver_script)
	assert_not_null(snapshot_script)
	if resolver_script == null or snapshot_script == null:
		return

	var resolver = resolver_script.new()
	var report = resolver.resolve(_fixture_recursive_snapshot(snapshot_script))

	assert_true(report.warnings.size() > 0)
	assert_lte(report.steps.size(), resolver.MAX_ITERATION_DEPTH)

func _fixture_snapshot(snapshot_script: GDScript):
	return snapshot_script.new({
		"base_output": [
			{"source_token": "pulse_seed", "target_token": "pulse_seed", "score_delta": 1, "message_key": "base_output"}
		],
		"adjacency": [
			{"source_token": "anchor_glyph", "target_token": "pulse_seed", "score_delta": 2, "message_key": "adjacency"}
		],
		"row_column": [
			{"source_token": "relay_prism", "target_token": "wild_signal", "score_delta": 3, "message_key": "row_column"}
		],
		"conditional": [
			{"source_token": "wild_signal", "target_token": "wild_signal", "score_delta": 4, "message_key": "conditional"}
		],
		"copy_amplify": [
			{"source_token": "relay_prism", "target_token": "pulse_seed", "score_delta": 5, "message_key": "copy_amplify"}
		],
		"cleanup": [
			{"source_token": "hollow_shell", "target_token": "hollow_shell", "score_delta": 6, "message_key": "cleanup"}
		]
	})

func _fixture_recursive_snapshot(snapshot_script: GDScript):
	var repeated_steps: Array[Dictionary] = []
	for index in 20:
		repeated_steps.append({
			"source_token": "wild_signal",
			"target_token": "wild_signal",
			"score_delta": index + 1,
			"message_key": "loop_step_%s" % index,
		})

	return snapshot_script.new({
		"conditional": repeated_steps
	})
