extends GdUnitTestSuite
## Local player statistics (Decks > Statistics): the store, the observer on the real series and
## rules engine (bot, hot-seat, network client), the facts list and the modal.


func before_test() -> void:
	PlayerStats.clear()


func after_test() -> void:
	PlayerStats.clear()


func _series(mode: String) -> Series:
	var s := Series.new()
	s.setup({"seed": 11, "best_of": 3})
	StatsObserver.attach(s, mode, "local")
	s.submit(0, {"t": "pick_starter", "index": 0})
	s.submit(1, {"t": "pick_starter", "index": 1})
	return s


func _fact(facts: Array, label: String) -> Dictionary:
	for f in facts:
		if f["label"] == label:
			return f
	return {}


func test_automated_runs_never_use_the_players_file() -> void:
	assert_str(PlayerStats.PATH).is_equal(PlayerStats.TEST_PATH)


func test_no_duels_means_no_facts() -> void:
	assert_array(PlayerStats.facts()).is_empty()


func test_bot_duel_records_result_deck_and_damage() -> void:
	var s := _series("bot")
	s.game.change_hp(1, -7, " (test)")
	s.game.change_hp(1, -999, " (test)")
	s._on_game_over()
	var duels: Array = PlayerStats.load_data()["duels"]
	assert_int(duels.size()).is_equal(1)
	var d: Dictionary = duels[0]
	assert_str(String(d["mode"])).is_equal("bot")
	assert_bool(d["won"]).is_true()
	assert_int(int(d["best_hit"])).is_equal(999)
	assert_int(int(d["damage"])).is_equal(1006)
	var copies := 0
	for k in d["cards"]:
		copies += int(d["cards"][k])
	assert_int(copies).is_equal(s.decks[0].size())
	assert_str(String(d["deck"])).is_equal(String(s.deck_names[0]))


func test_damage_to_the_local_seat_is_not_counted_as_dealt() -> void:
	var s := _series("bot")
	s.game.change_hp(0, -5, " (test)")
	s.game.change_hp(0, -999, " (test)")
	s._on_game_over()
	var d: Dictionary = PlayerStats.load_data()["duels"][0]
	assert_bool(d["won"]).is_false()
	assert_int(int(d["damage"])).is_equal(0)


func test_hot_seat_counts_duels_but_no_win_loss() -> void:
	var s := _series("local")
	s.game.change_hp(1, -999, " (test)")
	s._on_game_over()
	var d: Dictionary = PlayerStats.load_data()["duels"][0]
	assert_that(d["won"]).is_null()
	var facts := PlayerStats.facts()
	assert_str(String(_fact(facts, "Duels played")["value"])).is_equal("1")
	assert_dict(_fact(facts, "Win rate")).is_empty()


func test_series_result_is_recorded_once_from_the_local_seat() -> void:
	var s := _series("bot")
	for g in 2:
		s.game.change_hp(1, -999, " (test)")
		s._on_game_over()
		if s.stage != Series.STAGE_OVER:
			for p in 2:
				s.submit(p, {"t": "reward_finish"})
			s.submit(s.last_loser, {"t": "first_player", "who": 0})
			for q in 2:
				s.submit(q, {"t": "start_duel"})   # G05
	var series: Array = PlayerStats.load_data()["series"]
	assert_int(series.size()).is_equal(1)
	assert_bool(series[0]["won"]).is_true()
	assert_int(PlayerStats.load_data()["duels"].size()).is_equal(2)


func test_bot_look_ahead_copies_record_nothing() -> void:
	var s := _series("bot")
	var sim: MatchEngine = s.game.clone_for_sim()
	assert_object(sim.stats_observer).is_null()
	sim.change_hp(1, -999, " (sim)")
	assert_int(PlayerStats.load_data()["duels"].size()).is_equal(0)


func test_tutorial_is_not_recorded() -> void:
	var s := Series.new()
	s.setup({"seed": 3, "best_of": 1})
	StatsObserver.attach(s, "tutorial", "local")
	assert_object(s.stats_observer).is_null()


func test_network_client_records_each_duel_once_and_the_series() -> void:
	var tel := {"series": "s9", "game": "g1"}
	var base := {"you": 1, "tel_ids": tel, "deck_name": "Ashen Host", "deck": [{"id": 1}, {"id": 1}, {"id": 2}]}
	var v := base.duplicate(true)
	v.merge({"stage": "game", "history": []})
	StatsObserver.client_view(v, "steam")
	v = base.duplicate(true)
	v.merge({"stage": "rewards", "history": [{"game": 1, "winner": 1, "turns": 9}]})
	StatsObserver.client_view(v, "steam")
	StatsObserver.client_view(v, "steam")   # a repeated view adds nothing
	v = base.duplicate(true)
	v.merge({"stage": "over", "scores": [0, 2], "history": [{"game": 1, "winner": 1, "turns": 9}, {"game": 2, "winner": 1, "turns": 5}]})
	StatsObserver.client_view(v, "steam")
	StatsObserver.client_view(v, "steam")
	var data := PlayerStats.load_data()
	assert_int(data["duels"].size()).is_equal(2)
	assert_bool(data["duels"][1]["won"]).is_true()
	assert_str(String(data["duels"][0]["deck"])).is_equal("Ashen Host")
	assert_int(int(data["duels"][0]["cards"]["1"])).is_equal(2)
	assert_str(String(data["duels"][0]["mode"])).is_equal("steam")
	assert_int(data["series"].size()).is_equal(1)
	assert_bool(data["series"][0]["won"]).is_true()


func test_facts_summarise_record_streaks_cards_and_decks() -> void:
	var a := {"mode": "steam", "turns": 8, "ms": 600000, "deck": "Spirit Bomb", "cards": {"33": 2, "61": 1}, "plays": {"33": 3}, "summons": 2, "spells": 1, "damage": 30, "best_hit": 12}
	for won in [true, true, false, true, true, true]:
		var d := a.duplicate(true)
		d["won"] = won
		PlayerStats.record_duel(d)
	var fast := a.duplicate(true)
	fast.merge({"won": true, "turns": 4, "mode": "bot", "plays": {"61": 9}, "best_hit": 20}, true)
	PlayerStats.record_duel(fast)
	PlayerStats.record_duel({"mode": "local", "won": null, "turns": 20, "ms": 60000})
	PlayerStats.record_series("steam", true, [2, 1])
	PlayerStats.record_series("steam", false, [0, 2])
	PlayerStats.record_draft_pick(33)
	PlayerStats.record_draft_pick(33)
	PlayerStats.record_draft_done()
	PlayerStats.forget()   # the facts come from the saved file
	var f := PlayerStats.facts()
	assert_str(String(_fact(f, "Duels played")["value"])).is_equal("8")
	assert_str(String(_fact(f, "Duels played")["detail"])).is_equal("6 online, 1 vs bot, 1 hot-seat")
	assert_str(String(_fact(f, "Win rate")["value"])).is_equal("86%")
	assert_str(String(_fact(f, "Online record")["value"])).is_equal("5 - 1")
	assert_str(String(_fact(f, "Series won")["value"])).is_equal("1 of 2")
	assert_str(String(_fact(f, "Best win streak")["value"])).is_equal("4")
	assert_str(String(_fact(f, "Best win streak")["detail"])).is_equal("current streak 4")
	assert_str(String(_fact(f, "Fastest win")["value"])).is_equal("4 turns")
	assert_str(String(_fact(f, "Longest duel")["value"])).is_equal("20 turns")
	assert_str(String(_fact(f, "Biggest single hit")["value"])).is_equal("20 damage")
	assert_str(String(_fact(f, "Most played card")["value"])).is_equal(PlayerStats._name("33"))
	assert_str(String(_fact(f, "Most played card")["detail"])).is_equal("played 18 times")
	assert_str(String(_fact(f, "Your best card")["detail"])).is_equal("won 6 of 7 duels it was in your deck")
	assert_str(String(_fact(f, "Favourite deck")["value"])).is_equal("Spirit Bomb")
	assert_str(String(_fact(f, "Most drafted card")["detail"])).is_equal("picked 2 times in 1 drafts")
	assert_str(String(_fact(f, "Time in duels")["value"])).is_equal("1 h 11 min")


func test_shared_card_names_carry_their_type() -> void:
	var names := {}
	for c in CardDB.all():
		names[c["name"]] = int(names.get(c["name"], 0)) + 1
	for c in CardDB.all():
		if names[c["name"]] > 1:
			assert_str(PlayerStats._name(str(c["id"]))).is_equal("%s (%s)" % [c["name"], c["type"]])
			return


func test_store_keeps_only_the_newest_duels() -> void:
	for i in PlayerStats.MAX_DUELS + 3:
		PlayerStats.record_duel({"mode": "bot", "won": true, "turns": i})
	var duels: Array = PlayerStats.load_data()["duels"]
	assert_int(duels.size()).is_equal(PlayerStats.MAX_DUELS)
	assert_int(int(duels[0]["turns"])).is_equal(3)


func test_dialog_lists_every_fact_and_closes_on_escape() -> void:
	PlayerStats.record_duel({"mode": "bot", "won": true, "turns": 6, "ms": 120000})
	var root := Control.new()
	add_child(root)
	var d := StatsDialog.open(root)
	await get_tree().process_frame
	var texts := []
	for l in d.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	for f in PlayerStats.facts():
		assert_bool(texts.has(f["label"])).is_true()
		assert_bool(texts.has(f["value"])).is_true()
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	d._input(ev)
	await get_tree().process_frame
	assert_bool(is_instance_valid(d)).is_false()
	root.queue_free()


func test_empty_dialog_explains_how_to_fill_it() -> void:
	var root := Control.new()
	add_child(root)
	var d := StatsDialog.open(root)
	await get_tree().process_frame
	var found := false
	for l in d.find_children("*", "Label", true, false):
		found = found or (l as Label).text.begins_with("Finish a duel")
	assert_bool(found).is_true()
	root.queue_free()
