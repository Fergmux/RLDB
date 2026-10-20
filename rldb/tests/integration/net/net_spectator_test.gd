extends GdUnitTestSuite
## A1 / A2 over real ENet sockets on localhost: a host, the seat-1 client and a third connection
## that becomes a spectator. Covers seat assignment, redaction with and without permission, the
## permission toggle, refused spectator commands, chat relay / cleaning / rate limit, cursor relay,
## joining mid-game and leaving.

const PORT := 24761
const SECRET := 34   # Dragon of the Cave: in no structure deck

var host: NetSession
var client: NetSession
var spec: NetSession
var roots: Array = []
var spec_errors: Array = []
var client_errors: Array = []
var cursors: Array = []


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	spec_errors = []
	client_errors = []
	cursors = []
	roots = []
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
	# One process stands in for three machines: give each joiner its own session token.
	client._token = "client-token-0001"
	spec._token = "spectator-token-01"
	client.local_seat.status_changed.connect(func(t): client_errors.append(t))
	spec.local_seat.status_changed.connect(func(t): spec_errors.append(t))
	spec.cursor_received.connect(func(s, p): cursors.append([s, p]))


func after_test() -> void:
	for n in roots:
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


func _sv() -> Dictionary:
	return spec.local_seat.last_view


func _join_both() -> void:
	assert_str(host.host_enet(PORT, {"seed": 5, "best_of": 3, "host_name": "Hostess"})).is_empty()
	assert_str(client.join_enet("127.0.0.1", PORT)).is_empty()
	assert_bool(await _wait(func(): return host.remote_peer != 0 and not client.local_seat.last_view.is_empty())).is_true()


func _join_spectator() -> void:
	assert_str(spec.join_enet("127.0.0.1", PORT)).is_empty()
	assert_bool(await _wait(func(): return spec.is_spectator and not _sv().is_empty())).is_true()


func _start_game() -> MatchEngine:
	host.local_seat.send({"t": "pick_starter", "index": 0})
	client.local_seat.send({"t": "pick_starter", "index": 2})
	assert_bool(await _wait(func(): return host.series.stage == Series.STAGE_GAME)).is_true()
	return host.series.game


## A secret in each hand and a face-down Magic Cylinder for seat 0; returns their uids.
func _plant(m: MatchEngine) -> Dictionary:
	var s0 := TB.card(m, 0, SECRET, "hand")
	var s1 := TB.card(m, 1, SECRET, "hand")
	var trap := TB.set_card(m, 0, 45, 0)
	host._broadcast()
	return {"s0": s0, "s1": s1, "trap": trap}


func _hidden_uids(m: MatchEngine, p: int) -> Array:
	var out := []
	for z in ["hand", "draw", "extra"]:
		out += m.players[p][z]
	for u in m.players[p]["backrow"]:
		if u != -1 and not m.is_face_up(u):
			out.append(u)
	return out


func _leaked(blob: String, uids: Array) -> Array:
	return uids.filter(func(u): return blob.contains("\"uid\":%d," % u) or blob.contains("\"uid\":%d}" % u))


func _hand_uids(v: Dictionary, p: int) -> Array:
	return v.get("match", {}).get("players", [{}, {}])[p].get("hand", []).map(func(c): return int(c["uid"]))


func test_third_connection_when_seats_full_becomes_spectator(timeout := 30000) -> void:
	await _join_both()
	var player_peer := host.remote_peer
	await _join_spectator()
	assert_int(host.spectators.size()).is_equal(1)
	assert_int(host.remote_peer).is_equal(player_peer)        # the player keeps seat 1
	assert_bool(_sv()["net"]["spectator"]).is_true()
	assert_bool(client.is_spectator).is_false()
	# Players see the spectator in their list, not allowed by default.
	assert_bool(await _wait(func(): return client.local_seat.last_view["net"]["spectators"].size() == 1)).is_true()
	var row: Dictionary = host.local_seat.last_view["net"]["spectators"][0]
	assert_bool(row["allowed"]).is_false()
	assert_int(int(row["id"])).is_equal(spec.spectator_id)


func test_spectator_payloads_without_permission_never_contain_hidden_cards(timeout := 30000) -> void:
	await _join_both()
	await _join_spectator()
	var m := await _start_game()
	var pl := _plant(m)
	assert_bool(await _wait(func(): return _sv().get("match", {}).get("players", [{}])[0].get("backrow", [null])[0] != null)).is_true()
	var blob := JSON.stringify(spec.raw_received)
	assert_str(blob).not_contains("Dragon of the Cave")
	assert_str(blob).not_contains("Magic Cylinder")
	assert_array(_leaked(blob, _hidden_uids(m, 0) + _hidden_uids(m, 1))).is_empty()
	for p in 2:
		assert_bool(_sv()["match"]["players"][p].has("hand")).is_false()
	assert_bool(_sv().has("tel_ids")).is_false()
	assert_bool(_sv().has("starters")).is_false()
	assert_int(int(pl["trap"])).is_greater(0)


func test_permission_toggle_reveals_that_players_cards_then_reverts(timeout := 30000) -> void:
	await _join_both()
	await _join_spectator()
	var m := await _start_game()
	var pl := _plant(m)
	# The client (seat 1) allows the spectator: the spectator turns to seat 1 and sees its hand.
	client.local_seat.send({"t": "spectator_allow", "id": spec.spectator_id})
	assert_bool(await _wait(func(): return _hand_uids(_sv(), 1).has(int(pl["s1"])))).is_true()
	assert_int(int(_sv()["match"]["you"])).is_equal(1)
	assert_bool(_sv()["net"]["allowed"]).is_true()
	assert_array(_sv()["match"]["actions"]).is_empty()
	assert_array(_leaked(JSON.stringify(_sv()["match"]["players"][0]), _hidden_uids(m, 0))).is_empty()
	assert_bool(await _wait(func(): return client.local_seat.last_view["net"]["spectators"][0]["allowed"])).is_true()
	# Revoked: back to the redacted view at once, and later payloads hold no hidden card.
	client.local_seat.send({"t": "spectator_revoke", "id": spec.spectator_id})
	assert_bool(await _wait(func(): return not _sv()["net"]["allowed"])).is_true()
	spec.raw_received.clear()
	host._broadcast()
	assert_bool(await _wait(func(): return not spec.raw_received.is_empty())).is_true()
	var blob := JSON.stringify(spec.raw_received)
	assert_array(_leaked(blob, _hidden_uids(m, 0) + _hidden_uids(m, 1))).is_empty()
	assert_str(blob).not_contains("Dragon of the Cave")


func test_spectator_follow_switches_orientation_without_revealing(timeout := 30000) -> void:
	await _join_both()
	await _join_spectator()
	await _start_game()
	spec.local_seat.send({"t": "spectate_follow", "who": 1})
	assert_bool(await _wait(func(): return int(_sv()["match"]["you"]) == 1)).is_true()
	assert_bool(_sv()["match"]["players"][1].has("hand")).is_false()


func test_spectator_game_commands_are_refused_by_host(timeout := 30000) -> void:
	await _join_both()
	await _join_spectator()
	var m := await _start_game()
	var before := [m.turn, m.phase, m.active]
	# Locally blocked ...
	spec.local_seat.send({"t": "next_phase"})
	assert_str(spec_errors[-1]).is_equal(NetSession.SPECTATOR_REFUSED)
	# ... and refused by the host when sent anyway (a modified client).
	spec_errors.clear()
	spec.send_raw(50, {"t": "next_phase"})
	spec.send_raw(51, {"t": "concede"})
	spec.send_raw(52, {"t": "spectator_allow", "id": spec.spectator_id})
	spec.send_raw(53, {"t": "forfeit_series"})
	assert_bool(await _wait(func(): return spec_errors.size() >= 4)).is_true()
	for e in spec_errors:
		assert_str(e).is_equal(NetSession.SPECTATOR_REFUSED)
	assert_array([m.turn, m.phase, m.active]).is_equal(before)
	assert_int(m.winner).is_equal(-1)
	assert_str(host.series.stage).is_equal(Series.STAGE_GAME)
	assert_bool(host.spectator_allow[0].is_empty() and host.spectator_allow[1].is_empty()).is_true()


func test_chat_is_relayed_to_everyone_cleaned_and_marked(timeout := 30000) -> void:
	await _join_both()
	await _join_spectator()
	assert_str(client.send_chat("[color=red]hello[/color]   there\n")).is_empty()
	var said := func(s: NetSession, text: String, role: String) -> bool:
		return s.chat_log.any(func(e): return e["text"] == text and e["role"] == role)
	assert_bool(await _wait(func(): return said.call(host, "hello there", "player") and said.call(spec, "hello there", "player"))).is_true()
	var e: Dictionary = spec.chat_log.filter(func(x): return x["text"] == "hello there")[0]
	assert_int(int(e["seat"])).is_equal(1)
	assert_bool(e.has("at")).is_true()
	# A spectator's message reaches both players, marked as a spectator.
	await _wait(func(): return false, 25)
	assert_str(spec.send_chat("nice play")).is_empty()
	assert_bool(await _wait(func(): return said.call(host, "nice play", "spectator") and said.call(client, "nice play", "spectator"))).is_true()
	# The host's own message, capped at the maximum length.
	await _wait(func(): return false, 25)
	host.send_chat("x".repeat(500))
	assert_bool(await _wait(func(): return client.chat_log.any(func(x): return x["text"] == "x".repeat(NetChat.MAX_LEN)))).is_true()
	# The joining notice was a system line.
	assert_bool(client.chat_log.any(func(x): return x["role"] == "system" and String(x["text"]).contains("spectating"))).is_true()


func test_chat_flood_from_modified_client_is_rate_limited_by_host(timeout := 30000) -> void:
	await _join_both()
	# Bypass the client's own guard: straight RPCs, as a modified client would send them.
	for i in 12:
		client._c2s_chat.rpc_id(1, "spam %d" % i)
	assert_bool(await _wait(func(): return client.chat_log.any(func(x): return x["role"] == "notice"))).is_true()
	await _wait(func(): return false, 20)
	var relayed := host.chat_log.filter(func(x): return String(x["text"]).begins_with("spam"))
	assert_int(relayed.size()).is_less_equal(NetChat.BURST)
	assert_int(relayed.size()).is_greater_equal(1)


func test_cursor_reaches_only_a_spectator_the_player_allowed(timeout := 30000) -> void:
	await _join_both()
	await _join_spectator()
	await _start_game()
	# Not allowed: nothing is relayed.
	for i in 5:
		host._cursor_last = [0, 0]
		host.send_cursor(Vector2(0.25, 0.5))
		await get_tree().process_frame
	await _wait(func(): return false, 20)
	assert_array(cursors).is_empty()
	assert_bool(host.cursor_wanted()).is_false()
	# Allowed by the host (seat 0): the spectator follows seat 0 and gets its cursor.
	host.local_seat.send({"t": "spectator_allow", "id": spec.spectator_id})
	assert_bool(host.cursor_wanted()).is_true()
	assert_bool(await _wait(func(): return bool(_sv()["net"]["allowed"]))).is_true()
	var got := await _wait(func():
		host._cursor_last = [0, 0]
		host.send_cursor(Vector2(0.25, 0.5))
		return not cursors.is_empty())
	assert_bool(got).is_true()
	assert_int(int(cursors[-1][0])).is_equal(0)
	assert_float((cursors[-1][1] as Vector2).x).is_equal_approx(0.25, 0.0001)
	# The client's cursor is not sent to a spectator only seat 0 allowed.
	cursors.clear()
	for i in 5:
		host._cursor_last = [0, 0]
		client.send_cursor(Vector2(0.75, 0.1))
		await get_tree().process_frame
	await _wait(func(): return false, 20)
	assert_bool(cursors.any(func(c): return int(c[0]) == 1)).is_false()
	# Garbage positions are dropped.
	assert_bool(CursorTrack.valid(Vector2(INF, 0))).is_false()


func test_spectator_joining_mid_game_gets_the_board_and_log_without_secrets(timeout := 30000) -> void:
	await _join_both()
	var m := await _start_game()
	var pl := _plant(m)
	var u := TB.unit(m, 0, TB.WATER, 1)
	host._broadcast()
	await _join_spectator()
	var mv: Dictionary = _sv()["match"]
	assert_str(String(_sv()["stage"])).is_equal("game")
	assert_int(int(mv["players"][0]["units"][1]["uid"])).is_equal(u)
	assert_bool(mv["log"].size() > 0).is_true()
	assert_bool(_sv().get("log_reset", false)).is_true()
	var blob := JSON.stringify(spec.raw_received)
	assert_array(_leaked(blob, _hidden_uids(m, 0) + _hidden_uids(m, 1))).is_empty()
	assert_bool(blob.contains("\"uid\":%d," % int(pl["s0"]))).is_false()


func test_spectator_leaving_clears_list_and_permissions(timeout := 30000) -> void:
	await _join_both()
	await _join_spectator()
	host.local_seat.send({"t": "spectator_allow", "id": spec.spectator_id})
	assert_bool(host.spectator_allow[0].has(spec.spectator_id)).is_true()
	spec.host_gone = true                 # leaving on purpose: no reconnect
	spec._reconnect_timer.stop()
	spec.api.multiplayer_peer.close()
	assert_bool(await _wait(func(): return host.spectators.is_empty())).is_true()
	assert_bool(host.spectator_allow[0].is_empty()).is_true()
	assert_bool(await _wait(func(): return client.local_seat.last_view["net"]["spectators"].is_empty())).is_true()
	assert_bool(host.chat_log.any(func(x): return String(x["text"]).contains("stopped spectating"))).is_true()
	assert_int(host.remote_peer).is_not_equal(0)   # the players are untouched


func test_spectator_cap_refuses_extra_watchers(timeout := 30000) -> void:
	await _join_both()
	# Fill the spectator slots with fake entries, then a real joiner is refused.
	for i in NetSession.MAX_SPECTATORS:
		host.spectators[90000 + i] = {"id": 900 + i, "name": "Ghost", "token": "ghost%02d-token-xx" % i, "follow": 0, "log_sent": 0, "log_game": -1}
	spec.join_enet("127.0.0.1", PORT)
	assert_bool(await _wait(func(): return spec_errors.has(NetSession.SPECTATORS_FULL))).is_true()
	assert_bool(spec.is_spectator).is_false()
	for i in NetSession.MAX_SPECTATORS:
		host.spectators.erase(90000 + i)
