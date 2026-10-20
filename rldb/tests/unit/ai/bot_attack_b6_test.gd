extends GdUnitTestSuite
## Owner feedback 2026-10-20 B6: "sometimes the bot doesn't attack when it could easily kill a
## unit". Each scenario plays the bot's whole turn (Setup, Battle, Recovery) from its Setup Phase
## on turn 2 and checks the outcome, over several seeds (the bot adds a small random jitter).
## Root cause: in its Battle Phase the bot scored its units' attack potential (a kill plus part of
## the unit it would expose) above the attack's actual result, so it kept the threat instead of
## attacking a Defense guard in front of a strong back-row unit.

const BOT := 1
const HUMAN := 0
const SEEDS := [1, 2, 3, 4, 5, 6]


## Plays the bot's turn; the human passes every response. Returns the commands the bot sent.
func _bot_turn(m: MatchEngine, seed_value: int) -> Array:
	var bot := BotBrain.new(BOT, seed_value)
	var sent := []
	for i in 80:
		if m.winner != -1:
			break
		if not m.pending.is_empty() and int(m.pending["player"]) == HUMAN:
			m.submit(HUMAN, {"t": "choose", "id": m.pending["id"], "indices": [0]})
			continue
		if m.active != BOT:
			break
		var cmd := bot.decide(m)
		if cmd.is_empty():
			break
		sent.append(cmd)
		assert_str(m.submit(BOT, cmd)).override_failure_message("refused %s" % cmd).is_empty()
	return sent


## A fresh board on the bot's turn 2 (Setup Phase) with an empty bot Hand.
func _board() -> MatchEngine:
	var m := TB.make()
	TB.to_turn2(m)
	m.players[BOT]["hand"].clear()
	return m


func test_bot_kills_a_defense_guard_in_front_of_a_strong_back_row_unit() -> void:
	for sd in SEEDS:
		var m := _board()
		TB.unit(m, BOT, TB.WATER, 0, "atk", 20, 10)
		TB.unit(m, HUMAN, TB.WATER, 3, "atk", 30, 30)       # protected while the guard stands
		var guard := TB.unit(m, HUMAN, TB.WATER, 0, "def", 8, 8)
		_bot_turn(m, sd)
		assert_str(m.cards[guard]["zone"]).override_failure_message("seed %d" % sd).is_not_equal("unit")


func test_bot_kills_a_weak_attack_stance_unit() -> void:
	for sd in SEEDS:
		var m := _board()
		TB.unit(m, BOT, TB.WATER, 0, "atk", 20, 10)
		var weak := TB.unit(m, HUMAN, TB.WATER, 0, "atk", 8, 8)
		_bot_turn(m, sd)
		assert_str(m.cards[weak]["zone"]).override_failure_message("seed %d" % sd).is_not_equal("unit")


func test_bot_turns_to_attack_stance_and_kills_in_the_same_turn() -> void:
	for sd in SEEDS:
		var m := _board()
		var mine := TB.unit(m, BOT, TB.WATER, 0, "def", 20, 30)
		var weak := TB.unit(m, HUMAN, TB.WATER, 0, "def", 8, 8)
		_bot_turn(m, sd)
		assert_str(m.cards[weak]["zone"]).override_failure_message("seed %d" % sd).is_not_equal("unit")
		assert_str(m.cards[mine]["zone"]).is_equal("unit")


func test_bot_summons_then_kills_with_the_new_unit() -> void:
	for sd in SEEDS:
		var m := _board()
		m.players[BOT]["ap"] = 2
		var h := TB.card(m, BOT, TB.WATER)
		m.cards[h]["base_atk"] = 20
		var weak := TB.unit(m, HUMAN, TB.FIRE, 0, "atk", 4, 4)
		_bot_turn(m, sd)
		assert_str(m.cards[weak]["zone"]).override_failure_message("seed %d" % sd).is_not_equal("unit")


func test_bot_with_infiltrate_kills_a_protected_back_row_unit() -> void:
	for sd in SEEDS:
		var m := _board()
		var a := TB.unit(m, BOT, TB.WATER, 0, "atk", 20, 10)
		m.apply_status(a, "infiltrate", 1)
		TB.unit(m, HUMAN, TB.WATER, 0, "def", 40, 40)
		var back := TB.unit(m, HUMAN, TB.WATER, 3, "atk", 8, 8)
		_bot_turn(m, sd)
		assert_str(m.cards[back]["zone"]).override_failure_message("seed %d" % sd).is_not_equal("unit")


func test_bot_makes_no_attack_that_loses_its_unit_or_only_costs_hp() -> void:
	var cases := [
		[30, 30, "atk"],          # loses the unit
		[5, 30, "def"],           # bounces off a higher DEF: only HP lost
		[5, 20, "def"],           # equal DEF: nothing gained
	]
	for c in cases:
		for sd in SEEDS:
			var m := _board()
			var mine := TB.unit(m, BOT, TB.WATER, 0, "atk", 20, 10)
			TB.unit(m, HUMAN, TB.WATER, 0, c[2], c[0], c[1])
			_bot_turn(m, sd)
			assert_str(m.cards[mine]["zone"]).override_failure_message("%s seed %d" % [c, sd]).is_equal("unit")
			assert_int(int(m.cards[mine]["attacked_turn"])).override_failure_message("%s seed %d attacked" % [c, sd]).is_not_equal(m.turn)
