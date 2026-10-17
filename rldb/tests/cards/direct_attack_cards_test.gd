extends GdUnitTestSuite
## G07 per-card tests for the cards that "can attack your opponent directly" (flag
## direct_attack): Diggie (162) and Flying Sandworm (171). Each offers Attack and Attack
## Direct as two actions while the opponent has units; the attack follows the chosen action.


func _acts(m: MatchEngine, uid: int) -> Array:
	return MatchView.actions_for(m, m.active).filter(func(a): return a["t"] == "attack" and int(a.get("uid", -1)) == uid and a["ok"])


func test_c162_diggie_offers_attack_and_attack_direct_in_battle() -> void:
	var m := CF.p1_battle()
	var dg := TB.unit(m, 1, 162, 0)
	TB.unit(m, 0, TB.WATER, 0)
	assert_array(_acts(m, dg).map(func(a): return a["label"])).is_equal(["Attack", "Attack Direct"])


func test_c162_diggie_attack_targets_the_chosen_unit_not_the_player() -> void:
	var m := CF.p1_battle()
	var dg := TB.unit(m, 1, 162, 0)
	var foe := TB.unit(m, 0, TB.WATER, 0, "atk", 5)
	assert_str(m.submit(1, {"t": "attack", "uid": dg, "mode": "unit"})).is_empty()
	assert_array(CF.offered(m)).is_equal([foe])
	TB.choose_uids(m, [foe])
	assert_str(CF.zone(m, foe)).is_equal("spent")
	assert_int(CF.hp(m, 0)).is_equal(59)


func test_c162_diggie_attack_direct_deals_its_atk_past_units() -> void:
	var m := CF.p1_battle()
	var dg := TB.unit(m, 1, 162, 0)
	TB.unit(m, 0, TB.WATER, 0)
	assert_str(m.submit(1, {"t": "attack", "uid": dg, "mode": "direct"})).is_empty()
	assert_bool(m.pending.is_empty()).is_true()
	assert_int(CF.hp(m, 0)).is_equal(54)


func test_c171_flying_sandworm_offers_attack_and_attack_direct_in_battle() -> void:
	var m := CF.p1_battle()
	var fs := TB.unit(m, 1, 171, 0)
	TB.unit(m, 0, TB.WATER, 0)
	assert_array(_acts(m, fs).map(func(a): return a["label"])).is_equal(["Attack", "Attack Direct"])


func test_c171_flying_sandworm_attack_hits_a_unit_and_attack_direct_hits_the_player() -> void:
	var m := CF.p1_battle()
	var fs := TB.unit(m, 1, 171, 0)
	var foe := TB.unit(m, 0, TB.WATER, 0, "atk", 4)
	assert_str(m.submit(1, {"t": "attack", "uid": fs, "mode": "unit"})).is_empty()
	TB.choose_uids(m, [foe])
	assert_str(CF.zone(m, foe)).is_equal("spent")
	assert_int(CF.hp(m, 0)).is_equal(58)              # 6 ATK vs 4 ATK
	var m2 := CF.p1_battle()
	var fs2 := TB.unit(m2, 1, 171, 0)
	TB.unit(m2, 0, TB.WATER, 0)
	assert_str(m2.submit(1, {"t": "attack", "uid": fs2, "mode": "direct"})).is_empty()
	assert_int(CF.hp(m2, 0)).is_equal(54)
