extends GdUnitTestSuite
## Shared harness for adversarial two-client QA suites: one host NetSession and one
## client NetSession over real ENet localhost. Not a test suite on its own (no tests).

var host: NetSession
var client: NetSession
var roots: Array = []
var host_errors: Array = []
var client_errors: Array = []
var client_payloads: Array = []    # JSON of every view the client received (after log merge)


func port() -> int:
	return 24790


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	await _make_sessions()


func _make_sessions() -> void:
	host_errors = []
	client_errors = []
	client_payloads = []
	var hroot := Node.new()
	add_child(hroot)
	var croot := Node.new()
	add_child(croot)
	roots = [hroot, croot]
	host = NetSession.new()
	hroot.add_child(host)
	client = NetSession.new()
	croot.add_child(client)
	host.local_seat.status_changed.connect(func(t): host_errors.append(t))
	client.local_seat.status_changed.connect(func(t): client_errors.append(t))
	client.local_seat.view_changed.connect(func(v): client_payloads.append(JSON.stringify(v)))


func after_test() -> void:
	await _teardown()


func _teardown() -> void:
	for n in roots:
		if is_instance_valid(n):
			n.queue_free()
	roots = []
	for i in 8:
		await get_tree().process_frame


func _wait(cond: Callable, frames: int = 600) -> bool:
	var deadline := Time.get_ticks_msec() + frames * 1000 / 60
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func cview() -> Dictionary:
	return client.local_seat.last_view


func cpend() -> Dictionary:
	return cview().get("match", {}).get("pending", {})


func hpend() -> Dictionary:
	return host.local_seat.last_view.get("match", {}).get("pending", {})


## Starts a starter-deck series and returns the host-side engine once game 1 runs.
func _start(cfg: Dictionary = {"seed": 99, "best_of": 3}) -> MatchEngine:
	assert_str(host.host_enet(port(), cfg)).is_empty()
	assert_str(client.join_enet("127.0.0.1", port())).is_empty()
	assert_bool(await _wait(func(): return host.remote_peer != 0 and not cview().is_empty())).is_true()
	host.local_seat.send({"t": "pick_starter", "index": 0})
	client.local_seat.send({"t": "pick_starter", "index": 2})
	assert_bool(await _wait(func(): return host.series.stage == Series.STAGE_GAME)).is_true()
	return host.series.game


## Makes it the client's (seat 1) turn 2, Main Phase 1.
func _client_turn2() -> MatchEngine:
	var m: MatchEngine = await _start()
	if m.active == 0:
		host.local_seat.send({"t": "next_phase"})
		host.local_seat.send({"t": "next_phase"})
	else:
		client.local_seat.send({"t": "next_phase"})
		client.local_seat.send({"t": "next_phase"})
		assert_bool(await _wait(func(): return m.active == 0)).is_true()
		for i in 3:
			host.local_seat.send({"t": "next_phase"})
	assert_bool(await _wait(func(): return m.active == 1 and m.phase == "main1")).is_true()
	return m


## Ends the client's turn from any of its phases and waits for the host's turn.
func _end_client_turn(m: MatchEngine) -> void:
	var t := m.turn
	for i in 4:
		if m.turn != t:
			break
		var before := client_errors.size()
		var ph := m.phase
		client.local_seat.send({"t": "next_phase"})
		await _wait(func(): return m.phase != ph or m.turn != t or client_errors.size() > before, 120)
	assert_bool(await _wait(func(): return m.active == 0 and m.turn == t + 1)).is_true()


func _sync() -> void:
	host._broadcast()
	await _wait(func(): return false, 10)


func _labels(pd: Dictionary) -> Array:
	return pd.get("options", []).map(func(o): return String(o["label"]))


## Index list of options whose labels contain each text in order (from a redacted view).
func _idx(pd: Dictionary, texts: Array) -> Array:
	var out := []
	for t in texts:
		var found := -1
		for o in pd.get("options", []):
			# Basic-unit names no longer carry their Type (F03-09): also match "Name (Type)".
			var hay := String(o["label"])
			var c: Dictionary = o.get("card", {})
			if String(c.get("type", "")) != "":
				hay += " | %s (%s)" % [String(c["name"]), String(c["type"])]
			if hay.contains(t) and not (int(o["i"]) in out):
				found = int(o["i"])
				break
		assert_int(found).override_failure_message("option '%s' not in %s" % [t, str(_labels(pd))]).is_not_equal(-1)
		out.append(found)
	return out


func _client_choose(texts: Array) -> void:
	var pd := cpend()
	client.local_seat.send({"t": "choose", "id": pd["id"], "indices": _idx(pd, texts)})


func _host_choose(texts: Array) -> void:
	var pd := hpend()
	host.local_seat.send({"t": "choose", "id": pd["id"], "indices": _idx(pd, texts)})


## Waits until seat p has a pending choice of `kind` and the client view reflects it.
func _await_pending(m: MatchEngine, p: int, kind: String, frames: int = 600) -> bool:
	var ok := await _wait(func(): return m.pending.get("kind", "") == kind and m.pending["player"] == p, frames)
	if not ok:
		print("QA DEBUG pending=", m.pending.get("kind", ""), "/", m.pending.get("player", -1), " herr=", host_errors, " cerr=", client_errors)
		return false
	var id: int = m.pending["id"]
	if p == 1:
		return await _wait(func(): return cpend().get("id", -1) == id and cpend().get("mine", false))
	return await _wait(func(): return hpend().get("id", -1) == id)


func _await_idle(m: MatchEngine) -> bool:
	return await _wait(func(): return m.pending.is_empty() and m.stack.is_empty())


## Waits for a new client error and returns it ("" on timeout).
func _client_err_after(n: int) -> String:
	await _wait(func(): return client_errors.size() > n, 120)
	return client_errors[-1] if client_errors.size() > n else ""


func _blob() -> String:
	return "\n".join(client_payloads)
