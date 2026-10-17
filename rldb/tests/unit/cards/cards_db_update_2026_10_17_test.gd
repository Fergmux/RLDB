extends GdUnitTestSuite
## Behaviour of the cards changed by the 17 October 2026 card database
## (design/card-database-diff-2026-10-17.md; ledger design/production-batch-2026-10-17/card-ledger.md).
## Test names carry the card id (test_cNNN_...) for the support ledger. Each new effect is tested
## with its target rules, and each removed effect is shown not to run any more.

const MAGE_WATER := 1
const DRAGON_WATER := 2
const WARRIOR_WATER := 3
const BEAST_WATER := 4
const BEAST_FIRE := 113
const MAGE_FIRE := 110
const MAGIC_CYLINDER := 45           # Trap, cost 1
const SACRED_OFFERINGS := 83         # Spell, cost 1
const ASSASSINATE := 84              # Spell, cost 2
const MAGENTRIC := 69                # Unit, cost 2
const BRINEKEEPER := 26              # Monster Unit, cost 1


func _opts(m: MatchEngine) -> Array:
	return m.pending.get("options", []).map(func(o): return int(o["v"]))


func _labels(m: MatchEngine) -> Array:
	return m.pending.get("options", []).map(func(o): return String(o["label"]))


# ---------------------------------------------------------------- Tag Teams by stable ID

func test_c006_tag_team_l_optionally_adds_a_trap_that_costs_one_less() -> void:
	var m := TB.make(7, 0)
	TB.unit(m, 0, MAGE_WATER, 3)
	var trap := TB.card(m, 0, MAGIC_CYLINDER, "draw")
	var unit := TB.card(m, 0, BEAST_WATER, "draw")
	TB.summon(m, 0, 6, 0)
	assert_array(_opts(m)).contains_exactly_in_any_order([-1, trap])
	TB.choose_uids(m, [trap])
	assert_str(m.cards[trap]["zone"]).is_equal("hand")
	assert_str(m.cards[unit]["zone"]).is_equal("draw")
	assert_int(m.current_cost(trap)).is_equal(0)


func test_c006_tag_team_l_skip_leaves_the_trap_in_draw() -> void:
	var m := TB.make(7, 0)
	TB.unit(m, 0, MAGE_WATER, 3)
	var trap := TB.card(m, 0, MAGIC_CYLINDER, "draw")
	TB.summon(m, 0, 6, 0)
	TB.choose(m, ["Skip"])
	assert_str(m.cards[trap]["zone"]).is_equal("draw")
	assert_int(m.current_cost(trap)).is_equal(1)


func test_c007_tag_team_b_adds_a_spell_and_no_longer_cleanses() -> void:
	var m := TB.make(7, 0)
	var back := TB.unit(m, 0, MAGE_WATER, 3)
	m.apply_status(back, "poison", 2)
	var spell := TB.card(m, 0, SACRED_OFFERINGS, "draw")
	TB.card(m, 0, MAGIC_CYLINDER, "draw")
	TB.summon(m, 0, 7, 0)
	assert_array(_opts(m)).contains_exactly_in_any_order([-1, spell])
	TB.choose_uids(m, [spell])
	assert_str(m.cards[spell]["zone"]).is_equal("hand")
	assert_int(m.current_cost(spell)).is_equal(0)
	assert_int(m.status_count(back, "poison")).is_equal(2)     # the old Cleanse is gone
	assert_bool(m.pending.is_empty()).is_true()


func test_c009_tag_team_f_adds_same_cost_unit_with_discount_and_new_stats() -> void:
	var df := CardDB.get_def(9)
	assert_int(df["cost"]).is_equal(2)
	assert_int(df["def"]).is_equal(22)
	var m := TB.make(7, 0)
	TB.unit(m, 0, MAGE_WATER, 3)                                 # cost-1 partner
	var same := TB.card(m, 0, BEAST_WATER, "draw")
	TB.card(m, 0, MAGENTRIC, "draw")                             # cost 2: not offered
	TB.card(m, 0, SACRED_OFFERINGS, "draw")                      # not a unit
	TB.summon(m, 0, 9, 0)
	assert_array(_opts(m)).contains_exactly_in_any_order([-1, same])
	TB.choose_uids(m, [same])
	assert_str(m.cards[same]["zone"]).is_equal("hand")
	assert_int(m.current_cost(same)).is_equal(0)


func test_c010_tag_team_w_search_is_mandatory_same_race_with_discount() -> void:
	var m := TB.make(7, 0)
	TB.unit(m, 0, MAGE_WATER, 3)                                 # Mage partner
	var mage := TB.card(m, 0, MAGE_FIRE, "draw")
	TB.card(m, 0, BEAST_WATER, "draw")
	TB.card(m, 0, MAGIC_CYLINDER, "draw")                        # the old Trap search is gone
	TB.summon(m, 0, 10, 0)
	assert_array(_opts(m)).contains_exactly([mage])             # no Skip: "add", not "you can"
	TB.choose_uids(m, [mage])
	assert_str(m.cards[mage]["zone"]).is_equal("hand")
	assert_int(m.current_cost(mage)).is_equal(0)


func test_c011_tag_team_j_adds_same_type_unit_with_discount() -> void:
	var m := TB.make(7, 0)
	TB.unit(m, 0, MAGE_WATER, 3)                                 # Water partner
	var water := TB.card(m, 0, BEAST_WATER, "draw")
	TB.card(m, 0, BEAST_FIRE, "draw")
	TB.card(m, 0, SACRED_OFFERINGS, "draw")                      # the old Spell search is gone
	TB.summon(m, 0, 11, 0)
	assert_array(_opts(m)).contains_exactly_in_any_order([-1, water])
	TB.choose_uids(m, [water])
	assert_int(m.current_cost(water)).is_equal(0)


func test_c011_tag_team_j_typeless_partner_matches_nothing() -> void:
	var m := TB.make(7, 0)
	TB.unit(m, 0, 13, 3)                                         # Chaos Witch: typeless Mage
	TB.card(m, 0, BEAST_WATER, "draw")
	TB.summon(m, 0, 11, 0)
	assert_bool(m.pending.is_empty()).is_true()


func test_c010_c011_discount_expires_after_this_turn() -> void:
	var m := TB.make(7, 0)
	TB.unit(m, 0, MAGE_WATER, 3)
	var water := TB.card(m, 0, BEAST_WATER, "draw")
	TB.summon(m, 0, 11, 0)
	TB.choose_uids(m, [water])
	m.turn += 2
	assert_int(m.current_cost(water)).is_equal(1)


# ---------------------------------------------------------------- Chaos Witch, Da Mage, divine units

func test_c013_chaos_witch_changes_its_own_type_and_every_mage_follows() -> void:
	var m := TB.make()
	var witch := TB.unit(m, 0, 13, 0)
	var own_mage := TB.unit(m, 0, MAGE_FIRE, 1)
	var foe_mage := TB.unit(m, 1, MAGE_WATER, 0)
	var beast := TB.unit(m, 1, BEAST_WATER, 1)
	assert_str(m.unit_type(own_mage)).is_equal("Fire")            # a typeless Witch imposes nothing
	assert_str(TB.ability(m, witch)).is_empty()
	assert_bool(_labels(m).has("No type")).is_false()             # "except for ?"
	TB.choose(m, ["Earth"])
	assert_str(m.unit_type(witch)).is_equal("Earth")
	assert_str(m.unit_type(own_mage)).is_equal("Earth")
	assert_str(m.unit_type(foe_mage)).is_equal("Earth")
	assert_str(m.unit_type(beast)).is_equal("Water")
	TB.kill(m, witch)
	assert_str(m.unit_type(own_mage)).is_equal("Fire")
	if not m.pending.is_empty():
		TB.choose(m, ["No"])


func test_c015_da_mage_destroyed_can_give_eternal_to_a_mage_in_its_column() -> void:
	var m := TB.make()
	var dm := TB.unit(m, 0, 15, 0)
	var col_mage := TB.unit(m, 0, MAGE_WATER, 3)
	TB.unit(m, 0, MAGE_FIRE, 1)                                  # other column: not offered
	TB.unit(m, 1, BEAST_WATER, 0)                                # same column, not a Mage
	TB.kill(m, dm)
	assert_array(_opts(m)).contains_exactly_in_any_order([-1, col_mage])
	TB.choose_uids(m, [col_mage])
	assert_int(m.status_count(col_mage, "eternal")).is_equal(1)


func test_c021_c022_c023_c161_divine_units_apply_one_cleanse() -> void:
	for id in [21, 22, 23, 161]:
		var m := TB.make()
		var u := TB.special(m, 0, id, 0)
		assert_int(m.status_count(u, "cleanse")).override_failure_message(str(id)).is_equal(1)
		assert_int(m.status_count(u, "eternal")).override_failure_message(str(id)).is_equal(1)
	var auric := CardDB.get_def(23)
	assert_int(auric["atk"]).is_equal(30)
	assert_int(auric["def"]).is_equal(16)


# ---------------------------------------------------------------- Stormcaller, Sweeper, Abysslord

func test_c025_stormcaller_destroys_all_unprotected_basic_units_without_asking() -> void:
	var m := TB.make()
	var own_front := TB.unit(m, 0, MAGE_WATER, 0)
	var own_back := TB.unit(m, 0, MAGE_FIRE, 3)                  # protected by own_front
	var foe_basic := TB.unit(m, 1, BEAST_WATER, 1)
	var foe_unit := TB.unit(m, 1, BRINEKEEPER, 2)
	var storm := TB.summon(m, 0, 25, 1)
	assert_bool(m.pending.is_empty()).is_true()                   # mandatory: no prompt
	assert_str(m.cards[own_front]["zone"]).is_equal("spent")
	assert_str(m.cards[foe_basic]["zone"]).is_equal("spent")
	assert_str(m.cards[own_back]["zone"]).is_equal("unit")
	assert_str(m.cards[foe_unit]["zone"]).is_equal("unit")
	assert_str(m.cards[storm]["zone"]).is_equal("unit")


func test_c029_sweeper_reveals_a_spell_or_trap_in_its_column() -> void:
	var m := TB.make()
	var own_set := TB.set_card(m, 0, MAGIC_CYLINDER, 0)
	var foe_set := TB.set_card(m, 1, SACRED_OFFERINGS, 0)
	TB.set_card(m, 1, MAGIC_CYLINDER, 1)                         # other column
	TB.summon(m, 0, 29, 0)
	assert_array(_opts(m)).contains_exactly_in_any_order([-1, own_set, foe_set])
	TB.choose_uids(m, [foe_set])
	assert_int(m.status_count(foe_set, "reveal")).is_equal(1)


func test_c059_abysslord_destroys_a_spell_or_trap_without_reveal() -> void:
	var m := TB.make()
	var foe_set := TB.set_card(m, 1, MAGIC_CYLINDER, 2)          # not revealed
	TB.special(m, 0, 59, 0)
	assert_array(_opts(m)).contains(foe_set)
	TB.choose_uids(m, [foe_set])
	assert_str(m.cards[foe_set]["zone"]).is_equal("spent")


# ---------------------------------------------------------------- Accio, Dante, Solomon the Captain

func test_c030_accio_sends_a_draw_unit_to_spent_then_retains_a_hand_unit() -> void:
	var m := TB.make(7, 0)
	var du := TB.card(m, 0, BEAST_WATER, "draw")
	TB.card(m, 0, SACRED_OFFERINGS, "draw")
	var hu := TB.card(m, 0, BEAST_FIRE, "hand")
	var hs := TB.card(m, 0, ASSASSINATE, "hand")
	TB.summon(m, 0, 30, 0)
	assert_array(_opts(m)).contains_exactly_in_any_order([-1, du])
	TB.choose_uids(m, [du])
	assert_str(m.cards[du]["zone"]).is_equal("spent")
	assert_array(_opts(m)).contains_exactly([hu])                # units in Hand only
	TB.choose_uids(m, [hu])
	assert_int(m.status_count(hu, "retain")).is_equal(1)
	assert_int(m.status_count(hs, "retain")).is_equal(0)


func test_c030_accio_skip_sends_nothing_and_retains_nothing() -> void:
	var m := TB.make(7, 0)
	var du := TB.card(m, 0, BEAST_WATER, "draw")
	var hu := TB.card(m, 0, BEAST_FIRE, "hand")
	TB.summon(m, 0, 30, 0)
	TB.choose(m, ["Skip"])
	assert_bool(m.pending.is_empty()).is_true()
	assert_str(m.cards[du]["zone"]).is_equal("draw")
	assert_int(m.status_count(hu, "retain")).is_equal(0)


func test_c036_dante_burns_every_unit_and_gains_atk_from_its_own_burn() -> void:
	var m := TB.make()
	var ally := TB.unit(m, 0, MAGE_WATER, 1)
	var foe := TB.unit(m, 1, BEAST_WATER, 0)
	var foe_back := TB.unit(m, 1, MAGE_FIRE, 3)                  # protected units burn too
	var dante := TB.summon(m, 0, 36, 0)
	for u in [ally, foe, foe_back, dante]:
		assert_int(m.status_count(u, "burn")).is_equal(6)
	assert_int(m.atk_of(dante)).is_equal(28 + 6)


func test_c036_dante_manual_ten_burn_on_any_unit_once_per_turn() -> void:
	var m := TB.make()
	var dante := TB.unit(m, 0, 36, 0)
	var foe := TB.unit(m, 1, BEAST_WATER, 2)                     # not adjacent: any unit qualifies
	assert_str(TB.ability(m, dante)).is_empty()
	TB.choose_uids(m, [foe])
	TB.choose(m, ["10 Burn"])
	assert_int(m.status_count(foe, "burn")).is_equal(10)
	assert_str(TB.ability(m, dante)).is_not_empty()               # once per turn


func test_c036_dante_burning_itself_raises_its_atk_and_cleanse_lowers_it() -> void:
	var m := TB.make()
	var dante := TB.unit(m, 0, 36, 0)
	TB.ability(m, dante)
	TB.choose_uids(m, [dante])
	TB.choose(m, ["10 Burn"])
	assert_int(m.atk_of(dante)).is_equal(38)
	m.turn += 2
	TB.ability(m, dante)
	TB.choose_uids(m, [dante])
	TB.choose(m, ["1 Cleanse"])
	assert_int(m.status_count(dante, "burn")).is_equal(0)
	assert_int(m.atk_of(dante)).is_equal(28)


func test_c037_solomon_captain_gains_ten_only_while_protected() -> void:
	var m := TB.make()
	var sol := TB.unit(m, 0, 37, 3)
	assert_int(m.atk_of(sol)).is_equal(26)                       # back row, nothing in front
	var front := TB.unit(m, 0, MAGE_WATER, 0)
	assert_int(m.atk_of(sol)).is_equal(36)
	TB.kill(m, front)
	assert_int(m.atk_of(sol)).is_equal(26)
	var m2 := TB.make()
	var sol2 := TB.unit(m2, 0, 37, 0)
	TB.unit(m2, 0, MAGE_WATER, 3)                                # protecting is no longer rewarded
	assert_int(m2.atk_of(sol2)).is_equal(26)


# ---------------------------------------------------------------- Magentric's tribute benefit

func test_c069_magentric_tributed_for_a_fusion_gives_it_two_pierce() -> void:
	var m := TB.make()
	var mag := TB.unit(m, 0, MAGENTRIC, 0)                       # Beast
	var dragon := TB.unit(m, 0, DRAGON_WATER, 1)
	var wyrm := TB.card(m, 0, 93, "extra")                       # Bastion Wyrm: Beast + Dragon
	TB.cast(m, 0, 82)
	TB.choose_uids(m, [wyrm])
	TB.choose_uids(m, [mag])
	TB.choose_uids(m, [dragon])
	TB.choose(m, ["Front row, column 1"])
	TB.choose(m, ["Attack"])
	assert_str(m.cards[wyrm]["zone"]).is_equal("unit")
	assert_int(m.status_count(wyrm, "pierce")).is_equal(2)


func test_c069_magentric_tributed_for_a_ritual_gives_it_two_pierce() -> void:
	var m := TB.make()
	var mag := TB.unit(m, 0, MAGENTRIC, 0)
	m.apply_status(mag, "rune", 2)
	var nec := TB.card(m, 0, 64, "extra")                        # Necrovast, 2R
	assert_str(m.submit(0, {"t": "ritual", "uid": nec, "stance": "atk"})).is_empty()
	TB.choose_uids(m, [mag])
	TB.choose(m, ["Front row, column 1"])
	assert_str(m.cards[nec]["zone"]).is_equal("unit")
	assert_int(m.status_count(nec, "pierce")).is_equal(2)


func test_c069_other_fusion_materials_give_no_pierce() -> void:
	var m := TB.make()
	var beast := TB.unit(m, 0, BEAST_WATER, 0)
	var dragon := TB.unit(m, 0, DRAGON_WATER, 1)
	TB.unit(m, 0, MAGENTRIC, 2)                                  # on the Field but not tributed
	var wyrm := TB.card(m, 0, 93, "extra")
	TB.cast(m, 0, 82)
	TB.choose_uids(m, [wyrm])
	TB.choose_uids(m, [beast])
	TB.choose_uids(m, [dragon])
	TB.choose(m, ["Front row, column 1"])
	TB.choose(m, ["Attack"])
	assert_int(m.status_count(wyrm, "pierce")).is_equal(0)


func test_c069_magentric_exhausted_for_an_arcane_summon_gives_nothing() -> void:
	var m := TB.make()
	var mag := TB.card(m, 0, MAGENTRIC, "spent")                 # cost 2
	var cliff := TB.card(m, 0, 174, "extra")                     # Cliff, 2A
	assert_str(m.submit(0, {"t": "arcane", "uid": cliff, "stance": "atk"})).is_empty()
	TB.choose_uids(m, [mag])
	TB.choose(m, ["Front row, column 1"])
	assert_str(m.cards[cliff]["zone"]).is_equal("unit")
	assert_int(m.status_count(cliff, "pierce")).is_equal(0)
	var df := CardDB.get_def(MAGENTRIC)
	assert_int(df["atk"]).is_equal(20)
	assert_int(df["def"]).is_equal(20)


# ---------------------------------------------------------------- Faerie, Wukong, Narzyl, Diggie

func test_c071_faerie_flight_grants_nimble_to_any_unit() -> void:
	var m := TB.make()
	var ff := TB.unit(m, 0, 71, 0)
	var ally := TB.unit(m, 0, MAGE_WATER, 2)
	assert_str(TB.ability(m, ff)).is_empty()
	TB.choose_uids(m, [ally])
	assert_int(m.status_count(ally, "nimble")).is_equal(1)
	assert_int(m.status_count(ff, "nimble")).is_equal(0)
	assert_int(CardDB.get_def(71)["def"]).is_equal(16)


func test_c072_myth_wukong_gains_nimble_on_summon() -> void:
	var m := TB.make()
	var wk := TB.special(m, 0, 72, 0)
	assert_int(m.status_count(wk, "nimble")).is_equal(1)


func test_c018_corrupted_narzyl_applies_one_paralyse() -> void:
	var m := TB.make()
	var foe := TB.unit(m, 1, BEAST_WATER, 0)
	TB.summon(m, 0, 18, 0)
	TB.choose_uids(m, [foe])
	assert_int(m.status_count(foe, "paralyse")).is_equal(1)


func test_c162_diggie_sacrificed_costs_one_more_for_the_game() -> void:
	var m := TB.make()
	var dig := TB.unit(m, 0, 162, 0)
	assert_int(m.atk_of(dig)).is_equal(6)
	assert_str(m.submit(0, {"t": "sacrifice", "uid": dig})).is_empty()
	assert_str(m.cards[dig]["zone"]).is_equal("spent")
	assert_int(m.current_cost(dig)).is_equal(1)


func test_c162_diggie_destroyed_keeps_its_cost() -> void:
	var m := TB.make()
	var dig := TB.unit(m, 0, 162, 0)
	TB.kill(m, dig)
	assert_int(m.current_cost(dig)).is_equal(0)


# ---------------------------------------------------------------- Symbiotes

func test_c155_symbiote_spawn_boosts_its_protector_by_ten() -> void:
	var m := TB.make()
	var front := TB.unit(m, 0, MAGE_WATER, 0)
	TB.unit(m, 0, 155, 3)
	assert_int(m.atk_of(front)).is_equal(18)
	assert_str(CardDB.get_def(155)["name"]).is_equal("Symbiote Spawn")


func test_c156_symbiote_larva_boosts_protector_by_ten_and_draws_then_discards() -> void:
	var m := TB.make()
	var front := TB.unit(m, 1, MAGE_WATER, 0)
	TB.unit(m, 1, 156, 3)
	assert_int(m.atk_of(front)).is_equal(18)
	var hand_before: int = m.players[1]["hand"].size()
	var spent_before: int = m.players[1]["spent"].size()
	TB.to_turn2(m)                                               # player 1's turn starts
	assert_int(int(m.pending.get("player", -1))).is_equal(1)
	assert_str(String(m.pending.get("prompt", ""))).contains("Discard")
	var pick: int = int(m.pending["options"][0]["v"])
	TB.choose_uids(m, [pick])
	assert_str(m.cards[pick]["zone"]).is_equal("spent")
	assert_int(m.players[1]["spent"].size()).is_equal(spent_before + 1)
	assert_int(m.players[1]["hand"].size()).is_greater(hand_before)   # normal draw + Larva's draw - discard


func test_c157_symbiote_siphonophore_boosts_adjacent_only_while_protected() -> void:
	var m := TB.make()
	var sip := TB.unit(m, 0, 157, 4)                             # back row, column 2
	var adj := TB.unit(m, 0, MAGE_WATER, 3)                      # adjacent, back row
	assert_int(m.atk_of(adj)).is_equal(8)                        # not protected yet
	TB.unit(m, 0, MAGE_FIRE, 1)                                  # protector in front
	assert_int(m.atk_of(adj)).is_equal(18)
	assert_str(CardDB.get_def(157)["name"]).is_equal("Symbiote Siphonophore")
	assert_int(m.atk_of(sip)).is_equal(0)


func test_c157_symbiote_siphonophore_draws_an_extra_card_at_start_of_turn() -> void:
	var m := TB.make()
	var hand_before: int = m.players[1]["hand"].size()
	TB.unit(m, 1, 157, 3)
	TB.to_turn2(m)
	var m2 := TB.make()
	var hand_before2: int = m2.players[1]["hand"].size()
	TB.to_turn2(m2)
	assert_int(m.players[1]["hand"].size() - hand_before).is_equal(m2.players[1]["hand"].size() - hand_before2 + 1)


# ---------------------------------------------------------------- Geolock, Last Foundation, Tyde

func test_c057_geolock_summon_grants_infiltrate_and_nimble_to_your_units() -> void:
	var m := TB.make()
	var ally := TB.unit(m, 0, MAGE_WATER, 1)
	var foe := TB.unit(m, 1, BEAST_WATER, 0)
	var geo := TB.special(m, 0, 57, 0)
	TB.choose(m, ["Yes"])
	for u in [ally, geo]:
		assert_int(m.status_count(u, "infiltrate")).is_equal(1)
		assert_int(m.status_count(u, "nimble")).is_equal(1)
	assert_int(m.status_count(foe, "nimble")).is_equal(0)


func test_c057_geolock_changes_stance_of_unprotected_foes_and_no_longer_moves() -> void:
	var m := TB.make()
	var geo := TB.unit(m, 0, 57, 0)
	var front := TB.unit(m, 1, BEAST_WATER, 0, "atk")
	var back := TB.unit(m, 1, MAGE_WATER, 3, "atk")              # protected
	assert_int(CardScripts.get_entry(57)["abilities"].size()).is_equal(1)
	assert_str(TB.ability(m, geo)).is_empty()
	assert_str(m.cards[front]["stance"]).is_equal("def")
	assert_str(m.cards[back]["stance"]).is_equal("atk")


func test_c057_geolock_ability_needs_an_unprotected_foe() -> void:
	var m := TB.make()
	var geo := TB.unit(m, 0, 57, 0)
	assert_str(TB.ability(m, geo)).is_not_empty()


func test_c063_last_foundation_reveals_spells_traps_and_gains_eternal_even_when_buffed() -> void:
	var m := TB.make()
	var own_set := TB.set_card(m, 0, MAGIC_CYLINDER, 1)
	var foe_set := TB.set_card(m, 1, SACRED_OFFERINGS, 2)
	var lf := TB.special(m, 0, 63, 0)
	assert_int(m.status_count(own_set, "reveal")).is_equal(1)
	assert_int(m.status_count(foe_set, "reveal")).is_equal(1)
	m.apply_status(lf, "nimble", 1)                              # a Buff no longer blocks Eternal
	var before := m.status_count(lf, "eternal")
	TB.to_turn2(m)
	assert_int(m.status_count(lf, "eternal")).is_equal(before + 1)
	assert_bool(m.has_flag(lf, "cant_move")).is_false()           # the movement restriction is gone


func test_c172_tyde_adds_a_beast_with_discount_and_destroys_a_runed_unit() -> void:
	var m := TB.make(7, 0)
	var beast := TB.card(m, 0, BEAST_FIRE, "draw")
	TB.card(m, 0, MAGE_FIRE, "draw")
	var tyde := TB.special(m, 0, 172, 0)
	assert_array(_opts(m)).contains_exactly_in_any_order([-1, beast])
	TB.choose_uids(m, [beast])
	assert_int(m.current_cost(beast)).is_equal(0)
	var plain := TB.unit(m, 1, MAGE_WATER, 0)
	var runed := TB.unit(m, 1, MAGE_WATER, 1)
	m.apply_status(runed, "rune", 1)
	assert_str(TB.ability(m, tyde)).is_empty()
	assert_array(_opts(m)).contains_exactly([runed])
	TB.choose_uids(m, [runed])
	assert_str(m.cards[runed]["zone"]).is_equal("spent")
	assert_str(m.cards[plain]["zone"]).is_equal("unit")


func test_c172_tyde_sacrificed_no_longer_destroys_anything() -> void:
	var m := TB.make()
	var tyde := TB.unit(m, 0, 172, 0)
	var foe_set := TB.set_card(m, 1, MAGIC_CYLINDER, 0)
	m.apply_status(foe_set, "reveal", 1)
	assert_str(m.submit(0, {"t": "sacrifice", "uid": tyde})).is_empty()
	assert_bool(m.pending.is_empty()).is_true()
	assert_str(m.cards[foe_set]["zone"]).is_equal("backrow")


# ---------------------------------------------------------------- Solomon the Tyrannical

func test_c181_solomon_tyrannical_exhausts_the_unit_it_protects() -> void:
	var m := TB.make()
	var sol := TB.unit(m, 0, 181, 0)
	var ward := TB.unit(m, 0, MAGE_WATER, 3)
	TB.unit(m, 0, MAGE_FIRE, 4)                                  # not protected by Solomon
	var warrior := TB.card(m, 0, WARRIOR_WATER, "spent")         # the old Spent cost is gone
	var ap: int = 5
	m.players[0]["ap"] = ap
	assert_str(TB.ability(m, sol)).is_empty()
	assert_array(_opts(m)).contains_exactly([ward])
	TB.choose_uids(m, [ward])
	assert_str(m.cards[ward]["zone"]).is_equal("exhaust")
	assert_str(m.cards[warrior]["zone"]).is_equal("spent")
	assert_int(m.status_count(sol, "eternal")).is_equal(1)
	assert_int(m.players[0]["ap"]).is_equal(ap + 1)
	assert_str(TB.ability(m, sol)).is_not_empty()                 # once per turn


func test_c181_solomon_tyrannical_needs_to_be_protecting() -> void:
	var m := TB.make()
	var sol := TB.unit(m, 0, 181, 0)
	TB.card(m, 0, WARRIOR_WATER, "spent")
	assert_str(TB.ability(m, sol)).is_not_empty()
	var m2 := TB.make()
	var sol2 := TB.unit(m2, 0, 181, 3)                           # back row: protects nobody
	TB.unit(m2, 0, MAGE_WATER, 0)
	assert_str(TB.ability(m2, sol2)).is_not_empty()


# ---------------------------------------------------------------- The Illusionist and Rituals

func test_c177_illusionist_is_typeless_and_gains_thirty_on_its_own_turn() -> void:
	var m := TB.make()
	var ill := TB.unit(m, 0, 177, 0)
	assert_str(m.unit_type(ill)).is_equal("")
	assert_int(m.atk_of(ill)).is_equal(60)
	TB.to_turn2(m)
	assert_int(m.atk_of(ill)).is_equal(30)


func test_c177_illusionist_destroyed_recovers_a_low_cost_card_from_own_exhaust() -> void:
	var m := TB.make()
	var ill := TB.unit(m, 0, 177, 0)
	var cheap := TB.card(m, 0, MAGE_WATER, "exhaust")            # cost 1
	var free := TB.card(m, 0, 33, "exhaust")                     # cost 0
	TB.card(m, 0, MAGENTRIC, "exhaust")                          # cost 2
	TB.card(m, 0, 174, "exhaust")                                # Extra Deck: no ordinary cost
	TB.card(m, 1, MAGE_WATER, "exhaust")                         # opponent's Exhaust
	TB.kill(m, ill)
	assert_array(_opts(m)).contains_exactly_in_any_order([-1, cheap, free])
	TB.choose_uids(m, [cheap])
	assert_str(m.cards[cheap]["zone"]).is_equal("draw")


func test_c177_illusionist_recovery_is_optional() -> void:
	var m := TB.make()
	var ill := TB.unit(m, 0, 177, 0)
	var cheap := TB.card(m, 0, MAGE_WATER, "exhaust")
	TB.kill(m, ill)
	TB.choose(m, ["Skip"])
	assert_str(m.cards[cheap]["zone"]).is_equal("exhaust")


func test_c095_c065_c183_ritual_costs_and_stats_follow_the_new_source() -> void:
	var mimic := CardDB.get_def(95)
	assert_str(mimic["cost_kind"]).is_equal("ritual")
	assert_int(mimic["cost"]).is_equal(2)
	assert_that(mimic["atk"]).is_null()
	var null_u := CardDB.get_def(65)
	assert_int(null_u["atk"]).is_equal(40)
	assert_int(null_u["def"]).is_equal(28)
	var yam := CardDB.get_def(183)
	assert_int(yam["cost"]).is_equal(3)
	assert_int(yam["atk"]).is_equal(12)
	assert_int(yam["def"]).is_equal(20)
	assert_that(CardDB.get_def(96)["cost"]).is_null()


func test_c095_mimic_accepts_a_two_rune_material() -> void:
	var m := TB.make()
	var mat := TB.unit(m, 0, MAGE_WATER, 0)
	m.apply_status(mat, "rune", 2)
	TB.unit(m, 1, BEAST_WATER, 0)
	var mimic := TB.card(m, 0, 95, "extra")
	assert_str(m.submit(0, {"t": "ritual", "uid": mimic, "stance": "atk"})).is_empty()
	assert_array(_opts(m)).contains([mat])


func test_c183_yamata_three_runes_and_start_of_turn_damage_kept() -> void:
	var m := TB.make()
	var mat := TB.unit(m, 1, MAGE_WATER, 0)
	m.apply_status(mat, "rune", 3)
	TB.to_turn2(m)
	var yam := TB.card(m, 1, 183, "extra")
	assert_str(m.submit(1, {"t": "ritual", "uid": yam, "stance": "atk"})).is_empty()
	TB.choose_uids(m, [mat])
	TB.choose(m, ["Front row, column 1"])
	assert_str(m.cards[yam]["zone"]).is_equal("unit")
	var hp0: int = m.players[0]["hp"]
	m.submit(1, {"t": "next_phase"})
	m.submit(1, {"t": "next_phase"})
	m.submit(1, {"t": "next_phase"})                             # player 0's turn: no Yamata damage
	assert_int(m.players[0]["hp"]).is_equal(hp0)
