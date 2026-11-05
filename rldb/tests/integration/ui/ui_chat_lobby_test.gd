extends GdUnitTestSuite
## J17-J22 (owner feedback 22 Oct) on real match screens over ENet: the chat's round close button
## works with a real mouse click over the series modal and the draft (J20 regression: the modal's
## dim, a later sibling, took the click although the chat drew above it); no key hint (J19); a
## message while the box is closed pops the preview and the badge (J17); muting hides a person's
## lines and alerts, locally (J21); the always-present View lobby list has Players and Spectators
## sections, players with Mute only (J22), for players and for spectators.

const PORT := 24791

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


func _pause(frames: int) -> void:
	await _wait(func(): return false, frames)


## Host and client over ENet; `cfg` extends the host config. `to_game` plays to the first duel.
func _net(cfg: Dictionary = {}, to_game: bool = true) -> void:
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
	client._token = "lobby-client-token-1"
	spec._token = "lobby-spectator-tok1"
	var c := {"seed": 8, "best_of": 3, "host_name": "Aldric"}
	c.merge(cfg, true)
	host.host_enet(PORT, c)
	client.join_enet("127.0.0.1", PORT)
	assert_bool(await _wait(func(): return host.remote_peer != 0)).is_true()
	if not to_game:
		return
	host.local_seat.send({"t": "pick_starter", "index": 0})
	client.local_seat.send({"t": "pick_starter", "index": 1})
	assert_bool(await _wait(func(): return host.series.stage == Series.STAGE_GAME)).is_true()


func _add_spectator() -> void:
	spec.join_enet("127.0.0.1", PORT)
	assert_bool(await _wait(func(): return spec.is_spectator and spec.local_seat.last_view.has("net"))).is_true()
	assert_bool(await _wait(func(): return not host.local_seat.last_view.get("net", {}).get("spectators", []).is_empty())).is_true()


## A match screen in its own SubViewport (real GUI picking: input pushed to it reaches the
## control the viewport finds under the point, like a mouse click in the game).
func _screen_in_viewport(seat: SeatClient) -> Array:
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 900)
	add_child(vp)
	roots.append(vp)
	var gs := GameScreen.new()
	gs.size = Vector2(1600, 900)
	vp.add_child(gs)
	await gs.attach(seat)
	await await_idle_frame()
	return [vp, gs]


func _screen(seat: SeatClient) -> GameScreen:
	var gs := GameScreen.new()
	gs.size = Vector2(1600, 900)
	add_child(gs)
	roots.append(gs)
	await gs.attach(seat)
	await await_idle_frame()
	return gs


## A left click (press + release) at the centre of `c`, pushed through `vp`.
func _click(vp: SubViewport, c: Control) -> void:
	var p := c.get_global_rect().get_center()
	var mv := InputEventMouseMotion.new()
	mv.position = p
	mv.global_position = p
	vp.push_input(mv)
	await await_idle_frame()
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = p
		ev.global_position = p
		vp.push_input(ev)
		await await_idle_frame()


# ---------------------------------------------------------------- J20

func test_chat_close_click_over_series_modal_closes_box(timeout := 40000) -> void:
	await _net()
	var pair := await _screen_in_viewport(host.local_seat)
	var vp: SubViewport = pair[0]
	var gs: GameScreen = pair[1]
	host.local_seat.send({"t": "concede"})
	assert_bool(await _wait(func(): return host.series.stage == Series.STAGE_REWARDS)).is_true()
	await _pause(200)
	gs.skip_effects()
	gs.fx.release_game_end_hold()
	gs.render_all()
	await _pause(20)
	assert_bool(gs.overlays.overlay_dim.visible).is_true()
	gs.chat.open_box()
	await _pause(30)
	await _click(vp, gs.chat.close_button)
	assert_bool(gs.chat.is_open()).is_false()


func test_chat_close_click_during_online_draft_closes_box(timeout := 40000) -> void:
	await _net({"deck_mode": "draft"}, false)
	var pair := await _screen_in_viewport(host.local_seat)
	var vp: SubViewport = pair[0]
	var gs: GameScreen = pair[1]
	assert_bool(await _wait(func(): return String(gs.view.get("stage", "")) == "decks" and gs.overlays.overlay.visible)).is_true()
	assert_bool(gs.chat.button.is_visible_in_tree()).is_true()   # J18
	gs.chat.open_box()
	await _pause(30)
	# The input line takes a click too (it is under the draft modal's dim in tree order).
	gs.chat.input.release_focus()
	await _click(vp, gs.chat.input)
	assert_bool(gs.chat.input.has_focus()).is_true()
	await _click(vp, gs.chat.close_button)
	assert_bool(gs.chat.is_open()).is_false()


func test_close_button_is_round_disc_only() -> void:
	var b: RoundCloseButton = auto_free(RoundCloseButton.new(30.0))
	b.size = b.custom_minimum_size
	var c := b.size / 2.0
	assert_bool(b._has_point(c)).is_true()
	assert_bool(b._has_point(c + Vector2(14, 0))).is_true()
	assert_bool(b._has_point(Vector2(1, 1))).is_false()   # the square's corner is not the button


func test_raise_for_input_puts_popover_after_lower_layers_only() -> void:
	var parent: Control = auto_free(Control.new())
	var pop := Control.new()
	pop.z_index = 95
	var dim := Control.new()
	var hover := Control.new()
	hover.z_index = 100
	for n in [pop, dim, hover]:
		parent.add_child(n)
	GameChat.raise_for_input(pop)
	assert_int(pop.get_index()).is_greater(dim.get_index())
	assert_int(hover.get_index()).is_greater(pop.get_index())


# ---------------------------------------------------------------- J17 / J19

func test_chat_box_has_no_key_hint_and_enter_still_sends(timeout := 30000) -> void:
	await _net()
	var gs := await _screen(host.local_seat)
	gs.chat.open_box()
	await await_idle_frame()
	for l in gs.chat.panel.find_children("*", "Label", true, false):
		assert_str((l as Label).text).not_contains("Enter sends")
	gs.chat.input.text = "hello table"
	gs.chat.input.text_submitted.emit(gs.chat.input.text)
	assert_bool(await _wait(func(): return gs.chat.history.get_parsed_text().contains("hello table"))).is_true()
	assert_str(gs.chat.input.text).is_empty()


func test_message_while_closed_pops_preview_and_badge(timeout := 30000) -> void:
	await _net()
	var gs := await _screen(host.local_seat)
	client.send_chat("Your move")
	assert_bool(await _wait(func(): return gs.chat.unread == 1)).is_true()
	assert_bool(gs.chat.peek.visible).is_true()
	assert_str(gs.chat.peek._text.text).is_equal("Your move")
	assert_str(gs.chat.peek.key).is_equal("p1")
	assert_bool(gs.chat.badge.visible).is_true()
	# The preview opens the chat when clicked, and the box clears both.
	gs.chat.peek.clicked.emit()
	assert_bool(gs.chat.is_open()).is_true()
	assert_bool(gs.chat.peek.visible).is_false()
	assert_int(gs.chat.unread).is_equal(0)


func test_own_message_while_closed_raises_no_alert(timeout := 30000) -> void:
	await _net()
	var gs := await _screen(host.local_seat)
	host.send_chat("me again")
	assert_bool(await _wait(func(): return gs.chat.history.get_parsed_text().contains("me again"))).is_true()
	assert_int(gs.chat.unread).is_equal(0)
	assert_bool(gs.chat.peek.visible).is_false()


# ---------------------------------------------------------------- J21

func test_spectator_chat_entry_carries_spectator_id(timeout := 30000) -> void:
	await _net()
	await _add_spectator()
	spec.send_chat("hi from the gallery")
	assert_bool(await _wait(func(): return client.chat_log.any(func(e): return String(e["text"]) == "hi from the gallery"))).is_true()
	for lg in [host.chat_log, client.chat_log]:
		var e: Dictionary = (lg as Array).filter(func(x): return String(x["text"]) == "hi from the gallery")[0]
		assert_int(int(e["sid"])).is_equal(spec.spectator_id)
		assert_str(GameChat.sender_key(e)).is_equal("s%d" % spec.spectator_id)


func test_muted_spectator_lines_and_alerts_are_hidden_locally(timeout := 30000) -> void:
	await _net()
	await _add_spectator()
	var gs := await _screen(host.local_seat)
	spec.send_chat("before mute")
	assert_bool(await _wait(func(): return gs.chat.history.get_parsed_text().contains("before mute"))).is_true()
	gs.chat.open_box()
	gs.chat.close_box()
	gs.chat.set_muted("s%d" % spec.spectator_id, true)
	assert_str(gs.chat.history.get_parsed_text()).not_contains("before mute")
	await _pause(25)
	spec.send_chat("after mute")
	assert_bool(await _wait(func(): return host.chat_log.any(func(e): return String(e["text"]) == "after mute"))).is_true()
	await _pause(5)
	assert_int(gs.chat.unread).is_equal(0)
	assert_bool(gs.chat.peek.visible).is_false()
	assert_str(gs.chat.history.get_parsed_text()).not_contains("after mute")
	# Local only: the other screens and the session's memory keep everything.
	assert_bool(client.chat_log.any(func(e): return String(e["text"]) == "after mute") or await _wait(func(): return client.chat_log.any(func(e): return String(e["text"]) == "after mute"))).is_true()
	gs.chat.set_muted("s%d" % spec.spectator_id, false)
	assert_str(gs.chat.history.get_parsed_text()).contains("after mute")


func test_viewer_cannot_mute_themselves(timeout := 30000) -> void:
	await _net()
	var gs := await _screen(host.local_seat)
	gs.chat.set_muted("p0", true)
	assert_bool(gs.chat.is_muted("p0")).is_false()


# ---------------------------------------------------------------- J22

func test_player_lobby_list_has_players_and_spectators_sections(timeout := 30000) -> void:
	await _net()
	var gs := await _screen(host.local_seat)
	# Always present (in the in-game menu, L12), even before anyone watches.
	assert_bool(gs.spectate.lobby_button.visible).is_false()   # L12: View lobby is in the menu only
	assert_bool((gs.menu.items["spectators"] as Button).visible).is_true()
	assert_bool(gs.spectate.badge.visible).is_false()
	await _add_spectator()
	assert_bool(await _wait(func(): return gs.spectate._chip.visible)).is_true()
	gs.spectate.toggle_list()
	var p := gs.spectate.panel
	assert_object(p.find_child("Section_Players", true, false)).is_not_null()
	assert_object(p.find_child("Section_Spectators", true, false)).is_not_null()
	assert_object(p.find_child("Mute_p1", true, false)).is_not_null()
	assert_object(p.find_child("Mute_p0", true, false)).is_null()           # not myself
	var row: Control = p.find_child("Player_1", true, false)
	assert_int(row.find_children("EyeToggle*", "", true, false).size()).is_equal(0)   # players: Mute only
	var srow: Control = p.find_child("Spectator_%d" % spec.spectator_id, true, false)
	assert_object(srow.find_child("EyeToggle*", true, false)).is_not_null()
	assert_object(srow.find_child("Mute_s%d" % spec.spectator_id, true, false)).is_not_null()
	# Mute from the list re-renders it as muted.
	(p.find_child("Mute_p1", true, false) as Button).pressed.emit()
	assert_bool(gs.chat.is_muted("p1")).is_true()
	assert_bool(bool((p.find_child("Mute_p1", true, false) as Button).get_meta("muted"))).is_true()
	assert_str((gs.menu.items["spectators"] as Button).text).is_equal("View lobby (1 watching)")


func test_spectator_lobby_list_offers_mute_but_no_permissions(timeout := 30000) -> void:
	await _net()
	await _add_spectator()
	var gs := await _screen(spec.local_seat)
	assert_bool(gs.is_spectator()).is_true()
	assert_bool(gs.spectate.lobby_button.visible).is_false()   # L12: View lobby is in the menu only
	assert_bool((gs.menu.items["spectators"] as Button).visible).is_true()
	assert_bool((gs.menu.items["spectators"] as Button).visible).is_true()
	gs.spectate.toggle_list()
	var p := gs.spectate.panel
	assert_object(p.find_child("Mute_p0", true, false)).is_not_null()
	assert_object(p.find_child("Mute_p1", true, false)).is_not_null()
	assert_object(p.find_child("EyeToggle*", true, false)).is_null()
	assert_object(p.find_child("Spectator_%d" % spec.spectator_id, true, false)).is_not_null()
	assert_object(p.find_child("Mute_s%d" % spec.spectator_id, true, false)).is_null()   # not myself
