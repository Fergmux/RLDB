extends "res://tests/integration/qa/qa_net_base.gd"
## Adversarial QA of playtest-feedback-02 over real ENet: stance-carrying summon commands
## from the remote client (F02-02), malformed stance payloads, the hidden-card stance probe,
## and the raw payloads the client receives (preview/abilities/text_parts).
## Report: production/qa/qa-f02-adversarial-2026-10-15.md

const MUMENS_BOUNTY := 150     # no_defense


func port() -> int:
	return 24797


## B3 (owner feedback 2026-10-20): the client summons (Attack stance, no prompt), then changes the
## unit to Defense with the ordinary stance command.
func test_client_summon_then_defense_keeps_both_views_consistent() -> void:
	# Arrange
	var m: MatchEngine = await _client_turn2()
	var u := TB.card(m, 1, TB.WATER)
	m.players[1]["ap"] = 5
	await _sync()
	var ap0: int = m.players[1]["ap"]
	# Act
	client.local_seat.send({"t": "summon", "uid": u})
	assert_bool(await _await_pending(m, 1, "slot")).is_true()
	_client_choose([TB.slot_label(4)])
	assert_bool(await _await_idle(m)).is_true()
	assert_str(m.cards[u]["stance"]).is_equal("atk")
	client.local_seat.send({"t": "stance", "uid": u})
	await _sync()
	assert_bool(await _await_idle(m)).is_true()
	await _sync()
	# Assert: authority, client's own view and the host's view of the opponent all agree
	assert_str(m.cards[u]["stance"]).is_equal("def")
	assert_int(m.players[1]["ap"]).is_equal(ap0 - m.current_cost(u))
	var cu: Dictionary = cview()["match"]["players"][1]["units"][4]
	var hu: Dictionary = host.local_seat.last_view["match"]["players"][1]["units"][4]
	assert_str(cu["stance"]).is_equal("def")
	assert_str(hu["stance"]).is_equal("def")
	assert_int(int(cview()["match"]["players"][1]["ap"])).is_equal(m.players[1]["ap"])
	assert_int(int(host.local_seat.last_view["match"]["players"][1]["ap"])).is_equal(m.players[1]["ap"])


func test_client_malformed_stance_commands_are_rejected_without_state_change() -> void:
	# Arrange
	var m: MatchEngine = await _client_turn2()
	var u := TB.card(m, 1, TB.WATER)
	var f := TB.unit(m, 1, TB.WATER, 0)
	m.players[1]["ap"] = 5
	await _sync()
	var cases := [
		[{"t": "summon", "uid": u, "stance": ["def"]}, "Malformed"],
		[{"t": "summon", "uid": u, "stance": 1}, "Malformed"],
		[{"t": "summon", "uid": u, "stance": "Defense"}, "Invalid stance"],
		[{"t": "stance", "uid": f, "stance": "def"}, "Invalid stance"],
		[{"t": "sacrifice", "uid": f, "stance": "atk"}, "Invalid stance"],
		[{"t": "summon", "uid": u, "stance": "def", "slot": 0}, "Unknown command field"],
	]
	# Act / Assert
	for c in cases:
		var n := client_errors.size()
		client.local_seat.send(c[0])
		assert_str(await _client_err_after(n)).contains(c[1])
	assert_str(m.cards[u]["zone"]).is_equal("hand")
	assert_str(m.cards[f]["zone"]).is_equal("unit")
	assert_bool(m.pending.is_empty()).is_true()


func test_client_cannot_probe_host_hidden_hand_with_stance_summons() -> void:
	# Arrange: the host's hidden Hand holds a no_defense unit and an ordinary unit
	var m: MatchEngine = await _client_turn2()
	var hidden_nd := TB.card(m, 0, MUMENS_BOUNTY)
	var hidden_ok := TB.card(m, 0, TB.WATER)
	await _sync()
	# Act
	var n := client_errors.size()
	client.local_seat.send({"t": "summon", "uid": hidden_nd, "stance": "def"})
	var e1 := await _client_err_after(n)
	n = client_errors.size()
	client.local_seat.send({"t": "summon", "uid": hidden_ok, "stance": "def"})
	var e2 := await _client_err_after(n)
	# Assert: identical replies, so the hidden card's identity is not revealed
	assert_str(e1).is_equal(e2)


func test_client_payloads_never_carry_host_hidden_uids_during_attack_preview() -> void:
	# Arrange: client attacks; host has hand cards and a face-down card
	var m: MatchEngine = await _client_turn2()
	client.local_seat.send({"t": "next_phase"})
	assert_bool(await _wait(func(): return m.phase == "battle")).is_true()
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 8)
	TB.unit(m, 0, TB.FIRE, 0, "atk", 10)
	var setc := TB.set_card(m, 0, 163, 2)
	await _sync()
	# Act
	client.local_seat.send({"t": "attack", "uid": a})
	assert_bool(await _await_pending(m, 1, "attack_target")).is_true()
	await _sync()
	# Assert: preview present for the client, no hidden uid in any payload
	var opts: Array = cpend()["options"]
	assert_bool(opts.any(func(o): return o.has("preview"))).is_true()
	var blob := _blob()
	for uid in m.players[0]["hand"] + m.players[0]["draw"] + [setc]:
		assert_str(blob).override_failure_message("hidden uid %d leaked" % uid).not_contains("\"uid\":%d," % uid)
		assert_str(blob).not_contains("\"uid\":%d}" % uid)
		assert_str(blob).not_contains("\"uid\":%d.0" % uid)
