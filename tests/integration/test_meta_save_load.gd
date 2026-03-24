extends GutTest

const TEST_SLOT_ID := "gut_meta_slot"

func test_win_result_unlocks_meta_node_and_persists_to_save() -> void:
	var meta_service_script := load("res://scripts/meta/meta_progression_service.gd")
	var save_service_script := load("res://autoload/save_service.gd")
	var unlock_definition := load("res://content/meta/hero_flux.tres")

	assert_not_null(meta_service_script)
	assert_not_null(save_service_script)
	assert_not_null(unlock_definition)
	if meta_service_script == null or save_service_script == null or unlock_definition == null:
		return

	var meta_service = meta_service_script.new([unlock_definition])
	var save_service = save_service_script.new()

	save_service.delete_slot(TEST_SLOT_ID)
	meta_service.apply_run_result({
		"victory": true,
		"score": 24,
		"unlock_ids": ["hero_flux"],
	})

	assert_true(meta_service.is_unlocked("hero_flux"))

	save_service.save_slot(TEST_SLOT_ID, meta_service.to_dict())
	var loaded_data: Dictionary = save_service.load_slot(TEST_SLOT_ID)
	var restored = meta_service_script.from_dict(loaded_data, [unlock_definition])

	assert_true(restored.is_unlocked("hero_flux"))
	save_service.delete_slot(TEST_SLOT_ID)
