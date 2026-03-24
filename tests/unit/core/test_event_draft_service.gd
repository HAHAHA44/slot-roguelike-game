extends GutTest

func test_event_draft_biases_towards_board_tags() -> void:
	var service_script := load("res://scripts/core/services/event_draft_service.gd")
	var snapshot_script := load("res://scripts/core/value_objects/run_snapshot.gd")

	assert_not_null(service_script)
	assert_not_null(snapshot_script)
	if service_script == null or snapshot_script == null:
		return

	var service = service_script.new(_fixture_events())
	var draft: Dictionary = service.build_offer(_grow_heavy_snapshot(snapshot_script))
	var option_tags: Array = draft["options"].map(func(event: Dictionary): return event.get("primary_tag", ""))

	assert_eq(draft["options"].size(), 3)
	assert_true(option_tags.has("Grow"))
	assert_true(draft["options"].any(func(event: Dictionary): return event.get("stability", "") == "stable"))

func _fixture_events() -> Array[Dictionary]:
	return [
		{"id": "grow_surge", "primary_tag": "Grow", "stability": "stable", "weight": 1.0},
		{"id": "link_burst", "primary_tag": "Link", "stability": "risky", "weight": 1.0},
		{"id": "break_cascade", "primary_tag": "Break", "stability": "risky", "weight": 1.0},
		{"id": "guard_pact", "primary_tag": "Guard", "stability": "stable", "weight": 1.0},
	]

func _grow_heavy_snapshot(snapshot_script: GDScript):
	return snapshot_script.new({
		"board_tags": {
			"Grow": 4,
			"Link": 1,
			"Break": 0,
			"Guard": 0,
		}
	})
