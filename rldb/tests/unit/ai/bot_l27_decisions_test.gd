extends GdUnitTestSuite
## L27 (owner feedback 2026-11-05, "make the bot smarter"): key decisions of the reworked BotBrain.
## Each board is built by hand; turn scenarios play the bot's whole turn while the other seat
## passes, over several seeds (the bot adds a small seeded jitter).

const BOT := 1
const HUMAN := 0
const SEEDS := [1, 2, 3, 4]
const DAMAGE_CONVERSION := 47      # Trap, cost 1
const LONE_WARRIOR := 38           # Unit, cost 2, 24/16


## Plays the bot's turn until it ends (or the game does); the other seat takes first options.
## Returns the commands the bot sent.
func _bot_turn(m: MatchEngine, seed_value: int, seat: int = BOT) -> Array:
	var bot := BotBrain.new(seat, seed_value)
	var sent := []
	var turn := m.turn
	for i in 60:
		if m.winner != -1 or m.turn != turn:
			break
		if not m.pending.is_empty() and int(m.pending["player"]) != seat:
			m.submit(int(m.pending["player"]), {"t": "choose", "id": m.pending["id"], "indices": [0]})
			continue
		var cmd := bot.decide(m)
		if cmd.is_empty():
			break
		sent.append(cmd)
		assert_str(m.submit(seat, cmd)).override_failure_message("refused %s" % cmd).is_empty()
	return sent


## Bot (seat 1) to move in its turn-2 Setup Phase, with an empty Hand and no AP.
func _board() -> MatchEngine:
	var m := TB.make()
	TB.to_turn2(m)
	m.players[BOT]["hand"].clear()
	m.players[BOT]["ap"] = 0
	return m


func test_bot_takes_lethal_by_breaking_the_last_guard_then_attacking_directly() -> void:
	for sd in SEEDS:
		# Arrange: 10 HP left behind one guard; either attacker breaks it, the other finishes
		var m := _board()
		m.players[HUMAN]["hp"] = 10
		TB.unit(m, BOT, TB.WATER, 0, "atk", 20, 10)
		TB.unit(m, BOT, TB.WATER, 1, "atk", 15, 10)
		TB.unit(m, HUMAN, TB.WATER, 0, "def", 12, 12)
		# Act
		_bot_turn(m, sd)
		# Assert
		assert_int(m.winner).override_failure_message("seed %d" % sd).is_equal(BOT)


func test_bot_breaks_the_protector_with_the_weaker_unit_so_the_stronger_reaches_the_back_row() -> void:
	for sd in SEEDS:
		# Arrange: 11 ATK beats the 10-DEF guard but not the 12-ATK unit behind it; 20 ATK beats both
		var m := _board()
		TB.unit(m, BOT, TB.WATER, 0, "atk", 20, 10)
		TB.unit(m, BOT, TB.WATER, 1, "atk", 11, 10)
		var guard := TB.unit(m, HUMAN, TB.WATER, 0, "def", 10, 10)
		var back := TB.unit(m, HUMAN, TB.WATER, 3, "atk", 12, 12)
		# Act
		_bot_turn(m, sd)
		# Assert: the weak unit takes the guard, the strong one the unit it exposed
		assert_str(m.cards[guard]["zone"]).override_failure_message("seed %d guard" % sd).is_not_equal("unit")
		assert_str(m.cards[back]["zone"]).override_failure_message("seed %d back" % sd).is_not_equal("unit")


func test_bot_summons_a_defense_guard_rather_than_leave_an_empty_board_to_a_lethal_attack() -> void:
	for sd in SEEDS:
		# Arrange: 18 HP, no units, a 20-ATK attacker across; an 8/25 unit in Hand
		var m := _board()
		m.players[BOT]["hp"] = 18
		m.players[BOT]["ap"] = 2
		var h := TB.card(m, BOT, TB.WATER)
		m.cards[h]["base_atk"] = 8
		m.cards[h]["base_def"] = 25
		TB.unit(m, HUMAN, TB.WATER, 0, "atk", 20, 20)
		# Act
		_bot_turn(m, sd)
		# Assert: it stands in Defense, and it did not suicide into the 20-ATK unit
		assert_str(m.cards[h]["zone"]).override_failure_message("seed %d" % sd).is_equal("unit")
		assert_str(m.cards[h]["stance"]).override_failure_message("seed %d" % sd).is_equal("def")
		assert_int(int(m.players[BOT]["hp"])).is_equal(18)


func test_bot_puts_a_fragile_unit_in_the_back_row_behind_its_guard() -> void:
	for sd in SEEDS:
		# Arrange: a Defense wall in column 2; a 14/4 unit in Hand; a 20-ATK attacker across
		var m := _board()
		m.players[BOT]["ap"] = 1
		TB.unit(m, BOT, TB.WATER, 1, "def", 5, 40)
		var h := TB.card(m, BOT, TB.WATER)
		m.cards[h]["base_atk"] = 14
		m.cards[h]["base_def"] = 4
		TB.unit(m, HUMAN, TB.WATER, 0, "atk", 20, 20)
		# Act
		_bot_turn(m, sd)
		# Assert: the only protected zone is the one behind the wall (slot 4)
		assert_str(m.cards[h]["zone"]).override_failure_message("seed %d" % sd).is_equal("unit")
		assert_int(int(m.cards[h]["slot"])).override_failure_message("seed %d" % sd).is_equal(4)


func test_bot_spends_its_recovery_phase_ap_instead_of_wasting_it() -> void:
	for sd in SEEDS:
		# Arrange: Recovery Phase, 1 AP left and a 1-cost Trap in Hand
		var m := _board()
		TB.to_battle(m)
		assert_str(m.submit(BOT, {"t": "next_phase"})).is_empty()
		m.players[BOT]["ap"] = 1
		var trap := TB.card(m, BOT, DAMAGE_CONVERSION)
		# Act
		_bot_turn(m, sd)
		# Assert
		assert_str(m.cards[trap]["zone"]).override_failure_message("seed %d" % sd).is_equal("backrow")


func test_bot_ends_its_first_turn_without_flipping_a_unit_back_and_forth() -> void:
	for sd in SEEDS:
		# Arrange: turn 1 (no Battle Phase), 2 AP but nothing to spend it on, one unit on the Field.
		# (The bug: the Setup Phase valued unspent AP, the Recovery Phase it leads to did not, so
		# any free move such as a stance change looked better than moving on, again and again.)
		var m := TB.make()
		m.players[HUMAN]["hand"].clear()
		m.players[HUMAN]["ap"] = 2
		TB.unit(m, HUMAN, TB.WATER, 0, "atk", 10, 20)
		# Act
		var sent := _bot_turn(m, sd, HUMAN)
		# Assert: at most one stance change, and the turn ends
		assert_int(sent.filter(func(c): return c["t"] == "stance").size()).override_failure_message("seed %d: %s" % [sd, sent]).is_less_equal(1)
		assert_int(m.active).is_equal(BOT)


func test_belief_hides_every_card_the_seat_cannot_see() -> void:
	# Arrange: the opponent holds a Trap in Hand and has one set face down; the bot has a Draw
	var m := _board()
	var opp_hand := TB.card(m, HUMAN, DAMAGE_CONVERSION)
	var opp_set := TB.set_card(m, HUMAN, DAMAGE_CONVERSION, 1)
	var own_set := TB.set_card(m, BOT, DAMAGE_CONVERSION, 0)
	var bot := BotBrain.new(BOT, 5)
	# Act
	var b := bot.belief(m)
	# Assert: hidden cards are placeholders; own cards and the Field keep their identity
	assert_int(int(b.cards[opp_hand]["id"])).is_equal(BotBrain.PLACEHOLDER_ID)
	assert_int(int(b.cards[opp_set]["id"])).is_equal(BotBrain.PLACEHOLDER_ID)
	assert_int(int(b.cards[own_set]["id"])).is_equal(DAMAGE_CONVERSION)
	for u in m.players[BOT]["draw"]:
		assert_int(int(b.cards[u]["id"])).is_equal(int(m.cards[u]["id"]))
	for u in m.players[HUMAN]["draw"]:
		assert_int(int(b.cards[u]["id"])).is_equal(BotBrain.PLACEHOLDER_ID)
	# ... the random generator is not the real one, and the opponent's Traps stay silent
	assert_int(b.rng.state).is_not_equal(m.rng.state)
	assert_str(b.trap_prompt_mode(HUMAN)).is_equal(EffectEngine.TRAP_PROMPT_OFF)
	assert_int(int(m.cards[opp_hand]["id"])).is_equal(DAMAGE_CONVERSION)   # the real match is untouched


func test_decision_does_not_depend_on_the_opponents_hidden_cards() -> void:
	# Arrange: two matches equal in everything the bot may see; the opponent's set card differs
	var boards := []
	for id in [DAMAGE_CONVERSION, TB.WATER]:
		var m := _board()
		TB.unit(m, BOT, TB.WATER, 0, "def", 12, 20)
		TB.unit(m, HUMAN, TB.WATER, 0, "atk", 8, 8)
		TB.set_card(m, HUMAN, id, 0)
		boards.append(m)
	# Act
	var a := BotBrain.new(BOT, 9).decide(boards[0])
	var b := BotBrain.new(BOT, 9).decide(boards[1])
	# Assert
	assert_dict(a).is_equal(b)


func test_bot_answers_an_unknown_prompt_kind_with_a_legal_option() -> void:
	# Arrange: a prompt of a kind the bot was not written for (a zone pick)
	var m := _board()
	var f := m.make_frame(-1, BOT, [], "test prompt")
	m.stack.append(f)
	m.ask(f, BOT, "zone_pick_of_the_future", "Choose a zone.", [{"v": 3, "label": "Zone 4"}, {"v": 5, "label": "Zone 6"}])
	# Act
	var cmd := BotBrain.new(BOT, 1).decide(m)
	# Assert
	assert_str(String(cmd.get("t", ""))).is_equal("choose")
	assert_array(cmd["indices"]).has_size(1)
	assert_bool(int(cmd["indices"][0]) in [0, 1]).is_true()


func test_bot_always_answers_an_evolve_prompt_with_evolve() -> void:
	# Arrange: L23's turn-start prompt, Evolve offered second
	var m := _board()
	var f := m.make_frame(-1, BOT, [], "evolve")
	m.stack.append(f)
	m.ask(f, BOT, "evolve", "Evolve Symbiote Spawn?", [{"v": 0, "label": "Skip"}, {"v": 1, "label": "Evolve"}])
	# Act
	var cmd := BotBrain.new(BOT, 1).decide(m)
	# Assert
	assert_array(cmd["indices"]).is_equal([1])


func test_draft_pick_prefers_a_strong_unit_to_a_basic_unit() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	# Act
	var i := BotCards.best_index([TB.WATER, LONE_WARRIOR, TB.FIRE], [], rng)
	# Assert
	assert_int(i).is_equal(1)


func test_removal_reward_thins_the_weakest_card_only_from_a_large_deck() -> void:
	# Arrange
	var big := [TB.WATER]
	for k in 13:
		big.append(LONE_WARRIOR)
	var small := [TB.WATER, LONE_WARRIOR, LONE_WARRIOR]
	# Act / Assert
	assert_int(BotCards.removal(big)).is_equal(TB.WATER)
	assert_int(BotCards.removal(small)).is_equal(-1)
