# DisplaySettingsService 契约（只测纯映射，不碰 user://settings.cfg，免得动到真实设置）：
# - 两档 1k/2k，默认 1k；已知键映射到正确分辨率；未知键退默认；label 含分辨率数字。
extends GutTest

const DisplaySettingsServiceScript := preload("res://scripts/core/services/display_settings_service.gd")

var _svc

func before_each() -> void:
	_svc = DisplaySettingsServiceScript.new()

func test_default_key_is_1k() -> void:
	assert_eq(DisplaySettingsServiceScript.DEFAULT_KEY, "1k", "默认档是 1K")

func test_ordered_keys_are_1k_then_2k() -> void:
	assert_eq(_svc.ordered_keys(), ["1k", "2k"], "两档且 1K 在前")

func test_resolution_for_known_keys() -> void:
	assert_eq(_svc.resolution_for("1k"), Vector2i(1920, 1080), "1K = 1920×1080")
	assert_eq(_svc.resolution_for("2k"), Vector2i(2560, 1440), "2K = 2560×1440")

func test_resolution_for_unknown_falls_back_to_default() -> void:
	assert_eq(_svc.resolution_for("nope"), Vector2i(1920, 1080), "未知档退回默认 1K")

func test_is_valid() -> void:
	assert_true(_svc.is_valid("1k"))
	assert_true(_svc.is_valid("2k"))
	assert_false(_svc.is_valid("4k"))

func test_label_contains_resolution() -> void:
	assert_string_contains(_svc.label_for("1k"), "1920")
	assert_string_contains(_svc.label_for("2k"), "2560")
