extends GdUnitTestSuite
## Per-card behaviour checks for ordinary Units. Test names carry the card id
## (test_cNNN_...) so the support ledger can record which cards are tested.


func test_c006_tag_team_l_does_nothing_without_column_partner() -> void:
	var m := TB.make()
	TB.card(m, 0, 45, "draw")
	TB.summon(m, 0, 6, 0)
	assert_bool(m.pending.is_empty()).is_true()


func test_c008_tag_team_s_fusion_summons_from_field() -> void:
	var m := TB.make()
	# 2026-11-03 Bastion Wyrm: a unit with 20 or more ATK or DEF + a Physical unit.
	var beast := TB.unit(m, 0, 4, 3, "atk", 20, 8)
	var dragon := TB.unit(m, 0, 116, 1)                   # Basic Dragon (Physical)
	var wyrm := TB.card(m, 0, 93, "extra")
	TB.summon(m, 0, 8, 0)
	TB.choose(m, ["Yes"])
	TB.choose_uids(m, [wyrm])
	# F04-22 / F07: materials are picked one by one, then the zone; the stance choice commits.
	TB.choose_uids(m, [beast])
	TB.choose_uids(m, [dragon])
	TB.choose(m, ["Back row, column 2"])
	TB.choose(m, ["Attack"])
	assert_str(m.cards[wyrm]["zone"]).is_equal("unit")
	assert_str(m.cards[beast]["zone"]).is_equal("spent")
	assert_str(m.cards[dragon]["zone"]).is_equal("spent")


func test_c009_tag_team_f_adds_unit_with_partner_cost() -> void:
	var m := TB.make()
	TB.unit(m, 0, TB.WATER, 3)                          # cost 1 partner
	var d: int = m.players[0]["draw"][0]                # filler cost 1
	TB.summon(m, 0, 9, 0)
	TB.choose_uids(m, [d])
	assert_str(m.cards[d]["zone"]).is_equal("hand")


func test_c010_tag_team_w_destroy_still_clears_face_down_cards_in_column() -> void:
	var m := TB.make()
	var w := TB.unit(m, 0, 10, 0)
	var own := TB.set_card(m, 0, 45, 0)
	var theirs := TB.set_card(m, 1, 45, 0)
	var other_col := TB.set_card(m, 1, 45, 1)
	TB.kill(m, w)
	assert_str(m.cards[own]["zone"]).is_equal("spent")
	assert_str(m.cards[theirs]["zone"]).is_equal("spent")
	assert_str(m.cards[other_col]["zone"]).is_equal("backrow")


# 2026-10-18: Tag Team - J's On Destroy destroys a Power instead of every revealed card in its column.
func test_c011_tag_team_j_destroy_no_longer_hits_revealed_cards() -> void:
	var m := TB.make()
	var b := TB.unit(m, 0, 11, 0)
	var foe := TB.unit(m, 1, TB.WATER, 0)
	m.apply_status(foe, "reveal", 1)
	TB.kill(m, b)
	assert_str(m.cards[foe]["zone"]).is_equal("unit")


func test_c012_tag_team_x_draws_gains_ap_and_revives_into_column() -> void:
	var m := TB.make()
	TB.unit(m, 0, TB.WATER, 3)
	var x := TB.summon(m, 0, 12, 0)
	var hand_before: int = m.players[0]["hand"].size()
	TB.choose(m, ["Yes"])
	assert_int(m.players[0]["hand"].size()).is_equal(hand_before + 1)
	assert_int(m.players[0]["ap"]).is_equal(20 - 3 + 1)
	m.move_to_pile(m.players[0]["units"][3], "spent")
	var dead: int = m.players[0]["spent"][-1]
	assert_str(TB.ability(m, x)).is_empty()
	TB.choose_uids(m, [dead])
	TB.choose(m, [TB.slot_label(3)])        # the only free zone is still offered to the player
	TB.choose(m, ["Attack"])
	assert_int(m.cards[dead]["slot"]).is_equal(3)


func test_c013_chaos_witch_type_change_carries_every_mage() -> void:
	var m := TB.make()
	var witch := TB.unit(m, 0, 13, 0)
	var mage := TB.unit(m, 1, TB.WATER, 0)
	TB.ability(m, witch)
	TB.choose(m, ["Fire"])
	assert_str(m.unit_type(mage)).is_equal("Fire")
	assert_str(m.unit_type(witch)).is_equal("Fire")


func test_c014_avatar_applies_six_burn() -> void:
	var m := TB.make()
	var av := TB.unit(m, 0, 14, 0)
	var foe := TB.unit(m, 1, TB.WATER, 0)
	TB.ability(m, av)
	TB.choose_uids(m, [foe])
	assert_int(m.status_count(foe, "burn")).is_equal(6)


func test_c015_da_mage_applies_pierce() -> void:
	var m := TB.make()
	var dm := TB.unit(m, 0, 15, 0)
	TB.ability(m, dm)
	TB.choose_uids(m, [dm])                     # sole unit on the board: still chosen by the player
	assert_int(m.status_count(dm, "pierce")).is_equal(1)


func test_c019_shapeshifter_loak_copies_column_foe_and_gives_it_eternal() -> void:
	var m := TB.make()
	var foe := TB.unit(m, 1, 37, 0)            # Solomon, the Captain 20/14 Warrior (2026-11-03)
	var loak := TB.summon(m, 0, 19, 0)
	TB.choose_uids(m, [foe])                   # sole column foe: still chosen by the player
	assert_int(m.status_count(foe, "eternal")).is_equal(1)
	assert_int(m.atk_of(loak)).is_equal(20)
	assert_int(m.def_of(loak)).is_equal(14)
	assert_str(m.unit_race(loak)).is_equal("Warrior")


func test_c020_spirit_bomb_copies_buffs_and_grows_per_opposing_unit() -> void:
	var m := TB.make()
	var ally := TB.unit(m, 0, TB.WATER, 1)
	m.apply_status(ally, "pierce", 2)
	var foe := TB.unit(m, 1, TB.WATER, 0)
	m.apply_status(foe, "nimble", 1)
	var bomb := TB.summon(m, 0, 20, 0)
	assert_int(m.status_count(bomb, "pierce")).is_equal(2)
	assert_int(m.status_count(bomb, "nimble")).is_equal(1)
	assert_int(m.atk_of(bomb)).is_equal(18 + 4)               # 18 ATK (2026-11-03) + 4 per opposing unit


func test_c021_shen_gains_protection_scales_with_exhaust_and_raises_cost() -> void:
	var m := TB.make()
	var shen := TB.summon(m, 0, 21, 0)
	assert_int(m.status_count(shen, "eternal")).is_equal(1)
	assert_int(m.status_count(shen, "cleanse")).is_equal(1)    # 2026-10-17: Cleanse 3 -> 1
	TB.card(m, 0, TB.WATER, "exhaust")
	TB.card(m, 0, TB.WATER, "exhaust")
	assert_int(m.atk_of(shen)).is_equal(0 + 2 * 10)           # 0/0 since 2026-11-03, +10 per Exhaust card
	TB.kill(m, shen)
	assert_str(m.cards[shen]["zone"]).is_equal("unit")
	TB.kill(m, shen)
	assert_int(m.current_cost(shen)).is_equal(5)


func test_c022_zorath_stops_adjacent_units_attacking() -> void:
	var m := TB.make()
	TB.p1_battle(m)
	TB.unit(m, 1, 22, 0)
	var friend := TB.unit(m, 1, TB.WATER, 1)
	assert_str(m.validate(1, {"t": "attack", "uid": friend})).contains("prevents adjacent")


# 2026-11-03: the price and the gain are both 8 (were 10).
func test_c023_auric_pays_eight_hp_for_eight_atk() -> void:
	var m := TB.make()
	var auric := TB.unit(m, 0, 23, 0)
	TB.ability(m, auric)
	TB.choose(m, ["gains +8 ATK"])
	assert_int(m.atk_of(auric)).is_equal(30 + 8)    # 2026-10-17: Auric 30/16
	assert_int(m.players[0]["hp"]).is_equal(GameCore.START_HP - 8)


func test_c161_neva_exhausts_for_ten_damage_per_eternal() -> void:
	var m := TB.make()
	var neva := TB.unit(m, 0, 161, 0)
	m.apply_status(neva, "eternal", 2)
	TB.ability(m, neva)
	assert_str(m.cards[neva]["zone"]).is_equal("exhaust")
	assert_int(m.players[1]["hp"]).is_equal(40)


func test_c161_neva_gains_eternal_at_start_of_turn() -> void:
	var m := TB.make()
	var neva := TB.unit(m, 1, 161, 0)
	TB.to_turn2(m)
	assert_int(m.status_count(neva, "eternal")).is_equal(1)


func test_c024_chidori_monk_gains_infiltrate() -> void:
	var m := TB.make()
	var c := TB.summon(m, 0, 24, 0)
	assert_int(m.status_count(c, "infiltrate")).is_equal(1)


func test_c025_stormcaller_can_destroy_a_basic_unit() -> void:
	var m := TB.make()
	var foe := TB.unit(m, 1, TB.WATER, 0)
	TB.summon(m, 0, 25, 0)
	TB.choose_uids(m, [foe])
	assert_str(m.cards[foe]["zone"]).is_equal("spent")


func test_c026_brinekeeper_adds_zero_cost_card_and_destroy_clears_own_face_down() -> void:
	var m := TB.make()
	TB.unit(m, 0, TB.WATER, 3)
	var zero := TB.card(m, 0, 162, "draw")
	var bk := TB.summon(m, 0, 26, 0)
	TB.choose_uids(m, [zero])
	assert_str(m.cards[zero]["zone"]).is_equal("hand")
	var mine := TB.set_card(m, 0, 45, 2)
	var theirs := TB.set_card(m, 1, 45, 2)
	TB.kill(m, bk)
	assert_str(m.cards[mine]["zone"]).is_equal("spent")
	assert_str(m.cards[theirs]["zone"]).is_equal("backrow")


func test_c027_hydra_revives_small_dragon_into_its_zone() -> void:
	var m := TB.make()
	var hydra := TB.unit(m, 0, 27, 2)
	var drake := TB.card(m, 0, 33, "spent")
	TB.kill(m, hydra)
	TB.choose_uids(m, [drake])
	TB.choose(m, [TB.slot_label(2)])        # the only free zone is still offered to the player
	TB.choose(m, ["Attack"])
	assert_int(m.cards[drake]["slot"]).is_equal(2)


func test_c028_guardian_of_the_forest_summons_small_beast_into_column() -> void:
	var m := TB.make()
	var ff := TB.card(m, 0, 71, "spent")
	TB.summon(m, 0, 28, 0)
	TB.choose_uids(m, [ff])
	TB.choose(m, [TB.slot_label(3)])        # the only free zone is still offered to the player
	assert_int(m.cards[ff]["slot"]).is_equal(3)
	assert_str(m.cards[ff]["stance"]).is_equal("atk")   # B3: own Setup Phase, no stance prompt


func test_c029_sweeper_reveals_then_destroys_revealed_trap() -> void:
	var m := TB.make()
	var trap := TB.set_card(m, 1, 45, 0)
	var sw := TB.summon(m, 0, 29, 0)
	TB.choose_uids(m, [trap])
	assert_bool(m.is_face_up(trap)).is_true()
	assert_str(TB.ability(m, sw)).is_empty()
	TB.choose_uids(m, [trap])                  # target chosen first, then the cost is paid
	assert_str(m.cards[trap]["zone"]).is_equal("spent")


func test_c030_accio_returns_unit_from_spent_to_draw() -> void:
	var m := TB.make()
	var accio := TB.unit(m, 0, 30, 0)
	var u := TB.card(m, 0, 28, "spent")
	TB.kill(m, accio)
	TB.choose_uids(m, [u])
	assert_str(m.cards[u]["zone"]).is_equal("draw")


func test_c031_cosmic_dragon_pierce_and_medic_on_destruction() -> void:
	var m := TB.make()
	var cd := TB.summon(m, 0, 31, 0)
	assert_int(m.status_count(cd, "pierce")).is_equal(1)
	var friend := TB.unit(m, 0, TB.WATER, 1)
	TB.kill(m, cd)
	TB.choose_uids(m, [friend])
	assert_int(m.status_count(friend, "medic")).is_equal(6)       # 6 Medic since 2026-11-03 (was 3)


func test_c032_frost_wyvern_destroys_power_and_chills_column() -> void:
	var m := TB.make()
	var pw := TB.power(m, 1, 88)
	var fw := TB.summon(m, 0, 32, 0)
	TB.choose_uids(m, [pw])                    # sole Power: still chosen by the player
	assert_str(m.cards[pw]["zone"]).is_equal("spent")
	var foe := TB.unit(m, 1, TB.WATER, 0)
	TB.ability(m, fw)
	TB.choose_uids(m, [foe])
	assert_int(m.status_count(foe, "paralyse")).is_equal(1)
	assert_int(m.status_count(foe, "burn")).is_equal(4)


func test_c033_fledgling_drake_burns_column_unit() -> void:
	var m := TB.make()
	var fd := TB.unit(m, 0, 33, 1)
	var foe := TB.unit(m, 1, TB.WATER, 1)
	TB.ability(m, fd)
	TB.choose_uids(m, [foe])
	assert_int(m.status_count(foe, "burn")).is_equal(4)


func test_c035_enraged_komodo_gives_itself_pierce_once_per_turn() -> void:
	var m := TB.make()
	var k := TB.unit(m, 0, 35, 0)
	TB.ability(m, k)
	assert_int(m.status_count(k, "pierce")).is_equal(1)
	assert_str(TB.ability(m, k)).is_equal("Already used this turn.")


func test_c036_dante_revives_next_turn_for_one_ap() -> void:
	var m := TB.make()
	var dante := TB.unit(m, 0, 36, 1)
	TB.kill(m, dante)
	TB.choose(m, ["Yes"])
	TB.to_turn2(m)
	for i in 3:
		m.submit(1, {"t": "next_phase"})
	assert_str(TB.pend_kind(m)).is_equal("slot")      # the only free zone is still offered to the player
	TB.choose(m, [TB.slot_label(1)])
	assert_str(TB.pend_kind(m)).is_not_equal("stance")  # B3: returns in its owner's Setup Phase
	assert_str(m.cards[dante]["stance"]).is_equal("atk")
	assert_int(m.cards[dante]["slot"]).is_equal(1)
	assert_int(m.players[0]["ap"]).is_equal(1)


func test_c038_lone_warrior_weakens_per_adjacent_ally_and_refuses_buffs() -> void:
	var m := TB.make()
	var lw := TB.unit(m, 0, 38, 1)
	TB.unit(m, 0, TB.WATER, 0)
	TB.unit(m, 0, TB.WATER, 2)
	assert_int(m.atk_of(lw)).is_equal(24 - 2 * 6)                # 24/16 since 2026-11-03
	assert_int(m.def_of(lw)).is_equal(16 - 2 * 6)
	m.apply_status(lw, "eternal", 1)
	assert_int(m.status_count(lw, "eternal")).is_equal(0)


func test_c039_steadfast_soldier_survives_battle_with_30_atk() -> void:
	var m := TB.make()
	TB.p1_battle(m)
	var big := TB.unit(m, 1, TB.WATER, 0, "atk", 30)
	var ss := TB.unit(m, 0, 39, 0)
	TB.attack(m, big, ss)
	assert_str(m.cards[ss]["zone"]).is_equal("unit")
	assert_int(m.players[0]["hp"]).is_equal(GameCore.START_HP - (30 - 16))   # Steadfast Soldier 16 ATK (2026-11-03)


# 2026-11-03: the Fusion Summon comes first, then Void Basilisk is exhausted (it used to be the cost).
func test_c067_void_basilisk_exhausts_itself_to_fuse_from_spent() -> void:
	var m := TB.make()
	var vb := TB.unit(m, 0, 67, 0)
	# 2026-11-03 Bastion Wyrm: a unit with 20 or more ATK or DEF + a Physical unit.
	var beast := TB.card(m, 0, 28, "spent")               # Guardian of the Forest 12/22
	var dragon := TB.card(m, 0, 116, "spent")             # Basic Dragon (Physical)
	var wyrm := TB.card(m, 0, 93, "extra")
	TB.ability(m, vb)
	TB.choose_uids(m, [wyrm])
	# F04-22 / F07: materials are picked one by one, then the zone; the stance choice commits.
	TB.choose_uids(m, [beast])
	TB.choose_uids(m, [dragon])
	TB.choose(m, ["Front row, column 2"])
	TB.choose(m, ["Attack"])
	assert_str(m.cards[vb]["zone"]).is_equal("exhaust")
	assert_str(m.cards[beast]["zone"]).is_equal("exhaust")
	assert_str(m.cards[dragon]["zone"]).is_equal("exhaust")
	assert_str(m.cards[wyrm]["zone"]).is_equal("unit")


# 2026-11-03: the Fusion Summon comes first, then Seppuku is destroyed, so its own zone is not
# offered for the Fusion unit any more (it used to leave first, as a cost).
func test_c068_sepukku_destroys_itself_to_fuse() -> void:
	var m := TB.make()
	var sp := TB.unit(m, 0, 68, 0)
	var beast := TB.unit(m, 0, 4, 1, "atk", 20, 8)       # 20 or more ATK or DEF (2026-11-03 Bastion Wyrm)
	var dragon := TB.unit(m, 0, 116, 2)                  # Basic Dragon (Physical)
	var wyrm := TB.card(m, 0, 93, "extra")
	TB.ability(m, sp)
	TB.choose_uids(m, [wyrm])
	# F04-22 / F07: materials are picked one by one, then the zone; the stance choice commits.
	TB.choose_uids(m, [beast])
	TB.choose_uids(m, [dragon])
	assert_array(CF.labels(m)).not_contains(["Front row, column 1"])   # Seppuku still holds it
	TB.choose(m, ["Front row, column 2"])                # a material's zone, freed by the Tribute
	TB.choose(m, ["Attack"])
	assert_str(m.cards[sp]["zone"]).is_equal("spent")
	assert_str(m.cards[wyrm]["zone"]).is_equal("unit")


# 2026-11-03: the On Summon is an optional 1 Cleanse on an adjacent unit (was 2 Pierce).
func test_c069_magentric_gives_adjacent_unit_one_cleanse() -> void:
	var m := TB.make()
	var friend := TB.unit(m, 0, TB.WATER, 1)
	TB.summon(m, 0, 69, 0)
	TB.choose_uids(m, [friend])                 # sole adjacent unit: still chosen by the player
	assert_int(m.status_count(friend, "cleanse")).is_equal(1)
	assert_int(m.status_count(friend, "pierce")).is_equal(0)


func test_c040_aleister_pays_one_ap_to_fuse() -> void:
	var m := TB.make()
	var al := TB.unit(m, 0, 40, 0)
	var beast := TB.unit(m, 0, 4, 1, "atk", 20, 8)       # 20 or more ATK or DEF (2026-11-03 Bastion Wyrm)
	var dragon := TB.unit(m, 0, 116, 2)                  # Basic Dragon (Physical)
	var wyrm := TB.card(m, 0, 93, "extra")
	m.players[0]["ap"] = 2
	m.submit(0, {"t": "ability", "uid": al, "idx": 0})
	assert_int(m.players[0]["ap"]).is_equal(2)          # every choice is made before the cost (F04-22)
	TB.choose_uids(m, [wyrm])
	TB.choose_uids(m, [beast])
	TB.choose_uids(m, [dragon])
	TB.choose(m, ["Front row, column 2"])
	TB.choose(m, ["Attack"])                            # F07: the stance commits; the cost follows
	assert_int(m.players[0]["ap"]).is_equal(1)
	assert_str(m.cards[wyrm]["zone"]).is_equal("unit")


func test_c070_krakeshin_gains_atk_when_moving() -> void:
	var m := TB.make()
	var k := TB.summon(m, 0, 70, 0)
	assert_int(m.status_count(k, "nimble")).is_equal(3)
	m.submit(0, {"t": "move", "uid": k})
	TB.choose(m, ["Front row, column 2"])
	assert_int(m.atk_of(k)).is_equal(12 + 6)                 # 12 ATK, +6 per move (2026-11-03)


func test_c071_faerie_flight_gains_three_medic_when_moving() -> void:
	var m := TB.make()
	var ff := TB.unit(m, 0, 71, 0)
	TB.ability(m, ff)
	TB.choose_uids(m, [ff])                     # 2026-10-17: Nimble to a unit (itself here)
	m.submit(0, {"t": "move", "uid": ff})
	TB.choose(m, ["Front row, column 2"])
	assert_int(m.status_count(ff, "medic")).is_equal(3)


func test_c072_myth_wukong_switches_rows_and_bonus_at_end_of_turn() -> void:
	var m := TB.make()
	var wk := TB.unit(m, 0, 72, 0)                         # 16/16, +16 DEF in front, +16 ATK behind (2026-11-03)
	assert_int(m.def_of(wk)).is_equal(16 + 16)
	TB.to_turn2(m)
	assert_int(m.cards[wk]["slot"]).is_equal(3)
	assert_int(m.atk_of(wk)).is_equal(16 + 16)
	assert_int(m.def_of(wk)).is_equal(16)


func test_c073_mans_best_friend_searches_warrior_and_dies_for_column_warrior() -> void:
	var m := TB.make()
	var w := TB.card(m, 0, 122, "draw")
	var mbf := TB.summon(m, 0, 73, 3)
	TB.choose_uids(m, [w])
	assert_str(m.cards[w]["zone"]).is_equal("hand")
	var warrior := TB.unit(m, 0, 122, 0)
	TB.kill(m, warrior)
	assert_str(m.cards[warrior]["zone"]).is_equal("unit")
	assert_str(m.cards[mbf]["zone"]).is_equal("spent")


func test_c074_sparky_gives_infiltrate_when_sacrificed() -> void:
	var m := TB.make()
	var sp := TB.unit(m, 0, 74, 0)
	var friend := TB.unit(m, 0, TB.WATER, 1)
	m.submit(0, {"t": "sacrifice", "uid": sp})
	TB.choose_uids(m, [friend])                 # sole other unit: still chosen by the player
	assert_int(m.status_count(friend, "infiltrate")).is_equal(1)


func test_c016_edwin_gains_rune_when_you_destroy_an_opponent_unit() -> void:
	var m := TB.make()
	TB.p1_battle(m)
	var edwin := TB.unit(m, 1, 16, 3)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 30)
	var foe := TB.unit(m, 0, TB.WATER, 0)
	TB.attack(m, a, foe)
	assert_int(m.status_count(edwin, "rune")).is_equal(1)


func test_c017_accursed_zealot_gains_rune_each_own_turn() -> void:
	var m := TB.make()
	var z := TB.unit(m, 1, 17, 0)
	TB.to_turn2(m)
	assert_int(m.status_count(z, "rune")).is_equal(1)


func test_c075_travelwarden_gains_rune_when_ally_moves() -> void:
	var m := TB.make()
	var tw := TB.unit(m, 0, 75, 2)
	var mover := TB.unit(m, 0, TB.WATER, 0)
	m.apply_status(mover, "nimble", 1)
	m.submit(0, {"t": "move", "uid": mover})
	TB.choose(m, ["Back row, column 1"])
	assert_int(m.status_count(tw, "rune")).is_equal(1)


func test_c076_soul_devourer_gains_rune_when_any_unit_is_sacrificed() -> void:
	var m := TB.make()
	var sd := TB.unit(m, 0, 76, 0)
	var fodder := TB.unit(m, 0, TB.WATER, 1)
	m.submit(0, {"t": "sacrifice", "uid": fodder})
	assert_int(m.status_count(sd, "rune")).is_equal(1)


func test_c077_radablast_gains_rune_when_trap_activates() -> void:
	var m := TB.make()
	TB.p1_battle(m)
	var rb := TB.unit(m, 1, 77, 3)
	TB.set_card(m, 0, 50, 0)                              # Wabuku
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 5)
	var foe := TB.unit(m, 0, TB.WATER, 0)
	TB.attack(m, a, foe)
	TB.choose(m, ["Activate Wabuku"])
	assert_int(m.status_count(rb, "rune")).is_equal(1)


func test_c078_abraxus_cleanses_poisons_and_recovers_dragon() -> void:
	var m := TB.make()
	var ab := TB.summon(m, 0, 78, 0)
	assert_int(m.status_count(ab, "cleanse")).is_equal(1)
	var foe := TB.unit(m, 1, TB.WATER, 0)
	TB.ability(m, ab)
	TB.choose_uids(m, [foe])
	assert_int(m.status_count(foe, "poison")).is_equal(4)
	var dragon := TB.card(m, 0, 2, "spent")
	m.cards[ab]["st"] = {}
	TB.kill(m, ab)
	TB.choose_uids(m, [dragon])
	assert_str(m.cards[dragon]["zone"]).is_equal("hand")


func test_c079_akakaiju_destroys_a_water_unit() -> void:
	var m := TB.make()
	var water := TB.unit(m, 1, TB.WATER, 0)
	TB.unit(m, 1, TB.FIRE, 1)
	TB.summon(m, 0, 79, 0)
	TB.choose_uids(m, [water])                  # only Water unit: still chosen by the player
	assert_str(m.cards[water]["zone"]).is_equal("spent")


func test_c099_anduras_moves_unit_from_spent_to_draw() -> void:
	var m := TB.make()
	var u := TB.card(m, 0, 28, "spent")
	TB.summon(m, 0, 99, 0)
	TB.choose_uids(m, [u])
	assert_str(m.cards[u]["zone"]).is_equal("draw")


func test_c102_waang_changes_type_and_curses_matching_type() -> void:
	var m := TB.make()
	var w := TB.unit(m, 0, 102, 0)
	var fire_foe := TB.unit(m, 1, TB.FIRE, 0)
	m.apply_status(fire_foe, "pierce", 1)
	TB.ability(m, w, 0)
	TB.choose(m, ["Fire"])
	assert_str(m.unit_type(w)).is_equal("Fire")
	TB.ability(m, w, 1)
	if TB.pend_kind(m) == "select":
		TB.choose_uids(m, [fire_foe])
	assert_int(m.status_count(fire_foe, "pierce")).is_equal(0)


func test_c135_dragon_rider_boosts_protecting_dragon_and_cannot_attack() -> void:
	var m := TB.make()
	TB.p1_battle(m)
	var dragon := TB.unit(m, 1, 2, 0)
	var rider := TB.unit(m, 1, 135, 3)
	assert_int(m.atk_of(dragon)).is_equal(22)
	assert_str(m.validate(1, {"t": "attack", "uid": rider})).contains("Dragon Rider")


func test_c150_mumens_bounty_puts_spent_card_on_top_of_draw_and_cannot_defend() -> void:
	var m := TB.make()
	var top := TB.card(m, 0, 21, "spent")
	var mb := TB.summon(m, 0, 150, 0)
	TB.choose_uids(m, [top])
	assert_int(m.players[0]["draw"][-1]).is_equal(top)
	assert_str(m.validate(0, {"t": "stance", "uid": mb})).contains("cannot be in Defense")


func test_c162_diggie_blinds_the_unit_that_destroyed_it() -> void:
	var m := TB.make()
	TB.p1_battle(m)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	var dig := TB.unit(m, 0, 162, 0)
	TB.attack(m, a, dig)
	assert_int(m.status_count(a, "blind")).is_equal(1)


func test_c155_symbiote_spawn_still_boosts_its_protector() -> void:
	var m := TB.make()
	var front := TB.unit(m, 0, TB.WATER, 0)
	var sym := TB.summon(m, 0, 155, 3)
	assert_int(m.status_count(sym, "eternal")).is_equal(1)
	assert_int(m.atk_of(front)).is_equal(8 + 6)               # +6 since 2026-11-03 (was +10)


func test_c157_symbiote_siphonophore_needs_protection_for_its_boost() -> void:
	var m := TB.make()
	var a := TB.unit(m, 0, TB.WATER, 0)
	var far := TB.unit(m, 0, TB.WATER, 2)
	TB.unit(m, 0, 157, 3)
	assert_int(m.atk_of(a)).is_equal(8 + 6)                   # +6 since 2026-11-03 (was +10)
	assert_int(m.atk_of(far)).is_equal(8)


func test_c158_divine_serpent_head_paralyses_column_unit() -> void:
	var m := TB.make()
	var h := TB.unit(m, 0, 158, 2)
	var foe := TB.unit(m, 1, TB.WATER, 2)
	TB.ability(m, h)
	TB.choose_uids(m, [foe])
	assert_int(m.status_count(foe, "paralyse")).is_equal(1)


func test_c159_divine_serpent_body_adjacent_def_aura() -> void:
	var m := TB.make()
	var friend := TB.unit(m, 0, TB.WATER, 1)
	TB.unit(m, 0, 159, 0)
	assert_int(m.def_of(friend)).is_equal(18)


func test_c160_divine_serpent_soul_weakens_opposing_units() -> void:
	var m := TB.make()
	var s := TB.unit(m, 0, 160, 0)
	var a := TB.unit(m, 1, TB.WATER, 0)
	var b := TB.unit(m, 1, TB.WATER, 1)
	TB.ability(m, s)
	assert_int(m.atk_of(a)).is_equal(4)
	assert_int(m.atk_of(b)).is_equal(4)
