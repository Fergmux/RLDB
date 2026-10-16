extends GdUnitTestSuite
## Regression tests for defects found by the independent specialist reviews
## (combat/timing, hidden information). Each was confirmed failing before its fix.


func test_no_gain_unit_does_not_block_buff_to_other_targets() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	TB.to_battle(m)
	TB.set_card(m, 0, 51, 0)                                # Rushed Recklessly: +8 DEF column
	TB.unit(m, 0, 38, 0)                                    # Lone Warrior (no gains) in front
	var ally := TB.unit(m, 0, TB.WATER, 3, "atk", 8, 8)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 1)
	TB.attack(m, a, m.players[0]["units"][0])
	TB.choose(m, ["Activate Rushed Recklessly"])
	assert_int(m.def_of(ally)).is_equal(16)


func test_fusion_on_full_board_with_hand_materials_consumes_nothing() -> void:
	var m := TB.make()
	TB.power(m, 0, 137)                                     # Unstable Fusions: Hand materials
	for s in 6:
		TB.unit(m, 0, TB.FIRE, s)
	var beast := TB.card(m, 0, 4)
	var dragon := TB.card(m, 0, 2)
	var wyrm := TB.card(m, 0, 93, "extra")
	TB.cast(m, 0, 82)
	if m.pending.get("kind", "") == "select":
		TB.choose_uids(m, [wyrm])
	assert_str(m.cards[beast]["zone"]).is_equal("hand")
	assert_str(m.cards[dragon]["zone"]).is_equal("hand")
	assert_str(m.cards[wyrm]["zone"]).is_equal("extra")


func test_equal_atk_battle_immunity_reads_opponent_before_it_left_field() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	TB.to_battle(m)
	var steadfast := TB.unit(m, 1, 39, 0, "atk", 30)        # immune to 30+ ATK battles
	var foe := TB.unit(m, 0, TB.WATER, 0, "atk", 24)
	m.cards[foe]["mods"].append({"atk": 6, "def": 0, "until": "field", "src": "buff"})
	TB.attack(m, steadfast, foe)
	assert_str(m.cards[foe]["zone"]).is_equal("spent")
	assert_str(m.cards[steadfast]["zone"]).is_equal("unit")


func test_attack_does_not_resolve_if_target_became_protected() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	TB.to_battle(m)
	TB.set_card(m, 0, 52, 0)                                # Defcon 2 (summon) is not an attack trap
	var back := TB.unit(m, 0, TB.WATER, 3, "atk", 1)
	var a := TB.unit(m, 1, TB.WATER, 1, "atk", 30)
	m.submit(1, {"t": "attack", "uid": a})
	TB.choose_uids(m, [back])
	# Simulate a response that fills the front zone before the battle step.
	assert_bool(m.pending.is_empty()).is_true()
	var m2 := TB.make()
	TB.to_turn2(m2)
	TB.to_battle(m2)
	var back2 := TB.unit(m2, 0, TB.WATER, 3, "atk", 1)
	var a2 := TB.unit(m2, 1, TB.WATER, 1, "atk", 30)
	var f := m2.make_frame(a2, 1, [{"op": "battle"}], "attack")
	f["vars"]["target"] = back2
	TB.unit(m2, 0, TB.WATER, 0)                             # front zone now occupied
	m2.push_frame(f)
	m2.run()
	assert_str(m2.cards[back2]["zone"]).is_equal("unit")


func test_debilitated_flying_sandworm_goes_to_spent_not_exhaust() -> void:
	var m := TB.make()
	var fs := TB.unit(m, 0, 171, 0)
	m.apply_status(fs, "debilitate", 1)
	TB.kill(m, fs)
	assert_str(m.cards[fs]["zone"]).is_equal("spent")


func test_magic_cylinder_uses_attacker_last_known_atk_after_mirror_force() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	TB.to_battle(m)
	TB.set_card(m, 0, 46, 1)                                # Mirror Force
	TB.set_card(m, 0, 45, 0)                                # Magic Cylinder (column 1)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 14)
	m.cards[a]["mods"].append({"atk": 16, "def": 0, "until": "field", "src": "buff"})
	for s in [1, 2, 3]:
		TB.unit(m, 1, TB.WATER, s, "def")
	var d := TB.unit(m, 0, TB.WATER, 0)
	TB.attack(m, a, d)
	TB.choose(m, ["Activate Mirror Force"])
	TB.choose(m, ["Activate Magic Cylinder"])
	assert_int(m.players[1]["hp"]).is_equal(30)


func test_retain_does_not_follow_a_card_out_of_hand() -> void:
	var m := TB.make()
	var c: int = m.players[0]["hand"][0]
	m.apply_status(c, "retain", 1)
	m.move_to_pile(c, "spent")
	assert_int(m.status_count(c, "retain")).is_equal(0)


func test_stance_can_change_more_than_once_in_main_phase_one() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0)
	m.submit(0, {"t": "stance", "uid": u})
	assert_str(m.validate(0, {"t": "stance", "uid": u})).is_empty()


func test_moving_card_out_of_spent_is_not_named_publicly() -> void:
	var m := TB.make()
	var top := TB.card(m, 0, 21, "spent")
	TB.summon(m, 0, 150, 0)                                 # Mumen's Bounty: Spent -> top of Draw
	TB.choose_uids(m, [top])
	assert_bool(JSON.stringify(MatchView.log_for(m, 1)).contains("Shen")).is_false()
	assert_bool(JSON.stringify(MatchView.log_for(m, 0)).contains("Shen")).is_true()


func test_status_on_hand_card_is_not_named_publicly() -> void:
	var m := TB.make()
	var c := TB.card(m, 0, 21)
	m.apply_status(c, "retain", 1)
	assert_bool(JSON.stringify(MatchView.log_for(m, 1)).contains("Shen")).is_false()
	assert_bool(JSON.stringify(MatchView.log_for(m, 0)).contains("Shen")).is_true()


func test_choice_from_draw_is_not_presented_in_draw_order() -> void:
	var m := TB.make(7, 0)
	var ids := []
	for i in 6:
		ids.append(TB.card(m, 0, 122, "draw"))
	TB.summon(m, 0, 73, 0)                                  # Mans Best Friend: Warrior from Draw
	var shown: Array = m.pending["options"].map(func(o): return o["v"])
	var sorted := shown.duplicate()
	sorted.sort()
	assert_array(shown).is_equal(sorted)


func test_no_legal_choice_message_is_private() -> void:
	var m := TB.make()
	TB.summon(m, 0, 73, 0)                                  # no Warrior in Draw
	var pub := JSON.stringify(MatchView.log_for(m, 1))
	assert_bool(pub.contains("no legal choice")).is_false()


## Feedback 04 bug: a Fusion summon through Tag Team - S asked "Choose a stance for Tag Team - S"
## (the effect's source) instead of naming the Fusion unit being summoned; the zone prompt too.
func test_fusion_zone_and_stance_prompts_name_the_fusion_unit() -> void:
	var m := TB.make()
	TB.unit(m, 0, 4, 3)                                  # Basic Beast (Water)
	TB.unit(m, 0, 2, 1)                                  # Basic Dragon (Water)
	var wyrm := TB.card(m, 0, 93, "extra")
	TB.summon(m, 0, 8, 0)                                # Tag Team - S: On Summon may Fusion Summon
	TB.choose(m, ["Yes"])
	TB.choose_uids(m, [wyrm])
	assert_str(TB.pend_kind(m)).is_equal("slot")
	assert_str(String(m.pending["prompt"])).contains(m.name_of(wyrm))
	TB.choose(m, ["Front row, column 2"])                # the Dragon material's own zone
	assert_str(TB.pend_kind(m)).is_equal("stance")
	assert_str(String(m.pending["prompt"])).is_equal("Choose a stance for %s." % m.name_of(wyrm))
	TB.choose(m, ["Defense"])
	assert_str(m.cards[wyrm]["zone"]).is_equal("unit")
	assert_str(m.cards[wyrm]["stance"]).is_equal("def")


## Feedback 06 bug: Dante's "Apply 1 Cleanse to this unit or an adjacent unit" was never offered
## (the legality check read the adjacent-unit list before it was computed).
func test_dante_cleanse_ability_is_usable() -> void:
	var m := TB.make()
	var dante := TB.unit(m, 0, 36, 0)
	TB.unit(m, 0, TB.WATER, 1)
	assert_str(m.validate(0, {"t": "ability", "uid": dante, "idx": 0})).is_empty()
	assert_str(TB.ability(m, dante)).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("select")
	assert_int(m.pending["options"].size()).is_equal(2)          # Dante itself and the adjacent unit
	TB.choose_uids(m, [dante])
	assert_int(m.status_count(dante, "cleanse")).is_equal(1)


## Feedback 06: Polymerization cannot be cast without a Fusion unit it could summon.
func test_polymerization_needs_a_summonable_fusion() -> void:
	var m := TB.make()
	var poly := TB.card(m, 0, 82)
	m.players[0]["ap"] = 5
	assert_str(m.validate(0, {"t": "cast", "uid": poly})).is_equal("No Fusion unit can be summoned.")
	TB.unit(m, 0, 4, 3)                                  # Basic Beast + Basic Dragon: Bastion Wyrm materials
	TB.unit(m, 0, 2, 1)
	TB.card(m, 0, 93, "extra")
	assert_str(m.validate(0, {"t": "cast", "uid": poly})).is_empty()


## Feedback 07 bug: Wabuku ("Apply 1 Eternal to a unit in this column") was offered on a direct
## attack with no own unit in its column. A Trap whose effect has no legal target is not offered.
func test_trap_without_a_legal_target_is_not_offered() -> void:
	var m := TB.make()
	TB.to_turn2(m)                                           # player 1 attacks, player 0 holds the Trap
	TB.set_card(m, 0, 50, 0)                                 # Wabuku in column 1, no unit of player 0 there
	TB.to_battle(m)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	assert_str(TB.attack(m, a, -1)).is_empty()
	assert_str(TB.pend_kind(m)).is_not_equal("trap_response")


func test_trap_with_a_legal_target_is_offered() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	TB.set_card(m, 0, 50, 0)
	var guard := TB.unit(m, 0, TB.WATER, 3)                  # back row, column 1: Wabuku's column
	TB.to_battle(m)
	var a := TB.unit(m, 1, TB.WATER, 1, "atk", 10)
	TB.attack(m, a, guard)
	assert_str(TB.pend_kind(m)).is_equal("trap_response")


## Feedback 09 report: Mirror Force destroys only the attacker's Attack-stance units; the
## attacker's set Traps and Powers stay (destruction effects of the destroyed units aside).
func test_mirror_force_leaves_the_attackers_traps_and_powers() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	TB.set_card(m, 0, 46, 0)                                  # defender's Mirror Force
	var a1 := TB.unit(m, 1, TB.WATER, 0, "atk")
	var a2 := TB.unit(m, 1, TB.FIRE, 1, "atk")
	var d1 := TB.unit(m, 1, TB.EARTH, 2, "def")
	var t1 := TB.set_card(m, 1, 45, 0)
	var t2 := TB.set_card(m, 1, 50, 1)
	var pw := TB.power(m, 1, 88)
	TB.to_battle(m)
	TB.attack(m, a1, -1)
	assert_str(TB.choose(m, ["Activate Mirror Force"])).is_empty()
	assert_str(m.cards[a1]["zone"]).is_equal("spent")
	assert_str(m.cards[a2]["zone"]).is_equal("spent")
	assert_str(m.cards[d1]["zone"]).is_equal("unit")             # Defense stance survives
	assert_str(m.cards[t1]["zone"]).is_equal("backrow")
	assert_str(m.cards[t2]["zone"]).is_equal("backrow")
	assert_str(m.cards[pw]["zone"]).is_equal("power")


# ---------------------------------------------------------------- core rules review (2026-10-16)

## A lead MODE choice is made first, but its ops apply after the cost and the response
## window, so Energy Dispel negates Shaman's Snunday Brew before the opponent loses HP.
func test_lead_mode_applies_after_response_window_so_it_can_be_negated() -> void:
	var m := TB.make()
	var brew := TB.power(m, 0, 167)
	TB.set_card(m, 1, 140, 0)                                 # Energy Dispel
	TB.ability(m, brew)
	assert_str(TB.choose(m, ["Opponent loses 4 HP"])).is_empty()
	assert_int(m.players[1]["hp"]).is_equal(60)               # nothing applied before the window
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	TB.choose(m, ["Activate Energy Dispel"])
	assert_int(m.players[1]["hp"]).is_equal(60)


## Auric: the HP cost is paid before the chosen mode's +10 ATK applies.
func test_lead_mode_effect_follows_the_hp_cost() -> void:
	var m := TB.make()
	var a := TB.unit(m, 0, 23, 0)
	var atk0 := m.atk_of(a)
	TB.ability(m, a)
	TB.choose(m, ["gains +10 ATK"])
	assert_int(m.players[0]["hp"]).is_equal(50)
	assert_int(m.atk_of(a)).is_equal(atk0 + 10)
	var hp_i := TB.log_index(m, "pays") if TB.log_index(m, "pays") != -1 else TB.log_index(m, "cost of")
	var atk_i := TB.log_index(m, "+10 ATK")
	assert_bool(hp_i != -1 and atk_i > hp_i).is_true()


## Saviour Appears Defcon 2 is not offered when its column has no free zone.
func test_column_summon_trap_not_offered_without_a_free_zone() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	var t := TB.set_card(m, 0, 52, 0)
	TB.unit(m, 0, TB.WATER, 0)
	TB.unit(m, 0, TB.WATER, 3)
	TB.card(m, 0, TB.WATER, "spent")
	TB.summon(m, 1, 28, 1)
	assert_str(TB.pend_kind(m)).is_not_equal("trap_response")
	assert_str(m.cards[t]["zone"]).is_equal("backrow")
	assert_bool(m.cards[t]["face_up"]).is_false()


## A Trap whose summon finds no free zone still finishes (goes to Spent) instead of
## staying face-up on the Field to be activated again.
func test_trap_finishes_even_when_its_summon_finds_no_zone() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	var t := TB.set_card(m, 0, 52, 0)
	TB.unit(m, 0, TB.WATER, 0)
	TB.unit(m, 0, TB.WATER, 3)
	var dead := TB.card(m, 0, TB.WATER, "spent")
	m.activate_trap(t, 0, {"name": "summon", "player": 1, "column": 0})
	m.run()
	if TB.pend_kind(m) == "select":
		TB.choose_uids(m, [dead])
	assert_bool(m.pending.is_empty()).is_true()
	assert_str(m.cards[t]["zone"]).is_equal("spent")
	assert_str(m.cards[dead]["zone"]).is_equal("spent")


## Tag Team - X refuses its ability (no AP paid) when its column has no free zone.
func test_column_summon_ability_refused_without_a_free_zone() -> void:
	var m := TB.make()
	var x := TB.unit(m, 0, 12, 0)
	TB.unit(m, 0, TB.WATER, 3)
	TB.card(m, 0, TB.WATER, "spent")
	m.players[0]["ap"] = 2
	var e := m.submit(0, {"t": "ability", "uid": x, "idx": 0})
	assert_str(e).is_equal("No free zone in this column.")
	assert_int(m.players[0]["ap"]).is_equal(2)


## Sepukku: when the self-destroy cost is prevented (Mans Best Friend), no Fusion happens
## and Sepukku is never offered as its own material.
func test_sepukku_prevented_self_destroy_does_not_fusion() -> void:
	var m := TB.make()
	var sep := TB.unit(m, 0, 68, 0)
	TB.unit(m, 0, 73, 3)                                       # Mans Best Friend, same column
	TB.unit(m, 0, TB.FIRE, 1)
	TB.unit(m, 0, 3, 2)
	var sol := TB.card(m, 0, 181, "extra")                     # Warrior + Fire
	assert_str(TB.ability(m, sep)).is_empty()
	if TB.pend_kind(m) == "select" and m.pending["prompt"].contains("Fusion unit"):
		TB.choose_uids(m, [sol])
	var offered_self := false
	if not m.pending.is_empty():
		for o in m.pending["options"]:
			if o.get("uid", -1) == sep:
				offered_self = true
	assert_bool(offered_self).is_false()
	assert_bool(m.pending.is_empty()).is_true()
	assert_str(m.cards[sol]["zone"]).is_equal("extra")
	assert_str(m.cards[sep]["zone"]).is_equal("unit")


## Ambush: a Bahatia-blocked Basic Unit does not use up a free zone.
func test_ambush_skips_blocked_basics_without_wasting_zones() -> void:
	var m := TB.make(7, 0)
	TB.unit(m, 1, 141, 0)                                      # Bahatia blocks Physical summons
	m.players[0]["hand"].clear()
	TB.card(m, 0, TB.PHYSICAL)
	TB.card(m, 0, TB.WATER)
	TB.card(m, 0, TB.WATER)
	for s in [0, 1, 2, 3]:
		TB.unit(m, 0, TB.WATER, s)
	TB.cast(m, 0, 42)
	while not m.pending.is_empty():
		var pd := m.pending
		m.submit(pd["player"], {"t": "choose", "id": pd["id"], "indices": [pd["options"].size() - 1]})
	assert_int(m.field_units(0).size()).is_equal(6)


## "The Unit that Destroyed it" is only a unit: Gaping Crevasse destroyed by Martyrdom
## (a Power) paralyses nothing.
func test_destroyed_by_status_ignores_non_unit_destroyer() -> void:
	var m := TB.make()
	var mart := TB.power(m, 0, 148)
	TB.unit(m, 0, TB.WATER, 0)
	var crev := TB.unit(m, 1, 100, 0)
	TB.ability(m, mart)
	TB.choose(m, ["Basic Mage"])
	TB.choose_uids(m, [crev])
	assert_str(m.cards[crev]["zone"]).is_not_equal("unit")
	assert_bool(m.cards[mart]["st"].is_empty()).is_true()


## Every op named in a card script resolves to an _op_<name> method on MatchEngine.
func test_every_card_script_op_has_an_engine_method() -> void:
	var m := MatchEngine.new()
	var missing := []
	for d in CardDB.all():
		var entry := CardScripts.get_entry(int(d["id"]))
		_collect_missing_ops(m, entry, int(d["id"]), missing)
	assert_array(missing).is_empty()


func _collect_missing_ops(m: MatchEngine, node, id: int, missing: Array) -> void:
	if node is Dictionary:
		if node.has("op") and node["op"] is String and not m.has_method("_op_" + String(node["op"])):
			missing.append("%d:%s" % [id, node["op"]])
		for k in node:
			_collect_missing_ops(m, node[k], id, missing)
	elif node is Array:
		for v in node:
			_collect_missing_ops(m, v, id, missing)


## Review follow-up: a mode only offers options that can do something, so Auric never pays its
## 10 HP for "Destroy a face-down card" when no face-down card exists.
func test_mode_offers_only_possible_options() -> void:
	var m := TB.make()
	var au := TB.unit(m, 0, 23, 0)
	assert_str(TB.ability(m, au)).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("mode")
	var labels: Array = m.pending["options"].map(func(o): return String(o["label"]))
	assert_array(labels).is_equal(["This unit gains +10 ATK"])
	TB.set_card(m, 1, 45, 0)                                # now a face-down card exists
	m.submit(0, {"t": "cancel", "id": m.pending["id"]})
	m.cards[au]["opt"] = {}
	assert_str(TB.ability(m, au)).is_empty()
	assert_int(m.pending["options"].size()).is_equal(2)
