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
