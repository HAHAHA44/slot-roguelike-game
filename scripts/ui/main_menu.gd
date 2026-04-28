# 主菜单：开始游戏 / 游戏设置 / 退出游戏
class_name MainMenu
extends Control

@onready var _settings_dialog: AcceptDialog = $SettingsDialog


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/run/run_screen.tscn")


func _on_settings_pressed() -> void:
	_settings_dialog.popup_centered()


func _on_quit_pressed() -> void:
	get_tree().quit()
