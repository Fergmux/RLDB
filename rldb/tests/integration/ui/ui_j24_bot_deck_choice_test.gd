extends GdUnitTestSuite
## J24 (owner, 22 Oct): Play vs Bot with "Custom decks" offers "Choose the bot's deck". When it is
## on, choosing your deck opens a second deck screen ("Choose the bot's deck", with Back) instead of
## starting the game; the bot then plays the deck chosen there, locked in through the Series like
## any deck choice (so the telemetry source / Structure-deck name and the stats stay right). The
## choice is remembered for this viewer, in the TEST settings file during automated runs.

const DIR := "user://test_saves_j24"


func before_test() -> void:
	SeriesStore.DIR = DIR
	DirAccess.make_dir_recursive_absolute(DIR)


func after_test() -> void:
	for fn in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, fn])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SessionOptions.TEST_PREFS_PATH))


func _host(pick: bool, deck_mode: String = "starter") -> LocalHost:
	var host: LocalHost = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 24, "best_of": 3, "deck_mode": deck_mode, "names": ["Player", "Bot"], "mode": "bot", "bot_deck_pick": pick})
	return host


func _screen(host: LocalHost) -> GameScreen:
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 900)
	add_child(gs)
	gs.overlays.decks.tab = "structured"   # the Structure decks (the saved list varies by machine)
	await gs.attach(host.seats[0])
	await await_idle_frame()
	return gs


func _tiles(gs: GameScreen) -> Array:
	return gs.overlays.overlay.find_children("*", "DeckTile", true, false)


# ---------------------------------------------------------------- options

func test_choice_is_remembered_in_the_test_settings_file() -> void:
	assert_str(SessionOptions.PREFS_PATH).is_equal(SessionOptions.TEST_PREFS_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SessionOptions.TEST_PREFS_PATH))
	assert_bool(SessionOptions.new().choose_bot_deck).is_false()
	SessionOptions.new().set_choose_bot_deck(true)
	assert_bool(SessionOptions.new().choose_bot_deck).is_true()
	SessionOptions.new().set_choose_bot_deck(false)
	assert_bool(SessionOptions.load_choose_bot_deck()).is_false()


func test_bot_deck_pick_needs_the_option_and_custom_decks() -> void:
	var o := SessionOptions.new()
	o.choose_bot_deck = true
	assert_bool(o.bot_deck_pick({"deck_mode": "starter"})).is_true()
	assert_bool(o.bot_deck_pick({"deck_mode": "draft"})).is_false()
	o.choose_bot_deck = false
	assert_bool(o.bot_deck_pick({"deck_mode": "starter"})).is_false()


# ---------------------------------------------------------------- host + bot

func test_bot_waits_for_its_deck_only_when_the_player_chooses_it() -> void:
	var on := _host(true)
	assert_dict(BotBrain.new(1).series_command(on.series)).is_empty()
	var off := _host(false)
	assert_str(String(BotBrain.new(1).series_command(off.series).get("t", ""))).is_equal("pick_starter")


func test_bot_deck_locks_the_chosen_structure_deck_with_its_telemetry_source() -> void:
	var host := _host(true)
	var tc := TelemetryCollector.new()
	tc.attach(host.series, "bot", "local")
	host.handle(0, {"t": "bot_deck", "deck": {"t": "pick_starter", "index": 2}})
	var s := host.series
	assert_bool(s.deck_ready[1]).is_true()
	assert_bool(s.deck_ready[0]).is_false()
	assert_str(String(s.deck_names[1])).is_equal(String(s.starters[2]["name"]))
	assert_dict(tc.deck_src[1]).is_equal({"source": "prebuilt", "name": String(s.starters[2]["name"])})
	assert_str(String(tc.participant(1)["kind"])).is_equal("bot")
	tc.detach()


func test_bot_deck_custom_deck_is_tagged_custom() -> void:
	var host := _host(true)
	var tc := TelemetryCollector.new()
	tc.attach(host.series, "bot", "local")
	var cards: Array = host.series.starters[0]["main"].slice(0, 12)
	host.handle(0, {"t": "bot_deck", "deck": {"t": "custom_deck", "cards": cards, "name": "Mine"}})
	assert_bool(host.series.deck_ready[1]).is_true()
	assert_str(String(tc.deck_src[1]["source"])).is_equal("custom")
	assert_str(String(tc.deck_src[1]["name"])).is_equal("")   # free text is never sent
	tc.detach()


func test_bot_deck_is_refused_without_the_option_or_from_the_bot_seat() -> void:
	var off := _host(false)
	off.handle(0, {"t": "bot_deck", "deck": {"t": "pick_starter", "index": 0}})
	assert_bool(off.series.deck_ready[1]).is_false()
	var on := _host(true)
	on.handle(1, {"t": "bot_deck", "deck": {"t": "pick_starter", "index": 0}})
	assert_bool(on.series.deck_ready[1]).is_false()
	on.handle(0, {"t": "bot_deck", "deck": {"t": "concede"}})
	assert_bool(on.series.deck_ready[1]).is_false()


# ---------------------------------------------------------------- the two deck screens

func test_your_pick_opens_the_bot_deck_screen_and_back_returns() -> void:
	var host := _host(true)
	var gs := await _screen(host)
	var ov := gs.overlays
	assert_str(ov.stage_title("decks")).is_equal("Choose your deck")
	assert_object(ov.overlay_box.find_child("NextHint", true, false)).is_not_null()
	(_tiles(gs)[0] as DeckTile).chosen.emit()
	await await_idle_frame()
	assert_str(host.series.stage).is_equal(Series.STAGE_DECKS)
	assert_bool(host.series.deck_ready[0]).is_false()
	assert_bool(ov.decks.bot_stage()).is_true()
	assert_str(ov.stage_title("decks")).is_equal("Choose the bot's deck")
	var back: Button = ov.overlay_box.find_child("BotDeckBack", true, false)
	assert_object(back).is_not_null()
	back.pressed.emit()
	await await_idle_frame()
	assert_bool(ov.decks.bot_stage()).is_false()
	assert_str(ov.stage_title("decks")).is_equal("Choose your deck")
	# Esc goes back too.
	(_tiles(gs)[0] as DeckTile).chosen.emit()
	await await_idle_frame()
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	assert_bool(gs.keyboard.handle_key(esc)).is_true()
	assert_bool(ov.decks.bot_stage()).is_false()
	assert_bool(gs.menu.game_menu.visible).is_false()


func test_bot_deck_pick_starts_the_game_with_both_chosen_decks() -> void:
	var host := _host(true)
	var gs := await _screen(host)
	var s := host.series
	(_tiles(gs)[0] as DeckTile).chosen.emit()   # yours: Structure deck 0
	await await_idle_frame()
	(_tiles(gs)[3] as DeckTile).chosen.emit()   # the bot's: Structure deck 3
	await await_idle_frame()
	assert_str(s.stage).is_equal(Series.STAGE_GAME)
	assert_str(String(s.deck_names[0])).is_equal(String(s.starters[0]["name"]))
	assert_str(String(s.deck_names[1])).is_equal(String(s.starters[3]["name"]))
	assert_bool(gs.overlays.decks.bot_stage()).is_false()


func test_without_the_option_your_pick_locks_in_at_once() -> void:
	var host := _host(false)
	var gs := await _screen(host)
	assert_object(gs.overlays.overlay_box.find_child("BotDeckBar", true, false)).is_null()
	(_tiles(gs)[1] as DeckTile).chosen.emit()
	await await_idle_frame()
	assert_bool(host.series.deck_ready[0]).is_true()
	assert_bool(gs.overlays.decks.bot_stage()).is_false()
