extends "res://tests/integration/qa/qa_net_base.gd"
## Adversarial QA: ordered trigger prompts on both sides (P-24 windows included),
## hostile/stale/malformed answers and malformed commands from the remote client.

const SOUL_DEVOURER := 76      # rune when any unit is sacrificed
const ENERGY_DISPEL := 140


func port() -> int:
	return 24792


func test_trigger_order_prompts_reject_stale_duplicate_out_of_range_and_foreign_answers() -> void:
	# Arrange
	var m: MatchEngine = await _client_turn2()
	var c0 := TB.unit(m, 1, SOUL_DEVOURER, 0)
	var c1 := TB.unit(m, 1, SOUL_DEVOURER, 1)
	var fodder := TB.unit(m, 1, TB.WATER, 2)
	var h0 := TB.unit(m, 0, SOUL_DEVOURER, 0)
	var h1 := TB.unit(m, 0, SOUL_DEVOURER, 1)
	TB.set_card(m, 0, ENERGY_DISPEL, 0)
	await _sync()
	# Act: sacrifice fires four non-self triggers (two per side)
	client.local_seat.send({"t": "sacrifice", "uid": fodder})
	assert_bool(await _await_pending(m, 1, "order")).is_true()     # active player's group first
	var pd := cpend()
	var pid: int = pd["id"]
	var bad := [
		[{"t": "choose", "id": pid - 1, "indices": [0]}, "No such pending choice"],
		[{"t": "choose", "id": pid, "indices": [7]}, "Invalid option"],
		[{"t": "choose", "id": pid, "indices": [-1]}, "Invalid option"],
		[{"t": "choose", "id": pid, "indices": [0, 0]}, "Duplicate option"],
		[{"t": "choose", "id": pid, "indices": [0, 1]}, "Choose between"],
		[{"t": "choose", "id": pid, "indices": []}, "Choose between"],
		[{"t": "choose", "id": pid, "indices": "0"}, "Malformed command"],
		[{"t": "choose", "id": pid, "values": [c0]}, "Invalid choice format"],
		[{"t": "next_phase"}, "Waiting"],
	]
	for b in bad:
		var n := client_errors.size()
		client.local_seat.send(b[0])
		assert_str(await _client_err_after(n)).contains(b[1])
		assert_int(m.pending["id"]).is_equal(pid)
	var hn := host_errors.size()
	host.local_seat.send({"t": "choose", "id": pid, "indices": [0]})
	assert_str(host_errors[hn]).contains("other player")
	# Client resolves the column-2 Soul Devourer first (not option order 0)
	var pick := -1
	for o in pd["options"]:
		if o.has("ref") and o["ref"]["slot"] == 1:
			pick = o["i"]
	client.local_seat.send({"t": "choose", "id": pid, "indices": [pick]})
	# P-24: the host may answer the triggered effect with Energy Dispel
	assert_bool(await _await_pending(m, 0, "trap_response")).is_true()
	_host_choose(["Energy Dispel"])
	assert_bool(await _await_pending(m, 0, "order")).is_true()
	var cn := client_errors.size()
	client.local_seat.send({"t": "choose", "id": m.pending["id"], "indices": [0]})
	assert_str(await _client_err_after(cn)).contains("other player")
	_host_choose(["Soul Devourer"])
	assert_bool(await _await_idle(m)).is_true()
	# Assert
	assert_str(m.cards[c1]["zone"]).is_equal("spent")          # negated and destroyed
	assert_int(m.status_count(c0, "rune")).is_equal(1)
	assert_int(m.status_count(h0, "rune")).is_equal(1)
	assert_int(m.status_count(h1, "rune")).is_equal(1)
	assert_int(m.players[1]["ap"]).is_greater(0)


func test_malformed_client_commands_are_rejected_and_host_keeps_working() -> void:
	# Arrange
	var m: MatchEngine = await _client_turn2()
	var u := TB.unit(m, 1, TB.WATER, 0)
	await _sync()
	var snapshot := JSON.stringify(MatchView.build(m, 0)["players"])
	var cmds := [
		{"t": 5},
		{},
		{"t": "attack", "uid": "abc"},
		{"t": "attack", "uid": [u]},
		{"t": "stance", "uid": {"x": 1}},
		{"t": "choose", "id": "x", "indices": [[0]]},
		{"t": "choose", "id": 1, "indices": [{"a": 1}]},
		{"t": "summon", "uid": 1.0e20},
		{"t": "ability", "uid": u, "idx": "zz"},
		{"t": "pick_starter", "index": 0},
		{"t": "reward_finish"},
		{"t": "claim_game"},
	]
	# Act
	for c in cmds:
		client.local_seat.send(c)
	client._c2s_command.rpc_id(1, client._seq + 100, "not a dictionary")
	await _wait(func(): return false, 60)
	# Assert: nothing changed, and a valid command still works
	assert_str(JSON.stringify(MatchView.build(m, 0)["players"])).is_equal(snapshot)
	assert_int(m.winner).is_equal(-1)
	assert_int(host.series.scores[0] + host.series.scores[1]).is_equal(0)
	client.local_seat.send({"t": "next_phase"})
	assert_bool(await _wait(func(): return m.phase == "battle")) \
		.override_failure_message("host stopped accepting client commands; errors=%s" % str(client_errors)).is_true()


func test_each_malformed_command_gets_an_error_reply() -> void:
	# A client that sends a malformed command must be told it failed (otherwise the
	# UI waits forever); a script error in the host aborts silently with no reply.
	var m: MatchEngine = await _client_turn2()
	var u := TB.unit(m, 1, TB.WATER, 0)
	await _sync()
	var silent := []
	for c in [{"t": 5}, {"t": "attack", "uid": [u]}, {"t": "choose", "id": 1, "indices": [{"a": 1}]}, {"t": "stance", "uid": {"x": 1}}]:
		var n := client_errors.size()
		client.local_seat.send(c)
		if await _client_err_after(n) == "":
			silent.append(JSON.stringify(c))
	assert_array(silent).override_failure_message("no error reply for: %s" % str(silent)).is_empty()
