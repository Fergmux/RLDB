extends GdUnitTestSuite
## BotBrain: look-ahead copies are independent, the move choice follows the position score, and
## a whole series between two bots finishes with every command accepted.


func _battle(m: MatchEngine) -> void:
	TB.to_turn2(m)                                       # player 1 active
	TB.to_battle(m)


func test_clone_is_independent_of_the_real_match() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0)
	var sim := m.clone_for_sim()
	sim.players[0]["hp"] = 1
	sim.cards[u]["st"]["burn"] = 3
	sim.submit(0, {"t": "next_phase"})
	assert_int(m.players[0]["hp"]).is_equal(60)
	assert_int(m.status_count(u, "burn")).is_equal(0)
	assert_str(m.phase).is_equal("main1")
	assert_str(sim.phase).is_not_equal("main1")


func test_evaluate_prefers_more_own_stats_and_fewer_enemy_stats() -> void:
	var m := TB.make()
	var b := BotBrain.new(1, 1)
	var base := b.evaluate(m)
	TB.unit(m, 1, TB.WATER, 0)
	var with_own := b.evaluate(m)
	TB.unit(m, 0, TB.WATER, 0)
	TB.unit(m, 0, TB.WATER, 1)
	assert_float(with_own).is_greater(base)
	assert_float(b.evaluate(m)).is_less(with_own)


func test_bot_attacks_directly_when_the_opponent_has_no_units() -> void:
	var m := TB.make()
	_battle(m)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 20)
	var b := BotBrain.new(1, 3)
	var cmd := b.decide(m)
	assert_str(String(cmd.get("t", ""))).is_equal("attack")
	assert_int(int(cmd.get("uid", -1))).is_equal(a)


func test_bot_does_not_attack_into_a_much_stronger_defender() -> void:
	var m := TB.make()
	_battle(m)
	TB.unit(m, 1, TB.WATER, 0, "atk", 6)
	TB.unit(m, 0, TB.WATER, 0, "atk", 30)                # the only target: attacking loses the unit
	var b := BotBrain.new(1, 5)
	assert_str(String(b.decide(m).get("t", ""))).is_equal("next_phase")


func test_bot_summons_a_unit_in_main_phase() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	m.players[1]["ap"] = 2
	TB.card(m, 1, TB.WATER)
	var cmd := BotBrain.new(1, 9).decide(m)
	assert_str(String(cmd.get("t", ""))).is_equal("summon")
	assert_bool(m.players[1]["hand"].has(int(cmd.get("uid", -1)))).is_true()   # hand holds identical Water Mages


func test_bot_waits_while_the_human_decides() -> void:
	var m := TB.make()                                    # player 0 (the human) is active
	assert_bool(BotBrain.new(1, 2).decide(m).is_empty()).is_true()


## Two bots play a best-of-1 series through the real Series API: every command they send is
## legal and the game ends.
func test_two_bots_finish_a_series_with_only_legal_commands() -> void:
	var s := Series.new()
	s.setup({"seed": 21, "best_of": 1})
	var bots := [BotBrain.new(0, 11), BotBrain.new(1, 12)]
	var refused := []
	var steps := 0
	while s.stage != Series.STAGE_OVER and steps < 4000:
		steps += 1
		var acted := false
		for p in 2:
			var cmd: Dictionary = bots[p].series_command(s) if s.stage != Series.STAGE_GAME else bots[p].decide(s.game)
			if cmd.is_empty():
				continue
			var err := s.submit(p, cmd)
			if err != "":
				refused.append("%s -> %s" % [cmd, err])
				s.submit(p, {"t": "next_phase"} if s.stage == Series.STAGE_GAME and s.game.pending.is_empty() else {"t": "concede"})
			acted = true
			break
		if not acted:
			break
	assert_array(refused).is_empty()
	assert_str(s.stage).is_equal(Series.STAGE_OVER)
