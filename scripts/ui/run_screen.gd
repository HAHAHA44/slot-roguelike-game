extends Control

const BOARD_WIDTH := 5
const BOARD_HEIGHT := 5
const DEFAULT_TOKEN_ID := "pulse_seed"

const BoardServiceScript := preload("res://scripts/core/services/board_service.gd")
const TokenInstanceScript := preload("res://scripts/core/value_objects/token_instance.gd")
const RunSnapshotScript := preload("res://scripts/core/value_objects/run_snapshot.gd")
const SettlementResolverScript := preload("res://scripts/core/services/settlement_resolver.gd")
const RewardOfferServiceScript := preload("res://scripts/core/services/reward_offer_service.gd")
const RunSessionScript := preload("res://autoload/run_session.gd")

const StateChartScript := preload("res://addons/godot_state_charts/state_chart.gd")
const CompoundStateScript := preload("res://addons/godot_state_charts/compound_state.gd")
const AtomicStateScript := preload("res://addons/godot_state_charts/atomic_state.gd")
const TransitionScript := preload("res://addons/godot_state_charts/transition.gd")

const TOKEN_CELL_SCENE := preload("res://scenes/run/token_cell.tscn")

var run_session = RunSessionScript.new()
var _board_service = BoardServiceScript.new(BOARD_WIDTH, BOARD_HEIGHT)
var _settlement_resolver = SettlementResolverScript.new()
var _reward_offer_service = RewardOfferServiceScript.new()

var _cell_buttons_by_pos: Dictionary = {}
var _pending_steps: Array = []
var _active_offers: Array = []
var _active_state_name: String = ""

var _state_chart
var _boot_state
var _player_turn_state
var _settling_state
var _offer_choice_state
var _event_draft_state
var _run_failed_state
var _run_cleared_state

@onready var _board_grid: GridContainer = %BoardGrid
@onready var _run_state_label: Label = %RunStateLabel
@onready var _turn_label: Label = %TurnLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _mode_label: Label = get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/ModeLabel")
@onready var _place_mode_button: Button = get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/ModeButtons/PlaceModeButton")
@onready var _remove_mode_button: Button = get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/ModeButtons/RemoveModeButton")
@onready var _settle_button: Button = get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/SettleButton")
@onready var _offer_title_label: Label = get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/OfferTitleLabel")
@onready var _offer_button_1: Button = get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/OfferButton1")
@onready var _offer_button_2: Button = get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/OfferButton2")
@onready var _offer_button_3: Button = get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/OfferButton3")
@onready var _settlement_log_list: ItemList = get_node("MainMargin/MainLayout/ContentRow/Sidebar/SettlementLogPanel/MarginContainer/VBox/SettlementLogList")

func _ready() -> void:
	_build_state_chart()
	_wire_ui()
	_build_board_grid()
	_sync_board_ui()
	_sync_run_labels()
	_sync_offer_buttons()

func get_active_state_name() -> String:
	return _active_state_name

func _default_token_tags() -> PackedStringArray:
	return PackedStringArray(["Grow"])

func get_settlement_log_entries() -> Array[String]:
	var entries: Array[String] = []
	for index in _settlement_log_list.item_count:
		entries.append(_settlement_log_list.get_item_text(index))
	return entries

func advance_settlement_playback() -> bool:
	if _active_state_name != "settling":
		return false
	if _pending_steps.is_empty():
		return false

	var step = _pending_steps.pop_front()
	_append_log_entry(step)
	run_session.current_score += step.score_delta
	_sync_run_labels()

	if _pending_steps.is_empty():
		_complete_settlement()

	return true

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
	_run_failed_state = _make_state("RunFailed")
	_run_cleared_state = _make_state("RunCleared")

	for state in [
		_boot_state,
		_player_turn_state,
		_settling_state,
		_offer_choice_state,
		_event_draft_state,
		_run_failed_state,
		_run_cleared_state,
	]:
		root_state.add_child(state)

	_add_transition(_boot_state, "BootToPlayerTurn", NodePath("../../PlayerTurn"))
	_add_transition(_player_turn_state, "PlayerTurnToSettling", NodePath("../../Settling"), "settle")
	_add_transition(_settling_state, "SettlingToOfferChoice", NodePath("../../OfferChoice"), "settlement_complete")
	_add_transition(_offer_choice_state, "OfferChoiceToPlayerTurn", NodePath("../../PlayerTurn"), "offer_selected")

	add_child(_state_chart)

	_boot_state.state_entered.connect(_on_state_entered.bind("boot"))
	_player_turn_state.state_entered.connect(_on_state_entered.bind("player_turn"))
	_settling_state.state_entered.connect(_on_state_entered.bind("settling"))
	_offer_choice_state.state_entered.connect(_on_state_entered.bind("offer_choice"))
	_event_draft_state.state_entered.connect(_on_state_entered.bind("event_draft"))
	_run_failed_state.state_entered.connect(_on_state_entered.bind("run_failed"))
	_run_cleared_state.state_entered.connect(_on_state_entered.bind("run_cleared"))

func _make_state(name: String):
	var state = AtomicStateScript.new()
	state.name = name
	return state

func _add_transition(from_state, transition_name: String, target_path: NodePath, event_name: StringName = "") -> void:
	var transition = TransitionScript.new()
	transition.name = transition_name
	transition.to = target_path
	transition.event = event_name
	from_state.add_child(transition)

func _wire_ui() -> void:
	_place_mode_button.pressed.connect(_select_mode.bind("place"))
	_remove_mode_button.pressed.connect(_select_mode.bind("remove"))
	_settle_button.pressed.connect(_on_settle_pressed)
	_offer_button_1.pressed.connect(_on_offer_button_pressed.bind(0))
	_offer_button_2.pressed.connect(_on_offer_button_pressed.bind(1))
	_offer_button_3.pressed.connect(_on_offer_button_pressed.bind(2))

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

func _on_state_entered(state_name: String) -> void:
	_active_state_name = state_name
	if state_name != "offer_choice":
		_active_offers.clear()
	if state_name == "settling" and _pending_steps.is_empty():
		call_deferred("_complete_settlement")
	_sync_run_labels()
	_sync_offer_buttons()

func _select_mode(mode_name: String) -> void:
	_place_mode_button.set_pressed_no_signal(mode_name == "place")
	_remove_mode_button.set_pressed_no_signal(mode_name == "remove")
	run_session.operation_history.append({
		"kind": "mode_change",
		"mode": mode_name,
		"turn": run_session.current_turn,
	})
	_mode_label.text = "Mode %s" % mode_name.capitalize()

func _on_cell_pressed(pos: Vector2i) -> void:
	if _active_state_name != "player_turn":
		return

	var current_mode := _get_mode_name()
	if current_mode == "place":
		if _board_service.has_token(pos):
			return

		var token = TokenInstanceScript.new(DEFAULT_TOKEN_ID, _default_token_tags())
		if _board_service.place_token(pos, token):
			run_session.operation_history.append({
				"kind": "place_token",
				"position": {"x": pos.x, "y": pos.y},
				"turn": run_session.current_turn,
			})
	elif current_mode == "remove":
		var removed = _board_service.remove_token(pos)
		if removed != null:
			run_session.operation_history.append({
				"kind": "remove_token",
				"position": {"x": pos.x, "y": pos.y},
				"turn": run_session.current_turn,
			})

	_sync_board_ui()

func _on_settle_pressed() -> void:
	if _active_state_name != "player_turn":
		return

	var snapshot = _build_snapshot_from_board()
	var report = _settlement_resolver.resolve(snapshot)
	_pending_steps = report.steps.duplicate()
	_settlement_log_list.clear()
	_state_chart.send_event("settle")

func _on_offer_button_pressed(index: int) -> void:
	if _active_state_name != "offer_choice":
		return
	if index < 0 or index >= _active_offers.size():
		return

	var offer: Dictionary = _active_offers[index]
	run_session.operation_history.append({
		"kind": "offer_selected",
		"offer_kind": offer.get("kind", ""),
		"turn": run_session.current_turn,
	})
	run_session.current_turn += 1
	_active_offers.clear()
	_state_chart.send_event("offer_selected")
	_sync_run_labels()
	_sync_offer_buttons()

func _build_snapshot_from_board():
	var tokens_in_order: Array = []
	for row in BOARD_HEIGHT:
		for column in BOARD_WIDTH:
			var pos := Vector2i(column, row)
			if _board_service.has_token(pos):
				tokens_in_order.append(_board_service.get_token(pos))

	var phase_effects: Dictionary = {}
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

func _append_log_entry(step) -> void:
	var delta_text := "%+d" % step.score_delta
	_settlement_log_list.add_item("%02d | %s | %s" % [step.sequence_index, step.phase, delta_text])

func _complete_settlement() -> void:
	if _active_state_name != "settling":
		return

	_active_offers = _reward_offer_service.build_turn_offer(run_session)
	_state_chart.send_event("settlement_complete")
	_sync_offer_buttons()

func _sync_board_ui() -> void:
	for pos in _cell_buttons_by_pos.keys():
		var button: Button = _cell_buttons_by_pos[pos]
		var token = _board_service.get_token(pos)
		if token == null:
			button.text = ""
			button.tooltip_text = "Empty"
		else:
			button.text = "P"
			button.tooltip_text = token.definition_id

func _sync_run_labels() -> void:
	_run_state_label.text = "State %s" % _active_state_name
	_turn_label.text = "Turn %d" % run_session.current_turn
	_score_label.text = "Score %d / %d" % [run_session.current_score, run_session.phase_target]
	_mode_label.text = "Mode %s" % _get_mode_name().capitalize()

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

func _offer_buttons() -> Array[Button]:
	return [_offer_button_1, _offer_button_2, _offer_button_3]

func _format_offer(offer: Dictionary) -> String:
	return String(offer.get("kind", "offer")).replace("_", " ").capitalize()

func _get_mode_name() -> String:
	if _remove_mode_button.button_pressed:
		return "remove"
	return "place"
