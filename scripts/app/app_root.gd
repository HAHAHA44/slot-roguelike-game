# 应用根节点，主菜单由 main_menu.gd 自行管理场景切换。
# 启动时先应用上次选择的窗口分辨率（默认 1K），避免用户上次选 2K 时开场闪一下再放大。
extends Control

const DisplaySettingsServiceScript := preload("res://scripts/core/services/display_settings_service.gd")

func _ready() -> void:
	var settings := DisplaySettingsServiceScript.new()
	settings.apply(settings.load_choice())
