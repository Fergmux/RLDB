extends GdUnitTestSuite
## L23 (design/owner-feedback-2026-11-05.md, confirmed rules in its Clarifications): the Evolve
## mechanic. Symbiote Spawn (155) evolves into Symbiote Larva (156), which evolves into Symbiote
## Siphonophore (157). At the start of its controller's turn each evolvable unit gets an
## "Evolve <card> into <next>?" prompt (Evolve / Skip, free); the evolved card replaces the instance
## for the rest of the game, keeps its state, and is not a Summon.

const SPAWN := 155
const LARVA := 156
const SIPHONOPHORE := 157
const MAGE := TB.FILLER                  # Basic Mage (Water) 8/8
const SHEN := 21                         # "If your opponent Summons a Unit, that Unit permanently loses -10 ATK"
const SUMMON_TRAP := 49                  # a Trap answering a Summon (Paralyse 3)


## Player 1's Spawn on the Field (placed on turn 1), then player 1's turn starts: the Evolve prompt.
func _p1_spawn_turn(m: MatchEngine, slot: int = 3, id: int = SPAWN) -> int:
	var uid := TB.unit(m, 1, id, slot)
	TB.to_turn2(m)
	return uid


func test_spawn_at_start_of_its_turn_gets_the_evolve_prompt() -> void:
	var m := TB.make()
	var spawn := _p1_spawn_turn(m)
	assert_str(TB.pend_kind(m)).is_equal("evolve")
	assert_int(int(m.pending["player"])).is_equal(1)
	assert_int(int(m.pending["source"])).is_equal(spawn)
	assert_str(String(m.pending["prompt"])).is_equal("Evolve Symbiote Spawn into Symbiote Larva?")
	assert_array(m.pending["options"].map(func(o): return o["label"])).is_equal(["Evolve", "Skip"])
	assert_bool(m.pending["cancellable"]).is_false()


func test_evolve_replaces_the_card_and_keeps_zone_stance_statuses_and_changes() -> void:
	var m := TB.make()
	var spawn := TB.unit(m, 1, SPAWN, 4, "def")
	m.apply_status(spawn, "eternal", 2)
	m.cards[spawn]["runes"] = 1
	m.cards[spawn]["mods"].append({"atk": 6, "def": 2, "until": "perm", "src": "test"})
	m.cards[spawn]["cost_p"] = 1
	TB.to_turn2(m)
	var ap_before: int = m.players[1]["ap"]
	assert_str(TB.choose(m, ["Evolve"])).is_equal("")
	var inst: Dictionary = m.cards[spawn]
	assert_int(int(inst["id"])).is_equal(LARVA)
	assert_str(m.name_of(spawn)).is_equal("Symbiote Larva")
	assert_str(String(inst["zone"])).is_equal("unit")
	assert_int(int(inst["slot"])).is_equal(4)
	assert_str(String(inst["stance"])).is_equal("def")
	assert_int(m.status_count(spawn, "eternal")).is_equal(2)
	assert_int(m.status_count(spawn, "rune")).is_equal(1)
	assert_int(m.atk_of(spawn)).is_equal(6)                     # Larva's base 0 plus the kept +6
	assert_int(m.def_of(spawn)).is_equal(2)
	assert_int(m.current_cost(spawn)).is_equal(3)               # Larva's printed 2 plus the kept +1
	assert_int(m.players[1]["ap"]).is_equal(ap_before)          # free
	assert_int(m.players[1]["units"][4]).is_equal(spawn)


func test_evolve_is_not_a_summon() -> void:
	var m := TB.make()
	TB.unit(m, 0, SHEN, 0)                                     # the opponent's Shen
	TB.set_card(m, 0, SUMMON_TRAP, 1)                          # and a Trap answering a Summon
	var spawn := TB.unit(m, 1, SPAWN, 3)
	m.apply_status(spawn, "eternal", 1)
	TB.to_turn2(m)
	TB.choose(m, ["Evolve"])
	assert_int(int(m.cards[spawn]["id"])).is_equal(LARVA)
	assert_bool(m.pending.is_empty()).override_failure_message(str(m.pending)).is_true()   # no Trap window
	assert_int(m.status_count(spawn, "eternal")).is_equal(1)   # Larva's On Summon (Eternal) did not fire
	assert_int(m.atk_of(spawn)).is_equal(0)                    # Shen's -10 did not apply
	assert_array(m.cards[spawn]["mods"]).is_empty()
	assert_int(m.status_count(spawn, "paralyse")).is_equal(0)


func test_skip_keeps_the_card() -> void:
	var m := TB.make()
	var spawn := _p1_spawn_turn(m)
	assert_str(TB.choose(m, ["Skip"])).is_equal("")
	assert_int(int(m.cards[spawn]["id"])).is_equal(SPAWN)
	assert_bool(m.pending.is_empty()).is_true()
	assert_str(TB.log_text(m)).contains("does not evolve Symbiote Spawn")


func test_evolved_card_stays_evolved_wherever_it_goes_this_game() -> void:
	var m := TB.make()
	var spawn := _p1_spawn_turn(m)
	TB.choose(m, ["Evolve"])
	m.move_to_pile(spawn, "spent")
	assert_int(int(m.cards[spawn]["id"])).is_equal(LARVA)
	m.move_to_pile(spawn, "hand")
	assert_int(int(m.cards[spawn]["id"])).is_equal(LARVA)
	m.move_to_pile(spawn, "draw")
	assert_int(int(m.cards[spawn]["id"])).is_equal(LARVA)
	var v := MatchView.card_view(m, spawn, 1)
	assert_str(String(v["name"])).is_equal("Symbiote Larva")


func test_larva_evolves_into_siphonophore_and_the_chain_ends_there() -> void:
	var m := TB.make()
	var spawn := _p1_spawn_turn(m)
	TB.choose(m, ["Evolve"])                                   # turn 2: Spawn -> Larva
	m.submit(1, {"t": "next_phase"})
	m.submit(1, {"t": "next_phase"})
	m.submit(1, {"t": "next_phase"})                           # end of turn 2
	m.submit(0, {"t": "next_phase"})
	m.submit(0, {"t": "next_phase"})
	m.submit(0, {"t": "next_phase"})                           # end of turn 3
	assert_int(m.turn).is_equal(4)
	assert_str(TB.pend_kind(m)).is_equal("evolve")
	assert_str(String(m.pending["prompt"])).is_equal("Evolve Symbiote Larva into Symbiote Siphonophore?")
	TB.choose(m, ["Evolve"])
	assert_int(int(m.cards[spawn]["id"])).is_equal(SIPHONOPHORE)
	assert_bool(m.can_evolve(spawn)).is_false()
	assert_bool(m.pending.is_empty()).override_failure_message(str(m.pending)).is_true()


func test_new_form_start_of_turn_effect_first_fires_next_turn() -> void:
	# Spawn -> Larva at the start of the turn: Larva's "draw a card, then discard a card" waits.
	var m := TB.make()
	_p1_spawn_turn(m)
	TB.choose(m, ["Evolve"])
	assert_bool(m.pending.is_empty()).override_failure_message(str(m.pending)).is_true()
	var m2 := TB.make()
	TB.to_turn2(m2)
	assert_int(m.players[1]["hand"].size()).is_equal(m2.players[1]["hand"].size())   # no Larva draw


func test_larva_that_evolves_does_not_also_draw_and_discard() -> void:
	var m := TB.make()
	_p1_spawn_turn(m, 3, LARVA)
	TB.choose(m, ["Evolve"])                                   # Larva -> Siphonophore
	assert_bool(m.pending.is_empty()).override_failure_message(str(m.pending)).is_true()
	var m2 := TB.make()
	TB.to_turn2(m2)
	assert_int(m.players[1]["hand"].size()).is_equal(m2.players[1]["hand"].size())


func test_larva_that_skips_still_draws_then_discards() -> void:
	var m := TB.make()
	_p1_spawn_turn(m, 3, LARVA)
	TB.choose(m, ["Skip"])
	assert_str(String(m.pending.get("prompt", ""))).contains("Discard")


func test_evolve_prompts_come_one_per_unit_in_field_order() -> void:
	var m := TB.make()
	var back := TB.unit(m, 1, SPAWN, 4)
	var front := TB.unit(m, 1, SPAWN, 0)
	TB.to_turn2(m)
	assert_int(int(m.pending["source"])).is_equal(front)
	TB.choose(m, ["Skip"])
	assert_str(TB.pend_kind(m)).is_equal("evolve")
	assert_int(int(m.pending["source"])).is_equal(back)
	TB.choose(m, ["Evolve"])
	assert_int(int(m.cards[front]["id"])).is_equal(SPAWN)
	assert_int(int(m.cards[back]["id"])).is_equal(LARVA)
	assert_bool(m.pending.is_empty()).is_true()


func test_evolve_prompts_come_before_other_start_of_turn_effects() -> void:
	var m := TB.make()
	TB.unit(m, 1, LARVA, 0)
	TB.unit(m, 1, SPAWN, 4)
	TB.to_turn2(m)
	assert_str(TB.pend_kind(m)).is_equal("evolve")
	TB.choose(m, ["Skip"])
	assert_str(TB.pend_kind(m)).is_equal("evolve")             # the second unit's prompt, not the discard
	TB.choose(m, ["Skip"])
	assert_str(String(m.pending.get("prompt", ""))).contains("Discard")


func test_debilitated_spawn_is_not_offered() -> void:
	var m := TB.make()
	var spawn := TB.unit(m, 1, SPAWN, 3)
	m.cards[spawn]["st"]["debilitate"] = 2
	TB.to_turn2(m)
	assert_bool(m.pending.is_empty()).override_failure_message(str(m.pending)).is_true()
	assert_int(int(m.cards[spawn]["id"])).is_equal(SPAWN)


func test_spawn_is_not_offered_on_the_opponents_turn() -> void:
	var m := TB.make()
	TB.unit(m, 0, SPAWN, 3)                                    # player 0's Spawn
	TB.to_turn2(m)                                             # player 1's turn
	assert_bool(m.pending.is_empty()).override_failure_message(str(m.pending)).is_true()


func test_evolve_logs_and_shows_a_public_fx_to_both_seats() -> void:
	var m := TB.make()
	var spawn := _p1_spawn_turn(m, 3)
	TB.choose(m, ["Evolve"])
	assert_str(TB.log_text(m)).contains("evolves Symbiote Spawn into Symbiote Larva.")
	for viewer in [0, 1, -1]:
		var found := {}
		for row in MatchView.log_for(m, viewer):
			for e in row["fx"]:
				if String(e.get("k", "")) == "evolve":
					found = e
		assert_int(int(found.get("from", -1))).is_equal(SPAWN)
		assert_int(int(found.get("to", -1))).is_equal(LARVA)
		assert_dict(found["at"]).is_equal({"p": 1, "zone": "unit", "slot": 3})
	var opp_view := MatchView.build(m, 0)
	assert_int(int(opp_view["players"][1]["units"][3]["id"])).is_equal(LARVA)   # face-up public info
	assert_int(int(MatchView.card_view(m, spawn, 0)["id"])).is_equal(LARVA)


func test_prompt_view_shows_both_forms_and_the_opponent_sees_only_the_wait() -> void:
	var m := TB.make()
	_p1_spawn_turn(m)
	var mine: Dictionary = MatchView.build(m, 1)["pending"]
	assert_str(String(mine["kind"])).is_equal("evolve")
	assert_int(int(mine["evolve_to"])).is_equal(LARVA)
	assert_array(mine["mentions"].map(func(e): return e["role"])).is_equal(["evolve_from", "evolve_to"])
	assert_int(int(mine["mentions"][1]["card"]["id"])).is_equal(LARVA)
	var theirs: Dictionary = MatchView.build(m, 0)["pending"]
	assert_bool(theirs["mine"]).is_false()
	assert_str(String(theirs["prompt"])).contains("deciding whether to evolve a unit")
	assert_bool(theirs.has("options")).is_false()
	var spec: Dictionary = MatchView.build_spectator(m, 0)["pending"]
	assert_bool(spec.has("options")).is_false()


func test_a_saved_deck_with_evolved_forms_starts_as_base_cards() -> void:
	var m := MatchEngine.new()
	m.setup([[LARVA, SIPHONOPHORE, MAGE], [MAGE, MAGE, MAGE]], 0, 7)
	var ids := []
	for u in m.cards:
		if int(m.cards[u]["owner"]) == 0:
			ids.append(int(m.cards[u]["id"]))
	ids.sort()
	assert_array(ids).is_equal([MAGE, SPAWN, SPAWN])


func test_next_game_deck_list_is_untouched_by_evolving() -> void:
	var deck := [SPAWN, MAGE, MAGE, MAGE, MAGE, MAGE]
	var m := MatchEngine.new()
	m.setup([deck.duplicate(), deck.duplicate()], 0, 7)
	for u in m.cards:
		if int(m.cards[u]["id"]) == SPAWN:
			m.cards[u]["zone"] = "limbo"
			m.players[int(m.cards[u]["owner"])]["draw"].erase(u)
			m.players[int(m.cards[u]["owner"])]["hand"].erase(u)
			m.place_unit(u, int(m.cards[u]["owner"]), 3, "atk")
			m.evolve_unit(u)
	assert_array(deck).is_equal([SPAWN, MAGE, MAGE, MAGE, MAGE, MAGE])
	var m2 := MatchEngine.new()
	m2.setup([deck.duplicate(), deck.duplicate()], 0, 8)
	var spawns := 0
	for u in m2.cards:
		if int(m2.cards[u]["id"]) == SPAWN:
			spawns += 1
	assert_int(spawns).is_equal(2)


func test_bot_always_evolves() -> void:
	var m := TB.make()
	var spawn := _p1_spawn_turn(m)
	var bot := BotBrain.new(1, 5)
	var cmd := bot.decide(m)
	assert_str(String(cmd.get("t", ""))).is_equal("choose")
	assert_str(String(m.pending["options"][int(cmd["indices"][0])]["label"])).is_equal("Evolve")
	assert_str(m.submit(1, cmd)).is_equal("")
	assert_int(int(m.cards[spawn]["id"])).is_equal(LARVA)


func test_clone_for_sim_keeps_the_evolved_card() -> void:
	var m := TB.make()
	var spawn := _p1_spawn_turn(m)
	TB.choose(m, ["Evolve"])
	var sim := m.clone_for_sim()
	assert_int(int(sim.cards[spawn]["id"])).is_equal(LARVA)
	assert_int(int(sim.cards[spawn]["evolved_turn"])).is_equal(m.turn)
