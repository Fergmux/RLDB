extends "res://tests/integration/qa/qa_net_base.gd"
## L batch final QA (design/qa-final-2026-11-05.md): the Evolve prompt (L23) over real ENet. The
## remote client gets "Evolve <card> into <next>?" with both forms shown; the host only sees that
## the client is deciding; the answer travels by option index; both seats then see the evolved card
## and the public "evolve" presentation event.

const SPAWN := 155
const LARVA := 156


func port() -> int:
	return 24798


func test_client_evolves_its_spawn_and_both_seats_see_the_larva() -> void:
	# Arrange: the client's Spawn on the Field; its next turn starts with the prompt.
	var m: MatchEngine = await _client_turn2()
	var spawn := TB.unit(m, 1, SPAWN, 3)
	await _end_client_turn(m)
	for i in 3:
		var ph := m.phase
		host.local_seat.send({"t": "next_phase"})
		await _wait(func(): return m.phase != ph or m.active == 1, 120)
	assert_bool(await _await_pending(m, 1, "evolve")).is_true()
	# The client sees the question, its two answers and both forms; the host only the wait.
	var pd := cpend()
	assert_str(String(pd["prompt"])).is_equal("Evolve Symbiote Spawn into Symbiote Larva?")
	assert_array(_labels(pd)).is_equal(["Evolve", "Skip"])
	assert_int(int(pd["evolve_to"])).is_equal(LARVA)
	assert_array(pd["mentions"].map(func(e): return int(e["card"]["id"]))).is_equal([SPAWN, LARVA])
	assert_bool(await _wait(func(): return hpend().get("kind", "") == "evolve")).is_true()
	assert_bool(hpend()["mine"]).is_false()
	assert_bool(hpend().has("options")).is_false()
	# Act
	client_payloads.clear()
	_client_choose(["Evolve"])
	assert_bool(await _await_idle(m)).is_true()
	await _sync()
	# Assert
	assert_int(int(m.cards[spawn]["id"])).is_equal(LARVA)
	assert_bool(await _wait(func(): return int(cview()["match"]["players"][1]["units"][3].get("id", -1)) == LARVA)).is_true()
	assert_bool(await _wait(func(): return host.local_seat.last_view["match"]["players"][1]["units"][3].get("id", -1) == LARVA)).is_true()
	assert_bool(_blob().contains("\"k\":\"evolve\"")).is_true()
	assert_bool(client_errors.is_empty()).override_failure_message(str(client_errors)).is_true()
