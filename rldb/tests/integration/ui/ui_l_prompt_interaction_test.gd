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
