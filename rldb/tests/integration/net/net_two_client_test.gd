extends GdUnitTestSuite
## Two real network peers (ENet over localhost) driving one authority.
## Covers response suspension, illegal/out-of-turn input, payload redaction,
## reconnect during a pending prompt and duplicate-command protection.

const PORT := 24711

var host: NetSession
var client: NetSession
var roots: Array = []
var host_errors: Array = []
var client_errors: Array = []


func before_test() -> void:
	host_errors = []
	client_errors = []
	var hroot := Node.new()
	hroot.name = "H"
	add_child(hroot)
	var croot := Node.new()
	croot.name = "C"
	add_child(croot)
	roots = [hroot, croot]
	host = NetSession.new()
	hroot.add_child(host)
	client = NetSession.new()
	croot.add_child(client)
	host.local_seat.status_changed.connect(func(t): host_errors.append(t))
	client.local_seat.status_changed.connect(func(t): client_errors.append(t))


func after_test() -> void:
	for n in roots:
		n.queue_free()
	roots = []
	for i in 5:
		await get_tree().process_frame


func _wait(cond: Callable, frames: int = 600) -> bool:
	for i in frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _client_view() -> Dictionary:
	return client.local_seat.last_view


## Starts a series where it is the client's (seat 1) turn 2 with a prepared board:
## client attacker (Water 10) vs host defender (Water 8) and a face-down Magic
## Cylinder plus a secret Shen in the host's hand.
func _setup_battle() -> Dictionary:
	assert_str(host.host_enet(PORT, {"seed": 99, "best_of": 3})).is_empty()
	assert_str(client.join_enet("127.0.0.1", PORT)).is_empty()
	assert_bool(await _wait(func(): return host.remote_peer != 0 and not _client_view().is_empty())).is_true()
	host.local_seat.send({"t": "pick_starter", "index": 0})
	client.local_seat.send({"t": "pick_starter", "index": 2})
	var ok := await _wait(func(): return host.series.stage == Series.STAGE_GAME)
	if not ok:
		print("DEBUG stage=", host.series.stage, " ready=", host.series.deck_ready, " herr=", host_errors, " cerr=", client_errors, " seq=", host.last_seq, " peer=", host.remote_peer)
	assert_bool(ok).is_true()
	var m: MatchEngine = host.series.game
	# Make sure the client is the active player on turn 2.
	if m.active == 0:
		host.local_seat.send({"t": "next_phase"})
		host.local_seat.send({"t": "next_phase"})
	else:
		client.local_seat.send({"t": "next_phase"})
		client.local_seat.send({"t": "next_phase"})
		assert_bool(await _wait(func(): return m.active == 0)).is_true()
		host.local_seat.send({"t": "next_phase"})
		host.local_seat.send({"t": "next_phase"})
		host.local_seat.send({"t": "next_phase"})
	assert_bool(await _wait(func(): return m.active == 1)).is_true()
	var atk := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	var def := TB.unit(m, 0, TB.WATER, 0, "atk", 8)
	var trap := TB.set_card(m, 0, 45, 0)
	var secret := TB.card(m, 0, 21, "hand")
	host._broadcast()
	await _wait(func(): return _client_view().get("match", {}).get("players", [{}, {"units": [null]}])[1]["units"][0] != null)
	return {"m": m, "atk": atk, "def": def, "trap": trap, "secret": secret}


func test_trap_prompt_suspends_remote_attacker_until_host_answers(timeout := 30000) -> void:
	var s := await _setup_battle()
	var m: MatchEngine = s["m"]
	client.local_seat.send({"t": "next_phase"})
	assert_bool(await _wait(func(): return m.phase == "battle")).is_true()
	client.local_seat.send({"t": "attack", "uid": s["atk"]})
	assert_bool(await _wait(func(): return _client_view()["match"]["pending"].get("kind", "") == "attack_target")).is_true()
	var pd: Dictionary = _client_view()["match"]["pending"]
	var idx := -1
	for o in pd["options"]:
		if o.has("ref") and o["ref"]["p"] == 0:
			idx = o["i"]
	client.local_seat.send({"t": "choose", "id": pd["id"], "indices": [idx]})
	assert_bool(await _wait(func(): return m.pending.get("kind", "") == "trap_response")).is_true()
	# The attacker cannot progress or answer the host's prompt.
	client.local_seat.send({"t": "next_phase"})
	client.local_seat.send({"t": "choose", "id": m.pending["id"], "indices": [0]})
	assert_bool(await _wait(func(): return client_errors.size() >= 2)).is_true()
	assert_str(client_errors[-2]).contains("Waiting")
	assert_str(client_errors[-1]).contains("other player")
	assert_str(m.phase).is_equal("battle")
	assert_bool(_client_view()["match"]["pending"]["mine"]).is_false()
	# The waiting client's payload does not expose the trap's identity or options.
	assert_bool(JSON.stringify(client.raw_received).contains("Magic Cylinder")).is_false()
	# Host activates Magic Cylinder: HP loss first, then battle.
	host.local_seat.send({"t": "choose", "id": m.pending["id"], "indices": [1]})
	assert_bool(await _wait(func(): return m.pending.is_empty() and m.stack.is_empty())).is_true()
	assert_int(m.players[1]["hp"]).is_equal(50)
	assert_int(m.players[0]["hp"]).is_equal(58)


func test_out_of_turn_and_foreign_card_commands_are_rejected(timeout := 30000) -> void:
	var s := await _setup_battle()
	var m: MatchEngine = s["m"]
	host.local_seat.send({"t": "next_phase"})
	assert_str(host_errors[-1]).is_equal("It is not your turn.")
	client.local_seat.send({"t": "sacrifice", "uid": s["def"]})
	assert_bool(await _wait(func(): return not client_errors.is_empty())).is_true()
	assert_str(client_errors[-1]).is_equal("Not your unit.")
	assert_str(m.cards[s["def"]]["zone"]).is_equal("unit")


func test_client_payloads_never_contain_host_hidden_cards(timeout := 30000) -> void:
	var s := await _setup_battle()
	await _wait(func(): return client.raw_received.size() > 0)
	var blob := JSON.stringify(client.raw_received)
	assert_bool(blob.contains("Shen the World Dragon")).is_false()
	assert_bool(blob.contains(str(s["secret"]))).is_false()
	assert_bool(blob.contains(str(s["trap"]))).is_false()
	for uid in host.series.game.players[0]["draw"]:
		assert_bool(blob.contains("\"uid\":%d" % uid)).is_false()
	var opp: Dictionary = _client_view()["match"]["players"][0]
	assert_bool(opp.has("hand")).is_false()
	assert_int(opp["counts"]["hand"]).is_greater(0)


func test_disconnect_pauses_and_reconnect_restores_pending_prompt_once(timeout := 40000) -> void:
	var s := await _setup_battle()
	var m: MatchEngine = s["m"]
	client.local_seat.send({"t": "next_phase"})
	assert_bool(await _wait(func(): return m.phase == "battle")).is_true()
	client.local_seat.send({"t": "attack", "uid": s["atk"]})
	assert_bool(await _wait(func(): return _client_view()["match"]["pending"].get("kind", "") == "attack_target")).is_true()
	var prompt_id: int = _client_view()["match"]["pending"]["id"]
	# Network drop while the client's own target prompt is pending.
	client.simulate_drop()
	assert_bool(await _wait(func(): return host.paused)).is_true()
	host.local_seat.send({"t": "concede"})
	assert_str(host_errors[-1]).contains("paused")
	assert_int(m.winner).is_equal(-1)
	# Client reconnects automatically with the same token; the same prompt is restored.
	assert_bool(await _wait(func(): return not host.paused and host.remote_peer != 0, 900)).is_true()
	assert_bool(await _wait(func(): return _client_view().get("net", {}).get("opponent_connected", false) or _client_view()["match"]["pending"].get("id", -1) == prompt_id)).is_true()
	var pd: Dictionary = _client_view()["match"]["pending"]
	assert_int(pd["id"]).is_equal(prompt_id)
	assert_str(pd["kind"]).is_equal("attack_target")
	var idx := -1
	for o in pd["options"]:
		if o.has("ref") and o["ref"]["p"] == 0:
			idx = o["i"]
	client.local_seat.send({"t": "choose", "id": pd["id"], "indices": [idx]})
	assert_bool(await _wait(func(): return m.pending.get("kind", "") == "trap_response")).is_true()
	host.local_seat.send({"t": "choose", "id": m.pending["id"], "indices": [0]})   # pass
	# Hidden response windows: the host still holds a face-down card, so later events
	# (the destruction) ask again; pass each one.
	for i in 5:
		await _wait(func(): return m.pending.get("kind", "") == "trap_response" or (m.stack.is_empty() and m.pending.is_empty()), 60)
		if m.pending.get("kind", "") == "trap_response":
			host.local_seat.send({"t": "choose", "id": m.pending["id"], "indices": [0]})
	assert_bool(await _wait(func(): return m.stack.is_empty() and m.pending.is_empty())).is_true()
	assert_str(m.cards[s["def"]]["zone"]).is_equal("spent")
	assert_int(m.players[0]["hp"]).is_equal(58)
	# Replaying the already-applied command sequence is ignored (no second attack).
	client.send_raw(1, {"t": "next_phase"})
	client.send_raw(client._seq, {"t": "attack", "uid": s["atk"]})
	await _wait(func(): return false, 30)
	assert_int(m.players[0]["hp"]).is_equal(58)
	assert_str(m.phase).is_equal("battle")
