extends GdUnitTestSuite
## Owner feedback 22 Oct (design/owner-feedback-2026-10-22.md J9 J10 J13 J15), on the real GameScreen bound
## to a local host: the in-game menu order, the end of a game (no input once the kill is made, the kill plays
## out, nothing left over the rewards screen) and the rewards screen's full-window dim under the top strip.
## The windowed evidence run is src/dev/eog_shots.gd.

var host: LocalHost
var gs: GameScreen
var m: MatchEngine


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	host = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 11, "best_of": 3, "deck_mode": "starter", "names": ["A", "B"]})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	m = host.series.game
	gs = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	await gs.attach(host.seats[m.active])
	await await_idle_frame()


func after_test() -> void:
	StatusTip.hide_all()


## Visible in-game menu buttons, top to bottom, by key.
func _menu_order() -> Array:
	var out := []
	for c in (gs.menu.game_menu as HousePanel).body.get_children():
		if c is Button and (c as Button).visible:
			out.append(String(c.name).trim_prefix("Menu_"))
	return out


func test_j13_concede_game_comes_below_return_to_menu() -> void:
	# Arrange: a local player's menu (Settings, Return, Concede, Quit)
	gs.menu.refresh_items()
	# Act
	var order := _menu_order()
	# Assert
	assert_array(order).contains_exactly(["settings", "return", "concede", "quit"])


func test_menu_offers_no_concede_between_duels() -> void:
	# Arrange: the game has ended; the rewards screen is up
	host.handle(1 - m.active, {"t": "concede"})
	await await_idle_frame()
	gs.skip_effects()
	await await_idle_frame()
	# Act
	gs.menu.toggle()
	# Assert: nothing to concede between duels (the host would refuse it)
	assert_array(_menu_order()).contains_exactly(["settings", "return", "quit"])
	gs.menu.toggle()


## Turn 2's Battle Phase for the active seat `a`, shown on the screen: two ready attackers, the opponent on
## 5 HP with an empty field (any attack kills). Returns a.
func _kill_board() -> int:
	host.handle(m.active, {"t": "next_phase"})
	host.handle(m.active, {"t": "next_phase"})
	var a := m.active
	TB.unit(m, a, TB.FIRE, 0, "atk", 30, 30)
	TB.unit(m, a, TB.WATER, 1)
	TB.card(m, a, TB.WATER)
	m.players[1 - a]["hp"] = 5
	var guard := 0
	while String(m.phase) != "battle" and guard < 4:
		guard += 1
		host.handle(a, {"t": "next_phase"})
	host.broadcast()
	await gs.attach(host.seats[a])
	await await_idle_frame()
	return a


func _answer_all() -> void:
	var guard := 0
	while not m.pending.is_empty() and guard < 8:
		guard += 1
		host.handle(int(m.pending["player"]), {"t": "choose", "id": m.pending["id"], "indices": [0]})


func _push_click(at: Vector2) -> void:
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = at
		ev.global_position = at
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		gs.get_viewport().push_input(ev, true)
	await await_idle_frame()


func _push_key(k: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.pressed = down
		gs.get_viewport().push_input(ev, true)
	await await_idle_frame()


## Effective z_index of a canvas item (its own plus its relative parents').
static func _abs_z(n: CanvasItem) -> int:
	var z := 0
	var c: Node = n
	while c != null and c is CanvasItem:
		z += (c as CanvasItem).z_index
		if not (c as CanvasItem).z_as_relative:
			break
		c = c.get_parent()
	return z


func test_j9_input_after_the_killing_attack_sends_nothing_and_never_skips_the_kill() -> void:
	# Arrange: the killing direct attack has been made and its view has arrived
	var a := await _kill_board()
	host.handle(a, {"t": "attack", "uid": int(m.players[a]["units"][0])})
	_answer_all()
	await await_idle_frame()
	assert_int(m.winner).is_equal(a)
	assert_bool(gs.game_ending()).is_true()
	var sent := gs.debug_sent
	var other: CardWidget = gs.fx_slot_item(a, "unit", 1)["widget"]
	# Act: the player clicks the other attacker, a hand card and the table, and presses Tab / Enter / Esc
	await _push_click(gs.fx_slot_global_rect(a, "unit", 1).get_center())
	gs.selection.on_widget_pressed(other)
	var huid: int = gs.hand.order[0]
	await _push_click((gs.hand.items[huid]["holder"] as Control).get_global_rect().get_center())
	await _push_click(gs.play_area.get_center())
	for k in [KEY_TAB, KEY_ENTER, KEY_ESCAPE]:
		await _push_key(k)
	# Assert: nothing selected, opened or sent; the kill is still playing and the result still held back
	assert_int(gs.selected_uid).is_equal(-1)
	assert_object(gs.action_row.stack).is_null()
	assert_bool(gs.menu.game_menu.visible).is_false()
	assert_int(gs.debug_sent).is_equal(sent)
	assert_bool(gs.fx.busy()).is_true()
	assert_bool(gs.fx.game_end_hold).is_true()
	assert_bool(gs.overlays.overlay.visible).is_false()
	gs.skip_effects()


func test_j10_a_selected_card_and_a_status_tip_never_sit_over_the_rewards_screen() -> void:
	# Arrange: a hand card click-selected (lifted, its action row open) and a status tip showing
	var a := await _kill_board()
	var huid: int = gs.hand.order[0]
	gs.selection.select(huid)
	await await_idle_frame()
	var holder: Control = gs.hand.items[huid]["holder"]
	assert_int(holder.z_index).is_equal(UiLayers.LIFTED_CARD)
	var w: CardWidget = gs.fx_slot_item(a, "unit", 1)["widget"]
	StatusTip.show_for(w, "Poison ×2", w.get_global_rect())
	# Act: the opponent concedes; the end presentation runs to the rewards screen
	host.handle(1 - a, {"t": "concede"})
	await await_idle_frame()
	gs.skip_effects()
	await await_idle_frame()
	# Assert: the modal is up, the selection and tip are gone, and the modal draws above every board layer
	assert_bool(gs.overlays.overlay.visible).is_true()
	assert_int(gs.selected_uid).is_equal(-1)
	assert_str(StatusTip.shown_text()).is_empty()
	var modal_z := _abs_z(gs.overlays.overlay)
	assert_int(_abs_z(gs.overlays.overlay_dim)).is_equal(modal_z)
	for layer in [gs.arrow, gs.fx_layer, gs.hand.layer, gs.board.layer]:
		assert_int(_abs_z(layer) + UiLayers.LIFTED_CARD).is_less(modal_z)
	assert_int(_abs_z(gs.hover_layer)).is_less(modal_z)


func test_j15_the_rewards_dim_fills_the_window_under_the_top_strip_buttons() -> void:
	# Arrange
	var a := await _kill_board()
	# Act: the game ends; the rewards screen opens
	host.handle(1 - a, {"t": "concede"})
	await await_idle_frame()
	gs.skip_effects()
	await await_idle_frame()
	# Assert: the dim covers the whole window, the Menu button stays at the top above it and takes clicks
	var dim := gs.overlays.overlay_dim
	assert_bool(dim.visible).is_true()
	assert_vector(dim.get_global_rect().position).is_equal(gs.get_global_rect().position)
	assert_vector(dim.size).is_equal(gs.size)
	var mb := gs.menu.menu_button
	assert_float(mb.get_global_rect().position.y).is_less(GameScreen.TOP_H)
	assert_int(_abs_z(mb)).is_greater(_abs_z(dim))
	var at := mb.get_global_rect().get_center()
	assert_bool(dim._has_point(dim.get_global_transform().affine_inverse() * at)).is_false()
	assert_bool(dim._has_point(dim.get_global_transform().affine_inverse() * gs.play_area.get_center())).is_true()
	assert_bool(dim._has_point(dim.get_global_transform().affine_inverse() * Vector2(gs.size.x - 20.0, gs.size.y / 2.0))).is_true()   # the sidebar too
	# Back in a game the strip returns to its in-game layer
	gs.menu.raise_top_strip(false)
	assert_int(gs.menu.top_strip.z_index).is_equal(UiLayers.TOP_STRIP)


func test_popovers_over_the_rewards_screen_take_their_own_clicks() -> void:
	# Arrange: the rewards screen is up and the chat popover is open over it (as online)
	var a := await _kill_board()
	host.handle(1 - a, {"t": "concede"})
	await await_idle_frame()
	gs.skip_effects()
	await await_idle_frame()
	var panel: Control = gs.chat.panel
	panel.visible = true
	panel.position = Vector2(400, 300)
	panel.reset_size()
	await await_idle_frame()
	var hit := [0]
	var probe := Button.new()
	probe.text = "probe"
	probe.custom_minimum_size = Vector2(80, 30)
	probe.pressed.connect(func(): hit[0] += 1)
	(panel as HousePanel).body.add_child(probe)
	await await_idle_frame()
	# Act: a click on a button inside the popover (drawn above the modal, built before it)
	await _push_click(probe.get_global_rect().get_center())
	# Assert: the popover's button got it, not the modal or its dim under it
	assert_int(hit[0]).is_equal(1)
	panel.visible = false


func test_j15_deck_choice_dim_reaches_the_top_but_leaves_the_sidebar_live() -> void:
	# Arrange: a new series on its deck choice (the draft's "Your draft" list lives in the sidebar)
	var h2: LocalHost = auto_free(LocalHost.new())
	add_child(h2)
	h2.start({"seed": 5, "best_of": 3, "deck_mode": "draft", "names": ["A", "B"]})
	var g2: GameScreen = auto_free(GameScreen.new())
	g2.size = Vector2(1600, 1000)
	add_child(g2)
	# Act
	await g2.attach(h2.seats[0])
	await await_idle_frame()
	# Assert
	var dim := g2.overlays.overlay_dim
	assert_bool(dim.visible).is_true()
	assert_float(dim.position.y).is_equal(0.0)
	assert_float(dim.size.x).is_equal_approx(g2.size.x - g2.sidebar_w, 0.5)
