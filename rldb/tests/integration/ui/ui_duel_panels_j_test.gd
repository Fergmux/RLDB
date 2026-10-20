extends GdUnitTestSuite
## Owner feedback 22 Oct 2026 (design/owner-feedback-2026-10-22.md), the duel's right-hand panels:
## J7 the turn panel's title, J5 the overlaid scroll cue, J3 pile rows that open on click only and
## J4 card details that follow clicks, not hovers.

var host: LocalHost
var gs: GameScreen
var m: MatchEngine


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	UIStyle.reduce_motion = false
	host = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 11, "best_of": 1, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	m = host.series.game
	gs = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	await gs.attach(host.seats[m.active])
	await await_idle_frame()


func test_j7_turn_title_names_the_turn_only() -> void:
	# The player plates already mark whose turn it is; the name overlapped the clock.
	var title := gs.sidebar.turn_title.text
	assert_str(title).is_equal("Turn %d" % int(gs.mv["turn"]))
	assert_str(title).not_contains(String(gs.pv(int(gs.mv["active"]))["name"]))


## J5: long details (the forced overflow stands for a long card) with the cue at the top.
func _long_details() -> void:
	gs.details._set_empty(false)
	gs.details.details_view.custom_minimum_size = Vector2(0, 2400)
	await await_millis(400)


func test_j5_details_keep_their_size_when_the_scroll_cue_goes() -> void:
	# Arrange
	await _long_details()
	var sc: ScrollContainer = gs.details.details_scroll
	var cue: ScrollCue = gs.details.scroll_cue
	assert_bool(cue.visible).is_true()
	var rect_with_cue := _rect(sc)
	# Act: scrolled to the bottom, the cue fades out
	sc.scroll_vertical = 100000
	await await_millis(400)
	# Assert: the scroll area (and so its content) did not move or grow
	assert_bool(cue.visible).is_false()
	assert_vector(_rect(sc).position).is_equal(rect_with_cue.position)
	assert_vector(_rect(sc).size).is_equal(rect_with_cue.size)


func test_j5_scroll_cue_overlays_the_bottom_of_the_details() -> void:
	await _long_details()
	var sc: ScrollContainer = gs.details.details_scroll
	var cue: ScrollCue = gs.details.scroll_cue
	var r := _rect(cue)
	var area := _rect(sc)
	# Inside the scroll area, along its bottom edge, and clear of the scrollbar.
	assert_float(r.end.y).is_equal_approx(area.end.y, 0.5)
	assert_float(r.position.y).is_greater(area.position.y)
	assert_float(r.position.x).is_equal_approx(area.position.x, 0.5)
	var bar := sc.get_v_scroll_bar()
	assert_float(r.end.x).is_less_equal(_rect(bar).position.x + 0.5)


## The on-screen rect of `c` (the sidebar is scaled).
static func _rect(c: Control) -> Rect2:
	return c.get_global_transform() * Rect2(Vector2.ZERO, c.size)
