extends GutTest

func test_project_name_is_configured() -> void:
	assert_true(ProjectSettings.has_setting("application/config/name"))
