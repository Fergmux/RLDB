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
		assert_int(main_count).is_equal(20)
		assert_int(basics).is_equal(3)
		for id in deck["extra"]:
			assert_bool(CardDB.is_extra_category(CardDB.get_def(id)["category"])).is_true()


func test_game_starts_when_both_decks_locked() -> void:
	var s := _series()
	assert_str(s.stage).is_equal(Series.STAGE_GAME)
	assert_int(s.game_no).is_equal(1)
	assert_int(s.game.players[0]["extra"].size()).is_equal(3)


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
	assert_str(s.submit(0, {"t": "reward_add", "index": 0})).is_empty()
	assert_str(s.submit(0, {"t": "reward_add", "index": 1})).is_empty()
	assert_str(s.submit(0, {"t": "reward_remove", "card_id": 7})).is_empty()
	assert_str(s.submit(0, {"t": "reward_basic", "from_id": 1, "to_type": "Fire"})).is_empty()
	assert_bool(s.rewards[0]["done"]).is_true()
	assert_int(s.decks[0].size()).is_equal(size_before + 1)
	assert_int(s.decks[0].count(110)).is_equal(3)   # all three Water Mages became Fire Mages
	assert_int(s.decks[0].count(1)).is_equal(0)
	assert_str(s.submit(0, {"t": "reward_add", "index": 0})).is_not_empty()
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


func test_opponent_reward_choices_are_private() -> void:
	var s := _series()
	s.submit(s.game.active, {"t": "concede"})
	s.submit(0, {"t": "reward_add", "index": 0})
	var v := s.view_for(1)
	assert_bool(v.has("deck")).is_true()
	assert_bool(JSON.stringify(v["rewards"]).contains("Added")).is_false()
