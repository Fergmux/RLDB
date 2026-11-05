extends GdUnitTestSuite
## L26 (owner, 5 Nov): the series results, visually: the top strip's SeriesScoreboard during a series
## (hidden in a single game), the full SeriesResults card (lobby list, the scoreboard's hover card)
## and a point popping in, with the series_point cue, when a game is won.
## Story: design/owner-feedback-2026-11-05.md L26.


func _view(best_of: int, winners: Array, stage: String = "game", forfeit_by: int = -1) -> Dictionary:
	var hist := []
	var scores := [0, 0]
	for i in winners.size():
		hist.append({"game": i + 1, "winner": winners[i], "turns": 5 + i, "hp": [0, 10]})
		scores[winners[i]] += 1
	return {"best_of": best_of, "history": hist, "scores": scores, "names": ["Ana", "Ben"], "stage": stage,
		"mode": "local", "save_id": "s1", "forfeit_by": forfeit_by}


func test_l26_model_counts_wins_games_and_the_leader() -> void:
	var md := SeriesResults.model(_view(5, [1, 0, 1]), 0)
	assert_int(int(md["need"])).is_equal(3)
	assert_array(md["scores"]).is_equal([1, 2])
	assert_array(md["results"]).is_equal([1, 0, 1])
	assert_int(int(md["leader"])).is_equal(1)
	assert_int(int(md["current"])).is_equal(3)
	assert_bool(bool(md["over"])).is_false()


func test_l26_model_knows_the_series_winner() -> void:
	var md := SeriesResults.model(_view(3, [0, 0], "over"), 1)
	assert_bool(bool(md["over"])).is_true()
	assert_int(int(md["winner"])).is_equal(0)
	assert_int(int(md["current"])).is_equal(-1)
	assert_str(SeriesResults.summary(md)).contains("Ana wins the series")


func test_l26_a_forfeit_names_the_other_seat_the_winner() -> void:
	var md := SeriesResults.model(_view(3, [], "over", 1), 0)
	assert_int(int(md["winner"])).is_equal(0)


func test_l26_single_games_and_tutorials_show_no_series() -> void:
	assert_bool(SeriesResults.shows_for(_view(1, []))).is_false()
	var t := _view(3, [])
	t["mode"] = "tutorial"
	assert_bool(SeriesResults.shows_for(t)).is_false()
	assert_bool(SeriesResults.shows_for(_view(3, []))).is_true()


func test_l26_scoreboard_shows_the_score_with_my_side_left() -> void:
	var sb: SeriesScoreboard = auto_free(SeriesScoreboard.new())
	add_child(sb)
	sb.show_model(SeriesResults.model(_view(3, [1]), 1), "s1")
	assert_array(sb.shown).is_equal([0, 1])
	assert_bool(sb.gem_pos(true, 0).x < sb.size.x / 2.0).is_true()
	assert_str(sb.tooltip_text).contains("Ben 1 – 0 Ana")
	var card = auto_free(sb._make_custom_tooltip(""))
	assert_object(card).is_not_null()
	assert_int((card as Node).find_children("*", "SeriesResults", true, false).size()).is_equal(1)


func test_l26_a_won_game_pops_its_point_in_with_the_cue() -> void:
	UIStyle.reduce_motion = false
	var sb: SeriesScoreboard = auto_free(SeriesScoreboard.new())
	add_child(sb)
	sb.show_model(SeriesResults.model(_view(3, []), 0), "s1")
	var md := SeriesResults.model(_view(3, [0]), 0)
	sb.hold_point(md, 0)
	assert_array(sb.shown).is_equal([0, 0])          # held back until the pop
	Sfx.debug_played.clear()
	sb.pop_point(0)
	assert_bool(sb.popping()).is_true()
	assert_array(sb.shown).is_equal([0, 0])          # the popping gem is not drawn twice
	await get_tree().create_timer(0.9).timeout
	assert_bool(sb.popping()).is_false()
	assert_array(sb.shown).is_equal([1, 0])


func test_l26_results_card_draws_one_medallion_per_game() -> void:
	var r: SeriesResults = auto_free(SeriesResults.new().setup(SeriesResults.model(_view(7, [0, 1]), 0)))
	add_child(r)
	await await_idle_frame()
	assert_vector(r.size).is_equal(Vector2(SeriesResults.W, SeriesResults.H))
	assert_float(r.game_pos(6).x).is_less(SeriesResults.W)
	assert_float(r.game_pos(0).x).is_greater(0.0)


func test_l26_game_rows_name_the_winner() -> void:
	var row: Control = auto_free(SeriesResults.game_row(2, 1, "Ben", 9, false, false))
	var texts := row.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	assert_array(texts).contains(["Game 2", "Ben", "turn 9"])
