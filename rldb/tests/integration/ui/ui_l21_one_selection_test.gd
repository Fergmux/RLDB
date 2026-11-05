extends GdUnitTestSuite
## L21 (owner feedback 2026-11-05) on the real GameScreen bound to a local host: only one thing is
## selected at a time. A click on a pile while a field (or Hand) card is selected deselects the card.
## The windowed run with screenshots is src/dev/l_interaction_shots.gd.

var host: LocalHost
var gs: GameScreen
var m: MatchEngine
var me: int


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	host = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 11, "best_of": 1, "deck_mode": "starter", "names": ["A", "B"], "mode": "bot"})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	m = host.series.game
	me = m.active
	gs = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	await gs.attach(host.seats[me])
	gs.skip_effects()
	await await_idle_frame()


func _pile(zone: String) -> PileStack:
	return gs.board.piles[1][zone]


func _field_widget(slot: int) -> CardWidget:
	return gs.board.slot_item(me, "unit", slot)["widget"]


func test_pile_click_deselects_the_selected_field_card() -> void:
	# Arrange: a unit on the field, click-selected.
	var u := TB.unit(m, me, TB.WATER, 0)
	host.broadcast()
	await await_idle_frame()
	gs.selection.on_widget_pressed(_field_widget(0))
	assert_int(gs.selected_uid).is_equal(u)
	# Act: click my Spent pile.
	_pile("spent").pressed.emit("spent")
	await await_idle_frame()
	# Assert: the pile is the one selection; the card lost its ring and action row.
	assert_str(gs.details.pile_zone).is_equal("spent")
	assert_int(gs.selected_uid).is_equal(-1)
	assert_bool(gs.row_open).is_false()
	assert_object(gs.action_row.stack).is_null()


func test_pile_click_deselects_the_selected_hand_card() -> void:
	# Arrange: a hand card, click-selected.
	var uid: int = gs.hand.order[0]
	gs.selection.select(uid)
	assert_int(gs.selected_uid).is_equal(uid)
	# Act
	_pile("draw").pressed.emit("draw")
	await await_idle_frame()
	# Assert
	assert_str(gs.details.pile_zone).is_equal("draw")
	assert_int(gs.selected_uid).is_equal(-1)


func test_log_card_link_drops_the_selected_hand_card() -> void:
	# Arrange: a hand card, click-selected (it lifts while its action row is open).
	var uid: int = gs.hand.order[0]
	var w: CardWidget = gs.hand.items[uid]["widget"]
	gs.selection.select(uid)
	await get_tree().create_timer(0.35).timeout
	assert_float(w.lift_k).is_greater(1.2)
	# Act: open a card from the game log that is not in the match (its definition shows).
	gs.details.show_card_def(TB.FIRE)
	await get_tree().create_timer(0.35).timeout
	# Assert: one selection: the hand card dropped back to rest and lost its row.
	assert_int(gs.selected_uid).is_equal(-1)
	assert_object(gs.action_row.stack).is_null()
	assert_float(w.lift_k).is_equal_approx(1.0, 0.01)


func test_field_click_closes_an_open_pile() -> void:
	# Arrange: an open pile list.
	var u := TB.unit(m, me, TB.WATER, 0)
	host.broadcast()
	await await_idle_frame()
	_pile("spent").pressed.emit("spent")
	assert_str(gs.details.pile_zone).is_equal("spent")
	# Act: click a field card.
	gs.selection.on_widget_pressed(_field_widget(0))
	await await_idle_frame()
	# Assert: the card is the one selection; the pile closed.
	assert_int(gs.selected_uid).is_equal(u)
	assert_str(gs.details.pile_zone).is_equal("")
	assert_bool(_pile("spent").selected).is_false()
