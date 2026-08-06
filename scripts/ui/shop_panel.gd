# 道具商店面板：
# - 每年年末摆 4 件道具，玩家用当年购买力买。买完不关，可以连买几件再走
#   （与三选一不同：三选一是一次性抉择，商店是花光当年预算）。
# - 价格单位是**阶段门槛的倍数**，不是绝对数字（见 EconomyService 的相对计价），
#   所以显示的是「0.5 基准」而不是「600 分」——绝对数字会随年份指数膨胀，读不出贵贱。
# - 剩余购买力离开时作废，标题栏如实写着，不藏。
# - 纯展示 + 发信号：买不买由 RunScreen 走 ShopService 决定。
class_name ShopPanel
extends Control

signal buy_requested(stock_index: int)
signal closed()

const COLOR_PANEL_BG := Color(0.09, 0.09, 0.13, 0.98)
const COLOR_SCRIM := Color(0, 0, 0, 0.5)
const COLOR_DIM := Color(0.62, 0.63, 0.72)
const COLOR_GOLD := Color(0.93, 0.79, 0.36)

var _stock: Array = []
var _rows: Array[Button] = []
var _title_label: Label
var _power_label: Label
var _row_box: VBoxContainer

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()

func open(stock: Array, purchasing_power: float) -> void:
	refresh(stock, purchasing_power)
	visible = true

func close() -> void:
	visible = false
	closed.emit()

func is_open() -> bool:
	return visible

func stock_size() -> int:
	return _stock.size()

# 测试与 autoplay 用：不经过鼠标直接买。
func press_buy(index: int) -> bool:
	if index < 0 or index >= _rows.size() or _rows[index].disabled:
		return false
	buy_requested.emit(index)
	return true

func refresh(stock: Array, purchasing_power: float) -> void:
	if _row_box == null:
		return
	_stock = stock
	_power_label.text = L10n.format_text("ui.shop.power", {"power": "%.2f" % purchasing_power},
		"购买力 %.2f 基准（离开时作废）" % purchasing_power)
	for row in _rows:
		row.queue_free()
	_rows.clear()
	if _stock.is_empty():
		var empty := Button.new()
		empty.text = L10n.text("ui.shop.empty", "今年没有可买的道具")
		empty.disabled = true
		empty.custom_minimum_size = Vector2(0, 48)
		_row_box.add_child(empty)
		_rows.append(empty)
		return
	for i in _stock.size():
		var def = _stock[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 64)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 15)
		button.text = "%s · %.2f 基准\n%s" % [def.get_display_name(), float(def.price),
			def.describe_effect()]
		button.disabled = purchasing_power < float(def.price)
		var index := i
		button.pressed.connect(func(): buy_requested.emit(index))
		_row_box.add_child(button)
		_rows.append(button)

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
	frame.custom_minimum_size = Vector2(600, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.set_corner_radius_all(10)
	style.set_content_margin_all(22)
	style.border_color = Color(0.30, 0.31, 0.40)
	style.set_border_width_all(1)
	frame.add_theme_stylebox_override("panel", style)
	center.add_child(frame)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	frame.add_child(body)

	_title_label = Label.new()
	_title_label.text = L10n.text("ui.shop.title", "道具")
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", COLOR_GOLD)
	body.add_child(_title_label)

	_power_label = Label.new()
	_power_label.add_theme_font_size_override("font_size", 14)
	_power_label.add_theme_color_override("font_color", COLOR_DIM)
	body.add_child(_power_label)

	_row_box = VBoxContainer.new()
	_row_box.add_theme_constant_override("separation", 8)
	body.add_child(_row_box)

	var close_button := Button.new()
	close_button.text = L10n.text("ui.shop.close", "离开")
	close_button.custom_minimum_size = Vector2(0, 42)
	close_button.pressed.connect(close)
	body.add_child(close_button)
