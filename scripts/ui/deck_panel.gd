# 命盘 / 行囊 / 道具面板：
# - 左栏命盘（12 格，参与结算），中栏行囊（6 格，不参与结算）。选中两边各一张可对换。
# - 右栏是**已购道具**：它们不上盘、不参与 cascade，但每年都在给全盘上乘区。
#   道具不显示出来，玩家就只能凭记忆知道自己这辈子攒下了什么乘法——
#   而那恰恰是跨阶段唯一留得住的东西（碎片每 12 年清空一次）。
# - 对换免费、不限次，但只在投盘前可用——投盘后还能改，等于让玩家看到 cascade 结果再反悔。
#   RunScreen 负责在动画期间禁用入口，本面板不管这件事。
# - 每张牌显示「名字 ★星级 · 分数」，选中后在下方看完整属性 + 合成进度（2/3 这种）。
# - 纯展示 + 发信号：不持有牌堆，换牌/弃牌请求交给 RunScreen 走 DeckService。
class_name DeckPanel
extends Control

# 请求把命盘第 board_index 张与行囊第 bench_index 张对换。
signal swap_requested(board_index: int, bench_index: int)
# 请求把行囊第 bench_index 张移上命盘（命盘有空位时）。
signal promote_requested(bench_index: int)
# 请求把命盘第 board_index 张收回行囊（行囊有空位时）。
signal demote_requested(board_index: int)
signal closed()

const COLOR_PANEL_BG := Color(0.09, 0.09, 0.13, 0.98)
const COLOR_SCRIM := Color(0, 0, 0, 0.5)
const COLOR_DETAIL_DIM := Color(0.62, 0.63, 0.70)
const COLOR_DETAIL_TEXT := Color(0.90, 0.91, 0.95)
const STAR_MARK := "★"

# 详情栏当前在讲哪一栏选中的东西。三个列表共用一块详情，不记来源就只能按
# 固定优先级猜，玩家点了道具却看到命盘那张的属性。
const SOURCE_BOARD := "board"
const SOURCE_BENCH := "bench"
const SOURCE_ITEMS := "items"

var _tokens: Dictionary = {}
var _items: Dictionary = {}
var _merge_service = null
var _session = null

var _board_list: ItemList
var _bench_list: ItemList
var _item_list: ItemList
# 与 _item_list 各行平行的道具 id，选中后靠它查定义。
var _item_ids: Array[String] = []
var _detail_source: String = SOURCE_BOARD
var _detail_label: Label
var _swap_button: Button
var _move_button: Button
var _title_label: Label

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()

# 由 RunScreen 在 ContentRegistry 加载后调用一次。
func bind_content(tokens: Dictionary, merge_service, items: Dictionary = {}) -> void:
	_tokens = tokens
	_merge_service = merge_service
	_items = items

func open(session) -> void:
	refresh(session)
	visible = true

func close() -> void:
	visible = false
	closed.emit()

func is_open() -> bool:
	return visible

# 主刷新入口。session 是 RunSession；面板只读它，不改它。
func refresh(session) -> void:
	if _board_list == null:
		return
	_session = session
	var board_selected := _selected(_board_list)
	var bench_selected := _selected(_bench_list)
	var item_selected := _selected(_item_list)
	_fill(_board_list, session.board_cards if session != null else [])
	_fill(_bench_list, session.bench_cards if session != null else [])
	_fill_items(session)
	_reselect(_board_list, board_selected)
	_reselect(_bench_list, bench_selected)
	_reselect(_item_list, item_selected)
	_title_label.text = L10n.format_text("ui.deck.title",
		{"board": _board_list.item_count, "bench": _bench_list.item_count,
			"items": _total_item_count()},
		"命盘 %d/12 · 行囊 %d/6 · 道具 %d" %
			[_board_list.item_count, _bench_list.item_count, _total_item_count()])
	_refresh_detail()
	_refresh_buttons()

# -- 构建 --------------------------------------------------------------------

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
	frame.custom_minimum_size = Vector2(1000, 540)
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
	_title_label.add_theme_font_size_override("font_size", 20)
	body.add_child(_title_label)

	var lists := HBoxContainer.new()
	lists.add_theme_constant_override("separation", 16)
	lists.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(lists)

	_board_list = _titled_list(lists, L10n.text("ui.deck.board", "命盘（参与结算）"))
	_bench_list = _titled_list(lists, L10n.text("ui.deck.bench", "行囊（材料 / 备选）"))
	_item_list = _titled_list(lists, L10n.text("ui.deck.items", "道具（场外乘区）"))
	_board_list.item_selected.connect(func(_i): _on_selection_changed(SOURCE_BOARD))
	_bench_list.item_selected.connect(func(_i): _on_selection_changed(SOURCE_BENCH))
	_item_list.item_selected.connect(func(_i): _on_selection_changed(SOURCE_ITEMS))

	_detail_label = Label.new()
	_detail_label.add_theme_font_size_override("font_size", 14)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.custom_minimum_size = Vector2(940, 96)
	body.add_child(_detail_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	body.add_child(buttons)

	_swap_button = Button.new()
	_swap_button.text = L10n.text("ui.deck.swap", "对换")
	_swap_button.custom_minimum_size = Vector2(0, 42)
	_swap_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_swap_button.pressed.connect(_on_swap_pressed)
	buttons.add_child(_swap_button)

	_move_button = Button.new()
	_move_button.text = L10n.text("ui.deck.move", "移动")
	_move_button.custom_minimum_size = Vector2(0, 42)
	_move_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_move_button.pressed.connect(_on_move_pressed)
	buttons.add_child(_move_button)

	var close_button := Button.new()
	close_button.text = L10n.text("ui.deck.close", "关闭")
	close_button.custom_minimum_size = Vector2(0, 42)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.pressed.connect(close)
	buttons.add_child(close_button)

func _titled_list(parent: Control, title: String) -> ItemList:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(column)

	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COLOR_DETAIL_DIM)
	column.add_child(label)

	var list := ItemList.new()
	list.custom_minimum_size = Vector2(290, 260)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(list)
	return list

# -- 刷新 --------------------------------------------------------------------

func _fill(list: ItemList, cards: Array) -> void:
	list.clear()
	for card in cards:
		if card == null:
			continue
		var def = _tokens.get(String(card.definition_id), null)
		var display: String = def.get_display_name() if def != null else String(card.definition_id)
		var score: int = roundi(float(def.base_score) * card.multiplier()) if def != null else 0
		list.add_item("%s %s · %d" % [display, _stars(int(card.star)), score])

# 已购道具：一行一种，带份数。按 id 排序，让同一局里的位置稳定
# ——道具是跨阶段攒的，玩家会记住「我那件东西在第几行」。
func _fill_items(session) -> void:
	_item_list.clear()
	_item_ids.clear()
	if session == null:
		return
	var ids: Array = session.owned_items.keys()
	ids.sort()
	for item_id in ids:
		var count: int = int(session.owned_items[item_id])
		if count <= 0:
			continue
		var def = _items.get(String(item_id), null)
		var display: String = def.get_display_name() if def != null else String(item_id)
		_item_list.add_item("%s ×%d" % [display, count] if count > 1 else display)
		_item_ids.append(String(item_id))

func _total_item_count() -> int:
	if _session == null:
		return 0
	var total := 0
	for item_id in _session.owned_items:
		total += int(_session.owned_items[item_id])
	return total

func _stars(star: int) -> String:
	return STAR_MARK.repeat(maxi(star, 1))

func _selected(list: ItemList) -> int:
	if list == null:
		return -1
	var selection: PackedInt32Array = list.get_selected_items()
	return int(selection[0]) if selection.size() > 0 else -1

func _reselect(list: ItemList, index: int) -> void:
	if index >= 0 and index < list.item_count:
		list.select(index)

func _refresh_detail() -> void:
	if _detail_source == SOURCE_ITEMS:
		var index := _selected(_item_list)
		if index >= 0 and index < _item_ids.size():
			_detail_label.add_theme_color_override("font_color", COLOR_DETAIL_TEXT)
			_detail_label.text = describe_item(_item_ids[index])
			return
	var card = _selected_card()
	if card == null:
		_detail_label.add_theme_color_override("font_color", COLOR_DETAIL_DIM)
		_detail_label.text = L10n.text("ui.deck.select_hint", "选一张碎片或道具查看它的属性。")
		return
	_detail_label.add_theme_color_override("font_color", COLOR_DETAIL_TEXT)
	_detail_label.text = describe_card(card)

# 优先看命盘的选中项；命盘没选中才看行囊。
func _selected_card():
	var board_index := _selected(_board_list)
	if board_index >= 0 and _session != null and board_index < _session.board_cards.size():
		return _session.board_cards[board_index]
	var bench_index := _selected(_bench_list)
	if bench_index >= 0 and _session != null and bench_index < _session.bench_cards.size():
		return _session.bench_cards[bench_index]
	return null

func _refresh_buttons() -> void:
	var board_index := _selected(_board_list)
	var bench_index := _selected(_bench_list)
	_swap_button.disabled = board_index < 0 or bench_index < 0
	# 「移动」的方向由哪边选中决定：只选了行囊 → 上命盘；只选了命盘 → 回行囊。
	var can_promote: bool = bench_index >= 0 and board_index < 0 and _session != null \
		and not _session.board_is_full()
	var can_demote: bool = board_index >= 0 and bench_index < 0 and _session != null \
		and not _session.bench_is_full()
	_move_button.disabled = not (can_promote or can_demote)

# 一张碎片的完整属性卡。数值全部来自定义与 effect.describe()，
# 没有一处是抄在文案里的常量——调 .tres 数值这里自动跟着变。
func describe_card(card) -> String:
	var def = _tokens.get(String(card.definition_id), null)
	if def == null:
		return String(card.definition_id)
	var lines: Array[String] = []
	lines.append("%s %s（%s · %s）" % [def.get_display_name(), _stars(int(card.star)),
		def.get_display_domain(), def.get_display_rarity()])
	lines.append(L10n.format_text("ui.deck.detail.base_score",
		{"score": roundi(float(def.base_score) * card.multiplier())},
		"进盘分 %d（基础 %d × %.1f）" % [roundi(float(def.base_score) * card.multiplier()),
			def.base_score, card.multiplier()]))

	var affinity := String(def.zodiac_affinity)
	if not affinity.is_empty():
		lines.append(L10n.format_text("ui.deck.detail.affinity",
			{"zodiac": L10n.text("content.zodiac.%s.name" % affinity, affinity)},
			"生肖共鸣：%s" % L10n.text("content.zodiac.%s.name" % affinity, affinity)))

	for effect in def.effects:
		if effect == null:
			continue
		var line := String(effect.describe())
		if not line.is_empty():
			lines.append("· " + line)

	if _merge_service != null and _session != null:
		var progress: Dictionary = _merge_service.progress_for(_session, String(card.definition_id))
		if not progress.is_empty():
			lines.append(L10n.format_text("ui.deck.detail.merge",
				{"have": progress["have"], "need": progress["need"]},
				"合成进度 %d/%d" % [progress["have"], progress["need"]]))

	if def.can_ascend():
		lines.append(L10n.text("ui.deck.detail.ascend", "满星后可传承到下一阶段"))
	return "\n".join(lines)

# 一件道具的属性卡。乘区说明由 describe_effect() 现算，和商店里读到的是同一句话。
func describe_item(item_id: String) -> String:
	var def = _items.get(item_id, null)
	if def == null:
		return item_id
	var count: int = int(_session.owned_items.get(item_id, 0)) if _session != null else 0
	var lines: Array[String] = []
	var head := "%s（%s）" % [def.get_display_name(), def.get_display_rarity()]
	if count > 1:
		head += " ×%d" % count
	lines.append(head)
	lines.append("· " + def.describe_effect())
	lines.append(L10n.text("ui.deck.detail.item_scope", "道具不上盘，每年整局生效，跨阶段不清空。"))
	var flavor: String = def.get_display_description()
	if not flavor.is_empty():
		lines.append("")
		lines.append(flavor)
	return "\n".join(lines)

# -- 输入 --------------------------------------------------------------------

# 三个列表共用一块详情栏。选了道具就清掉两边的牌选中（反之只清道具），
# 因为「命盘 + 行囊各选一张」是对换的前提，不能被点道具打断。
func _on_selection_changed(source: String) -> void:
	_detail_source = source
	if source == SOURCE_ITEMS:
		_board_list.deselect_all()
		_bench_list.deselect_all()
	else:
		_item_list.deselect_all()
	_refresh_detail()
	_refresh_buttons()

func _on_swap_pressed() -> void:
	var board_index := _selected(_board_list)
	var bench_index := _selected(_bench_list)
	if board_index < 0 or bench_index < 0:
		return
	swap_requested.emit(board_index, bench_index)

func _on_move_pressed() -> void:
	var board_index := _selected(_board_list)
	var bench_index := _selected(_bench_list)
	if bench_index >= 0 and board_index < 0:
		promote_requested.emit(bench_index)
	elif board_index >= 0 and bench_index < 0:
		demote_requested.emit(board_index)
