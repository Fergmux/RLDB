extends GdUnitTestSuite
## Telemetry collector on the real rules engine and series: hand-entry opportunities and draw
## conversion (retain, redraw, retrieval, special summons, repeated activations), completion
## reasons, duplicate completion signals, pauses, drafts, rewards and client corroboration.

var items: Dictionary = {}
var emitted: Array = []
var clock: Array = [1_700_000_000_000]


func _collector() -> TelemetryCollector:
	items = {}
	emitted = []
	var c := TelemetryCollector.new()
	c.profile_pid = "pp_test"
	c.now_ms = func() -> int: return clock[0]
	c.emit_item = func(kind: String, id: String, state: String, mode: String, body: Dictionary):
		emitted.append([kind, id, state])
		items[id] = {"kind": kind, "state": state, "mode": mode, "body": body.duplicate(true)}
	return c


func _series(c: TelemetryCollector, mode: String = "bot", overrides: Dictionary = {}) -> Series:
	var s := Series.new()
	var o := {"seed": 11, "best_of": 3}
	o.merge(overrides, true)
	s.setup(o)
	c.attach(s, mode, "local")
	return s


func _start_starter_game(s: Series) -> void:
	s.submit(0, {"t": "pick_starter", "index": 0})
	s.submit(1, {"t": "pick_starter", "index": 1})


func _game_item(s: Series) -> Dictionary:
	return items.get("game_" + String(s.telemetry_ids["game"]), {})


func _hand_unit(m: MatchEngine, p: int) -> int:
	for u in m.players[p]["hand"]:
		if String(m.d(u)["category"]) in ["unit", "basic_unit"]:
			return u
	return -1


func _opp_for(c: TelemetryCollector, uid: int) -> Array:
	for t in c.g["opps"]:
		if int(c.g["opps"][t][3]) == uid:
			return c.g["opps"][t]
	return []


func test_duel_start_freezes_both_starting_decks_and_ids() -> void:
	var c := _collector()
	var s := _series(c)
	_start_starter_game(s)
	var it := _game_item(s)
	assert_str(String(it["state"])).is_equal("open")
	var decks: Array = it["body"]["decks"]
	assert_int(decks.size()).is_equal(2)
	var starter: Dictionary = Series.load_starters()[0]
	assert_int(int(decks[0]["main_size"])).is_equal(starter["main"].size())
	assert_int(int(decks[0]["extra_size"])).is_equal(starter["extra"].size())
	assert_str(String(decks[0]["source"])).is_equal("prebuilt")
	assert_str(String(it["body"]["ids"]["series_id"])).is_equal(String(s.telemetry_ids["series"]))
	assert_str(String(it["body"]["participants"][1]["kind"])).is_equal("bot")
	assert_bool(it["body"]["flags"]["bot"]).is_true()


func test_opening_draws_open_one_draw_opportunity_each() -> void:
	var c := _collector()
	var s := _series(c)
	_start_starter_game(s)
	var m := s.game
	assert_int(c.g["opps"].size()).is_equal(m.players[m.active]["hand"].size())
	for t in c.g["opps"]:
		assert_str(String(c.g["opps"][t][4])).is_equal("draw_turn")


func test_normal_summon_of_a_drawn_card_is_one_play_and_one_conversion() -> void:
	var c := _collector()
	var s := _series(c)
	_start_starter_game(s)
	var m := s.game
	var p := m.active
	var u := _hand_unit(m, p)
	assert_int(u).is_not_equal(-1)
	m.players[p]["ap"] = 20
	assert_str(s.submit(p, {"t": "summon", "uid": u, "stance": "atk"})).is_equal("")
	assert_str(TB.choose(m, [TB.slot_label(0)])).is_equal("")
	var def_id := str(int(m.cards[u]["id"]))
	var cnt: Dictionary = c.g["counters"][p][def_id]
	assert_int(int(cnt["plays_by_kind"]["normal_summon"])).is_equal(1)
	assert_int(int(cnt["plays"])).is_equal(1)
	assert_int(int(cnt["draw_opps_played"])).is_greater_equal(1)
	assert_str(String(_opp_for(c, u)[6])).is_equal("played")


func test_cancelled_summon_is_not_a_play() -> void:
	var c := _collector()
	var s := _series(c)
	_start_starter_game(s)
	var m := s.game
	var p := m.active
	var u := _hand_unit(m, p)
	m.players[p]["ap"] = 20
	s.submit(p, {"t": "summon", "uid": u, "stance": "atk"})
	assert_str(s.submit(p, {"t": "cancel", "id": int(m.pending["id"])})).is_equal("")
	assert_int(int(c.g["totals"][p]["plays"])).is_equal(0)
	assert_str(String(_opp_for(c, u)[6])).is_equal("open")


func test_retained_card_keeps_its_opportunity_and_a_redraw_is_a_new_one() -> void:
	var c := _collector()
	var s := _series(c)
	_start_starter_game(s)
	var m := s.game
	var p := m.active
	var kept: int = m.players[p]["hand"][0]
	var gone: int = m.players[p]["hand"][1]
	m._set_status(kept, "retain", 1)
	var kept_token: String = _opp_for(c, kept)[0]
	s.submit(p, {"t": "next_phase"})
	s.submit(p, {"t": "next_phase"})        # end of turn: discard all but the retained card
	assert_str(String(_opp_for(c, gone)[6])).is_equal("exited")
	assert_str(String(_opp_for(c, kept)[0])).is_equal(kept_token)
	assert_str(String(_opp_for(c, kept)[6])).is_equal("open")
	# The discarded card later comes back to Hand by an effect: a new, non-draw opportunity.
	var before: int = int(c.g["counters"][p][str(int(m.cards[gone]["id"]))]["draw_opps"])
	m.move_to_pile(gone, "hand")
	var last: Array = []
	for t in c.g["opps"]:
		if int(c.g["opps"][t][3]) == gone:
			last = c.g["opps"][t]
	assert_str(String(last[4])).is_equal("retrieve_spent")
	assert_str(String(last[0])).is_not_equal(kept_token)
	assert_int(int(c.g["counters"][p][str(int(m.cards[gone]["id"]))]["draw_opps"])).is_equal(before)


func test_repeated_activations_and_special_summons_do_not_inflate_draw_conversion() -> void:
	var c := _collector()
	var s := _series(c)
	_start_starter_game(s)
	var m := s.game
	var p := m.active
	var u := _hand_unit(m, p)
	var def_id := str(int(m.cards[u]["id"]))
	m.players[p]["ap"] = 20
	s.submit(p, {"t": "summon", "uid": u, "stance": "atk"})
	TB.choose(m, [TB.slot_label(0)])
	# The summon may already have fired real On Summon triggers: measure the change.
	var acts_before := int(c.g["counters"][p][def_id]["activations"])
	var frame := {"src": u, "ctl": p, "ops": [{"op": "ability_cost", "idx": 0}], "negated": false}
	m.note("activation", {"frame": frame})
	m.note("activation", {"frame": frame})
	frame["negated"] = true
	m.note("activation", {"frame": frame})
	var cnt: Dictionary = c.g["counters"][p][def_id]
	assert_int(int(cnt["activations"]) - acts_before).is_equal(3)
	assert_int(int(cnt["activations_by_kind"]["ability:resolved"])).is_equal(2)
	assert_int(int(cnt["activations_by_kind"]["ability:negated"])).is_equal(1)
	assert_int(int(cnt["plays"])).is_equal(1)
	# A revival from Spent and an Extra Deck ritual are plays, never draw conversions.
	var conv := int(cnt["draw_opps_played"])
	var spent := TB.card(m, p, int(m.cards[u]["id"]), "spent")
	m.note("summon", {"uid": spent, "p": p, "from": "spent", "frame": {"src": 999999, "ops": [{"op": "summon"}]}})
	var ex := TB.card(m, p, 1, "extra")
	m.note("material", {"uid": u, "from": "unit"})
	m.note("summon", {"uid": ex, "p": p, "from": "extra", "frame": {"src": ex, "ops": [{"op": "ritual_material"}, {"op": "place"}]}})
	assert_int(int(cnt["draw_opps_played"])).is_equal(conv)
	assert_int(int(cnt["plays_by_kind"]["special_effect"])).is_equal(1)
	assert_int(int(c.g["counters"][p]["1"]["plays_by_kind"]["special_ritual"])).is_equal(1)
	var last_play: Array = c.g["events"].filter(func(e): return e[2] == "play")[-1]
	assert_int((last_play[10] as Array).size()).is_equal(1)


func test_concession_completes_once_with_reason_and_closed_opportunities() -> void:
	var c := _collector()
	var s := _series(c)
	_start_starter_game(s)
	var gid := String(s.telemetry_ids["game"])
	s.submit(1, {"t": "concede"})
	var it := _game_item(s)
	assert_str(String(it["state"])).is_equal("ready")
	var g: Dictionary = it["body"]["game"]
	assert_str(String(g["reason"])).is_equal("concede")
	assert_int(int(g["winner"])).is_equal(0)
	assert_bool(g["decisive"]).is_true()
	for o in it["body"]["opportunities"]:
		assert_str(String(o[6])).is_not_equal("open")
	# A second completion signal for the same duel changes nothing.
	var n := emitted.size()
	c.on_core_event(s.game, "game_over", {"winner": 1, "reason": "again"})
	assert_int(emitted.size()).is_equal(n)
	assert_int(int(items["game_" + gid]["body"]["game"]["winner"])).is_equal(0)


func test_lethal_and_next_duel_get_distinct_game_ids() -> void:
	var c := _collector()
	var s := _series(c)
	_start_starter_game(s)
	var first := String(s.telemetry_ids["game"])
	s.game.change_hp(1, -999, " (test)")
	s._on_game_over()
	assert_str(String(items["game_" + first]["body"]["game"]["reason"])).is_equal("lethal")
	for p in 2:
		s.submit(p, {"t": "reward_finish"})
	s.submit(s.last_loser, {"t": "first_player", "who": 0})
	for q in 2:
		s.submit(q, {"t": "start_duel"})   # G05
	var second := String(s.telemetry_ids["game"])
	assert_str(second).is_not_equal(first)
	assert_int(int(items["game_" + second]["body"]["game"]["duel_index"])).is_equal(2)
	assert_str(String(items["game_" + second]["body"]["decks"][0]["source"])).is_equal("prebuilt+series_changes")


func test_host_timeout_victory_and_forfeit_are_distinct_reasons() -> void:
	var c := _collector()
	var s := _series(c, "lan")
	_start_starter_game(s)
	var g1 := String(s.telemetry_ids["game"])
	s.award_game(0, "opponent did not reconnect")
	assert_str(String(items["game_" + g1]["body"]["game"]["reason"])).is_equal("disconnect_claim")
	assert_bool(items["game_" + g1]["body"]["flags"]["network"]).is_true()
	assert_object(items["game_" + g1]["body"]["participants"][1]["participant_id"]).is_null()
	for p in 2:
		s.submit(p, {"t": "reward_finish"})
	s.submit(s.last_loser, {"t": "first_player", "who": 0})
	for q in 2:
		s.submit(q, {"t": "start_duel"})   # G05
	var g2 := String(s.telemetry_ids["game"])
	s.submit(1, {"t": "forfeit_series"})
	assert_str(String(items["game_" + g2]["body"]["game"]["reason"])).is_equal("forfeit")
	var sr: Dictionary = items["series_" + String(s.telemetry_ids["series"])]["body"]["series"]
	assert_str(String(sr["status"])).is_equal("forfeit")
	assert_int(int(sr["winner"])).is_equal(0)
	assert_int((sr["games"] as Array).size()).is_equal(2)


func test_disconnect_pause_is_excluded_from_active_time_and_keeps_counters() -> void:
	var c := _collector()
	var s := _series(c, "lan")
	_start_starter_game(s)
	var draws_before := int(c.g["totals"][s.game.active]["draws"])
	clock[0] += 10_000
	c.set_paused(true)
	clock[0] += 60_000
	c.set_paused(false)
	clock[0] += 5_000
	assert_int(int(c.g["totals"][s.game.active]["draws"])).is_equal(draws_before)
	s.submit(1, {"t": "concede"})
	var g: Dictionary = _game_item(s)["body"]["game"]
	assert_int(int(g["paused_ms"])).is_equal(60_000)
	assert_int(int(g["active_ms"])).is_equal(15_000)


func test_detaching_mid_duel_reports_abandoned_not_a_result() -> void:
	var c := _collector()
	var s := _series(c)
	_start_starter_game(s)
	c.detach()
	var g: Dictionary = _game_item(s)["body"]["game"]
	assert_str(String(g["outcome"])).is_equal("abandoned")
	assert_bool(g["decisive"]).is_false()
	assert_int(int(g["winner"])).is_equal(-1)


func test_open_record_recovered_after_restart_becomes_abandoned() -> void:
	var c := _collector()
	var s := _series(c)
	_start_starter_game(s)
	var open: Dictionary = _game_item(s)["body"]
	var b := TelemetryCollector.abandon_body("game", open)
	assert_str(String(b["game"]["outcome"])).is_equal("abandoned")
	assert_bool(b["completeness"]["recovered_after_restart"]).is_true()


func test_draft_picks_record_offers_with_counts_and_completion() -> void:
	var c := _collector()
	var s := _series(c, "bot", {"deck_mode": "draft", "draft_quota": {"unit": 2, "spell": 1, "trap": 0, "power": 0, "extra": 0}})
	var sid := String(s.telemetry_ids["series"])
	for i in 3:
		for p in 2:
			s.submit(p, {"t": "draft_pick", "index": 0})
		if i == 0:
			# 2026-10-18: no draft setup; the record opens with the first pick.
			assert_str(String(items["draft_%s_d0" % sid]["state"])).is_equal("open")
	# J30: the record completes when the seat confirms its selections, not on the last pick.
	assert_str(String(items["draft_%s_d0" % sid]["state"])).is_equal("open")
	for p in 2:
		s.submit(p, {"t": "draft_confirm"})
	var d: Dictionary = items["draft_%s_d0" % sid]["body"]["draft"]
	assert_str(String(items["draft_%s_d0" % sid]["state"])).is_equal("ready")
	assert_str(String(d["status"])).is_equal("complete")
	assert_int((d["picks"] as Array).size()).is_equal(3)
	var pick: Dictionary = d["picks"][0]
	assert_int((pick["offered"] as Array).size()).is_equal(int(s.cfg["draft"]["offer"]))
	assert_int(int(pick["offered_counts"][str(int(pick["selected"]))])).is_equal(1)
	assert_str(String(pick["category"])).is_equal("unit")
	assert_str(String(_game_item(s)["body"]["decks"][0]["source"])).is_equal("draft")


func test_abandoned_draft_is_reported_as_abandoned() -> void:
	var c := _collector()
	var s := _series(c, "bot", {"deck_mode": "draft", "draft_quota": {"unit": 3, "spell": 0, "trap": 0, "power": 0, "extra": 0}})
	s.submit(0, {"t": "draft_pick", "index": 1})
	c.detach()
	var it: Dictionary = items["draft_%s_d0" % String(s.telemetry_ids["series"])]
	assert_str(String(it["state"])).is_equal("ready")
	assert_str(String(it["body"]["draft"]["status"])).is_equal("abandoned")
	assert_int((it["body"]["draft"]["picks"] as Array).size()).is_equal(1)


func test_rewards_record_offers_picks_and_deck_after() -> void:
	var c := _collector()
	var s := _series(c)
	_start_starter_game(s)
	s.submit(1, {"t": "concede"})
	assert_str(s.submit(0, {"t": "reward_type", "category": "unit"})).is_equal("")
	assert_str(s.submit(0, {"t": "reward_add", "index": 0})).is_equal("")
	s.submit(0, {"t": "reward_finish"})
	var key := "reward_%s_g1_s0" % String(s.telemetry_ids["series"])
	var r: Dictionary = items[key]["body"]["reward"]
	assert_str(String(r["actions"][0]["kind"])).is_equal("type")
	var offered: Array = r["actions"][0]["offered"]
	assert_int(int(r["actions"][1]["selected"])).is_equal(int(offered[0]))
	var total := 0
	for k in r["deck_after"]:
		total += int(r["deck_after"][k])
	assert_int(total).is_equal(s.decks[0].size())


func test_hot_seat_seats_have_distinct_participants() -> void:
	var c := _collector()
	var s := _series(c, "local")
	_start_starter_game(s)
	var parts: Array = _game_item(s)["body"]["participants"]
	assert_str(String(parts[0]["participant_id"])).is_equal("pp_test")
	assert_str(String(parts[1]["link"])).is_equal("guest")
	assert_str(String(parts[1]["participant_id"])).is_not_equal("pp_test")


func test_bot_look_ahead_copies_report_nothing() -> void:
	var c := _collector()
	var s := _series(c)
	_start_starter_game(s)
	var n := emitted.size()
	var events := (c.g["events"] as Array).size()
	var sim := s.game.clone_for_sim()
	sim.submit(sim.active, {"t": "concede"})
	assert_int(emitted.size()).is_equal(n)
	assert_int((c.g["events"] as Array).size()).is_equal(events)


func test_network_client_reports_one_corroboration_per_duel_across_reconnects() -> void:
	var c := _collector()
	var tel := {"series": "s1", "game": "g1"}
	c.on_client_view({"stage": "first_player", "you": 1, "tel_ids": {"series": "s1"}, "deck": [{"id": 1}, {"id": 1}]}, "enet")
	c.on_client_view({"stage": "game", "you": 1, "game_no": 1, "tel_ids": tel, "match": {"turn": 1, "active": 0}, "history": []}, "enet")
	# Reconnect: the same duel keeps the same report.
	c.on_client_view({"stage": "game", "you": 1, "game_no": 1, "tel_ids": tel, "match": {"turn": 3, "active": 0}, "history": []}, "enet")
	c.on_client_view({"stage": "rewards", "you": 1, "game_no": 1, "tel_ids": tel,
		"history": [{"game": 1, "winner": 1, "turns": 7, "hp": [0, 12]}]}, "enet")
	c.on_client_view({"stage": "rewards", "you": 1, "game_no": 1, "tel_ids": tel,
		"history": [{"game": 1, "winner": 1, "turns": 7, "hp": [0, 12]}]}, "enet")
	var ready := emitted.filter(func(e): return e[2] == "ready")
	assert_int(ready.size()).is_equal(1)
	var gc: Dictionary = items["gclient_g1"]["body"]["gclient"]
	assert_int(int(gc["winner"])).is_equal(1)
	assert_int(int(gc["turns"])).is_equal(7)
	assert_int(int(gc["first_player"])).is_equal(0)
	assert_int(int(gc["deck"]["main"]["1"])).is_equal(2)
	assert_str(String(items["gclient_g1"]["mode"])).is_equal("lan")



# ------------------------------------------------------------------ schema v2: turn and game time (C2)

## Ends the active seat's turn through real commands (next_phase until the turn number moves).
func _end_turn(s: Series) -> bool:
	var t := s.game.turn
	for i in 12:
		if s.game.turn != t or s.game.winner != -1:
			break
		var pd: Dictionary = s.game.pending
		if not pd.is_empty():
			return false
		s.submit(s.game.active, {"t": "next_phase"})
	return s.game.turn != t


func test_turn_times_record_each_turn_per_seat_and_number() -> void:
	var c := _collector()
	var s := _series(c)
	_start_starter_game(s)
	var first: int = s.game.active
	clock[0] += 42_000
	assert_bool(_end_turn(s)).is_true()
	clock[0] += 7_000
	s.submit(s.game.active, {"t": "concede"})
	var g: Dictionary = _game_item(s)["body"]["game"]
	assert_array(g["turn_times"]).is_equal([[1, first, 42_000], [2, 1 - first, 7_000]])
	var tms: Array = g["turn_ms"]
	assert_int(int(tms[first])).is_equal(42_000)
	assert_int(int(tms[1 - first])).is_equal(7_000)
	assert_str(String(g["clock"])).is_equal("host_wall")
	assert_int(int(g["turn_times_truncated"])).is_equal(0)


func test_disconnect_pause_is_left_out_of_the_turn_it_happened_in() -> void:
	var c := _collector()
	var s := _series(c, "lan")
	_start_starter_game(s)
	clock[0] += 3_000
	c.set_paused(true)
	clock[0] += 50_000
	c.set_paused(false)
	clock[0] += 2_000
	s.submit(1, {"t": "concede"})
	var g: Dictionary = _game_item(s)["body"]["game"]
	assert_int(int(g["turn_times"][0][2])).is_equal(5_000)
	assert_int(int(g["active_ms"])).is_equal(5_000)


func test_turn_times_are_bounded_and_counted_beyond_the_cap() -> void:
	var c := _collector()
	var s := _series(c)
	_start_starter_game(s)
	for i in TelemetryCollector.MAX_TURN_TIMES + 5:
		clock[0] += 1_000
		c.on_core_event(s.game, "turn", {"p": i % 2, "turn": i + 2})
	s.submit(1, {"t": "concede"})
	var g: Dictionary = _game_item(s)["body"]["game"]
	assert_int((g["turn_times"] as Array).size()).is_equal(TelemetryCollector.MAX_TURN_TIMES)
	assert_int(int(g["turn_times_truncated"])).is_equal(6)


func test_structure_deck_name_is_sent_but_never_a_custom_deck_name() -> void:
	var c := _collector()
	var s := _series(c)
	_start_starter_game(s)
	var decks: Array = _game_item(s)["body"]["decks"]
	assert_str(String(decks[0]["name"])).is_equal(String(Series.load_starters()[0]["name"]))
	c.deck_src[0] = {"source": "custom", "name": "My secret deck"}
	assert_str(String(c.deck_snapshot(0)["name"])).is_equal("")


func test_records_are_stamped_with_schema_version_two() -> void:
	assert_int(TelemetryConfig.SCHEMA_VERSION).is_equal(2)
