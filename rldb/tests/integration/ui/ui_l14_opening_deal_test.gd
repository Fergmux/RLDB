extends GdUnitTestSuite
## L14 (owner, 5 Nov): "if you go first at the start of a game that is not the first game, you do not
## get the draw cards animation". Root cause: the first view of every new game skips its effects
## (GameScreen._collect_fx: the game number changed), so the opening draw is never animated by the
## effects player. Game 1 hid that because its coin flip then deals the hands in (_deal_after_coin);
## games 2+ have no coin, so the player going first saw their opening hand simply appear (the player
## going second draws on their own first turn, an ordinary animated draw). Now every game opens the
## same way: the hands are dealt in from the draw pile once the series modal has gone.
## Story: design/owner-feedback-2026-11-05.md L14.

const DIR := "user://test_saves_l14"


func before_test() -> void:
	SeriesStore.DIR = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	UIStyle.reduce_motion = false


func after_test() -> void:
	for fn in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, fn])


## A hot-seat series at the who-goes-first stage after game 1, which seat 0 lost (seat 0 chooses).
func _series_after_game_one() -> Series:
	var s := Series.new()
	s.setup({"seed": 14, "best_of": 3, "deck_mode": "starter", "names": ["Ann", "Bea"], "mode": "local"})
	s.submit(0, {"t": "pick_starter", "index": 0})
	s.submit(1, {"t": "pick_starter", "index": 1})
	s.submit(s.game.active, {"t": "concede"}) if s.game.active == 0 else s.submit(0, {"t": "concede"})
	for p in 2:
		s.submit(p, {"t": "reward_finish"})
	assert_str(s.stage).is_equal(Series.STAGE_FIRST)
	assert_int(s.last_loser).is_equal(0)
	return s


func _setup(first: int) -> Array:
	var s := _series_after_game_one()
	var host: LocalHost = auto_free(LocalHost.new())
	add_child(host)
	host.start({"resume": s})
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 900)
	add_child(gs)
	await gs.attach(host.seats[0])
	for i in 4:
		await await_idle_frame()
	host.handle(0, {"t": "first_player", "who": first})
	host.handle(0, {"t": "start_duel"})   # hot-seat: one press starts it for both seats
	assert_str(s.stage).is_equal(Series.STAGE_GAME)
	assert_int(s.game_no).is_equal(2)
	await await_idle_frame()
	return [host, gs]


func _hand_widgets(gs: GameScreen) -> Array:
	return gs.hand.layer.find_children("*", "CardWidget", true, false)


func test_l14_going_first_in_game_two_deals_the_opening_hand() -> void:
	# Arrange / act: game 2 starts with seat 0 (the viewer) going first.
	var r := await _setup(0)
	var gs: GameScreen = r[1]
	assert_int(int(gs.mv["active"])).is_equal(0)
	var cards := _hand_widgets(gs)
	assert_bool(cards.is_empty()).is_false()
	# Assert: the hand waits hidden for the deal, then each card flies in from the draw pile.
	assert_float(gs.hand.layer.modulate.a).is_equal(0.0)
	var dealt := false
	for i in 90:
		await await_idle_frame()
		if gs.hand.layer.modulate.a >= 1.0 and cards.any(func(w): return is_instance_valid(w) and (w as CardWidget).scale.x < 0.99):
			dealt = true
			break
	assert_bool(dealt).override_failure_message("the opening hand was not dealt in").is_true()
	await get_tree().create_timer(1.0).timeout
	assert_bool(cards.all(func(w): return (w as CardWidget).scale.is_equal_approx(Vector2.ONE) and (w as CardWidget).modulate.a >= 1.0)).is_true()


func test_l14_going_second_in_game_two_fades_the_opponents_hand_in() -> void:
	var r := await _setup(1)
	var gs: GameScreen = r[1]
	assert_int(int(gs.mv["active"])).is_equal(1)
	assert_float(gs.board.opp_hand_box.modulate.a).is_equal(0.0)
	await get_tree().create_timer(1.2).timeout
	assert_float(gs.board.opp_hand_box.modulate.a).is_equal(1.0)
	assert_float(gs.hand.layer.modulate.a).is_equal(1.0)


func test_l14_the_opening_deal_plays_once_per_game() -> void:
	var r := await _setup(0)
	var host: LocalHost = r[0]
	var gs: GameScreen = r[1]
	await get_tree().create_timer(1.2).timeout
	host.broadcast()   # the same game's view again (a re-render, a reconnect)
	await await_idle_frame()
	assert_float(gs.hand.layer.modulate.a).is_equal(1.0)
