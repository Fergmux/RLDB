extends GdUnitTestSuite
## Independent review probes (production batch 2026-10-17): seeded bot-vs-bot series on
## mixed custom decks (every card category, Extra Deck methods included), Ritual / Arcane
## cancel paths (F07), and hidden information from the opponent's seat.


## Deterministic mixed deck: `n_main` Main Deck cards and `n_extra` Extra Deck cards drawn from
## the whole database with a seeded generator.
func _mixed_deck(seed_value: int, n_main: int, n_extra: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var main := []
	var extra := []
	for df in CardDB.all():
		var id: int = int(df["id"])
		if CardDB.is_extra_category(df["category"]):
			extra.append(id)
		else:
			main.append(id)
	var out := []
	for i in n_main:
		out.append(main[rng.randi_range(0, main.size() - 1)])
	for i in n_extra:
		out.append(extra[rng.randi_range(0, extra.size() - 1)])
	return out


## Plays a whole series between two bots. Returns {refused, steps, stage}.
func _bot_series(seed_value: int, best_of: int) -> Dictionary:
	var s := Series.new()
	s.setup({"seed": seed_value, "best_of": best_of, "deck_mode": "starter"})
	var bots := [BotBrain.new(0, seed_value * 3 + 1), BotBrain.new(1, seed_value * 3 + 2)]
	var refused := []
	for p in 2:
		var e := s.submit(p, {"t": "custom_deck", "name": "probe", "cards": _mixed_deck(seed_value * 10 + p, 36, 12)})
		if e != "":
			refused.append("deck: " + e)
	var steps := 0
	var specials := {}
	var turns := []
	var last_game: MatchEngine = null
	while s.stage != Series.STAGE_OVER and steps < 6000:
		steps += 1
		if s.game != null and s.game != last_game:
			if last_game != null:
				turns.append(last_game.turn)
			last_game = s.game
		var acted := false
		for p in 2:
			var cmd: Dictionary = bots[p].series_command(s) if s.stage != Series.STAGE_GAME else bots[p].decide(s.game)
			if cmd.is_empty():
				continue
			if s.stage == Series.STAGE_GAME and String(cmd.get("t", "")) in ["ritual", "arcane", "ability", "cast", "activate_set"]:
				specials[cmd["t"]] = int(specials.get(cmd["t"], 0)) + 1
			var err := s.submit(p, cmd)
			if err != "":
				refused.append("seed %d %s -> %s" % [seed_value, cmd, err])
				s.submit(p, {"t": "next_phase"} if s.stage == Series.STAGE_GAME and s.game.pending.is_empty() else {"t": "concede"})
			acted = true
			break
		if not acted:
			refused.append("seed %d stalled at stage %s pending %s" % [seed_value, s.stage, s.game.pending if s.game != null else {}])
			break
	if last_game != null:
		turns.append(last_game.turn)
	print("probe seed %d: steps %d turns %s commands %s" % [seed_value, steps, turns, specials])
	return {"refused": refused, "steps": steps, "stage": s.stage}


func test_review_bots_finish_mixed_custom_deck_series_legally() -> void:
	for seed_value in [3, 17, 29, 41, 53]:
		var r := _bot_series(seed_value, 3)
		assert_array(r["refused"]).override_failure_message(str(r["refused"])).is_empty()
		assert_str(r["stage"]).override_failure_message("seed %d steps %d" % [seed_value, r["steps"]]).is_equal(Series.STAGE_OVER)


func _answer(m: MatchEngine, v: int) -> String:
	return m.submit(m.pending["player"], {"t": "choose", "id": m.pending["id"], "values": [v]})


func _answer_many(m: MatchEngine, vs: Array) -> String:
	return m.submit(m.pending["player"], {"t": "choose", "id": m.pending["id"], "values": vs})


func _state(m: MatchEngine) -> Dictionary:
	return {"cards": m.cards.duplicate(true), "players": m.players.duplicate(true), "stack": m.stack.size()}


func test_review_ritual_cancel_each_step_then_commit() -> void:
	# B3: no stance prompt in the Setup Phase, so the zone commits and the unit enters in Attack.
	for k in 3:
		var m := TB.make()
		var mimic := TB.card(m, 0, 95, "extra")               # Mimic 2R
		var mat := TB.unit(m, 0, TB.WATER, 0)
		m.apply_status(mat, "rune", 2)
		var before := _state(m)
		assert_str(m.submit(0, {"t": "ritual", "uid": mimic})).is_empty()
		var answers := [mat, 0]
		for i in mini(k, 2):
			assert_str(_answer(m, answers[i])).override_failure_message("step %d" % i).is_empty()
		if k < 2:
			assert_bool(m.pending.get("cancellable", false)).override_failure_message("ritual step %d" % k).is_true()
			assert_str(m.submit(0, {"t": "cancel", "id": m.pending["id"]})).is_empty()
			assert_dict(_state(m)).override_failure_message("ritual cancel %d" % k).is_equal(before)
		else:
			assert_str(m.cards[mimic]["zone"]).is_equal("unit")
			assert_str(m.cards[mimic]["stance"]).is_equal("atk")
			assert_str(m.cards[mat]["zone"]).is_equal("spent")


func test_review_arcane_cancel_each_step_then_exact_commit() -> void:
	for k in 4:
		var m := TB.make()
		var tyde := TB.card(m, 0, 172, "extra")               # Tyde 2A
		var a := TB.card(m, 0, TB.WATER, "spent")             # cost 1
		var b := TB.card(m, 0, TB.FIRE, "spent")              # cost 1
		var two := TB.card(m, 0, 28, "spent")                 # cost 2
		var three := TB.card(m, 0, 23, "spent")               # cost 3: more than the total
		var before := _state(m)
		assert_str(m.submit(0, {"t": "arcane", "uid": tyde})).is_empty()
		if k == 0:
			assert_str(_answer_many(m, [a, two])).contains("exactly")     # overpay refused
			assert_str(_answer_many(m, [three])).contains("exactly")
			assert_str(_answer_many(m, [a])).contains("exactly")
			assert_str(m.submit(0, {"t": "cancel", "id": m.pending["id"]})).is_empty()
			assert_dict(_state(m)).is_equal(before)
			continue
		assert_str(_answer_many(m, [a, b])).is_empty()
		if k == 2:
			assert_bool(m.pending.get("cancellable", false)).is_true()   # the zone choice
			assert_str(m.submit(0, {"t": "cancel", "id": m.pending["id"]})).is_empty()
			assert_dict(_state(m)).is_equal(before)
			continue
		if k >= 3:
			assert_str(_answer(m, 1)).is_empty()                  # the zone commits (B3: no stance)
			assert_str(m.cards[tyde]["zone"]).is_equal("unit")
			assert_str(m.cards[tyde]["stance"]).is_equal("atk")
			assert_str(m.cards[a]["zone"]).is_equal("exhaust")
			assert_str(m.cards[b]["zone"]).is_equal("exhaust")
			assert_str(m.cards[two]["zone"]).is_equal("spent")
			continue
		assert_str(m.submit(0, {"t": "cancel", "id": m.pending["id"]})).is_empty()
		assert_dict(_state(m)).override_failure_message("arcane cancel %d" % k).is_equal(before)


func test_review_tag_team_w_without_match_does_not_stall() -> void:
	var m := TB.make(7, 0)
	TB.unit(m, 0, TB.WATER, 3)                                 # Mage partner
	TB.card(m, 0, 4, "draw")                                   # Beast only: no same-Race unit
	TB.summon(m, 0, 10, 0)
	assert_bool(m.pending.is_empty()).override_failure_message(str(m.pending)).is_true()
	assert_bool(m.stack.is_empty()).is_true()


func test_review_symbiote_larva_with_empty_draw_and_hand_does_not_stall() -> void:
	var m := TB.make(7, 0)
	TB.unit(m, 0, 156, 3)
	m.players[0]["hand"].clear()
	TB.to_turn2(m)
	for i in 3:
		if m.active == 1 and m.pending.is_empty():
			m.submit(1, {"t": "next_phase"})
	while not m.pending.is_empty() and int(m.pending["player"]) == 0 and m.pending["options"].size() > 0:
		_answer(m, m.pending["options"][0]["v"])
	assert_bool(m.pending.is_empty()).override_failure_message(str(m.pending)).is_true()
	assert_int(m.active).is_equal(0)


## Opponent's seat during searches and pile choices: no searched card's identity in the view,
## the log or the pending prompt.
func test_review_opponent_view_hides_searched_cards() -> void:
	var m := TB.make(7, 0)
	TB.unit(m, 0, TB.WATER, 3)
	var trap := TB.card(m, 0, 45, "draw")                      # Magic Cylinder
	TB.summon(m, 0, 6, 0)                                      # Tag Team - L
	var mid := JSON.stringify(MatchView.build(m, 1))
	assert_str(mid).not_contains("Magic Cylinder")
	TB.choose_uids(m, [trap])
	var after := JSON.stringify(MatchView.build(m, 1))
	assert_str(after).not_contains("Magic Cylinder")
	assert_str(JSON.stringify(MatchView.build(m, 0))).contains("Magic Cylinder")
	# Accio: Draw unit to Spent, then a Retain on a Hand unit.
	var m2 := TB.make(7, 0)
	var dr := TB.card(m2, 0, 32, "draw")                       # Frost Wyvern
	var h := TB.card(m2, 0, 28, "hand")                        # Guardian of the Forest
	TB.summon(m2, 0, 30, 0)
	assert_str(JSON.stringify(MatchView.build(m2, 1))).not_contains("Frost Wyvern")
	TB.choose_uids(m2, [dr])
	assert_str(JSON.stringify(MatchView.build(m2, 1))).not_contains("Guardian of the Forest")
	TB.choose_uids(m2, [h])
	var v1 := JSON.stringify(MatchView.build(m2, 1))
	assert_str(v1).not_contains("Frost Wyvern")
	assert_str(v1).not_contains("Guardian of the Forest")
	assert_int(m2.status_count(h, "retain")).is_equal(1)


## F04 Extra Deck rows: the opponent's view never lists the active player's Extra summons.
func test_review_extra_availability_is_private() -> void:
	var m := TB.make()
	var tyde := TB.card(m, 0, 172, "extra")
	TB.card(m, 0, TB.WATER, "spent")
	TB.card(m, 0, TB.FIRE, "spent")
	var v0 := MatchView.build(m, 0)
	var v1 := MatchView.build(m, 1)
	assert_bool(v0["extra_avail"]["any"]).is_true()
	assert_bool(v1["extra_avail"]["any"]).is_false()
	assert_str(JSON.stringify(v1)).not_contains("Tyde")
	assert_int(int(v0["extra_avail"]["methods"][0]["uid"])).is_equal(tyde)


## Magentric tributed through Tag Team - S's On Summon Fusion still gives the Fusion unit 2 Pierce.
func test_review_magentric_bonus_through_tag_team_s_trigger() -> void:
	var m := TB.make()
	var mag := TB.unit(m, 0, 69, 3)                            # Beast, back row column 1
	var dr := TB.unit(m, 0, 2, 1)                              # Dragon
	var wyrm := TB.card(m, 0, 93, "extra")                     # Bastion Wyrm: Beast + Dragon
	TB.summon(m, 0, 8, 0)                                      # Tag Team - S in front of Magentric
	for v in [1, wyrm, mag, dr, 1]:
		assert_str(_answer(m, v)).is_empty()
	assert_str(m.cards[wyrm]["zone"]).is_equal("unit")
	assert_int(m.status_count(wyrm, "pierce")).is_equal(2)


## Chaos Witch's Type carries Mage Fusion materials: a Water Mage under a Fire Witch is a Fire Mage.
func test_review_chaos_witch_type_feeds_fusion_requirements() -> void:
	var m := TB.make()
	var witch := TB.unit(m, 0, 13, 0)
	var mage := TB.unit(m, 0, TB.WATER, 1)
	var trigonam := TB.card(m, 0, 145, "extra")                # Mage + Fire
	var abysslord := TB.card(m, 0, 59, "extra")                # Mage + Water
	assert_array(m.fusion_candidates(0, ["field"])).contains([abysslord])
	TB.ability(m, witch)
	TB.choose(m, ["Fire"])
	var c := m.fusion_candidates(0, ["field"])
	assert_array(c).contains([trigonam])
	assert_array(c).not_contains([abysslord])
	assert_str(m.unit_type(mage)).is_equal("Fire")
