extends Control

const BOARD_WIDTH := 5
const BOARD_HEIGHT := 5
const DEFAULT_TOKEN_ID := "pulse_seed"
const EMPTY_TOKEN_ID := "empty_token"

const BoardServiceScript := preload("res://scripts/core/services/board_service.gd")
const BoardRollServiceScript := preload("res://scripts/core/services/board_roll_service.gd")
const TokenInstanceScript := preload("res://scripts/core/value_objects/token_instance.gd")
const RunSnapshotScript := preload("res://scripts/core/value_objects/run_snapshot.gd")
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
var _settlement_autoplay_running := false
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
@onready var _mode_label: Label = get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/ModeLabel")
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
@onready var _settlement_log_list: ItemList = get_node("MainMargin/MainLayout/ContentRow/Sidebar/SettlementLogPanel/MarginContainer/VBox/SettlementLogList")

func _ready() -> void:
	_content_registry.load_all()
	_event_draft_service = EventDraftServiceScript.new(_content_registry)
	_selected_hero = _content_registry.heroes.get("resolve_specialist")
	_selected_difficulty = _content_registry.difficulty_modifiers.get("ascension_1")
	_build_state_chart()
	_wire_ui()
	_build_board_grid()
	_sync_board_ui()
	_sync_run_labels()
	_sync_all_panels()

# ---------------------------------------------------------------------------
# Public API (also used by tests)
# ---------------------------------------------------------------------------

func get_active_state_name() -> String:
	return _active_state_name

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
		_on_event_button_pressed(0)

func debug_force_active_contract() -> void:
	# Selects first offer and first event to establish a real active contract,
	# ending in roll_board state ready for NextTurnButton.
	if _active_state_name == "offer_choice":
		debug_force_reward_event_complete()  # → event_draft
	if _active_state_name == "event_draft":
		debug_force_reward_event_complete()  # → roll_board

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

	# Default mainline: Boot → OfferChoice → EventDraft → RollBoard → Settling → SettlementResult → OfferChoice
	_add_transition(_boot_state, "BootToOfferChoice", NodePath("../../OfferChoice"))
	_add_transition(_offer_choice_state, "OfferChoiceToEventDraft", NodePath("../../EventDraft"), "offer_selected")
	_add_transition(_event_draft_state, "EventDraftToRollBoard", NodePath("../../RollBoard"), "event_selected")
	_add_transition(_roll_board_state, "RollBoardToSettling", NodePath("../../Settling"), "next_turn")
	_add_transition(_settling_state, "SettlingToSettlementResult", NodePath("../../SettlementResult"), "settlement_complete")
	_add_transition(_settlement_result_state, "SettlementResultToOfferChoice", NodePath("../../OfferChoice"), "continue_to_reward")

	# Debug path: manual placement → settle → settlement_result path
	_add_transition(_offer_choice_state, "OfferChoiceToPlayerTurn", NodePath("../../PlayerTurn"), "debug_player_turn")
	_add_transition(_roll_board_state, "RollBoardToPlayerTurn", NodePath("../../PlayerTurn"), "debug_player_turn")
	_add_transition(_event_draft_state, "EventDraftToPlayerTurn", NodePath("../../PlayerTurn"), "debug_player_turn")
	_add_transition(_player_turn_state, "PlayerTurnToSettling", NodePath("../../Settling"), "settle")

	add_child(_state_chart)

	_boot_state.state_entered.connect(_on_state_entered.bind("boot"))
	_player_turn_state.state_entered.connect(_on_state_entered.bind("player_turn"))
	_settling_state.state_entered.connect(_on_state_entered.bind("settling"))
	_offer_choice_state.state_entered.connect(_on_state_entered.bind("offer_choice"))
	_event_draft_state.state_entered.connect(_on_state_entered.bind("event_draft"))
	_roll_board_state.state_entered.connect(_on_state_entered.bind("roll_board"))
	_settlement_result_state.state_entered.connect(_on_state_entered.bind("settlement_result"))
	_run_failed_state.state_entered.connect(_on_state_entered.bind("run_failed"))
	_run_cleared_state.state_entered.connect(_on_state_entered.bind("run_cleared"))

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

# Debug / legacy manual settle (player_turn path).
func _on_settle_pressed() -> void:
	if _active_state_name != "player_turn":
		return

	var snapshot = _build_snapshot_from_board()
	var report = _settlement_resolver.resolve(snapshot)
	_pending_steps = report.steps.duplicate()
	_last_settlement_score_gain = 0
	_settlement_log_list.clear()
	_state_chart.send_event("settle")

# Mainline: next-turn arrow rolls the board then auto-settles.
func _on_next_turn_pressed() -> void:
	if _active_state_name != "roll_board":
		return

	_roll_board_from_pool()
	var snapshot = _build_snapshot_from_board()
	var report = _settlement_resolver.resolve(snapshot)
	_pending_steps = report.steps.duplicate()
	_last_settlement_score_gain = 0
	_settlement_log_list.clear()
	_state_chart.send_event("next_turn")

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
	var draft: Dictionary = _event_draft_service.build_offer(
		_build_snapshot_from_board(),
		_run_modifier_service.hero_tag_modifiers(_selected_hero) if _selected_hero != null else {},
		_run_modifier_service.difficulty_tag_modifiers(_selected_difficulty) if _selected_difficulty != null else {}
	)
	_active_event_options = draft["options"]
	_state_chart.send_event("offer_selected")
	_sync_run_labels()
	_sync_all_panels()

func _on_event_button_pressed(index: int) -> void:
	if _active_state_name != "event_draft":
		return
	if index < 0 or index >= _active_event_options.size():
		return

	var event_data: Dictionary = _active_event_options[index]
	_active_contract = _contract_service.build_contract(event_data)
	if _selected_hero != null:
		_active_contract["penalty_bundle"] = _run_modifier_service.apply_hero_to_penalty(
			_selected_hero,
			_active_contract.get("penalty_bundle", {})
		)
	run_session.operation_history.append({
		"kind": "event_selected",
		"event_id": event_data.get("id", ""),
		"turn": run_session.current_turn,
	})
	run_session.active_modifiers = [_active_contract.duplicate(true)]
	run_session.current_turn += 1
	_state_chart.send_event("event_selected")
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

	_sync_board_ui()

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
	while _active_state_name == "settling" and not _pending_steps.is_empty():
		advance_settlement_playback()
		if _active_state_name != "settling" or _pending_steps.is_empty():
			break
		await get_tree().process_frame

	_settlement_autoplay_running = false

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
# Snapshot (transitional synthetic builder – real scorer comes in later task)
# ---------------------------------------------------------------------------

func _build_snapshot_from_board():
	var tokens_in_order: Array = []
	var board_tags: Dictionary = {}
	for row in BOARD_HEIGHT:
		for column in BOARD_WIDTH:
			var pos := Vector2i(column, row)
			if _board_service.has_token(pos):
				var token = _board_service.get_token(pos)
				# Skip empty tokens – they don't contribute to the synthetic snapshot.
				if token.definition_id == EMPTY_TOKEN_ID:
					continue
				tokens_in_order.append(token)
				for tag in token.tags:
					board_tags[tag] = int(board_tags.get(tag, 0)) + 1

	var phase_effects: Dictionary = {}
	phase_effects["board_tags"] = board_tags
	if tokens_in_order.size() > 0:
		phase_effects["base_output"] = [
			_make_effect(tokens_in_order[0].definition_id, "base_output", 1)
		]
	if tokens_in_order.size() > 1:
		phase_effects["adjacency"] = [
			_make_effect(tokens_in_order[1].definition_id, "adjacency", 2)
		]
	if tokens_in_order.size() > 2:
		phase_effects["row_column"] = [
			_make_effect(tokens_in_order[2].definition_id, "row_column", 3)
		]

	phase_effects["cleanup"] = [
		_make_effect("system", "cleanup", 0)
	]

	return RunSnapshotScript.new(phase_effects)

func _make_effect(source_token: String, phase_name: String, score_delta: int) -> Dictionary:
	return {
		"source_token": source_token,
		"target_token": source_token,
		"score_delta": score_delta,
		"message_key": phase_name,
	}

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
	_settlement_log_list.add_item("%02d | %s | %s" % [step.sequence_index, step.phase, delta_text])

func _sync_board_ui() -> void:
	for pos in _cell_buttons_by_pos.keys():
		var button: Button = _cell_buttons_by_pos[pos]
		var token = _board_service.get_token(pos)
		if token == null:
			button.text = ""
			button.tooltip_text = "Empty"
		elif token.definition_id == EMPTY_TOKEN_ID:
			button.text = "·"
			button.tooltip_text = "Empty token"
		else:
			button.text = "P"
			button.tooltip_text = token.definition_id

func _sync_run_labels() -> void:
	_run_state_label.text = "State %s" % _active_state_name
	_turn_label.text = "Turn %d" % run_session.current_turn
	_score_label.text = "Score %d / %d" % [run_session.current_score, run_session.phase_target]
	_contract_label.text = "Contract %s" % (get_active_contract_summary() if not _active_contract.is_empty() else "None")
	_mode_label.text = "Mode %s | Next %s" % [_get_mode_name().capitalize(), _format_token_name(get_active_placement_token_id())]

func _sync_all_panels() -> void:
	_sync_debug_controls()
	_sync_offer_buttons()
	_sync_event_draft_ui()
	_sync_roll_board_ui()

func _sync_debug_controls() -> void:
	var in_player_turn := _active_state_name == "player_turn"
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
		button.text = _format_offer(_active_offers[index]) if has_offer else ""

func _sync_event_draft_ui() -> void:
	var buttons := _event_buttons()
	var show_panel := _active_state_name == "event_draft"

	_event_draft_panel.visible = show_panel
	_event_summary_label.text = "Choose an event."
	if show_panel and not _active_event_options.is_empty():
		_event_summary_label.text = String(_active_event_options[0].get("description", "Choose an event."))

	for index in buttons.size():
		var button: Button = buttons[index]
		var has_event := show_panel and index < _active_event_options.size()
		button.visible = has_event
		button.disabled = not has_event
		button.text = _format_event(_active_event_options[index]) if has_event else ""

func _sync_roll_board_ui() -> void:
	_next_turn_button.visible = _active_state_name == "roll_board"
	_continue_to_reward_button.visible = _active_state_name == "settlement_result"

func _offer_buttons() -> Array[Button]:
	return [_offer_button_1, _offer_button_2, _offer_button_3]

func _event_buttons() -> Array[Button]:
	return [_event_button_1, _event_button_2, _event_button_3]

func _format_offer(offer: Dictionary) -> String:
	var label := String(offer.get("kind", "offer")).replace("_", " ").capitalize()
	var token_id := String(offer.get("token_id", ""))
	if not token_id.is_empty():
		label += " %s" % _format_token_name(token_id)
	return label

func _format_event(event_data: Dictionary) -> String:
	return "%s [%s]" % [event_data.get("name", event_data.get("id", "Event")), event_data.get("primary_tag", "Tag")]

func _format_token_name(token_id: String) -> String:
	if token_id.is_empty():
		return "No-op"
	var definition: TokenDefinition = _content_registry.tokens.get(token_id)
	if definition != null:
		return definition.name
	return token_id.replace("_", " ").capitalize()

func _get_mode_name() -> String:
	if _remove_mode_button.button_pressed:
		return "remove"
	return "place"
