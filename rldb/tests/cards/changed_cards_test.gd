extends GdUnitTestSuite
## F26 -- cards changed in the 2026-10-17 CSV, tested against the migrated behaviour.
## Starts with the cards that had no per-card test (34, 45, 46, 51, 96, 100, 174, 180) and the
## stat/cost balance changes. Expected numbers come from design/card-database-diff-2026-10-17.md,
## not from cards.json, so an importer regression cannot silently move both sides.


# ---------------------------------------------------------------- balance (stat / cost) changes

## [id, new cost, new ATK on the Field, new DEF on the Field]; -1 = not asserted (unchanged or
## modified by an On Summon / aura the placement does not trigger).
## 2026-11-03: rows re-pinned to the 3 Nov sheet (design/card-database-update-2026-11-03.md,
## "Stat-only changes"); the 2026-10-17 value each one replaced is kept in its comment.
const BALANCE := [
	[9, 2, 10, 16],      # Tag Team - F: cost 1 -> 2 (10-17); 16/22 -> 10/16 (11-03)
	[23, 4, 30, 16],     # Auric: 50/50 -> 30/16 (10-17)
	[69, -1, 16, 16],    # Magentric: 8/26 -> 20/20 (10-17) -> 16/16 (11-03)
	[71, -1, -1, 18],    # Faerie Flight: DEF 18 -> 16 (10-17) -> 18 (11-03)
	[78, -1, 8, -1],     # Abraxus Terrormane: ATK 26 -> 24 (10-17) -> 8 (11-03)
	[162, -1, 6, -1],    # Diggie: ATK 2 -> 6 (10-17)
	[171, -1, 6, 6],     # Flying Sandworm: ATK 4 -> 6; DEF 6 (2026-11-03)
]


# @cards 9,23,69,71,78,162,171
func test_changed_cards_use_their_new_stats_and_costs_in_play() -> void:
	var bad := []
	for row in BALANCE:
		var m := CF.make()
		var u := TB.unit(m, 0, row[0], 0)
		if row[2] != -1 and m.atk_of(u) != row[2]: bad.append("%d ATK %d != %d" % [row[0], m.atk_of(u), row[2]])
		if row[3] != -1 and m.def_of(u) != row[3]: bad.append("%d DEF %d != %d" % [row[0], m.def_of(u), row[3]])
		if row[1] != -1:
			var h := TB.card(m, 0, row[0])
			if m.current_cost(h) != row[1]: bad.append("%d cost %d != %d" % [row[0], m.current_cost(h), row[1]])
	assert_array(bad).is_empty()


func test_c009_tag_team_f_summon_pays_its_new_two_ap_cost() -> void:
	var m := CF.make()
	TB.summon(m, 0, 9, 0)
	if TB.pend_kind(m) != "":
		CF.decline(m)
	assert_int(CF.ap(m, 0)).is_equal(18)


func test_c162_diggie_new_six_atk_wins_against_a_five_atk_unit() -> void:
	var m := CF.p1_battle()
	var dg := TB.unit(m, 1, 162, 0)
	var foe := TB.unit(m, 0, TB.WATER, 0, "atk", 5)
	TB.attack(m, dg, foe)
	assert_str(CF.zone(m, foe)).is_equal("spent")


# ---------------------------------------------------------------- 34 Dragon of the Cave

func test_c034_dragon_of_the_cave_gives_only_adjacent_units_six_def() -> void:
	var m := CF.make()
	# Adjacency includes diagonals (GameCore.adjacent_slots); from a corner, column 3 is not adjacent.
	var cave := TB.unit(m, 0, 34, 0)
	var right := TB.unit(m, 0, TB.WATER, 1)
	var behind := TB.unit(m, 0, TB.WATER, 3)
	var diagonal := TB.unit(m, 0, TB.WATER, 4)
	var far := TB.unit(m, 0, TB.WATER, 2)
	var foe := TB.unit(m, 1, TB.WATER, 0)
	assert_int(m.def_of(right)).is_equal(14)
	assert_int(m.def_of(behind)).is_equal(14)
	assert_int(m.def_of(diagonal)).is_equal(14)
	assert_int(m.def_of(far)).is_equal(8)
	assert_int(m.def_of(foe)).is_equal(8)
	assert_int(m.def_of(cave)).is_equal(18)                  # not itself (6/18 since 2026-11-03)


func test_c034_dragon_of_the_cave_bonus_ends_when_it_leaves() -> void:
	var m := CF.make()
	var cave := TB.unit(m, 0, 34, 1)
	var left := TB.unit(m, 0, TB.WATER, 0)
	TB.kill(m, cave)
	assert_int(m.def_of(left)).is_equal(8)


# ---------------------------------------------------------------- 45 Magic Cylinder

func test_c045_magic_cylinder_reflects_attacker_atk_and_costs_one_more() -> void:
	var m := CF.p1_battle()
	var cyl := TB.set_card(m, 0, 45, 0)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 30)
	var d := TB.unit(m, 0, TB.WATER, 0)
	TB.attack(m, a, d)
	TB.choose(m, ["Activate Magic Cylinder"])
	assert_int(CF.hp(m, 1)).is_equal(GameCore.START_HP - 30)
	assert_int(m.current_cost(cyl)).is_equal(2)


# 2026-11-03 (intent changed on purpose, replaces C-03): the trigger is the attacker's column,
# whatever the target, and a direct attack from that column counts.
func test_c045_magic_cylinder_follows_the_attackers_column_direct_attacks_included() -> void:
	var m := CF.p1_battle()
	TB.set_card(m, 0, 45, 0)
	var a := TB.unit(m, 1, TB.WATER, 1, "atk", 30)           # attacker in column 2
	var mine := TB.unit(m, 0, TB.WATER, 0)
	TB.attack(m, a, mine)                                    # attack on the Trap's column 1
	assert_bool(CF.labels(m).has("Activate Magic Cylinder")).is_false()
	var m2 := CF.p1_battle()
	TB.set_card(m2, 0, 45, 0)
	var a2 := TB.unit(m2, 1, TB.WATER, 0, "atk", 30)
	TB.attack(m2, a2, -1)                                    # direct attack from column 1
	assert_bool(CF.labels(m2).has("Activate Magic Cylinder")).is_true()


# ---------------------------------------------------------------- 46 Mirror Force

func test_c046_mirror_force_destroys_only_attack_stance_units_at_four_cards() -> void:
	var m := CF.p1_battle()
	TB.set_card(m, 0, 46, 0)
	var a := TB.unit(m, 1, TB.WATER, 0)
	var atk2 := TB.unit(m, 1, TB.WATER, 1)
	var defender := TB.unit(m, 1, TB.WATER, 2, "def")
	TB.set_card(m, 1, 49, 0)                                 # 4th opposing card
	TB.attack(m, a, -1)
	TB.choose(m, ["Activate Mirror Force"])
	assert_str(CF.zone(m, a)).is_equal("spent")
	assert_str(CF.zone(m, atk2)).is_equal("spent")
	assert_str(CF.zone(m, defender)).is_equal("unit")
	assert_int(CF.hp(m, 0)).is_equal(GameCore.START_HP)


func test_c046_mirror_force_unavailable_with_three_opposing_cards() -> void:
	var m := CF.p1_battle()
	TB.set_card(m, 0, 46, 0)
	var a := TB.unit(m, 1, TB.WATER, 0)
	TB.unit(m, 1, TB.WATER, 1)
	TB.unit(m, 1, TB.WATER, 2)
	TB.attack(m, a, -1)
	assert_bool(CF.labels(m).has("Activate Mirror Force")).is_false()


# ---------------------------------------------------------------- 51 Rushed Recklessly

func test_c051_rushed_recklessly_gives_column_units_eight_def_this_turn() -> void:
	var m := CF.p1_battle()
	TB.set_card(m, 0, 51, 0)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 12)
	var d := TB.unit(m, 0, TB.WATER, 0, "def")
	var back := TB.unit(m, 0, TB.WATER, 3)
	var other := TB.unit(m, 0, TB.WATER, 1)
	TB.attack(m, a, d)
	TB.choose(m, ["Activate Rushed Recklessly"])
	assert_str(CF.zone(m, d)).is_equal("unit")               # 16 DEF holds against 12 ATK
	assert_int(m.def_of(back)).is_equal(16)
	assert_int(m.def_of(other)).is_equal(8)
	CF.end_turn(m)
	assert_int(m.def_of(back)).is_equal(8)


# ---------------------------------------------------------------- 96 Roma, Exile of The Order

func _roma(m: MatchEngine, runes: int) -> int:
	var uid := m._create_instance(96, 0)
	m.cards[uid]["zone"] = "limbo"
	m.cards[uid]["runes_used"] = runes
	m.place_unit(uid, 0, 0, "atk")
	m.cards[uid]["summoned_turn"] = m.turn
	m.emit("summoned", {"self": uid, "ctl": 0, "player": 0})
	m.run()
	return uid


# 2026-11-03: +10 per Rune (was +12).
func test_c096_roma_is_ten_per_rune_used() -> void:
	var m := CF.make()
	var two := _roma(m, 2)
	assert_int(m.atk_of(two)).is_equal(20)
	assert_int(m.def_of(two)).is_equal(20)
	var m2 := CF.make()
	assert_int(m2.atk_of(_roma(m2, 0))).is_equal(0)          # summoned without Runes


func test_c096_roma_pays_ten_hp_to_destroy_a_lower_atk_unit_once_per_turn() -> void:
	var m := CF.make()
	var roma := _roma(m, 2)                                  # 20 ATK (2026-11-03)
	var low := TB.unit(m, 1, TB.WATER, 0, "atk", 19)
	var equal := TB.unit(m, 1, TB.WATER, 1, "atk", 20)
	assert_str(TB.ability(m, roma)).is_empty()
	assert_bool(low in CF.offered(m)).is_true()
	assert_bool(equal in CF.offered(m)).is_false()
	TB.choose_uids(m, [low])
	assert_str(CF.zone(m, low)).is_equal("spent")
	assert_int(CF.hp(m, 0)).is_equal(GameCore.START_HP - 10)
	assert_str(TB.ability(m, roma)).is_equal("Already used this turn.")


# ---------------------------------------------------------------- 100 Gaping Crevasse

func test_c100_gaping_crevasse_paralyses_the_unit_that_destroyed_it_in_battle() -> void:
	var m := CF.p1_battle()
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 12)
	var gc := TB.unit(m, 0, 100, 0)
	TB.attack(m, a, gc)
	assert_str(CF.zone(m, gc)).is_equal("spent")
	assert_int(m.status_count(a, "paralyse")).is_equal(2)


func test_c100_gaping_crevasse_destroyed_by_an_effect_paralyses_nothing() -> void:
	var m := CF.make()
	var gc := TB.unit(m, 0, 100, 0)
	var foe := TB.unit(m, 1, TB.WATER, 0)
	TB.kill(m, gc)
	assert_int(m.status_count(foe, "paralyse")).is_equal(0)
	assert_bool(m.pending.is_empty()).is_true()


# ---------------------------------------------------------------- 174 Cliff the Flying Bison

# 2026-11-03: +1 AP (was +2).
func test_c174_cliff_gives_one_ap_when_sacrificed_but_not_when_destroyed() -> void:
	var m := CF.make()
	var a := TB.unit(m, 0, 174, 0)
	var b := TB.unit(m, 0, 174, 1)
	var before := CF.ap(m, 0)
	TB.kill(m, a)
	assert_int(CF.ap(m, 0)).is_equal(before)
	m.submit(0, {"t": "sacrifice", "uid": b})                # +1 rule AP, +1 from Cliff
	assert_int(CF.ap(m, 0)).is_equal(before + 2)


# ---------------------------------------------------------------- 180 Hypnotise

# 2026-11-03: 16 ATK or less (was 20).
func test_c180_hypnotise_takes_a_16_atk_unit_until_end_of_turn() -> void:
	var m := CF.make()
	var ok := TB.unit(m, 1, TB.WATER, 0, "atk", 16)
	var big := TB.unit(m, 1, TB.WATER, 1, "atk", 17)
	TB.cast(m, 0, 180)
	assert_bool(ok in CF.offered(m)).is_true()
	assert_bool(big in CF.offered(m)).is_false()
	TB.choose_uids(m, [ok])
	assert_str(TB.choose(m, ["Front row, column 2"])).is_empty()   # L9: the caster picks the zone
	assert_int(int(m.cards[ok]["ctl"])).is_equal(0)
	assert_str(m.validate(0, {"t": "sacrifice", "uid": ok})).is_not_empty()
	CF.end_turn(m)
	assert_int(int(m.cards[ok]["ctl"])).is_equal(1)
	assert_str(CF.zone(m, ok)).is_equal("unit")


func test_c180_hypnotise_cannot_be_cast_without_a_legal_target() -> void:
	var m := CF.make()
	TB.unit(m, 1, TB.WATER, 0, "atk", 17)                     # just over the 16-ATK limit (2026-11-03)
	var s := TB.card(m, 0, 180)
	m.players[0]["ap"] = 5
	assert_str(m.submit(0, {"t": "cast", "uid": s})).is_not_empty()
	assert_str(CF.zone(m, s)).is_equal("hand")
