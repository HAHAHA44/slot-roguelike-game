# 通用模态选择面板：标题 + 正文 + 若干竖排选项卡（+ 可选的「跳过」）。
# - 三选一抽碎片与转折年事件共用它：两者的形状本来就是「读一段话，点一个选项」。
#   为一样的交互写两套 UI 只会让两边慢慢长歪。
# - 选项**竖排成整行的卡**，每张左边留一块固定的图位：现在显示名字首字，
#   等碎片有了立绘，塞进 option 的 "icon" 就直接顶上去，版式不用再动一次。
#   横排三个小按钮换不出这块地方——竖排是为了给图腾地方，不只是好看。
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
const COLOR_ART_BG := Color(0.15, 0.15, 0.20)
const COLOR_ART_GLYPH := Color(0.70, 0.66, 0.50)

# 面板宽度。竖排整行卡要放得下「图位 + 两行说明」，比横排三按钮时宽。
const PANEL_WIDTH := 620.0
# 一张选项卡的高度，也是图位的高度基准。
const OPTION_HEIGHT := 104.0
# 左侧图位的边长。等有了立绘直接填进这块，不用改版式。
const ART_SIZE := 72.0

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
	frame.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
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
	_body_label.custom_minimum_size = Vector2(PANEL_WIDTH - 48.0, 0)
	body.add_child(_body_label)

	_option_box = VBoxContainer.new()
	_option_box.add_theme_constant_override("separation", 10)
	body.add_child(_option_box)

	_skip_button = Button.new()
	_skip_button.custom_minimum_size = Vector2(0, 40)
	_skip_button.pressed.connect(func(): skipped.emit())
	body.add_child(_skip_button)

# 主入口。options 每项：
#   {"text": String, "subtext": String, "disabled": bool, "icon": Texture2D}
# icon 缺省时图位显示名字首字；有立绘了填进来就自动顶上。
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
		var button := _build_option(options[i], i)
		_option_box.add_child(button)
		_option_buttons.append(button)

# 一张选项卡：整行是个 Button，内容用 MarginContainer 铺满它。
# Button 自己不排版子节点，所以内容容器要显式铺满；且所有子节点都必须
# MOUSE_FILTER_IGNORE，否则点在文字上时事件被子控件吃掉，按钮收不到 pressed。
func _build_option(entry: Dictionary, index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, OPTION_HEIGHT)
	button.disabled = bool(entry.get("disabled", false))
	button.pressed.connect(func(): chosen.emit(index))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	# 禁用态整块压暗，让「拿不了」一眼可见（Button 的 disabled 只淡化自带 text，
	# 而我们的文字在子节点上，不受它影响）。
	margin.modulate = Color(1, 1, 1, 0.45) if button.disabled else Color(1, 1, 1, 1)
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var text_value := String(entry.get("text", ""))
	row.add_child(_build_art_slot(entry.get("icon", null), text_value))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)

	var title := Label.new()
	title.text = text_value
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", COLOR_BODY)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)

	var subtext := String(entry.get("subtext", ""))
	if not subtext.is_empty():
		var sub := Label.new()
		sub.text = subtext
		sub.add_theme_font_size_override("font_size", 13)
		sub.add_theme_color_override("font_color", COLOR_SUB)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(sub)
	return button

# 左侧固定图位。有 icon 就画 icon，没有就画名字首字当占位——
# 这块地方的尺寸不随内容变，所以将来换成立绘时版式一行都不用改。
func _build_art_slot(icon, display_name: String) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(ART_SIZE, ART_SIZE)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ART_BG
	style.set_corner_radius_all(6)
	slot.add_theme_stylebox_override("panel", style)

	if icon is Texture2D:
		var texture := TextureRect.new()
		texture.texture = icon
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(texture)
		return slot

	var glyph := Label.new()
	glyph.text = display_name.substr(0, 1) if not display_name.is_empty() else "?"
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 32)
	glyph.add_theme_color_override("font_color", COLOR_ART_GLYPH)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(glyph)
	return slot
