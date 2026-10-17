extends GdUnitTestSuite
## Production batch 2026-10-17, match UI: F06 zone-choice hover, F08 exact Arcane payment,
## F10 reward click-to-take, F05 prompt card context and F04 Extra Deck summon buttons.


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


func _summonable(m: MatchEngine, p: int) -> int:
	for u in m.players[p]["hand"]:
		if m.is_unit(u) and m.validate(p, {"t": "summon", "uid": u}) == "":
			return u
	return -1


## A visible card view for option lists (definition view with a uid).
func _cv(id: int, uid: int, cost: int) -> Dictionary:
	var c := MatchView.def_view(id)
	c["uid"] = uid
	c["cost"] = cost
	c["zone"] = "spent"
	return c


func _material_pd(need: int, costs: Array) -> Dictionary:
	var opts := []
	for i in costs.size():
		opts.append({"i": i, "label": "M%d" % i, "value": costs[i], "card": _cv(13, 9000 + i, costs[i])})
	return {"id": 777, "mine": true, "player": 0, "kind": "select", "prompt": "Exhaust units from Spent whose current costs total exactly %d." % need,
		"options": opts, "min": 1, "max": opts.size(), "cancellable": true, "min_total": need, "total_required": need, "total_exact": true}


# ---------------------------------------------------------------- F08 rules of the picker

func test_exact_payment_counts_paid_and_remaining() -> void:
	var pd := _material_pd(5, [2, 3, 1, 4])
	var ep := GamePromptBanner.exact_payment(pd, [0])
	assert_int(ep["need"]).is_equal(5)
	assert_int(ep["paid"]).is_equal(2)
	assert_int(ep["remaining"]).is_equal(3)
	assert_dict(GamePromptBanner.exact_payment({"kind": "select", "options": []}, [0])).is_empty()


func test_zero_cost_and_over_total_materials_are_not_offered() -> void:
	var pd := _material_pd(4, [0, 2, 5, 4])
	var offered: Array = pd["options"].filter(func(o): return GamePromptBanner.payable_option(pd, o)).map(func(o): return int(o["i"]))
	assert_array(offered).is_equal([1, 3])


func test_options_that_would_overpay_are_refused_and_picks_stay_deselectable() -> void:
	var pd := _material_pd(5, [2, 3, 4, 1])
	assert_bool(GamePromptBanner.would_overpay(pd, [], 2)).is_false()      # 4 <= 5
	assert_bool(GamePromptBanner.would_overpay(pd, [0], 2)).is_true()      # 2 + 4 > 5
	assert_bool(GamePromptBanner.would_overpay(pd, [0], 1)).is_false()     # 2 + 3 = 5
	assert_bool(GamePromptBanner.would_overpay(pd, [0, 1], 0)).is_false()  # already picked
	assert_bool(GamePromptBanner.would_overpay(pd, [0, 1], 3)).is_true()   # nothing remains


func test_material_tray_marks_overpay_and_confirm_needs_the_exact_total() -> void:
	var r := await _screen()
	var gs: GameScreen = r[0]
	var pd := _material_pd(5, [2, 3, 4, 0, 6])
	gs.mv["pending"] = pd
	gs.multi = []
	gs.prompt.prompt_sig = 0
	gs.prompt.render()
	await await_idle_frame()
	assert_int(gs.prompt.tray_cards.size()).is_equal(3)          # 0-cost and 6-cost left out
	assert_bool(gs.prompt.cost_pips.visible).is_true()
	assert_int(gs.prompt.cost_pips.need).is_equal(5)
	gs.selection.pick_option(0)                                  # pays 2
	gs.prompt.prompt_sig = 0
	gs.prompt.render()
	var over := _tray_widget(gs, 9002)
	assert_bool(over.get_meta("overpay")).is_true()
	assert_str(over.tooltip_text).is_equal("Cannot overpay")
	gs.selection.pick_option(2)                                  # 4 would overpay: refused
	assert_array(gs.multi).is_equal([0])
	assert_bool(_confirm(gs).disabled).is_true()
	gs.selection.pick_option(1)                                  # 2 + 3 = 5
	gs.prompt.prompt_sig = 0
	gs.prompt.render()
	assert_array(gs.multi).is_equal([0, 1])
	assert_int(gs.prompt.cost_pips.paid()).is_equal(5)
	assert_bool(_confirm(gs).disabled).is_false()
	gs.selection.pick_option(1)                                  # deselect
	assert_array(gs.multi).is_equal([0])
	gs.multi = []


func _tray_widget(gs: GameScreen, uid: int) -> CardWidget:
	for w in _all(gs.prompt.tray_box):
		if w is CardWidget and int(w.view.get("uid", -1)) == uid:
			return w
	return null


func _confirm(gs: GameScreen) -> Button:
	for b in gs.prompt.banner_btns.get_children():
		if b is Button and b.text == "Confirm":
			return b
	return null


func _all(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


# ---------------------------------------------------------------- F06 hover during a zone choice

func test_field_cards_do_not_hover_while_choosing_a_zone_and_hover_returns_after() -> void:
	var r := await _screen()
	var gs: GameScreen = r[0]
	var host: LocalHost = r[1]
	var m: MatchEngine = r[2]
	var a: int = r[3]
	var fu := TB.unit(m, a, 13, 5, "atk")
	host.broadcast()
	await await_idle_frame()
	var it := gs.selection.item_for_uid(fu)
	assert_bool(it.is_empty()).is_false()
	var at: Vector2 = (it["holder"] as Control).get_global_rect().get_center()
	gs.hover.update(at)
	assert_int(int(gs.hover.hv.get("uid", -1))).is_equal(fu)
	var hu := _summonable(m, a)
	assert_int(hu).is_not_equal(-1)
	host.handle(a, {"t": "summon", "uid": hu})
	await await_idle_frame()
	assert_str(String(m.pending.get("kind", ""))).is_equal("slot")
	assert_bool(gs.hover.zone_choice()).is_true()
	gs.hover.update(at)
	assert_bool(gs.hover.hv.is_empty()).is_true()                # the hovered field card dropped
	gs.hover.update(at)
	assert_bool(gs.hover.hv.is_empty()).is_true()                # and does not hover again
	host.handle(a, {"t": "cancel", "id": m.pending["id"]})
	await await_idle_frame()
	assert_bool(gs.hover.zone_choice()).is_false()
	gs.hover.update(at)
	assert_int(int(gs.hover.hv.get("uid", -1))).is_equal(fu)     # ordinary hover is back


# ---------------------------------------------------------------- F10 reward click-to-take

func test_offered_reward_card_click_takes_it_once() -> void:
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 900)
	add_child(gs)
	var rw := {"pending": true, "offer": [MatchView.def_view(13), MatchView.def_view(36)], "left": 3, "taken": []}
	gs.view = {"stage": "rewards", "rewards": rw}
	var sig := GameRewardPanels.offer_sig(rw)
	var before := gs.debug_sent
	assert_bool(gs.overlays.rewards.take_offer(1, sig)).is_true()
	assert_bool(gs.overlays.rewards.take_offer(1, sig)).is_false()   # double click
	assert_bool(gs.overlays.rewards.take_offer(0, sig)).is_false()   # another card of the same offer
	assert_int(gs.debug_sent - before).is_equal(1)
	assert_bool(gs.overlays.rewards.take_offer(0, sig + 1)).is_false()   # a stale offer


# ---------------------------------------------------------------- F05 card context in the prompt

func test_zone_prompt_shows_the_card_being_summoned() -> void:
	var r := await _screen()
	var gs: GameScreen = r[0]
	var host: LocalHost = r[1]
	var m: MatchEngine = r[2]
	var a: int = r[3]
	var hu := _summonable(m, a)
	host.handle(a, {"t": "summon", "uid": hu})
	await await_idle_frame()
	assert_bool(gs.prompt.subject_box.visible).is_true()
	assert_str(gs.prompt.subject_name.text).is_equal(String(m.d(hu)["name"]))
	assert_int(int(gs.prompt.subject_card.view.get("uid", -1))).is_equal(hu)
	host.handle(a, {"t": "cancel", "id": m.pending["id"]})


func test_placement_prompt_names_the_fusion_unit_not_the_spell() -> void:
	var r := await _screen()
	var gs: GameScreen = r[0]
	var host: LocalHost = r[1]
	var m: MatchEngine = r[2]
	var a: int = r[3]
	var fu := TB.card(m, a, 93, "extra")
	var spell := TB.card(m, a, 82, "hand")
	host.broadcast()
	await await_idle_frame()
	var pd := {"id": 900, "mine": true, "player": a, "kind": "slot", "prompt": "Choose a zone for %s." % m.d(fu)["name"],
		"options": [{"i": 0, "label": "Front row, column 1", "slot": 0, "zone": "unit"}], "min": 1, "max": 1, "cancellable": true, "source_uid": spell}
	assert_int(int(gs.prompt.subject_for(pd).get("uid", -1))).is_equal(fu)


func test_trap_response_and_hidden_cards_show_no_card() -> void:
	var r := await _screen()
	var gs: GameScreen = r[0]
	var m: MatchEngine = r[2]
	var a: int = r[3]
	var hidden_opp := TB.card(m, 1 - a, 13, "hand")
	r[1].broadcast()
	await await_idle_frame()
	var trap := {"id": 901, "mine": true, "kind": "trap_response", "prompt": "Respond?", "options": [], "source_uid": hidden_opp}
	assert_dict(gs.prompt.subject_for(trap)).is_empty()
	var other := {"id": 902, "mine": true, "kind": "select", "prompt": "Choose a zone for %s." % m.d(hidden_opp)["name"], "options": [], "source_uid": hidden_opp}
	assert_dict(gs.prompt.subject_for(other)).is_empty()   # an opponent's Hand card is never shown


# ---------------------------------------------------------------- F04 Extra Deck summon buttons

func _extra_board() -> Array:
	var r := await _screen()
	var host: LocalHost = r[1]
	var m: MatchEngine = r[2]
	var a: int = r[3]
	TB.unit(m, a, 27, 0, "atk")          # Hydra (Dragon)
	TB.unit(m, a, 28, 1, "atk")          # Guardian of the Forest (Beast)
	TB.unit(m, a, 40, 2, "atk")          # Aleister: Pay 1 AP: Fusion Summon (Field)
	var poly := TB.card(m, a, 82, "hand")
	var wyrm := TB.card(m, a, 93, "extra")        # Bastion Wyrm: Beast + Dragon
	var kaya := TB.card(m, a, 170, "extra")       # Arcane, cost 1
	var none := TB.card(m, a, 56, "extra")        # Razeon Storm: no materials on the field
	TB.card(m, a, 34, "spent")                    # a cost-1 material
	m.players[a]["ap"] = 2
	host.broadcast()
	await await_idle_frame()
	r.append_array([poly, wyrm, kaya, none])
	return r


func _summon_buttons(gs: GameScreen, uid: int) -> Array:
	var row := gs.details.pile_row(uid)
	if row == null:
		return []
	return _all(row).filter(func(n): return n is Button and n.has_meta("summon_kind"))


func test_extra_list_shows_summon_buttons_without_selection() -> void:
	var r := await _extra_board()
	var gs: GameScreen = r[0]
	gs.details.show_pile("extra")
	await await_idle_frame()
	var wy := _summon_buttons(gs, r[5])
	assert_array(wy.map(func(b): return String(b.get_meta("summon_kind")))).contains(["fusion"])
	var ka := _summon_buttons(gs, r[6])
	assert_bool(ka.any(func(b): return String(b.get_meta("summon_kind")) == "arcane")).is_true()
	assert_array(_summon_buttons(gs, r[7])).is_empty()          # nothing can summon it
	assert_bool(wy.all(func(b): return not b.disabled)).is_true()


func test_fusion_with_two_methods_asks_which_then_continues() -> void:
	var r := await _extra_board()
	var gs: GameScreen = r[0]
	var m: MatchEngine = r[2]
	var poly: int = r[4]
	var wyrm: int = r[5]
	assert_int(gs.details.fusion_methods_for(wyrm).size()).is_equal(2)
	gs.details.show_pile("extra")
	await await_idle_frame()
	var fb: Button = _summon_buttons(gs, wyrm).filter(func(b): return b.get_meta("summon_kind") == "fusion")[0]
	fb.pressed.emit()
	await await_idle_frame()
	assert_bool(gs.details.method_picker_open()).is_true()
	assert_bool(m.pending.is_empty()).is_true()                 # nothing sent, nothing chosen for them
	var poly_m: Dictionary = gs.details.fusion_methods_for(wyrm).filter(func(x): return int(x["via"]) == poly)[0]
	gs.details.run_fusion(wyrm, poly_m)
	for i in 4:
		await await_idle_frame()
	assert_bool(gs.details.method_picker_open()).is_false()
	assert_bool(m.pending.is_empty()).is_false()
	assert_str(String(m.pending["prompt"])).not_contains("Choose a Fusion unit")   # answered with the Wyrm
	assert_int(int(m.pending["player"])).is_equal(int(r[3]))


func test_method_picker_closes_on_cancel_and_when_the_state_changes() -> void:
	var r := await _extra_board()
	var gs: GameScreen = r[0]
	var host: LocalHost = r[1]
	var m: MatchEngine = r[2]
	var wyrm: int = r[5]
	gs.details.open_method_picker(wyrm)
	assert_bool(gs.selection.cancel()).is_true()
	assert_bool(gs.details.method_picker_open()).is_false()
	gs.details.show_pile("extra")
	gs.details.open_method_picker(wyrm)
	m.players[r[3]]["hand"].erase(r[4])       # Polymerization leaves the Hand: one method left
	m.players[r[3]]["spent"].append(r[4])
	m.cards[r[4]]["zone"] = "spent"
	host.broadcast()
	await await_idle_frame()
	assert_bool(gs.details.method_picker_open()).is_false()
