extends GutTest

func test_smoke_playable_path_still_works() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	var board_grid: Node = scene.get_node("%BoardGrid")
	var settle_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/SettleButton") as Button

	var cell := board_grid.get_child(0) as Button
	cell.emit_signal("pressed")
	settle_button.emit_signal("pressed")

	assert_true(scene.get_active_state_name() in ["settling", "offer_choice", "event_draft", "player_turn"])

func test_run_screen_builds_25_cells() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	assert_eq(scene.get_node("%BoardGrid").get_child_count(), 25)

func test_clicking_a_cell_places_a_token_during_player_turn() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	var cell := scene.get_node("%BoardGrid").get_child(0) as Button
	cell.emit_signal("pressed")

	assert_eq(cell.text, "P")

func test_remove_mode_clears_an_occupied_cell() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	var board_grid: Node = scene.get_node("%BoardGrid")
	var cell := board_grid.get_child(0) as Button
	var remove_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/ModeButtons/RemoveModeButton") as Button

	cell.emit_signal("pressed")
	remove_button.emit_signal("pressed")
	cell.emit_signal("pressed")

	assert_eq(cell.text, "")

func test_settlement_autoplay_reaches_offer_choice_in_order() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	var board_grid: Node = scene.get_node("%BoardGrid")
	var settle_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/SettleButton") as Button

	for index in [0, 1, 2]:
		var cell := board_grid.get_child(index) as Button
		cell.emit_signal("pressed")

	settle_button.emit_signal("pressed")

	assert_eq(scene.get_active_state_name(), "settling")
	assert_eq(scene.get_settlement_log_entries().size(), 0)

	await _wait_for_state(scene, "offer_choice")

	assert_eq(scene.get_settlement_log_entries().size(), 4)
	assert_eq(scene.get_settlement_log_entries()[0], "00 | base_output | +1")
	assert_eq(scene.get_settlement_log_entries()[1], "01 | adjacency | +2")
	assert_eq(scene.get_settlement_log_entries()[2], "02 | row_column | +3")
	assert_eq(scene.get_settlement_log_entries()[3], "03 | cleanup | +0")
	assert_eq(scene.get_active_state_name(), "offer_choice")

func test_offer_selection_transitions_through_event_draft() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	var board_grid: Node = scene.get_node("%BoardGrid")
	var settle_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/SettleButton") as Button
	var offer_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/OfferButton1") as Button

	for index in [0, 1, 2]:
		var cell := board_grid.get_child(index) as Button
		cell.emit_signal("pressed")

	settle_button.emit_signal("pressed")
	await _wait_for_state(scene, "offer_choice")

	assert_eq(scene.get_active_state_name(), "offer_choice")

	offer_button.emit_signal("pressed")
	assert_eq(scene.get_active_state_name(), "event_draft")

	var event_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/EventDraftPanel/MarginContainer/VBox/EventButton1") as Button
	event_button.emit_signal("pressed")

	assert_eq(scene.get_active_state_name(), "player_turn")
	assert_true(scene.get_active_contract_summary().contains("Goal"))

func test_add_reward_changes_the_next_token_you_place() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	var board_grid: Node = scene.get_node("%BoardGrid")
	var settle_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/SettleButton") as Button
	var offer_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/OfferButton1") as Button

	for index in [0, 1, 2]:
		var cell := board_grid.get_child(index) as Button
		cell.emit_signal("pressed")

	settle_button.emit_signal("pressed")
	await _wait_for_state(scene, "offer_choice")

	offer_button.emit_signal("pressed")

	var rewarded_token_id: String = scene.get_active_placement_token_id()
	assert_ne(rewarded_token_id, "pulse_seed")
	assert_eq(scene.get_active_state_name(), "event_draft")

	var event_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/EventDraftPanel/MarginContainer/VBox/EventButton1") as Button
	event_button.emit_signal("pressed")

	assert_eq(scene.get_active_state_name(), "player_turn")

	var new_cell := board_grid.get_child(3) as Button
	new_cell.emit_signal("pressed")

	assert_eq(new_cell.tooltip_text, rewarded_token_id)

func test_contract_turns_tick_after_the_next_scored_turn() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	var board_grid: Node = scene.get_node("%BoardGrid")
	var settle_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/SettleButton") as Button
	var offer_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/OfferButton1") as Button
	var event_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/EventDraftPanel/MarginContainer/VBox/EventButton1") as Button

	for index in [0, 1, 2]:
		var cell := board_grid.get_child(index) as Button
		cell.emit_signal("pressed")

	settle_button.emit_signal("pressed")
	await _wait_for_state(scene, "offer_choice")
	offer_button.emit_signal("pressed")
	event_button.emit_signal("pressed")

	var initial_contract: Dictionary = scene.get_active_contract_data()
	var initial_turns := int(initial_contract.get("turns_remaining", 0))

	for index in [3, 4, 5]:
		var next_cell := board_grid.get_child(index) as Button
		next_cell.emit_signal("pressed")

	settle_button.emit_signal("pressed")
	await _wait_for_state(scene, "offer_choice")

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
