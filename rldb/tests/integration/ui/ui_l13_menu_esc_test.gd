extends GdUnitTestSuite
## L13 follow-up (5 Nov): Esc on the open in-game menu closed it at once with the "back" cue, while a
## click off it plays the close motion and panel_close. Esc now goes through GameMenu.close_menu,
## so both paths look and sound the same.
## Story: design/owner-feedback-2026-11-05.md L13 (follow-up).

const DIR := "user://test_saves_l13_esc"


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


func _esc() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	return e


func test_esc_closes_the_menu_with_its_close_motion_and_cue() -> void:
	# Arrange
	var gs := await _screen()
	var m := gs.menu
	m.toggle()
	await get_tree().create_timer(0.4).timeout   # past the opening motion
	Sfx._reset_ui()
	# Act
	assert_bool(gs.keyboard.handle_key(_esc())).is_true()
	await await_idle_frame()
	# Assert: panel_close (never "back"), the catcher goes, and the menu is still fading out.
	assert_array(Sfx.debug_ui).contains(["panel_close"])
	assert_array(Sfx.debug_ui).not_contains(["back"])
	assert_bool(m.outside_catcher.visible).is_false()
	assert_bool(m.game_menu.visible).is_true()
	assert_float(m.game_menu.modulate.a).is_less(1.0)
	await get_tree().create_timer(0.5).timeout
	assert_bool(m.game_menu.visible).is_false()
	assert_float(m.game_menu.modulate.a).is_equal(1.0)   # left at rest for the next open
	assert_vector(m.game_menu.scale).is_equal(Vector2.ONE)


func test_esc_under_reduce_motion_hides_the_menu_at_once_with_panel_close() -> void:
	# Arrange
	var gs := await _screen()
	var m := gs.menu
	UIStyle.reduce_motion = true
	m.toggle()
	await await_idle_frame()
	Sfx._reset_ui()
	# Act
	gs.keyboard.handle_key(_esc())
	await await_idle_frame()
	# Assert
	assert_bool(m.game_menu.visible).is_false()
	assert_bool(m.outside_catcher.visible).is_false()
	assert_array(Sfx.debug_ui).contains(["panel_close"])
	assert_array(Sfx.debug_ui).not_contains(["back"])


func test_esc_then_esc_reopens_the_menu() -> void:
	# Arrange: Esc toggles the menu; a second Esc during the close motion opens it again.
	var gs := await _screen()
	var m := gs.menu
	m.toggle()
	await get_tree().create_timer(0.4).timeout
	gs.keyboard.handle_key(_esc())
	await await_idle_frame()
	# Act
	gs.keyboard.handle_key(_esc())
	await get_tree().create_timer(0.5).timeout
	# Assert: open and at rest.
	assert_bool(m.game_menu.visible).is_true()
	assert_bool(m.outside_catcher.visible).is_true()
	assert_float(m.game_menu.modulate.a).is_equal(1.0)
	assert_vector(m.game_menu.scale).is_equal(Vector2.ONE)
