# 通用模态选择面板：标题 + 正文 + 若干选项按钮（+ 可选的「跳过」）。
# - 三选一抽碎片与转折年事件共用它：两者的形状本来就是「读一段话，点一个选项」。
#   为一样的交互写两套 UI 只会让两边慢慢长歪。
# - 整块铺满父级并吃掉鼠标事件，所以打开时底下的按钮点不到——避免玩家在半开的
#   模态上误推进一年。
# - 纯展示 + 发信号：不持有游戏状态，选了什么由 RunScreen 决定怎么办。
class_name ModalChoicePanel
extends Control

# index = 选了第几个选项。
signal chosen(index: int)
# 玩家点了「跳过」（只在 allow_skip 时可能发出）。
signal skipped()

const COLOR_PANEL_BG := Color(0.09, 0.09, 0.13, 0.97)
const COLOR_SCRIM := Color(0, 0, 0, 0.55)
const COLOR_TITLE := Color(0.96, 0.93, 0.80)
const COLOR_BODY := Color(0.86, 0.87, 0.92)
const COLOR_SUB := Color(0.62, 0.63, 0.72)

var _title_label: Label
var _body_label: Label
var _option_box: VBoxContainer
var _skip_button: Button
var _option_buttons: Array[Button] = []

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()

func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = COLOR_SCRIM
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(560, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	style.border_color = Color(0.30, 0.31, 0.40)
	style.set_border_width_all(1)
	frame.add_theme_stylebox_override("panel", style)
	center.add_child(frame)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	frame.add_child(body)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", COLOR_TITLE)
	body.add_child(_title_label)

	_body_label = Label.new()
	_body_label.add_theme_font_size_override("font_size", 15)
	_body_label.add_theme_color_override("font_color", COLOR_BODY)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(512, 0)
	body.add_child(_body_label)

	_option_box = VBoxContainer.new()
	_option_box.add_theme_constant_override("separation", 8)
	body.add_child(_option_box)

	_skip_button = Button.new()
	_skip_button.custom_minimum_size = Vector2(0, 40)
	_skip_button.pressed.connect(func(): skipped.emit())
	body.add_child(_skip_button)

# 主入口。options 每项：{"text": String, "subtext": String, "disabled": bool}。
# skip_text 为空串表示不给跳过按钮。
func open_with(title: String, body_text: String, options: Array, skip_text: String = "") -> void:
	_title_label.text = title
	_body_label.text = body_text
	_body_label.visible = not body_text.is_empty()
	_rebuild_options(options)
	_skip_button.text = skip_text
	_skip_button.visible = not skip_text.is_empty()
	visible = true

func close() -> void:
	visible = false

func is_open() -> bool:
	return visible

func option_count() -> int:
	return _option_buttons.size()

# 测试与 autoplay 用：不经过鼠标直接选。越界返回 false。
func press_option(index: int) -> bool:
	if index < 0 or index >= _option_buttons.size():
		return false
	if _option_buttons[index].disabled:
		return false
	chosen.emit(index)
	return true

func _rebuild_options(options: Array) -> void:
	for button in _option_buttons:
		button.queue_free()
	_option_buttons.clear()
	for i in options.size():
		var entry: Dictionary = options[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 52)
		button.disabled = bool(entry.get("disabled", false))
		var text := String(entry.get("text", ""))
		var subtext := String(entry.get("subtext", ""))
		button.text = "%s\n%s" % [text, subtext] if not subtext.is_empty() else text
		button.add_theme_font_size_override("font_size", 16)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var index := i
		button.pressed.connect(func(): chosen.emit(index))
		_option_box.add_child(button)
		_option_buttons.append(button)
