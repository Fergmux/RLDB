extends "res://tests/integration/qa/qa_net_base.gd"
## Adversarial QA: pile reveals go to the chooser only; the other client's raw
## payloads never carry the hidden names or uids.

const INTO_THE_VOID := 101
const SHEN := 21
const MAGIC_CYLINDER := 45
const KAYA := 170
const SECRET := 101          # Into the Void: not in the host's starter deck (Tide & Storm)


func port() -> int:
	return 24793


func test_into_the_void_reveals_host_spent_to_client_only_while_choosing() -> void:
	# Arrange
	var m: MatchEngine = await _client_turn2()
	var shen := TB.card(m, 0, SHEN, "spent")
	var mc := TB.card(m, 0, MAGIC_CYLINDER, "spent")
	var itv := TB.card(m, 1, INTO_THE_VOID, "hand")
	m.players[1]["ap"] = 20
	await _sync()
	assert_bool(_blob().contains("Shen the World Dragon")).is_false()
	# Act
	client.local_seat.send({"t": "cast", "uid": itv})
	assert_bool(await _await_pending(m, 1, "select")).is_true()
	var names: Array = cpend()["options"].filter(func(o): return o.has("card")).map(func(o): return o["card"]["name"])
	assert_array(names).contains(["Shen the World Dragon", "Magic Cylinder"])
	_client_choose(["Magic Cylinder"])
	assert_bool(await _await_idle(m)).is_true()
	# Assert
	assert_str(m.cards[mc]["zone"]).is_equal("exhaust")
	client_payloads.clear()
	await _sync()
	assert_bool(await _wait(func(): return not client_payloads.is_empty())).is_true()
	var blob := _blob()
	assert_bool(blob.contains("Shen the World Dragon")).is_false()
	assert_bool(blob.contains("\"uid\":%d" % shen)).is_false()
	assert_bool(blob.contains("\"uid\":%d" % mc)).is_false()


func test_host_arcane_and_hand_choices_never_leak_to_client() -> void:
	# Arrange: host's turn 3
	var m: MatchEngine = await _client_turn2()
	await _end_client_turn(m)
	var shen := TB.card(m, 0, SHEN, "spent")
	var mat := TB.card(m, 0, TB.EARTH, "spent")
	var secret := TB.card(m, 0, SECRET, "hand")
	var kaya := -1
	for u in m.players[0]["extra"]:
		if m.cards[u]["id"] == KAYA:
			kaya = u
	if kaya == -1:
		kaya = TB.card(m, 0, KAYA, "extra")
	m.players[0]["ap"] = 20
	client_payloads.clear()
	await _sync()
	# Act
	host.local_seat.send({"t": "arcane", "uid": kaya})
	assert_bool(await _await_pending(m, 0, "select")).is_true()
	assert_bool(cpend().has("options")).is_false()
	var mat_label := ""
	for o in hpend()["options"]:
		if o.get("card", {}).get("uid", -1) == mat:
			mat_label = o["label"]
	host.local_seat.send({"t": "choose", "id": hpend()["id"], "indices": _idx(hpend(), [mat_label])})
	assert_bool(await _await_pending(m, 0, "slot")).is_true()
	_host_choose(["column 3"])
	if await _await_pending(m, 0, "stance", 120):
		_host_choose(["Attack"])
	assert_bool(await _await_pending(m, 0, "select")).is_true()        # Kaya: optional hand card
	_host_choose(["Into the Void"])
	assert_bool(await _await_idle(m)).is_true()
	await _sync()
	# Assert
	assert_str(m.cards[kaya]["zone"]).is_equal("unit")
	assert_str(m.cards[secret]["zone"]).is_equal("spent")
	var blob := _blob()
	for needle in ["Shen the World Dragon", "Into the Void", "\"uid\":%d" % shen, "\"uid\":%d" % secret, "\"uid\":%d" % mat]:
		assert_bool(blob.contains(needle)).override_failure_message("client payload leaked " + needle).is_false()
