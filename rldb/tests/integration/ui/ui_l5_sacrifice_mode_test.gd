extends GdUnitTestSuite
## L5 (owner feedback 2026-11-05) on the real GameScreen bound to a local host: the Sacrifice button
## toggles sacrifice MODE. In it a click on a sacrificable unit sacrifices it at once (no prompt, no
## confirmation) and the mode stays on; it ends with the button, Esc, a phase change, a prompt, nothing
## left to sacrifice or the game ending. Outside it nothing can be sacrificed by a click. The windowed
## run with screenshots is src/dev/l_interaction_shots.gd.

const PIERCE_UNIT := 15

var host: LocalHost
var gs: GameScreen
var m: MatchEngine
var me: int


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


## Two of my units that may be sacrificed (slots 0 and 1), one summoned this turn (slot 2), and an
## opposing unit; returns their uids [a, b, fresh, opp].
func _board() -> Array:
	var a := TB.unit(m, me, TB.WATER, 0)
	var b := TB.unit(m, me, TB.FIRE, 1)
	var fresh := TB.unit(m, me, TB.WATER, 2, "atk", null, null, true)
	var opp := TB.unit(m, 1 - me, TB.WATER, 1)
	host.broadcast()
	gs.skip_effects()
	return [a, b, fresh, opp]


func _w(p: int, slot: int) -> CardWidget:
	return gs.board.slot_item(p, "unit", slot)["widget"]


func _click(w: CardWidget) -> void:
	gs.selection.on_widget_pressed(w)
	gs.skip_effects()


func _toggle() -> void:
	gs.board.controls.sacrifice_btn.pressed.emit()


func test_button_turns_the_mode_on_with_its_look_and_sound() -> void:
	# Arrange
	_board()
	Sfx._reset_ui()
	Sfx.debug_ui.clear()
	# Act
	_toggle()
	await await_idle_frame()
	# Assert
	assert_bool(gs.sacrifice.active).is_true()
	assert_array(Sfx.debug_ui).contains(["sacrifice_mode_on"])
	assert_bool(gs.sacrifice.vignette.visible).is_true()
	assert_bool(gs.board.controls.sacrifice_btn.latched).is_true()
	assert_bool(m.pending.is_empty()).is_true()
	assert_bool(gs.board.ready_uids.is_empty()).is_true()          # only the sacrificable units glow
	var ring0: ZoneRing = gs.board.slot_item(me, "unit", 0)["ring"]
	var ring2: ZoneRing = gs.board.slot_item(me, "unit", 2)["ring"]
	assert_bool(ring0.on).is_true()
	assert_object(ring0.col).is_equal(GameSacrificeMode.EMBER)
	assert_bool(ring2.on).is_false()                                 # summoned this turn
	assert_bool(_w(me, 2).dimmed).is_true()
	assert_bool(_w(1 - me, 1).dimmed).is_true()


func test_a_click_sacrifices_at_once_and_the_mode_stays_on() -> void:
	# Arrange
	var u := _board()
	var ap: int = m.players[me]["ap"]
	_toggle()
	# Act
	_click(_w(me, 0))
	await await_idle_frame()
	# Assert: gone, +1 AP, no prompt, still in the mode.
	assert_str(String(m.cards[u[0]]["zone"])).is_equal("spent")
	assert_int(m.players[me]["ap"]).is_equal(ap + 1)
	assert_bool(m.pending.is_empty()).is_true()
	assert_bool(gs.sacrifice.active).is_true()
	# Act: the next one.
	_click(_w(me, 1))
	await await_idle_frame()
	assert_str(String(m.cards[u[1]]["zone"])).is_equal("spent")


func test_nothing_left_to_sacrifice_ends_the_mode() -> void:
	# Arrange: one sacrificable unit.
	TB.unit(m, me, TB.WATER, 0)
	host.broadcast()
	gs.skip_effects()
	_toggle()
	Sfx._reset_ui()
	Sfx.debug_ui.clear()
	# Act
	_click(_w(me, 0))
	await await_idle_frame()
	# Assert
	assert_bool(gs.sacrifice.active).is_false()
	assert_array(Sfx.debug_ui).contains(["sacrifice_mode_off"])
	assert_bool(gs.board.controls.sacrifice_btn.latched).is_false()


func test_an_unsacrificable_unit_is_refused_with_its_reason() -> void:
	# Arrange
	var u := _board()
	_toggle()
	# Act: the unit summoned this turn, then the opponent's unit.
	_click(_w(me, 2))
	await await_idle_frame()
	# Assert
	assert_str(String(m.cards[u[2]]["zone"])).is_equal("unit")
	assert_bool(gs.prompt.toast.visible).is_true()
	assert_str(gs.prompt.toast.text).contains("summoned this turn")
	_click(_w(1 - me, 1))
	assert_str(String(m.cards[u[3]]["zone"])).is_equal("unit")
	assert_bool(gs.sacrifice.active).is_true()


func test_outside_the_mode_a_click_selects_and_never_sacrifices() -> void:
	# Arrange
	var u := _board()
	# Act
	_click(_w(me, 0))
	await await_idle_frame()
	# Assert
	assert_str(String(m.cards[u[0]]["zone"])).is_equal("unit")
	assert_int(gs.selected_uid).is_equal(u[0])
	var labels: Array = gs.action_row.stack.get_children().map(func(b): return (b as Button).text) if gs.action_row.stack != null else []
	assert_array(labels).not_contains(["Sacrifice"])


func test_the_button_again_ends_the_mode() -> void:
	_board()
	_toggle()
	Sfx._reset_ui()
	Sfx.debug_ui.clear()
	_toggle()
	await await_idle_frame()
	assert_bool(gs.sacrifice.active).is_false()
	assert_array(Sfx.debug_ui).contains(["sacrifice_mode_off"])


func test_esc_ends_the_mode() -> void:
	_board()
	_toggle()
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	assert_bool(gs.keyboard.handle_key(e)).is_true()
	assert_bool(gs.sacrifice.active).is_false()
	assert_bool(gs.menu.game_menu.visible).is_false()   # Esc ended the mode; it did not open the menu


func test_a_phase_change_ends_the_mode() -> void:
	_board()
	_toggle()
	host.handle(me, {"t": "next_phase"})
	gs.skip_effects()
	await await_idle_frame()
	assert_bool(gs.sacrifice.active).is_false()


func test_a_prompt_taking_over_ends_the_mode() -> void:
	# Arrange: a unit with a targeted ability; the mode on.
	var pu := TB.unit(m, me, PIERCE_UNIT, 3)
	_board()
	_toggle()
	assert_bool(gs.sacrifice.active).is_true()
	# Act: the ability opens a choice (as a remote command or a script would).
	var act := {}
	for a in gs.mv.get("actions", []):
		if String(a["t"]) == "ability" and int(a.get("uid", -1)) == pu and a["ok"]:
			act = a
	host.handle(me, {"t": "ability", "uid": pu, "idx": act.get("idx", 0)})
	gs.skip_effects()
	await await_idle_frame()
	# Assert
	assert_bool(m.pending.is_empty()).is_false()
	assert_bool(gs.sacrifice.active).is_false()


func test_the_game_ending_ends_the_mode_silently() -> void:
	_board()
	_toggle()
	Sfx._reset_ui()
	Sfx.debug_ui.clear()
	m.winner = me
	host.broadcast()
	gs.skip_effects()
	await await_idle_frame()
	assert_bool(gs.sacrifice.active).is_false()
	assert_array(Sfx.debug_ui).not_contains(["sacrifice_mode_off"])


func test_a_double_click_before_the_reply_sends_one_sacrifice() -> void:
	# Arrange: my commands wait (online).
	_board()
	var held: HeldSeat = auto_free(HeldSeat.new(host.seats[me]))
	add_child(held)
	await gs.attach(held)
	_toggle()
	# Act
	_click(_w(me, 0))
	_click(_w(me, 0))
	# Assert
	assert_int(held.queued.size()).is_equal(1)
	assert_dict(held.queued[0]).is_equal({"t": "sacrifice", "uid": int(_w(me, 0).view["uid"])})


func test_keyboard_tab_focuses_and_enter_sacrifices() -> void:
	# Arrange
	var u := _board()
	_toggle()
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	# Act
	assert_bool(gs.keyboard.handle_key(tab)).is_true()
	assert_int(gs.sacrifice.kb_uid).is_equal(u[0])
	assert_bool(gs.keyboard.handle_key(enter)).is_true()
	gs.skip_effects()
	await await_idle_frame()
	# Assert
	assert_str(String(m.cards[u[0]]["zone"])).is_equal("spent")
	assert_bool(gs.sacrifice.active).is_true()
	assert_str(m.phase).is_not_equal(MatchEngine.PHASE_BATTLE)   # Enter did not end the phase


func test_enter_without_a_focus_does_nothing_in_the_mode() -> void:
	_board()
	var phase := m.phase
	_toggle()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	assert_bool(gs.keyboard.handle_key(enter)).is_true()
	assert_str(m.phase).is_equal(phase)


func test_a_new_seat_on_the_screen_starts_outside_the_mode() -> void:
	_board()
	_toggle()
	await gs.attach(host.seats[me])
	assert_bool(gs.sacrifice.active).is_false()
	assert_bool(gs.sacrifice.vignette.visible).is_false()


func test_cursor_hooks_report_the_mode() -> void:
	# Arrange
	var u := _board()
	var seen: Array = []
	gs.sacrifice.changed.connect(func(on: bool): seen.append(on))
	# Act / Assert
	_toggle()
	assert_bool(gs.sacrifice.is_active()).is_true()
	assert_bool(gs.sacrifice.would_sacrifice(u[0])).is_true()
	assert_bool(gs.sacrifice.would_sacrifice(u[2])).is_false()   # summoned this turn
	assert_bool(gs.targeting.aiming()).is_false()
	_toggle()
	assert_bool(gs.sacrifice.is_active()).is_false()
	assert_array(seen).is_equal([true, false])


func test_the_mode_does_not_start_when_no_sacrifice_is_legal() -> void:
	# No unit on the field.
	_toggle()
	assert_bool(gs.sacrifice.active).is_false()
