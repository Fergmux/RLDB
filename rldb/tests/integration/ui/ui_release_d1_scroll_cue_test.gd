extends GdUnitTestSuite
## D1 (owner feedback 20 Oct 2026): the "Scroll for more" cue under the card details fades out when
## the panel is scrolled to the bottom and fades back in when scrolled up. It never pops.

var host: LocalHost
var gs: GameScreen
var m: MatchEngine


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	UIStyle.reduce_motion = false
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
	# Intent change (H1 #42): with no card the panel shows the illustrated empty state and no cue;
	# the forced overflow stands for a long card's details.
	gs.details._set_empty(false)
	gs.details.details_view.custom_minimum_size = Vector2(0, 2400)   # taller than the panel
	await await_millis(400)


func test_cue_is_shown_at_the_top_of_long_details() -> void:
	var cue: ScrollCue = gs.details.scroll_cue
	assert_bool(cue.shown).is_true()
	assert_float(cue.modulate.a).is_equal(1.0)


func test_cue_fades_out_at_the_bottom_instead_of_popping() -> void:
	var cue: ScrollCue = gs.details.scroll_cue
	var sc: ScrollContainer = gs.details.details_scroll
	sc.scroll_vertical = 100000
	await await_idle_frame()
	await await_idle_frame()
	assert_bool(cue.shown).is_false()
	assert_bool(cue.visible).is_true()           # still fading, not popped away
	assert_float(cue.modulate.a).is_between(0.0, 1.0)
	await await_millis(400)
	assert_bool(cue.visible).is_false()


func test_cue_comes_back_when_scrolled_up_again() -> void:
	var cue: ScrollCue = gs.details.scroll_cue
	var sc: ScrollContainer = gs.details.details_scroll
	sc.scroll_vertical = 100000
	await await_millis(400)
	sc.scroll_vertical = 0
	await await_millis(400)
	assert_bool(cue.shown).is_true()
	assert_bool(cue.visible).is_true()
	assert_float(cue.modulate.a).is_equal(1.0)


func test_pile_list_hides_the_details_cue() -> void:
	# The cue belongs to the card details: an open pile or draft list (the empty "Your draft (0)" list
	# showed it) never carries it, whatever the hidden details scroll would say.
	var cue: ScrollCue = gs.details.scroll_cue
	gs.details.show_pile("spent")
	await await_idle_frame()
	assert_bool(cue.shown).is_false()


func test_reduced_motion_changes_the_cue_at_once() -> void:
	UIStyle.reduce_motion = true
	var cue: ScrollCue = gs.details.scroll_cue
	gs.details.details_scroll.scroll_vertical = 100000
	await await_idle_frame()
	await await_idle_frame()
	assert_bool(cue.visible).is_false()
	UIStyle.reduce_motion = false
