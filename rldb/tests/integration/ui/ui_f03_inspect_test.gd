extends GdUnitTestSuite
## F03-01 / F03-02 / F03-26 on the real GameScreen bound to a local host: right-click inspects
## (read-only, no selection / command / cancel), piles open in the browser, empty-space click
## dismisses the passive pile list. Windowed evidence: src/dev/f03_inspect_driver.gd.

var host: LocalHost
var gs: GameScreen
var m: MatchEngine
var me: int
var opp: int


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	host = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 11, "best_of": 1, "deck_mode": "starter", "names": ["A", "B"]})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	m = host.series.game
	me = m.active
	opp = 1 - me
	gs = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	await gs.attach(host.seats[me])
	await await_idle_frame()


func after_test() -> void:
	CardInspector.close_all()


func _click(ctl: Control, button: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	ev.position = ctl.size / 2.0
	ctl.gui_input.emit(ev)      # what the engine does first
	ctl._gui_input(ev)


func _field_widget(p: int, slot: int) -> CardWidget:
	return gs.fx_slot_item(p, "unit", slot)["widget"]


func _unit_on_field() -> int:
	var uid := TB.unit(m, me, TB.WATER, 0)
	host.broadcast()
	return uid


func test_right_click_field_card_opens_inspector_without_side_effects() -> void:
	var uid := _unit_on_field()
	await await_idle_frame()
	var logn := m.log_entries.size()
	_click(_field_widget(me, 0), MOUSE_BUTTON_RIGHT)
	await await_idle_frame()
	var ins := CardInspector.topmost()
	assert_object(ins).is_not_null()
	assert_int(ins.card_uid()).is_equal(uid)
	assert_int(gs.selected_uid).is_equal(-1)
	assert_bool(gs.row_open).is_false()
	assert_int(gs.debug_sent).is_equal(0)
	assert_int(m.log_entries.size()).is_equal(logn)
	assert_bool(ins.details().all_text().contains("Basic Mage")).is_true()


func test_right_click_hand_card_opens_inspector_and_does_not_select() -> void:
	var uid := TB.card(m, me, TB.WATER)
	host.broadcast()
	await await_idle_frame()
	_click(gs.hand.items[uid]["widget"], MOUSE_BUTTON_RIGHT)
	assert_int(CardInspector.topmost().card_uid()).is_equal(uid)
	assert_int(gs.selected_uid).is_equal(-1)
	assert_int(gs.debug_sent).is_equal(0)


func test_right_click_does_not_deselect_or_cancel_a_selected_card() -> void:
	var uid := _unit_on_field()
	var other := TB.card(m, me, TB.WATER)
	host.broadcast()
	await await_idle_frame()
	gs.selection.select(uid)
	_click(gs.hand.items[other]["widget"], MOUSE_BUTTON_RIGHT)
	assert_int(gs.selected_uid).is_equal(uid)
	assert_object(CardInspector.topmost()).is_not_null()


func test_hidden_opposing_card_is_not_inspectable() -> void:
	TB.set_card(m, opp, 45, 0)          # face-down Trap
	host.broadcast()
	await await_idle_frame()
	var w: CardWidget = gs.fx_slot_item(opp, "backrow", 0)["widget"]
	assert_bool(w.view.get("hidden", false)).is_true()
	_click(w, MOUSE_BUTTON_RIGHT)
	assert_int(CardInspector.open_count()).is_equal(0)
	assert_bool(CardInspector.is_inspectable(w.view)).is_false()


func test_right_click_on_empty_zone_still_deselects() -> void:
	var uid := _unit_on_field()
	await await_idle_frame()
	gs.selection.select(uid)
	var empty: CardWidget = gs.fx_slot_item(me, "unit", 2)["bg"]
	_click(empty, MOUSE_BUTTON_RIGHT)
	assert_int(CardInspector.open_count()).is_equal(0)
	assert_int(gs.selected_uid).is_equal(-1)


func test_esc_closes_the_inspector_before_anything_else() -> void:
	var uid := _unit_on_field()
	await await_idle_frame()
	gs.selection.select(uid)
	_click(_field_widget(me, 0), MOUSE_BUTTON_RIGHT)
	assert_bool(gs.selection.cancel()).is_true()
	assert_int(CardInspector.open_count()).is_equal(0)
	assert_int(gs.selected_uid).is_equal(uid)       # the selection survived the first Esc


func test_inspector_closes_when_the_card_is_no_longer_visible() -> void:
	_unit_on_field()
	await await_idle_frame()
	_click(_field_widget(me, 0), MOUSE_BUTTON_RIGHT)
	CardInspector.refresh_open(func(_uid): return {})
	await await_idle_frame()
	assert_int(CardInspector.open_count()).is_equal(0)


func test_inspector_shows_the_updated_card_on_refresh() -> void:
	var uid := _unit_on_field()
	await await_idle_frame()
	_click(_field_widget(me, 0), MOUSE_BUTTON_RIGHT)
	var v: Dictionary = gs.details.find_card(uid).duplicate()
	v["statuses"] = {"burn": 2}
	CardInspector.refresh_open(func(_u): return v)
	assert_bool(CardInspector.topmost().details().all_text().contains("Burn ×2")).is_true()


func test_right_click_own_spent_pile_opens_browser_listing_it() -> void:
	for i in 3:
		TB.card(m, me, TB.WATER, "spent")
	host.broadcast()
	await await_idle_frame()
	var ps: PileStack = gs.board.piles[1]["spent"]
	_click(ps, MOUSE_BUTTON_RIGHT)
	await await_idle_frame()
	assert_object(gs.inspect.browser).is_not_null()
	assert_int(gs.inspect.browser.card_widgets().size()).is_equal(3)
	assert_int(gs.selected_uid).is_equal(-1)
	assert_int(gs.debug_sent).is_equal(0)


func test_left_click_on_pile_keeps_the_sidebar_list() -> void:
	TB.card(m, me, TB.WATER, "spent")
	host.broadcast()
	await await_idle_frame()
	_click(gs.board.piles[1]["spent"], MOUSE_BUTTON_LEFT)
	assert_str(gs.details.pile_zone).is_equal("spent")
	assert_bool(gs.inspect.browser == null).is_true()


func test_opponent_pile_has_no_browser() -> void:
	TB.card(m, opp, TB.WATER, "spent")
	host.broadcast()
	await await_idle_frame()
	_click(gs.board.piles[0]["spent"], MOUSE_BUTTON_RIGHT)
	assert_bool(gs.inspect.browser == null or not is_instance_valid(gs.inspect.browser)).is_true()


func test_empty_pile_opens_with_an_empty_state() -> void:
	await await_idle_frame()
	assert_bool(gs.inspect.open_pile("exhaust")).is_true()
	assert_int(gs.inspect.browser.card_widgets().size()).is_equal(0)


func test_draw_browser_lists_every_card_and_leaves_the_real_order() -> void:
	var before: Array = m.players[me]["draw"].duplicate()
	gs.inspect.open_pile("draw")
	assert_int(gs.inspect.browser.card_widgets().size()).is_equal(before.size())
	assert_array(m.players[me]["draw"]).is_equal(before)


func test_closing_a_card_from_the_browser_returns_to_it_with_the_same_scroll() -> void:
	for i in 40:
		TB.card(m, me, TB.WATER, "spent")
	host.broadcast()
	await await_idle_frame()
	gs.inspect.open_pile("spent")
	var b: PileBrowser = gs.inspect.browser
	await await_idle_frame()
	await await_idle_frame()
	b._scroll.scroll_vertical = 300
	await await_idle_frame()
	var pos := b.scroll_position()
	assert_int(pos).is_greater(0)
	_click(b.card_widgets()[5], MOUSE_BUTTON_RIGHT)
	assert_int(CardInspector.open_count()).is_equal(1)
	assert_int(gs.selected_uid).is_equal(-1)
	CardInspector.close_topmost()
	await await_idle_frame()
	assert_bool(is_instance_valid(b) and not b.is_queued_for_deletion()).is_true()
	assert_int(b.scroll_position()).is_equal(pos)
	assert_int(m.players[me]["spent"].size()).is_equal(40)


func test_esc_closes_the_card_then_the_browser() -> void:
	TB.card(m, me, TB.WATER, "spent")
	host.broadcast()
	await await_idle_frame()
	gs.inspect.open_pile("spent")
	var b: PileBrowser = gs.inspect.browser
	_click(b.card_widgets()[0], MOUSE_BUTTON_RIGHT)
	assert_bool(gs.selection.cancel()).is_true()
	assert_int(CardInspector.open_count()).is_equal(0)
	assert_bool(b.is_queued_for_deletion()).is_false()
	assert_bool(gs.selection.cancel()).is_true()
	assert_bool(b.is_queued_for_deletion()).is_true()


func test_open_browser_blocks_board_hover() -> void:
	gs.inspect.open_pile("spent")
	assert_bool(gs.hover_blocked()).is_true()


func test_empty_space_click_closes_the_pile_list_and_sends_nothing() -> void:
	TB.card(m, me, TB.WATER, "spent")
	host.broadcast()
	await await_idle_frame()
	gs.details.show_pile("spent")
	assert_str(gs.details.pile_zone).is_equal("spent")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	gs._gui_input(ev)
	assert_str(gs.details.pile_zone).is_equal("")
	assert_int(gs.debug_sent).is_equal(0)


func test_empty_space_click_does_not_cancel_a_pending_choice() -> void:
	var u := TB.card(m, me, TB.WATER)
	m.players[me]["ap"] = 5
	m.submit(me, {"t": "summon", "uid": u, "stance": "atk"})     # asks for a zone: mandatory choice
	host.broadcast()
	await await_idle_frame()
	var pid: int = m.pending["id"]
	gs.details.show_pile("spent")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	gs._gui_input(ev)
	assert_str(gs.details.pile_zone).is_equal("")
	assert_bool(m.pending.is_empty()).is_false()
	assert_int(m.pending["id"]).is_equal(pid)
	assert_int(gs.debug_sent).is_equal(0)


func test_log_card_viewer_is_dismissed_by_empty_space() -> void:
	gs.details.show_card_def(1)
	assert_bool(gs.details.log_card.is_empty()).is_false()
	assert_bool(gs.details.dismiss_passive()).is_true()
	assert_bool(gs.details.log_card.is_empty()).is_true()


func test_best_layout_fills_space_with_large_cards_and_no_scroll_when_it_fits() -> void:
	var lay := PileBrowser.best_layout(3, Vector2(1400, 700), 170.0, 300.0, 14.0)
	assert_bool(lay["scroll"]).is_false()
	assert_float(lay["w"]).is_greater_equal(170.0)
	assert_int(lay["cols"]).is_greater_equal(1)


func test_best_layout_scrolls_a_large_pile_at_readable_size() -> void:
	var lay := PileBrowser.best_layout(60, Vector2(1400, 700), 170.0, 300.0, 14.0)
	assert_bool(lay["scroll"]).is_true()
	assert_float(lay["w"]).is_greater_equal(170.0)
	assert_float(lay["w"] * lay["cols"] + 14.0 * (lay["cols"] - 1)).is_less_equal(1400.0)


func test_inspector_refuses_empty_and_hidden_views() -> void:
	assert_object(CardInspector.open(gs, {})).is_null()
	assert_object(CardInspector.open(gs, {"hidden": true, "zone": "backrow"})).is_null()


## Owner feedback 2026-10-18: the pile list is held like a selected card. No Close button; the
## pile shows the selected brackets; an empty-space click closes it and drops the brackets.
## J4 (owner, 22 Oct): hovering a card no longer shows its details over the list.
func test_open_pile_is_selected_hover_keeps_it_and_empty_space_closes_it() -> void:
	TB.card(m, me, TB.WATER, "spent")
	var u := _unit_on_field()
	await await_idle_frame()
	gs.details.show_pile("spent")
	var ps: PileStack = gs.board.piles[1]["spent"]
	assert_bool(ps.selected).is_true()
	assert_bool(gs.details.pile_scroll.visible).is_true()
	var buttons := gs.details.pile_head.find_children("*", "Button", true, false)
	assert_array(buttons).is_empty()
	gs.hover.debug_hover_slot(me, "unit", 0)
	assert_bool(gs.details.pile_scroll.visible).is_true()
	assert_bool(gs.details.details_scroll.visible).is_false()
	assert_int(gs.details.details_uid()).is_not_equal(u)
	gs.hover.debug_clear()
	assert_bool(gs.details.pile_scroll.visible).is_true()
	assert_str(gs.details.pile_zone).is_equal("spent")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	gs._gui_input(ev)
	assert_str(gs.details.pile_zone).is_equal("")
	assert_bool(ps.selected).is_false()
