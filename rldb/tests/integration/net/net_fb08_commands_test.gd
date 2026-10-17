extends GdUnitTestSuite
## Feedback 08 commands over a real ENet connection: the host refuses a client's `suspend` during
## a duel and a `start_duel` outside who-goes-first, and validates a client's attack `mode`.

const PORT := 24731

var host: NetSession
var client: NetSession
var roots: Array = []
var host_errors: Array = []
var client_errors: Array = []


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
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


## Waits for cond up to `frames` x 1/60 s of real time (independent of frame rate).
func _wait(cond: Callable, frames: int = 600) -> bool:
	var deadline := Time.get_ticks_msec() + frames * 1000 / 60
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


## Connects both peers and starts duel 1.
func _start_duel() -> MatchEngine:
	assert_str(host.host_enet(PORT, {"seed": 99, "best_of": 3})).is_empty()
	assert_str(client.join_enet("127.0.0.1", PORT)).is_empty()
	assert_bool(await _wait(func(): return host.remote_peer != 0 and not client.local_seat.last_view.is_empty())).is_true()
	host.local_seat.send({"t": "pick_starter", "index": 0})
	client.local_seat.send({"t": "pick_starter", "index": 2})
	assert_bool(await _wait(func(): return host.series.stage == Series.STAGE_GAME)).is_true()
	return host.series.game


func test_client_suspend_during_a_duel_is_refused_and_play_continues(timeout := 30000) -> void:
	var m := await _start_duel()
	client.local_seat.send({"t": "suspend"})
	assert_bool(await _wait(func(): return not client_errors.is_empty())).is_true()
	assert_str(client_errors[-1]).contains("between duels")
	assert_bool(host.opponent_suspended).is_false()
	assert_str(host.series.stage).is_equal(Series.STAGE_GAME)
	assert_object(host.series.game).is_same(m)


func test_client_start_duel_outside_who_goes_first_is_refused(timeout := 30000) -> void:
	await _start_duel()
	client.local_seat.send({"t": "start_duel"})
	assert_bool(await _wait(func(): return not client_errors.is_empty())).is_true()
	assert_str(host.series.stage).is_equal(Series.STAGE_GAME)


func test_client_attack_with_a_forged_direct_mode_is_refused(timeout := 30000) -> void:
	var m := await _start_duel()
	# Make it the client's (seat 1) Battle Phase with an ordinary attacker and a host unit.
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
	TB.unit(m, 0, TB.WATER, 0, "atk", 8)
	host._broadcast()
	client.local_seat.send({"t": "next_phase"})
	assert_bool(await _wait(func(): return m.phase == "battle")).is_true()
	var hp := int(m.players[0]["hp"])
	var n := client_errors.size()
	client.local_seat.send({"t": "attack", "uid": atk, "mode": "direct"})
	assert_bool(await _wait(func(): return client_errors.size() > n)).is_true()
	assert_bool(m.pending.is_empty() and m.stack.is_empty()).is_true()
	assert_int(int(m.players[0]["hp"])).is_equal(hp)
	assert_int(int(m.cards[atk].get("attacked_turn", -1))).is_not_equal(m.turn)
