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
