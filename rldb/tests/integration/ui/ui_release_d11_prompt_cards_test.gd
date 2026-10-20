extends GdUnitTestSuite
## D11 (owner feedback 20 Oct 2026): cards shown in the left input pane carry the rich effect tooltip
## (not "Right-click to inspect") and are never drawn face down to their owner; an opponent's hidden
## card stays hidden.

var gs: GameScreen
var a: int


func before_test() -> void:
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
	gs = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 900)
	add_child(gs)
	await gs.attach(host.seats[m.active])
	await await_idle_frame()
	a = m.active


func _trap_view() -> Dictionary:
	var c := MatchView.def_view(46)         # Mirror Force: set by me, face down
	c["uid"] = 9001
	c["zone"] = "backrow"
	c["face_up"] = false
	c["set_by_you"] = true
	return c


func _render(pd: Dictionary) -> void:
	gs.mv["pending"] = pd
	gs.prompt.prompt_sig = 0
	gs.prompt.render()
	await await_idle_frame()


func _widgets(n: Node, out: Array) -> void:
	if n is CardWidget:
		out.append(n)
	for c in n.get_children():
		_widgets(c, out)


func test_pane_view_turns_my_face_down_card_face_up_but_not_a_hidden_one() -> void:
	assert_bool(bool(GamePromptBanner.pane_view(_trap_view())["face_up"])).is_true()
	var hidden := {"hidden": true, "zone": "backrow", "slot": 1, "ctl": 1 - a}
	assert_dict(GamePromptBanner.pane_view(hidden)).is_equal(hidden)
	assert_dict(GamePromptBanner.pane_view({})).is_empty()


func test_my_face_down_trap_response_card_shows_face_up_with_its_effect_tooltip() -> void:
	var pd := {"id": 890, "mine": true, "player": a, "kind": "trap_response", "prompt": "Respond to: an attack",
		"options": [{"i": 0, "label": "Pass"}], "min": 1, "max": 1, "cancellable": false,
		"mentions": [{"role": "response", "card": _trap_view()}]}
	await _render(pd)
	var ws := []
	_widgets(gs.prompt.respond_col, ws)
	assert_int(ws.size()).is_equal(1)
	var w: CardWidget = ws[0]
	assert_bool(bool(w.view["face_up"])).is_true()
	assert_str(w.tooltip_text).not_contains("Right-click")
	assert_str(w.tooltip_text).contains(String(_trap_view()["name"]))
	assert_str(w.tooltip_text).contains(CardWidget.card_text(_trap_view()).substr(0, 12))


func test_an_opponents_hidden_card_in_the_pane_stays_hidden() -> void:
	var pd := {"id": 891, "mine": true, "player": a, "kind": "trap_response", "prompt": "Respond to: a set Spell/Trap destroyed",
		"options": [{"i": 0, "label": "Pass (no Trap can respond)"}], "min": 1, "max": 1, "cancellable": false,
		"mentions": [{"role": "destroyed", "card": {"hidden": true, "zone": "backrow", "slot": 1, "ctl": 1 - a}}]}
	await _render(pd)
	var ws := []
	_widgets(gs.prompt.mention_row, ws)
	assert_int(ws.size()).is_equal(1)
	assert_bool((ws[0] as CardWidget).view.get("hidden", false)).is_true()
	assert_bool((ws[0] as CardWidget).view.has("face_up")).is_false()
