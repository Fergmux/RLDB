extends GdUnitTestSuite
## Final review #10 (design/review-final-2026-11-05.md): the Evolve prompt's two forms were ~40 px
## thumbnails, too small to read. The side-column prompt now lists them as readable rows (card,
## name, kind and stats) joined by an Evolve arrow; hovering the strip opens a large side-by-side
## comparison beside the panel, and a left click on a form opens its inspector.

const SPAWN := 155
const LARVA := 156

var gs: GameScreen
var a: int


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	CardInspector.close_all()
	var host: LocalHost = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 11, "best_of": 1, "deck_mode": "starter", "names": ["A", "B"]})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	var m: MatchEngine = host.series.game
	while m.turn < 2 or m.phase != "main1":
		m.submit(m.active, {"t": "next_phase"})
	host.broadcast()
	gs = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	await gs.attach(host.seats[m.active])
	await await_idle_frame()
	a = m.active


func after_test() -> void:
	CardInspector.close_all()


func _evolve_pd() -> Dictionary:
	var from := MatchView.def_view(SPAWN)
	from["uid"] = 9301
	from["zone"] = "units"
	from["slot"] = 1
	from["ctl"] = a
	from["owner"] = a
	return {"id": 930, "mine": true, "player": a, "kind": "evolve",
		"prompt": "Evolve Symbiote Spawn into Symbiote Larva?",
		"options": [{"i": 0, "label": MatchEngine.EVOLVE_YES}, {"i": 1, "label": MatchEngine.EVOLVE_SKIP}],
		"min": 1, "max": 1, "cancellable": false, "evolve_to": LARVA,
		"mentions": [{"role": "evolve_from", "card": from}, {"role": "evolve_to", "card": MatchView.def_view(LARVA)}]}


func _render(pd: Dictionary) -> void:
	gs.mv["pending"] = pd
	gs.prompt.prompt_sig = 0
	gs.prompt.render()
	for i in 8:
		await await_idle_frame()


func _widgets(n: Node, out: Array) -> void:
	if n is CardWidget:
		out.append(n)
	for c in n.get_children():
		_widgets(c, out)


func _rows() -> Array:
	return gs.prompt.respond_col.get_children().filter(func(n): return n.has_meta("evolve_row"))


func test_evolve_prompt_lists_both_forms_as_readable_rows() -> void:
	await _render(_evolve_pd())
	var rows := _rows()
	assert_int(rows.size()).is_equal(2)
	var ids := []
	for r in rows:
		var ws := []
		_widgets(r, ws)
		assert_int(ws.size()).is_equal(1)
		var w: CardWidget = ws[0]
		ids.append(int(w.view["id"]))
		# Larger than the old ~40 px thumbnails.
		assert_float(w.size.x).is_greater_equal(GamePromptBanner.EVOLVE_ROW_CARD_MIN.x)
		var nm: Label = (r as Node).find_children("*", "Label", true, false).filter(func(l): return l.has_meta("ename"))[0]
		assert_bool(nm.is_visible_in_tree()).is_true()
		assert_int(nm.get_theme_font_size("font_size")).is_greater_equal(GamePromptBanner.EVOLVE_NAME_MIN_PX)
		var st: Label = (r as Node).find_children("*", "Label", true, false).filter(func(l): return l.has_meta("estats"))[0]
		assert_str(st.text).contains("ATK")
	assert_array(ids).is_equal([SPAWN, LARVA])
	# An Evolve-coloured arrow joins the two rows, and the old thumbnail row is gone.
	assert_int(gs.prompt.respond_col.get_children().filter(func(n): return n.has_meta("evolve_arrow")).size()).is_equal(1)
	assert_bool(gs.prompt.mention_row.visible).is_false()
	# The rows stay inside the panel and the panel stays above my plate.
	var panel := gs.prompt.ctx_banner.get_global_rect()
	for r in rows:
		assert_bool(panel.encloses((r as Control).get_global_rect())).is_true()


func test_hovering_the_evolve_strip_shows_both_forms_large_beside_the_panel() -> void:
	await _render(_evolve_pd())
	var fly: EvolveCompare = gs.prompt.evolve_compare
	assert_bool(fly.armed()).is_true()
	assert_bool(fly.visible).is_false()
	fly.set_hover(true)
	for i in 4:
		await await_idle_frame()
	assert_bool(fly.visible).is_true()
	var ws := []
	_widgets(fly, ws)
	assert_int(ws.size()).is_equal(2)
	assert_int(int((ws[0] as CardWidget).view["id"])).is_equal(SPAWN)
	assert_int(int((ws[1] as CardWidget).view["id"])).is_equal(LARVA)
	for w in ws:
		assert_float((w as CardWidget).size.x).is_greater_equal(EvolveCompare.CARD.x)
	var r := fly.get_global_rect()
	assert_bool(r.intersects(gs.prompt.ctx_banner.get_global_rect())).is_false()
	assert_bool(Rect2(Vector2.ZERO, gs.size).encloses(r)).is_true()
	fly.set_hover(false)
	await get_tree().create_timer(0.5).timeout
	assert_bool(fly.visible).is_false()


func test_the_flyout_disarms_when_the_prompt_is_not_an_evolve() -> void:
	await _render(_evolve_pd())
	gs.prompt.evolve_compare.set_hover(true)
	var pd := {"id": 931, "mine": true, "player": a, "kind": "confirm", "prompt": "Really?",
		"options": [{"i": 0, "label": "Yes"}, {"i": 1, "label": "No"}], "min": 1, "max": 1, "cancellable": false}
	await _render(pd)
	assert_bool(gs.prompt.evolve_compare.armed()).is_false()
	assert_bool(gs.prompt.evolve_compare.visible).is_false()
	assert_int(_rows().size()).is_equal(0)


func test_clicking_a_form_opens_its_inspector() -> void:
	await _render(_evolve_pd())
	var ws := []
	_widgets(_rows()[1], ws)
	(ws[0] as CardWidget).pressed.emit(ws[0])
	await await_idle_frame()
	assert_int(CardInspector.open_count()).is_equal(1)
	assert_int(int(CardInspector.topmost().card()["id"])).is_equal(LARVA)


func test_flyout_goes_right_of_the_panel_and_flips_left_or_below_when_there_is_no_room() -> void:
	var bounds := Rect2(0, 0, 1600, 1000)
	var sz := Vector2(500, 380)
	# Room on the right: beside the panel, centred on the strip, inside the screen.
	var p := EvolveCompare.place(Rect2(24, 130, 196, 420), 300.0, sz, bounds)
	assert_float(p.x).is_equal(24 + 196 + EvolveCompare.GAP)
	assert_float(p.y).is_equal(300.0 - sz.y / 2.0)
	# Near the bottom: clamped up into the screen.
	p = EvolveCompare.place(Rect2(24, 600, 196, 380), 950.0, sz, bounds)
	assert_float(p.y + sz.y).is_less_equal(bounds.end.y - EvolveCompare.EDGE)
	# A panel on the right edge: the flyout goes to its left.
	p = EvolveCompare.place(Rect2(1300, 130, 280, 420), 300.0, sz, bounds)
	assert_float(p.x + sz.x).is_equal(1300 - EvolveCompare.GAP)
	# A wide top-strip panel with no room on either side: below it.
	p = EvolveCompare.place(Rect2(400, 10, 800, 120), 70.0, sz, Rect2(0, 0, 1300, 1000))
	assert_float(p.y).is_equal(130 + EvolveCompare.GAP)
