extends GutTest

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

func test_settlement_playback_stays_in_order_until_all_steps_are_consumed() -> void:
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

	assert_true(scene.advance_settlement_playback())
	assert_eq(scene.get_settlement_log_entries()[0], "00 | base_output | +1")
	assert_eq(scene.get_active_state_name(), "settling")

	assert_true(scene.advance_settlement_playback())
	assert_eq(scene.get_settlement_log_entries()[1], "01 | adjacency | +2")
	assert_eq(scene.get_active_state_name(), "settling")

	assert_true(scene.advance_settlement_playback())
	assert_eq(scene.get_settlement_log_entries()[2], "02 | row_column | +3")
	assert_eq(scene.get_active_state_name(), "settling")

	assert_true(scene.advance_settlement_playback())
	assert_eq(scene.get_settlement_log_entries()[3], "03 | cleanup | +0")
	assert_eq(scene.get_active_state_name(), "offer_choice")

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
