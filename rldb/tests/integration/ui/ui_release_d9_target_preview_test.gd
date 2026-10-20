extends GdUnitTestSuite
## D9 (owner feedback 20 Oct 2026): hovering a field card's effect button previews the valid targets
## (invalid ones stay darkened, valid ones get a subtle border) and clears on hover end. The preview
## comes from the engine's own selector, so it matches the real prompt exactly.

const PIERCER := 15          # ability: Apply 1 Pierce to a unit

var host: LocalHost
var gs: GameScreen
var m: MatchEngine
var a: int
var mine: int
var their_unit: int


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	host = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 11, "best_of": 1, "deck_mode": "starter", "names": ["A", "B"]})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	m = host.series.game
	while m.turn < 2 or m.phase != "main1":
		m.submit(m.active, {"t": "next_phase"})
	a = m.active
	mine = TB.unit(m, a, PIERCER, 4, "atk")
	their_unit = TB.unit(m, 1 - a, TB.WATER, 0, "atk")
	host.broadcast()
	gs = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	await gs.attach(host.seats[a])
	await await_idle_frame()


func _ability_action() -> Dictionary:
	for x in gs.mv["actions"]:
		if x["t"] == "ability" and x["uid"] == mine:
			return x
	return {}


func _refs_key(refs: Array) -> Array:
	var out := refs.map(func(r): return "%d:%s:%d" % [int(r["p"]), r["zone"], int(r["slot"])])
	out.sort()
	return out


func test_ability_action_lists_the_zones_the_real_prompt_offers() -> void:
	var act := _ability_action()
	assert_bool(act.has("targets")).is_true()
	assert_int((act["targets"] as Array).size()).is_equal(2)
	# Run the ability: the options of the real prompt are exactly the previewed zones.
	assert_str(m.submit(a, {"t": "ability", "uid": mine, "idx": 0})).is_equal("")
	var real := []
	for o in MatchView.build(m, a)["pending"]["options"]:
		if o.has("ref"):
			real.append(o["ref"])
	assert_array(_refs_key(real)).is_equal(_refs_key(act["targets"]))


func test_actions_that_do_not_target_the_field_carry_no_targets() -> void:
	for x in gs.mv["actions"]:
		if x["t"] in ["attack", "stance", "sacrifice", "next_phase"]:
			assert_bool(x.has("targets")).is_false()


func test_hovering_the_effect_button_previews_targets_and_leaving_clears() -> void:
	gs.selection.select(mine)
	await await_idle_frame()
	var btn: Button = gs.action_row.stack.get_children().filter(func(b): return (b as Button).text == "Apply Pierce")[0]
	btn.mouse_entered.emit()
	await await_idle_frame()
	assert_int(gs.board.preview_refs.size()).is_equal(2)
	var hit: CardWidget = gs.fx_slot_item(1 - a, "unit", 0)["widget"]
	var other_mine: CardWidget = gs.fx_slot_item(a, "unit", 4)["widget"]
	assert_bool(hit.preview_target).is_true()
	assert_bool(other_mine.preview_target).is_true()
	assert_bool(hit.highlighted).is_false()          # not the full, animated targeting highlight
	# An empty zone is darkened; a card that is not a target would be too.
	var empty: CardWidget = gs.board.slots[GameBoardView.key(1, "unit", 0)]["bg"]
	assert_bool(empty.dimmed).is_true()
	btn.mouse_exited.emit()
	await await_idle_frame()
	assert_array(gs.board.preview_refs).is_empty()
	assert_bool(hit.preview_target).is_false()
	assert_bool(empty.dimmed).is_false()


func test_preview_clears_when_the_row_closes() -> void:
	gs.selection.select(mine)
	await await_idle_frame()
	var btn: Button = gs.action_row.stack.get_children().filter(func(b): return (b as Button).text == "Apply Pierce")[0]
	btn.mouse_entered.emit()
	await await_idle_frame()
	gs.action_row.clear()
	assert_array(gs.board.preview_refs).is_empty()
