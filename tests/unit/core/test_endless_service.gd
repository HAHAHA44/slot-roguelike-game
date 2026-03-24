extends GutTest

func test_endless_target_increases_predictably() -> void:
	var service_script := load("res://scripts/core/services/endless_service.gd")

	assert_not_null(service_script)
	if service_script == null:
		return

	var service = service_script.new()

	assert_gt(service.get_target_for_loop(2), service.get_target_for_loop(1))
	assert_eq(service.get_target_for_loop(3), 45)

