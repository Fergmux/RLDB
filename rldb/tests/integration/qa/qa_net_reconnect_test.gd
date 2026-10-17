extends "res://tests/integration/qa/qa_net_base.gd"
## Adversarial QA: drop/reconnect during an optional trigger choice and during
## multi-selects (Arcane materials, Plan B targets); each completes exactly once.

const RITUAL_SANCT := 91
const TYDE := 172
const PLAN_B := 163


func port() -> int:
	return 24794


func _drop_and_return() -> void:
	client.simulate_drop()
	assert_bool(await _wait(func(): return host.paused)).is_true()
	assert_bool(await _wait(func(): return not host.paused and host.remote_peer != 0, 900)).is_true()
	assert_bool(await _wait(func(): return not client._awaiting_view)).is_true()


func test_reconnect_during_optional_start_of_turn_trigger_applies_once() -> void:
	# Arrange
	var m: MatchEngine = await _client_turn2()
	var u := TB.unit(m, 1, TB.WATER, 0)
	TB.power(m, 1, RITUAL_SANCT, 0)
	await _end_client_turn(m)
	for i in 3:
		host.local_seat.send({"t": "next_phase"})
	assert_bool(await _await_pending(m, 1, "select")).is_true()
	var pid: int = m.pending["id"]
	assert_array(_labels(cpend())).contains(["Skip"])
	# Act
	await _drop_and_return()
	assert_bool(await _wait(func(): return cpend().get("id", -1) == pid)).is_true()
	_client_choose(["your Basic Mage"])
	assert_bool(await _await_idle(m)).is_true()
	var seq := client._seq
	client.send_raw(seq, {"t": "choose", "id": pid, "indices": [1]})   # replayed command
	var n := client_errors.size()
	client.local_seat.send({"t": "choose", "id": pid, "indices": [1]}) # stale id, new seq
	assert_str(await _client_err_after(n)).contains("No such pending choice")
	# Assert
	assert_int(m.status_count(u, "rune")).is_equal(1)


func test_reconnect_during_arcane_material_multiselect_summons_once() -> void:
	# Arrange
	var m: MatchEngine = await _client_turn2()
	var tyde := TB.card(m, 1, TYDE, "extra")
	var mats := [TB.card(m, 1, TB.WATER, "spent"), TB.card(m, 1, TB.FIRE, "spent"), TB.card(m, 1, TB.EARTH, "spent")]
	var ex_before: int = m.players[1]["exhaust"].size()
	await _sync()
	client.local_seat.send({"t": "arcane", "uid": tyde})
	assert_bool(await _await_pending(m, 1, "select")).is_true()
	var pid: int = m.pending["id"]
	# Act
	await _drop_and_return()
	assert_bool(await _wait(func(): return cpend().get("id", -1) == pid)).is_true()
	var n := client_errors.size()
	_client_choose(["Basic Mage (Water)"])
	assert_str(await _client_err_after(n)).contains("required")
	n = client_errors.size()
	client.local_seat.send({"t": "choose", "id": pid, "indices": [0, 0]})
	assert_str(await _client_err_after(n)).contains("Duplicate")
	_client_choose(["Basic Mage (Water)", "Basic Mage (Earth)"])
	assert_bool(await _await_pending(m, 1, "slot")).is_true()
	var seq := client._seq
	client.send_raw(seq, {"t": "choose", "id": pid, "indices": [0, 2]})   # replay
	_client_choose(["column 1"])
	if await _await_pending(m, 1, "stance", 120):
		_client_choose(["Attack"])
	if await _await_pending(m, 1, "select", 120):
		_client_choose(["Skip"])                     # Tyde's optional Beast search (2026-10-17)
	assert_bool(await _await_idle(m)).is_true()
	# Assert
	assert_str(m.cards[tyde]["zone"]).is_equal("unit")
	assert_int(m.players[1]["exhaust"].size()).is_equal(ex_before + 2)
	assert_str(m.cards[mats[1]]["zone"]).is_equal("spent")
	assert_int(m.field_units(1).filter(func(x): return m.cards[x]["id"] == TYDE).size()).is_equal(1)


func test_drop_during_host_plan_b_selection_blocks_host_then_resolves_once() -> void:
	# Arrange
	var m: MatchEngine = await _client_turn2()
	var atk := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	var h1 := TB.unit(m, 0, TB.EARTH, 0)
	var h2 := TB.unit(m, 0, TB.FIRE, 1)
	TB.set_card(m, 0, PLAN_B, 0)
	await _sync()
	client.local_seat.send({"t": "next_phase"})
	assert_bool(await _wait(func(): return m.phase == "battle")).is_true()
	client.local_seat.send({"t": "attack", "uid": atk})
	assert_bool(await _await_pending(m, 1, "attack_target")).is_true()
	_client_choose(["Basic Mage (Earth)"])
	assert_bool(await _await_pending(m, 0, "trap_response")).is_true()
	_host_choose(["Plan B"])
	assert_bool(await _await_pending(m, 0, "select")).is_true()
	var pd := hpend()
	# Act
	client.simulate_drop()
	assert_bool(await _wait(func(): return host.paused)).is_true()
	host.local_seat.send({"t": "choose", "id": pd["id"], "indices": _idx(pd, ["Basic Mage (Fire)"])})
	assert_str(host_errors[-1]).contains("paused")
	assert_str(m.cards[h2]["zone"]).is_equal("unit")
	assert_bool(await _wait(func(): return not host.paused, 900)).is_true()
	host.local_seat.send({"t": "choose", "id": pd["id"], "indices": _idx(pd, ["Basic Mage (Fire)"])})
	host.local_seat.send({"t": "choose", "id": pd["id"], "indices": _idx(pd, ["Basic Mage (Fire)"])})   # double click
	assert_bool(await _await_idle(m)).is_true()
	# Assert: one destruction, one heal; battle then resolves against Earth (10 vs 8)
	assert_str(m.cards[h2]["zone"]).is_equal("spent")
	assert_int(TB.log_text(m).count("(Plan B, 1 destroyed)")).is_equal(1)
	assert_str(m.cards[h1]["zone"]).is_equal("spent")
	assert_int(m.players[0]["hp"]).is_equal(60 + 10 - 2)
