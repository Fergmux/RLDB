extends GdUnitTestSuite
## F09 (design/playtest-feedback-07-production-2026-10-17.md): the owner suspected Sanctified Blade's
## (61) once-per-turn ability activated by itself. These tests show the ability only runs on a
## deliberate activation followed by a choice, is never triggered by unrelated events, and keeps its
## separate On Summon effect. Updated on purpose for the 2026-11-03 text: the ability is now "Once
## per turn: you can discard a Unit to gain +1 AP" and the On Summon "You can apply 8 Medic to an
## Adjacent Unit" (design/card-database-update-2026-11-03.md).

const BLADE := 61
const MAGE_WATER := 1
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


func _hand_units(m: MatchEngine, p: int) -> Array:
	return m.players[p]["hand"].filter(func(u): return m.is_unit(u))


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
	var hand_n: int = m.players[0]["hand"].size()
	# Another unit summoned next to it, a Spell cast, a unit destroyed, a stance change.
	TB.summon(m, 0, WARRIOR_FIRE, 3)
	TB.cast(m, 0, HEAVENLY_SPELL_TARGET)
	if not m.pending.is_empty():
		TB.choose_uids(m, [ally])
	var foe := TB.unit(m, 1, MAGE_WATER, 0)
	TB.kill(m, foe)
	m.submit(0, {"t": "stance", "uid": ally})
	assert_int(m.status_count(ally, "medic")).is_equal(0)
	assert_int(m.players[0]["hand"].size()).is_equal(hand_n)     # nothing was discarded
	assert_bool(_opt_used(m, blade)).is_false()
	# Turn changes (both players' starts and ends) do not trigger it either.
	TB.to_turn2(m)
	m.submit(1, {"t": "next_phase"})
	m.submit(1, {"t": "next_phase"})
	m.submit(1, {"t": "next_phase"})
	assert_int(_medic_total(m)).is_equal(0)
	assert_bool(_opt_used(m, blade)).is_false()


func test_f09_activation_waits_for_a_choice_even_with_one_legal_card() -> void:
	var m := TB.make()
	var blade := TB.unit(m, 0, BLADE, 0)
	for h in m.players[0]["hand"].duplicate():
		m.move_to_pile(h, "spent")
	var only := TB.card(m, 0, MAGE_WATER)                        # the only unit in Hand
	TB.card(m, 0, HEAVENLY_SPELL_TARGET)                         # a Spell: not a Unit
	assert_str(TB.ability(m, blade)).is_empty()
	var ap: int = m.players[0]["ap"]
	assert_str(TB.pend_kind(m)).is_equal("select")
	assert_array(m.pending["options"].map(func(o): return int(o["v"]))).contains_exactly([only])
	assert_str(String(m.cards[only]["zone"])).is_equal("hand")   # nothing yet: no auto-pick
	assert_bool(_opt_used(m, blade)).is_false()                  # nor is the use spent yet
	TB.choose_uids(m, [only])
	assert_str(String(m.cards[only]["zone"])).is_equal("spent")
	assert_int(m.players[0]["ap"]).is_equal(ap + 1)
	assert_bool(_opt_used(m, blade)).is_true()
	assert_str(TB.ability(m, blade)).is_equal("Already used this turn.")


func test_f09_cancelling_the_choice_keeps_the_use() -> void:
	var m := TB.make()
	var blade := TB.unit(m, 0, BLADE, 0)
	var hand_n: int = m.players[0]["hand"].size()
	TB.ability(m, blade)
	assert_bool(m.pending.get("cancellable", false)).is_true()
	assert_str(m.submit(0, {"t": "cancel", "id": m.pending["id"]})).is_empty()
	assert_int(m.players[0]["hand"].size()).is_equal(hand_n)
	assert_bool(_opt_used(m, blade)).is_false()
	assert_str(TB.ability(m, blade)).is_empty()                   # still available this turn


func test_f09_no_unit_in_hand_means_the_ability_is_not_offered() -> void:
	var m := TB.make()
	var blade := TB.unit(m, 0, BLADE, 0)
	for h in _hand_units(m, 0):
		m.move_to_pile(h, "spent")
	TB.card(m, 0, HEAVENLY_SPELL_TARGET)
	assert_str(m.validate(0, {"t": "ability", "uid": blade, "idx": 0})).is_equal("No legal target.")


func test_f09_on_summon_medic_is_optional_and_offers_own_adjacent_units_only() -> void:
	var m := TB.make()
	var right := TB.unit(m, 0, MAGE_WATER, 1)
	var behind := TB.unit(m, 0, MAGE_WATER, 3)
	TB.unit(m, 0, MAGE_WATER, 2)                                 # not adjacent
	TB.unit(m, 1, MAGE_WATER, 0)                                 # the opponent's
	TB.special(m, 0, BLADE, 0)
	assert_str(TB.pend_kind(m)).is_equal("select")
	assert_array(m.pending["options"].map(func(o): return int(o["v"]))).contains_exactly_in_any_order([-1, right, behind])
	TB.choose_uids(m, [behind])
	assert_int(m.status_count(behind, "medic")).is_equal(8)
	assert_int(_medic_total(m)).is_equal(8)


func test_f09_on_summon_with_no_adjacent_unit_asks_nothing() -> void:
	var m := TB.make()
	TB.unit(m, 0, MAGE_WATER, 2)
	TB.special(m, 0, BLADE, 0)
	assert_bool(m.pending.is_empty()).is_true()
