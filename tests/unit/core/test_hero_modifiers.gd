extends GutTest

func test_resolve_hero_reduces_crisis_penalty() -> void:
	var service_script := load("res://scripts/core/services/run_modifier_service.gd")
	var hero := load("res://content/heroes/resolve_specialist.tres")

	assert_not_null(service_script)
	assert_not_null(hero)
	if service_script == null or hero == null:
		return

	var service = service_script.new()
	var result: Dictionary = service.apply_hero_to_penalty(hero, {"score_penalty": 6})

	assert_eq(result["score_penalty"], 3)

