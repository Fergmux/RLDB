extends "res://tests/integration/qa/qa_net_base.gd"
## Adversarial QA: between-game save/resume over the network, host claim (P-02),
## fatigue ending a networked game (C-04), concede during a pending choice and
## commands sent during series stage transitions.

const MAGIC_CYLINDER := 45


func port() -> int:
	return 24795


func test_series_resumes_from_save_with_same_client_and_refuses_other_token() -> void:
	# Arrange: game 1 ends (host concedes), rewards partly taken, checkpoint saved
	var m: MatchEngine = await _start()
	host.local_seat.send({"t": "concede"})
	assert_bool(await _wait(func(): return host.series.stage == Series.STAGE_REWARDS)).is_true()
	assert_bool(await _wait(func(): return cview().get("stage", "") == "rewards")).is_true()
	client.local_seat.send({"t": "reward_type", "category": "unit"})
	client.local_seat.send({"t": "reward_add", "index": 0})
	assert_bool(await _wait(func(): return host.series.rewards[1]["left"] == 3 and not host.series.rewards[1]["pending"])).is_true()
	host.local_seat.send({"t": "reward_finish"})
	assert_bool(await _wait(func(): return host.series.rewards[0]["done"])).is_true()
	var save_id := host.series.save_id
	var decks: Array = host.series.decks.duplicate(true)
	var token := client._token
	await _teardown()
	# Act 1: new host resumes from disk; an impostor with another token tries first
	var resumed := SeriesStore.load_series(save_id)
	assert_object(resumed).is_not_null()
	await _make_sessions()
	assert_str(host.host_enet(port(), {"resume": resumed})).is_empty()
	var iroot := Node.new()
	add_child(iroot)
	roots.append(iroot)
	var impostor := NetSession.new()
	iroot.add_child(impostor)
	var imp_errors := []
	impostor.local_seat.status_changed.connect(func(t): imp_errors.append(t))
	impostor._token = "deadbeefdeadbeefdeadbeef"
	assert_str(impostor.join_enet("127.0.0.1", port())).is_empty()
	assert_bool(await _wait(func(): return imp_errors.any(func(e): return String(e).contains("another player")))).is_true()
	assert_int(host.remote_peer).is_equal(0)
	assert_bool(impostor.local_seat.last_view.is_empty()).is_true()
	iroot.queue_free()
	await _wait(func(): return false, 20)
	# Act 2: the original client returns with its persisted token
	assert_str(client.join_enet("127.0.0.1", port())).is_empty()
	assert_bool(await _wait(func(): return host.remote_peer != 0 and cview().get("stage", "") == "rewards", 900)).is_true()
	assert_str(client._token).is_equal(token)
	# Assert: score, decks and reward progress continue
	assert_array(host.series.scores).is_equal([0, 1])
	assert_array(host.series.decks).is_equal(decks)
	assert_int(cview()["rewards"]["left"]).is_equal(3)
	assert_bool(cview()["rewards"]["opponent_done"]).is_true()
	client.local_seat.send({"t": "reward_finish"})
	assert_bool(await _wait(func(): return host.series.stage == Series.STAGE_FIRST)).is_true()
	var n := client_errors.size()
	client.local_seat.send({"t": "first_player", "who": 1})            # winner may not choose
	assert_str(await _client_err_after(n)).contains("loser")
	host.local_seat.send({"t": "first_player", "who": 1})
	host.local_seat.send({"t": "start_duel"})                          # G05: each seat starts the duel
	client.local_seat.send({"t": "start_duel"})
	assert_bool(await _wait(func(): return host.series.stage == Series.STAGE_GAME and host.series.game_no == 2)).is_true()
	assert_int(host.series.game.active).is_equal(1)
	assert_bool(await _wait(func(): return cview().get("game_no", 0) == 2 and cview().has("match"))).is_true()


func test_host_claim_awards_current_game_only_then_client_returns_and_series_continues() -> void:
	# Arrange: client away while its own attack-target prompt is pending
	var m: MatchEngine = await _client_turn2()
	var atk := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	TB.unit(m, 0, TB.WATER, 0)
	await _sync()
	host.local_seat.send({"t": "claim_game"})
	assert_str(host_errors[-1]).contains("connected")                 # opponent present
	client.local_seat.send({"t": "next_phase"})
	assert_bool(await _wait(func(): return m.phase == "battle")).is_true()
	client.local_seat.send({"t": "attack", "uid": atk})
	assert_bool(await _await_pending(m, 1, "attack_target")).is_true()
	client._reconnect_timer.stop()
	client.host_gone = true
	client.simulate_drop()
	assert_bool(await _wait(func(): return host.paused)).is_true()
	# Act
	host.local_seat.send({"t": "claim_game"})
	assert_str(host_errors[-1]).contains("claim the game in")
	host.claim_wait_seconds = 0
	host.local_seat.send({"t": "claim_game"})
	# Assert
	assert_array(host.series.scores).is_equal([1, 0])
	assert_str(host.series.stage).is_equal(Series.STAGE_REWARDS)
	assert_bool(m.pending.is_empty()).override_failure_message("finished game still has pending %s" % str(m.pending.get("kind", ""))).is_true()
	host.local_seat.send({"t": "claim_game"})
	assert_str(host_errors[-1]).contains("no game in progress")       # no second claim
	# The client comes back; series continues normally.
	client.host_gone = false
	assert_str(client.join_enet("127.0.0.1", port())).is_empty()
	assert_bool(await _wait(func(): return not host.paused and cview().get("stage", "") == "rewards", 900)).is_true()
	assert_bool(cview()["match"]["pending"].is_empty()).override_failure_message("client sees a live prompt in a finished game").is_true()
	host.local_seat.send({"t": "reward_finish"})
	client.local_seat.send({"t": "reward_finish"})
	assert_bool(await _wait(func(): return host.series.stage == Series.STAGE_FIRST)).is_true()
	client.local_seat.send({"t": "first_player", "who": 1})
	client.local_seat.send({"t": "start_duel"})                        # G05
	host.local_seat.send({"t": "start_duel"})
	assert_bool(await _wait(func(): return host.series.game_no == 2 and host.series.stage == Series.STAGE_GAME)).is_true()
	assert_array(host.series.scores).is_equal([1, 0])


func test_fatigue_ends_networked_game_and_client_sees_result() -> void:
	# Arrange: host has no Draw and no Spent; 4 missed draws x 2 = 8 HP
	var m: MatchEngine = await _client_turn2()
	for z in ["draw", "spent"]:
		for u in m.players[0][z]:
			m.cards[u]["zone"] = "exhaust"
			m.players[0]["exhaust"].append(u)
		m.players[0][z] = []
	m.players[0]["hp"] = 8
	await _sync()
	# Act
	var t := m.turn
	for i in 3:
		var ph := m.phase
		client.local_seat.send({"t": "next_phase"})
		await _wait(func(): return m.phase != ph or m.winner != -1, 120)
	# Assert
	assert_bool(await _wait(func(): return m.winner == 1)).is_true()
	assert_int(m.players[0]["hp"]).is_equal(0)
	assert_str(TB.log_text(m)).contains("(fatigue)")
	assert_array(host.series.scores).is_equal([0, 1])
	assert_str(host.series.stage).is_equal(Series.STAGE_REWARDS)
	assert_bool(await _wait(func(): return cview().get("stage", "") == "rewards" and cview()["match"]["winner"] == 1)).is_true()


func test_concede_during_opponent_trap_prompt_ends_game_without_stale_prompt() -> void:
	# Arrange
	var m: MatchEngine = await _client_turn2()
	var atk := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	TB.unit(m, 0, TB.WATER, 0)
	TB.set_card(m, 0, MAGIC_CYLINDER, 0)
	await _sync()
	client.local_seat.send({"t": "next_phase"})
	assert_bool(await _wait(func(): return m.phase == "battle")).is_true()
	client.local_seat.send({"t": "attack", "uid": atk})
	assert_bool(await _await_pending(m, 1, "attack_target")).is_true()
	_client_choose(["Basic Mage (Water)"])
	assert_bool(await _await_pending(m, 0, "trap_response")).is_true()
	var pid: int = m.pending["id"]
	# Act
	client.local_seat.send({"t": "concede"})
	assert_bool(await _wait(func(): return m.winner == 0)).is_true()
	# Assert
	assert_str(host.series.stage).is_equal(Series.STAGE_REWARDS)
	host.local_seat.send({"t": "choose", "id": pid, "indices": [1]})
	assert_int(m.players[1]["hp"]).is_equal(60)                         # dead prompt cannot fire
	assert_bool(m.pending.is_empty()).override_failure_message("pending %s survives game over" % str(m.pending.get("kind", ""))).is_true()
	assert_bool(m.stack.is_empty()).override_failure_message("stack of %d frames survives game over" % m.stack.size()).is_true()
	assert_bool(hpend().is_empty()).override_failure_message("host view still shows a prompt after game over").is_true()


func test_commands_sent_across_stage_transitions_are_refused_cleanly() -> void:
	# Arrange
	var m: MatchEngine = await _start()
	host.local_seat.send({"t": "concede"})
	assert_bool(await _wait(func(): return host.series.stage == Series.STAGE_REWARDS and cview().get("stage", "") == "rewards")).is_true()
	var deck_before: Array = host.series.decks[1].duplicate()
	# Act / Assert: game, deck and first-player commands during rewards
	for pair in [[{"t": "next_phase"}, "reward"], [{"t": "pick_starter", "index": 1}, "reward"],
			[{"t": "first_player", "who": 1}, "reward"], [{"t": "reward_add", "index": 99}, "type first"],
			[{"t": "reward_type", "category": "nope"}, "card type"],
			[{"t": "reward_remove", "card_id": 999999}, "not in your deck"], [{"t": "reward_basic", "to_type": "Nope", "to_race": "Mage"}, "Type and a Race"]]:
		var n := client_errors.size()
		client.local_seat.send(pair[0])
		assert_str(await _client_err_after(n)).contains(pair[1])
	assert_array(host.series.decks[1]).is_equal(deck_before)
	client.local_seat.send({"t": "reward_finish"})
	assert_bool(await _wait(func(): return host.series.rewards[1]["done"])).is_true()
	var n2 := client_errors.size()
	client.local_seat.send({"t": "reward_add", "index": 0})
	assert_str(await _client_err_after(n2)).contains("finished")
	host.local_seat.send({"t": "reward_finish"})
	assert_bool(await _wait(func(): return host.series.stage == Series.STAGE_FIRST)).is_true()
	host.local_seat.send({"t": "first_player", "who": 0})            # host lost: may choose
	assert_bool(await _wait(func(): return cview().get("next", {}).get("first_chosen", false))).is_true()
	assert_str(host.series.stage).is_equal(Series.STAGE_FIRST)        # G05: not started by the choice
	host.local_seat.send({"t": "start_duel"})
	client.local_seat.send({"t": "start_duel"})
	assert_bool(await _wait(func(): return host.series.stage == Series.STAGE_GAME)).is_true()
	var n3 := client_errors.size()
	client.local_seat.send({"t": "first_player", "who": 1})          # stale transition command
	assert_str(await _client_err_after(n3)).is_not_empty()
	assert_int(host.series.game_no).is_equal(2)
	assert_int(host.series.game.active).is_equal(0)


## Review fix: the host can forfeit (in-game menu Return / Quit) while the client is away; the
## series ends instead of the command being refused as "paused".
func test_host_can_forfeit_while_opponent_is_disconnected() -> void:
	await _start()
	client._reconnect_timer.stop()
	client.host_gone = true
	client.simulate_drop()
	assert_bool(await _wait(func(): return host.paused)).is_true()
	host.local_seat.send({"t": "forfeit_series"})
	assert_bool(await _wait(func(): return host.series.stage == Series.STAGE_OVER)).is_true()
	assert_int(host.series.forfeit_by).is_equal(0)
	client.host_gone = false
