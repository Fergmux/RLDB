extends GdUnitTestSuite
## J6 / J11 (owner feedback 2026-10-22) on the real GameScreen bound to a local host: the duel
## controls under the local player's plate. Sacrifice Unit (enabled only while legal; pick, confirm)
## replaces the Sacrifice card action; the Trap Prompts toggle is the viewer's saved choice and sets
## the seat's prompts on the authority. The windowed run with screenshots is
## src/dev/duel_controls_shots.gd (evidence in production/qa/evidence/2026-10-22-batch/duel-controls).

var host: LocalHost
var gs: GameScreen
var m: MatchEngine
var me: int


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	DuelControls.store_prompts(DuelControls.PREF_KEY, true)      # the default: prompts on
	host = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 11, "best_of": 1, "deck_mode": "starter", "names": ["A", "B"], "mode": "bot"})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	m = host.series.game
	me = m.active
	gs = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	await gs.attach(host.seats[me])
	gs.skip_effects()
	await await_idle_frame()


func after_test() -> void:
	DuelControls.store_prompts(DuelControls.PREF_KEY, true)
	DuelControls.reset_cache()


func _controls() -> DuelControls:
	return gs.board.controls


func _row() -> Array:
	if gs.action_row.stack == null or not is_instance_valid(gs.action_row.stack):
		return []
	return gs.action_row.stack.get_children().map(func(b): return (b as Button).text)


func _field_unit() -> int:
	var u := TB.unit(m, me, TB.WATER, 0)
	host.broadcast()
	return u


func test_controls_sit_under_the_local_plate() -> void:
	var c := _controls()
	assert_bool(c.visible).is_true()
	var plate := gs.plate_of(me).get_global_rect()
	var r := c.get_global_rect()
	assert_float(r.position.y).is_greater_equal(plate.end.y)
	assert_float(r.position.x).is_equal_approx(plate.position.x, 0.5)
	assert_float(r.end.y).is_less_equal(gs.size.y)


func test_card_row_no_longer_offers_sacrifice() -> void:
	var u := _field_unit()
	await await_idle_frame()
	gs.selection.select(u)
	await await_idle_frame()
	assert_array(_row()).is_not_empty()
	assert_array(_row()).not_contains(["Sacrifice"])


func test_sacrifice_button_is_enabled_only_while_legal() -> void:
	await await_idle_frame()
	assert_bool(_controls().sacrifice_btn.disabled).is_true()           # no unit yet
	assert_str(_controls().sacrifice_btn.tooltip_text).contains("no unit")
	_field_unit()
	await await_idle_frame()
	assert_bool(_controls().sacrifice_btn.disabled).is_false()
	host.handle(me, {"t": "next_phase"})                              # Battle (or Recovery on turn 1)
	gs.skip_effects()
	await await_idle_frame()
	if m.phase == "battle":
		assert_bool(_controls().sacrifice_btn.disabled).is_true()


func test_sacrifice_button_picks_then_confirms() -> void:
	var u := _field_unit()
	await await_idle_frame()
	var ap: int = m.players[me]["ap"]
	_controls().sacrifice_btn.pressed.emit()
	gs.skip_effects()
	await await_idle_frame()
	assert_str(TB.pend_kind(m)).is_equal("select")
	assert_bool(gs.selection.board_targeting()).is_true()             # pick on the board
	assert_int(gs.selection.option_for_ref(me, "unit", 0)).is_not_equal(-1)
	gs.selection.pick_option(gs.selection.option_for_ref(me, "unit", 0))
	gs.skip_effects()
	await await_idle_frame()
	assert_str(TB.pend_kind(m)).is_equal("confirm")
	var labels: Array = gs.prompt.banner_list.find_children("*", "Button", true, false).map(func(b): return (b as Button).text)
	assert_array(labels).contains([MatchEngine.SACRIFICE_YES])
	TB.choose(m, [MatchEngine.SACRIFICE_YES])
	host.broadcast()
	assert_str(String(m.cards[u]["zone"])).is_equal("spent")
	assert_int(m.players[me]["ap"]).is_equal(ap + 1)


func test_prompts_toggle_starts_on_and_sets_the_seat() -> void:
	await await_idle_frame()
	var c := _controls()
	assert_bool(c.prompts_btn.visible).is_true()
	assert_bool(c.prompts_on()).is_true()
	assert_str(c.prompts_btn.text).is_equal(DuelControls.PROMPTS_ON_LABEL)
	assert_str(m.trap_prompt_mode(me)).is_equal(EffectEngine.TRAP_PROMPT_ELIGIBLE)
	assert_str(m.trap_prompt_mode(1 - me)).is_equal(EffectEngine.TRAP_PROMPT_ELIGIBLE)   # the bot's own


func test_prompts_toggle_off_is_saved_and_sent() -> void:
	await await_idle_frame()
	var c := _controls()
	c.prompts_btn.pressed.emit()
	await await_idle_frame()
	assert_bool(c.prompts_on()).is_false()
	assert_str(c.prompts_btn.text).is_equal(DuelControls.PROMPTS_OFF_LABEL)
	assert_int(c.prompts_btn.lamp).is_equal(0)
	assert_str(m.trap_prompt_mode(me)).is_equal(EffectEngine.TRAP_PROMPT_OFF)
	DuelControls.reset_cache()
	assert_bool(DuelControls.load_prompts(DuelControls.PREF_KEY)).is_false()   # read back from the file
	c.prompts_btn.pressed.emit()
	await await_idle_frame()
	assert_str(m.trap_prompt_mode(me)).is_equal(EffectEngine.TRAP_PROMPT_ELIGIBLE)


func test_a_saved_off_choice_is_sent_for_a_new_screen() -> void:
	DuelControls.store_prompts(DuelControls.PREF_KEY, false)
	var gs2: GameScreen = auto_free(GameScreen.new())
	gs2.size = Vector2(1600, 1000)
	add_child(gs2)
	await gs2.attach(host.seats[me])
	await await_idle_frame()
	assert_bool(gs2.board.controls.prompts_on()).is_false()
	assert_str(m.trap_prompt_mode(me)).is_equal(EffectEngine.TRAP_PROMPT_OFF)


func test_the_hand_keeps_clear_of_the_controls() -> void:
	for i in 9:
		TB.card(m, me, TB.WATER)
	host.broadcast()
	await await_idle_frame()
	var clear_x := _controls().get_global_rect().end.x
	for uid in gs.hand.order:
		var r: Rect2 = (gs.hand.items[uid]["holder"] as Control).get_global_rect()
		assert_float(r.position.x).is_greater(clear_x)
		assert_float(r.end.x).is_less_equal(gs.play_area.end.x + 0.5)


func test_hot_seat_keeps_one_choice_per_seat() -> void:
	assert_str(DuelControls.pref_key(true, 0)).is_not_equal(DuelControls.pref_key(true, 1))
	assert_str(DuelControls.pref_key(false, 1)).is_equal(DuelControls.PREF_KEY)


func test_sacrifice_button_stays_lit_during_its_flow_and_a_second_click_cancels() -> void:
	_field_unit()
	await await_idle_frame()
	var c := _controls()
	c.sacrifice_btn.pressed.emit()
	gs.skip_effects()
	await await_idle_frame()
	assert_bool(c.sacrifice_engaged()).is_true()
	assert_bool(c.sacrifice_btn.disabled).is_false()
	assert_bool(c.sacrifice_btn.keyboard_pick).is_true()
	c.sacrifice_btn.pressed.emit()
	gs.skip_effects()
	await await_idle_frame()
	assert_bool(m.pending.is_empty()).is_true()
	assert_bool(c.sacrifice_engaged()).is_false()
	assert_bool(c.sacrifice_btn.keyboard_pick).is_false()
