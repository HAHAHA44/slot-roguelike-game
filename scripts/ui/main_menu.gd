# 主菜单：开始游戏 / 游戏设置 / 退出游戏
class_name MainMenu
extends Control

const DisplaySettingsServiceScript := preload("res://scripts/core/services/display_settings_service.gd")

@onready var _settings_dialog: AcceptDialog = $SettingsDialog

var _display_settings := DisplaySettingsServiceScript.new()
var _res_option: OptionButton


func _ready() -> void:
	_build_settings_content()


# 设置弹窗内容用代码搭：一行「窗口分辨率」+ OptionButton（1K / 2K）。
func _build_settings_content() -> void:
	_settings_dialog.dialog_text = ""
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var label := Label.new()
	label.text = "窗口分辨率"
	label.add_theme_font_size_override("font_size", 18)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

	_res_option = OptionButton.new()
	_res_option.add_theme_font_size_override("font_size", 18)
	var keys: Array = _display_settings.ordered_keys()
	for i in keys.size():
		_res_option.add_item(String(_display_settings.label_for(String(keys[i]))), i)
	var current: String = _display_settings.load_choice()
	_res_option.select(maxi(0, keys.find(current)))
	_res_option.item_selected.connect(_on_resolution_selected)
	row.add_child(_res_option)

	margin.add_child(row)
	_settings_dialog.add_child(margin)


func _on_resolution_selected(index: int) -> void:
	var keys: Array = _display_settings.ordered_keys()
	if index < 0 or index >= keys.size():
		return
	var key := String(keys[index])
	_display_settings.save_choice(key)
	_display_settings.apply(key)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/run/run_screen.tscn")


func _on_settings_pressed() -> void:
	_settings_dialog.popup_centered()


func _on_quit_pressed() -> void:
	get_tree().quit()
