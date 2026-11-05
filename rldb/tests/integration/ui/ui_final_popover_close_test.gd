extends GdUnitTestSuite
## Final L-batch review (design/review-final-2026-11-05.md, item e): every in-game popover closes
## the way the in-game menu does since L13 — the panel_close cue and a closing motion — and the Lobby
## list (opened from that menu) also closes on a press anywhere off it. Before, the Settings popup
## vanished silently, and the Lobby list and the Chat box vanished with the "back" cue.

const DIR := "user://test_saves_final_popover"


func before_test() -> void:
	SeriesStore.DIR = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	UIStyle.reduce_motion = false


func after_test() -> void:
	UIStyle.reduce_motion = false
	for fn in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, fn])


func _screen() -> GameScreen:
	var host: LocalHost = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 5, "best_of": 3, "deck_mode": "starter", "names": ["Ann", "Bea"], "mode": "local"})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	await gs.attach(host.seats[0])
	for i in 4:
		await await_idle_frame()
	return gs


func _press(at: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = at
	e.global_position = at
	return e


func _open_settings(gs: GameScreen) -> HousePanel:
	gs.menu._show_popup(gs.menu.settings_popup)
	await get_tree().create_timer(0.4).timeout
	Sfx._reset_ui()
	return gs.menu.settings_popup as HousePanel


func test_settings_close_button_plays_panel_close_and_its_motion() -> void:
	# Arrange
	var gs := await _screen()
	var sp := await _open_settings(gs)
	# Act
	(sp.find_child("Close", true, false) as Button).pressed.emit()
	await await_idle_frame()
	# Assert: one close cue (a pressed button's own "back" click outranks panel_close in its frame,
	# F22), still fading on the next frame, then hidden and left at rest.
	assert_int(Sfx.debug_ui.size()).is_equal(1)
	assert_bool(Sfx.debug_ui[0] in ["back", "panel_close"]).is_true()
	assert_bool(sp.visible).is_true()
	assert_float(sp.modulate.a).is_less(1.0)
	await get_tree().create_timer(0.5).timeout
	assert_bool(sp.visible).is_false()
	assert_float(sp.modulate.a).is_equal(1.0)


func test_settings_veil_click_and_esc_close_the_same_way() -> void:
	var gs := await _screen()
	var sp := await _open_settings(gs)
	# Act: a click on the veil.
	gs.menu.settings_veil.gui_input.emit(_press(Vector2(40, 500)))
	await await_idle_frame()
	# Assert
	assert_array(Sfx.debug_ui).contains(["panel_close"])
	assert_array(Sfx.debug_ui).not_contains(["back"])
	await get_tree().create_timer(0.5).timeout
	assert_bool(sp.visible).is_false()
	# Esc: the same cue, never "back".
	sp = await _open_settings(gs)
	assert_bool(gs.selection.cancel()).is_true()
	assert_array(Sfx.debug_ui).contains(["panel_close"])
	assert_array(Sfx.debug_ui).not_contains(["back"])


func test_lobby_list_closes_on_a_press_off_it_with_panel_close() -> void:
	# Arrange
	var gs := await _screen()
	var sp := gs.spectate
	sp.toggle_list()
	await get_tree().create_timer(0.4).timeout
	assert_bool(sp.is_open()).is_true()
	assert_bool(sp.outside_catcher.visible).is_true()
	Sfx._reset_ui()
	# Act: press on the board, far from the list.
	sp.outside_catcher.gui_input.emit(_press(Vector2(300, 500)))
	await await_idle_frame()
	# Assert
	assert_array(Sfx.debug_ui).contains(["panel_close"])
	assert_array(Sfx.debug_ui).not_contains(["back"])
	assert_bool(sp.outside_catcher.visible).is_false()
	await get_tree().create_timer(0.5).timeout
	assert_bool(sp.panel.visible).is_false()


func test_lobby_list_closes_on_esc_with_panel_close() -> void:
	var gs := await _screen()
	gs.spectate.toggle_list()
	await get_tree().create_timer(0.4).timeout
	Sfx._reset_ui()
	# Act
	assert_bool(gs.selection.cancel()).is_true()
	# Assert
	assert_array(Sfx.debug_ui).contains(["panel_close"])
	assert_bool(gs.spectate.is_open()).is_false()


func test_house_panel_dismiss_then_appear_takes_it_back_at_rest() -> void:
	# Arrange: a popover on its way out is reopened mid-motion (the Chat box toggled twice quickly).
	var p: HousePanel = auto_free(HousePanel.new("Chat", "", Vector2(16, 16), 8))
	p.size = Vector2(300, 200)
	add_child(p)
	p.appear()
	await get_tree().create_timer(0.4).timeout
	p.dismiss()
	await await_idle_frame()
	assert_bool(p.dismissing).is_true()
	assert_bool(p.is_open()).is_false()
	# Act
	p.appear()
	await get_tree().create_timer(0.6).timeout
	# Assert
	assert_bool(p.visible).is_true()
	assert_bool(p.is_open()).is_true()
	assert_float(p.modulate.a).is_equal(1.0)


func test_house_panel_dismiss_under_reduce_motion_still_plays_the_cue() -> void:
	UIStyle.reduce_motion = true
	var p: HousePanel = auto_free(HousePanel.new("Lobby", "", Vector2(16, 16), 8))
	p.size = Vector2(300, 200)
	add_child(p)
	p.visible = true
	Sfx._reset_ui()
	# Act
	p.dismiss()
	await get_tree().create_timer(0.3).timeout
	# Assert
	assert_array(Sfx.debug_ui).contains(["panel_close"])
	assert_bool(p.visible).is_false()
