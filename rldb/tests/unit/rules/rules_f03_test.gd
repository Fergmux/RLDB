extends GdUnitTestSuite
## Rules-side support for playtest feedback 03 (design/playtest-feedback-03.md): exact Arcane
## material totals (F03-04), zero-cost Arcane material filtering (F03-05), Fusion availability
## (F03-08), basic-unit display names (F03-09), Overextend's chosen target (F03-19) and the
## pending choice's effect source (F03-18).

const COST2_UNIT := 28          # Guardian of the Forest, cost 2
const COST2_UNIT_B := 32        # Frost Wyvern, cost 2
const COST3_UNIT := 13          # Chaos Witch, cost 3
const COST0_UNIT := 33          # Fledgling Drake, cost 0
const COST2_SPELL := 84         # Assassinate, cost 2
const ARCANE1 := 170            # Grandmother Kaya, 1 Arcane
const ARCANE2 := 174            # Cliff the Flying Bison, 2 Arcane
const ARCANE3 := 175            # Boom, Councillor of The Order, 3 Arcane
const FUSION_ARCANE_SPENT := 93 # Bastion Wyrm (Fusion) used as an ineligible Spent card
const POLY := 82                # Polymerization (Fusion Spell, cost 1)
const BASTION := 93             # Bastion Wyrm: Beast + Dragon
const BEAST_W := 4              # Basic Beast (Water)
const DRAGON_W := 2             # Basic Dragon (Water)
const MAGENTRIC := 69           # unit ability: Fusion Summon (Field)
const NETHER_PORTAL := 89       # Power: once per turn, pay 1 AP to Fusion Summon (Field)
const OVEREXTEND := 48


func _arcane_actions(m: MatchEngine, uid: int) -> Array:
	return MatchView.actions_for(m, 0).filter(func(a): return a.get("uid", -1) == uid and a["t"] == "arcane")


func _arcane_ok(m: MatchEngine, uid: int) -> bool:
	var acts := _arcane_actions(m, uid)
	return not acts.is_empty() and acts[0]["ok"]


func _option_uids(m: MatchEngine) -> Array:
	return m.pending["options"].map(func(o): return o["v"])


# ---------------------------------------------------------------- F03-04 exact Arcane total

func test_f03_04_requirement_two_paid_by_one_plus_one() -> void:
	var m := TB.make()
	var a := TB.card(m, 0, TB.WATER, "spent")
	var b := TB.card(m, 0, TB.FIRE, "spent")
	var cliff := TB.card(m, 0, ARCANE2, "extra")
	assert_bool(_arcane_ok(m, cliff)).is_true()
	assert_str(m.submit(0, {"t": "arcane", "uid": cliff, "stance": "atk"})).is_empty()
	assert_str(TB.choose_uids(m, [a, b])).is_empty()
	TB.choose(m, [TB.slot_label(0)])
	assert_str(m.cards[cliff]["zone"]).is_equal("unit")
	assert_str(m.cards[a]["zone"]).is_equal("exhaust")
	assert_str(m.cards[b]["zone"]).is_equal("exhaust")
	assert_int(m.players[0]["ap"]).is_equal(2)


func test_f03_04_requirement_two_paid_by_single_two() -> void:
	var m := TB.make()
	var a := TB.card(m, 0, COST2_UNIT, "spent")
	var cliff := TB.card(m, 0, ARCANE2, "extra")
	assert_bool(_arcane_ok(m, cliff)).is_true()
	m.submit(0, {"t": "arcane", "uid": cliff, "stance": "atk"})
	assert_str(TB.choose_uids(m, [a])).is_empty()
	TB.choose(m, [TB.slot_label(0)])
	assert_str(m.cards[cliff]["zone"]).is_equal("unit")


func test_f03_04_overpayment_is_rejected_and_nothing_is_consumed() -> void:
	var m := TB.make()
	var one := TB.card(m, 0, TB.WATER, "spent")
	var two := TB.card(m, 0, COST2_UNIT, "spent")
	var cliff := TB.card(m, 0, ARCANE2, "extra")
	m.submit(0, {"t": "arcane", "uid": cliff, "stance": "atk"})
	var id: int = m.pending["id"]
	assert_str(TB.choose_uids(m, [one, two])).contains("exactly")
	# The choice stays open and nothing moved.
	assert_int(m.pending["id"]).is_equal(id)
	assert_str(m.cards[one]["zone"]).is_equal("spent")
	assert_str(m.cards[two]["zone"]).is_equal("spent")
	assert_str(m.cards[cliff]["zone"]).is_equal("extra")
	assert_int(m.players[0]["ap"]).is_equal(2)


func test_f03_04_underpayment_is_rejected() -> void:
	var m := TB.make()
	var one := TB.card(m, 0, TB.WATER, "spent")
	TB.card(m, 0, TB.FIRE, "spent")
	var cliff := TB.card(m, 0, ARCANE2, "extra")
	m.submit(0, {"t": "arcane", "uid": cliff, "stance": "atk"})
	assert_str(TB.choose_uids(m, [one])).contains("exactly")
	assert_str(m.cards[one]["zone"]).is_equal("spent")


func test_f03_04_only_overpaying_materials_means_no_arcane_action() -> void:
	# A single cost-3 unit cannot pay 2 exactly, so the summon is unavailable (not "total >= cost").
	var m := TB.make()
	TB.card(m, 0, COST3_UNIT, "spent")
	var cliff := TB.card(m, 0, ARCANE2, "extra")
	assert_bool(_arcane_ok(m, cliff)).is_false()
	assert_str(m.validate(0, {"t": "arcane", "uid": cliff})).contains("exactly")


func test_f03_04_availability_is_subset_sum_not_total() -> void:
	# Spent costs 2 and 2 total 4: 3 is unreachable exactly, 2 and 4 are reachable.
	var m := TB.make()
	TB.card(m, 0, COST2_UNIT, "spent")
	TB.card(m, 0, COST2_UNIT_B, "spent")
	var boom := TB.card(m, 0, ARCANE3, "extra")
	var cliff := TB.card(m, 0, ARCANE2, "extra")
	assert_bool(_arcane_ok(m, boom)).is_false()
	assert_bool(_arcane_ok(m, cliff)).is_true()


func test_f03_04_modified_cost_determines_the_total() -> void:
	# Printed cost 3 reduced to 2 pays a requirement of 2.
	var m := TB.make()
	var w := TB.card(m, 0, COST3_UNIT, "spent")
	m.cards[w]["cost_p"] = -1
	assert_int(m.current_cost(w)).is_equal(2)
	var cliff := TB.card(m, 0, ARCANE2, "extra")
	assert_bool(_arcane_ok(m, cliff)).is_true()
	m.submit(0, {"t": "arcane", "uid": cliff, "stance": "atk"})
	assert_str(TB.choose_uids(m, [w])).is_empty()
	TB.choose(m, [TB.slot_label(0)])
	assert_str(m.cards[cliff]["zone"]).is_equal("unit")
	assert_str(m.cards[w]["zone"]).is_equal("exhaust")


func test_f03_04_extra_deck_units_and_non_units_are_ineligible() -> void:
	var m := TB.make()
	var arc := TB.card(m, 0, ARCANE2, "spent")              # an Extra Deck unit with "2"
	var spell := TB.card(m, 0, COST2_SPELL, "spent")        # a non-unit with cost 2
	var fus := TB.card(m, 0, FUSION_ARCANE_SPENT, "spent")
	var cliff := TB.card(m, 0, ARCANE2, "extra")
	assert_bool(_arcane_ok(m, cliff)).is_false()
	var mats: Array = m.arcane_materials(0)
	assert_bool(arc in mats or spell in mats or fus in mats).is_false()


func test_f03_04_authority_rejects_unoffered_and_stale_selections() -> void:
	var m := TB.make()
	var a := TB.card(m, 0, TB.WATER, "spent")
	var b := TB.card(m, 0, TB.FIRE, "spent")
	var spell := TB.card(m, 0, COST2_SPELL, "spent")
	var cliff := TB.card(m, 0, ARCANE2, "extra")
	m.submit(0, {"t": "arcane", "uid": cliff, "stance": "atk"})
	var id: int = m.pending["id"]
	assert_str(m.submit(0, {"t": "choose", "id": id, "values": [spell]})).contains("Invalid")
	assert_str(m.submit(0, {"t": "choose", "id": id + 7, "values": [a, b]})).contains("No such")
	assert_str(m.submit(1, {"t": "choose", "id": id, "values": [a, b]})).is_not_empty()
	assert_str(m.cards[a]["zone"]).is_equal("spent")


func test_f03_04_pending_choice_exposes_required_total_and_values() -> void:
	var m := TB.make()
	TB.card(m, 0, TB.WATER, "spent")
	TB.card(m, 0, COST2_UNIT, "spent")
	var cliff := TB.card(m, 0, ARCANE2, "extra")
	m.submit(0, {"t": "arcane", "uid": cliff, "stance": "atk"})
	var pv: Dictionary = MatchView.build(m, 0)["pending"]
	assert_int(int(pv["total_required"])).is_equal(2)
	assert_bool(pv["total_exact"]).is_true()
	var vals: Array = pv["options"].map(func(o): return int(o["value"]))
	vals.sort()
	assert_array(vals).is_equal([1, 2])
	assert_str(String(pv["prompt"])).contains("exactly 2")
	# The shared legality helper the picker uses agrees with the authority.
	var one := -1
	var two := -1
	for o in pv["options"]:
		if int(o["value"]) == 1: one = o["i"]
		else: two = o["i"]
	assert_str(MatchView.multi_pick_error(pv, [one])).is_not_empty()
	assert_str(MatchView.multi_pick_error(pv, [one, two])).is_not_empty()
	assert_str(MatchView.multi_pick_error(pv, [two])).is_empty()


func test_f03_04_exact_subset_helper() -> void:
	assert_array(SummonOps.exact_subset([1, 1], 2)).has_size(2)
	assert_array(SummonOps.exact_subset([3], 2)).is_empty()
	assert_array(SummonOps.exact_subset([2, 2], 3)).is_empty()
	var pick: Array = SummonOps.exact_subset([3, 1, 2], 3)
	var total := 0
	for i in pick:
		total += [3, 1, 2][i]
	assert_int(total).is_equal(3)


# ---------------------------------------------------------------- F03-05 zero-cost filter

func test_f03_05_zero_current_cost_units_are_not_offered() -> void:
	var m := TB.make()
	var zero := TB.card(m, 0, COST0_UNIT, "spent")
	var reduced := TB.card(m, 0, TB.WATER, "spent")
	m.cards[reduced]["cost_p"] = -1                    # printed 1, now 0
	var one := TB.card(m, 0, TB.FIRE, "spent")
	var kaya := TB.card(m, 0, ARCANE1, "extra")
	m.submit(0, {"t": "arcane", "uid": kaya, "stance": "atk"})
	var offered := _option_uids(m)
	assert_bool(zero in offered).is_false()
	assert_bool(reduced in offered).is_false()
	assert_bool(one in offered).is_true()


func test_f03_05_printed_zero_with_positive_current_cost_is_offered() -> void:
	var m := TB.make()
	var raised := TB.card(m, 0, COST0_UNIT, "spent")
	m.cards[raised]["cost_p"] = 1
	var kaya := TB.card(m, 0, ARCANE1, "extra")
	assert_bool(_arcane_ok(m, kaya)).is_true()
	m.submit(0, {"t": "arcane", "uid": kaya, "stance": "atk"})
	assert_bool(raised in _option_uids(m)).is_true()


func test_f03_05_zero_cost_units_still_shown_in_other_spent_selections() -> void:
	var m := TB.make()
	var zero := TB.card(m, 0, COST0_UNIT, "spent")
	var f := m.make_frame(-1, 0, [], "")
	assert_bool(zero in m.select(f, {"kind": "spent", "side": "self", "unit_card": true})).is_true()


# ---------------------------------------------------------------- F03-08 Fusion availability

func _fusion_avail(m: MatchEngine, p: int = 0) -> Array:
	var ea: Dictionary = MatchView.build(m, p)["extra_avail"]
	return ea["methods"].filter(func(x): return x["kind"] == "fusion")


func _materials(m: MatchEngine) -> Array:
	return [TB.unit(m, 0, BEAST_W, 0), TB.unit(m, 0, DRAGON_W, 1)]


func _no_hand_spells(m: MatchEngine, p: int = 0) -> void:
	m.players[p]["hand"] = m.players[p]["hand"].filter(func(u): return m.category(u) != "spell")


func test_f03_08_recipe_and_materials_without_a_method_give_no_signal() -> void:
	var m := TB.make()
	_materials(m)
	TB.card(m, 0, BASTION, "extra")
	_no_hand_spells(m)
	assert_array(_fusion_avail(m)).is_empty()
	assert_bool(MatchView.build(m, 0)["extra_avail"]["any"]).is_false()


func test_f03_08_method_without_materials_gives_no_signal() -> void:
	var m := TB.make()
	TB.unit(m, 0, BEAST_W, 0)
	TB.card(m, 0, BASTION, "extra")
	TB.card(m, 0, POLY, "hand")
	assert_array(_fusion_avail(m)).is_empty()


func test_f03_08_method_and_materials_without_extra_target_give_no_signal() -> void:
	var m := TB.make()
	_materials(m)
	TB.card(m, 0, POLY, "hand")
	assert_array(_fusion_avail(m)).is_empty()


func test_f03_08_complete_fusion_signals_and_activation_succeeds() -> void:
	var m := TB.make()
	var mats := _materials(m)
	var wyrm := TB.card(m, 0, BASTION, "extra")
	var poly := TB.card(m, 0, POLY, "hand")
	var avail := _fusion_avail(m)
	assert_int(avail.size()).is_equal(1)
	assert_int(int(avail[0]["via"])).is_equal(poly)
	assert_array(avail[0]["targets"]).contains([wyrm])
	assert_bool(MatchView.build(m, 0)["extra_avail"]["any"]).is_true()
	# The same query's verdict holds through the real activation.
	assert_str(m.submit(0, {"t": "cast", "uid": poly})).is_empty()
	var guard := 0
	while not m.pending.is_empty() and guard < 10:
		assert_str(m.submit(m.pending["player"], {"t": "choose", "id": m.pending["id"], "indices": [0]})).is_empty()
		guard += 1
	assert_str(m.cards[wyrm]["zone"]).is_equal("unit")
	assert_str(m.cards[mats[0]]["zone"]).is_equal("spent")


func test_f03_08_unaffordable_method_gives_no_signal() -> void:
	var m := TB.make()
	_materials(m)
	TB.card(m, 0, BASTION, "extra")
	TB.power(m, 0, NETHER_PORTAL)
	_no_hand_spells(m)
	m.players[0]["ap"] = 1
	assert_int(_fusion_avail(m).size()).is_equal(1)
	m.players[0]["ap"] = 0                                 # Nether Portal costs 1 AP
	assert_array(_fusion_avail(m)).is_empty()


func test_f03_08_used_once_per_turn_method_gives_no_signal() -> void:
	var m := TB.make()
	_materials(m)
	TB.card(m, 0, BASTION, "extra")
	var np := TB.power(m, 0, NETHER_PORTAL)
	_no_hand_spells(m)
	m.cards[np]["opt"][0] = m.turn
	assert_array(_fusion_avail(m)).is_empty()


func test_f03_08_wrong_phase_hand_spell_gives_no_signal() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	TB.unit(m, 1, BEAST_W, 0)
	TB.unit(m, 1, DRAGON_W, 1)
	TB.card(m, 1, BASTION, "extra")
	TB.card(m, 1, POLY, "hand")
	m.players[1]["ap"] = 5
	assert_int(_fusion_avail(m, 1).size()).is_equal(1)
	TB.to_battle(m)                                        # Spells are not cast from Hand in Battle
	assert_array(_fusion_avail(m, 1)).is_empty()


func test_f03_08_debilitated_method_or_material_gives_no_signal() -> void:
	var m := TB.make()
	var mats := _materials(m)
	TB.card(m, 0, BASTION, "extra")
	var mag := TB.unit(m, 0, MAGENTRIC, 2)
	_no_hand_spells(m)
	assert_int(_fusion_avail(m).size()).is_equal(1)
	m.apply_status(mag, "debilitate", 1)
	assert_array(_fusion_avail(m)).is_empty()
	m.cards[mag]["st"] = {}
	m.apply_status(mats[1], "debilitate", 1)                # the Dragon (Magentric is itself a Beast)
	assert_array(_fusion_avail(m)).is_empty()


func test_f03_08_full_field_with_field_materials_still_qualifies() -> void:
	var m := TB.make()
	_materials(m)
	for s in range(2, 6):
		TB.unit(m, 0, TB.WATER, s)
	assert_bool(m.free_unit_slots(0).is_empty()).is_true()
	TB.card(m, 0, BASTION, "extra")
	TB.card(m, 0, POLY, "hand")
	assert_int(_fusion_avail(m).size()).is_equal(1)


func test_f03_08_full_field_with_only_hand_materials_is_blocked() -> void:
	# Unstable Fusions lets Hand units be materials, but they free no zone on a full Field.
	var m := TB.make()
	for s in 6:
		TB.unit(m, 0, TB.WATER, s)
	TB.power(m, 0, 137)
	TB.card(m, 0, BEAST_W, "hand")
	TB.card(m, 0, DRAGON_W, "hand")
	TB.card(m, 0, BASTION, "extra")
	var poly := TB.card(m, 0, POLY, "hand")
	assert_array(_fusion_avail(m)).is_empty()
	assert_str(m.validate(0, {"t": "cast", "uid": poly})).is_not_empty()


func test_f03_08_opponent_view_has_no_fusion_information() -> void:
	var m := TB.make()
	_materials(m)
	TB.card(m, 0, BASTION, "extra")
	TB.card(m, 0, POLY, "hand")
	assert_bool(MatchView.build(m, 1)["extra_avail"]["any"]).is_false()


# ---------------------------------------------------------------- F03-19 / F03-18 Overextend

func _overextend_board() -> Dictionary:
	var m := TB.make()
	TB.to_turn2(m)
	var trap := TB.set_card(m, 0, OVEREXTEND, 1)
	var big := TB.unit(m, 1, TB.WATER, 0, "atk", 30)
	var small := TB.unit(m, 1, TB.WATER, 1, "atk", 24)
	var mine := TB.unit(m, 0, TB.WATER, 0, "atk", 12)
	var third := TB.summon(m, 1, TB.FIRE, 2)
	assert_str(TB.choose(m, ["Activate Overextend"])).is_empty()
	return {"m": m, "trap": trap, "big": big, "small": small, "mine": mine, "third": third}


func test_f03_19_overextend_can_choose_a_non_highest_unit() -> void:
	var b := _overextend_board()
	var m: MatchEngine = b["m"]
	assert_int(int(m.pending["player"])).is_equal(0)
	assert_str(TB.choose_uids(m, [b["small"]])).is_empty()
	assert_int(m.atk_of(b["small"])).is_equal(4)
	assert_int(m.atk_of(b["big"])).is_equal(30)


func test_f03_19_overextend_offers_every_opposing_unit_and_no_friendly_unit() -> void:
	var b := _overextend_board()
	var m: MatchEngine = b["m"]
	var offered := _option_uids(m)
	assert_array(offered).contains_exactly_in_any_order([b["big"], b["small"], b["third"]])
	assert_bool(b["mine"] in offered).is_false()
	assert_str(TB.choose_uids(m, [b["mine"]])).contains("Invalid")


func test_f03_19_overextend_reduction_floors_at_zero_and_lasts_on_field() -> void:
	var b := _overextend_board()
	var m: MatchEngine = b["m"]
	TB.choose_uids(m, [b["third"]])                         # Basic Mage (Fire), 8 ATK
	assert_int(m.atk_of(b["third"])).is_equal(0)
	m.submit(1, {"t": "next_phase"})
	m.submit(1, {"t": "next_phase"})
	m.submit(1, {"t": "next_phase"})                        # end of turn 2
	assert_int(m.turn).is_equal(3)
	assert_int(m.atk_of(b["third"])).is_equal(0)            # still reduced on a later turn


func test_f03_19_overextend_text_names_the_choice() -> void:
	var df := CardDB.get_def(OVEREXTEND)
	assert_str(String(df["on_summon"])).is_equal("Choose an opponent's Unit; it loses 20 ATK.")
	assert_str(String(df["condition"])).contains("3 or more Units")


func test_f03_18_pending_choice_carries_its_effect_source() -> void:
	var b := _overextend_board()
	var m: MatchEngine = b["m"]
	var mine_view: Dictionary = MatchView.build(m, 0)["pending"]
	assert_dict(mine_view["source"]).is_equal({"p": 0, "zone": "backrow", "slot": 1})
	assert_int(int(mine_view["source_uid"])).is_equal(b["trap"])
	# The opponent learns where the effect comes from (the Trap is face up now), nothing more.
	var opp_view: Dictionary = MatchView.build(m, 1)["pending"]
	assert_dict(opp_view["source"]).is_equal({"p": 0, "zone": "backrow", "slot": 1})
	assert_bool(opp_view.has("options")).is_false()
