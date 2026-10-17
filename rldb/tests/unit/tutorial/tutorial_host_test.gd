extends GdUnitTestSuite
## Guided tutorial (F03-15): every lesson's scripted path completes through the TutorialHost
## using the real rules engine; off-script commands are refused without changing state; Restart
## restores the premade state; ordinary local sessions carry no tutorial filtering.

const ME := TutorialLessons.PLAYER
const RIVAL := TutorialLessons.OPPONENT


func _host(lesson: int) -> TutorialHost:
	var h: TutorialHost = auto_free(TutorialHost.new())
	h.opp_delay = 0.0
	h.start({"lesson": lesson})
	return h


func _snap(h: TutorialHost) -> Array:
	var m := h.game()
	return [m.cards.duplicate(true), m.players.duplicate(true), m.turn, m.phase, m.active, m.pending.duplicate(true), h.step_index]


## Plays the current step the way the lesson expects (Next, or its first expected command).
func _play_step(h: TutorialHost) -> void:
	var st := h.current_step()
	match String(st["kind"]):
		"read":
			h.next_step()
		"do":
			var cmd := TutorialScript.resolve(h.game(), h.keys, st["expect"][0])
			assert_dict(cmd).is_not_empty()
			h.handle(ME, cmd)
		"wait":
			fail("wait step %d did not settle by itself" % h.step_index)


## Plays the whole lesson; returns the number of player actions taken.
func _play_all(h: TutorialHost) -> int:
	var guard := 0
	while not h.is_complete() and guard < 100:
		var before := h.step_index
		var st := h.current_step()
		_play_step(h)
		guard += 1
		if st["kind"] == "do" and h.step_index == before:
			# A multi-press step ("until the turn ends") stays on its step until the condition holds.
			assert_dict(st.get("until", {})).is_not_empty()
	return guard


func test_every_lesson_completes_with_the_scripted_actions() -> void:
	for i in TutorialLessons.count():
		var h := _host(i)
		var done := [false]
		h.lesson_completed.connect(func(_i): done[0] = true)
		_play_all(h)
		assert_bool(h.is_complete()).override_failure_message("lesson %d incomplete at step %d" % [i, h.step_index]).is_true()
		assert_bool(done[0]).is_true()
		assert_int(h.refused).is_equal(0)
		assert_int(h.game().winner).is_equal(-1)
		assert_str(h.series.stage).is_equal(Series.STAGE_GAME)


func test_turn_flow_lesson_reaches_a_fresh_turn() -> void:
	var h := _host(0)
	_play_all(h)
	var m := h.game()
	assert_int(m.turn).is_equal(3)
	assert_int(m.active).is_equal(ME)
	assert_int(m.players[ME]["ap"]).is_equal(2)
	assert_int(m.players[ME]["hand"].size()).is_equal(4)
	assert_int(m.players[ME]["spent"].size()).is_equal(4)
	assert_str(m.cards[h.keys["o_warrior"]]["zone"]).is_equal("unit")    # the Rival's scripted summon


func test_summoning_lesson_places_units_and_stances() -> void:
	var h := _host(1)
	_play_all(h)
	var m := h.game()
	var mage: Dictionary = m.cards[h.keys["p_mage"]]
	var warrior: Dictionary = m.cards[h.keys["p_warrior"]]
	assert_int(mage["slot"]).is_equal(1)
	assert_str(mage["stance"]).is_equal("def")
	assert_int(warrior["slot"]).is_equal(4)
	assert_bool(m.is_protected(h.keys["p_warrior"])).is_true()
	assert_int(m.players[ME]["ap"]).is_equal(0)


func test_battle_lesson_outcome() -> void:
	var h := _host(2)
	_play_all(h)
	var m := h.game()
	assert_int(m.players[RIVAL]["hp"]).is_equal(46)
	assert_int(m.players[ME]["hp"]).is_equal(60)
	assert_array(m.field_units(RIVAL)).is_empty()


func test_spells_and_traps_lesson_outcome() -> void:
	var h := _host(3)
	_play_all(h)
	var m := h.game()
	assert_int(m.players[RIVAL]["hp"]).is_equal(46)          # Magic Cylinder 8, failed attack 6
	assert_str(m.cards[h.keys["p_cyl"]]["zone"]).is_equal("spent")
	assert_str(m.cards[h.keys["p_warrior"]]["zone"]).is_equal("unit")
	assert_int(m.cards[h.keys["p_warrior"]]["runes"]).is_equal(1)
	assert_int(m.active).is_equal(ME)


func test_extra_deck_lesson_outcome() -> void:
	var h := _host(4)
	_play_all(h)
	var m := h.game()
	var wyrm: Dictionary = m.cards[h.keys["p_wyrm"]]
	assert_str(wyrm["zone"]).is_equal("unit")
	assert_str(m.cards[h.keys["p_beast"]]["zone"]).is_equal("spent")
	assert_str(m.cards[h.keys["p_dragon"]]["zone"]).is_equal("spent")
	assert_int(m.players[RIVAL]["hp"]).is_equal(32)


func test_off_script_command_is_refused_and_changes_nothing() -> void:
	var h := _host(1)
	h.next_step()                                            # to "Summon in Attack stance"
	var before := _snap(h)
	var hints := []
	h.hint.connect(func(t): hints.append(t))
	h.handle(ME, {"t": "summon", "uid": h.keys["p_mage"], "stance": "def"})     # wrong stance
	h.handle(ME, {"t": "summon", "uid": h.keys["p_warrior"], "stance": "atk"})  # wrong card
	h.handle(ME, {"t": "next_phase"})
	h.handle(ME, {"t": "concede"})
	assert_array(_snap(h)).is_equal(before)
	assert_int(h.refused).is_equal(4)
	assert_int(hints.size()).is_equal(4)
	# The expected command still works afterwards; the wrong zone is refused too.
	h.handle(ME, {"t": "summon", "uid": h.keys["p_mage"], "stance": "atk"})
	assert_str(h.game().pending.get("kind", "")).is_equal("slot")
	var slot_snap := _snap(h)
	var pd := h.game().pending
	h.handle(ME, {"t": "choose", "id": pd["id"], "indices": [0]})
	h.handle(ME, {"t": "cancel", "id": pd["id"]})
	assert_array(_snap(h)).is_equal(slot_snap)


func test_read_steps_block_every_action_in_the_view() -> void:
	var h := _host(2)
	var v: Dictionary = h.seats[ME].last_view
	for a in v["match"]["actions"]:
		assert_bool(a["ok"]).is_false()
	h.next_step()
	h.next_step()                                            # "Enter the Battle Phase"
	v = h.seats[ME].last_view
	var oks: Array = v["match"]["actions"].filter(func(a): return a["ok"])
	assert_int(oks.size()).is_equal(1)
	assert_str(oks[0]["t"]).is_equal("next_phase")


func test_only_the_expected_action_is_offered() -> void:
	var h := _host(1)
	h.next_step()
	var oks: Array = h.seats[ME].last_view["match"]["actions"].filter(func(a): return a["ok"])
	assert_int(oks.size()).is_equal(1)
	assert_int(oks[0]["uid"]).is_equal(h.keys["p_mage"])
	assert_str(oks[0]["stance"]).is_equal("atk")


func test_restart_restores_the_initial_state() -> void:
	var h := _host(3)
	var initial := _snap(h)
	for i in 6:
		_play_step(h)
	assert_array(_snap(h)).is_not_equal(initial)
	h.restart()
	assert_array(_snap(h)).is_equal(initial)
	assert_int(h.opp_index).is_equal(0)
	# And the restarted lesson still completes.
	_play_all(h)
	assert_bool(h.is_complete()).is_true()


func test_next_lesson_loads_the_following_scenario() -> void:
	var h := _host(0)
	_play_all(h)
	assert_bool(h.has_next_lesson()).is_true()
	h.load_lesson(1)
	assert_int(h.lesson_index).is_equal(1)
	assert_int(h.step_index).is_equal(0)
	assert_bool(h.is_complete()).is_false()


func test_tutorial_never_saves() -> void:
	var h := _host(0)
	assert_array(h.series.checkpoint.get_connections()).is_empty()
	h.handle(ME, {"t": "forfeit_series"})                   # in-game "Return to menu"
	assert_str(h.series.stage).is_equal(Series.STAGE_GAME)


func test_ordinary_local_session_is_not_filtered() -> void:
	var lh: LocalHost = auto_free(LocalHost.new())
	lh.start({"seed": 5, "best_of": 1})
	lh.handle(0, {"t": "pick_starter", "index": 0})
	lh.handle(1, {"t": "pick_starter", "index": 1})
	var p: int = lh.series.game.active
	var v: Dictionary = lh.seats[p].last_view
	assert_bool(v.has("tutorial")).is_false()
	var oks: Array = v["match"]["actions"].filter(func(a): return a["ok"])
	assert_int(oks.size()).is_greater(1)
	for a in v["match"]["actions"]:
		assert_str(String(a.get("reason", ""))).is_not_equal(TutorialHost.REASON_LOCKED)
	var errors := []
	lh.error.connect(func(_s, t): errors.append(t))
	lh.handle(p, {"t": "next_phase"})
	assert_array(errors).is_empty()
	assert_str(lh.series.game.phase).is_not_equal("main1")


func test_lessons_reference_existing_cards_only() -> void:
	CardDB.ensure_loaded()
	for l in TutorialLessons.all():
		for c in l["setup"]["cards"]:
			assert_bool(CardDB.has(int(c["id"]))).override_failure_message("unknown card %s" % c["id"]).is_true()
			assert_bool(CardScripts.is_implemented(int(c["id"])) or CardDB.get_def(int(c["id"]))["category"] == "basic_unit").is_true()


# ---------------------------------------------------------------- F05-01 Ritual and Arcane lessons

## Plays steps until the current one is titled `title` (it is not played).
func _play_to(h: TutorialHost, title: String) -> void:
	var guard := 0
	while not h.is_complete() and String(h.current_step().get("title", "")) != title and guard < 100:
		guard += 1
		_play_step(h)
	assert_str(String(h.current_step().get("title", ""))).is_equal(title)


## Pending option index of lesson card `key`, or -1.
func _opt(h: TutorialHost, key: String) -> int:
	return TutorialScript.option_index(h.game(), h.keys, {"card": key})


func test_lesson_list_has_ritual_and_arcane_after_fusion() -> void:
	var ids := TutorialLessons.all().map(func(l): return String(l["id"]))
	assert_array(ids).is_equal(["turn_flow", "summoning", "battle", "spells_traps", "extra_deck", "ritual", "arcane"])
	for i in ids.size():
		assert_bool(String(TutorialLessons.get_lesson(i)["title"]).begins_with("Lesson %d ·" % (i + 1))).is_true()
	# Only the very last step of the very last lesson says "Tutorial complete".
	for i in ids.size():
		var steps: Array = TutorialLessons.get_lesson(i)["steps"]
		var last := i == ids.size() - 1
		assert_bool(String(steps[-1]["title"]) == "Tutorial complete").is_equal(last)
	# The Fusion lesson no longer carries the Ritual/Arcane explanation step.
	for st in TutorialLessons.get_lesson(TutorialLessons.index_of("extra_deck"))["steps"]:
		assert_str(String(st["title"])).is_not_equal("Ritual and Arcane")
	var h := _host(TutorialLessons.index_of("ritual"))
	assert_bool(h.has_next_lesson()).is_true()
	h.load_lesson(TutorialLessons.index_of("arcane"))
	assert_bool(h.has_next_lesson()).is_false()


func test_ritual_lesson_runes_tribute_and_payoff() -> void:
	var h := _host(TutorialLessons.index_of("ritual"))
	var m := h.game()
	var zealot: int = h.keys["p_zealot"]
	assert_int(m.status_count(zealot, "rune")).is_equal(2)          # premade 1 + its own start-of-turn Rune
	_play_to(h, "Open the Ritual summon")
	assert_int(m.status_count(zealot, "rune")).is_equal(3)          # Sacred Offerings
	assert_int(m.players[ME]["ap"]).is_equal(1)
	_play_all(h)
	assert_bool(h.is_complete()).is_true()
	assert_int(h.refused).is_equal(0)
	assert_str(m.cards[zealot]["zone"]).is_equal("spent")           # tribute goes to Spent
	assert_int(m.cards[zealot]["runes"]).is_equal(0)                # Runes clear on leaving Field (P-10)
	var null_u: Dictionary = m.cards[h.keys["p_null"]]
	assert_str(null_u["zone"]).is_equal("unit")
	assert_int(null_u["slot"]).is_equal(1)
	assert_int(m.players[ME]["ap"]).is_equal(1)                     # the Ritual summon paid no AP
	assert_str(m.cards[h.keys["o_warrior"]]["zone"]).is_equal("spent")
	assert_int(m.players[RIVAL]["hp"]).is_equal(28)                 # 40 against 8 in Attack stance (2026-10-17 Null 40/28)


func test_ritual_lesson_refuses_off_script_commands() -> void:
	var h := _host(TutorialLessons.index_of("ritual"))
	_play_to(h, "Open the Ritual summon")
	var before := _snap(h)
	h.handle(ME, {"t": "ritual", "uid": h.keys["p_null"], "stance": "def"})   # wrong stance
	h.handle(ME, {"t": "next_phase"})
	h.handle(ME, {"t": "summon", "uid": h.keys["p_hand0"], "stance": "atk"})
	assert_array(_snap(h)).is_equal(before)
	assert_int(h.refused).is_equal(3)
	_play_step(h)                                                    # the expected Ritual summon
	assert_str(String(h.current_step()["title"])).is_equal("Choose the material")
	var pd := h.game().pending
	var snap := _snap(h)
	h.handle(ME, {"t": "cancel", "id": pd["id"]})
	assert_array(_snap(h)).is_equal(snap)


func test_arcane_lesson_exact_total_exhausts_materials() -> void:
	var h := _host(TutorialLessons.index_of("arcane"))
	_play_all(h)
	var m := h.game()
	assert_bool(h.is_complete()).is_true()
	assert_int(h.refused).is_equal(0)
	assert_str(m.cards[h.keys["s_mage"]]["zone"]).is_equal("exhaust")
	assert_str(m.cards[h.keys["s_wyvern"]]["zone"]).is_equal("exhaust")
	assert_str(m.cards[h.keys["s_hydra"]]["zone"]).is_equal("spent")
	assert_str(m.cards[h.keys["s_drake"]]["zone"]).is_equal("spent")
	assert_str(m.cards[h.keys["p_boom"]]["zone"]).is_equal("unit")
	assert_int(m.players[ME]["ap"]).is_equal(2)                     # no AP paid for the Arcane summon
	assert_int(m.players[RIVAL]["hp"]).is_equal(32)                 # flipped to Attack: 36 against 8


func test_arcane_lesson_offers_no_zero_cost_unit_and_refuses_wrong_totals() -> void:
	var h := _host(TutorialLessons.index_of("arcane"))
	_play_to(h, "Choose the materials")
	var pd := h.game().pending
	assert_bool(pd.get("total_exact", false)).is_true()
	assert_int(int(pd["total_required"])).is_equal(3)
	assert_int(_opt(h, "s_drake")).is_equal(-1)                      # 0-cost: not offered (F03-05)
	var before := _snap(h)
	var hints := []
	h.hint.connect(func(t): hints.append(t))
	# Over-pay: both Dragons = 4.
	h.handle(ME, {"t": "choose", "id": pd["id"], "indices": [_opt(h, "s_wyvern"), _opt(h, "s_hydra")]})
	# Under-pay: a Dragon alone = 2.
	h.handle(ME, {"t": "choose", "id": pd["id"], "indices": [_opt(h, "s_wyvern")]})
	# Over-pay with an exact pair inside it: 1 + 2 + 2 = 5.
	h.handle(ME, {"t": "choose", "id": pd["id"], "indices": [_opt(h, "s_mage"), _opt(h, "s_wyvern"), _opt(h, "s_hydra")]})
	assert_array(_snap(h)).is_equal(before)
	assert_int(h.refused).is_equal(3)
	assert_array(hints).is_equal([TutorialHost.HINT_TOTAL % [4, 3], TutorialHost.HINT_TOTAL % [2, 3], TutorialHost.HINT_TOTAL % [5, 3]])
	# The view's picker agrees: Confirm would stay disabled for the over-pay, enabled for exact.
	var vp: Dictionary = h.seats[ME].last_view["match"]["pending"]
	assert_str(MatchView.multi_pick_error(vp, [_opt(h, "s_wyvern"), _opt(h, "s_hydra")])).is_not_empty()
	assert_str(MatchView.multi_pick_error(vp, [_opt(h, "s_mage"), _opt(h, "s_hydra")])).is_empty()
	# The other exact combination (Mage + Hydra), in either order, is accepted.
	h.handle(ME, {"t": "choose", "id": pd["id"], "indices": [_opt(h, "s_hydra"), _opt(h, "s_mage")]})
	assert_int(h.refused).is_equal(3)
	assert_str(String(h.current_step()["title"])).is_equal("Choose its zone")
	_play_all(h)
	assert_str(h.game().cards[h.keys["s_hydra"]]["zone"]).is_equal("exhaust")
	assert_str(h.game().cards[h.keys["s_wyvern"]]["zone"]).is_equal("spent")
