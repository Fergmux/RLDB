extends GdUnitTestSuite
## L batch final QA (design/qa-final-2026-11-05.md): a tutorial step must survive an off-script answer.
## L7 marks a choice "answered" the moment it is picked (the arrow goes at once) and waits for the
## host's reply; a refused answer is replied to with a fresh view showing the same choice, which ends
## the mark. The TutorialHost refused off-script answers without replying, so after one wrong zone
## (or Esc / right-click on the forced zone pick) every later click was ignored: the learner was stuck.

const ME := TutorialLessons.PLAYER

var h: TutorialHost
var gs: GameScreen


func before_test() -> void:
	h = auto_free(TutorialHost.new())
	h.opp_delay = 0.0
	add_child(h)
	h.start({"lesson": 1})
	h.next_step()                                          # "Summon a unit"
	h.handle(ME, TutorialScript.resolve(h.game(), h.keys, h.current_step()["expect"][0]))
	h.next_step()
	gs = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	await gs.attach(h.seats[ME])
	gs.skip_effects()
	await await_idle_frame()


func _expected_index() -> int:
	var cmd := TutorialScript.resolve(h.game(), h.keys, h.current_step()["expect"][0])
	return int(cmd.get("indices", [-1])[0])


func test_a_refused_zone_pick_is_replied_to_and_the_right_zone_still_works() -> void:
	# Arrange: the forced zone pick of the lesson's summon.
	assert_str(String(h.game().pending.get("kind", ""))).is_equal("slot")
	var good := _expected_index()
	var wrong := 0 if good != 0 else 1
	var step := h.step_index
	var views := [0]
	h.seats[ME].view_changed.connect(func(_v): views[0] += 1)
	# Act: a wrong zone first.
	gs.selection.pick_option(wrong)
	gs.skip_effects()
	await await_idle_frame()
	# Assert: refused, replied to, and the choice can be answered again.
	assert_int(h.refused).is_equal(1)
	assert_int(views[0]).override_failure_message("the refusal was not replied to").is_greater(0)
	assert_bool(gs.selection.answered()).is_false()
	gs.selection.pick_option(good)
	gs.skip_effects()
	await await_idle_frame()
	assert_str(String(h.game().pending.get("kind", ""))).is_not_equal("slot")
	assert_int(h.step_index).is_greater(step)


func test_esc_on_the_forced_zone_pick_leaves_it_answerable() -> void:
	assert_str(String(h.game().pending.get("kind", ""))).is_equal("slot")
	var step := h.step_index
	# Act: Esc (the screen's cancel) is refused by the lesson.
	gs.selection.cancel()
	gs.skip_effects()
	await await_idle_frame()
	# Assert
	assert_int(h.refused).is_equal(1)
	assert_bool(gs.selection.answered()).is_false()
	gs.selection.pick_option(_expected_index())
	gs.skip_effects()
	await await_idle_frame()
	assert_int(h.step_index).is_greater(step)
