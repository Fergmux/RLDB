extends GdUnitTestSuite
## A1 / A2 on real match screens: the Chat button and spectator controls exist online only; the
## chat box counts unread messages and renders markup as plain text; the Spectators list toggles
## carry the owner's tooltips; a spectator's screen is locked, offers Stop watching instead of
## Concede, and never sends a command when leaving. No "Connected (steam)" text is shown.

const PORT := 24771

var host: NetSession
var client: NetSession
var spec: NetSession
var roots: Array = []


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	roots = []


func after_test() -> void:
	for n in roots:
		if is_instance_valid(n):
			n.queue_free()
	roots = []
	for i in 5:
		await get_tree().process_frame


func _wait(cond: Callable, frames: int = 600) -> bool:
	var deadline := Time.get_ticks_msec() + frames * 1000 / 60
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _screen(seat: SeatClient) -> GameScreen:
	var gs := GameScreen.new()
	gs.size = Vector2(1600, 900)
	add_child(gs)
	roots.append(gs)
	await gs.attach(seat)
	await await_idle_frame()
	return gs


func _net() -> void:
	for n in ["H", "C", "S"]:
		var r := Node.new()
		r.name = n
		add_child(r)
		roots.append(r)
	host = NetSession.new()
	roots[0].add_child(host)
	client = NetSession.new()
	roots[1].add_child(client)
	spec = NetSession.new()
	roots[2].add_child(spec)
	client._token = "ui-client-token-01"
	spec._token = "ui-spectator-tok-1"
	host.host_enet(PORT, {"seed": 8, "best_of": 3, "host_name": "Aldric"})
	client.join_enet("127.0.0.1", PORT)
	assert_bool(await _wait(func(): return host.remote_peer != 0)).is_true()
	host.local_seat.send({"t": "pick_starter", "index": 0})
	client.local_seat.send({"t": "pick_starter", "index": 1})
	assert_bool(await _wait(func(): return host.series.stage == Series.STAGE_GAME)).is_true()
	spec.join_enet("127.0.0.1", PORT)
	assert_bool(await _wait(func(): return spec.is_spectator and spec.local_seat.last_view.has("match"))).is_true()


func test_offline_screen_has_no_chat_or_spectator_controls() -> void:
	var lh: LocalHost = auto_free(LocalHost.new())
	add_child(lh)
	lh.start({"seed": 3, "best_of": 3, "deck_mode": "starter", "names": ["A", "B"], "mode": "local"})
	var gs := await _screen(lh.seats[0])
	assert_bool(gs.chat.button.visible).is_false()
	assert_bool(gs.spectate.badge.visible).is_false()
	assert_bool((gs.menu.items["spectators"] as Button).visible).is_false()
	assert_bool((gs.menu.items["concede"] as Button).visible).is_true()
	assert_bool((gs.menu.items["stop"] as Button).visible).is_false()


func test_player_screen_chat_unread_badge_and_plain_text_history(timeout := 30000) -> void:
	await _net()
	var gs := await _screen(host.local_seat)
	assert_bool(gs.chat.button.visible).is_true()
	assert_str(gs.menu.conn_label.text).is_empty()          # no "Connected (enet)"
	client.send_chat("[b]bold[/b] move")
	assert_bool(await _wait(func(): return gs.chat.unread == 1)).is_true()
	assert_bool(gs.chat.badge.visible).is_true()
	var txt := gs.chat.history.get_parsed_text()
	assert_str(txt).contains("bold move")
	assert_str(txt).not_contains("[b]")
	gs.chat.open_box()
	assert_int(gs.chat.unread).is_equal(0)
	assert_bool(gs.chat.badge.visible).is_false()
	# While open, a new message adds no unread count.
	await _wait(func(): return false, 25)
	client.send_chat("again")
	assert_bool(await _wait(func(): return gs.chat.history.get_parsed_text().contains("again"))).is_true()
	assert_int(gs.chat.unread).is_equal(0)


func test_typing_in_chat_never_triggers_game_shortcuts(timeout := 30000) -> void:
	await _net()
	# The active seat's screen: there, Enter alone would end the phase (Space / Tab act too).
	var active := host.series.game.active
	var gs := await _screen(host.local_seat if active == 0 else client.local_seat)
	assert_bool(gs.locked()).is_false()
	gs.chat.open_box()
	await await_idle_frame()
	gs.chat.input.grab_focus()
	await await_idle_frame()
	var before := gs.debug_sent
	for k in [KEY_ENTER, KEY_SPACE, KEY_TAB]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.pressed = true
		gs._input(ev)
	assert_int(gs.debug_sent).is_equal(before)
	# Esc closes the chat box first.
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	gs._input(esc)
	assert_bool(gs.chat.is_open()).is_false()
	assert_bool(gs.menu.game_menu.visible).is_false()


func test_spectators_list_toggle_tooltips_and_state(timeout := 30000) -> void:
	await _net()
	var gs := await _screen(host.local_seat)
	assert_bool(await _wait(func(): return gs.spectate.badge.visible)).is_true()
	assert_str((gs.menu.items["spectators"] as Button).text).is_equal("Spectators (1)")
	gs.spectate.toggle_list()
	var t: Button = gs.spectate.panel.find_child("EyeToggle*", true, false)
	assert_object(t).is_not_null()
	assert_str(t.tooltip_text).is_equal("Allow this player to see your cards")
	assert_bool((t.find_child("Eye", true, false) as EyeGlyph).open).is_false()
	t.pressed.emit()
	assert_bool(await _wait(func():
		var t2: Button = gs.spectate.panel.find_child("EyeToggle*", true, false)
		return t2 != null and t2.tooltip_text == "Stop this player seeing your cards")).is_true()
	var t3: Button = gs.spectate.panel.find_child("EyeToggle*", true, false)
	assert_bool((t3.find_child("Eye", true, false) as EyeGlyph).open).is_true()
	assert_bool(host.spectator_allow[0].has(spec.spectator_id)).is_true()
	t3.pressed.emit()
	assert_bool(await _wait(func(): return host.spectator_allow[0].is_empty())).is_true()


func test_spectator_screen_is_locked_and_leaving_sends_nothing(timeout := 30000) -> void:
	await _net()
	var gs := await _screen(spec.local_seat)
	assert_bool(gs.is_spectator()).is_true()
	assert_bool(gs.locked()).is_true()
	assert_bool(gs.spectate.badge.visible).is_true()
	assert_bool(gs.spectate.flip_button.visible).is_true()
	assert_bool((gs.menu.items["stop"] as Button).visible).is_true()
	assert_bool((gs.menu.items["concede"] as Button).visible).is_false()
	assert_bool((gs.menu.items["spectators"] as Button).visible).is_false()
	assert_bool(gs.sidebar.phase_btn.visible).is_false()
	# Redacted: the bottom player's hand is shown as card backs, never as cards.
	assert_int(gs.hand.order.size()).is_equal(0)
	var n := int(gs.pv(gs.me())["counts"]["hand"])
	assert_int(gs.board.own_backs_box.get_child_count()).is_equal(mini(n, GameBoardView.OPP_HAND_MAX))
	var before := gs.debug_sent
	gs.menu.confirm_forfeit(false)
	assert_object(gs.menu.dialog()).is_null()
	assert_int(gs.debug_sent).is_equal(before)
