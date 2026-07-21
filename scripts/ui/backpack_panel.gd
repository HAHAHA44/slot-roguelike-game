# 背包面板（M1）：
# - 列出 RunSession.token_pool 里的每一张人生碎片，选中后看它的完整属性。
# - 「删除选中」消耗一次删牌次数；次数或选中缺一，按钮就是灰的。
# - 纯展示 + 发信号：不持有池子、不自己删牌。删除请求交给 RunScreen 走
#   TokenInventoryService，改完再 refresh() 推回来。这和 ZodiacRing 是同一套约定。
# - 整块 Control 铺满父级并吃掉鼠标事件，所以打开时底下的「下一年」点不到——
#   这是有意的，避免玩家在半开的背包上误推进一年。
class_name BackpackPanel
extends Control

# 玩家点了删除，携带池中下标（不是 token id：池子允许重复，按 id 删会删错张）。
signal delete_requested(pool_index: int)
signal closed()

const COLOR_DETAIL_DIM := Color(0.62, 0.63, 0.70, 1.0)
const COLOR_DETAIL_TEXT := Color(0.90, 0.91, 0.95, 1.0)

var _tokens: Dictionary = {}
var _pool: Array = []
var _charges: int = 0
var _filler_token_id: String = ""

@onready var _title_label: Label = %BackpackTitle
@onready var _charges_label: Label = %ChargesLabel
@onready var _token_list: ItemList = %TokenList
@onready var _detail_label: Label = %DetailLabel
@onready var _filler_label: Label = %FillerLabel
@onready var _delete_button: Button = %DeleteButton
@onready var _close_button: Button = %CloseButton

func _ready() -> void:
	visible = false
	_token_list.item_selected.connect(_on_item_selected)
	_delete_button.pressed.connect(_on_delete_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_title_label.text = L10n.text("ui.backpack.title", "人生碎片")
	_delete_button.text = L10n.text("ui.backpack.delete", "删除选中")
	_close_button.text = L10n.text("ui.backpack.close", "关闭")

# 由 RunScreen 在 ContentRegistry 加载后调用一次。
# filler_token_id 只用来在页脚说明「不够 12 张时补什么」，面板不参与投盘。
func bind_content(tokens: Dictionary, filler_token_id: String) -> void:
	_tokens = tokens
	_filler_token_id = filler_token_id

# 主刷新入口：pool 是 RunSession.token_pool 的快照，charges 是剩余删牌次数。
func refresh(pool: Array, charges: int) -> void:
	if _token_list == null:
		return
	var previous: int = _selected_index()
	_pool = pool.duplicate()
	_charges = charges
	_rebuild_list()
	# 删完一张后列表整体前移，保持选中同一个位置比跳回无选中更接近玩家预期。
	if previous >= 0 and not _pool.is_empty():
		var restored: int = mini(previous, _pool.size() - 1)
		_token_list.select(restored)
	_refresh_charges()
	_refresh_filler_note()
	_refresh_detail()
	_refresh_delete_button()

func open(pool: Array, charges: int) -> void:
	refresh(pool, charges)
	visible = true

func close() -> void:
	visible = false
	closed.emit()

func is_open() -> bool:
	return visible

# -- 内部刷新 ----------------------------------------------------------------

func _rebuild_list() -> void:
	_token_list.clear()
	for i in _pool.size():
		var token_id := String(_pool[i])
		var def = _tokens.get(token_id, null)
		var display: String = def.get_display_name() if def != null else token_id
		var base_score: int = int(def.base_score) if def != null else 0
		_token_list.add_item("%s · %d" % [display, base_score])

func _refresh_charges() -> void:
	_charges_label.text = L10n.format_text("ui.backpack.charges", {"count": _charges},
		"可删除次数：%d" % _charges)

func _refresh_filler_note() -> void:
	if _filler_token_id.is_empty():
		_filler_label.text = ""
		return
	var def = _tokens.get(_filler_token_id, null)
	var filler_name: String = def.get_display_name() if def != null else _filler_token_id
	_filler_label.text = L10n.format_text("ui.backpack.filler_note",
		{"filler": filler_name, "count": _pool.size()},
		"碎片不足 12 张时，空出的格子由「%s」补上。" % filler_name)

func _refresh_detail() -> void:
	if _pool.is_empty():
		_detail_label.add_theme_color_override("font_color", COLOR_DETAIL_DIM)
		_detail_label.text = L10n.text("ui.backpack.empty_hint",
			"碎片已全部删光，明年整盘都是凡庸。")
		return
	var index: int = _selected_index()
	if index < 0:
		_detail_label.add_theme_color_override("font_color", COLOR_DETAIL_DIM)
		_detail_label.text = L10n.text("ui.backpack.select_hint", "选一张碎片查看它的属性。")
		return
	_detail_label.add_theme_color_override("font_color", COLOR_DETAIL_TEXT)
	_detail_label.text = describe_token(String(_pool[index]))

func _refresh_delete_button() -> void:
	_delete_button.disabled = _charges <= 0 or _selected_index() < 0

func _selected_index() -> int:
	if _token_list == null:
		return -1
	var selected: PackedInt32Array = _token_list.get_selected_items()
	return int(selected[0]) if selected.size() > 0 else -1

# 一张 token 的完整属性卡。数值全部来自 TokenDefinition 和 effect.describe()，
# 没有一处是抄在文案里的常量——调 .tres 数值这里自动跟着变。
func describe_token(token_id: String) -> String:
	var def = _tokens.get(token_id, null)
	if def == null:
		return token_id
	var lines: Array[String] = []
	lines.append("%s（%s · %s）" % [def.get_display_name(), def.get_display_type(),
		def.get_display_rarity()])
	lines.append(L10n.format_text("ui.backpack.detail.base_score", {"score": def.base_score},
		"基础分 %d" % def.base_score))

	var affinity := String(def.zodiac_affinity)
	if affinity.is_empty():
		lines.append(L10n.text("ui.backpack.detail.no_affinity", "无生肖共鸣"))
	else:
		lines.append(L10n.format_text("ui.backpack.detail.affinity",
			{"zodiac": L10n.text("content.zodiac.%s.name" % affinity, affinity)},
			"生肖共鸣：%s" % affinity))

	var effect_lines: Array[String] = []
	for effect in def.effects:
		if effect == null:
			continue
		var line := String(effect.describe())
		if not line.is_empty():
			effect_lines.append("· " + line)
	if effect_lines.is_empty():
		lines.append(L10n.text("ui.backpack.detail.no_effect", "无联动效果"))
	else:
		lines.append_array(effect_lines)

	var flavor: String = def.get_display_description()
	if not flavor.is_empty():
		lines.append("")
		lines.append(flavor)
	return "\n".join(lines)

# -- 输入 --------------------------------------------------------------------

func _on_item_selected(_index: int) -> void:
	_refresh_detail()
	_refresh_delete_button()

func _on_delete_pressed() -> void:
	var index: int = _selected_index()
	if index < 0 or _charges <= 0:
		return
	delete_requested.emit(index)

func _on_close_pressed() -> void:
	close()
