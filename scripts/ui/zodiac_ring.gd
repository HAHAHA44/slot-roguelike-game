# 12 格生肖盘 UI 控件（M0 可视化层）：
# - 纯展示：把 RingBoardService 上 12 槽的 token id 渲染成圆周上 12 个 slot panel。
# - 圆心 = 自身中心，slot 0（鼠）在 12 点钟方向，顺时针 30°/格（鼠→牛→…→猪）。
# - 每个 slot 显示生肖单字 + 两种装饰：本命年（粗金边）/ 当年奖励格（绿描边）。
# - 不持有数据，每次 refresh() 由 RunScreen 推入；RunScreen 是状态源头。
# - 不做动画 / 数字弹跳（那些是 M1 cascade 的活）。
class_name ZodiacRing
extends Control

const RING_SIZE := 12
const SLOT_SIZE := Vector2(72, 72)
# 圆周占控件最短边的比例，留边距给描边和数字。
const RADIUS_RATIO := 0.40

# 颜色策略：基础 = 中性灰底；本命年 = 金描边；当年奖励格 = 青绿描边；两者叠加用双层 Panel。
const COLOR_SLOT_BG := Color(0.16, 0.16, 0.20, 1.0)
const COLOR_SLOT_TEXT := Color(0.92, 0.92, 0.94, 1.0)
const COLOR_BIRTH_BORDER := Color(1.0, 0.82, 0.20, 1.0)
const COLOR_CURRENT_BORDER := Color(0.30, 0.85, 0.55, 1.0)

var _slot_panels: Array[Panel] = []
var _slot_labels: Array[Label] = []
var _zodiac_service = null

func _ready() -> void:
	custom_minimum_size = Vector2(420, 420)
	_build_slots()
	resized.connect(_layout_slots)
	_layout_slots()

func bind_zodiac_service(zodiac_service) -> void:
	# 由 RunScreen 在创建 ZodiacService 后调用一次。glyph 来自 ZodiacDefinition.display_name。
	_zodiac_service = zodiac_service
	_refresh_labels_from_service()

# 主刷新入口。current_slot 是"当年奖励格" slot 索引（ZodiacService.reward_slot_index）；
# birth_slot 是出生生肖的 slot 索引（zodiac_service.get_by_id(zodiac_birth).order）。
# 传 -1 表示该装饰不显示。
func refresh(ring_board, current_slot: int, birth_slot: int) -> void:
	if _slot_panels.is_empty():
		return
	for slot in RING_SIZE:
		var token_id: String = ""
		if ring_board != null:
			token_id = ring_board.token_at(slot)
		_apply_slot_state(slot, token_id, slot == current_slot, slot == birth_slot)

# -- internals ---------------------------------------------------------------

func _build_slots() -> void:
	for slot in RING_SIZE:
		var panel := Panel.new()
		panel.custom_minimum_size = SLOT_SIZE
		panel.size = SLOT_SIZE
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(panel)

		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.anchor_right = 1.0
		label.anchor_bottom = 1.0
		label.add_theme_font_size_override("font_size", 28)
		label.add_theme_color_override("font_color", COLOR_SLOT_TEXT)
		label.text = "·"
		panel.add_child(label)

		_apply_slot_style(panel, false, false)

		_slot_panels.append(panel)
		_slot_labels.append(label)

func _layout_slots() -> void:
	if _slot_panels.is_empty():
		return
	var center := size * 0.5
	var radius: float = min(size.x, size.y) * RADIUS_RATIO
	for slot in RING_SIZE:
		# 12 点钟方向 = -PI/2；顺时针 = 角度递增。
		var angle: float = -PI * 0.5 + (TAU * float(slot) / float(RING_SIZE))
		var slot_center := center + Vector2(cos(angle), sin(angle)) * radius
		var panel := _slot_panels[slot]
		panel.position = slot_center - panel.size * 0.5

func _refresh_labels_from_service() -> void:
	if _zodiac_service == null:
		return
	for slot in RING_SIZE:
		var z = _zodiac_service.get_by_order(slot)
		if z == null:
			_slot_labels[slot].text = "?"
			continue
		_slot_labels[slot].text = z.get_display_name()

func _apply_slot_state(slot: int, token_id: String, is_current: bool, is_birth: bool) -> void:
	# token_id 决定是否"有人"；M0 stub 每格都会被填，但保留空态以便 M1 真实投放。
	var label := _slot_labels[slot]
	if token_id.is_empty():
		label.modulate = Color(1, 1, 1, 0.35)
	else:
		label.modulate = Color(1, 1, 1, 1)
	_apply_slot_style(_slot_panels[slot], is_current, is_birth)

func _apply_slot_style(panel: Panel, is_current: bool, is_birth: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SLOT_BG
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	# 本命年优先金边；当年格青绿边；同格（本命年命中）→ 金边 + 内描青绿。
	if is_birth:
		style.border_width_left = 4
		style.border_width_right = 4
		style.border_width_top = 4
		style.border_width_bottom = 4
		style.border_color = COLOR_BIRTH_BORDER
		if is_current:
			# 命中本命年：底色偏暖，强调"剧情时刻"。
			style.bg_color = Color(0.32, 0.22, 0.08, 1.0)
	elif is_current:
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_color = COLOR_CURRENT_BORDER
	panel.add_theme_stylebox_override("panel", style)
