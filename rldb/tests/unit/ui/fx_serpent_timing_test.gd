extends GdUnitTestSuite
## B5 (owner feedback 2026-10-20): a Divine Serpent whose On Summon destroys it in the same batch must be
## visibly summoned first and then destroyed. The summon and the destructions arrive in one view, so the
## final board already shows its slot empty: the arrival must play on a ghost of the card, and every
## destruction must wait until that arrival has landed. The Serpent effect plays its own set piece.

const SOUL := 160
const HEAD := 158
const BODY := 159


## The real event batch of the third Serpent's summon, read from the rules engine (viewer = the summoner).
func _serpent_batch() -> Array:
	var m := TB.make()
	TB.unit(m, 0, HEAD, 0)
	TB.unit(m, 0, BODY, 1)
	var since: int = int(m.log_entries[-1]["seq"])
	TB.summon(m, 0, SOUL, 4)
	var events := []
	for row in MatchView.log_for(m, 0, since):
		for f in row["fx"]:
			events.append(f)
	return events


func _screen() -> GameScreen:
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	return gs


func _first(plan: Array, prefix: String) -> Dictionary:
	for s in plan:
		if String(s["tag"]).begins_with(prefix):
			return s
	return {}


func test_summon_and_destroy_events_name_the_public_card() -> void:
	var ev := _serpent_batch()
	var summons := ev.filter(func(e): return e["k"] == "summon")
	var destroys := ev.filter(func(e): return e["k"] == "destroy")
	assert_int(summons.size()).is_equal(1)
	assert_int(int(summons[0].get("id", -1))).is_equal(SOUL)
	assert_int(destroys.size()).is_equal(3)
	for d in destroys:
		assert_bool(d.has("id")).is_true()   # face-up units are public: their identity may be shown


func test_summoned_serpent_is_shown_before_any_destruction() -> void:
	# Arrange: the board shows the final state (every Serpent gone), as the screen renders it
	var gs := _screen()
	await await_idle_frame()
	var ev := _serpent_batch()
	# Act
	gs.fx.play(ev, {})
	var plan: Array = gs.fx.last_plan
	# Assert: the Soul arrives on a ghost, and nothing destroys a Serpent until it has landed
	var arrive := _first(plan, "summon_ghost:0:4")
	assert_bool(arrive.is_empty()).is_false()
	var strike := _first(plan, "serpent")
	assert_bool(strike.is_empty()).is_false()
	assert_float(float(strike["t"])).is_greater_equal(float(arrive["t"]) + FxPlayer.TRANSIENT_HOLD - 0.001)
	for s in plan:
		if String(s["tag"]).begins_with("destroy"):
			assert_float(float(s["t"])).is_greater_equal(float(arrive["t"]) + FxPlayer.TRANSIENT_HOLD - 0.001)
	gs.fx.finish_all()


func test_summoned_serpent_ghost_is_visible_in_its_slot() -> void:
	var gs := _screen()
	await await_idle_frame()
	gs.fx.play(_serpent_batch(), {})
	await await_millis(int(FxPlayer.TRANSIENT_HOLD * 0.8 * 1000.0 * UIStyle.dur(1.0)) + 60)
	var slot_c := gs.fx_slot_global_rect(0, "unit", 4).get_center()
	var found := false
	for n in gs.fx_layer.get_children():
		if n is CardWidget and is_instance_valid(n) and int((n as CardWidget).view.get("id", -1)) == SOUL:
			if n.get_global_rect().get_center().distance_to(slot_c) < 40.0 and n.modulate.a > 0.5:
				found = true
	assert_bool(found).is_true()
	gs.fx.finish_all()
	# a click (finish_all) clears every ghost and hold
	await await_idle_frame()
	for n in gs.fx_layer.get_children():
		assert_bool(n is CardWidget and not n.is_queued_for_deletion()).is_false()
