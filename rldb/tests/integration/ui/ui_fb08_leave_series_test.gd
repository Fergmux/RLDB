extends GdUnitTestSuite
## Playtest feedback 08, G01 and G05 on a real match screen. G01: leaving between duels offers
## Save / Forfeit / Keep playing, and saving leaves the series resumable without forfeiting it.
## G05: Start next duel (hot-seat: one press for both players; vs the bot: never blocked).

const DIR := "user://test_saves_fb08"


func before_test() -> void:
	SeriesStore.DIR = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	for fn in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, fn])


func after_test() -> void:
	for fn in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, fn])


## A hot-seat series on a screen showing seat 0, played to `stage` ("decks", "game", "rewards",
## "first_player"). Returns [screen, host].
func _screen(stage: String, mode: String = "local") -> Array:
	var host: LocalHost = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 31, "best_of": 3, "deck_mode": "starter", "names": ["A", "B"], "mode": mode})
	if stage != "decks":
		host.handle(0, {"t": "pick_starter", "index": 0})
		host.handle(1, {"t": "pick_starter", "index": 1})
	if stage in ["rewards", "first_player"]:
		host.handle(1, {"t": "concede"})          # seat 1 loses game 1
	if stage == "first_player":
		for p in 2:
			host.handle(p, {"t": "reward_finish"})
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 900)
	add_child(gs)
	await gs.attach(host.seats[0])
	await await_idle_frame()
	return [gs, host]


func _texts(d: ConfirmDialog) -> Array:
	return d.choices.map(func(c): return String(c["text"]))


func _body(d: ConfirmDialog) -> String:
	return " ".join(d.find_children("*", "Label", true, false).map(func(l): return (l as Label).text))


func test_rewards_offers_save_forfeit_keep_playing_without_forfeit_warning() -> void:
	var r: Array = await _screen("rewards")
	var gs: GameScreen = r[0]
	gs.menu.confirm_forfeit(false)
	var d := gs.menu.dialog()
	assert_object(d).is_not_null()
	assert_array(_texts(d)).is_equal(["Save and leave", "Forfeit and leave", "Keep playing"])
	assert_str(_body(d)).contains("resume it later")
	assert_str(_body(d)).not_contains("will forfeit the match")
	gs.menu.close_dialog()


func test_quit_wording_uses_quit() -> void:
	var r: Array = await _screen("first_player")
	var gs: GameScreen = r[0]
	gs.menu.confirm_forfeit(true)
	assert_array(_texts(gs.menu.dialog())).is_equal(["Save and quit", "Forfeit and quit", "Keep playing"])
	gs.menu.close_dialog()            # never press: Quit would end the test run


func test_save_and_leave_keeps_the_series_resumable_and_unforfeited() -> void:
	var r: Array = await _screen("rewards")
	var gs: GameScreen = r[0]
	var host: LocalHost = r[1]
	var left := [false]
	gs.leave_to_menu.connect(func(): left[0] = true)
	gs.menu.confirm_forfeit(false)
	assert_bool(gs.menu.dialog().press("Save and leave")).is_true()
	assert_bool(left[0]).is_true()
	assert_str(host.series.stage).is_equal(Series.STAGE_REWARDS)
	assert_int(host.series.forfeit_by).is_equal(-1)
	var saves := SeriesStore.list()
	assert_int(saves.size()).is_equal(1)
	assert_str(String(saves[0]["id"])).is_equal(host.series.save_id)
	assert_object(SeriesStore.load_series(host.series.save_id)).is_not_null()


func test_save_at_first_stage_keeps_the_loser_choice() -> void:
	var r: Array = await _screen("first_player")
	var gs: GameScreen = r[0]
	var host: LocalHost = r[1]
	host.handle(1, {"t": "first_player", "who": 0})
	gs.menu.confirm_forfeit(false)
	gs.menu.dialog().press("Save and leave")
	var back := SeriesStore.load_series(host.series.save_id)
	assert_str(back.stage).is_equal(Series.STAGE_FIRST)
	assert_bool(back.first_chosen).is_true()
	assert_int(back.first_player).is_equal(0)


func test_forfeit_and_leave_still_forfeits() -> void:
	var r: Array = await _screen("rewards")
	var gs: GameScreen = r[0]
	var host: LocalHost = r[1]
	gs.menu.confirm_forfeit(false)
	gs.menu.dialog().press("Forfeit and leave")
	assert_str(host.series.stage).is_equal(Series.STAGE_OVER)
	assert_int(host.series.forfeit_by).is_equal(0)
	assert_int(SeriesStore.list().size()).is_equal(0)


func test_keep_playing_changes_nothing() -> void:
	var r: Array = await _screen("rewards")
	var gs: GameScreen = r[0]
	var host: LocalHost = r[1]
	gs.menu.confirm_forfeit(false)
	gs.menu.dialog().press("Keep playing")
	await await_idle_frame()
	assert_object(gs.menu.dialog()).is_null()
	assert_str(host.series.stage).is_equal(Series.STAGE_REWARDS)
	assert_int(host.series.forfeit_by).is_equal(-1)


func test_mid_duel_explains_that_leaving_forfeits() -> void:
	var r: Array = await _screen("game")
	var gs: GameScreen = r[0]
	gs.menu.confirm_forfeit(false)
	var d := gs.menu.dialog()
	assert_array(_texts(d)).is_equal(["Forfeit and leave", "Keep playing"])
	assert_str(_body(d)).contains("saved between duels")
	gs.menu.close_dialog()


func test_deck_choice_offers_abandon() -> void:
	var r: Array = await _screen("decks")
	var gs: GameScreen = r[0]
	gs.menu.confirm_forfeit(false)
	assert_array(_texts(gs.menu.dialog())).is_equal(["Abandon and leave", "Keep playing"])
	gs.menu.close_dialog()


func test_suspend_mid_duel_is_refused_and_forfeits_nothing() -> void:
	var r: Array = await _screen("game")
	var host: LocalHost = r[1]
	var errs := []
	host.error.connect(func(_s, t): errs.append(t))
	host.handle(0, {"t": "suspend"})
	assert_int(errs.size()).is_equal(1)
	assert_str(host.series.stage).is_equal(Series.STAGE_GAME)
	assert_int(host.series.forfeit_by).is_equal(-1)


func test_hotseat_start_press_starts_the_duel_for_both() -> void:
	var r: Array = await _screen("first_player")
	var host: LocalHost = r[1]
	host.handle(1, {"t": "first_player", "who": 1})
	host.handle(1, {"t": "start_duel"})
	assert_str(host.series.stage).is_equal(Series.STAGE_GAME)
	assert_int(host.series.game.active).is_equal(1)


func test_bot_mode_needs_each_seat_and_the_bot_readies_itself() -> void:
	var r: Array = await _screen("first_player", "bot")
	var host: LocalHost = r[1]
	host.handle(1, {"t": "first_player", "who": 0})
	host.handle(0, {"t": "start_duel"})
	assert_str(host.series.stage).is_equal(Series.STAGE_FIRST)      # not hot-seat: seat 1 must press
	var brain := BotBrain.new(1)
	assert_dict(brain.series_command(host.series)).is_equal({"t": "start_duel"})
	host.handle(1, brain.series_command(host.series))
	assert_str(host.series.stage).is_equal(Series.STAGE_GAME)


func test_start_next_duel_button_is_centred_and_waits_for_the_choice() -> void:
	var r: Array = await _screen("first_player", "bot")
	var gs: GameScreen = r[0]
	var host: LocalHost = r[1]
	await await_idle_frame()
	var start := _button(gs, "Start next duel")
	assert_object(start).is_not_null()
	assert_bool(start.disabled).is_false()              # seat 0 won: nothing to choose
	assert_int(start.size_flags_horizontal).is_equal(Control.SIZE_SHRINK_CENTER)
	var labels: Array = gs.overlays.overlay_box.find_children("*", "Label", true, false).filter(func(l): return (l as Label).text.contains("choosing who goes first"))
	assert_int(labels.size()).is_equal(1)
	assert_int(labels[0].horizontal_alignment).is_equal(HORIZONTAL_ALIGNMENT_CENTER)
	start.pressed.emit()
	await await_idle_frame()
	assert_bool(host.series.duel_ready[0]).is_true()
	assert_str(host.series.stage).is_equal(Series.STAGE_FIRST)


func _button(gs: GameScreen, text: String) -> Button:
	for b in gs.overlays.overlay_box.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null
