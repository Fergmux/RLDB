extends GdUnitTestSuite
## F11: bot stance decisions follow bounded, explainable scoring (BotStance) instead of
## "Defense whenever DEF > ATK". Representative positions plus full bot-vs-bot games.

## Longest a bot-vs-bot game may run (turns) before it counts as a passive stalemate.
const TURN_BOUND := 120


## Player 1 (the bot) active in Setup, no AP so only stance / phase moves are attractive.
func _setup() -> MatchEngine:
	var m := TB.make()
	TB.to_turn2(m)
	m.players[1]["ap"] = 0
	m.players[1]["hand"].clear()
	return m


func test_attack_is_chosen_although_def_is_higher_when_the_target_is_beatable() -> void:
	var m := _setup()
	var u := TB.unit(m, 1, TB.WATER, 0, "def", 10, 20)
	TB.unit(m, 0, TB.WATER, 0, "atk", 5, 5)               # beaten by ATK 10, cannot hurt it back
	var b := BotBrain.new(1, 3)
	var cmd := b.decide(m)
	assert_str(String(cmd.get("t", ""))).is_equal("stance")
	assert_int(int(cmd.get("uid", -1))).is_equal(u)
	assert_str(b.last_debug).contains("stance")


## L27 (2026-11-05): the unit must also be safe in Attack stance through the opponent's next turn
## (stance is locked after the Setup Phase). A 5/20 unit flipped for 5 direct damage is killed by
## the first unit they summon, so the reworked bot rightly keeps that one in Defense; a 25/20 unit
## takes the direct attack and stays safe.
func test_direct_attack_opportunity_moves_a_defense_unit_to_attack() -> void:
	var m := _setup()
	var u := TB.unit(m, 1, TB.WATER, 0, "def", 25, 20)
	var cmd := BotBrain.new(1, 4).decide(m)
	assert_str(String(cmd.get("t", ""))).is_equal("stance")
	assert_int(int(cmd.get("uid", -1))).is_equal(u)


func test_defense_is_chosen_when_attack_would_only_expose_the_unit() -> void:
	var m := _setup()
	var u := TB.unit(m, 1, TB.WATER, 0, "atk", 10, 20)
	TB.unit(m, 0, TB.WATER, 0, "atk", 15, 15)             # beats ATK 10, bounces off DEF 20
	var cmd := BotBrain.new(1, 5).decide(m)
	assert_str(String(cmd.get("t", ""))).is_equal("stance")
	assert_int(int(cmd.get("uid", -1))).is_equal(u)


func test_a_defending_guard_is_not_flipped_into_a_beatable_attack() -> void:
	var m := _setup()
	TB.unit(m, 1, TB.WATER, 0, "def", 8, 20)              # guard in the front row ...
	TB.unit(m, 1, TB.WATER, 3, "def", 8, 8)               # ... protecting this back-row unit
	TB.unit(m, 0, TB.WATER, 0, "atk", 15, 15)
	var cmd := BotBrain.new(1, 6).decide(m)
	assert_str(String(cmd.get("t", ""))).is_not_equal("stance")


func test_score_breakdown_is_explained_and_bounded() -> void:
	var m := _setup()
	var u := TB.unit(m, 1, TB.WATER, 0, "def", 10, 20)
	TB.unit(m, 0, TB.WATER, 0, "atk", 5, 5)
	var atk := BotStance.explain(m, u, 1, "atk")
	var def := BotStance.explain(m, u, 1, "def")
	assert_float(atk["total"]).is_greater(def["total"])
	assert_float(atk["offense"]).is_less_equal(BotStance.CAP)
	assert_str(atk["text"]).contains("offense")
	assert_str(BotStance.compare_text(m, u, 1)).contains("def")


func test_stance_decisions_are_deterministic_for_a_seed() -> void:
	var a := _setup()
	TB.unit(a, 1, TB.WATER, 0, "def", 10, 20)
	TB.unit(a, 0, TB.WATER, 0, "atk", 5, 5)
	var first := BotBrain.new(1, 77).decide(a)
	var second := BotBrain.new(1, 77).decide(a)
	assert_dict(first).is_equal(second)



## Full games between two bots end without a stalemate inside the turn bound. Prints stance mix
## and turn counts so before/after balance can be compared.
func test_bot_vs_bot_games_complete_without_stalemate() -> void:
	var finished := 0
	var turns_total := 0
	var summons := {"atk": 0, "def": 0}
	var flips := {"atk": 0, "def": 0}
	var seeds := [31, 32, 33, 34]
	for sd in seeds:
		var s := Series.new()
		s.setup({"seed": sd, "best_of": 1})
		var bots := [BotBrain.new(0, sd * 2), BotBrain.new(1, sd * 2 + 1)]
		var steps := 0
		while s.stage != Series.STAGE_OVER and steps < 8000:
			steps += 1
			var acted := false
			for p in 2:
				var cmd: Dictionary = bots[p].series_command(s) if s.stage != Series.STAGE_GAME else bots[p].decide(s.game)
				if cmd.is_empty():
					continue
				if s.stage == Series.STAGE_GAME:
					if cmd["t"] == "summon" and cmd.has("stance"):
						summons[cmd["stance"]] += 1
					elif cmd["t"] == "stance":
						var now: String = s.game.cards[cmd["uid"]]["stance"]
						flips["def" if now == "atk" else "atk"] += 1
					if s.game.turn > TURN_BOUND:
						s.submit(p, {"t": "concede"})
						acted = true
						break
				s.submit(p, cmd)
				acted = true
				break
			if not acted:
				break
		if s.stage == Series.STAGE_OVER and s.game != null and s.game.turn <= TURN_BOUND:
			finished += 1
		turns_total += s.game.turn if s.game != null else 0
	print("F11 bot-vs-bot: finished %d/%d, avg turns %.1f, summons %s, flips %s" % [
		finished, seeds.size(), float(turns_total) / seeds.size(), summons, flips])
	assert_int(finished).is_equal(seeds.size())
