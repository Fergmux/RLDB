extends GdUnitTestSuite
## Per-card behaviour checks for Powers and Extra Deck units (Fusion, Ritual, Arcane).


# ---------------------------------------------------------------- Powers

func test_c053_power_of_normal_boosts_only_basic_units() -> void:
	var m := TB.make()
	TB.power(m, 0, 53)
	var basic := TB.unit(m, 0, TB.WATER, 0)
	var other := TB.unit(m, 0, 28, 1)
	assert_int(m.atk_of(basic)).is_equal(16)
	assert_int(m.atk_of(other)).is_equal(14)


func test_c054_strength_in_unity_scales_with_unique_races() -> void:
	var m := TB.make()
	TB.power(m, 0, 54)
	var mage := TB.unit(m, 0, TB.WATER, 0)
	TB.unit(m, 0, 4, 1)
	assert_int(m.atk_of(mage)).is_equal(16)
	assert_int(m.def_of(mage)).is_equal(16)


func test_c089_nether_portal_fuses_for_one_ap() -> void:
	var m := TB.make()
	var np := TB.power(m, 0, 89)
	TB.unit(m, 0, 4, 0)
	TB.unit(m, 0, 2, 1)
	var wyrm := TB.card(m, 0, 93, "extra")
	TB.ability(m, np)
	TB.choose_uids(m, [wyrm])
	TB.choose(m, ["Front row, column 1"])
	TB.choose(m, ["Attack"])
	assert_str(m.cards[wyrm]["zone"]).is_equal("unit")


func test_c055_spy_pays_two_hp_to_reveal_face_down_card() -> void:
	var m := TB.make()
	var spy := TB.power(m, 0, 55)
	var fd := TB.set_card(m, 1, 45, 0)
	TB.ability(m, spy)
	TB.choose_uids(m, [fd])
	assert_bool(m.is_face_up(fd)).is_true()
	assert_int(m.players[0]["hp"]).is_equal(58)


func test_c090_chains_of_binding_paralyses() -> void:
	var m := TB.make()
	var ch := TB.power(m, 0, 90)
	var foe := TB.unit(m, 1, TB.WATER, 0)
	TB.ability(m, ch)
	TB.choose_uids(m, [foe])              # a single legal target is still the player's choice
	assert_int(m.status_count(foe, "paralyse")).is_equal(1)


func test_c091_ritual_sanct_offers_a_rune_each_turn() -> void:
	var m := TB.make()
	TB.power(m, 1, 91)
	var u := TB.unit(m, 1, TB.WATER, 0)
	TB.to_turn2(m)
	TB.choose_uids(m, [u])
	assert_int(m.status_count(u, "rune")).is_equal(1)


func test_c092_preservation_jar_retains_a_hand_card() -> void:
	var m := TB.make()
	var jar := TB.power(m, 0, 92)
	var h: int = m.players[0]["hand"][0]
	TB.ability(m, jar)
	TB.choose_uids(m, [h])
	assert_int(m.status_count(h, "retain")).is_equal(1)


func test_c137_unstable_fusions_uses_and_exhausts_hand_materials() -> void:
	var m := TB.make()
	TB.power(m, 0, 137)
	var beast := TB.card(m, 0, 4)
	var dragon := TB.card(m, 0, 2)
	var wyrm := TB.card(m, 0, 93, "extra")
	TB.cast(m, 0, 82)
	TB.choose_uids(m, [wyrm])
	TB.choose(m, ["Front row, column 1"])
	TB.choose(m, ["Attack"])
	assert_str(m.cards[beast]["zone"]).is_equal("exhaust")
	assert_str(m.cards[dragon]["zone"]).is_equal("exhaust")
	assert_str(m.cards[wyrm]["zone"]).is_equal("unit")


func test_c148_martyrdom_exhausts_own_unit_to_destroy_a_unit() -> void:
	var m := TB.make()
	var mt := TB.power(m, 0, 148)
	var mine := TB.unit(m, 0, TB.WATER, 0)
	var foe := TB.unit(m, 1, TB.WATER, 0)
	TB.ability(m, mt)                     # each step is now the player's choice, even with one legal option
	TB.choose_uids(m, [mine])
	TB.choose_uids(m, [foe])
	assert_bool(m.pending.is_empty()).is_true()
	assert_str(m.cards[mine]["zone"]).is_equal("exhaust")
	assert_str(m.cards[foe]["zone"]).is_equal("spent")


func test_c149_marked_by_the_abyss_blocked_by_zero_cost_card_in_deck() -> void:
	var m := TB.make()
	TB.card(m, 0, 162, "draw")
	var mark := TB.card(m, 0, 149)
	m.players[0]["ap"] = 5
	assert_str(m.validate(0, {"t": "power", "uid": mark})).contains("0-cost")


func test_c149_marked_by_the_abyss_adds_ap_while_exhaust_has_cards() -> void:
	var m := TB.make()
	TB.power(m, 1, 149)
	TB.card(m, 1, TB.WATER, "exhaust")
	TB.to_turn2(m)
	assert_int(m.players[1]["ap"]).is_equal(3)


func test_c139_magical_council_reduces_spell_costs() -> void:
	var m := TB.make()
	TB.power(m, 0, 139)
	var s := TB.card(m, 0, 84)
	assert_int(m.current_cost(s)).is_equal(1)


func test_c166_saboteurs_guild_reduces_trap_costs() -> void:
	var m := TB.make()
	TB.power(m, 0, 166)
	var t := TB.card(m, 0, 46)
	assert_int(m.current_cost(t)).is_equal(1)


func test_c167_shamans_brew_drains_opponent() -> void:
	var m := TB.make()
	var b := TB.power(m, 0, 167)
	TB.ability(m, b)
	TB.choose(m, ["Opponent loses 4 HP"])
	assert_int(m.players[1]["hp"]).is_equal(56)


func test_c168_tactical_arrangements_cycles_a_card() -> void:
	var m := TB.make()
	var ta := TB.power(m, 0, 168)
	var h: int = m.players[0]["hand"][0]
	var n: int = m.players[0]["hand"].size()
	TB.ability(m, ta)
	TB.choose_uids(m, [h])
	assert_str(m.cards[h]["zone"]).is_equal("spent")
	assert_int(m.players[0]["hand"].size()).is_equal(n)


func test_c169_options_draws_five() -> void:
	var m := TB.make()
	TB.power(m, 1, 169)
	TB.to_turn2(m)
	assert_int(m.players[1]["hand"].size()).is_equal(5)


func test_c178_reinforcements_discounts_units_when_only_opponent_has_units() -> void:
	var m := TB.make()
	TB.power(m, 0, 178)
	var u := TB.card(m, 0, 28)
	assert_int(m.current_cost(u)).is_equal(2)
	TB.unit(m, 1, TB.WATER, 0)
	assert_int(m.current_cost(u)).is_equal(1)


func test_c179_tyrants_lantern_boosts_fire_and_punishes_both_on_fire_death() -> void:
	var m := TB.make()
	TB.power(m, 0, 179)
	var fire := TB.unit(m, 0, TB.FIRE, 0)
	assert_int(m.atk_of(fire)).is_equal(20)
	TB.kill(m, fire)
	assert_int(m.players[0]["hp"]).is_equal(54)
	assert_int(m.players[1]["hp"]).is_equal(54)


func test_c044_draw_virus_stops_opponent_setting() -> void:
	var m := TB.make()
	TB.power(m, 1, 44)
	var t := TB.card(m, 0, 45)
	assert_str(m.validate(0, {"t": "set", "uid": t})).contains("Draw Virus")


# ---------------------------------------------------------------- Fusion

func test_c056_razeon_storm_reveals_face_down_and_paralyses_all_on_death() -> void:
	var m := TB.make()
	var fd := TB.set_card(m, 1, 45, 0)
	var rz := TB.special(m, 0, 56, 0)
	assert_bool(m.is_face_up(fd)).is_true()
	var foe := TB.unit(m, 1, TB.WATER, 0)
	TB.kill(m, rz)
	assert_int(m.status_count(foe, "paralyse")).is_equal(1)


func test_c057_geolock_colossus_moves_ally_anywhere() -> void:
	var m := TB.make()
	var g := TB.unit(m, 0, 57, 0)
	var ally := TB.unit(m, 0, TB.WATER, 1)
	TB.ability(m, g)
	TB.choose_uids(m, [ally])
	TB.choose(m, ["Back row, column 3"])
	assert_int(m.cards[ally]["slot"]).is_equal(5)


func test_c058_infernogate_burns_everything() -> void:
	var m := TB.make()
	var ig := TB.unit(m, 0, 58, 0)
	var foe := TB.unit(m, 1, TB.WATER, 0)
	TB.ability(m, ig)
	assert_int(m.status_count(foe, "burn")).is_equal(10)
	assert_int(m.status_count(ig, "burn")).is_equal(10)


func test_c059_abysslord_paralyses_and_grants_infiltrate() -> void:
	var m := TB.make()
	var al := TB.unit(m, 0, 59, 0)
	var foe := TB.unit(m, 1, TB.WATER, 0)
	TB.ability(m, al, 0)
	TB.choose_uids(m, [foe])
	assert_int(m.status_count(foe, "paralyse")).is_equal(1)
	TB.ability(m, al, 1)
	TB.choose_uids(m, [al])
	assert_int(m.status_count(al, "infiltrate")).is_equal(1)


func test_c060_rotmaw_debilitates_on_summon() -> void:
	var m := TB.make()
	var foe := TB.unit(m, 1, TB.WATER, 0)
	TB.special(m, 0, 60, 0)
	TB.choose_uids(m, [foe])
	assert_int(m.status_count(foe, "debilitate")).is_equal(3)


func test_c061_sanctified_blade_heals_adjacent() -> void:
	var m := TB.make()
	var sb := TB.unit(m, 0, 61, 0)
	var ally := TB.unit(m, 0, TB.WATER, 1)
	TB.ability(m, sb)
	TB.choose_uids(m, [ally])
	assert_int(m.status_count(ally, "medic")).is_equal(3)


func test_c094_mirrorflesh_combines_material_stats_and_type() -> void:
	var m := TB.make()
	var a := TB.unit(m, 0, 110, 0, "atk", 10, 12)          # Fire
	var b := TB.unit(m, 0, 111, 1, "atk", 6, 4)            # Fire
	TB.unit(m, 0, TB.WATER, 2)
	var mf := TB.card(m, 0, 94, "extra")
	TB.cast(m, 0, 82)
	TB.choose_uids(m, [mf])
	TB.choose_uids(m, [a])
	TB.choose(m, ["Front row, column 1"])
	TB.choose(m, ["Attack"])
	assert_int(m.atk_of(mf)).is_equal(16)
	assert_int(m.def_of(mf)).is_equal(16)
	assert_str(m.unit_type(mf)).is_equal("Fire")
	assert_str(m.cards[b]["zone"]).is_equal("spent")


func test_c141_bahatia_blocks_opponent_summoning_its_type() -> void:
	var m := TB.make()
	TB.unit(m, 1, 141, 0)
	var phys := TB.card(m, 0, TB.PHYSICAL)
	assert_str(m.validate(0, {"t": "summon", "uid": phys})).contains("Bahatia")


func test_c142_gojirun_trades_def_for_atk_each_turn() -> void:
	var m := TB.make()
	var g := TB.unit(m, 1, 142, 0)
	TB.to_turn2(m)
	assert_int(m.atk_of(g)).is_equal(42)
	assert_int(m.def_of(g)).is_equal(20)


func test_c143_typhoon_simorgh_nimbles_allies_and_blinds_foes() -> void:
	var m := TB.make()
	var ts := TB.unit(m, 0, 143, 0)
	var foe := TB.unit(m, 1, TB.WATER, 0)
	TB.ability(m, ts, 0)
	TB.ability(m, ts, 1)
	assert_int(m.status_count(ts, "nimble")).is_equal(1)
	assert_int(m.status_count(foe, "blind")).is_equal(1)


func test_c144_stone_guardian_cannot_be_destroyed_by_lightning_in_battle() -> void:
	var m := TB.make()
	TB.p1_battle(m)
	var a := TB.unit(m, 1, 9, 0, "atk", 60)                  # Tag Team - L (Lightning)
	var sg := TB.unit(m, 0, 144, 0)
	TB.attack(m, a, sg)
	assert_str(m.cards[sg]["zone"]).is_equal("unit")


func test_c145_trigonam_burns_all_and_buys_hp() -> void:
	var m := TB.make()
	var foe := TB.unit(m, 1, TB.WATER, 0)
	var tg := TB.special(m, 0, 145, 0)
	assert_int(m.status_count(foe, "burn")).is_equal(10)
	TB.ability(m, tg)
	assert_int(m.players[0]["hp"]).is_equal(70)


func test_c146_akiramari_gives_medic_to_basic_units() -> void:
	var m := TB.make()
	var basic := TB.unit(m, 1, TB.WATER, 0)
	TB.special(m, 0, 146, 0)
	assert_int(m.status_count(basic, "medic")).is_equal(5)


func test_c147_demented_apparition_forces_attacks_onto_itself() -> void:
	var m := TB.make()
	TB.p1_battle(m)
	var app := TB.unit(m, 0, 147, 1)
	var other := TB.unit(m, 0, TB.WATER, 0)
	var a := TB.unit(m, 1, TB.WATER, 0)
	var targets := m.attack_targets(a)
	assert_bool(app in targets).is_true()
	assert_bool(other in targets).is_false()


func test_c147_demented_apparition_paralyses_unprotected_foes_on_summon() -> void:
	var m := TB.make()
	var foe := TB.unit(m, 1, TB.WATER, 0)
	TB.special(m, 0, 147, 0)
	assert_int(m.status_count(foe, "paralyse")).is_equal(2)


func test_c181_solomon_tyrannical_feeds_on_warriors_and_costs_hp_on_death() -> void:
	var m := TB.make()
	var st := TB.unit(m, 0, 181, 0)
	var w := TB.card(m, 0, 122, "spent")
	m.players[0]["ap"] = 2
	TB.ability(m, st)
	TB.choose_uids(m, [w])
	assert_str(m.cards[w]["zone"]).is_equal("exhaust")
	assert_int(m.status_count(st, "eternal")).is_equal(1)
	m.cards[st]["st"] = {}
	TB.kill(m, st)
	assert_int(m.players[0]["hp"]).is_equal(48)


func test_c151_ultimate_dragon_doubles_debuffs_on_death() -> void:
	var m := TB.make()
	var ud := TB.unit(m, 0, 151, 0)
	var foe := TB.unit(m, 1, TB.WATER, 0)
	m.apply_status(foe, "poison", 3)
	TB.kill(m, ud)
	TB.choose(m, ["Yes"])
	assert_int(m.status_count(foe, "poison")).is_equal(6)


# ---------------------------------------------------------------- Ritual

func test_c098_raging_inferno_burns_itself_and_its_destroyer() -> void:
	var m := TB.make()
	TB.p1_battle(m)
	var ri := TB.special(m, 0, 98, 0)
	assert_int(m.status_count(ri, "burn")).is_equal(8)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 40)
	TB.attack(m, a, ri)
	assert_int(m.status_count(a, "burn")).is_equal(4)


func test_c062_naturewrath_curses_itself_and_debilitates_column() -> void:
	var m := TB.make()
	var nw := TB.special(m, 0, 62, 0)
	assert_int(m.status_count(nw, "curse")).is_equal(1)
	var foe := TB.unit(m, 1, TB.WATER, 0)
	TB.ability(m, nw)
	TB.choose_uids(m, [foe])
	assert_int(m.status_count(foe, "debilitate")).is_equal(1)


func test_c063_last_foundation_reveals_and_destroys_weakest_foe_on_death() -> void:
	var m := TB.make()
	var fd := TB.set_card(m, 1, 45, 2)
	var lf := TB.special(m, 0, 63, 0)
	assert_bool(m.is_face_up(fd)).is_true()
	var weak := TB.unit(m, 1, TB.WATER, 0, "atk", 2)
	TB.unit(m, 1, TB.WATER, 1, "atk", 9)
	TB.kill(m, lf)
	TB.choose_uids(m, [weak])             # the lowest-ATK unit is the only legal target, but the player still confirms it
	assert_str(m.cards[weak]["zone"]).is_equal("spent")


func test_c063_last_foundation_gains_eternal_at_end_of_turn_without_buffs() -> void:
	var m := TB.make()
	var lf := TB.unit(m, 0, 63, 0)
	TB.to_turn2(m)
	assert_int(m.status_count(lf, "eternal")).is_equal(1)


func test_c064_necrovast_grows_with_exhaust() -> void:
	var m := TB.make()
	var nv := TB.unit(m, 0, 64, 0)
	TB.card(m, 0, TB.WATER, "exhaust")
	assert_int(m.atk_of(nv)).is_equal(28)


func test_c066_nyxthral_shields_neighbour_and_filters_cards() -> void:
	var m := TB.make()
	var ally := TB.unit(m, 0, TB.WATER, 1)
	var nx := TB.special(m, 0, 66, 0)
	TB.choose_uids(m, [ally])             # sole adjacent unit: still chosen by the player
	assert_int(m.status_count(ally, "eternal")).is_equal(1)
	var n: int = m.players[0]["hand"].size()
	TB.ability(m, nx)
	TB.choose_uids(m, [m.players[0]["hand"][0]])
	assert_int(m.players[0]["hand"].size()).is_equal(n)


func test_c095_mimic_copies_column_foe_and_doubles_debuffs_on_death() -> void:
	var m := TB.make()
	var foe := TB.unit(m, 1, 37, 0)
	var mm := TB.special(m, 0, 95, 0)
	TB.choose_uids(m, [foe])              # sole unprotected column foe: still chosen by the player
	assert_int(m.status_count(foe, "paralyse")).is_equal(2)
	assert_int(m.atk_of(mm)).is_equal(26)
	assert_str(m.unit_type(mm)).is_equal("Physical")
	TB.kill(m, mm)
	assert_int(m.status_count(foe, "paralyse")).is_equal(4)


func test_c065_creeping_null_paralyses_opposing_units() -> void:
	var m := TB.make()
	var a := TB.unit(m, 1, TB.WATER, 0)
	var b := TB.unit(m, 1, TB.WATER, 3)
	TB.special(m, 0, 65, 0)
	assert_int(m.status_count(a, "paralyse")).is_equal(1)
	assert_int(m.status_count(b, "paralyse")).is_equal(1)


func test_c097_legendary_swordsman_gains_cleanse_and_comeback_atk() -> void:
	var m := TB.make()
	var ls := TB.special(m, 0, 97, 0)
	assert_int(m.status_count(ls, "cleanse")).is_equal(3)
	assert_int(m.atk_of(ls)).is_equal(26)
	m.players[0]["hp"] = 40
	assert_int(m.atk_of(ls)).is_equal(56)


func test_c183_yamata_has_eight_eternal_and_burns_opponent_each_start_of_turn() -> void:
	var m := TB.make()
	var y := TB.special(m, 1, 183, 0)
	assert_int(m.status_count(y, "eternal")).is_equal(8)
	assert_int(m.script_of(y).get("abilities", []).size()).is_equal(0)   # P-30: not a manual button
	TB.to_turn2(m)
	assert_int(m.players[0]["hp"]).is_equal(54)


# ---------------------------------------------------------------- Arcane

func test_c170_grandmother_kaya_discards_for_ap() -> void:
	var m := TB.make()
	var h: int = m.players[0]["hand"][0]
	TB.special(m, 0, 170, 0)
	TB.choose_uids(m, [h])
	assert_str(m.cards[h]["zone"]).is_equal("spent")
	assert_int(m.players[0]["ap"]).is_equal(3)


func test_c170_grandmother_kaya_buys_back_a_card_on_death() -> void:
	var m := TB.make()
	var k := TB.unit(m, 0, 170, 0)
	var s := TB.card(m, 0, 21, "spent")
	TB.kill(m, k)
	TB.choose(m, ["Yes"])
	TB.choose_uids(m, [s])
	assert_str(m.cards[s]["zone"]).is_equal("hand")
	assert_int(m.players[0]["hp"]).is_equal(50)


func test_c171_flying_sandworm_grows_attacks_directly_and_exhausts() -> void:
	var m := TB.make()
	var fs := TB.unit(m, 1, 171, 0)
	TB.unit(m, 0, TB.WATER, 0)
	TB.to_turn2(m)
	assert_int(m.atk_of(fs)).is_equal(10)
	assert_bool(-1 in m.attack_targets(fs)).is_true()
	TB.kill(m, fs)
	assert_str(m.cards[fs]["zone"]).is_equal("exhaust")


func test_c172_tyde_destroys_revealed_card_when_sacrificed() -> void:
	var m := TB.make()
	var ty := TB.unit(m, 0, 172, 0)
	var fd := TB.set_card(m, 1, 45, 0)
	m.apply_status(fd, "reveal", 1)
	m.submit(0, {"t": "sacrifice", "uid": ty})
	TB.choose_uids(m, [fd])
	assert_str(m.cards[fd]["zone"]).is_equal("spent")


func test_c173_thunderclap_dragon_hits_per_opposing_unit() -> void:
	var m := TB.make()
	TB.unit(m, 1, TB.WATER, 0)
	TB.unit(m, 1, TB.WATER, 1)
	TB.special(m, 0, 173, 0)
	assert_int(m.players[1]["hp"]).is_equal(52)


func test_c175_boom_flips_opposing_stances() -> void:
	var m := TB.make()
	var a := TB.unit(m, 1, TB.WATER, 0, "atk")
	var b := TB.unit(m, 1, TB.WATER, 4, "def")
	TB.special(m, 0, 175, 0)
	assert_str(m.cards[a]["stance"]).is_equal("def")
	assert_str(m.cards[b]["stance"]).is_equal("atk")


func test_c176_tritu_atk_is_combined_atk_of_water_units() -> void:
	var m := TB.make()
	TB.unit(m, 0, TB.WATER, 1, "atk", 10)
	TB.unit(m, 1, TB.WATER, 0, "atk", 12)
	TB.unit(m, 1, TB.FIRE, 1, "atk", 50)
	var t := TB.special(m, 0, 176, 0)
	assert_int(m.atk_of(t)).is_equal(22)


func test_c177_illusionist_strong_on_own_turn_but_deals_no_battle_damage() -> void:
	var m := TB.make()
	TB.p1_battle(m)
	var il := TB.unit(m, 1, 177, 0)
	assert_int(m.atk_of(il)).is_equal(40)
	TB.attack(m, il, -1)
	assert_int(m.players[0]["hp"]).is_equal(60)
	var foe := TB.unit(m, 0, TB.WATER, 0)
	m.cards[il]["attacked_turn"] = -1
	TB.attack(m, il, foe)
	assert_str(m.cards[foe]["zone"]).is_equal("spent")
	assert_int(m.players[0]["hp"]).is_equal(60)
