extends GdUnitTestSuite
## L2 (owner, 5 Nov): "sometimes when adding one of the new three cards via draft it makes the noise
## but doesn't go into the draft". Root cause: the between-game reward modal folds the other offered
## cards away and only sent `reward_add` from a tween on the folding row. Whenever the modal was
## rebuilt during that fold, the row was freed, the tween died with it and the take was never sent:
## the pick sound played and the card never reached the deck. Two things rebuild it then: the
## opponent finishing their rewards, and (the common one, when cards are added back to back) the
## previous take's 2.1 s "recover" refresh, which fired on whatever offer was pending by then. The
## reward-kind tiles had the same flaw, and worse: their fold flag stayed set, so no reward kind
## could be opened again.
## Story: design/owner-feedback-2026-11-05.md L2.

const DIR := "user://test_saves_l2"
## Owlbear Druid and Snow Tiger Paladin (Fusion, 3 Nov sheet): new cards the owner was adding.
const OWLBEAR := 189
const SNOW_TIGER := 190


func before_test() -> void:
	SeriesStore.DIR = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	UIStyle.reduce_motion = false


func after_test() -> void:
	for fn in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, fn])


## A hot-seat series at the rewards stage after game 1 (seat 1 won), before any screen sees it.
func _series_at_rewards() -> Series:
	var s := Series.new()
	s.setup({"seed": 22, "best_of": 3, "deck_mode": "starter", "names": ["Ann", "Bea"], "mode": "local"})
	s.submit(0, {"t": "pick_starter", "index": 0})
	s.submit(1, {"t": "pick_starter", "index": 1})
	s.submit(0, {"t": "concede"})
	return s


func _host(s: Series) -> LocalHost:
	var host: LocalHost = auto_free(LocalHost.new())
	add_child(host)
	host.start({"resume": s})
	return host


func _screen(host: LocalHost) -> GameScreen:
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 900)
	add_child(gs)
	await gs.attach(host.seats[0])
	for i in 4:
		await await_idle_frame()
	return gs


func _offer_cards(gs: GameScreen) -> Array:
	return gs.overlays.overlay_box.find_children("*", "CardWidget", true, false).filter(func(w): return w.has_meta("reward_offer"))


## Seat 0 chooses the Extra Deck type and is offered card `first` in the first slot.
func _offer(host: LocalHost, first: int) -> void:
	host.handle(0, {"t": "reward_type", "category": "extra"})
	host.series.rewards[0]["offer"][0] = first
	host.broadcast()


func _take_first(gs: GameScreen) -> void:
	var cards := _offer_cards(gs)
	assert_int(cards.size()).is_equal(3)
	var w: CardWidget = cards[0]
	w.pressed.emit(w)


func test_l2_offered_card_is_taken_when_the_opponent_finishes_during_the_fold() -> void:
	# Arrange: seat 0 is offered Owlbear Druid first.
	var s := _series_at_rewards()
	assert_str(s.stage).is_equal(Series.STAGE_REWARDS)
	var host := _host(s)
	_offer(host, OWLBEAR)
	var gs := await _screen(host)
	var before: int = s.decks[0].count(OWLBEAR)
	# Act: take it; while the other cards fold away the opponent finishes (seat 0's view changes).
	_take_first(gs)
	await await_idle_frame()
	host.handle(1, {"t": "reward_finish"})
	await get_tree().create_timer(0.8).timeout
	# Assert: the card reached the deck and the offer is closed.
	assert_int(s.decks[0].count(OWLBEAR)).is_equal(before + 1)
	assert_bool(bool(s.rewards[0]["pending"])).is_false()


func test_l2_back_to_back_takes_both_reach_the_deck() -> void:
	# Arrange: take Owlbear Druid, then open the next Extra Deck offer straight away.
	var s := _series_at_rewards()
	var host := _host(s)
	_offer(host, OWLBEAR)
	var gs := await _screen(host)
	_take_first(gs)
	await get_tree().create_timer(0.5).timeout
	assert_int(s.decks[0].count(OWLBEAR)).is_greater(0)
	_offer(host, SNOW_TIGER)
	await await_idle_frame()
	var before: int = s.decks[0].count(SNOW_TIGER)
	# Act: take Snow Tiger Paladin so that its fold spans the first take's recover moment (2.1 s
	# after the first send).
	await get_tree().create_timer(1.75).timeout
	_take_first(gs)
	await get_tree().create_timer(0.9).timeout
	# Assert
	assert_int(s.decks[0].count(SNOW_TIGER)).is_equal(before + 1)
	assert_bool(bool(s.rewards[0]["pending"])).is_false()


func test_l2_reward_kind_opens_when_the_opponent_finishes_during_the_fold() -> void:
	# Arrange
	var s := _series_at_rewards()
	var host := _host(s)
	var gs := await _screen(host)
	var rw := gs.overlays.rewards
	var tiles := gs.overlays.overlay_box.find_children("*", "ChoiceTile", true, false)
	assert_bool(tiles.is_empty()).is_false()
	# Act: choose "Add a card" (the tiles fold away); the opponent finishes meanwhile.
	rw.choose_mode("add", (tiles[0] as Node).get_parent())
	await await_idle_frame()
	host.handle(1, {"t": "reward_finish"})
	await get_tree().create_timer(0.8).timeout
	# Assert: the Add a card panel is open and the next choice is not blocked.
	assert_str(rw.mode).is_equal("add")
	assert_bool(rw._collapsing).is_false()
