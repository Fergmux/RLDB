extends "res://tests/integration/qa/qa_net_base.gd"
## Adversarial QA: nested Trap chains (P-20), summon order (P-22) and column traps
## on direct attacks (P-23; C-03 replaced on 2026-11-03), all driven over a real two-client ENet session.

const PLAN_B := 163
const SHARED_FATE := 87
const MAGIC_CYLINDER := 45
const DAMAGE_CONVERSION := 47
const CHIDORI_MONK := 24       # 16/14; On Summon: 1 Infiltrate on itself
const ALEXANDERS_ARROW := 103


func port() -> int:
	return 24791


func test_plan_b_over_network_resolves_depth_first_heals_last_and_client_view_matches() -> void:
	# Arrange
	var m: MatchEngine = await _client_turn2()
	var atk := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	# F03-09: names no longer carry the Type, so the three units differ by Race.
	var c2 := TB.unit(m, 1, 118, 1)                         # Basic Beast (Physical)
	var h1 := TB.unit(m, 0, 122, 0)                         # Basic Warrior (Earth)
	var h2 := TB.unit(m, 0, 111, 1)                         # Basic Dragon (Fire)
	TB.set_card(m, 0, PLAN_B, 0)
	TB.set_card(m, 0, SHARED_FATE, 1)
	var decoy := TB.set_card(m, 0, MAGIC_CYLINDER, 2)        # never selected, must stay hidden
	await _sync()
	client_payloads.clear()      # deck-selection views list every starter card publicly
	client.local_seat.send({"t": "next_phase"})
	assert_bool(await _wait(func(): return m.phase == "battle")).is_true()
	# Act: client attacks the Earth mage in column 1
	client.local_seat.send({"t": "attack", "uid": atk})
	assert_bool(await _await_pending(m, 1, "attack_target")).is_true()
	_client_choose(["Basic Warrior"])
	assert_bool(await _await_pending(m, 0, "trap_response")).is_true()
	assert_array(_labels(hpend())).not_contains(["Activate Magic Cylinder"])   # column 3, not eligible
	_host_choose(["Plan B"])
	assert_bool(await _await_pending(m, 0, "select")).is_true()
	# The waiting client sees only that the host is choosing.
	assert_bool(cpend().get("mine", true)).is_false()
	assert_bool(cpend().has("options")).is_false()
	_host_choose(["Basic Dragon", "Basic Warrior"])     # ordered: Fire first
	assert_bool(await _await_pending(m, 0, "trap_response")).is_true()
	assert_int(m.players[0]["hp"]).is_equal(60)                # no healing before chains finish
	assert_str(m.cards[h1]["zone"]).is_equal("unit")            # second target not yet destroyed
	_host_choose(["Shared Fate"])
	if await _await_pending(m, 0, "select", 60):
		_host_choose(["Basic Beast"])
	assert_bool(await _await_idle(m)).is_true()
	# Assert
	var i_fire := TB.log_index(m, "Basic Dragon is destroyed")
	var i_fate := TB.log_index(m, "activates Trap Shared Fate")
	var i_phys := TB.log_index(m, "Basic Beast is destroyed")
	var i_earth := TB.log_index(m, "Basic Warrior is destroyed")
	var i_heal := TB.log_index(m, "(Plan B, 2 destroyed)")
	assert_bool(i_fire >= 0 and i_fire < i_fate and i_fate < i_phys and i_phys < i_earth and i_earth < i_heal) \
		.override_failure_message("order fire=%d fate=%d phys=%d earth=%d heal=%d" % [i_fire, i_fate, i_phys, i_earth, i_heal]).is_true()
	assert_int(m.players[0]["hp"]).is_equal(80)
	assert_int(m.players[1]["hp"]).is_equal(60)
	assert_str(m.cards[c2]["zone"]).is_equal("spent")
	assert_str(m.cards[h2]["zone"]).is_equal("spent")
	assert_str(m.cards[decoy]["zone"]).is_equal("backrow")
	# The client's merged log equals the authority's redacted log for seat 1.
	await _sync()
	var want: Array = MatchView.log_for(m, 1).map(func(e): return e["text"])
	assert_bool(await _wait(func(): return cview()["match"]["log"].map(func(e): return e["text"]) == want)).is_true()
	# Nothing about the unselected face-down card ever reached the client.
	var blob := _blob()
	assert_bool(blob.contains("Magic Cylinder")).is_false()
	assert_bool(blob.contains("\"uid\":%d" % decoy)).is_false()


# 2026-11-03 (owner ruling, replaces C-03): Magic Cylinder and Damage Conversion answer an attack
# declared by an opponent's unit in their column, a direct attack included. Over the network only
# the Trap in the attacker's column is offered, and a declined window reveals nothing.
func test_column_traps_answer_only_a_direct_attack_from_their_column_over_network() -> void:
	# Arrange: host has no units; Magic Cylinder, Damage Conversion, Magic Cylinder in columns 1-3
	var m: MatchEngine = await _client_turn2()
	var atk := TB.unit(m, 1, TB.WATER, 0, "atk", 10)            # attacks from column 1
	var mc := TB.set_card(m, 0, MAGIC_CYLINDER, 0)
	var dc := TB.set_card(m, 0, DAMAGE_CONVERSION, 1)
	var mc3 := TB.set_card(m, 0, MAGIC_CYLINDER, 2)
	await _sync()
	client.local_seat.send({"t": "next_phase"})
	assert_bool(await _wait(func(): return m.phase == "battle")).is_true()
	# Act
	client.local_seat.send({"t": "attack", "uid": atk})
	if await _await_pending(m, 1, "attack_target", 120):
		_client_choose(["directly"])
	assert_bool(await _await_pending(m, 0, "trap_response")).is_true()
	# Assert: only the column-1 Trap answers, and the client is told nothing about it
	var offered: Array = _labels(hpend()).filter(func(l): return String(l).begins_with("Activate"))
	assert_array(offered).is_equal(["Activate Magic Cylinder"])
	var act: Array = m.pending["options"].filter(func(o): return String(o["label"]).begins_with("Activate"))
	assert_int(int(act[0]["v"])).is_equal(mc)                  # the column-1 Cylinder, not column 3's
	assert_bool(_blob().contains("Magic Cylinder")).is_false()
	_host_choose(["Skip"])
	assert_bool(await _await_idle(m)).is_true()
	assert_int(m.players[0]["hp"]).is_equal(60 - 10)
	assert_int(m.players[1]["hp"]).is_equal(60)
	assert_bool(m.is_face_up(mc) or m.is_face_up(dc) or m.is_face_up(mc3)).is_false()


func test_on_summon_resolves_before_summon_trap_prompt_over_network() -> void:
	# Arrange
	var m: MatchEngine = await _client_turn2()
	TB.unit(m, 0, TB.WATER, 0)                                  # host's lowest ATK: 8
	TB.set_card(m, 0, ALEXANDERS_ARROW, 0)
	# 2026-11-03: Shen is 0/0 now (Alexander's Arrow would floor at 0), so Chidori Monk stands in.
	var monk := TB.card(m, 1, CHIDORI_MONK, "hand")
	m.players[1]["ap"] = 20
	await _sync()
	# Act
	client.local_seat.send({"t": "summon", "uid": monk})
	assert_bool(await _await_pending(m, 1, "slot")).is_true()
	_client_choose(["Front row, column 2"])
	if await _await_pending(m, 1, "stance", 120):
		_client_choose(["Attack"])
	assert_bool(await _await_pending(m, 0, "trap_response")).is_true()
	# Assert: the Monk's own On Summon (Infiltrate) already resolved when the host is asked
	assert_int(m.status_count(monk, "infiltrate")).is_equal(1)
	_host_choose(["Alexander"])
	assert_bool(await _await_idle(m)).is_true()
	assert_int(m.atk_of(monk)).is_equal(16 - 8)
