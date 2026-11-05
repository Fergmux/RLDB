extends GdUnitTestSuite
## L12 (owner, 5 Nov): the View lobby button is no longer on the main game screen; it lives only in
## the in-game menu. L13: while that menu is open, a click anywhere off it closes it, with its close
## cue (panel_close) and motion; the click goes no further (it does not reach the board).
## Story: design/owner-feedback-2026-11-05.md L12 L13.

const DIR := "user://test_saves_l13"


func before_test() -> void:
	SeriesStore.DIR = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	UIStyle.reduce_motion = false


func after_test() -> void:
	for fn in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, fn])


func _screen() -> GameScreen:
	var host: LocalHost = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 13, "best_of": 3, "deck_mode": "starter", "names": ["Ann", "Bea"], "mode": "local"})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 900)
	add_child(gs)
	await gs.attach(host.seats[0])
	for i in 4:
		await await_idle_frame()
	return gs


func _press(at: Vector2, button := MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	e.position = at
	e.global_position = at
	return e


func test_l13_click_off_the_menu_closes_it_with_its_cue() -> void:
	# Arrange
	var gs := await _screen()
	var m := gs.menu
	m.toggle()
	await await_idle_frame()
	assert_bool(m.game_menu.visible).is_true()
	assert_bool(m.outside_catcher.visible).is_true()
	Sfx.debug_ui.clear()
	# Act: press on the board, far from the menu.
	m.outside_catcher.gui_input.emit(_press(Vector2(300, 500)))
	await await_idle_frame()
	# Assert: the close cue plays at once, the catcher goes, the menu fades out and hides.
	assert_array(Sfx.debug_ui).contains(["panel_close"])
	assert_bool(m.outside_catcher.visible).is_false()
	await get_tree().create_timer(0.5).timeout
	assert_bool(m.game_menu.visible).is_false()
	assert_float(m.game_menu.modulate.a).is_equal(1.0)          # left at rest for the next open
	assert_vector(m.game_menu.scale).is_equal(Vector2.ONE)


func test_l13_right_click_off_the_menu_closes_it_too() -> void:
	var gs := await _screen()
	var m := gs.menu
	m.toggle()
	await await_idle_frame()
	m.outside_catcher.gui_input.emit(_press(Vector2(300, 500), MOUSE_BUTTON_RIGHT))
	await get_tree().create_timer(0.5).timeout
	assert_bool(m.game_menu.visible).is_false()


func test_l13_the_catcher_covers_the_window_under_the_menu() -> void:
	var gs := await _screen()
	var m := gs.menu
	m.toggle()
	await await_idle_frame()
	assert_int(m.outside_catcher.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_int(m.outside_catcher.z_index).is_less(m.game_menu.z_index)
	assert_vector(m.outside_catcher.size).is_equal(gs.size)


func test_l13_reopening_during_the_close_shows_it_at_rest() -> void:
	var gs := await _screen()
	var m := gs.menu
	m.toggle()
	await get_tree().create_timer(0.4).timeout
	var rest := m.game_menu.position
	assert_bool(m.close_menu()).is_true()
	await await_idle_frame()
	m.toggle()   # the Menu button again, mid-close
	await get_tree().create_timer(0.5).timeout
	assert_bool(m.game_menu.visible).is_true()
	assert_bool(m.outside_catcher.visible).is_true()
	assert_float(m.game_menu.modulate.a).is_equal(1.0)
	assert_vector(m.game_menu.position).is_equal(rest)


func test_l13_menu_items_still_work_and_hide_the_catcher() -> void:
	var gs := await _screen()
	var m := gs.menu
	m.toggle()
	await await_idle_frame()
	(m.items["settings"] as Button).pressed.emit()
	await await_idle_frame()
	assert_bool(m.game_menu.visible).is_false()
	assert_bool(m.outside_catcher.visible).is_false()
	assert_bool(m.settings_popup.visible).is_true()


func test_l12_offline_screen_has_no_view_lobby_button() -> void:
	var gs := await _screen()
	assert_bool(gs.spectate.lobby_button.visible).is_false()
	assert_bool(gs.menu.top_strip.find_children("LobbyButton", "", true, false).all(func(b): return not (b as Control).visible)).is_true()
