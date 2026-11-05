extends GdUnitTestSuite
## H1 WP-6 board surfaces (design/design-review-2026-10-20.md #22-#48, #109; D10): the pure rules behind
## the inlaid zones, the pile medallions, the ready badge, the phase track, the log's arrival motion and
## adaptive height, and the wait notice.

var _rm := false


func before_test() -> void:
	_rm = UIStyle.reduce_motion


func after_test() -> void:
	UIStyle.reduce_motion = _rm


func test_engraved_zone_mark_alpha_is_subtle_d10() -> void:
	# D10 follow-up: the mark is a faint engraving (0.08-0.10), smaller than the old 0.25 x size.
	assert_float(CardLayouts.MARK_A).is_between(0.08, 0.10)
	assert_float(CardLayouts.MARK_K).is_less(0.25)


func test_zone_tint_alpha_is_thin_over_the_wood() -> void:
	# #22: the tint is laid thinly (it was 0.62 alpha, reading as a flat panel over the table).
	assert_float(CardLayouts.ZONE_FILL_A).is_less_equal(0.35)


func test_ready_badge_sits_inside_the_card_top_border() -> void:
	# #25: an 18 px badge whose top pokes at most a few px above the card (it used to overlap the zone
	# above by about 8 px).
	var card := Rect2(10, 100, 85, 128)
	var r := CardOverlays.ready_badge_radius(1.0)
	var c := CardOverlays.ready_badge_center(card, 1.0)
	assert_float(r * 2.0).is_equal_approx(18.0, 0.01)
	assert_float(card.position.y - (c.y - r)).is_less_equal(6.0)
	assert_float(c.y).is_greater(card.position.y)


func test_phase_track_states_follow_the_current_phase() -> void:
	assert_str(PhasePips.state_of(0, "battle")).is_equal("done")
	assert_str(PhasePips.state_of(1, "battle")).is_equal("current")
	assert_str(PhasePips.state_of(2, "battle")).is_equal("next")
	assert_str(PhasePips.state_of(0, "")).is_equal("next")
	assert_int(PhasePips.index_of("main2")).is_equal(2)
	assert_int(PhasePips.index_of("nope")).is_equal(-1)


func test_phase_change_without_motion_sets_no_travelling_light() -> void:
	UIStyle.reduce_motion = true
	var p: PhasePips = auto_free(PhasePips.new())
	p.phase = "main1"
	p.phase = "battle"
	assert_str(p.phase).is_equal("battle")
	assert_float(p._travel).is_less(0.0)


func test_log_arrival_curve_rises_then_rests() -> void:
	var start := LogFreshFx.state(0.0)
	assert_float(start.x).is_equal_approx(LogFreshFx.RISE_PX, 0.01)
	assert_float(start.y).is_equal_approx(0.0, 0.001)
	assert_float(start.z).is_equal_approx(LogFreshFx.GLOW_K, 0.001)
	var before := LogFreshFx.state(-0.2)
	assert_float(before.y).is_equal_approx(0.0, 0.001)
	var rest := LogFreshFx.state(LogFreshFx.GLOW_S)
	assert_vector(rest).is_equal(Vector3(0.0, 1.0, 0.0))
	var mid := LogFreshFx.state(LogFreshFx.RISE_S)
	assert_float(mid.y).is_equal_approx(1.0, 0.001)
	assert_float(mid.z).is_greater(0.0)


func test_log_takes_a_share_of_the_sidebar_with_a_floor() -> void:
	# #48 / H11: the short default is 22% of the sidebar's height, never under its floor.
	assert_float(GameSidebar.log_height(1000.0)).is_equal(220.0)
	assert_float(GameSidebar.log_height(500.0)).is_equal(GameSidebar.LOG_MIN_H)


func test_expanded_log_is_a_little_taller_than_the_old_size() -> void:
	# H11: the tall log is a little larger than the old 28% / 180 px share; the short one smaller.
	assert_float(GameSidebar.log_height(1000.0, true)).is_equal(340.0)
	assert_float(GameSidebar.log_height(1000.0, true)).is_greater(280.0)
	assert_float(GameSidebar.log_height(1000.0)).is_less(280.0)
	assert_float(GameSidebar.log_height(500.0, true)).is_equal(GameSidebar.LOG_MIN_TALL)
	assert_float(GameSidebar.LOG_MIN_TALL).is_greater(180.0)


func test_wait_notice_strips_its_static_dots() -> void:
	assert_str(WaitNotice.base_text("Ben is responding…")).is_equal("Ben is responding")
	assert_str(WaitNotice.base_text("Opponent is choosing...")).is_equal("Opponent is choosing")
	assert_str(WaitNotice.base_text("Waiting")).is_equal("Waiting")


func test_wait_notice_docks_under_the_opponent_plate() -> void:
	# #38 / L16: it settles under the plate (after appearing in the middle), right edges aligned.
	var plate: Control = auto_free(Control.new())
	plate.position = Vector2(1000, 50)
	plate.size = Vector2(228, 90)
	var dock := GamePromptBanner.wait_dock(plate)
	var pos := WaitNotice.place_at(Vector2(600, 400), dock, Vector2(200, 40), 1.0, 1.0)
	assert_float(pos.x + 200.0).is_equal_approx(1228.0, 0.01)
	assert_float(pos.y).is_greater(140.0)


func test_pile_count_jumps_without_motion() -> void:
	UIStyle.reduce_motion = true
	var ps: PileStack = auto_free(PileStack.new())
	ps.set_pile(7, false)
	assert_int(ps.displayed_count()).is_equal(7)
	ps.set_pile(3, true)
	assert_int(ps.displayed_count()).is_equal(3)


func test_empty_pile_outline_is_dashed_on_every_edge() -> void:
	var segs := PileStack.dashed_rect(Rect2(0, 0, 50, 30), 6.0, 4.0)
	# 50 px edges: 5 dashes each; 30 px edges: 3 each.
	assert_int(segs.size()).is_equal(16)
	for s in segs:
		assert_float((s[0] as Vector2).distance_to(s[1])).is_less_equal(6.0001)


func test_opponent_hand_chip_text_counts_cards() -> void:
	# #16: a count chip instead of the "OPPONENT HAND" caption.
	assert_str(GameBoardView.opp_hand_text(5, "Ben", false)).is_equal("5 cards")
	assert_str(GameBoardView.opp_hand_text(1, "Ben", false)).is_equal("1 card")
	assert_str(GameBoardView.opp_hand_text(4, "Ben", true)).is_equal("Ben's hand · 4")


func test_cta_cue_lights_only_when_nothing_is_left() -> void:
	# #41: stance changes and the phase button do not count as something left to do.
	assert_bool(GameSidebar.nothing_left([{"t": "next_phase", "ok": true}, {"t": "stance", "ok": true}])).is_true()
	assert_bool(GameSidebar.nothing_left([{"t": "summon", "ok": false}])).is_true()
	assert_bool(GameSidebar.nothing_left([{"t": "attack", "ok": true}])).is_false()


func test_cta_sweep_runs_once_per_period() -> void:
	assert_float(CtaCue.sweep_at(0.0)).is_equal_approx(0.0, 0.001)
	assert_float(CtaCue.sweep_at(CtaCue.PASS_S * 0.5)).is_equal_approx(0.5, 0.001)
	assert_float(CtaCue.sweep_at(CtaCue.PASS_S + 0.1)).is_equal(-1.0)
	assert_float(CtaCue.sweep_at(CtaCue.PERIOD + 0.1)).is_greater(0.0)


func test_side_panels_use_the_f2_frame() -> void:
	# #109: sidebar panels are FrameBox (gilded bevel, rivets), not the flat panel style.
	var p: PanelContainer = auto_free(GameUi.side_panel())
	assert_bool(p.get_theme_stylebox("panel") is FrameBox).is_true()
	assert_float(p.get_theme_stylebox("panel").content_margin_left).is_equal(float(UIStyle.sp("lg")))
