# 12 格生肖盘 UI 控件（M1 双层圆环）：
# - 飞镖盘式的两条同心环带，共用同一组 12 条扇区边界（每格 30°）：
#   * 外环 = 槽位的生肖身份（鼠–猪，固定不变）
#   * 内环 = 当年投在这格上的 token（每年洗牌后变化）
#   两条环带同格对齐，所以「内环相邻」和「槽位相邻」是同一件事——
#   ModifyNeighbor 的邻接联动在视觉上就是内环左右挨着的两块。
# - slot 0（鼠）在 12 点钟方向，顺时针 30°/格。扇区以该角度为中心，左右各 15°。
# - 装饰：本命年 = 整个楔形描金边；当年奖励格 = 描青绿边；两者同格时金边优先、底色转暖。
# - 纯展示：不持有数据，每次 refresh() 由 RunScreen 推入；RunScreen 是状态源头。
# - 不做动画 / 数字弹跳 / 连线（那些是 T1.6 的活，数据在 CascadeReport.steps 里）。
class_name ZodiacRing
extends Control

const RING_SIZE := 12
const SECTOR_SPAN := TAU / float(RING_SIZE)
# 扇区之间留的缝，让相邻两块分得开（弧度）。
const SECTOR_GAP := 0.012
# 每条弧用多少段折线近似。12 段在 420px 直径下已经看不出棱角。
const ARC_STEPS := 12

# 半径按控件最短边的比例取，保证缩放时版式不变。
# 内环比外环厚：内环放 token 名（两个字），外环放生肖（一个字），
# 而内环半径更小、同样 30° 对应的弧长更短——需要更多空间的那圈反而更窄，得补回来。
const RATIO_OUTER := 0.48
const RATIO_MID := 0.355
const RATIO_INNER := 0.15

const COLOR_ZODIAC_BG := Color(0.13, 0.13, 0.17, 1.0)
const COLOR_ZODIAC_BG_ALT := Color(0.16, 0.16, 0.21, 1.0)
const COLOR_TOKEN_BG := Color(0.19, 0.20, 0.26, 1.0)
const COLOR_TOKEN_BG_ALT := Color(0.22, 0.23, 0.30, 1.0)
const COLOR_TOKEN_BG_EMPTY := Color(0.11, 0.11, 0.14, 1.0)
const COLOR_ZODIAC_TEXT := Color(0.72, 0.73, 0.78, 1.0)
const COLOR_TOKEN_TEXT := Color(0.94, 0.94, 0.96, 1.0)
const COLOR_BIRTH_BORDER := Color(1.0, 0.82, 0.20, 1.0)
const COLOR_CURRENT_BORDER := Color(0.30, 0.85, 0.55, 1.0)
const COLOR_BIRTH_TINT := Color(0.32, 0.22, 0.08, 1.0)

var _zodiac_labels: Array[Label] = []
var _token_labels: Array[Label] = []
var _zodiac_service = null
var _tokens: Dictionary = {}
# 每格当前的 token id，refresh() 写入，_draw() 读取。
var _slot_token_ids: PackedStringArray = PackedStringArray()
var _current_slot: int = -1
var _birth_slot: int = -1

func _ready() -> void:
	custom_minimum_size = Vector2(420, 420)
	_slot_token_ids.resize(RING_SIZE)
	_build_labels()
	resized.connect(_on_resized)
	_layout_labels()

# 由 RunScreen 在创建 ZodiacService 之后调用一次。
# tokens 是 ContentRegistry.tokens（id -> TokenDefinition），用来把 token id 显示成名字。
func bind_content(zodiac_service, tokens: Dictionary) -> void:
	_zodiac_service = zodiac_service
	_tokens = tokens
	_refresh_zodiac_labels()
	queue_redraw()

# 主刷新入口。current_slot 是当年奖励格，birth_slot 是出生生肖所在格；-1 表示不显示该装饰。
func refresh(ring_board, current_slot: int, birth_slot: int) -> void:
	if _token_labels.is_empty():
		return
	_current_slot = current_slot
	_birth_slot = birth_slot
	for slot in RING_SIZE:
		var token_id: String = ""
		if ring_board != null:
			token_id = ring_board.token_at(slot)
		_slot_token_ids[slot] = token_id
		_apply_token_label(slot, token_id)
	queue_redraw()

# -- 绘制 --------------------------------------------------------------------

func _draw() -> void:
	var center := size * 0.5
	var unit: float = minf(size.x, size.y)
	var r_outer: float = unit * RATIO_OUTER
	var r_mid: float = unit * RATIO_MID
	var r_inner: float = unit * RATIO_INNER

	for slot in RING_SIZE:
		var a_start: float = _sector_start(slot)
		var a_end: float = _sector_end(slot)
		var is_birth: bool = slot == _birth_slot
		var is_current: bool = slot == _current_slot
		var alternate: bool = slot % 2 == 1

		# 外环：生肖身份。
		var zodiac_bg := COLOR_ZODIAC_BG_ALT if alternate else COLOR_ZODIAC_BG
		if is_birth:
			zodiac_bg = COLOR_BIRTH_TINT
		draw_colored_polygon(
			_annular_sector(center, r_mid, r_outer, a_start, a_end), zodiac_bg)

		# 内环：当年投上来的 token。空槽用更暗的底，一眼看出这格没牌。
		var token_bg := COLOR_TOKEN_BG_ALT if alternate else COLOR_TOKEN_BG
		if _slot_token_ids[slot].is_empty():
			token_bg = COLOR_TOKEN_BG_EMPTY
		draw_colored_polygon(
			_annular_sector(center, r_inner, r_mid, a_start, a_end), token_bg)

		# 装饰描边套整个楔形（内外环一起），因为本命年 / 当年格是「这一格」的属性。
		if is_birth or is_current:
			var outline := _annular_sector(center, r_inner, r_outer, a_start, a_end)
			outline.append(outline[0])
			var border_color := COLOR_BIRTH_BORDER if is_birth else COLOR_CURRENT_BORDER
			var border_width: float = 3.0 if is_birth else 2.0
			draw_polyline(outline, border_color, border_width, true)

	# 内外环之间的分隔线，强调这是两条独立的环带。
	draw_arc(center, r_mid, 0.0, TAU, ARC_STEPS * RING_SIZE, Color(0, 0, 0, 0.45), 1.5, true)

func _sector_start(slot: int) -> float:
	return -PI * 0.5 + SECTOR_SPAN * float(slot) - SECTOR_SPAN * 0.5 + SECTOR_GAP

func _sector_end(slot: int) -> float:
	return -PI * 0.5 + SECTOR_SPAN * float(slot) + SECTOR_SPAN * 0.5 - SECTOR_GAP

# 环形扇区多边形：外弧正向走一遍，内弧反向走回来，闭合成一块环带。
func _annular_sector(center: Vector2, r_in: float, r_out: float,
		a_start: float, a_end: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in ARC_STEPS + 1:
		var t: float = float(i) / float(ARC_STEPS)
		var a: float = lerpf(a_start, a_end, t)
		points.append(center + Vector2(cos(a), sin(a)) * r_out)
	for i in range(ARC_STEPS, -1, -1):
		var t: float = float(i) / float(ARC_STEPS)
		var a: float = lerpf(a_start, a_end, t)
		points.append(center + Vector2(cos(a), sin(a)) * r_in)
	return points

# -- 标签 --------------------------------------------------------------------

func _build_labels() -> void:
	for slot in RING_SIZE:
		_zodiac_labels.append(_make_label(17, COLOR_ZODIAC_TEXT))
		_token_labels.append(_make_label(19, COLOR_TOKEN_TEXT))

func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.text = ""
	add_child(label)
	return label

func _on_resized() -> void:
	_layout_labels()
	queue_redraw()

func _layout_labels() -> void:
	if _token_labels.is_empty():
		return
	var center := size * 0.5
	var unit: float = minf(size.x, size.y)
	var r_zodiac: float = unit * (RATIO_MID + RATIO_OUTER) * 0.5
	var r_token: float = unit * (RATIO_INNER + RATIO_MID) * 0.5
	# 标签框略窄于扇区在该半径处的弧长，避免视觉上压到相邻扇区。
	var label_size := Vector2(unit * 0.14, unit * 0.08)

	for slot in RING_SIZE:
		var angle: float = -PI * 0.5 + SECTOR_SPAN * float(slot)
		var dir := Vector2(cos(angle), sin(angle))
		_place_label(_zodiac_labels[slot], center + dir * r_zodiac, label_size)
		_place_label(_token_labels[slot], center + dir * r_token, label_size)

func _place_label(label: Label, at: Vector2, label_size: Vector2) -> void:
	label.size = label_size
	label.position = at - label_size * 0.5

func _refresh_zodiac_labels() -> void:
	if _zodiac_service == null:
		return
	for slot in RING_SIZE:
		var z = _zodiac_service.get_by_order(slot)
		_zodiac_labels[slot].text = z.get_display_name() if z != null else "?"

func _apply_token_label(slot: int, token_id: String) -> void:
	var label := _token_labels[slot]
	if token_id.is_empty():
		label.text = ""
		return
	var def = _tokens.get(token_id, null)
	# 查不到定义时退回显示 id，比显示空白更容易定位内容配错。
	label.text = def.get_display_name() if def != null else token_id
