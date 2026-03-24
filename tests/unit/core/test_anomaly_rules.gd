extends GutTest

func test_temporary_6x6_anomaly_only_expands_board_for_current_loop() -> void:
	var service_script := load("res://scripts/core/services/endless_service.gd")
	var anomaly := load("res://content/anomalies/temporary_6x6.tres")

	assert_not_null(service_script)
	assert_not_null(anomaly)
	if service_script == null or anomaly == null:
		return

	var service = service_script.new()
	var context: Dictionary = service.apply_anomaly({"width": 5, "height": 5}, anomaly)

	assert_eq(context["width"], 6)
	assert_eq(context["height"], 6)
	assert_true(context["temporary"])
