extends GdUnitTestSuite
## J23 (owner feedback 2026-10-22): "do we definitely shuffle the deck before game start?" Every
## real game (bot, local, online, every game of a series, custom and drafted decks) is created by
## Series._start_game -> MatchEngine.setup, which shuffles each player's Draw pile with the game's
## seeded rng. Only the tutorial builds a scripted Draw order on purpose (TutorialSetup).
## Card instances are created in deck order (MatchEngine.cards keeps insertion order; the uids
## themselves are random), so an unshuffled pile would match that creation order.

const DECK_SIZE := 20


func _filler_deck() -> Array:
	var deck := []
	for i in DECK_SIZE:
		deck.append(TB.FILLER)
	return deck


func _match(seed_value: int) -> MatchEngine:
	var m := MatchEngine.new()
	m.setup([_filler_deck(), _filler_deck()], 0, seed_value, {})
	return m


## Every Main Deck uid of player p in pile order: the remaining Draw pile (bottom first), then the
## Hand in reverse draw order, so the result is the whole pile as it was right after the shuffle.
static func _pile_order(m: MatchEngine, p: int) -> Array:
	var hand: Array = m.players[p]["hand"].duplicate()
	hand.reverse()
	return m.players[p]["draw"] + hand


## Player p's Main Deck uids in the order the game created them (the deck list order).
static func _creation_order(m: MatchEngine, p: int) -> Array:
	var out := []
	for u in m.cards:
		if int(m.cards[u]["owner"]) == p and not m.is_extra(u):
			out.append(u)
	return out


## The pile as positions in the deck list: [0, 1, 2, ...] when it was not shuffled.
static func _permutation(m: MatchEngine, p: int) -> Array:
	var made := _creation_order(m, p)
	return _pile_order(m, p).map(func(u): return made.find(u))


static func _unshuffled(m: MatchEngine, p: int) -> bool:
	return _pile_order(m, p) == _creation_order(m, p)


func test_setup_shuffles_both_draw_piles() -> void:
	var m := _match(7)
	for p in 2:
		assert_int(_pile_order(m, p).size()).is_equal(DECK_SIZE)
		assert_bool(_unshuffled(m, p)).override_failure_message("player %d's Draw pile was not shuffled: %s" % [p, _permutation(m, p)]).is_false()


func test_same_seed_gives_the_same_draw_order() -> void:
	var a := _match(1234)
	var b := _match(1234)
	for p in 2:
		assert_array(_permutation(b, p)).is_equal(_permutation(a, p))


func test_different_seeds_give_different_draw_orders() -> void:
	var a := _match(1234)
	var b := _match(98765)
	assert_array(_permutation(b, 0)).is_not_equal(_permutation(a, 0))


func test_the_two_players_are_shuffled_independently() -> void:
	var m := _match(42)
	assert_array(_permutation(m, 1)).is_not_equal(_permutation(m, 0))


func test_series_game_with_starter_decks_is_shuffled_and_seeded() -> void:
	var a := _starter_series(11)
	var b := _starter_series(11)
	for p in 2:
		assert_bool(_unshuffled(a.game, p)).override_failure_message("starter deck of seat %d not shuffled: %s" % [p, _permutation(a.game, p)]).is_false()
		assert_array(_permutation(b.game, p)).is_equal(_permutation(a.game, p))


func test_series_game_with_drafted_decks_is_shuffled() -> void:
	var s := Series.new()
	s.setup({"seed": 5, "deck_mode": "draft", "best_of": 1})
	for p in 2:
		var guard := 0
		while not s.deck_ready[p] and guard < 100:
			assert_str(s.submit(p, {"t": "draft_pick", "index": 0})).is_empty()
			guard += 1
	assert_str(s.stage).is_equal(Series.STAGE_GAME)
	for p in 2:
		assert_bool(_unshuffled(s.game, p)).is_false()


func test_series_without_a_seed_shuffles_differently_each_time() -> void:
	var orders := {}
	for i in 4:
		var s := _starter_series(-1)
		orders[str(_permutation(s.game, 0))] = true
	assert_int(orders.size()).is_greater(1)


func _starter_series(seed_value: int) -> Series:
	var s := Series.new()
	var cfg := {"best_of": 1}
	if seed_value >= 0:
		cfg["seed"] = seed_value
	s.setup(cfg)
	s.submit(0, {"t": "pick_starter", "index": 0})
	s.submit(1, {"t": "pick_starter", "index": 1})
	return s
