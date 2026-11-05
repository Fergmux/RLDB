extends GdUnitTestSuite
## L15 (design/owner-feedback-2026-11-05.md): Sneaky Snunday reworked. "Until the end of this turn:
## all new and ongoing ATK/DEF gains and losses are reversed." While it is active every unit reads
## base - (unreversed - base), permanent changes from earlier turns included; costs and AP are not
## touched; it ends with the turn.

const SNUNDAY := 154
const HYPNOTISE := 180
const SHIMMER_SERUM := 182
const SERPENT_BODY := 159      # adjacent units +10 DEF
const LONE_WARRIOR := 38       # cannot gain ATK/DEF; -6/-6 per adjacent unit of yours


## Applies a card-effect ATK/DEF change to `u` (as a resolving effect of player 0).
func _stat(m: MatchEngine, u: int, a: int, df: int, until: String = "field") -> void:
	m.push_frame(m.make_frame(-1, 0, [{"op": "stat", "target": u, "atk": a, "def": df, "until": until}], "test"))
	m.run()


func test_permanent_gain_from_an_earlier_turn_reads_reversed() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0, "atk", 10, 10)
	_stat(m, u, 10, 6)
	assert_int(m.atk_of(u)).is_equal(20)
	TB.cast(m, 0, SNUNDAY)
	assert_int(m.atk_of(u)).is_equal(0)         # 10 - (20 - 10)
	assert_int(m.def_of(u)).is_equal(4)         # 10 - (16 - 10)


func test_permanent_loss_reads_as_a_gain() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0, "atk", 20, 20)
	_stat(m, u, -8, -4)
	TB.cast(m, 0, SNUNDAY)
	assert_int(m.atk_of(u)).is_equal(28)
	assert_int(m.def_of(u)).is_equal(24)


func test_temporary_gain_reads_reversed() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0, "atk", 10, 10)
	_stat(m, u, 0, 8, "turn")
	TB.cast(m, 0, SNUNDAY)
	assert_int(m.def_of(u)).is_equal(2)
	assert_int(m.atk_of(u)).is_equal(10)        # no change from base: nothing to reverse


func test_gain_applied_after_snunday_reads_reversed_now_and_as_printed_next_turn() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0, "atk", 10, 10)
	TB.cast(m, 0, SNUNDAY)
	_stat(m, u, 10, 0)                          # a permanent +10 gained while Snunday is active
	assert_int(m.atk_of(u)).is_equal(0)
	TB.to_turn2(m)
	assert_bool(m.reversal_active()).is_false()
	assert_int(m.atk_of(u)).is_equal(20)        # the gain was kept as printed, not stored as -10


func test_loss_after_snunday_reads_as_a_gain() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0, "atk", 20, 20)
	TB.cast(m, 0, SNUNDAY)
	_stat(m, u, -6, 0, "turn")
	assert_int(m.atk_of(u)).is_equal(26)


func test_loss_past_zero_is_mirrored_in_full_and_the_floor_still_applies() -> void:
	var m := TB.make()
	var weak := TB.unit(m, 0, TB.WATER, 0, "atk", 10, 10)
	var strong := TB.unit(m, 0, TB.WATER, 1, "atk", 10, 10)
	_stat(m, weak, -30, 0)
	_stat(m, strong, 30, 0)
	assert_int(m.atk_of(weak)).is_equal(0)
	TB.cast(m, 0, SNUNDAY)
	assert_int(m.atk_of(weak)).is_equal(40)     # the whole -30 loss reverses
	assert_int(m.atk_of(strong)).is_equal(0)    # 10 - 30, floored at 0


func test_continuous_aura_reads_reversed_while_active() -> void:
	var m := TB.make()
	TB.unit(m, 0, SERPENT_BODY, 0)
	var friend := TB.unit(m, 0, TB.WATER, 1, "atk", 8, 20)
	assert_int(m.def_of(friend)).is_equal(30)
	TB.cast(m, 0, SNUNDAY)
	assert_int(m.def_of(friend)).is_equal(10)


func test_both_seats_are_reversed_whoever_casts_it() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	var mine := TB.unit(m, 1, TB.WATER, 0, "atk", 10, 10)
	var theirs := TB.unit(m, 0, TB.WATER, 0, "atk", 10, 10)
	_stat(m, mine, 4, 0)
	_stat(m, theirs, -4, 0)
	TB.cast(m, 1, SNUNDAY)
	assert_int(m.atk_of(mine)).is_equal(6)
	assert_int(m.atk_of(theirs)).is_equal(14)


func test_costs_and_ap_are_not_reversed() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0, "atk", 10, 10)
	TB.cast(m, 0, SNUNDAY)
	var cost_before := m.current_cost(u)
	m.push_frame(m.make_frame(-1, 0, [{"op": "cost_perm", "target": u, "n": 1}], "test"))
	m.run()
	assert_int(m.current_cost(u)).is_equal(cost_before + 1)
	var ap := int(m.players[0]["ap"])
	m.push_frame(m.make_frame(-1, 0, [{"op": "ap", "n": 1}], "test"))
	m.run()
	assert_int(int(m.players[0]["ap"])).is_equal(ap + 1)


func test_shimmer_serum_after_snunday_reverses_its_atk_but_not_its_cost() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0, "atk", 10, 10)
	var cost_before := m.current_cost(u)
	TB.cast(m, 0, SNUNDAY)
	TB.cast(m, 0, SHIMMER_SERUM)
	assert_str(TB.choose_uids(m, [u])).is_empty()
	assert_int(m.atk_of(u)).is_less(10)         # its ATK gain reads as a loss
	assert_int(m.current_cost(u)).is_equal(cost_before + 1)


func test_turn_end_resets_every_unit() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0, "atk", 10, 10)
	var foe := TB.unit(m, 1, TB.WATER, 0, "atk", 10, 10)
	_stat(m, u, 10, 0)
	_stat(m, foe, -5, 0)
	TB.cast(m, 0, SNUNDAY)
	TB.to_turn2(m)
	assert_bool(m.reversal_active()).is_false()
	assert_int(m.atk_of(u)).is_equal(20)
	assert_int(m.atk_of(foe)).is_equal(5)


func test_battle_damage_uses_the_reversed_atk() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 20, 20)
	_stat(m, a, -8, 0)                          # 12 normally
	TB.cast(m, 1, SNUNDAY)
	TB.to_battle(m)
	assert_str(TB.attack(m, a, -1)).is_empty()
	assert_int(m.players[0]["hp"]).is_equal(GameCore.START_HP - 28)


func test_atk_threshold_uses_the_reversed_value() -> void:
	var m := TB.make()
	var foe := TB.unit(m, 1, TB.WATER, 0, "atk", 10, 10)
	_stat(m, foe, 10, 0)                        # 20 ATK: above Hypnotise's 16
	var spell := TB.card(m, 0, HYPNOTISE)
	m.players[0]["ap"] = 10
	assert_str(m.validate(0, {"t": "cast", "uid": spell})).is_equal("No legal target.")
	TB.cast(m, 0, SNUNDAY)
	m.players[0]["ap"] = 10
	assert_str(m.validate(0, {"t": "cast", "uid": spell})).is_empty()   # reads 0 ATK now


func test_view_shows_the_reversed_stats_and_explains_them() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0, "atk", 10, 10)
	_stat(m, u, 10, 0)
	TB.cast(m, 0, SNUNDAY)
	for viewer in [0, 1]:
		var v := MatchView.card_view(m, u, viewer)
		assert_int(int(v["atk"])).is_equal(0)
		assert_str(" ".join(v["stat_parts"])).contains("Sneaky Snunday")
	assert_bool(MatchView.build(m, 1)["reversal"]).is_true()


func test_two_copies_cancel() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0, "atk", 10, 10)
	_stat(m, u, 10, 0)
	TB.cast(m, 0, SNUNDAY)
	TB.cast(m, 0, SNUNDAY)
	assert_int(m.atk_of(u)).is_equal(20)


func test_freaky_funday_switch_is_not_a_gain_but_changes_after_it_mirror() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0, "atk", 30, 10)
	_stat(m, u, 10, 0)                          # 40/10, then switched: 10/40 around a 10/30 base
	m.push_frame(m.make_frame(-1, 0, [{"op": "swap_all"}], "test"))
	m.run()
	assert_int(m.atk_of(u)).is_equal(10)
	assert_int(m.def_of(u)).is_equal(40)
	TB.cast(m, 0, SNUNDAY)
	assert_int(m.atk_of(u)).is_equal(10)
	assert_int(m.def_of(u)).is_equal(20)        # the +10 (now on DEF) reads -10


func test_a_unit_that_cannot_gain_is_not_raised_above_its_base() -> void:
	var m := TB.make()
	var lone := TB.unit(m, 0, LONE_WARRIOR, 0)
	TB.unit(m, 0, TB.WATER, 1)                  # one adjacent ally: -6/-6
	var base := m.base_atk(lone)
	assert_int(m.atk_of(lone)).is_equal(maxi(base - 6, 0))
	TB.cast(m, 0, SNUNDAY)
	assert_int(m.atk_of(lone)).is_equal(base)
