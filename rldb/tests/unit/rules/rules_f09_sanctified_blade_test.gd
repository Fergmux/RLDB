extends GdUnitTestSuite
## F09 (design/playtest-feedback-07-production-2026-10-17.md): Sanctified Blade (61) — "Once per
## turn: you can Apply 3 Medic to an Adjacent Unit." The owner suspected it activated by itself.
## These tests reproduce the reported situations and show the ability only runs on a deliberate
## activation followed by a target choice, is never triggered by unrelated events, and keeps its
## separate On Summon effect.

const BLADE := 61
const MAGE_WATER := 1
const HEAVENLY_MAGE := 105         # Basic Mage (Heavenly), cost 1
const WARRIOR_FIRE := 112
const HEAVENLY_SPELL_TARGET := 83  # Sacred Offerings


func _medic_total(m: MatchEngine) -> int:
	var n := 0
	for p in [0, 1]:
		for u in m.field_units(p):
			n += m.status_count(u, "medic")
	return n


func _opt_used(m: MatchEngine, uid: int) -> bool:
	return m.cards[uid]["opt"].get(0, -1) == m.turn


func test_f09_summon_does_not_apply_medic_or_use_the_ability() -> void:
	var m := TB.make()
	var ally := TB.unit(m, 0, MAGE_WATER, 1)
	var blade := TB.special(m, 0, BLADE, 0)                      # Fusion unit put onto the Field
	if not m.pending.is_empty():
		TB.choose(m, ["Skip"])                                   # its On Summon is optional
	assert_bool(m.pending.is_empty()).is_true()
	assert_int(m.status_count(ally, "medic")).is_equal(0)
	assert_bool(_opt_used(m, blade)).is_false()


func test_f09_unrelated_events_never_activate_or_consume_it() -> void:
	var m := TB.make()
	var blade := TB.unit(m, 0, BLADE, 0)
	var ally := TB.unit(m, 0, MAGE_WATER, 1)
	# Another unit summoned next to it, a Spell cast, a unit destroyed, a stance change.
	TB.summon(m, 0, WARRIOR_FIRE, 3)
	TB.cast(m, 0, HEAVENLY_SPELL_TARGET)
	if not m.pending.is_empty():
		TB.choose_uids(m, [ally])
	var foe := TB.unit(m, 1, MAGE_WATER, 0)
	TB.kill(m, foe)
	m.submit(0, {"t": "stance", "uid": ally})
	assert_int(m.status_count(ally, "medic")).is_equal(0)
	assert_bool(_opt_used(m, blade)).is_false()
	# Turn changes (both players' starts and ends) do not trigger it either.
	TB.to_turn2(m)
	m.submit(1, {"t": "next_phase"})
	m.submit(1, {"t": "next_phase"})
	m.submit(1, {"t": "next_phase"})
	assert_int(_medic_total(m)).is_equal(0)
	assert_bool(_opt_used(m, blade)).is_false()


func test_f09_activation_waits_for_a_target_even_with_one_legal_choice() -> void:
	var m := TB.make()
	var blade := TB.unit(m, 0, BLADE, 0)
	var ally := TB.unit(m, 0, MAGE_WATER, 1)                     # the only adjacent unit
	TB.unit(m, 0, MAGE_WATER, 2)                                 # not adjacent
	TB.unit(m, 1, MAGE_WATER, 1)                                 # opponent's: not adjacent
	assert_str(TB.ability(m, blade)).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("select")
	assert_array(m.pending["options"].map(func(o): return int(o["v"]))).contains_exactly([ally])
	assert_int(m.status_count(ally, "medic")).is_equal(0)        # nothing yet: no auto-pick
	assert_bool(_opt_used(m, blade)).is_false()                  # nor is the use spent yet
	TB.choose_uids(m, [ally])
	assert_int(m.status_count(ally, "medic")).is_equal(3)
	assert_bool(_opt_used(m, blade)).is_true()
	assert_str(TB.ability(m, blade)).is_equal("Already used this turn.")


func test_f09_cancelling_the_target_choice_keeps_the_use() -> void:
	var m := TB.make()
	var blade := TB.unit(m, 0, BLADE, 0)
	var ally := TB.unit(m, 0, MAGE_WATER, 1)
	TB.ability(m, blade)
	assert_bool(m.pending.get("cancellable", false)).is_true()
	assert_str(m.submit(0, {"t": "cancel", "id": m.pending["id"]})).is_empty()
	assert_int(m.status_count(ally, "medic")).is_equal(0)
	assert_bool(_opt_used(m, blade)).is_false()
	assert_str(TB.ability(m, blade)).is_empty()                   # still available this turn


func test_f09_no_adjacent_unit_means_the_ability_is_not_offered() -> void:
	var m := TB.make()
	var blade := TB.unit(m, 0, BLADE, 0)
	TB.unit(m, 0, MAGE_WATER, 2)
	assert_str(m.validate(0, {"t": "ability", "uid": blade, "idx": 0})).is_equal("No legal target.")


func test_f09_on_summon_heavenly_revival_is_kept_and_optional() -> void:
	var m := TB.make()
	var dead := TB.card(m, 0, HEAVENLY_MAGE, "spent")
	TB.special(m, 0, BLADE, 0)
	assert_str(TB.pend_kind(m)).is_equal("select")
	assert_array(m.pending["options"].map(func(o): return int(o["v"]))).contains_exactly_in_any_order([-1, dead])
	TB.choose_uids(m, [dead])
	if TB.pend_kind(m) == "slot":
		TB.choose(m, [TB.slot_label(3)])
	if TB.pend_kind(m) == "stance":
		TB.choose(m, ["Attack"])
	assert_str(m.cards[dead]["zone"]).is_equal("unit")
	assert_int(m.slot_col(m.cards[dead]["slot"])).is_equal(0)
