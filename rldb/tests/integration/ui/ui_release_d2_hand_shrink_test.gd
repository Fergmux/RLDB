extends GdUnitTestSuite
## D2 (owner feedback 20 Oct 2026): choosing to summon or set a hand card shrinks it back to its
## normal size straight away, so the 1.75x hover lift never covers the trap zones while a zone is
## picked. It also stays shrunk if the pointer is still over it during the zone choice.

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


func _summon_pending() -> int:
	var uid := TB.card(m, m.active, TB.WATER)
	m.players[m.active]["ap"] = 5
	host.broadcast()
	await await_idle_frame()
	gs.hover.debug_hover_hand(gs.hand.order.find(uid))
	gs.selection.select(uid)
	await await_millis(250)
	return uid


func _press_summon() -> void:
	var b: Button = gs.action_row.stack.get_children().filter(func(x): return (x as Button).text == "Summon Attack")[0]
	b.pressed.emit()
	await await_millis(250)


func test_hand_card_shrinks_at_once_when_summon_is_chosen() -> void:
	var uid := await _summon_pending()
	var w: CardWidget = gs.hand.items[uid]["widget"]
	assert_float(w.lift_k).is_greater(1.5)
	await _press_summon()
	assert_str(m.pending["kind"]).is_equal("slot")
	assert_dict(gs.hover.hv).is_empty()
	assert_float(w.lift_k).is_equal(1.0)


func test_summoned_card_does_not_lift_again_while_the_zone_is_chosen() -> void:
	var uid := await _summon_pending()
	var w: CardWidget = gs.hand.items[uid]["widget"]
	await _press_summon()
	var holder: Control = gs.hand.items[uid]["holder"]
	gs.hover.update(holder.get_global_rect().get_center())
	await await_millis(250)
	assert_dict(gs.hover.hv).is_empty()
	assert_float(w.lift_k).is_equal(1.0)
