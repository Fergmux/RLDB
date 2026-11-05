extends GdUnitTestSuite
## L batch final QA (design/qa-final-2026-11-05.md): a status look on a card whose previous status
## name was freed by a skip (FxPlayer.finish_all: a game switch, a reconnect, skip_effects) must still
## play. FxStatus._name read the remembered label into a typed `Label` variable, and assigning a freed
## instance is a script error, so the name (and the error spam) broke every later status on that card.
## Found by tests/perf/perf_run.gd.


func test_status_name_plays_after_the_previous_name_was_freed_by_a_skip() -> void:
	# Arrange
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	await await_idle_frame()
	var st: FxStatus = gs.fx._status
	var at := {"p": 0, "zone": "unit", "slot": 0}
	var rect := Rect2(400, 400, 85, 128)
	st._name(at, rect, "Poison", Color.WHITE, 17, 1.0)
	gs.fx.finish_all()
	await await_idle_frame()
	await await_idle_frame()
	# Act: the next status name on the same card.
	st._name(at, rect, "Burn", Color.WHITE, 17, 1.0)
	# Assert: it was created and remembered (a script error would have aborted before).
	var shown = st._names.get(FxStatus._slot_key(at), null)
	assert_bool(shown != null and is_instance_valid(shown)).is_true()
	assert_str((shown as Label).text).is_equal("Burn")
