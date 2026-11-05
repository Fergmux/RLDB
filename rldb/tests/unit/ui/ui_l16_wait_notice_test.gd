extends GdUnitTestSuite
## L16 (owner feedback 2026-11-05): the opponent-is-responding notice appears in the middle of the
## board, plays its cue, settles in its dock under the opponent's plate, never takes a click, and
## always clears. The phases are driven directly (no waiting on timers).

const CENTRE := Vector2(620, 420)
const DOCK := Vector2(1210, 160)   # top-right corner of the dock

var wn: WaitNotice
var cues: Array


func before_test() -> void:
	cues = []
	wn = auto_free(WaitNotice.new())
	wn.anchors = func() -> Array: return [CENTRE, DOCK]
	wn.play_cue = func() -> void: cues.append("opponent_responding")
	add_child(wn)


func test_it_is_click_through() -> void:
	assert_int(wn.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_show_waits_the_delay_before_it_appears() -> void:
	# Act
	wn.show_text("Ana is responding…", "They may answer with a Trap")
	# Assert: armed, not yet visible to the eye, no cue yet.
	assert_bool(wn.waiting()).is_true()
	assert_int(wn.phase).is_equal(WaitNotice.Phase.DELAY)
	assert_float(wn.modulate.a).is_equal_approx(0.0, 0.001)
	assert_array(cues).is_empty()
	assert_str(wn.label.base).is_equal("Ana is responding")
	assert_str(wn.sub.text).is_equal("They may answer with a Trap")


func test_it_appears_centred_on_the_board_with_its_cue() -> void:
	# Arrange
	wn.show_text("Ana is responding…")
	# Act
	wn._appear()
	wn._apply()
	# Assert
	assert_int(wn.phase).is_equal(WaitNotice.Phase.CENTRED)
	assert_array(cues).is_equal(["opponent_responding"])
	var c := wn.position + wn.size / 2.0
	assert_vector(c).is_equal_approx(CENTRE, Vector2(1, 1))


func test_it_settles_in_its_dock_smaller() -> void:
	# Arrange
	wn.show_text("Ana is responding…")
	wn._appear()
	# Act: the glide's end state.
	wn._settle()
	wn.dock_k = 1.0
	wn.pop = 1.0
	wn._apply()
	# Assert: right edge on the dock's, top under it, at the dock scale.
	var r := Rect2(wn.position + wn.size / 2.0 - wn.size * WaitNotice.DOCK_SCALE / 2.0, wn.size * WaitNotice.DOCK_SCALE)
	assert_float(r.end.x).is_equal_approx(DOCK.x, 1.0)
	assert_float(r.position.y).is_equal_approx(DOCK.y, 1.0)
	assert_float(wn.scale.x).is_equal_approx(WaitNotice.DOCK_SCALE, 0.001)


func test_place_at_blends_centre_and_dock() -> void:
	var sz := Vector2(300, 70)
	assert_vector(WaitNotice.place_at(CENTRE, DOCK, sz, 0.0, 1.0)).is_equal(CENTRE - sz / 2.0)
	var docked := WaitNotice.place_at(CENTRE, DOCK, sz, 1.0, 0.5)
	assert_vector(docked + sz / 2.0).is_equal(DOCK + Vector2(-75, 17.5))


func test_empty_text_before_it_appeared_hides_at_once() -> void:
	wn.show_text("Ana is choosing…")
	wn.show_text("")
	assert_bool(wn.visible).is_false()
	assert_int(wn.phase).is_equal(WaitNotice.Phase.HIDDEN)
	assert_array(cues).is_empty()


func test_empty_text_after_it_appeared_leaves() -> void:
	wn.show_text("Ana is choosing…")
	wn._appear()
	wn.show_text("")
	assert_int(wn.phase).is_equal(WaitNotice.Phase.LEAVING)
	assert_bool(wn.waiting()).is_false()


func test_it_clears_itself_when_no_longer_wanted() -> void:
	# Arrange: shown, then its prompt goes away without an explicit hide (a game that ended).
	var want := [true]
	wn.wanted = func() -> bool: return want[0]
	wn.show_text("Ana is responding…")
	want[0] = false
	# Act
	wn._process(0.016)
	# Assert
	assert_bool(wn.waiting()).is_false()
	assert_bool(wn.visible).is_false()


func test_a_new_text_while_shown_does_not_replay_the_cue() -> void:
	wn.show_text("Ana is responding…")
	wn._appear()
	wn.show_text("Ana is choosing…")
	assert_array(cues).is_equal(["opponent_responding"])
	assert_str(wn.label.base).is_equal("Ana is choosing")
	assert_int(wn.phase).is_equal(WaitNotice.Phase.CENTRED)
