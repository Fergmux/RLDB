extends GdUnitTestSuite
## Playtest feedback 02 interaction rules on the real GameScreen bound to a local host:
## hover is inspection only (no actions, nothing sent), click-selection opens the card's legal
## actions, locks hide them, and a pile choice is answered by clicking the card in the tray.
## The windowed run with pointer events is src/dev/f02_driver.gd (evidence in production/qa).

var host: LocalHost
var gs: GameScreen
var m: MatchEngine


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	host = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 11, "best_of": 1, "deck_mode": "starter", "names": ["A", "B"]})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	m = host.series.game
	gs = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	await gs.attach(host.seats[m.active])
	await await_idle_frame()


func _hand_unit() -> int:
	var uid := TB.card(m, m.active, TB.WATER)
	m.players[m.active]["ap"] = 5
	host.broadcast()
	return uid


func _row() -> Array:
	if gs._stack == null or not is_instance_valid(gs._stack):
		return []
	return gs._stack.get_children().map(func(b): return (b as Button).text)


func test_f02_01_hover_shows_details_but_no_actions_and_sends_nothing() -> void:
	var uid := _hand_unit()
	await await_idle_frame()
	var idx: int = gs._hand_order.find(uid)
	var log_n := m.log_entries.size()
	gs.debug_hover_hand(idx)
	await await_millis(300)
	assert_int(gs._details_uid()).is_equal(uid)
	assert_object(gs._stack).is_null()
	assert_int(gs.debug_sent).is_equal(0)
	assert_int(m.log_entries.size()).is_equal(log_n)
	gs.debug_clear_hover()


func test_f02_01_click_selects_and_reveals_summon_buttons() -> void:
	var uid := _hand_unit()
	await await_idle_frame()
	gs._on_widget_pressed(gs._hand_items[uid]["widget"])
	await await_idle_frame()
	assert_int(gs.selected_uid).is_equal(uid)
	assert_array(_row()).contains_exactly(["Summon Attack", "Summon Defense"])
	assert_int(gs.debug_sent).is_equal(0)
	gs._on_widget_pressed(gs._hand_items[uid]["widget"])      # second click deselects
	await await_idle_frame()
	assert_int(gs.selected_uid).is_equal(-1)
	assert_array(_row()).is_empty()


func test_f02_02_summon_defense_button_runs_stance_fixed_summon() -> void:
	var uid := _hand_unit()
	await await_idle_frame()
	gs._select(uid)
	await await_idle_frame()
	var b: Button = gs._stack.get_children().filter(func(x): return (x as Button).text == "Summon Defense")[0]
	b.pressed.emit()
	await await_idle_frame()
	assert_str(m.pending["kind"]).is_equal("slot")
	assert_bool(gs.ctx_banner.visible).is_true()
	TB.choose(m, [TB.slot_label(2)])
	host.broadcast()
	assert_str(m.cards[uid]["stance"]).is_equal("def")
	var w: CardWidget = gs.fx_slot_item(m.active, "unit", 2)["widget"]
	assert_bool(w.rotated).is_true()


func test_f02_01_selected_card_shows_no_actions_while_locked() -> void:
	var uid := _hand_unit()
	await await_idle_frame()
	gs._select(uid)
	await await_idle_frame()
	assert_array(_row()).is_not_empty()
	m.submit(m.active, {"t": "summon", "uid": uid, "stance": "atk"})   # a pending zone choice locks normal actions
	host.broadcast()
	await await_idle_frame()
	assert_array(_row()).is_empty()


func test_f02_10_pile_choice_is_answered_by_clicking_the_card_in_the_tray() -> void:
	var p := m.active
	for i in 2:
		TB.card(m, p, TB.WATER, "spent")
	var u := TB.card(m, p, 99)                                # On Summon: unit from Spent to Draw
	m.players[p]["ap"] = 5
	m.submit(p, {"t": "summon", "uid": u, "stance": "atk"})
	TB.choose(m, [TB.slot_label(0)])
	host.broadcast()
	await await_idle_frame()
	assert_bool(gs.tray.visible).is_true()
	var cards: Array = []
	for ch in gs.tray_box.get_children():
		if ch is HFlowContainer:
			cards = ch.get_children()
	assert_int(cards.size()).is_equal(2)
	for c in cards:
		assert_bool(c is CardWidget).is_true()             # no separate Choose buttons
	var picked: int = (cards[0] as CardWidget).view["uid"]
	(cards[0] as CardWidget).pressed.emit(cards[0])
	await await_idle_frame()
	assert_str(m.cards[picked]["zone"]).is_equal("draw")
	assert_bool(m.pending.is_empty()).is_true()


func test_f02_12_preview_text_names_values_and_hidden_risk() -> void:
	var pv := {"outcome": "win", "verdict": "good", "av": 14, "dv": 10, "adv": "attacker", "bonus": 6, "defending_atk": true,
		"t_dies": true, "a_dies": false, "dmg_opp": 4, "dmg_you": 0, "notes": [], "hidden_risk": true}
	var t := GameScreen.preview_text(pv, "Water", "Fire")
	assert_str(t).contains("Favourable").contains("14").contains("10").contains("Fire destroyed").contains("face-down")


# Regression: two Hand cards leaving in one update while one is hovered used to abort the
# hand render on a stale key (hover unlift walked the old order).
func test_hand_render_survives_two_cards_leaving_while_one_is_hovered() -> void:
	var p := m.active
	var u1 := TB.card(m, p, TB.WATER)
	var u2 := TB.card(m, p, TB.WATER)
	host.broadcast()
	await await_idle_frame()
	gs.debug_hover_hand(gs._hand_order.find(u2))
	for u in [u1, u2]:
		m.players[p]["hand"].erase(u)
		m.cards[u]["zone"] = "spent"
		m.players[p]["spent"].append(u)
	host.broadcast()
	await await_idle_frame()
	assert_array(gs._hand_order).is_equal(m.players[p]["hand"])
	assert_bool(gs._hand_items.has(u1) or gs._hand_items.has(u2)).is_false()
