extends GutTest

func test_smoke_playable_path_still_works() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	# Mainline: offer_choice 鈫?event_draft 鈫?roll_board 鈫?next turn 鈫?settling/settlement_result
	scene.debug_force_reward_event_complete()  # select offer[0] 鈫?event_draft
	scene.debug_force_reward_event_complete()  # select event[0] 鈫?roll_board

	var next_turn_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/NextTurnButton") as Button
	next_turn_button.emit_signal("pressed")

	assert_true(scene.get_active_state_name() in ["settling", "settlement_result"])

func test_mainline_round_progresses_without_manual_place_or_settle() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	scene.debug_force_reward_event_complete()  # offer 鈫?event_draft
	scene.debug_force_reward_event_complete()  # event 鈫?roll_board

	var next_turn_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/NextTurnButton") as Button
	next_turn_button.emit_signal("pressed")

	await _wait_for_state(scene, "settlement_result")

	assert_true(true)

func test_run_screen_builds_25_cells() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	assert_eq(scene.get_node("%BoardGrid").get_child_count(), 25)

func test_turn_flow_mode_defaults_to_auto() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	var mode_button := scene.get_node("%TurnFlowModeButton") as Button
	assert_eq(scene.get_turn_flow_mode_name(), "auto")
	assert_eq(mode_button.text, "模式：自动")

func test_next_turn_arrow_rolls_board_and_stops_on_settlement_result() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	# Navigate mainline to roll_board
	scene.debug_force_reward_event_complete()  # offer 鈫?event_draft
	scene.debug_force_reward_event_complete()  # event 鈫?roll_board
	assert_eq(scene.get_active_state_name(), "roll_board")

	var next_turn_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/NextTurnButton") as Button
	next_turn_button.emit_signal("pressed")

	await _wait_for_state(scene, "settlement_result")

	assert_eq(scene.get_active_state_name(), "settlement_result")
	assert_eq(scene.get_board_token_count(), 25)

func test_clicking_a_cell_places_a_token_during_player_turn() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	scene.debug_enter_player_turn()
	var cell := scene.get_node("%BoardGrid").get_child(0) as Button
	cell.emit_signal("pressed")

	assert_eq(cell.text, "P")

func test_remove_mode_clears_an_occupied_cell() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	scene.debug_enter_player_turn()
	var board_grid: Node = scene.get_node("%BoardGrid")
	var cell := board_grid.get_child(0) as Button
	var remove_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/ModeButtons/RemoveModeButton") as Button

	cell.emit_signal("pressed")
	remove_button.emit_signal("pressed")
	cell.emit_signal("pressed")

	assert_eq(cell.text, "")

func test_settlement_autoplay_reaches_settlement_result_in_order() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	scene.debug_enter_player_turn()
	var board_grid: Node = scene.get_node("%BoardGrid")
	var settle_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/SettleButton") as Button

	for index in [0, 1, 2]:
		var cell := board_grid.get_child(index) as Button
		cell.emit_signal("pressed")

	settle_button.emit_signal("pressed")

	assert_eq(scene.get_active_state_name(), "settling")
	assert_eq(scene.get_settlement_log_entries().size(), 0)

	await _wait_for_state(scene, "settlement_result")

	# 3 fire_common (浣欑儸) placed at (0,0),(1,0),(2,0), row 0 鈫?no fire above 鈫?3 base_output + 1 cleanup
	assert_eq(scene.get_settlement_log_entries().size(), 4)
	assert_eq(scene.get_settlement_log_entries()[0], "00 | (0,0) 余烬 | 基础产出 | +1")
	assert_eq(scene.get_settlement_log_entries()[1], "01 | (1,0) 余烬 | 基础产出 | +1")
	assert_eq(scene.get_settlement_log_entries()[2], "02 | (2,0) 余烬 | 基础产出 | +1")
	assert_eq(scene.get_settlement_log_entries()[3], "03 | 清理 | +0")
	assert_eq(scene.get_active_state_name(), "settlement_result")

func test_offer_selection_transitions_through_event_draft() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	var offer_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/OfferButton1") as Button

	assert_eq(scene.get_active_state_name(), "offer_choice")

	offer_button.emit_signal("pressed")
	assert_eq(scene.get_active_state_name(), "event_draft")

	_confirm_first_event(scene)

	assert_eq(scene.get_active_state_name(), "roll_board")

func test_set_mode_routes_event_draft_to_player_turn() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	var mode_button := scene.get_node("%TurnFlowModeButton") as Button
	var offer_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/OfferButton1") as Button
	var place_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/ModeButtons/PlaceModeButton") as Button
	var remove_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/ModeButtons/RemoveModeButton") as Button
	var settle_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/SettleButton") as Button

	mode_button.emit_signal("pressed")
	assert_eq(scene.get_turn_flow_mode_name(), "set")
	assert_eq(mode_button.text, "模式：手动")

	offer_button.emit_signal("pressed")
	assert_eq(scene.get_active_state_name(), "event_draft")

	_confirm_first_event(scene)
	assert_eq(scene.get_active_state_name(), "player_turn")
	assert_true(place_button.visible)
	assert_true(remove_button.visible)
	assert_true(settle_button.visible)

func test_switching_to_set_mode_from_roll_board_enters_player_turn() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	var mode_button := scene.get_node("%TurnFlowModeButton") as Button

	scene.debug_force_reward_event_complete()
	scene.debug_force_reward_event_complete()
	assert_eq(scene.get_active_state_name(), "roll_board")

	mode_button.emit_signal("pressed")

	assert_eq(scene.get_turn_flow_mode_name(), "set")
	assert_eq(scene.get_active_state_name(), "player_turn")

func test_switching_back_to_auto_in_player_turn_keeps_current_manual_turn() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	var mode_button := scene.get_node("%TurnFlowModeButton") as Button
	var settle_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/SettleButton") as Button

	scene.debug_force_reward_event_complete()
	scene.debug_force_reward_event_complete()
	mode_button.emit_signal("pressed")
	assert_eq(scene.get_active_state_name(), "player_turn")

	mode_button.emit_signal("pressed")
	assert_eq(scene.get_turn_flow_mode_name(), "auto")
	assert_eq(scene.get_active_state_name(), "player_turn")

	settle_button.emit_signal("pressed")
	await _wait_for_state(scene, "settlement_result")
	assert_eq(scene.get_active_state_name(), "settlement_result")

func test_add_reward_changes_the_next_rolled_board() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	var offer_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/OfferButton1") as Button

	offer_button.emit_signal("pressed")

	var rewarded_token_id: String = scene.get_active_placement_token_id()
	assert_ne(rewarded_token_id, "")
	assert_eq(scene.get_active_state_name(), "event_draft")

	_confirm_first_event(scene)

	assert_eq(scene.get_active_state_name(), "roll_board")

	var next_turn_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/NextTurnButton") as Button
	next_turn_button.emit_signal("pressed")

	await _wait_for_state(scene, "settlement_result")

	var rewarded_definition: TokenDefinition = scene._content_registry.tokens.get(rewarded_token_id)
	var rewarded_name := rewarded_definition.get_display_name() if rewarded_definition else rewarded_token_id
	assert_gt(_count_cells_with_tooltip(scene, rewarded_name), 0)

func test_empty_tokens_are_not_included_in_base_output() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	scene._board_service.place_token(Vector2i(0, 0), scene._make_token_instance_for_id("fire_common"))
	scene._board_service.place_token(Vector2i(1, 0), scene._make_token_instance_for_id("empty_token"))
	scene._board_service.place_token(Vector2i(2, 0), scene._make_token_instance_for_id("empty_token"))

	var snapshot = scene._settlement_resolver.build_snapshot(scene._board_service, scene._content_registry)
	var base_output: Array = snapshot.get_phase_effects("base_output")

	assert_eq(base_output.size(), 1)
	assert_eq(base_output[0]["source_token"], "fire_common")

func test_contract_ticks_after_a_completed_rolled_round() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	scene.debug_force_active_contract()
	assert_eq(scene.get_active_state_name(), "roll_board")

	var next_turn_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/NextTurnButton") as Button
	next_turn_button.emit_signal("pressed")

	await _wait_for_state(scene, "settlement_result")

	assert_eq(scene.get_active_contract_data()["turns_remaining"], 2)

func test_switching_back_to_auto_only_affects_next_turn_branch() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	var mode_button := scene.get_node("%TurnFlowModeButton") as Button
	var settle_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/SettleButton") as Button
	var continue_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/ContinueToRewardButton") as Button
	var offer_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/OfferButton1") as Button
	var board_grid: Node = scene.get_node("%BoardGrid")

	scene.debug_force_reward_event_complete()
	scene.debug_force_reward_event_complete()
	mode_button.emit_signal("pressed")
	assert_eq(scene.get_active_state_name(), "player_turn")

	var cell := board_grid.get_child(0) as Button
	cell.emit_signal("pressed")
	mode_button.emit_signal("pressed")
	assert_eq(scene.get_turn_flow_mode_name(), "auto")
	assert_eq(scene.get_active_state_name(), "player_turn")

	settle_button.emit_signal("pressed")
	await _wait_for_state(scene, "settlement_result")
	continue_button.emit_signal("pressed")
	assert_eq(scene.get_active_state_name(), "offer_choice")

	offer_button.emit_signal("pressed")
	assert_eq(scene.get_active_state_name(), "event_draft")
	_confirm_first_event(scene)
	assert_eq(scene.get_active_state_name(), "roll_board")

func test_contract_turns_tick_after_the_next_scored_turn() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	var board_grid: Node = scene.get_node("%BoardGrid")
	var settle_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/SettleButton") as Button
	var offer_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/OfferButton1") as Button
	var event_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/EventDraftPanel/MarginContainer/VBox/EventButton1") as Button
	var continue_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/ContinueToRewardButton") as Button

	# First turn: settle via debug path to reach settlement_result, then continue to offer_choice
	scene.debug_enter_player_turn()
	for index in [0, 1, 2]:
		var cell := board_grid.get_child(index) as Button
		cell.emit_signal("pressed")
	settle_button.emit_signal("pressed")
	await _wait_for_state(scene, "settlement_result")
	continue_button.emit_signal("pressed")
	assert_eq(scene.get_active_state_name(), "offer_choice")

	# Inject contract and navigate to roll_board, then enter player_turn via debug path
	scene.debug_force_active_contract()
	assert_eq(scene.get_active_state_name(), "roll_board")
	scene.debug_enter_player_turn()

	var initial_contract: Dictionary = scene.get_active_contract_data()
	var initial_turns := int(initial_contract.get("turns_remaining", 0))
	assert_gt(initial_turns, 0)

	for index in [3, 4, 5]:
		var next_cell := board_grid.get_child(index) as Button
		next_cell.emit_signal("pressed")

	settle_button.emit_signal("pressed")
	await _wait_for_state(scene, "settlement_result")
	continue_button.emit_signal("pressed")
	assert_eq(scene.get_active_state_name(), "offer_choice")

	var advanced_contract: Dictionary = scene.get_active_contract_data()
	assert_eq(int(advanced_contract.get("turns_remaining", 0)), initial_turns - 1)
	assert_eq(advanced_contract.get("status", ""), "active")
	assert_gt(int(advanced_contract.get("progress_value", 0)), 0)

func _spawn_run_screen():
	var packed_scene: PackedScene = load("res://scenes/run/run_screen.tscn")
	assert_not_null(packed_scene)
	if packed_scene == null:
		return null

	var scene := packed_scene.instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	return scene

func _wait_for_state(scene, expected_state: String, max_frames: int = 20) -> void:
	for _index in max_frames:
		if scene.get_active_state_name() == expected_state:
			return
		await get_tree().process_frame

	assert_eq(scene.get_active_state_name(), expected_state)

func _confirm_first_event(scene) -> void:
	var event_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/EventDraftPanel/MarginContainer/VBox/EventButton1") as Button
	if event_button.visible and not event_button.disabled:
		event_button.emit_signal("pressed")
		return

	var token_picker_flow := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/EventDraftPanel/MarginContainer/VBox/TokenPickerScroll/TokenPickerFlow") as FlowContainer
	assert_gt(token_picker_flow.get_child_count(), 0)
	var token_button := token_picker_flow.get_child(0) as Button
	token_button.emit_signal("pressed")

func _count_cells_with_tooltip(scene, tooltip_text: String) -> int:
	var board_grid: Node = scene.get_node("%BoardGrid")
	var count := 0
	for index in board_grid.get_child_count():
		var cell := board_grid.get_child(index) as Button
		if cell.tooltip_text == tooltip_text:
			count += 1
	return count
