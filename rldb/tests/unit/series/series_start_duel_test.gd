extends GdUnitTestSuite
## G05 (playtest feedback 08): after both players have chosen their rewards the next duel does
## not start by itself. The loser of the last game chooses who goes first, and each seat presses
## Start next duel ("start_duel"); the duel starts once the choice is made and both are ready.


## A series at the who-goes-first stage after game 1; returns it (loser = s.last_loser).
func _at_first_stage(seed_value: int = 21) -> Series:
	var s := Series.new()
	s.setup({"seed": seed_value, "best_of": 3, "deck_mode": "starter"})
	s.submit(0, {"t": "pick_starter", "index": 0})
	s.submit(1, {"t": "pick_starter", "index": 1})
	s.submit(s.game.active, {"t": "concede"})
	for p in 2:
		s.submit(p, {"t": "reward_finish"})
	return s


func test_rewards_done_waits_at_first_stage_with_nobody_ready() -> void:
	var s := _at_first_stage()
	assert_str(s.stage).is_equal(Series.STAGE_FIRST)
	assert_bool(s.first_chosen).is_false()
	assert_array(s.duel_ready).is_equal([false, false])


func test_first_choice_alone_does_not_start_the_duel() -> void:
	var s := _at_first_stage()
	var loser := s.last_loser
	assert_str(s.submit(loser, {"t": "first_player", "who": loser})).is_empty()
	assert_str(s.stage).is_equal(Series.STAGE_FIRST)
	assert_bool(s.first_chosen).is_true()
	assert_int(s.first_player).is_equal(loser)
	assert_int(s.game_no).is_equal(1)


func test_duel_starts_when_choice_made_and_both_ready() -> void:
	var s := _at_first_stage()
	var loser := s.last_loser
	s.submit(loser, {"t": "first_player", "who": 1 - loser})
	assert_str(s.submit(1 - loser, {"t": "start_duel"})).is_empty()
	assert_str(s.stage).is_equal(Series.STAGE_FIRST)
	assert_str(s.submit(loser, {"t": "start_duel"})).is_empty()
	assert_str(s.stage).is_equal(Series.STAGE_GAME)
	assert_int(s.game_no).is_equal(2)
	assert_int(s.game.active).is_equal(1 - loser)


func test_winner_may_be_ready_before_the_choice() -> void:
	var s := _at_first_stage()
	var loser := s.last_loser
	assert_str(s.submit(1 - loser, {"t": "start_duel"})).is_empty()
	assert_array(s.duel_ready).is_equal([loser == 1, loser == 0])
	s.submit(loser, {"t": "first_player", "who": loser})
	assert_str(s.stage).is_equal(Series.STAGE_FIRST)      # the loser has not pressed yet
	s.submit(loser, {"t": "start_duel"})
	assert_str(s.stage).is_equal(Series.STAGE_GAME)
	assert_int(s.game.active).is_equal(loser)


func test_loser_must_choose_before_being_ready() -> void:
	var s := _at_first_stage()
	assert_str(s.submit(s.last_loser, {"t": "start_duel"})).is_not_empty()
	assert_bool(s.duel_ready[s.last_loser]).is_false()


func test_loser_may_change_the_choice_until_ready_but_not_after() -> void:
	var s := _at_first_stage()
	var loser := s.last_loser
	s.submit(loser, {"t": "first_player", "who": loser})
	assert_str(s.submit(loser, {"t": "first_player", "who": 1 - loser})).is_empty()
	assert_int(s.first_player).is_equal(1 - loser)
	s.submit(loser, {"t": "start_duel"})
	assert_str(s.submit(loser, {"t": "first_player", "who": loser})).is_not_empty()
	assert_int(s.first_player).is_equal(1 - loser)


func test_ready_twice_is_refused() -> void:
	var s := _at_first_stage()
	var winner := 1 - s.last_loser
	s.submit(winner, {"t": "start_duel"})
	assert_str(s.submit(winner, {"t": "start_duel"})).is_not_empty()


func test_only_loser_chooses_and_start_duel_only_at_first_stage() -> void:
	var s := _at_first_stage()
	assert_str(s.submit(1 - s.last_loser, {"t": "first_player", "who": 0})).is_not_empty()
	s.submit(s.last_loser, {"t": "first_player", "who": 0})
	for p in 2:
		s.submit(p, {"t": "start_duel"})
	assert_str(s.stage).is_equal(Series.STAGE_GAME)
	assert_str(s.submit(0, {"t": "start_duel"})).is_not_empty()     # in a game: not a game command


func test_view_shows_choice_and_readiness_to_both_seats() -> void:
	var s := _at_first_stage()
	var loser := s.last_loser
	s.submit(loser, {"t": "first_player", "who": loser})
	s.submit(1 - loser, {"t": "start_duel"})
	for p in 2:
		var nx: Dictionary = s.view_for(p)["next"]
		assert_bool(nx["first_chosen"]).is_true()
		assert_int(nx["first_player"]).is_equal(loser)
		assert_bool(nx["you_ready"]).is_equal(p != loser)
		assert_bool(nx["opponent_ready"]).is_equal(p == loser)


func test_save_keeps_the_choice_but_not_readiness() -> void:
	var s := _at_first_stage()
	var loser := s.last_loser
	s.submit(loser, {"t": "first_player", "who": 1 - loser})
	s.submit(1 - loser, {"t": "start_duel"})
	var r := Series.from_save(JSON.parse_string(JSON.stringify(s.to_save())))
	assert_str(r.stage).is_equal(Series.STAGE_FIRST)
	assert_bool(r.first_chosen).is_true()
	assert_int(r.first_player).is_equal(1 - loser)
	assert_array(r.duel_ready).is_equal([false, false])
	for p in 2:
		assert_str(r.submit(p, {"t": "start_duel"})).is_empty()
	assert_str(r.stage).is_equal(Series.STAGE_GAME)
	assert_int(r.game.active).is_equal(1 - loser)


func test_old_save_without_the_choice_asks_the_loser_again() -> void:
	var s := _at_first_stage()
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_save()))
	d.erase("first_chosen")
	var r := Series.from_save(d)
	assert_bool(r.first_chosen).is_false()
	assert_str(r.submit(r.last_loser, {"t": "start_duel"})).is_not_empty()


func test_choice_saves_a_checkpoint() -> void:
	var s := _at_first_stage()
	var hits := [0]
	s.checkpoint.connect(func(): hits[0] += 1)
	s.submit(s.last_loser, {"t": "first_player", "who": 0})
	assert_int(hits[0]).is_equal(1)


func test_old_hot_seat_save_without_mode_resumes_as_hot_seat() -> void:
	var s := Series.new()
	s.setup({"seed": 5, "best_of": 3, "names": ["Ana", "Ben"]})
	var d := s.to_save()
	d["cfg"].erase("mode")
	assert_str(String(Series.from_save(d.duplicate(true)).cfg["mode"])).is_equal("local")
	d["names"] = ["Ana", "Bot"]
	assert_str(String(Series.from_save(d.duplicate(true)).cfg["mode"])).is_equal("bot")
