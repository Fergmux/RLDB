extends GdUnitTestSuite
## G07 (design/playtest-feedback-08.md): a unit that may attack directly (flag direct_attack:
## Diggie 162, Flying Sandworm 171) offers two actions in the Battle Phase, Attack (an
## opposing unit) and Attack Direct, instead of one action that may end in a direct attack.
## Rules 01 §Battle: a normal direct attack needs an empty opposing field; Taunt overrides
## "can attack directly"; Blind picks a random legal target.

const DIGGIE := 162
const TAUNT_UNIT := 147        # Demented Apparition (flag taunt)


func _battle() -> MatchEngine:
	var m := TB.make()
	TB.to_turn2(m)                         # player 1 active
	TB.to_battle(m)
	return m


func _attack_actions(m: MatchEngine, uid: int) -> Array:
	return MatchView.actions_for(m, m.active).filter(func(a): return a["t"] == "attack" and int(a.get("uid", -1)) == uid)


func _labels(acts: Array) -> Array:
	return acts.map(func(a): return "%s/%s/%s" % [a["label"], a.get("mode", ""), a["ok"]])


func test_direct_attack_unit_with_opposing_units_offers_attack_and_attack_direct() -> void:
	var m := _battle()
	var dg := TB.unit(m, 1, DIGGIE, 0)
	TB.unit(m, 0, TB.WATER, 0)
	assert_array(_labels(_attack_actions(m, dg))).is_equal(["Attack/unit/true", "Attack Direct/direct/true"])


func test_normal_unit_with_opposing_units_offers_one_attack() -> void:
	var m := _battle()
	var u := TB.unit(m, 1, TB.WATER, 0)
	TB.unit(m, 0, TB.WATER, 0)
	assert_array(_labels(_attack_actions(m, u))).is_equal(["Attack//true"])


func test_direct_attack_unit_against_empty_field_offers_only_attack_direct() -> void:
	var m := _battle()
	var dg := TB.unit(m, 1, DIGGIE, 0)
	assert_array(_labels(_attack_actions(m, dg))).is_equal(["Attack Direct//true"])


func test_attack_mode_unit_asks_for_a_unit_without_a_direct_option() -> void:
	var m := _battle()
	var dg := TB.unit(m, 1, DIGGIE, 0)
	var foe := TB.unit(m, 0, TB.WATER, 0, "atk", 5)
	assert_str(m.submit(1, {"t": "attack", "uid": dg, "mode": "unit"})).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("attack_target")
	assert_array(CF.offered(m)).is_equal([foe])
	var has_direct := false
	for o in m.pending["options"]:
		if int(o.get("v", 0)) == -1:
			has_direct = true
	assert_bool(has_direct).is_false()
	TB.choose_uids(m, [foe])
	assert_str(CF.zone(m, foe)).is_equal("spent")
	assert_int(CF.hp(m, 0)).is_equal(59)       # 6 ATK vs 5 ATK: 1 battle damage


func test_attack_mode_direct_hits_the_opponent_without_a_prompt() -> void:
	var m := _battle()
	var dg := TB.unit(m, 1, DIGGIE, 0)
	var foe := TB.unit(m, 0, TB.WATER, 0)
	assert_str(m.submit(1, {"t": "attack", "uid": dg, "mode": "direct"})).is_empty()
	assert_bool(m.pending.is_empty()).is_true()
	assert_int(CF.hp(m, 0)).is_equal(54)       # Diggie's 6 ATK
	assert_str(CF.zone(m, foe)).is_equal("unit")


func test_attack_mode_direct_is_rejected_for_a_normal_unit_facing_units() -> void:
	var m := _battle()
	var u := TB.unit(m, 1, TB.WATER, 0)
	TB.unit(m, 0, TB.WATER, 0)
	assert_str(m.submit(1, {"t": "attack", "uid": u, "mode": "direct"})).is_not_empty()
	assert_int(CF.hp(m, 0)).is_equal(60)


func test_attack_mode_unit_is_rejected_against_an_empty_field() -> void:
	var m := _battle()
	var dg := TB.unit(m, 1, DIGGIE, 0)
	assert_str(m.submit(1, {"t": "attack", "uid": dg, "mode": "unit"})).is_not_empty()
	assert_str(m.submit(1, {"t": "attack", "uid": dg, "mode": "sideways"})).is_equal("Invalid attack mode.")


# 2026-11-03 ruling (changed on purpose): Demented Apparition reads "Your opponent's Units cannot attack
# other Units if they can attack this Unit". A direct attack is not restricted any more (it used to be
# overridden), so a direct attacker keeps both modes, and its only unit target is the Apparition.
func test_taunt_restricts_unit_targets_and_leaves_attack_direct() -> void:
	var m := _battle()
	var dg := TB.unit(m, 1, DIGGIE, 0)
	var other := TB.unit(m, 0, TB.WATER, 0)                  # another target the lure takes away
	var taunt := TB.unit(m, 0, TAUNT_UNIT, 1)
	assert_array(_labels(_attack_actions(m, dg))).is_equal(["Attack/unit/true", "Attack Direct/direct/true"])
	assert_array(m.attack_targets(dg)).is_equal([taunt, -1])
	assert_bool(other in m.attack_targets(dg)).is_false()
	assert_str(m.submit(1, {"t": "attack", "uid": dg, "mode": "direct"})).is_empty()
	assert_bool(m.pending.is_empty()).is_true()
	assert_int(CF.hp(m, 0)).is_equal(GameCore.START_HP - 6)  # Diggie's 6 ATK


func test_blind_direct_attack_unit_keeps_one_random_attack() -> void:
	var m := _battle()
	var dg := TB.unit(m, 1, DIGGIE, 0)
	TB.unit(m, 0, TB.WATER, 0)
	m.apply_status(dg, "blind", 1)
	assert_array(_labels(_attack_actions(m, dg))).is_equal(["Attack//true"])
	assert_str(m.submit(1, {"t": "attack", "uid": dg, "mode": "direct"})).is_not_empty()
	assert_str(m.submit(1, {"t": "attack", "uid": dg})).is_empty()
	assert_bool(m.pending.is_empty()).is_true()        # Blind: random target, no prompt


func test_both_actions_disabled_after_the_unit_attacked() -> void:
	var m := _battle()
	var dg := TB.unit(m, 1, DIGGIE, 0)
	TB.unit(m, 0, TB.WATER, 0)
	assert_str(m.submit(1, {"t": "attack", "uid": dg, "mode": "direct"})).is_empty()
	var acts := _attack_actions(m, dg)
	assert_int(acts.size()).is_equal(2)
	for a in acts:
		assert_bool(a["ok"]).is_false()


func test_bot_candidates_carry_the_attack_mode() -> void:
	var m := _battle()
	var dg := TB.unit(m, 1, DIGGIE, 0)
	TB.unit(m, 0, TB.WATER, 0)
	var b := BotBrain.new(1, 1)
	var modes := b.candidates(m).filter(func(c): return c["t"] == "attack" and int(c["uid"]) == dg).map(func(c): return c.get("mode", ""))
	assert_array(modes).is_equal(["unit", "direct"])


func test_bot_takes_the_direct_attack_when_the_only_unit_target_is_bad() -> void:
	var m := _battle()
	TB.unit(m, 1, DIGGIE, 0)
	TB.unit(m, 0, TB.WATER, 0, "atk", 30)              # attacking it would lose Diggie
	var b := BotBrain.new(1, 1)
	var cmd := b.best_action(m)
	assert_str(String(cmd.get("t", ""))).is_equal("attack")
	assert_str(String(cmd.get("mode", ""))).is_equal("direct")
	assert_str(m.submit(1, cmd)).is_empty()
	assert_int(CF.hp(m, 0)).is_equal(54)
