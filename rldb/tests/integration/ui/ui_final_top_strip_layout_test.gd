extends GdUnitTestSuite
## Final L-batch review (design/review-final-2026-11-05.md, item d): the series scoreboard (top-centre
## strip), the opponent-responding notice, sacrifice mode's hint pill and the Menu / Chat buttons must
## never collide. The window stretches canvas items from 1600x1000 with "expand", so 1280x800 lays out
## as 1600x1000, and 1920x1080 and 3840x2160 as 1851x1000 (1280x720 as 1778x1000).
## Before the fix the hint pill sat under the scoreboard, in the same spot.

const DIR := "user://test_saves_final_top_strip"
## Logical screen sizes: 1280x800 / 1600x1000, 1280x720, 1920x1080 / 4K.
const SIZES := [Vector2(1600, 1000), Vector2(1778, 1000), Vector2(1851, 1000)]
## Long names at the scoreboard's NAME_MAX and the longest series (best of 5).
const NAMES := ["Maximiliana Thornwood", "Bartholomew Ashgrave"]


func before_test() -> void:
	SeriesStore.DIR = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	UIStyle.reduce_motion = true   # instant fades: the test reads the settled layout


func after_test() -> void:
	UIStyle.reduce_motion = false
	for fn in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, fn])


func _screen(sz: Vector2) -> GameScreen:
	var host: LocalHost = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 21, "best_of": 5, "deck_mode": "starter", "names": NAMES, "mode": "local"})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = sz
	add_child(gs)
	await gs.attach(host.seats[0])
	for i in 4:
		await await_idle_frame()
	gs.sidebar.update_scoreboard()
	await await_idle_frame()
	return gs


## Visible top-strip buttons (Menu, Chat, the spectator badge...).
func _buttons(gs: GameScreen) -> Array:
	var out := []
	for b in gs.menu.top_strip.find_children("*", "BaseButton", true, false):
		if (b as Control).is_visible_in_tree():
			out.append(b)
	return out


func _hint_rect(gs: GameScreen) -> Rect2:
	var v := gs.sacrifice.vignette
	return v.hint.get_global_rect()


func test_scoreboard_clears_the_top_strip_buttons_at_every_size() -> void:
	for sz in SIZES:
		var gs := await _screen(sz)
		var sb := gs.menu.scoreboard
		assert_bool(sb.visible).override_failure_message("scoreboard hidden at %s" % sz).is_true()
		for b in _buttons(gs):
			assert_bool(sb.get_global_rect().intersects((b as Control).get_global_rect())) \
				.override_failure_message("scoreboard hits %s at %s" % [b.name, sz]).is_false()
		gs.queue_free()
		await await_idle_frame()


func test_sacrifice_hint_is_never_under_the_scoreboard_or_a_button() -> void:
	for sz in SIZES:
		var gs := await _screen(sz)
		# Act: the mode's banner comes up (the same call start() makes).
		gs.sacrifice._show_vignette(true)
		await await_idle_frame()
		var hint := _hint_rect(gs)
		var sb := gs.menu.scoreboard
		# Assert: the scoreboard has stepped aside wherever the two meet, and no button is covered.
		if sb.get_global_rect().intersects(hint):
			assert_float(sb.modulate.a).override_failure_message("scoreboard covers the hint at %s" % sz).is_less(0.05)
			assert_int(sb.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		for b in _buttons(gs):
			assert_bool(hint.intersects((b as Control).get_global_rect())) \
				.override_failure_message("hint hits %s at %s" % [b.name, sz]).is_false()
		gs.queue_free()
		await await_idle_frame()


func test_scoreboard_returns_when_sacrifice_mode_ends() -> void:
	var gs := await _screen(SIZES[0])
	gs.sacrifice._show_vignette(true)
	await await_idle_frame()
	# Act
	gs.sacrifice._show_vignette(false)
	await await_idle_frame()
	# Assert
	assert_float(gs.menu.scoreboard.modulate.a).is_equal(1.0)
	assert_int(gs.menu.scoreboard.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)


func test_scoreboard_returns_when_the_mode_is_reset() -> void:
	var gs := await _screen(SIZES[0])
	gs.sacrifice.active = true
	gs.sacrifice._show_vignette(true)
	await await_idle_frame()
	# Act: a new seat or game on this screen resets the mode without its fade.
	gs.sacrifice.reset()
	# Assert
	assert_float(gs.menu.scoreboard.modulate.a).is_equal(1.0)


func test_wait_notice_clears_the_top_strip_centred_and_docked() -> void:
	for sz in SIZES:
		var gs := await _screen(sz)
		var wn := gs.prompt.wait_chip as WaitNotice
		wn.show_text("Opponent is responding…", "They may answer with a Trap")
		await await_idle_frame()
		var a: Array = gs.prompt.wait_anchors()
		var gt := gs.get_global_transform()
		var s := WaitNotice.DOCK_SCALE
		var centred := Rect2(gt * (Vector2(a[0]) - wn.size / 2.0), wn.size)
		var docked := Rect2(gt * (Vector2(a[1]) - Vector2(wn.size.x * s, 0.0)), wn.size * s)
		var top := Rect2(gt * Vector2.ZERO, Vector2(sz.x, GameScreen.TOP_H))
		for r in [centred, docked]:
			assert_bool(r.intersects(top)).override_failure_message("notice %s in the top strip at %s" % [r, sz]).is_false()
			assert_bool(r.intersects(gs.menu.scoreboard.get_global_rect())).is_false()
			for b in _buttons(gs):
				assert_bool(r.intersects((b as Control).get_global_rect())).is_false()
		# The docked notice stays left of the sidebar.
		assert_float(docked.end.x).is_less_equal((gt * Vector2(gs.play_area.end.x, 0)).x + 1.0)
		wn.show_text("")
		gs.queue_free()
		await await_idle_frame()
