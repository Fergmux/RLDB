extends GdUnitTestSuite
## Playtest feedback 08 (agent B): G04 exact-payment panel without a status line, G03 every card
## a response prompt mentions with Pass below Activate, G09 card-anchored toasts.


func _screen() -> Array:
	SeriesStore.DIR = "user://test_saves"
	var host: LocalHost = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 11, "best_of": 1, "deck_mode": "starter", "names": ["A", "B"]})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	var m: MatchEngine = host.series.game
	while m.turn < 2 or m.phase != "main1":
		m.submit(m.active, {"t": "next_phase"})
	host.broadcast()
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 900)
	add_child(gs)
	await gs.attach(host.seats[m.active])
	await await_idle_frame()
	return [gs, host, m, m.active]


func _cv(id: int, uid: int, cost: int) -> Dictionary:
	var c := MatchView.def_view(id)
	c["uid"] = uid
	c["cost"] = cost
	c["zone"] = "spent"
	return c


func _material_pd(need: int, costs: Array) -> Dictionary:
	var opts := []
	for i in costs.size():
		opts.append({"i": i, "label": "M%d" % i, "value": costs[i], "card": _cv(13, 9100 + i, costs[i])})
	return {"id": 778, "mine": true, "player": 0, "kind": "select", "prompt": "Exhaust units from Spent whose current costs total exactly %d." % need,
		"options": opts, "min": 1, "max": opts.size(), "cancellable": true, "min_total": need, "total_required": need, "total_exact": true}


func _render(gs: GameScreen, pd: Dictionary) -> void:
	gs.mv["pending"] = pd
	gs.prompt.prompt_sig = 0
	gs.prompt.render()
	await await_idle_frame()


# ---------------------------------------------------------------- G03

## The attacked seat's screen while Radablast attacks Basic Monster and Damage Conversion (set in
## that column) may respond. Returns [gs, host, m, attacker seat, radablast, monster, trap].
func _attack_window(direct: bool = false) -> Array:
	var r := await _screen()
	var gs: GameScreen = r[0]
	var host: LocalHost = r[1]
	var m: MatchEngine = r[2]
	var a: int = r[3]
	var b := 1 - a
	m.submit(a, {"t": "next_phase"})                     # Battle Phase
	var rad := TB.unit(m, a, 77, 1, "atk")
	var mon := -1 if direct else TB.unit(m, b, 5, 1, "atk")
	var trap := TB.set_card(m, b, 47, 1)
	m.submit(a, {"t": "attack", "uid": rad})
	if m.pending.get("kind", "") == "attack_target":
		TB.choose_uids(m, [mon if not direct else -1])
	await gs.attach(host.seats[b])
	host.broadcast()
	await await_idle_frame()
	await await_idle_frame()
	return [gs, host, m, a, rad, mon, trap]


func _figures(gs: GameScreen) -> Array:
	return gs.prompt.mention_row.get_children().filter(func(n): return n.has_meta("role"))


func _widget_in(n: Node) -> CardWidget:
	for c in n.get_children():
		if c is CardWidget:
			return c
	return null


func _list_texts(gs: GameScreen) -> Array:
	return gs.prompt.banner_list.get_children().map(func(b): return String((b as Button).text))


func test_g03_trap_response_shows_attacker_target_and_responding_trap() -> void:
	var r := await _attack_window()
	var gs: GameScreen = r[0]
	var m: MatchEngine = r[2]
	assert_str(String(m.pending.get("kind", ""))).is_equal("trap_response")
	assert_bool(gs.prompt.ctx_banner.visible).is_true()
	assert_bool(gs.prompt.mention_box.visible).is_true()
	var figs := _figures(gs)
	assert_array(figs.map(func(f): return String(f.get_meta("role")))).is_equal(["attacker", "target"])
	assert_int(int(_widget_in(figs[0]).view.get("uid", -1))).is_equal(r[4])
	assert_int(int(_widget_in(figs[1]).view.get("uid", -1))).is_equal(r[5])
	var resp := []
	for row in gs.prompt.respond_col.get_children():
		var w := _widget_in(row)
		if w != null:
			resp.append(int(w.view.get("uid", -1)))
	assert_array(resp).is_equal([r[6]])


func test_g03_pass_sits_below_activate() -> void:
	var r := await _attack_window()
	var gs: GameScreen = r[0]
	var m: MatchEngine = r[2]
	assert_str(String(m.pending["options"][0]["label"])).is_equal("Pass")    # the engine lists Pass first
	assert_array(_list_texts(gs)).is_equal(["Activate Damage Conversion", "Pass"])
	await await_idle_frame()
	var btns := gs.prompt.banner_list.get_children()
	assert_float((btns[1] as Control).position.y).is_greater((btns[0] as Control).position.y)
	assert_bool(gs.prompt.banner_flow.visible).is_false()
	# Pressing the list buttons answers the right options.
	(btns[1] as Button).pressed.emit()
	await await_idle_frame()
	assert_str(String(m.pending.get("kind", ""))).is_not_equal("trap_response")


func test_g03_direct_attack_shows_the_attacked_player() -> void:
	var r := await _screen()
	var gs: GameScreen = r[0]
	var m: MatchEngine = r[2]
	var a: int = r[3]
	var rad := TB.unit(m, 1 - a, 77, 1, "atk")
	var ev := {"name": "attack", "player": 1 - a, "attacker": rad, "target": -1}
	var ms := MatchView.event_cards(m, ev, a)
	assert_int(int(ms[1]["p"])).is_equal(a)
	var pd := {"id": 884, "mine": true, "player": a, "kind": "trap_response", "prompt": "Respond to: Radablast attacks directly",
		"options": [{"i": 0, "label": "Pass"}], "min": 1, "max": 1, "cancellable": false, "mentions": ms}
	await _render(gs, pd)
	var figs := _figures(gs)
	assert_array(figs.map(func(f): return String(f.get_meta("role")))).is_equal(["attacker", "direct"])
	var tok: Control = figs[1].get_child(0)
	assert_bool(tok is GamePromptBanner.DirectToken).is_true()
	assert_str((tok as GamePromptBanner.DirectToken).who).is_equal("YOU")


func test_g03_event_cards_never_reveal_a_hidden_card() -> void:
	var r := await _screen()
	var m: MatchEngine = r[2]
	var a: int = r[3]
	var opp_hand := TB.card(m, 1 - a, 13, "hand")
	var opp_set := TB.set_card(m, 1 - a, 47, 2)
	var mine := TB.card(m, a, 13, "hand")
	var hidden := MatchView.event_cards(m, {"name": "activate", "card": opp_hand}, a)
	assert_bool(bool(hidden[0]["card"].get("hidden", false))).is_true()
	assert_bool(hidden[0]["card"].has("name") or hidden[0]["card"].has("id")).is_false()
	var face_down := MatchView.event_cards(m, {"name": "destroyed", "self": opp_set}, a)
	assert_bool(face_down[0]["card"].has("name")).is_false()
	var own := MatchView.event_cards(m, {"name": "summon", "card": mine}, a)
	assert_str(String(own[0]["card"].get("name", ""))).is_equal(String(m.d(mine)["name"]))


func test_g03_hidden_mention_shows_a_back_and_no_name() -> void:
	var r := await _screen()
	var gs: GameScreen = r[0]
	var a: int = r[3]
	var pd := {"id": 880, "mine": true, "player": a, "kind": "trap_response", "prompt": "Respond to: a face-down card destroyed",
		"options": [{"i": 0, "label": "Pass (no Trap can respond)"}], "min": 1, "max": 1, "cancellable": false,
		"mentions": [{"role": "destroyed", "card": {"hidden": true, "zone": "backrow", "slot": 1, "ctl": 1 - a}}]}
	await _render(gs, pd)
	var figs := _figures(gs)
	assert_int(figs.size()).is_equal(1)
	assert_bool(bool(_widget_in(figs[0]).view.get("hidden", false))).is_true()
	var names := []
	for n in figs[0].get_children():
		if n is Label:
			names.append((n as Label).text)
	assert_array(names).contains(["Face-down card"])
	assert_array(_list_texts(gs)).is_equal(["Pass (no Trap can respond)"])


func test_g03_yes_no_prompt_stacks_yes_above_no_and_shows_the_source() -> void:
	var r := await _screen()
	var gs: GameScreen = r[0]
	var m: MatchEngine = r[2]
	var a: int = r[3]
	var src := TB.unit(m, a, 12, 0, "atk")
	r[1].broadcast()
	await await_idle_frame()
	var pd := {"id": 881, "mine": true, "player": a, "kind": "confirm", "prompt": "Draw a card and gain +1 AP?",
		"options": [{"i": 0, "label": "Yes"}, {"i": 1, "label": "No"}], "min": 1, "max": 1, "cancellable": false, "source_uid": src}
	await _render(gs, pd)
	assert_array(_list_texts(gs)).is_equal(["Yes", "No"])
	assert_bool(gs.prompt.subject_box.visible or gs.prompt._in_top_strip).is_true()
	assert_int(int(gs.prompt.subject_for(pd).get("uid", -1))).is_equal(src)
	assert_bool(gs.prompt.mention_box.visible).is_false()
	# A Skip option of a pick prompt comes after Confirm.
	pd = {"id": 882, "mine": true, "player": a, "kind": "mode", "prompt": "Pick one.",
		"options": [{"i": 0, "label": "Skip"}, {"i": 1, "label": "Gain 1 AP"}], "min": 1, "max": 1, "cancellable": false}
	await _render(gs, pd)
	assert_array(_list_texts(gs)).is_equal(["Gain 1 AP", "Skip"])


func test_g03_subject_falls_back_to_the_source_card_of_the_view() -> void:
	var r := await _screen()
	var gs: GameScreen = r[0]
	var a: int = r[3]
	var cv := MatchView.def_view(82)
	cv["uid"] = 4242
	cv["zone"] = "limbo"
	var pd := {"id": 883, "mine": true, "player": a, "kind": "select", "prompt": "Choose a unit.", "options": [], "min": 1, "max": 1,
		"cancellable": false, "source_uid": 4242, "source_card": cv}
	assert_int(int(gs.prompt.subject_for(pd).get("uid", -1))).is_equal(4242)
	pd["source_card"] = {"hidden": true, "zone": "hand"}
	assert_dict(gs.prompt.subject_for(pd)).is_empty()


# ---------------------------------------------------------------- G04

func test_g04_exact_payment_has_no_status_line_and_a_smaller_headline() -> void:
	var r := await _screen()
	var gs: GameScreen = r[0]
	gs.multi = []
	await _render(gs, _material_pd(3, [1, 2, 2]))
	assert_bool(gs.prompt.cost_pips.visible).is_true()
	assert_bool(gs.prompt.banner_sub.visible).is_false()
	assert_str(gs.prompt.cost_pips.tooltip_text).contains("Pay exactly 3")
	var px := gs.prompt.banner_title.get_theme_font_size("font_size")
	assert_bool(px == GamePromptBanner.HEADLINE_PAY_PX or px == GamePromptBanner.HEADLINE_PAY_NARROW_PX).is_true()
	gs.selection.pick_option(1)
	gs.prompt.prompt_sig = 0
	gs.prompt.render()
	assert_bool(gs.prompt.banner_sub.visible).is_false()
	assert_str(gs.prompt.cost_pips.tooltip_text).contains("2 of 3 paid")
	gs.multi = []
	# Any other multi-choice keeps its status line and the regular headline.
	var pd := _material_pd(3, [1, 2, 2])
	pd.erase("total_required")
	pd["total_exact"] = false
	pd["min_total"] = 0
	await _render(gs, pd)
	assert_bool(gs.prompt.cost_pips.visible).is_false()
	assert_bool(gs.prompt.banner_sub.visible).is_true()
	var px2 := gs.prompt.banner_title.get_theme_font_size("font_size")
	assert_bool(px2 == GamePromptBanner.HEADLINE_PX or px2 == GamePromptBanner.HEADLINE_NARROW_PX).is_true()
