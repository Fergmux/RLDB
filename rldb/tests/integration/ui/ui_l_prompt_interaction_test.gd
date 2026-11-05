extends GdUnitTestSuite
## L batch (owner feedback 2026-11-05) on the real GameScreen bound to a local host: L6 the prompt's
## Cancel is a real button, L7 the targeting arrow hides the moment a target is picked, L16 the
## opponent-is-responding notice. The windowed run with screenshots is src/dev/l_interaction_shots.gd.

const PIERCE_UNIT := 15     # ability: Apply 1 Pierce to a unit (a cancellable target pick)

var host: LocalHost
var gs: GameScreen
var m: MatchEngine
var me: int


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
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


## Opens the Pierce unit's targeted ability (a cancellable board pick); returns the unit's uid.
func _open_target_pick() -> int:
	var u := TB.unit(m, me, PIERCE_UNIT, 0)
	TB.unit(m, 1 - me, TB.WATER, 1)
	host.broadcast()
	gs.skip_effects()
	var act := {}
	for a in gs.mv.get("actions", []):
		if String(a["t"]) == "ability" and int(a.get("uid", -1)) == u and a["ok"]:
			act = a
	assert_bool(act.is_empty()).override_failure_message("no Pierce ability offered").is_false()
	gs.action_row.run_action(u, act)
	gs.skip_effects()
	return u


func _cancel_button() -> Button:
	for ch in gs.prompt.cancel_row.get_children():
		if ch is Button:
			return ch
	return null


# ---------------------------------------------------------------- L6

func test_cancel_is_a_real_button_as_wide_as_the_panel() -> void:
	# Arrange / Act: a cancellable pick opens the prompt panel.
	_open_target_pick()
	await await_idle_frame()
	await await_idle_frame()
	# Assert
	assert_bool(m.pending.get("cancellable", false)).is_true()
	var b := _cancel_button()
	assert_object(b).is_not_null()
	assert_bool(b is TextLink).is_false()
	assert_bool(b is PromptPlate.CancelButton).is_true()
	assert_bool(b.is_visible_in_tree()).is_true()
	assert_str(b.text).is_equal("Cancel")
	assert_float(b.size.y).is_greater_equal(PromptPlate.CancelButton.HEIGHT - 0.5)
	var body: Control = (gs.prompt.ctx_banner as HousePanel).body
	assert_float(b.size.x).is_greater(body.size.x * 0.9)


func test_cancel_button_cancels_the_choice() -> void:
	await _cancel_case()


# ---------------------------------------------------------------- L7

const ASSASSINATE := 84     # Spell: destroy a unit with 20 DEF or less (a Spell spotlight follows)


## A seat that holds my commands until flush() (an online reply on its way).
class HeldSeat extends SeatClient:
	var inner: SeatClient
	var queued: Array = []

	func _init(i: SeatClient) -> void:
		inner = i
		seat = i.seat
		last_view = i.last_view
		i.view_changed.connect(deliver)

	func send(cmd: Dictionary) -> void:
		queued.append(cmd)

	func flush() -> void:
		var q := queued.duplicate()
		queued.clear()
		for c in q:
			inner.send(c)


func _option_for(p: int, slot: int) -> int:
	return gs.selection.option_for_ref(p, "unit", slot)


func _aim(opt: int) -> void:
	gs.targeting.hover_opt = opt          # the pointer over the target
	gs.targeting.update_arrow()


func test_arrow_hides_the_moment_a_spell_target_is_picked_and_stays_hidden_in_the_spotlight() -> void:
	# Arrange: a targeted Spell in hand, the opponent's unit to destroy, aimed at.
	var sp := TB.card(m, me, ASSASSINATE)
	TB.unit(m, 1 - me, TB.WATER, 1)
	m.players[me]["ap"] = 6
	host.broadcast()
	gs.skip_effects()
	for a in gs.mv.get("actions", []):
		if String(a["t"]) == "cast" and int(a.get("uid", -1)) == sp:
			gs.action_row.run_action(sp, a)
	gs.skip_effects()
	var pid := int(m.pending.get("id", -1))
	var opt := _option_for(1 - me, 1)
	assert_int(opt).is_not_equal(-1)
	_aim(opt)
	assert_bool(gs.arrow.on).is_true()
	# Act: pick the target.
	gs.selection.pick_option(opt)
	# Assert: hidden at once, and still hidden while the spotlight holds the old board (whose
	# pending choice is still the one just answered) even with the pointer on the target.
	assert_bool(gs.arrow.on).is_false()
	assert_int(int(gs.pending().get("id", -2))).override_failure_message("the spotlight should hold the old board").is_equal(pid)
	_aim(opt)
	assert_bool(gs.arrow.on).is_false()
	assert_int(gs.targeting.option_under_pointer()).is_equal(-1)
	gs.skip_effects()
	_aim(-1)
	assert_bool(gs.arrow.on).is_false()


func test_arrow_stays_hidden_until_an_online_reply_and_a_second_pick_is_not_sent() -> void:
	# Arrange: my commands wait (online); a targeted ability is aimed.
	var held: HeldSeat = auto_free(HeldSeat.new(host.seats[me]))
	add_child(held)
	await gs.attach(held)
	_open_target_pick()
	held.flush()                          # the ability itself goes through
	gs.skip_effects()
	var opt := _option_for(1 - me, 1)
	assert_int(opt).is_not_equal(-1)
	_aim(opt)
	assert_bool(gs.arrow.on).is_true()
	# Act: pick, then click again before the reply.
	gs.selection.pick_option(opt)
	gs.selection.pick_option(opt)
	_aim(opt)
	# Assert: hidden while the reply is on its way; one answer sent.
	assert_bool(gs.arrow.on).is_false()
	assert_int(held.queued.size()).is_equal(1)
	held.flush()
	gs.skip_effects()
	assert_bool(m.pending.is_empty()).is_true()


func test_a_refused_answer_lets_the_choice_be_aimed_again() -> void:
	# Arrange
	var held: HeldSeat = auto_free(HeldSeat.new(host.seats[me]))
	add_child(held)
	await gs.attach(held)
	_open_target_pick()
	held.flush()
	gs.skip_effects()
	var opt := _option_for(1 - me, 1)
	gs.selection.pick_option(opt)
	_aim(opt)
	assert_bool(gs.arrow.on).is_false()
	# Act: the authority's reply still shows the same choice (the answer was refused).
	held.queued.clear()
	host.broadcast()
	gs.skip_effects()
	_aim(opt)
	# Assert
	assert_bool(gs.selection.answered()).is_false()
	assert_bool(gs.arrow.on).is_true()


func _cancel_case() -> void:
	# Arrange
	_open_target_pick()
	await await_idle_frame()
	assert_bool(m.pending.is_empty()).is_false()
	# Act
	_cancel_button().pressed.emit()
	gs.skip_effects()
	await await_idle_frame()
	# Assert
	assert_bool(m.pending.is_empty()).is_true()
	assert_bool(gs.prompt.ctx_banner.visible).is_false()
