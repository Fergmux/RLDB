extends GdUnitTestSuite
## F12: a game-winning attack on a unit gets the killing-blow sequence, chosen only from an authoritative
## batch that ends the game; effect damage, rebound damage and a negated attack never do.

const ATK_UNIT := {"k": "attack", "from": {"p": 0, "slot": 1}, "to": {"p": 1, "slot": 2}}
const DESTROY_T := {"k": "destroy", "at": {"p": 1, "zone": "unit", "slot": 2}, "cause": "battle", "dest": "spent"}
const OVER_0 := {"k": "game_over", "winner": 0}


func _hp(p: int, d: int, via: String = "") -> Dictionary:
	var e := {"k": "hp", "p": p, "d": d}
	if via != "":
		e["via"] = via
	return e


func test_winning_battle_damage_on_a_unit_is_the_unit_killing_blow() -> void:
	var ev := [ATK_UNIT, DESTROY_T, _hp(1, -12, "battle"), OVER_0]
	var info := FxStrike.detect(ev)
	assert_str(String(info["mode"])).is_equal("unit")
	assert_int(int(info["attack"])).is_equal(0)
	assert_int(int(info["destroy"])).is_equal(1)
	assert_dict(info["destroy_e"]).is_equal(DESTROY_T)
	assert_int(int(info["d"])).is_equal(12)
	assert_float(FxStrike.hold_extra(info)).is_equal(FxStrike.LETHAL_LEN + FxStrike.UNIT_OVERFLOW)


func test_effect_damage_after_an_attack_on_a_unit_stays_the_flourish() -> void:
	# untagged (an effect, e.g. a trap's damage) and Burn-style damage are not the attack's blow
	assert_str(String(FxStrike.detect([ATK_UNIT, _hp(1, -12), OVER_0])["mode"])).is_equal("effect")
	assert_str(String(FxStrike.detect([ATK_UNIT, _hp(1, -12, ""), OVER_0])["mode"])).is_equal("effect")


func test_attacker_losing_to_rebound_damage_is_not_a_winning_attack() -> void:
	var ev := [ATK_UNIT, _hp(0, -9, "battle"), {"k": "game_over", "winner": 1}]
	assert_str(String(FxStrike.detect(ev)["mode"])).is_equal("effect")


func test_negated_or_prevented_attack_never_previews_a_win() -> void:
	# no game_over in the batch: nothing is lethal, whatever the damage tags say
	assert_dict(FxStrike.detect([ATK_UNIT, DESTROY_T, _hp(1, -12, "battle")])).is_empty()
	assert_dict(FxStrike.detect([ATK_UNIT])).is_empty()


func test_attack_declared_in_an_earlier_batch_uses_the_prior_attack() -> void:
	# trap window: the declaration came first; the resolving batch has only damage and game_over
	var ev := [{"k": "spotlight", "p": 1}, DESTROY_T, _hp(1, -12, "battle"), OVER_0]
	var info := FxStrike.detect(ev, ATK_UNIT)
	assert_str(String(info["mode"])).is_equal("unit")
	assert_int(int(info["attack"])).is_equal(-1)
	assert_int(int(info["start"])).is_equal(1)
	assert_dict(info["e"]).is_equal(ATK_UNIT)
	var direct := {"k": "attack", "from": {"p": 0, "slot": 0}, "to": {"p": 1, "direct": true}}
	var di := FxStrike.detect([_hp(1, -7, "direct"), OVER_0], direct)
	assert_str(String(di["mode"])).is_equal("direct")
	assert_int(int(di["start"])).is_equal(0)
	# a prior attack by the other player never claims this damage
	var other := {"k": "attack", "from": {"p": 1, "slot": 0}, "to": {"p": 0, "slot": 0}}
	assert_str(String(FxStrike.detect([_hp(1, -12, "battle"), OVER_0], other)["mode"])).is_equal("effect")


func test_hp_cause_reads_the_real_battle_log_lines() -> void:
	# Arrange: a real battle through the rules engine that wins the game by battle damage
	var m := TB.make()
	TB.to_battle(m)
	var a := m.active
	var o := 1 - a
	var att := TB.unit(m, a, TB.WATER, 0, "atk", 30, 30)
	var tgt := TB.unit(m, o, TB.WATER, 1, "atk")
	m.players[o]["hp"] = 5
	var since: int = int(m.log_entries[-1]["seq"])
	# Act
	assert_str(TB.attack(m, att, tgt)).is_equal("")
	while not m.pending.is_empty() and m.pending.get("kind", "") == "trap_response":
		TB.choose_uids(m, [-1])
	# Assert: the client-side tagging of the viewer's log finds the unit killing blow
	var events := []
	for row in MatchView.log_for(m, a, since):
		var via := FxStrike.hp_cause(String(row["text"]))
		for f in row["fx"]:
			var g: Dictionary = (f as Dictionary).duplicate()
			if via != "" and String(g["k"]) == "hp":
				g["via"] = via
			events.append(g)
	assert_int(m.winner).is_equal(a)
	var info := FxStrike.detect(events)
	assert_str(String(info["mode"])).is_equal("unit")
	assert_int(int(info["destroy"])).is_greater(int(info["attack"]))
	assert_str(FxStrike.hp_cause("Ben loses 6 HP (direct attack by Basic Mage) (HP 0).")).is_equal("direct")
	assert_str(FxStrike.hp_cause("Ben loses 2 HP (Burn on Basic Mage after its attack) (HP 3).")).is_equal("")
