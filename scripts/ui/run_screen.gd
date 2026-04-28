# 涓昏繍琛岀晫闈?/ 娴佺▼缂栨帓鍣細
# - 杩欐槸褰撳墠椤圭洰鏈€鏍稿績鐨勮剼鏈紝璐熻矗鎶婂満鏅€佸唴瀹广€乻ervice銆佺姸鎬佹満涓叉垚涓€鏉¤兘鐜╃殑涓诲惊鐜€?
# - 瀹冧笉鐩存帴鍐欏鏉傝鍒欙紝鑰屾槸鎶娾€滅帺瀹惰緭鍏?-> 鐘舵€佸垏鎹?-> service 璋冪敤 -> UI 鍒锋柊鈥濊繖鏉￠摼璺粍缁囪捣鏉ャ€?
# - 涓昏鑱斿姩瀵硅薄锛?
#   - `ContentRegistry`锛氬姞杞?token / event / hero / difficulty 绛夊唴瀹硅祫婧愩€?
#   - `RunSession`锛氫繚瀛樻湰灞€鎸佷箙鐘舵€侊紝渚嬪鐗屾睜銆佸垎鏁般€佸洖鍚堝拰鎿嶄綔鍘嗗彶銆?
#   - `BoardService` / `BoardRollService`锛氱淮鎶ゆ鐩樺苟鍦ㄦ瘡杞紑濮嬫椂鐢熸垚鏂版澘闈€?
#   - `RewardOfferService` / `EventDraftService` / `ContractService` / `RunModifierService`锛氬垎鍒礋璐ｅ鍔便€佷簨浠躲€佸悎绾﹀拰淇銆?
#   - `SettlementResolver`锛氭妸涓€娆″洖鍚堢殑妫嬬洏鐘舵€佽浆鎴愬彲鎾斁鐨勭粨绠楁楠ゃ€?
# - 鐘舵€佹満鐢?Godot State Charts 绠＄悊锛岄粯璁や富璺緞鏄?`offer_choice -> event_draft -> roll_board -> settling -> settlement_result -> offer_choice`銆?
# - `player_turn` 鐜板湪浣滀负姝ｅ紡鐨?set mode 鍒嗘敮淇濈暀锛涢《閮ㄦ寜閽垏鍒?set mode 鍚庯紝浜嬩欢纭浼氭敼涓鸿繘鍏ユ墜鍔ㄦ憜鏀俱€?
extends Control

const BOARD_WIDTH := 5
const BOARD_HEIGHT := 5
const DEFAULT_TOKEN_ID := "fire_common"
const EMPTY_TOKEN_ID := "empty_token"

const SLOT_SPIN_DURATION_BASE := 0.5   # 绗?0 鍒楀仠姝㈠墠鐨勬棆杞椂闀匡紙绉掞級
const SLOT_SPIN_STAGGER := 0.18        # 姣忓垪棰濆寤惰繜锛堢锛夛紝閫愬垪鍋滄
const SLOT_SPIN_INTERVAL := 0.06       # 姣忓抚绗﹀彿鍒囨崲闂撮殧锛堢锛?

const SETTLEMENT_STEP_INTERVAL := 0.30  # 姣忎釜缁撶畻姝ラ鐨勬€绘椂闀匡紙绉掞級
const SETTLEMENT_HIGHLIGHT_HOLD := 0.22 # 楂樹寒鎸佺画鏃堕暱锛堢锛?
const SETTLEMENT_POPUP_RISE := 55.0     # 寰楀垎娴瓧涓婂崌璺濈锛堝儚绱狅級

const RARITY_COLORS := {
	"Common":    Color(0.25, 0.25, 0.28),
	"Uncommon":  Color(0.13, 0.40, 0.16),
	"Rare":      Color(0.08, 0.30, 0.62),
	"Legendary": Color(0.55, 0.26, 0.02),
}

const BoardServiceScript := preload("res://scripts/core/services/board_service.gd")
const BoardRollServiceScript := preload("res://scripts/core/services/board_roll_service.gd")
const TokenInstanceScript := preload("res://scripts/core/value_objects/token_instance.gd")
const SettlementResolverScript := preload("res://scripts/core/services/settlement_resolver.gd")
const RewardOfferServiceScript := preload("res://scripts/core/services/reward_offer_service.gd")
const RunSessionScript := preload("res://autoload/run_session.gd")
const ContentRegistryScript := preload("res://autoload/content_registry.gd")
const EventDraftServiceScript := preload("res://scripts/core/services/event_draft_service.gd")
const ContractServiceScript := preload("res://scripts/core/services/contract_service.gd")
const RunModifierServiceScript := preload("res://scripts/core/services/run_modifier_service.gd")

const StateChartScript := preload("res://addons/godot_state_charts/state_chart.gd")
const CompoundStateScript := preload("res://addons/godot_state_charts/compound_state.gd")
const AtomicStateScript := preload("res://addons/godot_state_charts/atomic_state.gd")
const TransitionScript := preload("res://addons/godot_state_charts/transition.gd")

const TOKEN_CELL_SCENE := preload("res://scenes/run/token_cell.tscn")

var run_session = RunSessionScript.new()
var _board_service = BoardServiceScript.new(BOARD_WIDTH, BOARD_HEIGHT)
var _board_roll_service = BoardRollServiceScript.new()
var _rng := RandomNumberGenerator.new()
var _settlement_resolver = SettlementResolverScript.new()
var _reward_offer_service = RewardOfferServiceScript.new()
var _content_registry = ContentRegistryScript.new()
var _event_draft_service
var _contract_service = ContractServiceScript.new()
var _run_modifier_service = RunModifierServiceScript.new()
var _selected_hero: HeroDefinition
var _selected_difficulty: DifficultyModifier

var _cell_buttons_by_pos: Dictionary = {}
var _pending_steps: Array = []
var _active_offers: Array = []
var _active_event_options: Array = []
var _active_contract: Dictionary = {}
var _active_state_name: String = ""
var _items: Array[String] = []
var _turn_flow_set_mode := false
var _settlement_autoplay_running := false
var _token_icon_cache: Dictionary = {}
var _rarity_style_cache: Dictionary = {}
var _last_settlement_score_gain := 0

var _state_chart
var _boot_state
var _player_turn_state
var _settling_state
var _offer_choice_state
var _event_draft_state
var _roll_board_state
var _settlement_result_state
var _run_failed_state
var _run_cleared_state

@onready var _board_grid: GridContainer = %BoardGrid
@onready var _run_state_label: Label = %RunStateLabel
@onready var _turn_label: Label = %TurnLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _contract_label: Label = %ContractLabel
@onready var _turn_flow_mode_button: Button = %TurnFlowModeButton
@onready var _mode_label: Label = get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/ModeLabel")
@onready var _mode_buttons: HBoxContainer = get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/ModeButtons")
@onready var _place_mode_button: Button = get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/ModeButtons/PlaceModeButton")
@onready var _remove_mode_button: Button = get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/ModeButtons/RemoveModeButton")
@onready var _settle_button: Button = get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/SettleButton")
@onready var _offer_title_label: Label = get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/OfferTitleLabel")
@onready var _offer_button_1: Button = get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/OfferButton1")
@onready var _offer_button_2: Button = get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/OfferButton2")
@onready var _offer_button_3: Button = get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/OfferButton3")
@onready var _next_turn_button: Button = get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/NextTurnButton")
@onready var _continue_to_reward_button: Button = get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/ContinueToRewardButton")
@onready var _event_draft_panel: PanelContainer = get_node("MainMargin/MainLayout/ContentRow/Sidebar/EventDraftPanel")
@onready var _event_summary_label: Label = get_node("MainMargin/MainLayout/ContentRow/Sidebar/EventDraftPanel/MarginContainer/VBox/SummaryLabel")
@onready var _event_button_1: Button = get_node("MainMargin/MainLayout/ContentRow/Sidebar/EventDraftPanel/MarginContainer/VBox/EventButton1")
@onready var _event_button_2: Button = get_node("MainMargin/MainLayout/ContentRow/Sidebar/EventDraftPanel/MarginContainer/VBox/EventButton2")
@onready var _event_button_3: Button = get_node("MainMargin/MainLayout/ContentRow/Sidebar/EventDraftPanel/MarginContainer/VBox/EventButton3")
@onready var _event_token_picker_scroll: ScrollContainer = get_node("MainMargin/MainLayout/ContentRow/Sidebar/EventDraftPanel/MarginContainer/VBox/TokenPickerScroll")
@onready var _event_token_picker_flow: FlowContainer = get_node("MainMargin/MainLayout/ContentRow/Sidebar/EventDraftPanel/MarginContainer/VBox/TokenPickerScroll/TokenPickerFlow")
@onready var _items_row: FlowContainer = %ItemsRow
@onready var _settlement_log_list: ItemList = %ConsoleLogList
@onready var _console_panel: PanelContainer = %ConsolePanel
@onready var _bag_button: Button = %BagButton
@onready var _bag_panel: PanelContainer = %BagPanel
@onready var _bag_close_button: Button = %BagCloseButton
@onready var _bag_list: GridContainer = %BagList

func _ready() -> void:
	_content_registry.load_all()
	_event_draft_service = EventDraftServiceScript.new(_content_registry)
	_selected_hero = _content_registry.heroes.get("resolve_specialist")
	_selected_difficulty = _content_registry.difficulty_modifiers.get("ascension_1")
	_build_state_chart()
	_wire_ui()
	_bag_panel.visible = false
	_console_panel.visible = false
	_build_board_grid()
	_sync_board_ui()
	_sync_run_labels()
	_sync_all_panels()

func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED or not is_node_ready():
		return
	_sync_board_ui()
	_sync_run_labels()
	_sync_all_panels()
	if _bag_panel.visible:
		_sync_bag_panel()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT:
			_console_panel.visible = not _console_panel.visible
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Public API (also used by tests)
# ---------------------------------------------------------------------------

func get_active_state_name() -> String:
	return _active_state_name

func get_turn_flow_mode_name() -> String:
	return "set" if _turn_flow_set_mode else "auto"

func get_settlement_log_entries() -> Array[String]:
	var entries: Array[String] = []
	for index in _settlement_log_list.item_count:
		entries.append(_settlement_log_list.get_item_text(index))
	return entries

func get_active_placement_token_id() -> String:
	return run_session.get_active_token_id()

func get_active_contract_data() -> Dictionary:
	return _active_contract.duplicate(true)

func get_active_contract_summary() -> String:
	if _active_contract.is_empty():
		return ""
	return _contract_service.summarize_contract(_active_contract)

func get_board_token_count() -> int:
	var count := 0
	for row in BOARD_HEIGHT:
		for col in BOARD_WIDTH:
			if _board_service.has_token(Vector2i(col, row)):
				count += 1
	return count

# Advances one settlement step manually (used by older tests / debug).
func advance_settlement_playback() -> bool:
	if _active_state_name != "settling":
		return false
	if _pending_steps.is_empty():
		return false

	var step = _pending_steps.pop_front()
	_append_log_entry(step)
	run_session.current_score += step.score_delta
	_last_settlement_score_gain += step.score_delta
	_sync_run_labels()

	if _pending_steps.is_empty():
		_complete_settlement()

	return true

# Debug helpers (for tests that need to skip the mainline flow).
func debug_force_reward_event_complete() -> void:
	# Ensure offers exist (they're built on offer_choice entry, but call just in case).
	if _active_offers.is_empty():
		_active_offers = _reward_offer_service.build_turn_offer(run_session, _content_registry)
	if _active_state_name == "offer_choice" and not _active_offers.is_empty():
		_on_offer_button_pressed(0)
	if _active_state_name == "event_draft" and not _active_event_options.is_empty():
		var event_data: Dictionary = _active_event_options[0]
		if bool(event_data.get("needs_token_pick", false)):
			var eligible: Array = event_data.get("eligible_tokens", [])
			var pick_id: String = eligible[0] if not eligible.is_empty() else ""
			if not pick_id.is_empty():
				_on_event_token_pick_pressed(pick_id)
			else:
				_finish_event(event_data)
		else:
			_on_event_button_pressed(0)

func debug_force_active_contract() -> void:
	# Navigate to roll_board through the normal offer/event flow.
	if _active_state_name == "offer_choice":
		debug_force_reward_event_complete()  # 鈫?event_draft
	if _active_state_name == "event_draft":
		debug_force_reward_event_complete()  # 鈫?roll_board
	# Events no longer set contracts; inject a test contract directly.
	_active_contract = _contract_service.build_contract({
		"id": "debug_contract",
		"type": "crisis",
		"contract_template": {"goal_type": "reach_score", "goal_value": 100, "turns_remaining": 3},
		"reward_bundle": {"score_bonus": 5},
		"penalty_bundle": {"score_penalty": 2},
	})
	run_session.active_modifiers = [_active_contract.duplicate(true)]

# Test/debug compatibility helper. The real player-facing entry is the header mode toggle.
func debug_enter_player_turn() -> void:
	if _active_state_name in ["offer_choice", "roll_board", "event_draft"]:
		_state_chart.send_event("debug_player_turn")

# ---------------------------------------------------------------------------
# State chart
# ---------------------------------------------------------------------------

func _build_state_chart() -> void:
	_state_chart = StateChartScript.new()
	_state_chart.name = "RunStateChart"

	var root_state = CompoundStateScript.new()
	root_state.name = "FlowRoot"
	root_state.initial_state = NodePath("Boot")
	_state_chart.add_child(root_state)

	_boot_state = _make_state("Boot")
	_player_turn_state = _make_state("PlayerTurn")
	_settling_state = _make_state("Settling")
	_offer_choice_state = _make_state("OfferChoice")
	_event_draft_state = _make_state("EventDraft")
	_roll_board_state = _make_state("RollBoard")
	_settlement_result_state = _make_state("SettlementResult")
	_run_failed_state = _make_state("RunFailed")
	_run_cleared_state = _make_state("RunCleared")

	for state in [
		_boot_state,
		_player_turn_state,
		_settling_state,
		_offer_choice_state,
		_event_draft_state,
		_roll_board_state,
		_settlement_result_state,
		_run_failed_state,
		_run_cleared_state,
	]:
		root_state.add_child(state)

	# Default mainline: Boot 鈫?OfferChoice 鈫?EventDraft 鈫?RollBoard 鈫?Settling 鈫?SettlementResult 鈫?OfferChoice
	_add_transition(_boot_state, "BootToOfferChoice", NodePath("../../OfferChoice"))
	_add_transition(_offer_choice_state, "OfferChoiceToEventDraft", NodePath("../../EventDraft"), "offer_selected")
	_add_transition(_event_draft_state, "EventDraftToRollBoard", NodePath("../../RollBoard"), "event_selected")
	_add_transition(_roll_board_state, "RollBoardToSettling", NodePath("../../Settling"), "next_turn")
	_add_transition(_settling_state, "SettlingToSettlementResult", NodePath("../../SettlementResult"), "settlement_complete")
	_add_transition(_settlement_result_state, "SettlementResultToOfferChoice", NodePath("../../OfferChoice"), "continue_to_reward")

	# Set-mode / compatibility path: manual placement 鈫?settle 鈫?settlement_result path
	_add_transition(_offer_choice_state, "OfferChoiceToPlayerTurn", NodePath("../../PlayerTurn"), "debug_player_turn")
	_add_transition(_roll_board_state, "RollBoardToPlayerTurn", NodePath("../../PlayerTurn"), "debug_player_turn")
	_add_transition(_event_draft_state, "EventDraftToPlayerTurn", NodePath("../../PlayerTurn"), "debug_player_turn")
	_add_transition(_player_turn_state, "PlayerTurnToSettling", NodePath("../../Settling"), "settle")

	_boot_state.state_entered.connect(_on_state_entered.bind("boot"))
	_player_turn_state.state_entered.connect(_on_state_entered.bind("player_turn"))
	_settling_state.state_entered.connect(_on_state_entered.bind("settling"))
	_offer_choice_state.state_entered.connect(_on_state_entered.bind("offer_choice"))
	_event_draft_state.state_entered.connect(_on_state_entered.bind("event_draft"))
	_roll_board_state.state_entered.connect(_on_state_entered.bind("roll_board"))
	_settlement_result_state.state_entered.connect(_on_state_entered.bind("settlement_result"))
	_run_failed_state.state_entered.connect(_on_state_entered.bind("run_failed"))
	_run_cleared_state.state_entered.connect(_on_state_entered.bind("run_cleared"))

	add_child(_state_chart)

func _make_state(state_name: String):
	var state = AtomicStateScript.new()
	state.name = state_name
	return state

func _add_transition(from_state, transition_name: String, target_path: NodePath, event_name: StringName = "") -> void:
	var transition = TransitionScript.new()
	transition.name = transition_name
	transition.to = target_path
	transition.event = event_name
	from_state.add_child(transition)

# ---------------------------------------------------------------------------
# UI wiring
# ---------------------------------------------------------------------------

func _wire_ui() -> void:
	_turn_flow_mode_button.pressed.connect(_on_turn_flow_mode_button_pressed)
	_place_mode_button.pressed.connect(_select_mode.bind("place"))
	_remove_mode_button.pressed.connect(_select_mode.bind("remove"))
	_settle_button.pressed.connect(_on_settle_pressed)
	_offer_button_1.pressed.connect(_on_offer_button_pressed.bind(0))
	_offer_button_2.pressed.connect(_on_offer_button_pressed.bind(1))
	_offer_button_3.pressed.connect(_on_offer_button_pressed.bind(2))
	_event_button_1.pressed.connect(_on_event_button_pressed.bind(0))
	_event_button_2.pressed.connect(_on_event_button_pressed.bind(1))
	_event_button_3.pressed.connect(_on_event_button_pressed.bind(2))
	_next_turn_button.pressed.connect(_on_next_turn_pressed)
	_continue_to_reward_button.pressed.connect(_on_continue_to_reward_pressed)
	_bag_button.pressed.connect(_on_bag_button_pressed)
	_bag_close_button.pressed.connect(func(): _bag_panel.visible = false)

func _on_turn_flow_mode_button_pressed() -> void:
	_set_turn_flow_mode(not _turn_flow_set_mode)

func _set_turn_flow_mode(enabled: bool) -> void:
	_turn_flow_set_mode = enabled
	run_session.operation_history.append({
		"kind": "turn_flow_mode_change",
		"flow_mode": get_turn_flow_mode_name(),
		"turn": run_session.current_turn,
		"state": _active_state_name,
	})
	_apply_turn_flow_mode_to_current_state()
	_sync_run_labels()
	_sync_all_panels()

func _apply_turn_flow_mode_to_current_state() -> void:
	if _turn_flow_set_mode and _active_state_name == "roll_board":
		_state_chart.send_event("debug_player_turn")

func _build_board_grid() -> void:
	for child in _board_grid.get_children():
		child.queue_free()

	_cell_buttons_by_pos.clear()

	for row in BOARD_HEIGHT:
		for column in BOARD_WIDTH:
			var pos := Vector2i(column, row)
			var button := TOKEN_CELL_SCENE.instantiate() as Button
			button.name = "Cell_%s_%s" % [column, row]
			button.pressed.connect(_on_cell_pressed.bind(pos))
			_board_grid.add_child(button)
			_cell_buttons_by_pos[pos] = button

# ---------------------------------------------------------------------------
# State handlers
# ---------------------------------------------------------------------------

func _on_state_entered(state_name: String) -> void:
	_active_state_name = state_name

	# Clear transient state when leaving the relevant state.
	if state_name != "settling":
		_settlement_autoplay_running = false
	if state_name != "offer_choice":
		_active_offers.clear()
	if state_name != "event_draft":
		_active_event_options.clear()

	match state_name:
		"offer_choice":
			# Build offers on every entry (first boot or after settlement_result).
			_active_offers = _reward_offer_service.build_turn_offer(run_session, _content_registry)
		"settling":
			if _pending_steps.is_empty():
				call_deferred("_complete_settlement")
			else:
				call_deferred("_start_settlement_autoplay")

	_sync_run_labels()
	_sync_all_panels()

func _select_mode(mode_name: String) -> void:
	_place_mode_button.set_pressed_no_signal(mode_name == "place")
	_remove_mode_button.set_pressed_no_signal(mode_name == "remove")
	run_session.operation_history.append({
		"kind": "mode_change",
		"mode": mode_name,
		"turn": run_session.current_turn,
	})
	_sync_run_labels()

func _on_cell_pressed(pos: Vector2i) -> void:
	if _active_state_name != "player_turn":
		return

	var current_mode := _get_mode_name()
	if current_mode == "place":
		if _board_service.has_token(pos):
			return

		var token := _make_active_token_instance()
		if _board_service.place_token(pos, token):
			run_session.operation_history.append({
				"kind": "place_token",
				"token_id": token.definition_id,
				"position": {"x": pos.x, "y": pos.y},
				"turn": run_session.current_turn,
			})
			run_session.advance_token_cursor()
	elif current_mode == "remove":
		var removed = _board_service.remove_token(pos)
		if removed != null:
			run_session.operation_history.append({
				"kind": "remove_token",
				"position": {"x": pos.x, "y": pos.y},
				"turn": run_session.current_turn,
			})

	_sync_board_ui()

# Set-mode/manual settle path.
func _on_settle_pressed() -> void:
	if _active_state_name != "player_turn":
		return

	var report = _settlement_resolver.resolve_board(_board_service, _content_registry, _get_active_item_defs())
	_pending_steps = report.steps.duplicate()
	_last_settlement_score_gain = 0
	_settlement_log_list.clear()
	_state_chart.send_event("settle")

# Mainline: next-turn arrow rolls the board then auto-settles.
func _on_next_turn_pressed() -> void:
	if _active_state_name != "roll_board":
		return

	_next_turn_button.disabled = true
	_roll_board_from_pool()
	await _play_slot_animation()
	_sync_board_ui()
	var report = _settlement_resolver.resolve_board(_board_service, _content_registry, _get_active_item_defs())
	_pending_steps = report.steps.duplicate()
	_last_settlement_score_gain = 0
	_settlement_log_list.clear()
	_state_chart.send_event("next_turn")
	_next_turn_button.disabled = false

func _on_continue_to_reward_pressed() -> void:
	if _active_state_name != "settlement_result":
		return
	_state_chart.send_event("continue_to_reward")

func _on_offer_button_pressed(index: int) -> void:
	if _active_state_name != "offer_choice":
		return
	if index < 0 or index >= _active_offers.size():
		return

	var offer: Dictionary = _active_offers[index]
	var reward_resolution := _reward_offer_service.apply_offer(run_session, offer)
	run_session.operation_history.append({
		"kind": "offer_selected",
		"offer_kind": offer.get("kind", ""),
		"token_id": reward_resolution.get("token_id", ""),
		"active_token_id": reward_resolution.get("active_token_id", ""),
		"turn": run_session.current_turn,
	})
	var event_seed: int = run_session.current_turn * 37 + run_session.phase_index * 13
	_active_event_options = [_event_draft_service.build_event(run_session, event_seed)]
	_state_chart.send_event("offer_selected")
	_sync_run_labels()
	_sync_all_panels()

func _on_event_button_pressed(_index: int) -> void:
	if _active_state_name != "event_draft":
		return
	if _active_event_options.is_empty():
		return
	var event_data: Dictionary = _active_event_options[0]
	if bool(event_data.get("needs_token_pick", false)):
		return
	_finish_event(event_data)

func _on_event_token_pick_pressed(token_id: String) -> void:
	if _active_state_name != "event_draft":
		return
	if _active_event_options.is_empty():
		return
	var event_data: Dictionary = _active_event_options[0]
	event_data["token_id"] = token_id
	_finish_event(event_data)

func _finish_event(event_data: Dictionary) -> void:
	_event_draft_service.apply_event(run_session, event_data)
	if String(event_data.get("event_type", "")) == "item":
		var item_effect_type := String(event_data.get("item_effect_type", "passive"))
		if item_effect_type == "passive":
			var item_id := String(event_data.get("item_id", ""))
			if not item_id.is_empty():
				_items.append(item_id)
	run_session.operation_history.append({
		"kind": "event_resolved",
		"event_type": event_data.get("event_type", ""),
		"token_id": event_data.get("token_id", ""),
		"turn": run_session.current_turn,
	})
	run_session.current_turn += 1
	_state_chart.send_event("event_selected")
	_apply_turn_flow_mode_to_current_state()
	_sync_run_labels()
	_sync_all_panels()

# ---------------------------------------------------------------------------
# Board roll (mainline)
# ---------------------------------------------------------------------------

func _roll_board_from_pool() -> void:
	# Clear existing board.
	for row in BOARD_HEIGHT:
		for col in BOARD_WIDTH:
			var pos := Vector2i(col, row)
			if _board_service.has_token(pos):
				_board_service.remove_token(pos)

	# Build round pool: fill to capacity with empty tokens, then shuffle.
	var round_pool := _board_roll_service.build_round_pool(
		Array(run_session.token_pool),
		BOARD_WIDTH * BOARD_HEIGHT,
		EMPTY_TOKEN_ID,
		_rng
	)

	# Place each token from the round pool onto the board.
	var board_map := _board_roll_service.pool_to_board_map(round_pool, BOARD_WIDTH)
	for pos in board_map.keys():
		var token_id := String(board_map[pos])
		var token := _make_token_instance_for_id(token_id)
		_board_service.place_token(pos, token)

# 鑰佽檸鏈哄姩鐢伙細姣忓垪闅忔満婊氬姩锛屼粠宸﹀埌鍙充緷娆″仠涓?
func _play_slot_animation() -> void:
	var spin_pool: Array = []
	for token_id in run_session.token_pool:
		if token_id != EMPTY_TOKEN_ID and not (token_id in spin_pool):
			spin_pool.append(token_id)
	if spin_pool.is_empty():
		spin_pool = _content_registry.tokens.keys()
	if spin_pool.is_empty():
		return

	# 鍚姩鎵€鏈夊垪鐨勬棆杞崗绋嬶紙骞跺彂锛屼笉 await锛?
	for col in BOARD_WIDTH:
		_spin_column_anim(col, spin_pool, SLOT_SPIN_DURATION_BASE + col * SLOT_SPIN_STAGGER)

	# 绛夊緟鏈€鍚庝竴鍒楀畬鎴?
	var total := SLOT_SPIN_DURATION_BASE + (BOARD_WIDTH - 1) * SLOT_SPIN_STAGGER + SLOT_SPIN_INTERVAL * 2.0
	await get_tree().create_timer(total).timeout

func _spin_column_anim(col: int, spin_pool: Array, duration: float) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		for row in BOARD_HEIGHT:
			var button: Button = _cell_buttons_by_pos[Vector2i(col, row)]
			var random_id: String = spin_pool[_rng.randi() % spin_pool.size()]
			_apply_token_id_to_button(button, random_id)
		await get_tree().create_timer(SLOT_SPIN_INTERVAL).timeout
		elapsed += SLOT_SPIN_INTERVAL

	# 鍒楀仠姝㈡椂鏄剧ず鐪熷疄缁撴灉
	for row in BOARD_HEIGHT:
		var pos := Vector2i(col, row)
		var button: Button = _cell_buttons_by_pos[pos]
		var token = _board_service.get_token(pos)
		if token == null:
			button.text = ""
			button.icon = null
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("hover")
		else:
			_apply_token_id_to_button(button, token.definition_id)

func _apply_token_id_to_button(button: Button, token_id: String) -> void:
	if token_id.is_empty() or token_id == EMPTY_TOKEN_ID:
		button.text = L10n.text("ui.board.empty_slot_short", "空")
		button.icon = null
		button.remove_theme_stylebox_override("normal")
		button.remove_theme_stylebox_override("hover")
		return
	var definition: TokenDefinition = _content_registry.tokens.get(token_id)
	var icon_tex := _get_token_icon(token_id)
	button.text = "" if icon_tex else token_id.left(2).to_upper()
	button.icon = icon_tex
	button.expand_icon = true
	var rarity: String = definition.rarity if definition else "Common"
	var style := _get_rarity_style(rarity)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)

# ---------------------------------------------------------------------------
# Settlement
# ---------------------------------------------------------------------------

func _start_settlement_autoplay() -> void:
	if _settlement_autoplay_running:
		return
	if _active_state_name != "settling":
		return
	if _pending_steps.is_empty():
		return

	_settlement_autoplay_running = true
	_run_settlement_autoplay()

func _run_settlement_autoplay() -> void:
	# 鍙栧嚭骞舵竻绌?pending_steps锛屾寜寰楀垎浠庝綆鍒伴珮鎺掑簭
	var steps_to_play := _pending_steps.duplicate()
	_pending_steps.clear()
	steps_to_play.sort_custom(func(a, b): return a.score_delta < b.score_delta)

	# 灏嗙浉鍚?score_delta 鐨?steps 鍚堝苟鎴愪竴缁勶紝鍚岀粍鏍煎瓙鍚屾椂楂樹寒
	var groups: Array = []
	for step in steps_to_play:
		if groups.is_empty() or groups[-1][0].score_delta != step.score_delta:
			groups.append([step])
		else:
			groups[-1].append(step)

	for group in groups:
		if _active_state_name != "settling":
			_settlement_autoplay_running = false
			return

		# 鏀堕泦鏈粍鎵€鏈夋牸瀛愶紝骞跺啓鏃ュ織 & 绱姞鍒嗘暟
		var group_positions: Array = []
		var group_delta: int = group[0].score_delta
		for step in group:
			_append_log_entry(step)
			run_session.current_score += step.score_delta
			_last_settlement_score_gain += step.score_delta
			if step.source_token == "system":
				continue
			for pos in _cell_buttons_by_pos.keys():
				var token = _board_service.get_token(pos)
				if token != null and token.definition_id == step.source_token:
					group_positions.append(pos)
		_sync_run_labels()

		if group_positions.is_empty():
			await get_tree().process_frame
			continue

		# 鍚岀粍鏍煎瓙鍚屾椂楂樹寒 & 寮瑰嚭寰楀垎娴瓧
		for pos in group_positions:
			var btn: Button = _cell_buttons_by_pos[pos]
			_set_cell_highlighted(btn, true)
			if group_delta != 0:
				_spawn_score_popup(btn, group_delta)

		await get_tree().create_timer(SETTLEMENT_HIGHLIGHT_HOLD).timeout

		for pos in group_positions:
			_restore_cell_style(pos, _cell_buttons_by_pos[pos])

		await get_tree().create_timer(SETTLEMENT_STEP_INTERVAL - SETTLEMENT_HIGHLIGHT_HOLD).timeout

	_settlement_autoplay_running = false
	if _active_state_name == "settling":
		_complete_settlement()

# 缁欐牸瀛愬彔鍔犻噾鑹查珮浜竟妗?
func _set_cell_highlighted(button: Button, on: bool) -> void:
	if on:
		var base_color := Color(0.25, 0.25, 0.28)
		if button.has_theme_stylebox_override("normal"):
			var existing := button.get_theme_stylebox("normal") as StyleBoxFlat
			if existing:
				base_color = existing.bg_color
		var hl := StyleBoxFlat.new()
		hl.bg_color = base_color.lightened(0.12)
		hl.border_color = Color(1.0, 0.85, 0.0)
		hl.set_border_width_all(4)
		hl.set_corner_radius_all(4)
		hl.set_content_margin_all(6)
		button.add_theme_stylebox_override("normal", hl)
		button.add_theme_stylebox_override("hover", hl)

# 鎭㈠鏍煎瓙鍒版鐩樺綋鍓?token 瀵瑰簲鐨勭█鏈夊害鏍峰紡
func _restore_cell_style(pos: Vector2i, button: Button) -> void:
	var token = _board_service.get_token(pos)
	if token == null or token.definition_id.is_empty() or token.definition_id == EMPTY_TOKEN_ID:
		button.remove_theme_stylebox_override("normal")
		button.remove_theme_stylebox_override("hover")
	else:
		var definition: TokenDefinition = _content_registry.tokens.get(token.definition_id)
		var rarity: String = definition.rarity if definition else "Common"
		var style := _get_rarity_style(rarity)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)

# 鍦ㄦ牸瀛愪笂鏂圭敓鎴愬緱鍒嗘诞瀛楀苟鍚戜笂椋炲嚭娣″寲锛坒ire-and-forget锛屼笉闃诲璋冪敤鏂癸級
func _spawn_score_popup(button: Button, score_delta: int) -> void:
	var popup := Label.new()
	popup.text = "+%d" % score_delta if score_delta > 0 else "%d" % score_delta
	popup.add_theme_font_size_override("font_size", 22)
	popup.modulate = Color(1.0, 0.92, 0.15) if score_delta > 0 else Color(1.0, 0.35, 0.35)
	popup.z_index = 10
	add_child(popup)

	# 绛変竴甯ц鑺傜偣瀹屾垚甯冨眬锛岃幏鍙栫湡瀹炲昂瀵?
	await get_tree().process_frame

	var btn_rect := button.get_global_rect()
	var popup_size := popup.get_minimum_size()
	var start_global := Vector2(
		btn_rect.get_center().x - popup_size.x * 0.5,
		btn_rect.position.y - popup_size.y - 4.0
	)
	popup.global_position = start_global

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "global_position:y", start_global.y - SETTLEMENT_POPUP_RISE, 0.65)
	tween.tween_property(popup, "modulate:a", 0.0, 0.65).set_delay(0.15)
	tween.tween_callback(popup.queue_free).set_delay(0.65)

func _complete_settlement() -> void:
	if _active_state_name != "settling":
		return

	_advance_active_contract()
	_state_chart.send_event("settlement_complete")
	_sync_run_labels()

func _advance_active_contract() -> void:
	if _active_contract.is_empty():
		return
	if String(_active_contract.get("status", "active")) != "active":
		return

	_active_contract = _contract_service.advance_contract(_active_contract, {
		"score_gained": _last_settlement_score_gain,
	})
	var status := String(_active_contract.get("status", "active"))
	if status == "success" or status == "failed":
		var score_delta := _contract_service.apply_resolution_score_delta(_active_contract)
		run_session.current_score = max(0, run_session.current_score + score_delta)
		run_session.operation_history.append({
			"kind": "contract_resolved",
			"status": status,
			"score_delta": score_delta,
			"turn": run_session.current_turn,
		})
		_active_contract.clear()
		run_session.active_modifiers = []
	else:
		run_session.active_modifiers = [_active_contract.duplicate(true)]
	_sync_run_labels()

# ---------------------------------------------------------------------------
# Item helpers
# ---------------------------------------------------------------------------

# 杩斿洖褰撳墠閬撳叿鏍忎腑鎵€鏈夎鍔ㄩ亾鍏风殑 ItemDefinition 鍒楄〃锛屼緵缁撶畻鍣ㄤ娇鐢ㄣ€?
func _get_active_item_defs() -> Array:
	var defs: Array = []
	for item_id in _items:
		var item_def: ItemDefinition = _content_registry.items.get(item_id) if _content_registry else null
		if item_def != null and item_def.effect_type == "passive":
			defs.append(item_def)
	return defs

# ---------------------------------------------------------------------------
# Token helpers
# ---------------------------------------------------------------------------

func _make_active_token_instance() -> TokenInstance:
	var token_id := run_session.get_active_token_id()
	return _make_token_instance_for_id(token_id)

func _make_token_instance_for_id(token_id: String) -> TokenInstance:
	var definition: TokenDefinition = _content_registry.tokens.get(token_id)
	if definition == null:
		return TokenInstanceScript.new(token_id, PackedStringArray())
	return TokenInstanceScript.new(
		definition.id,
		definition.tags,
		definition.state_fields.duplicate(true)
	)

# ---------------------------------------------------------------------------
# UI sync helpers
# ---------------------------------------------------------------------------

func _append_log_entry(step) -> void:
	var delta_text := "%+d" % step.score_delta
	var line: String
	if step.token_pos.x >= 0:
		line = L10n.format_text("ui.settlement.log_with_pos", {
			"index": "%02d" % step.sequence_index,
			"x": step.token_pos.x,
			"y": step.token_pos.y,
			"token": step.token_name,
			"phase": L10n.phase_name(step.phase),
			"delta": delta_text,
		})
	else:
		line = L10n.format_text("ui.settlement.log_without_pos", {
			"index": "%02d" % step.sequence_index,
			"phase": L10n.phase_name(step.phase),
			"delta": delta_text,
		})
	_settlement_log_list.add_item(line)
	print(line)

func _sync_board_ui() -> void:
	for pos in _cell_buttons_by_pos.keys():
		var button: Button = _cell_buttons_by_pos[pos]
		var token = _board_service.get_token(pos)
		if token == null:
			button.text = ""
			button.icon = null
			button.tooltip_text = L10n.text("ui.board.empty")
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("hover")
		elif token.definition_id.is_empty() or token.definition_id == EMPTY_TOKEN_ID:
			button.text = L10n.text("ui.board.empty_slot_short", "空")
			button.icon = null
			button.tooltip_text = L10n.text("ui.board.empty_token")
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("hover")
		else:
			var definition: TokenDefinition = _content_registry.tokens.get(token.definition_id)
			var icon_tex := _get_token_icon(token.definition_id)
			button.text = "" if icon_tex else token.definition_id.left(2).to_upper()
			button.icon = icon_tex
			button.expand_icon = true
			button.tooltip_text = definition.get_display_name() if definition else token.definition_id
			var rarity: String = definition.rarity if definition else "Common"
			var style := _get_rarity_style(rarity)
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_stylebox_override("hover", style)

func _build_token_tooltip(definition: TokenDefinition, fallback_id: String) -> String:
	if definition == null:
		return fallback_id
	var lines: PackedStringArray = []
	lines.append(definition.get_display_name())
	lines.append("%s  |  %s" % [definition.get_display_rarity(), definition.get_display_type()])
	var translated_tags := definition.get_display_tags()
	if translated_tags.size() > 0:
		lines.append(L10n.format_text("ui.tooltip.tags", {"tags": ", ".join(translated_tags)}))
	if definition.base_value != 0:
		lines.append(L10n.format_text("ui.tooltip.base_value", {"value": definition.base_value}))
	if not definition.get_display_description().is_empty():
		lines.append("")
		lines.append(definition.get_display_description())
	return "\n".join(lines)

func _get_token_icon(definition_id: String) -> Texture2D:
	if definition_id in _token_icon_cache:
		return _token_icon_cache[definition_id]
	var path := "res://assets/icons/tokens/%s.svg" % definition_id
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_token_icon_cache[definition_id] = tex
	return tex

func _get_rarity_style(rarity: String) -> StyleBoxFlat:
	if rarity in _rarity_style_cache:
		return _rarity_style_cache[rarity]
	var bg: Color = RARITY_COLORS.get(rarity, RARITY_COLORS["Common"])
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = bg.lightened(0.35)
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	_rarity_style_cache[rarity] = style
	return style

func _on_bag_button_pressed() -> void:
	_sync_bag_panel()
	_bag_panel.visible = true

func _sync_bag_panel() -> void:
	for child in _bag_list.get_children():
		child.queue_free()

	var counts: Dictionary = {}
	for token_id in run_session.token_pool:
		counts[token_id] = counts.get(token_id, 0) + 1

	if counts.is_empty():
		var empty_label := Label.new()
		empty_label.text = L10n.text("ui.backpack.empty")
		_bag_list.add_child(empty_label)
		return

	const RARITY_ORDER := ["Legendary", "Rare", "Uncommon", "Common"]
	var sorted_ids := counts.keys()
	sorted_ids.sort_custom(func(a, b):
		var def_a: TokenDefinition = _content_registry.tokens.get(a)
		var def_b: TokenDefinition = _content_registry.tokens.get(b)
		var ra := def_a.rarity if def_a else "Common"
		var rb := def_b.rarity if def_b else "Common"
		return RARITY_ORDER.find(ra) < RARITY_ORDER.find(rb)
	)

	for token_id in sorted_ids:
		var definition: TokenDefinition = _content_registry.tokens.get(token_id)
		var rarity: String = definition.rarity if definition else "Common"
		var display_name: String = definition.get_display_name() if definition else token_id
		var count: int = counts[token_id]

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(90, 110)
		card.add_theme_stylebox_override("panel", _get_rarity_style(rarity))
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.tooltip_text = _build_token_tooltip(definition, token_id)

		var card_vbox := VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 4)
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(card_vbox)

		var icon_tex := _get_token_icon(token_id)
		if icon_tex:
			var icon_rect := TextureRect.new()
			icon_rect.texture = icon_tex
			icon_rect.custom_minimum_size = Vector2(56, 56)
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			card_vbox.add_child(icon_rect)
		else:
			var placeholder := Label.new()
			placeholder.text = token_id.left(2).to_upper()
			placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card_vbox.add_child(placeholder)

		var name_label := Label.new()
		name_label.text = display_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_vbox.add_child(name_label)

		if count > 1:
			var count_label := Label.new()
			count_label.text = L10n.format_text("ui.backpack.count", {"count": count}, "x{count}")
			count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card_vbox.add_child(count_label)

		_bag_list.add_child(card)

func _sync_run_labels() -> void:
	_run_state_label.text = L10n.format_text("ui.run.state", {"state": L10n.state_name(_active_state_name)})
	_turn_label.text = L10n.format_text("ui.run.turn", {"turn": run_session.current_turn})
	_score_label.text = L10n.format_text("ui.run.score", {"score": run_session.current_score, "target": run_session.phase_target})
	var contract_summary := get_active_contract_summary() if not _active_contract.is_empty() else L10n.text("ui.contract.none")
	_contract_label.text = L10n.format_text("ui.run.contract", {"summary": contract_summary})
	_turn_flow_mode_button.text = L10n.format_text("ui.run.mode_button", {"mode": L10n.mode_name(get_turn_flow_mode_name())})
	_mode_label.text = L10n.format_text("ui.run.action", {
		"action": L10n.mode_name(_get_mode_name()),
		"token": _format_token_name(get_active_placement_token_id()),
	})

func _sync_all_panels() -> void:
	_sync_debug_controls()
	_sync_offer_buttons()
	_sync_event_draft_ui()
	_sync_roll_board_ui()
	_sync_items_row()

func _sync_debug_controls() -> void:
	var in_player_turn := _active_state_name == "player_turn"
	_mode_label.visible = in_player_turn
	_mode_buttons.visible = in_player_turn
	_place_mode_button.visible = in_player_turn
	_remove_mode_button.visible = in_player_turn
	_settle_button.visible = in_player_turn

func _sync_offer_buttons() -> void:
	var buttons := _offer_buttons()
	var show_offers := _active_state_name == "offer_choice"

	_offer_title_label.visible = show_offers
	for index in buttons.size():
		var button: Button = buttons[index]
		var has_offer := show_offers and index < _active_offers.size()
		button.visible = has_offer
		button.disabled = not has_offer
		if has_offer:
			var offer: Dictionary = _active_offers[index]
			var token_id := String(offer.get("token_id", ""))
			var definition: TokenDefinition = _content_registry.tokens.get(token_id) if not token_id.is_empty() else null
			button.text = definition.get_display_name() if definition else _format_token_name(token_id)
			if definition:
				var style := _get_rarity_style(definition.rarity)
				button.add_theme_stylebox_override("normal", style)
				button.add_theme_stylebox_override("hover", style)
			else:
				button.remove_theme_stylebox_override("normal")
				button.remove_theme_stylebox_override("hover")
		else:
			button.text = ""
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("hover")

func _sync_event_draft_ui() -> void:
	var show_panel := _active_state_name == "event_draft"
	_event_draft_panel.visible = show_panel

	if show_panel and not _active_event_options.is_empty():
		var event_data: Dictionary = _active_event_options[0]
		var title := _resolve_event_text(event_data, "title")
		var desc := _resolve_event_text(event_data, "description")
		_event_summary_label.text = "%s\n%s" % [title, desc] if not desc.is_empty() else title

		var needs_pick: bool = bool(event_data.get("needs_token_pick", false))
		if needs_pick:
			_event_button_1.visible = false
			_event_button_1.disabled = true
			_populate_token_picker(event_data.get("eligible_tokens", []))
			_event_token_picker_scroll.visible = true
		else:
			_event_button_1.visible = true
			_event_button_1.disabled = false
			_event_button_1.text = L10n.text("ui.event_draft.confirm")
			_clear_token_picker()
	else:
		_event_summary_label.text = ""
		_event_button_1.visible = show_panel
		_event_button_1.disabled = true
		_event_button_1.text = ""
		_clear_token_picker()

	_event_button_2.visible = false
	_event_button_3.visible = false

func _populate_token_picker(token_ids: Array) -> void:
	for child in _event_token_picker_flow.get_children():
		child.queue_free()
	for token_id in token_ids:
		var btn := Button.new()
		var definition: TokenDefinition = _content_registry.tokens.get(token_id)
		btn.text = definition.get_display_name() if definition else _format_token_name(token_id)
		if definition:
			var style := _get_rarity_style(definition.rarity)
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_stylebox_override("hover", style)
		btn.pressed.connect(_on_event_token_pick_pressed.bind(token_id))
		_event_token_picker_flow.add_child(btn)

func _clear_token_picker() -> void:
	for child in _event_token_picker_flow.get_children():
		child.queue_free()
	_event_token_picker_scroll.visible = false

func _sync_items_row() -> void:
	for child in _items_row.get_children():
		child.queue_free()
	for item_id in _items:
		var item_def: ItemDefinition = _content_registry.items.get(item_id) if _content_registry else null
		var btn := Button.new()
		btn.text = item_def.get_display_name() if item_def else item_id.replace("_", " ").capitalize()
		btn.disabled = true
		btn.custom_minimum_size = Vector2(80, 36)
		if item_def and not item_def.get_display_description().is_empty():
			btn.tooltip_text = item_def.get_display_description()
		_items_row.add_child(btn)
	_items_row.visible = not _items.is_empty()

func _sync_roll_board_ui() -> void:
	_next_turn_button.visible = _active_state_name == "roll_board"
	_continue_to_reward_button.visible = _active_state_name == "settlement_result"

func _offer_buttons() -> Array[Button]:
	return [_offer_button_1, _offer_button_2, _offer_button_3]

func _event_buttons() -> Array[Button]:
	return [_event_button_1, _event_button_2, _event_button_3]

func _format_offer(offer: Dictionary) -> String:
	var token_id := String(offer.get("token_id", ""))
	if token_id.is_empty():
		return L10n.text("ui.offer.no_token")
	var definition: TokenDefinition = _content_registry.tokens.get(token_id)
	if definition != null:
		return definition.get_display_name()
	return _format_token_name(token_id)

func _format_event(event_data: Dictionary) -> String:
	return "%s [%s]" % [
		_resolve_event_text(event_data, "title"),
		L10n.tag_name(String(event_data.get("primary_tag", "tag"))),
	]

func _format_token_name(token_id: String) -> String:
	if token_id.is_empty():
		return L10n.text("ui.token.none")
	var definition: TokenDefinition = _content_registry.tokens.get(token_id)
	if definition != null:
		return definition.get_display_name()
	return token_id.replace("_", " ").capitalize()

func _resolve_event_text(event_data: Dictionary, prefix: String) -> String:
	var key := String(event_data.get("%s_key" % prefix, ""))
	var params: Dictionary = event_data.get("%s_params" % prefix, {})
	if key.is_empty():
		return String(event_data.get(prefix, ""))
	if params.is_empty():
		return L10n.text(key)
	var localized_params: Dictionary = {}
	for param_key in params.keys():
		var value = params[param_key]
		if value is String:
			localized_params[param_key] = L10n.text(String(value), String(value))
		else:
			localized_params[param_key] = value
	return L10n.format_text(key, localized_params)

func _get_mode_name() -> String:
	if _remove_mode_button.button_pressed:
		return "remove"
	return "place"
