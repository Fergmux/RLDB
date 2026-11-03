extends GdUnitTestSuite
## F26 -- Powers and Fusion units whose card data is unchanged in the 2026-10-17 CSV,
## including the F09 Sanctified Blade regression. Complements tests/unit/cards.


# ---------------------------------------------------------------- 88 Elemental Mastery

func test_c088_elemental_mastery_raises_type_advantage_to_twelve() -> void:
	# Fire 8 + 12 = 20 beats an 18-ATK Earth defender; without the Power 8 + 6 = 14 loses.
	var m := CF.p1_battle()
	TB.power(m, 1, 88)
	var a := TB.unit(m, 1, TB.FIRE, 0)
	var dfd := TB.unit(m, 0, TB.EARTH, 0, "atk", 18)
	TB.attack(m, a, dfd)
	assert_str(CF.zone(m, dfd)).is_equal("spent")
	assert_str(CF.zone(m, a)).is_equal("unit")


func test_c088_elemental_mastery_control_without_power_attacker_loses() -> void:
	var m := CF.p1_battle()
	var a := TB.unit(m, 1, TB.FIRE, 0)
	var dfd := TB.unit(m, 0, TB.EARTH, 0, "atk", 18)
	TB.attack(m, a, dfd)
	assert_str(CF.zone(m, a)).is_equal("spent")
	assert_str(CF.zone(m, dfd)).is_equal("unit")


func test_c088_elemental_mastery_only_helps_its_controller() -> void:
	var m := CF.p1_battle()
	TB.power(m, 0, 88)                                          # the defender's Power
	var a := TB.unit(m, 1, TB.FIRE, 0)
	var dfd := TB.unit(m, 0, TB.EARTH, 0, "atk", 13)
	TB.attack(m, a, dfd)                                        # 8 + 6 = 14 beats 13
	assert_str(CF.zone(m, dfd)).is_equal("spent")


# ---------------------------------------------------------------- 91 Ritual Sanct

func test_c091_ritual_sanct_is_optional_and_only_on_own_turn() -> void:
	var m := CF.make()
	TB.power(m, 1, 91)
	var u := TB.unit(m, 1, TB.WATER, 0)
	TB.to_turn2(m)
	assert_str(CF.decline(m)).is_empty()
	assert_int(m.status_count(u, "rune")).is_equal(0)
	CF.end_turn(m)                                              # player 0's turn: no prompt for player 1
	assert_bool(m.pending.is_empty() or int(m.pending["player"]) != 1).is_true()


# ---------------------------------------------------------------- 92 Preservation Jar

func test_c092_preservation_jar_is_once_per_turn() -> void:
	var m := CF.make()
	var jar := TB.power(m, 0, 92)
	var h := TB.card(m, 0, 4)
	assert_str(TB.ability(m, jar)).is_empty()
	TB.choose_uids(m, [h])
	assert_int(m.status_count(h, "retain")).is_equal(1)
	assert_str(TB.ability(m, jar)).is_equal("Already used this turn.")


# ---------------------------------------------------------------- 148 Martyrdom

func test_c148_martyrdom_needs_an_own_unit_to_exhaust() -> void:
	var m := CF.make()
	var mart := TB.power(m, 0, 148)
	TB.unit(m, 1, TB.WATER, 0)
	assert_str(TB.ability(m, mart)).is_equal("No legal target.")


# ---------------------------------------------------------------- 139 Magical Council / 166 Saboteurs' Guild

func test_c139_magical_council_does_not_discount_traps_or_go_below_zero() -> void:
	var m := CF.make()
	TB.power(m, 0, 139)
	var trap := TB.card(m, 0, 49)                               # cost 1 Trap
	var free_spell := TB.card(m, 0, 182)                        # cost 0 Spell
	var spell := TB.card(m, 0, 84)                              # cost 2 Spell
	assert_int(m.current_cost(trap)).is_equal(1)
	assert_int(m.current_cost(free_spell)).is_equal(0)
	assert_int(m.current_cost(spell)).is_equal(1)


func test_c166_saboteurs_guild_does_not_discount_spells() -> void:
	var m := CF.make()
	TB.power(m, 0, 166)
	var trap := TB.card(m, 0, 165)                              # cost 2 Trap
	var spell := TB.card(m, 0, 84)                              # cost 2 Spell
	var opp_trap := TB.card(m, 1, 165)
	assert_int(m.current_cost(trap)).is_equal(1)
	assert_int(m.current_cost(spell)).is_equal(2)
	assert_int(m.current_cost(opp_trap)).is_equal(2)


# ---------------------------------------------------------------- 167 Shaman's Snunday Brew

func test_c167_shamans_brew_heals_and_is_once_per_turn() -> void:
	var m := CF.make()
	var brew := TB.power(m, 0, 167)
	TB.ability(m, brew)
	TB.choose(m, ["Heal 4 HP"])
	assert_int(CF.hp(m, 0)).is_equal(GameCore.START_HP + 4)
	assert_int(CF.hp(m, 1)).is_equal(GameCore.START_HP)
	assert_str(TB.ability(m, brew)).is_equal("Already used this turn.")


# ---------------------------------------------------------------- 168 Tactical Arrangements

# 2026-10-18: Tactical Arrangements draws first, then discards, so an empty Hand is no obstacle.
func test_c168_tactical_arrangements_works_from_an_empty_hand() -> void:
	var m := CF.make()
	var ta := TB.power(m, 0, 168)
	for h in m.players[0]["hand"].duplicate():
		m.move_to_pile(h, "spent")
	assert_str(TB.ability(m, ta)).is_empty()
	assert_int(m.players[0]["hand"].size()).is_equal(1)
	TB.choose_uids(m, [m.players[0]["hand"][0]])
	assert_int(m.players[0]["hand"].size()).is_equal(0)


func test_c168_tactical_arrangements_keeps_hand_size() -> void:
	var m := CF.make()
	var ta := TB.power(m, 0, 168)
	var h := TB.card(m, 0, 4)
	var size: int = m.players[0]["hand"].size()
	TB.ability(m, ta)
	TB.choose_uids(m, [h])
	assert_str(CF.zone(m, h)).is_equal("spent")
	assert_int(m.players[0]["hand"].size()).is_equal(size)


# ---------------------------------------------------------------- 169 Options

func test_c169_options_two_copies_draw_one_extra_each() -> void:
	var m := CF.make()
	TB.power(m, 1, 169, 0)
	TB.power(m, 1, 169, 1)
	TB.to_turn2(m)
	assert_int(m.players[1]["hand"].size()).is_equal(GameCore.BASE_DRAW + 2)


func test_c169_options_does_not_affect_opponent_draws() -> void:
	var m := CF.make()
	TB.power(m, 0, 169)
	TB.to_turn2(m)
	assert_int(m.players[1]["hand"].size()).is_equal(GameCore.BASE_DRAW)


# ---------------------------------------------------------------- 44 Draw Virus

func test_c044_draw_virus_does_not_stop_its_controller_setting() -> void:
	var m := CF.make()
	TB.power(m, 0, 44)
	var t := TB.card(m, 0, 45)
	assert_str(m.validate(0, {"t": "set", "uid": t})).is_empty()


# ---------------------------------------------------------------- 60 Rotmaw Risen

func test_c060_rotmaw_needs_one_debuffed_and_one_buffed_unit() -> void:
	var m := CF.make()
	var buffed := TB.unit(m, 0, TB.WATER, 0)
	m.apply_status(buffed, "pierce", 1)
	var buffed2 := TB.unit(m, 0, TB.WATER, 1)
	m.apply_status(buffed2, "pierce", 1)
	var debuffed := TB.unit(m, 0, TB.WATER, 2)
	m.apply_status(debuffed, "poison", 1)
	assert_bool(CF.fusion_mats_ok(m, 60, [debuffed, buffed])).is_true()
	assert_bool(CF.fusion_mats_ok(m, 60, [buffed, buffed2])).is_false()


func test_c060_rotmaw_poison_is_once_per_turn() -> void:
	var m := CF.make()
	var r := TB.unit(m, 0, 60, 0)
	var foe := TB.unit(m, 1, TB.WATER, 0)
	assert_str(TB.ability(m, r)).is_empty()
	TB.choose_uids(m, [foe])
	assert_int(m.status_count(foe, "poison")).is_equal(3)
	assert_str(TB.ability(m, r)).is_equal("Already used this turn.")


# ---------------------------------------------------------------- 61 Sanctified Blade (F09)
# Updated on purpose for the 2026-11-03 text: materials "Unit with 20 or more ATK or DEF + Light
# Unit"; On Summon "You can apply 8 Medic to an Adjacent Unit"; "Once per turn: you can discard a
# Unit to gain +1 AP". The F09 intent (nothing activates by itself) is kept.

func test_c061_sanctified_blade_materials_are_a_tall_unit_plus_light() -> void:
	var m := CF.make()
	var warrior := TB.unit(m, 0, 3, 0)                          # Basic Warrior (Water) 8/8
	var light := TB.unit(m, 0, 105, 1)                       # Basic Mage (Light)
	var tall := TB.unit(m, 0, TB.WATER, 2, "atk", 6, 20)
	assert_bool(CF.fusion_mats_ok(m, 61, [warrior, light])).is_false()   # the old Warrior + Light pair
	assert_bool(CF.fusion_mats_ok(m, 61, [tall, light])).is_true()


func test_c061_sanctified_blade_summon_no_longer_revives_from_spent() -> void:
	var m := CF.make()
	var small := TB.card(m, 0, 105, "spent")                    # Light, cost 1
	var ally := TB.unit(m, 0, TB.WATER, 1)
	TB.special(m, 0, 61, 0)
	assert_bool(small in CF.offered(m)).is_false()
	assert_bool(ally in CF.offered(m)).is_true()                # the 8 Medic choice instead
	CF.decline(m)
	assert_str(CF.zone(m, small)).is_equal("spent")


func test_c061_sanctified_blade_medic_never_auto_activates() -> void:
	# F09: summoning it (and declining its On Summon), more summons, a Spell and two turn starts
	# must not apply Medic, discard anything or spend the once-per-turn use.
	var m := CF.make()
	var ally := TB.unit(m, 0, TB.WATER, 1)
	var sb := TB.special(m, 0, 61, 0)
	assert_str(CF.decline(m)).is_empty()
	TB.summon(m, 0, 4, 3)
	TB.cast(m, 0, 83)
	TB.choose_uids(m, [ally])
	assert_bool(m.pending.is_empty()).is_true()
	assert_int(m.status_count(ally, "medic")).is_equal(0)
	assert_int(m.status_count(sb, "medic")).is_equal(0)
	assert_str(TB.ability(m, sb)).is_empty()                    # use still available on turn 1
	assert_str(TB.pend_kind(m)).is_equal("select")              # waits for a card choice


func test_c061_sanctified_blade_medic_survives_unrelated_turns() -> void:
	var m := CF.make()
	var sb := TB.unit(m, 0, 61, 0)
	CF.end_turn(m)
	CF.end_turn(m)                                              # player 0's turn 3
	var unit_card: int = m.players[0]["hand"].filter(func(u): return m.is_unit(u))[0]
	assert_str(TB.ability(m, sb)).is_empty()
	var ap := CF.ap(m, 0)
	TB.choose_uids(m, [unit_card])
	assert_int(CF.ap(m, 0)).is_equal(ap + 1)
	assert_str(TB.ability(m, sb)).is_equal("Already used this turn.")


func test_c061_sanctified_blade_medic_offers_only_own_adjacent_units() -> void:
	var m := CF.make()
	var right := TB.unit(m, 0, TB.WATER, 1)
	var behind := TB.unit(m, 0, TB.WATER, 3)
	var far := TB.unit(m, 0, TB.WATER, 2)
	var foe := TB.unit(m, 1, TB.WATER, 0)
	var sb := TB.special(m, 0, 61, 0)
	var offered := CF.offered(m)
	assert_bool(right in offered).is_true()
	assert_bool(behind in offered).is_true()
	assert_bool(far in offered).is_false()
	assert_bool(foe in offered).is_false()
	assert_bool(sb in offered).is_false()


func test_c061_sanctified_blade_without_adjacent_unit_keeps_its_use() -> void:
	var m := CF.make()
	var sb := TB.unit(m, 0, 61, 0)
	for h in m.players[0]["hand"].duplicate():
		m.move_to_pile(h, "spent")
	assert_str(TB.ability(m, sb)).is_equal("No legal target.")     # no unit in Hand to discard
	var u := TB.card(m, 0, TB.WATER)
	assert_str(TB.ability(m, sb)).is_empty()
	TB.choose_uids(m, [u])
	assert_str(CF.zone(m, u)).is_equal("spent")


# ---------------------------------------------------------------- 93 Bastion Wyrm

func test_c093_bastion_wyrm_materials_and_summon_eternal() -> void:
	var m := CF.make()
	var beast := TB.unit(m, 0, 4, 0)
	var phys := TB.unit(m, 0, 115, 1)                           # Basic Mage (Physical)
	var dragon := TB.unit(m, 0, 2, 2)
	var tall := TB.unit(m, 0, 2, 3, "atk", 20, 4)
	assert_bool(CF.fusion_mats_ok(m, 93, [dragon, beast])).is_false()   # 2026-11-03: the old Beast + Dragon pair
	assert_bool(CF.fusion_mats_ok(m, 93, [tall, phys])).is_true()
	assert_bool(CF.fusion_mats_ok(m, 93, [beast, phys])).is_false()      # 8/8: not 20 ATK or DEF
	var w := TB.special(m, 0, 93, 4)
	assert_int(m.status_count(w, "eternal")).is_equal(1)


# ---------------------------------------------------------------- 142 Gojirun

func test_c142_gojirun_materials_pierce_and_no_growth_on_opponent_turn() -> void:
	var m := CF.make()
	var dragon := TB.unit(m, 0, 2, 0)                           # Water Dragon
	var light := TB.unit(m, 0, 130, 1)                          # Lightning Mage
	var mage := TB.unit(m, 0, TB.WATER, 2)
	assert_bool(CF.fusion_mats_ok(m, 142, [dragon, light])).is_true()
	assert_bool(CF.fusion_mats_ok(m, 142, [dragon, mage])).is_false()
	var g := TB.special(m, 0, 142, 3)
	assert_int(m.status_count(g, "pierce")).is_equal(1)
	TB.to_turn2(m)                                              # player 1's turn
	assert_int(m.atk_of(g)).is_equal(26)                       # 2026-11-03: 26/20, no growth
	assert_int(m.def_of(g)).is_equal(20)


# ---------------------------------------------------------------- 144 Stone Guardian

func test_c144_stone_guardian_materials_and_optional_cleanse() -> void:
	var m := CF.make()
	var warrior := TB.unit(m, 0, 3, 0)
	var earth := TB.unit(m, 0, TB.EARTH, 1)
	var fire := TB.unit(m, 0, TB.FIRE, 2)
	assert_bool(CF.fusion_mats_ok(m, 144, [warrior, earth])).is_true()
	assert_bool(CF.fusion_mats_ok(m, 144, [warrior, fire])).is_false()
	m.apply_status(fire, "poison", 2)
	TB.special(m, 0, 144, 3)
	assert_str(CF.decline(m)).is_empty()
	assert_int(m.status_count(fire, "poison")).is_equal(2)


func test_c144_stone_guardian_destruction_adds_earth_unit_from_draw() -> void:
	var m := CF.make()
	var sg := TB.unit(m, 0, 144, 0)
	var earth := TB.card(m, 0, TB.EARTH, "draw")
	var fire := TB.card(m, 0, TB.FIRE, "spent")
	TB.kill(m, sg)
	assert_bool(earth in CF.offered(m)).is_true()
	assert_bool(fire in CF.offered(m)).is_false()
	TB.choose_uids(m, [earth])
	assert_str(CF.zone(m, earth)).is_equal("hand")


func test_c144_stone_guardian_is_destroyed_by_non_lightning_battle() -> void:
	var m := CF.p1_battle()
	var a := TB.unit(m, 1, TB.FIRE, 0, "atk", 60)
	var sg := TB.unit(m, 0, 144, 0)
	TB.attack(m, a, sg)
	if TB.pend_kind(m) == "select":
		CF.decline(m)
	assert_str(CF.zone(m, sg)).is_equal("spent")
