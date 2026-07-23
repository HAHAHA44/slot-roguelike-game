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
# 外环收到 0.45（原 0.48），在外缘留出跑马灯灯泡的空间。
const RATIO_OUTER := 0.45
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

# -- 老虎机光效（T5：spin / cascade 逐格点亮 / 跑马灯灯泡） --------------------
const BULB_COUNT := 24
const COLOR_BULB_DIM := Color(0.45, 0.38, 0.16, 0.5)
const COLOR_BULB_LIT := Color(1.0, 0.9, 0.55, 1.0)
const COLOR_HIGHLIGHT := Color(1.0, 0.95, 0.72, 1.0)
const COLOR_LINK_ZODIAC := Color(1.0, 0.82, 0.30, 0.9)
const COLOR_LINK_ADJACENT := Color(0.35, 0.85, 0.95, 0.9)
const COLOR_LINK_DEFAULT := Color(0.8, 0.8, 0.85, 0.7)

var _zodiac_labels: Array[Label] = []
var _token_labels: Array[Label] = []
var _zodiac_service = null
var _tokens: Dictionary = {}
# 每格当前的 token id，refresh() 写入，_draw() 读取。
var _slot_token_ids: PackedStringArray = PackedStringArray()
var _current_slot: int = -1
var _birth_slot: int = -1

# 光效状态：_elapsed 驱动跑马灯 + 脉冲相位；_spinning 转盘预滚中；
# _highlight_slot / _highlight_pulse 是 cascade 当前点亮的格；_active_links 是本步连线。
var _elapsed: float = 0.0
var _spinning: bool = false
var _highlight_slot: int = -1
var _highlight_pulse: float = 0.0
var _active_links: Array = []

func _ready() -> void:
	custom_minimum_size = Vector2(420, 420)
	_slot_token_ids.resize(RING_SIZE)
	_build_labels()
	resized.connect(_on_resized)
	_layout_labels()

# 跑马灯 + 脉冲要逐帧动，所以持续重绘（控件小，开销可忽略）。
func _process(delta: float) -> void:
	_elapsed += delta
	if _highlight_pulse > 0.0:
		_highlight_pulse = maxf(0.0, _highlight_pulse - delta * 2.5)
	queue_redraw()

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

# -- 老虎机光效 API（RunScreen 交互路径调用；autoplay/测试不走这里） -------------

# 转盘预滚：内环 token 快速乱跳，再从 slot 0 到 11 依次「停轮」定格到本年真实盘面。
# 协程：await 完再返回。盘面真实数据已在 refresh() 存进 _slot_token_ids，这里只做视觉。
func play_spin(duration: float = 0.7) -> void:
	if _token_labels.is_empty() or _tokens.is_empty():
		return
	_spinning = true
	var scramble_time: float = duration * 0.5
	var t: float = 0.0
	while t < scramble_time:
		_scramble_labels(0)
		await get_tree().create_timer(0.045).timeout
		t += 0.045
	var per: float = maxf(0.02, (duration - scramble_time) / float(RING_SIZE))
	for slot in RING_SIZE:
		_apply_token_label(slot, _slot_token_ids[slot])  # 这一格定格
		_scramble_labels(slot + 1)                        # 后面的继续乱跳
		await get_tree().create_timer(per).timeout
	_spinning = false
	_restore_labels()
	queue_redraw()

# cascade 单步点亮：高亮该格 + 起脉冲 + 记下本步连线（按 kind 配色）。瞬时，不 await。
func highlight_step(step) -> void:
	if step == null:
		return
	_highlight_slot = int(step.slot)
	_highlight_pulse = 1.0
	_active_links = []
	for link in step.chain_links:
		_active_links.append({
			"to": int(link.get("slot", -1)),
			"color": _link_color(String(link.get("kind", ""))),
		})
	queue_redraw()

func clear_highlight() -> void:
	_highlight_slot = -1
	_active_links = []
	_highlight_pulse = 0.0
	queue_redraw()

func _scramble_labels(from_slot: int) -> void:
	var ids: Array = _tokens.keys()
	if ids.is_empty():
		return
	for slot in range(from_slot, RING_SIZE):
		_apply_token_label(slot, String(ids[randi() % ids.size()]))

func _restore_labels() -> void:
	for slot in RING_SIZE:
		_apply_token_label(slot, _slot_token_ids[slot])

func _link_color(kind: String) -> Color:
	if kind == "zodiac":
		return COLOR_LINK_ZODIAC
	if kind == "adjacent":
		return COLOR_LINK_ADJACENT
	return COLOR_LINK_DEFAULT

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

	# 光效层（画在环带之上）：跑马灯灯泡 → 当前格高亮 → 本步连线。
	_draw_marquee(center, unit, r_outer)
	if _highlight_slot >= 0 and _highlight_slot < RING_SIZE:
		_draw_highlight(center, r_inner, r_outer)
	_draw_links(center, unit)

# 外缘一圈灯泡顺时针追光；spin 时更快更亮（老虎机跑马灯）。
func _draw_marquee(center: Vector2, unit: float, r_outer: float) -> void:
	var bulb_ring_r: float = r_outer + unit * 0.028
	var bulb_radius: float = unit * 0.011
	var speed: float = 3.2 if _spinning else 0.9
	var head: float = fmod(_elapsed * speed, 1.0) * float(BULB_COUNT)
	for i in BULB_COUNT:
		var a: float = TAU * float(i) / float(BULB_COUNT) - PI * 0.5
		var pos: Vector2 = center + Vector2(cos(a), sin(a)) * bulb_ring_r
		var lit: float = clampf(1.0 - absf(_cyclic_delta(float(i), head, float(BULB_COUNT))) / 3.0, 0.0, 1.0)
		if _spinning:
			lit = maxf(lit, 0.35)
		draw_circle(pos, bulb_radius * (0.8 + 0.5 * lit), COLOR_BULB_DIM.lerp(COLOR_BULB_LIT, lit))

# 环形距离（考虑绕回），用来算灯泡离追光头有多远。
func _cyclic_delta(a: float, b: float, n: float) -> float:
	var d: float = fmod(a - b + n, n)
	if d > n * 0.5:
		d -= n
	return d

# 当前 cascade 格：整楔形叠一层亮膜 + 随脉冲收缩的亮边。
func _draw_highlight(center: Vector2, r_inner: float, r_outer: float) -> void:
	var a_start: float = _sector_start(_highlight_slot)
	var a_end: float = _sector_end(_highlight_slot)
	var wedge := _annular_sector(center, r_inner, r_outer, a_start, a_end)
	var glow := COLOR_HIGHLIGHT
	glow.a = 0.22 + 0.45 * _highlight_pulse
	draw_colored_polygon(wedge, glow)
	if _highlight_pulse > 0.01:
		var outline := wedge.duplicate()
		outline.append(outline[0])
		var edge := COLOR_HIGHLIGHT
		edge.a = _highlight_pulse * 0.85
		draw_polyline(outline, edge, 2.0 + 3.0 * _highlight_pulse, true)

# 本步联动连线：从当前格中心连到每个被影响的格，颜色按 kind。
func _draw_links(center: Vector2, unit: float) -> void:
	if _active_links.is_empty() or _highlight_slot < 0:
		return
	var r: float = unit * (RATIO_INNER + RATIO_MID) * 0.5
	var from_pos: Vector2 = _slot_mid_center(_highlight_slot, r)
	for link in _active_links:
		var to_slot: int = int(link["to"])
		if to_slot < 0 or to_slot >= RING_SIZE:
			continue
		var to_pos: Vector2 = _slot_mid_center(to_slot, r)
		var col: Color = link["color"]
		col.a = 0.35 + 0.55 * _highlight_pulse
		draw_line(from_pos, to_pos, col, 2.5, true)
		draw_circle(to_pos, unit * 0.012, col)

func _slot_mid_center(slot: int, r: float) -> Vector2:
	var angle: float = -PI * 0.5 + SECTOR_SPAN * float(slot)
	return size * 0.5 + Vector2(cos(angle), sin(angle)) * r

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
