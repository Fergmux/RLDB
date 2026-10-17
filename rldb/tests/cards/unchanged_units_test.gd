extends GdUnitTestSuite
## F26 -- ordinary Units whose card data is unchanged in the 2026-10-17 CSV. These add the
## optional/illegal-target/once-per-turn/negative cases that tests/unit/cards does not cover.


# ---------------------------------------------------------------- 14 Avatar of the Flame Spirit

func test_c014_avatar_on_summon_rune_is_optional() -> void:
	var m := CF.make()
	var foe := TB.unit(m, 1, TB.WATER, 0)
	var av := TB.summon(m, 0, 14, 0)
	assert_str(TB.pend_kind(m)).is_equal("select")
	assert_str(CF.decline(m)).is_empty()
	assert_int(m.status_count(av, "rune")).is_equal(0)
	assert_int(m.status_count(foe, "rune")).is_equal(0)


func test_c014_avatar_on_summon_rune_can_target_an_opponent_unit() -> void:
	var m := CF.make()
	var foe := TB.unit(m, 1, TB.WATER, 0)
	TB.summon(m, 0, 14, 0)
	TB.choose_uids(m, [foe])
	assert_int(m.status_count(foe, "rune")).is_equal(1)


func test_c014_avatar_burn_is_once_per_turn() -> void:
	var m := CF.make()
	var av := TB.unit(m, 0, 14, 0)
	var foe := TB.unit(m, 1, TB.WATER, 0)
	assert_str(TB.ability(m, av)).is_empty()
	TB.choose_uids(m, [foe])
	assert_str(TB.ability(m, av)).is_equal("Already used this turn.")
	assert_int(m.status_count(foe, "burn")).is_equal(6)


func test_c014_avatar_destruction_costs_both_players_six_hp() -> void:
	var m := CF.make()
	var av := TB.unit(m, 0, 14, 0)
	TB.kill(m, av)
	assert_int(CF.hp(m, 0)).is_equal(GameCore.START_HP - 6)
	assert_int(CF.hp(m, 1)).is_equal(GameCore.START_HP - 6)


# ---------------------------------------------------------------- 24 Chidori Monk

func test_c024_chidori_monk_infiltrate_comes_from_summon_only() -> void:
	var m := CF.make()
	var placed := TB.unit(m, 0, 24, 1)                  # put on the Field without a summon
	var summoned := TB.summon(m, 0, 24, 0)
	assert_int(m.status_count(placed, "infiltrate")).is_equal(0)
	assert_int(m.status_count(summoned, "infiltrate")).is_equal(1)
	assert_int(CF.ap(m, 0)).is_equal(19)


# ---------------------------------------------------------------- 26 Brinekeeper Summoner

func test_c026_brinekeeper_without_column_partner_adds_nothing() -> void:
	var m := CF.make()
	var zero := TB.card(m, 0, 33, "draw")                # Fledgling Drake, cost 0
	TB.summon(m, 0, 26, 0)
	assert_bool(m.pending.is_empty()).is_true()
	assert_str(CF.zone(m, zero)).is_equal("draw")


func test_c026_brinekeeper_only_offers_zero_cost_cards() -> void:
	var m := CF.make()
	TB.unit(m, 0, TB.WATER, 3)
	var zero := TB.card(m, 0, 33, "draw")
	TB.summon(m, 0, 26, 0)
	var offered := CF.offered(m)
	assert_bool(zero in offered).is_true()
	for u in offered:
		assert_int(m.current_cost(u)).is_equal(0)


func test_c026_brinekeeper_destruction_spares_opponent_face_down_cards() -> void:
	var m := CF.make()
	var bk := TB.unit(m, 0, 26, 0)
	var own := TB.set_card(m, 0, 49, 2)
	var theirs := TB.set_card(m, 1, 49, 0)
	TB.kill(m, bk)
	assert_str(CF.zone(m, own)).is_equal("spent")
	assert_str(CF.zone(m, theirs)).is_equal("backrow")


# ---------------------------------------------------------------- 27 Hydra

func test_c027_hydra_offers_only_one_cost_dragons_and_can_decline() -> void:
	var m := CF.make()
	var hy := TB.unit(m, 0, 27, 1)
	var small := TB.card(m, 0, 2, "spent")              # Basic Dragon, cost 1
	var big := TB.card(m, 0, 31, "spent")               # Cosmic Dragon, cost 3
	var beast := TB.card(m, 0, 4, "spent")              # Basic Beast, cost 1, not a Dragon
	TB.kill(m, hy)
	var offered := CF.offered(m)
	assert_bool(small in offered).is_true()
	assert_bool(big in offered).is_false()
	assert_bool(beast in offered).is_false()
	assert_str(CF.decline(m)).is_empty()
	assert_str(CF.zone(m, small)).is_equal("spent")
	assert_int(m.players[0]["units"][1]).is_equal(-1)


# ---------------------------------------------------------------- 28 Guardian of the Forest

func test_c028_guardian_rejects_beasts_costing_more_than_one() -> void:
	var m := CF.make()
	var small := TB.card(m, 0, 4, "spent")              # Basic Beast, cost 1
	var big := TB.card(m, 0, 70, "spent")               # Krakeshin, Beast cost 3
	TB.summon(m, 0, 28, 0)
	var offered := CF.offered(m)
	assert_bool(small in offered).is_true()
	assert_bool(big in offered).is_false()
	assert_str(CF.decline(m)).is_empty()
	assert_str(CF.zone(m, small)).is_equal("spent")


# ---------------------------------------------------------------- 31 Cosmic Dragon

func test_c031_cosmic_dragon_summon_pierce_and_optional_medic() -> void:
	var m := CF.make()
	var cd := TB.summon(m, 0, 31, 0)
	assert_int(m.status_count(cd, "pierce")).is_equal(1)
	var ally := TB.unit(m, 0, TB.WATER, 1)
	TB.kill(m, cd)
	assert_str(CF.decline(m)).is_empty()
	assert_int(m.status_count(ally, "medic")).is_equal(0)


# ---------------------------------------------------------------- 33 Fledgling Drake

func test_c033_fledgling_drake_cannot_burn_outside_its_column() -> void:
	var m := CF.make()
	var fd := TB.unit(m, 0, 33, 0)
	var col := TB.unit(m, 1, TB.WATER, 0)
	var other := TB.unit(m, 1, TB.WATER, 1)
	assert_str(TB.ability(m, fd)).is_empty()
	var offered := CF.offered(m)
	assert_bool(col in offered).is_true()
	assert_bool(other in offered).is_false()
	TB.choose_uids(m, [col])
	assert_int(m.status_count(col, "burn")).is_equal(4)
	assert_str(TB.ability(m, fd)).is_equal("Already used this turn.")


func test_c033_fledgling_drake_costs_zero_ap() -> void:
	var m := CF.make()
	TB.summon(m, 0, 33, 0)
	assert_int(CF.ap(m, 0)).is_equal(20)


# ---------------------------------------------------------------- 70 Krakeshin

func test_c070_krakeshin_summons_with_three_nimble() -> void:
	var m := CF.make()
	var k := TB.summon(m, 0, 70, 0)
	assert_int(m.status_count(k, "nimble")).is_equal(3)
	assert_int(m.atk_of(k)).is_equal(14)


# ---------------------------------------------------------------- 73 Mans Best Friend

func test_c073_mans_best_friend_search_offers_only_warriors() -> void:
	var m := CF.make()
	var warrior := TB.card(m, 0, 3, "draw")             # Basic Warrior
	TB.summon(m, 0, 73, 0)
	var offered := CF.offered(m)
	assert_bool(warrior in offered).is_true()
	for u in offered:
		assert_str(m.unit_race(u)).is_equal("Warrior")


func test_c073_mans_best_friend_does_not_guard_non_warriors() -> void:
	var m := CF.make()
	var dog := TB.unit(m, 0, 73, 3)
	var beast := TB.unit(m, 0, 4, 0)                    # Basic Beast in the same column
	TB.kill(m, beast)
	assert_str(CF.zone(m, beast)).is_equal("spent")
	assert_str(CF.zone(m, dog)).is_equal("unit")


# ---------------------------------------------------------------- 74 Sparky

func test_c074_sparky_destroyed_by_effect_gives_nothing() -> void:
	var m := CF.make()
	var sp := TB.unit(m, 0, 74, 0)
	var friend := TB.unit(m, 0, TB.WATER, 1)
	TB.kill(m, sp)
	assert_bool(m.pending.is_empty()).is_true()
	assert_int(m.status_count(friend, "infiltrate")).is_equal(0)


# ---------------------------------------------------------------- 17 Accursed Zealot

func test_c017_accursed_zealot_ignores_opponent_turn_start() -> void:
	var m := CF.make()
	var z := TB.unit(m, 0, 17, 0)
	TB.to_turn2(m)                                     # player 1's turn starts
	assert_int(m.status_count(z, "rune")).is_equal(0)
	CF.end_turn(m)                                     # player 0's turn 3 starts
	assert_int(m.status_count(z, "rune")).is_equal(1)


# ---------------------------------------------------------------- 77 Radablast

func test_c077_radablast_ignores_spells() -> void:
	var m := CF.make()
	var r := TB.unit(m, 0, 77, 0)
	var t := TB.cast(m, 0, 83)                         # Sacred Offerings is a Spell, not a Trap
	TB.choose_uids(m, [r])
	assert_int(m.status_count(r, "rune")).is_equal(1)   # only the Spell's own Rune
	assert_str(CF.zone(m, t)).is_equal("spent")


# ---------------------------------------------------------------- 79 Akakaiju

func test_c079_akakaiju_cannot_destroy_non_water_units() -> void:
	var m := CF.make()
	var fire := TB.unit(m, 1, TB.FIRE, 0)
	TB.summon(m, 0, 79, 0)
	assert_bool(m.pending.is_empty()).is_true()
	assert_str(CF.zone(m, fire)).is_equal("unit")


func test_c079_akakaiju_infiltrate_once_per_turn_and_reveal_on_destruction() -> void:
	var m := CF.make()
	var ak := TB.unit(m, 0, 79, 0)
	var ally := TB.unit(m, 0, TB.FIRE, 1)
	assert_str(TB.ability(m, ak)).is_empty()
	TB.choose_uids(m, [ally])
	assert_int(m.status_count(ally, "infiltrate")).is_equal(1)
	assert_str(TB.ability(m, ak)).is_equal("Already used this turn.")
	var fd := TB.set_card(m, 1, 49, 0)
	TB.kill(m, ak)
	assert_bool(fd in CF.offered(m)).is_true()
	TB.choose_uids(m, [fd])
	assert_int(m.status_count(fd, "reveal")).is_equal(1)


# ---------------------------------------------------------------- 99 Anduras

func test_c099_anduras_only_moves_units() -> void:
	var m := CF.make()
	var spell := TB.card(m, 0, 83, "spent")
	var unit_card := TB.card(m, 0, 4, "spent")
	TB.summon(m, 0, 99, 0)
	var offered := CF.offered(m)
	assert_bool(unit_card in offered).is_true()
	assert_bool(spell in offered).is_false()
	TB.choose_uids(m, [unit_card])
	assert_str(CF.zone(m, unit_card)).is_equal("draw")


# ---------------------------------------------------------------- 150 Mumen's Bounty

func test_c150_mumens_bounty_gives_ap_when_sacrificed_not_when_destroyed() -> void:
	var m := CF.make()
	var a := TB.unit(m, 0, 150, 0)
	var b := TB.unit(m, 0, 150, 1)
	var plain := TB.unit(m, 0, TB.WATER, 2)
	var before := CF.ap(m, 0)
	TB.kill(m, a)
	assert_int(CF.ap(m, 0)).is_equal(before)
	m.submit(0, {"t": "sacrifice", "uid": plain})       # the rules' own +1 AP for any sacrifice
	assert_int(CF.ap(m, 0)).is_equal(before + 1)
	m.submit(0, {"t": "sacrifice", "uid": b})           # +1 rule AP, +1 from Mumen's Bounty
	assert_int(CF.ap(m, 0)).is_equal(before + 3)
