# 状态面板：展示六维属性 + 攒下的购买力 + 开局携带的 Buff/Debuff。
# - 纯展示：数据由 RunScreen 每次 refresh() 推入，本面板不持有 session。
# - 六维用彩色圆点 + 名 + 值列出；Buff 绿 chip、Debuff 红 chip，都没有则显示「无」。
# - 购买力每年都在涨，但商店 12 年才开一次门——不摆在常驻面板上，玩家有十一年
#   看不见自己攒了多少，也就无从判断这一年的收益值不值。它没有第二个显示位置。
# - 属性加成 / Buff 实际效果都还没设计，这里只如实列出当前值（预留）。
# - 布局在 _build() 里用代码搭：属性行 / chip 数量都是动态的，代码构比手写 .tscn 稳。
class_name StatusPanel
extends PanelContainer

const AttributeServiceScript := preload("res://scripts/core/services/attribute_service.gd")

# 六维展示配置：按 AttributeService.ORDERED_KEYS 的序，配 l10n 名 + 颜色。
const STAT_STYLE := {
	"str": {"key": "ui.stat.str", "fallback": "力量", "color": Color("e5766a")},
	"int": {"key": "ui.stat.int", "fallback": "智力", "color": Color("6ea8e5")},
	"agi": {"key": "ui.stat.agi", "fallback": "敏捷", "color": Color("6fd98c")},
	"end": {"key": "ui.stat.end", "fallback": "耐力", "color": Color("e5a96a")},
	"spr": {"key": "ui.stat.spr", "fallback": "精神力", "color": Color("b98ce6")},
	"luck": {"key": "ui.stat.luck", "fallback": "运气", "color": Color("e6c84d")},
}
const BUFF_BG := Color("1f3a2b")
const BUFF_BORDER := Color("4cd98c")
const DEBUFF_BG := Color("3a1f22")
const DEBUFF_BORDER := Color("e8776a")
const TEXT_DIM := Color("9a9ab0")
const GOLD := Color("edc95c")

var _buffs: Dictionary = {}          # id -> BuffDefinition
var _value_labels: Dictionary = {}   # stat key -> Label
var _power_label: Label
var _buff_flow: HFlowContainer
var _attr_service := AttributeServiceScript.new()

@onready var _body: VBoxContainer = $Body

func _ready() -> void:
	_build()

# 由 RunScreen 在 ContentRegistry 加载后调用一次，供 chip 把 id 显示成名字。
func bind_content(buffs: Dictionary) -> void:
	_buffs = buffs

# 主刷新入口：更新六维数值 + 重建 buff chip。session 是 RunSession。
func refresh(session) -> void:
	if _value_labels.is_empty():
		return
	for key in _value_labels:
		var value: int = _attr_service.get_value(session, key)
		_value_labels[key].text = str(value)
	if _power_label != null:
		var power: float = float(session.purchasing_power) if session != null else 0.0
		_power_label.text = L10n.format_text("ui.status.power_value",
			{"power": "%.2f" % power}, "%.2f 基准" % power)
	_rebuild_chips(session)

# -- 构建 --------------------------------------------------------------------

func _build() -> void:
	_body.add_theme_constant_override("separation", 10)
	_body.add_child(_section_title(L10n.text("ui.status.attributes", "属性")))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	for key in AttributeServiceScript.ORDERED_KEYS:
		grid.add_child(_stat_row(String(key)))
	_body.add_child(grid)

	_body.add_child(HSeparator.new())
	_body.add_child(_power_row())

	_body.add_child(HSeparator.new())
	_body.add_child(_section_title(L10n.text("ui.status.buffs", "机缘")))
	_buff_flow = HFlowContainer.new()
	_buff_flow.add_theme_constant_override("h_separation", 6)
	_buff_flow.add_theme_constant_override("v_separation", 6)
	_body.add_child(_buff_flow)

# 攒下的购买力。单位是「阶段门槛的倍数」而不是绝对数字（见 EconomyService 的
# 相对计价）——绝对数字随年份指数膨胀，读不出贵贱，写「2.50 基准」才知道能买几件。
func _power_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = L10n.text("ui.status.power", "购买力")
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	_power_label = Label.new()
	_power_label.text = "0.00 基准"
	_power_label.add_theme_font_size_override("font_size", 16)
	_power_label.add_theme_color_override("font_color", GOLD)
	_power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_power_label)
	return row

func _section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", TEXT_DIM)
	return label

func _stat_row(key: String) -> Control:
	var style: Dictionary = STAT_STYLE[key]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(132, 0)

	var dot := ColorRect.new()
	dot.color = style["color"]
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)

	var name_label := Label.new()
	name_label.text = L10n.text(style["key"], style["fallback"])
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.text = "0"
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.add_theme_color_override("font_color", style["color"])
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	_value_labels[key] = value_label
	return row

func _rebuild_chips(session) -> void:
	for child in _buff_flow.get_children():
		child.queue_free()
	var any := false
	for buff_id in session.active_buffs:
		_buff_flow.add_child(_chip(String(buff_id), true))
		any = true
	for debuff_id in session.active_debuffs:
		_buff_flow.add_child(_chip(String(debuff_id), false))
		any = true
	if not any:
		var none := Label.new()
		none.text = L10n.text("ui.status.none", "无")
		none.add_theme_color_override("font_color", TEXT_DIM)
		_buff_flow.add_child(none)

func _chip(buff_id: String, positive: bool) -> Control:
	var def = _buffs.get(buff_id, null)
	var display: String = def.get_display_name() if def != null else buff_id
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BUFF_BG if positive else DEBUFF_BG
	sb.border_color = BUFF_BORDER if positive else DEBUFF_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", sb)
	if def != null:
		chip.tooltip_text = def.get_display_description()

	var label := Label.new()
	label.text = display
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", BUFF_BORDER if positive else DEBUFF_BORDER)
	chip.add_child(label)
	return chip
