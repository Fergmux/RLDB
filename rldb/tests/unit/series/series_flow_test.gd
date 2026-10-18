extends GdUnitTestSuite
## Series flow: decks, score, rewards for both players, loser chooses first player,
## and full per-game reset.


func _series(best_of: int = 3) -> Series:
	var s := Series.new()
	s.setup({"seed": 11, "best_of": best_of})
	s.submit(0, {"t": "pick_starter", "index": 0})
	s.submit(1, {"t": "pick_starter", "index": 1})
	return s


func test_starter_decks_are_valid_and_fully_implemented() -> void:
	for deck in Series.load_starters():
		var main_count := 0
		var basics := 0
		for id in deck["main"]:
			var d := CardDB.get_def(id)
			assert_bool(CardDB.is_extra_category(d["category"])).is_false()
			main_count += 1
			if d["category"] == "basic_unit":
				basics += 1
		# F06-03 structure decks: 3 copies of one basic unit plus 9 other main-deck cards.
		assert_int(main_count).is_equal(12)
		assert_int(basics).is_equal(3)
		assert_int(deck["extra"].size()).is_between(1, 3)
		for id in deck["extra"]:
			assert_bool(CardDB.is_extra_category(CardDB.get_def(id)["category"])).is_true()


func test_game_starts_when_both_decks_locked() -> void:
	var s := _series()
	assert_str(s.stage).is_equal(Series.STAGE_GAME)
	assert_int(s.game_no).is_equal(1)
	assert_int(s.game.players[0]["extra"].size()).is_equal(3)


## Add-card reward (feedback 04): choose a type (spends the pick), then take one offered card.
func _add(s: Series, p: int, cat: String, index: int) -> String:
	var err := s.submit(p, {"t": "reward_type", "category": cat})
	if err != "":
		return err
	return s.submit(p, {"t": "reward_add", "index": index})


func test_win_moves_both_players_to_four_rewards() -> void:
	var s := _series()
	var loser: int = s.game.active
	s.submit(loser, {"t": "concede"})
	assert_str(s.stage).is_equal(Series.STAGE_REWARDS)
	assert_int(s.scores[1 - loser]).is_equal(1)
	assert_int(s.rewards[0]["left"]).is_equal(4)
	assert_int(s.rewards[1]["left"]).is_equal(4)


func test_rewards_accept_any_combination_and_persist_into_next_game() -> void:
	var s := _series()
	var loser: int = s.game.active
	s.submit(loser, {"t": "concede"})
	var size_before: int = s.decks[0].size()
	# Player 0: add, add, remove, change basic type.
	assert_str(_add(s, 0, "spell", 0)).is_empty()
	assert_str(_add(s, 0, "unit", 1)).is_empty()
	assert_str(s.submit(0, {"t": "reward_remove", "card_id": 166})).is_empty()   # Saboteurs' Guild
	assert_str(s.submit(0, {"t": "reward_basic", "to_type": "Fire", "to_race": "Beast"})).is_empty()
	assert_bool(s.rewards[0]["done"]).is_true()
	assert_int(s.decks[0].size()).is_equal(size_before + 1)
	assert_int(s.decks[0].count(113)).is_equal(3)   # all three Water Beasts became Fire Beasts
	assert_int(s.decks[0].count(4)).is_equal(0)
	assert_str(s.submit(0, {"t": "reward_type", "category": "spell"})).is_not_empty()
	# Player 1: four removals.
	for i in 4:
		assert_str(s.submit(1, {"t": "reward_remove", "card_id": s.decks[1][-1]})).is_empty()
	assert_str(s.stage).is_equal(Series.STAGE_FIRST)


func test_only_loser_chooses_first_player() -> void:
	var s := _series()
	var loser: int = s.game.active
	s.submit(loser, {"t": "concede"})
	for p in 2:
		s.submit(p, {"t": "reward_finish"})
	assert_str(s.submit(1 - loser, {"t": "first_player", "who": 0})).is_not_empty()
	assert_str(s.submit(loser, {"t": "first_player", "who": 1 - loser})).is_empty()
	for q in 2:
		s.submit(q, {"t": "start_duel"})   # G05
	assert_int(s.game.active).is_equal(1 - loser)
	assert_int(s.game_no).is_equal(2)


func test_new_game_resets_hp_statuses_runes_exhaust_and_costs() -> void:
	var s := _series()
	var m := s.game
	var u: int = m.players[0]["draw"][0]
	m.cards[u]["cost_p"] = 3
	m.players[0]["hp"] = 12
	m.move_to_pile(u, "exhaust")
	var loser: int = m.active
	s.submit(loser, {"t": "concede"})
	for p in 2:
		s.submit(p, {"t": "reward_finish"})
	s.submit(loser, {"t": "first_player", "who": 0})
	for q in 2:
		s.submit(q, {"t": "start_duel"})   # G05
	var m2 := s.game
	assert_object(m2).is_not_same(m)
	for p in 2:
		assert_int(m2.players[p]["hp"]).is_equal(60)
		assert_int(m2.players[p]["exhaust"].size()).is_equal(0)
	for uid in m2.cards:
		assert_int(m2.cards[uid]["cost_p"]).is_equal(0)
		assert_bool(m2.cards[uid]["st"].is_empty()).is_true()
		assert_int(m2.cards[uid]["runes"]).is_equal(0)


func test_series_ends_when_a_player_reaches_required_wins() -> void:
	var s := _series(3)
	for g in 2:
		s.submit(1, {"t": "concede_series"})
		if s.stage == Series.STAGE_OVER:
			break
		for p in 2:
			s.submit(p, {"t": "reward_finish"})
		s.submit(1, {"t": "first_player", "who": 0})
		for q in 2:
			s.submit(q, {"t": "start_duel"})   # G05
	assert_str(s.stage).is_equal(Series.STAGE_OVER)
	assert_int(s.scores[0]).is_equal(2)


func test_draft_builds_deck_from_category_quotas() -> void:
	var s := Series.new()
	s.setup({"seed": 5, "deck_mode": "draft"})
	for p in 2:
		var guard := 0
		while not s.deck_ready[p] and guard < 50:
			assert_str(s.submit(p, {"t": "draft_pick", "index": 0})).is_empty()
			guard += 1
	assert_str(s.stage).is_equal(Series.STAGE_GAME)
	assert_int(s.decks[0].size()).is_equal(23)   # 3 basic copies + 17 picks + 3 extra


func _draft_all(s: Series) -> void:
	for p in 2:
		var guard := 0
		while not s.deck_ready[p] and guard < 100:
			assert_str(s.submit(p, {"t": "draft_pick", "index": 0})).is_empty()
			guard += 1


func test_f03_10_configured_draft_counts_are_used_and_shown() -> void:
	var s := Series.new()
	s.setup({"seed": 9, "deck_mode": "draft", "draft_quota": {"basic": 0, "unit": 2, "spell": 1, "trap": 0, "power": 0, "extra": 2}})
	var dv: Dictionary = s.view_for(1)["draft"]
	assert_int(int(dv["total"])).is_equal(5)
	assert_str(String(dv["composition"])).is_equal("2 Unit, 1 Spell, 2 Extra Deck")
	assert_str(String(s.view_for(1)["draft"]["category_label"])).is_equal("Unit")
	s.draft[1] = s._new_draft()
	_draft_all(s)
	var cats := {}
	for id in s.decks[0]:
		var c: String = CardDB.get_def(id)["category"]
		cats[c] = cats.get(c, 0) + 1
	assert_int(cats.get("unit", 0)).is_equal(2)
	assert_int(cats.get("spell", 0)).is_equal(1)
	assert_int(int(cats.get("fusion", 0)) + int(cats.get("ritual", 0)) + int(cats.get("arcane", 0))).is_equal(2)
	assert_int(cats.get("basic_unit", 0)).is_equal(3)              # F06-06: the chosen basic unit, x3
	assert_int(s.decks[0].size()).is_equal(8)
	# Extra Deck picks still route to the Extra Deck at game start.
	assert_int(s.game.players[0]["extra"].size()).is_equal(2)


func test_f03_10_partial_quota_override_keeps_other_draft_settings() -> void:
	var s := Series.new()
	s.setup({"seed": 9, "deck_mode": "draft", "draft_quota": {"unit": 1}})
	assert_int(int(s.cfg["draft"]["offer"])).is_equal(3)
	assert_bool(s.cfg["draft"]["quota"].has("basic")).is_false()   # F06-06: no basic-unit category


func test_f03_10_invalid_draft_counts_are_explained() -> void:
	assert_str(Series.validate_draft_quota({"basic": 0, "unit": 0, "spell": 0, "trap": 0, "power": 0, "extra": 0})).contains("at least one")
	assert_str(Series.validate_draft_quota({"unit": -1})).contains("between")
	assert_str(Series.validate_draft_quota({"unit": 1.5})).contains("whole")
	assert_str(Series.validate_draft_quota({"fusion": 2})).contains("Unknown")
	assert_str(Series.validate_draft_quota(Series.default_draft_quota())).is_empty()
	var s := Series.new()
	s.setup({"seed": 9, "deck_mode": "draft", "draft_quota": {"unit": 0}})
	assert_bool(" ".join(s.series_log).contains("Draft composition not used")).is_true()


func test_f03_11_draft_and_rewards_use_one_extra_deck_group() -> void:
	assert_bool("fusion" in Series.REWARD_TYPES or "ritual" in Series.REWARD_TYPES or "arcane" in Series.REWARD_TYPES).is_false()
	assert_bool("extra" in Series.REWARD_TYPES).is_true()
	var cats := {}
	for id in Series.reward_pool("extra"):
		cats[CardDB.get_def(id)["category"]] = true
	assert_array(cats.keys()).contains_exactly_in_any_order(["fusion", "ritual", "arcane"])
	var s := _series()
	s.submit(s.game.active, {"t": "concede"})
	var types: Array = s.view_for(0)["rewards"]["types"]
	assert_bool("extra" in types and not ("fusion" in types)).is_true()
	assert_str(s.submit(0, {"t": "reward_type", "category": "extra"})).is_empty()
	for c in s.view_for(0)["rewards"]["offer"]:
		assert_bool(String(c["category"]) in ["fusion", "ritual", "arcane"]).is_true()


func test_opponent_reward_choices_are_private() -> void:
	var s := _series()
	s.submit(s.game.active, {"t": "concede"})
	_add(s, 0, "trap", 0)
	var v := s.view_for(1)
	assert_bool(v.has("deck")).is_true()
	assert_bool(JSON.stringify(v["rewards"]).contains("Added")).is_false()


func test_custom_deck_is_unrestricted_and_routes_extra_cards() -> void:
	var s := Series.new()
	s.setup({"seed": 3})
	assert_str(s.submit(0, {"t": "custom_deck", "cards": [21, 21, 21, 21, 93, 96], "name": "Gods"})).is_empty()
	s.submit(1, {"t": "pick_starter", "index": 0})
	assert_str(s.stage).is_equal(Series.STAGE_GAME)
	assert_int(s.game.players[0]["extra"].size()).is_equal(2)
	assert_str(s.deck_names[0]).is_equal("Gods")


func test_custom_deck_rejects_unknown_card() -> void:
	var s := Series.new()
	s.setup({"seed": 3})
	assert_str(s.submit(0, {"t": "custom_deck", "cards": [99999]})).contains("Unknown")


func test_award_game_counts_one_game_win_only() -> void:
	var s := _series(5)
	assert_str(s.award_game(0, "opponent did not reconnect")).is_empty()
	assert_int(s.scores[0]).is_equal(1)
	assert_str(s.stage).is_equal(Series.STAGE_REWARDS)


func test_series_saves_and_resumes_between_games() -> void:
	var s := _series(3)
	s.submit(s.game.active, {"t": "concede"})
	_add(s, 0, "power", 0)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s.to_save()))
	var r := Series.from_save(saved)
	assert_str(r.stage).is_equal(Series.STAGE_REWARDS)
	assert_array(r.scores).is_equal(s.scores)
	assert_array(r.decks[0]).is_equal(s.decks[0])
	assert_int(r.rewards[0]["left"]).is_equal(3)
	for p in 2:
		r.submit(p, {"t": "reward_finish"})
	assert_str(r.submit(r.last_loser, {"t": "first_player", "who": 0})).is_empty()
	for q in 2:
		assert_str(r.submit(q, {"t": "start_duel"})).is_empty()   # G05
	assert_str(r.stage).is_equal(Series.STAGE_GAME)
	assert_int(r.game_no).is_equal(2)


func test_series_is_not_saveable_mid_game() -> void:
	var s := _series(3)
	assert_bool(s.at_checkpoint()).is_false()


func test_custom_deck_rejects_malformed_and_oversized_input() -> void:
	var s := Series.new()
	s.setup({"seed": 3})
	assert_str(s.submit(0, {"t": "custom_deck", "cards": "1,2,3"})).is_equal("Malformed deck.")
	assert_str(s.submit(0, {"t": "custom_deck", "cards": [1, "x"]})).is_equal("Malformed deck.")
	assert_str(s.submit(0, {"t": "custom_deck", "cards": [1], "name": 5})).is_equal("Malformed deck.")
	var big := []
	big.resize(Series.MAX_CUSTOM_DECK + 1)
	big.fill(1)
	assert_str(s.submit(0, {"t": "custom_deck", "cards": big})).contains("limited")
	assert_bool(s.deck_ready[0]).is_false()


func test_saved_series_keeps_client_token_for_resume_binding() -> void:
	var s := _series(3)
	s.client_token = "abcdef0123456789abcdef01"
	s.submit(s.game.active, {"t": "concede"})
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s.to_save()))
	assert_str(Series.from_save(saved).client_token).is_equal("abcdef0123456789abcdef01")


func test_reward_type_spends_the_pick_and_offers_three_of_that_type() -> void:
	var s := _series()
	s.submit(s.game.active, {"t": "concede"})
	assert_str(s.submit(0, {"t": "reward_add", "index": 0})).is_equal("Choose a card type first.")
	assert_str(s.submit(0, {"t": "reward_type", "category": "trap"})).is_empty()
	assert_int(s.rewards[0]["left"]).is_equal(3)            # spent at once: no backing out
	var offer: Array = s.view_for(0)["rewards"]["offer"]
	assert_int(offer.size()).is_equal(3)
	for c in offer:
		assert_str(String(c["category"])).is_equal("trap")
	# Nothing else (another type, remove, change, finish) until a card is taken.
	assert_str(s.submit(0, {"t": "reward_type", "category": "spell"})).is_equal("Pick one of the offered cards first.")
	assert_str(s.submit(0, {"t": "reward_remove", "card_id": s.decks[0][0]})).is_equal("Pick one of the offered cards first.")
	assert_str(s.submit(0, {"t": "reward_finish"})).is_equal("Pick one of the offered cards first.")
	var picked: int = s.rewards[0]["offer"][2]
	assert_str(s.submit(0, {"t": "reward_add", "index": 2})).is_empty()
	assert_int(s.decks[0].count(picked)).is_greater_equal(1)
	assert_int(s.rewards[0]["left"]).is_equal(3)
	assert_bool(s.rewards[0]["pending"]).is_false()


func test_last_pick_type_waits_for_the_card_before_finishing() -> void:
	var s := _series()
	s.submit(s.game.active, {"t": "concede"})
	for i in 3:
		assert_str(s.submit(0, {"t": "reward_remove", "card_id": s.decks[0][-1]})).is_empty()
	assert_str(s.submit(0, {"t": "reward_type", "category": "unit"})).is_empty()
	assert_bool(s.rewards[0]["done"]).is_false()             # left is 0 but a card is still owed
	assert_str(s.submit(0, {"t": "reward_add", "index": 0})).is_empty()
	assert_bool(s.rewards[0]["done"]).is_true()


func test_unknown_reward_type_is_refused() -> void:
	var s := _series()
	s.submit(s.game.active, {"t": "concede"})
	assert_str(s.submit(0, {"t": "reward_type", "category": "basic_unit"})).is_equal("Choose a card type.")
	assert_int(s.rewards[0]["left"]).is_equal(4)


func test_basic_change_can_change_race_and_type() -> void:
	var s := _series()
	s.submit(s.game.active, {"t": "concede"})
	var n: int = s.decks[0].count(4)                         # Basic Beast (Water)
	assert_int(n).is_greater(0)
	assert_str(s.submit(0, {"t": "reward_basic", "to_type": "Fire", "to_race": "Dragon"})).is_empty()
	assert_int(s.decks[0].count(111)).is_equal(n)            # Basic Dragon (Fire)
	assert_int(s.decks[0].count(4)).is_equal(0)
	assert_str(s.submit(0, {"t": "reward_basic", "to_type": "Fire", "to_race": "Dragon"})).contains("different")


## In-game menu "Return to menu / Quit": the leaving player forfeits the whole series and the
## save is no longer resumable.
func test_forfeit_series_ends_the_series_for_the_leaver() -> void:
	var s := _series()
	assert_str(s.submit(0, {"t": "forfeit_series"})).is_empty()
	assert_str(s.stage).is_equal(Series.STAGE_OVER)
	assert_int(s.forfeit_by).is_equal(0)
	assert_str(s.submit(1, {"t": "forfeit_series"})).is_equal("The series is over.")
