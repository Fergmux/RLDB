extends GdUnitTestSuite
## F04-22 / F07 (2026-10-17): every Fusion method makes all its choices first (Fusion unit, each
## material, zone, stance). The stance choice is the final, committing step (no separate Confirm).
## Before it the action is cancellable and nothing has changed; after it the cost /
## self-destruction resolves, then the summon. Choices are asked
## with the method's source still on the Field (pending `source`).
## Methods: Sepukku (68), Void Basilisk (67), Magentric (69), Aleister the Invoker (40),
## Fusion Laboratory (89), Fusion Ceremony cast (82) and set-activated, Tag Team - S (8, On Summon),
## and Unstable Fusions (137, Hand materials through Fusion Ceremony).

const WYRM := 93            # Bastion Wyrm: Beast + Dragon
const BEAST := 4            # Basic Beast (Water)
const DRAGON := 2           # Basic Dragon (Water)
const SEPUKKU := 68
const BASILISK := 67
const MAGENTRIC := 69
const ALEISTER := 40
const NETHER_PORTAL := 89
const POLY := 82
const TAG_TEAM_S := 8
const UNSTABLE := 137
const TRAP := 85            # any Trap: a face-down card opens hidden response windows


## Relevant state: every card instance and both players (AP, HP, zones), plus the stack.
func _state(m: MatchEngine) -> Dictionary:
	return {"cards": m.cards.duplicate(true), "players": m.players.duplicate(true), "stack": m.stack.size(),
		"triggers": m.trigger_queue.size(), "windows": m.window_queue.size()}


func _answer(m: MatchEngine, v: int) -> String:
	return m.submit(m.pending["player"], {"t": "choose", "id": m.pending["id"], "values": [v]})


func _cancel(m: MatchEngine) -> String:
	return m.submit(m.pending["player"], {"t": "cancel", "id": m.pending["id"]})


## Builds one method's scenario. Returns {m, start: Callable(m) -> String, src, answers, cost}.
## `answers`: Fusion unit, materials, zone, stance (0 = Attack; the committing step).
## `cost`: a log needle for the cost / self-destruction that must come before the summon.
func _setup(method: String) -> Dictionary:
	var m := TB.make()
	m.players[0]["ap"] = 5
	var wyrm := TB.card(m, 0, WYRM, "extra")
	var d := {"m": m, "wyrm": wyrm}
	match method:
		"sepukku":
			var sp := TB.unit(m, 0, SEPUKKU, 0)
			var b := TB.unit(m, 0, BEAST, 1)
			var dr := TB.unit(m, 0, DRAGON, 2)
			d.merge({"src": sp, "mats": [b, dr], "cmd": {"t": "ability", "uid": sp, "idx": 0},
				"answers": [wyrm, b, dr, 0, 0], "cost": "Sepukku is destroyed"})
		"basilisk":
			var vb := TB.unit(m, 0, BASILISK, 0)
			var b := TB.card(m, 0, BEAST, "spent")
			var dr := TB.card(m, 0, DRAGON, "spent")
			d.merge({"src": vb, "mats": [b, dr], "cmd": {"t": "ability", "uid": vb, "idx": 0},
				"answers": [wyrm, b, dr, 0, 0], "cost": "activates Void Basilisk"})
		"magentric":
			var mg := TB.unit(m, 0, MAGENTRIC, 0)
			var dr := TB.unit(m, 0, DRAGON, 1)
			d.merge({"src": mg, "mats": [mg, dr], "cmd": {"t": "ability", "uid": mg, "idx": 0},
				"answers": [wyrm, mg, dr, 1, 0], "cost": "activates Magentric"})
		"aleister":
			var al := TB.unit(m, 0, ALEISTER, 0)
			var b := TB.unit(m, 0, BEAST, 1)
			var dr := TB.unit(m, 0, DRAGON, 2)
			d.merge({"src": al, "mats": [b, dr], "cmd": {"t": "ability", "uid": al, "idx": 0},
				"answers": [wyrm, b, dr, 1, 0], "cost": "loses 1 AP"})
		"nether_portal":
			var np := TB.power(m, 0, NETHER_PORTAL)
			var b := TB.unit(m, 0, BEAST, 1)
			var dr := TB.unit(m, 0, DRAGON, 2)
			d.merge({"src": np, "mats": [b, dr], "cmd": {"t": "ability", "uid": np, "idx": 0},
				"answers": [wyrm, b, dr, 1, 0], "cost": "loses 1 AP"})
		"poly_cast":
			var poly := TB.card(m, 0, POLY, "hand")
			var b := TB.unit(m, 0, BEAST, 1)
			var dr := TB.unit(m, 0, DRAGON, 2)
			d.merge({"src": poly, "mats": [b, dr], "cmd": {"t": "cast", "uid": poly},
				"answers": [wyrm, b, dr, 1, 0], "cost": "pays 1 AP"})
		"poly_set":
			var poly := TB.set_card(m, 0, POLY, 0)
			var b := TB.unit(m, 0, BEAST, 1)
			var dr := TB.unit(m, 0, DRAGON, 2)
			d.merge({"src": poly, "mats": [b, dr], "cmd": {"t": "activate_set", "uid": poly},
				"answers": [wyrm, b, dr, 1, 0], "cost": "activates set Spell Fusion Ceremony"})
		"unstable":
			TB.power(m, 0, UNSTABLE)
			var poly := TB.card(m, 0, POLY, "hand")
			var b := TB.card(m, 0, BEAST, "hand")
			var dr := TB.unit(m, 0, DRAGON, 2)
			d.merge({"src": poly, "mats": [b, dr], "cmd": {"t": "cast", "uid": poly},
				"answers": [wyrm, b, dr, 2, 0], "cost": "pays 1 AP"})
	return d


const METHODS := ["sepukku", "basilisk", "magentric", "aleister", "nether_portal", "poly_cast", "poly_set", "unstable"]


func test_f04_22_cancel_at_every_step_restores_state() -> void:
	for method in METHODS:
		var steps: int = _setup(method)["answers"].size()
		for k in steps:
			var d := _setup(method)
			var m: MatchEngine = d["m"]
			var before := _state(m)
			var log_n := m.log_entries.size()
			assert_str(m.submit(0, d["cmd"])).override_failure_message("%s start" % method).is_empty()
			for i in k:
				assert_str(_answer(m, d["answers"][i])).override_failure_message("%s step %d" % [method, i]).is_empty()
			assert_bool(m.pending.get("cancellable", false)).override_failure_message("%s step %d cancellable" % [method, k]).is_true()
			assert_str(_cancel(m)).is_empty()
			assert_bool(m.pending.is_empty()).is_true()
			assert_dict(_state(m)).override_failure_message("%s: cancel at step %d changed state" % [method, k]).is_equal(before)
			# Only the private "Cancelled" line was logged: no cost, trigger or movement.
			assert_int(m.log_entries.size()).override_failure_message("%s step %d log" % [method, k]).is_equal(log_n + 1)


func test_f04_22_source_stays_on_field_while_choosing() -> void:
	for method in METHODS:
		var d := _setup(method)
		var m: MatchEngine = d["m"]
		var src: int = d["src"]
		var zone0: String = m.cards[src]["zone"]
		m.submit(0, d["cmd"])
		var answers: Array = d["answers"]
		for i in answers.size():
			assert_int(int(m.pending["source"])).override_failure_message("%s step %d source" % [method, i]).is_equal(src)
			assert_str(m.cards[src]["zone"]).override_failure_message("%s step %d zone" % [method, i]).is_equal(zone0)
			_answer(m, answers[i])


func test_f04_22_stance_commits_then_pays_and_summons_in_order() -> void:
	for method in METHODS:
		var d := _setup(method)
		var m: MatchEngine = d["m"]
		var wyrm: int = d["wyrm"]
		var log_n := m.log_entries.size()
		m.submit(0, d["cmd"])
		var answers: Array = d["answers"]
		for i in answers.size():
			if i == answers.size() - 1:
				assert_str(TB.pend_kind(m)).is_equal("stance")
				assert_int(m.log_entries.size()).override_failure_message("%s: nothing logged before the stance" % method).is_equal(log_n)
			assert_str(_answer(m, answers[i])).override_failure_message("%s step %d" % [method, i]).is_empty()
		assert_bool(m.pending.is_empty()).override_failure_message("%s pending %s" % [method, m.pending]).is_true()
		assert_str(m.cards[wyrm]["zone"]).override_failure_message(method).is_equal("unit")
		assert_int(m.cards[wyrm]["slot"]).override_failure_message(method).is_equal(answers[3])
		for mat in d["mats"]:
			assert_str(m.cards[mat]["zone"]).override_failure_message(method).is_not_equal("unit")
			assert_str(m.cards[mat]["zone"]).override_failure_message(method).is_not_equal("hand")
		var i_cost := TB.log_index(m, d["cost"])
		var i_sum := TB.log_index(m, "summons Bastion Wyrm")
		assert_int(i_cost).override_failure_message("%s cost log\n%s" % [method, TB.log_text(m)]).is_greater_equal(log_n)
		assert_int(i_sum).override_failure_message("%s summon log" % method).is_greater(i_cost)


func test_f04_22_sepukku_destroyed_after_stance_and_its_zone_is_offered() -> void:
	var d := _setup("sepukku")
	var m: MatchEngine = d["m"]
	var sp: int = d["src"]
	m.submit(0, d["cmd"])
	_answer(m, d["wyrm"])
	# Sepukku is never its own material.
	for o in m.pending["options"]:
		assert_int(int(o.get("uid", -1))).is_not_equal(sp)
	_answer(m, d["mats"][0])
	_answer(m, d["mats"][1])
	var slots: Array = m.pending["options"].map(func(o): return o["v"])
	assert_bool(0 in slots).is_true()                   # Sepukku's own zone (it leaves first)
	_answer(m, 0)
	assert_str(m.cards[sp]["zone"]).is_equal("unit")   # still there at the stance prompt
	_answer(m, 0)
	assert_str(m.cards[sp]["zone"]).is_equal("spent")
	assert_int(m.cards[d["wyrm"]]["slot"]).is_equal(0)


func test_f04_22_tag_team_trigger_cancel_and_stance() -> void:
	for k in 6:
		var m := TB.make()
		var b := TB.unit(m, 0, BEAST, 3)
		var dr := TB.unit(m, 0, DRAGON, 1)
		var wyrm := TB.card(m, 0, WYRM, "extra")
		var tt := TB.summon(m, 0, TAG_TEAM_S, 0)
		assert_str(TB.pend_kind(m)).is_equal("confirm")    # "Fusion Summon using units from your Field?"
		var before := _state(m)
		var answers := [1, wyrm, b, dr, 1, 0]
		for i in k:
			assert_int(int(m.pending["source"])).is_equal(tt)
			assert_str(_answer(m, answers[i])).is_empty()
		if k == 0:
			continue                                        # the opt-in itself: "No" declines
		if k < answers.size():
			assert_str(_cancel(m)).is_empty()
			var after := _state(m)
			assert_dict(after["cards"]).override_failure_message("Tag Team cancel at %d" % k).is_equal(before["cards"])
			assert_array(after["players"]).is_equal(before["players"])
	var m2 := TB.make()
	var b2 := TB.unit(m2, 0, BEAST, 3)
	var dr2 := TB.unit(m2, 0, DRAGON, 1)
	var wyrm2 := TB.card(m2, 0, WYRM, "extra")
	TB.summon(m2, 0, TAG_TEAM_S, 0)
	for v in [1, wyrm2, b2, dr2, 1, 0]:
		assert_str(_answer(m2, v)).is_empty()
	assert_str(m2.cards[wyrm2]["zone"]).is_equal("unit")
	assert_str(m2.cards[b2]["zone"]).is_equal("spent")
	assert_str(m2.cards[dr2]["zone"]).is_equal("spent")


func test_f04_22_illegal_and_stale_selections_are_rejected() -> void:
	var d := _setup("aleister")
	var m: MatchEngine = d["m"]
	var other := TB.unit(m, 0, TB.WATER, 4)               # a Mage: neither Beast nor Dragon
	m.submit(0, d["cmd"])
	_answer(m, d["wyrm"])
	var id_mat: int = m.pending["id"]
	assert_str(_answer(m, other)).is_equal("Invalid option.")
	assert_str(_answer(m, d["mats"][1])).is_equal("Invalid option.")   # the Dragon is not a Beast
	assert_str(m.submit(1, {"t": "choose", "id": id_mat, "values": [d["mats"][0]]})).is_not_empty()
	_answer(m, d["mats"][0])
	# A stale answer to the already-answered material prompt is refused.
	assert_str(m.submit(0, {"t": "choose", "id": id_mat, "values": [d["mats"][0]]})).is_equal("No such pending choice.")
	assert_str(_answer(m, d["mats"][0])).is_equal("Invalid option.")    # same unit twice
	assert_int(m.players[0]["ap"]).is_equal(5)


## A material lost during the response window after the committing stance: the summon fails, nothing else
## is tributed, the Fusion unit stays in the Extra Deck (the cost stays paid).
func test_f04_22_material_lost_in_response_window_fails_cleanly() -> void:
	var m := TB.make(7, 20, true)
	TB.set_card(m, 1, TRAP, 0)
	m.players[0]["ap"] = 5
	var wyrm := TB.card(m, 0, WYRM, "extra")
	var al := TB.unit(m, 0, ALEISTER, 0)
	var b := TB.unit(m, 0, BEAST, 1)
	var dr := TB.unit(m, 0, DRAGON, 2)
	m.submit(0, {"t": "ability", "uid": al, "idx": 0})
	for v in [wyrm, b, dr, 1, 0]:
		assert_str(_answer(m, v)).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	assert_int(m.players[0]["ap"]).is_equal(4)
	m.destroy(dr, "effect", -1, 1)                       # stands in for an opponent's response
	assert_str(TB.choose(m, ["Pass"])).is_empty()
	while not m.pending.is_empty() and TB.pend_kind(m) == "trap_response":
		TB.choose(m, ["Pass"])
	assert_str(m.cards[wyrm]["zone"]).is_equal("extra")
	assert_str(m.cards[b]["zone"]).is_equal("unit")
	assert_str(TB.log_text(m)).contains("no longer available")


## Review 2026-10-17: a method's self-destruction / exhaustion is a cost, paid right after the
## committing stance and before the response window (F04-22: "After Confirm, costs and
## self-destruction resolve, then the summon"). Before the fix the paying unit was still on the
## Field in the window; if it was destroyed there, Void Basilisk's cost then pulled it from Spent.
func test_f04_22_self_cost_is_paid_before_the_response_window() -> void:
	for method in ["sepukku", "basilisk"]:
		var d := _setup(method)
		var m: MatchEngine = d["m"]
		TB.set_card(m, 1, TRAP, 0)
		m.config["hidden_response_windows"] = true
		var src: int = d["src"]
		m.submit(0, d["cmd"])
		for v in d["answers"]:
			assert_str(_answer(m, v)).override_failure_message(method).is_empty()
		assert_str(TB.pend_kind(m)).override_failure_message(method).is_equal("trap_response")
		var paid_zone := "spent" if method == "sepukku" else "exhaust"
		assert_str(m.cards[src]["zone"]).override_failure_message("%s: cost not paid before the window" % method).is_equal(paid_zone)
		while not m.pending.is_empty() and TB.pend_kind(m) == "trap_response":
			TB.choose(m, ["Pass"])
		assert_str(m.cards[d["wyrm"]]["zone"]).override_failure_message(method).is_equal("unit")
		assert_str(m.cards[src]["zone"]).override_failure_message(method).is_equal(paid_zone)


## A self-destruction prevented by Eternal pays nothing more: no window, no summon, materials kept.
func test_f04_22_sepukku_saved_by_eternal_ends_before_the_window() -> void:
	var d := _setup("sepukku")
	var m: MatchEngine = d["m"]
	TB.set_card(m, 1, TRAP, 0)
	m.config["hidden_response_windows"] = true
	m.apply_status(d["src"], "eternal", 1)
	m.submit(0, d["cmd"])
	for v in d["answers"]:
		_answer(m, v)
	assert_bool(m.pending.is_empty()).override_failure_message(str(m.pending)).is_true()
	assert_str(m.cards[d["src"]]["zone"]).is_equal("unit")
	assert_str(m.cards[d["wyrm"]]["zone"]).is_equal("extra")
	for mat in d["mats"]:
		assert_str(m.cards[mat]["zone"]).is_equal("unit")
