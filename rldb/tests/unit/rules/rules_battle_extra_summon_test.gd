extends GdUnitTestSuite
## Owner rule 2026-10-18: no Fusion, Ritual or Arcane summon in the Battle Phase. Cards whose effect
## would make one cannot use that effect there (abilities, set Spells, triggered offers).

const VOID_BASILISK := 67          # ability: exhaust itself to Fusion Summon from Spent
const FUSION_CEREMONY := 82        # Spell: Fusion Summon
const CREEPING_NULL := 65          # Ritual unit, 3 Runes
const BRONZE_SALAMAN := 186        # offers a Fusion Summon as it lands
const BASIC_BEAST := 4            # the Ritual material
# 2026-11-03 Bastion Wyrm: a unit with 20 or more ATK or DEF + a Physical unit (was Beast + Dragon).
const TALL_BEAST := 28             # Guardian of the Forest 12/22: the 20+ DEF material
const BASIC_DRAGON := 116          # Basic Dragon (Physical): the Physical material
const BASTION_WYRM := 93


## Turn 2 (player 1's, Setup Phase): the first turn with a Battle Phase.
func _turn2() -> MatchEngine:
	var m := TB.make()
	TB.to_turn2(m)
	return m


func _fusion_ready_board() -> MatchEngine:
	var m := _turn2()
	TB.card(m, 1, TALL_BEAST, "spent")
	TB.card(m, 1, BASIC_DRAGON, "spent")
	TB.card(m, 1, BASTION_WYRM, "extra")
	return m


func test_fusion_ability_is_refused_in_the_battle_phase_and_allowed_in_setup() -> void:
	var m := _fusion_ready_board()
	var vb := TB.unit(m, 1, VOID_BASILISK, 0)
	assert_str(m.validate(1, {"t": "ability", "uid": vb, "idx": 0})).is_empty()
	TB.to_battle(m)
	assert_str(m.validate(1, {"t": "ability", "uid": vb, "idx": 0})).is_equal(MatchEngine.NO_EXTRA_IN_BATTLE)
	assert_array(m.fusion_methods(1)).is_empty()


func test_set_fusion_spell_is_refused_in_the_battle_phase() -> void:
	var m := _fusion_ready_board()
	var sc := TB.set_card(m, 1, FUSION_CEREMONY, 0)
	TB.unit(m, 1, TALL_BEAST, 1)
	TB.unit(m, 1, BASIC_DRAGON, 2)
	assert_str(m.validate(1, {"t": "activate_set", "uid": sc})).is_empty()
	TB.to_battle(m)
	assert_str(m.validate(1, {"t": "activate_set", "uid": sc})).is_equal(MatchEngine.NO_EXTRA_IN_BATTLE)


func test_ritual_summon_is_refused_in_the_battle_phase() -> void:
	var m := _turn2()
	var mat := TB.unit(m, 1, BASIC_BEAST, 0)
	m.apply_status(mat, "rune", 3)
	var null_u := TB.card(m, 1, CREEPING_NULL, "extra")
	assert_str(m.validate(1, {"t": "ritual", "uid": null_u, "stance": "atk"})).is_empty()
	TB.to_battle(m)
	assert_str(m.validate(1, {"t": "ritual", "uid": null_u, "stance": "atk"})).is_equal(MatchEngine.NO_EXTRA_IN_BATTLE)


func test_a_triggered_fusion_offer_is_not_made_in_the_battle_phase() -> void:
	# Control: outside the Battle Phase the same board does get the offer, so the check below is not
	# passing only because the materials are illegal.
	var ctl := _turn2()
	TB.unit(ctl, 1, TALL_BEAST, 1)
	TB.unit(ctl, 1, BASIC_DRAGON, 2)
	TB.card(ctl, 1, BASTION_WYRM, "extra")
	TB.special(ctl, 1, BRONZE_SALAMAN, 0)
	assert_str(TB.pend_kind(ctl)).is_equal("confirm")
	var m := _turn2()
	TB.unit(m, 1, TALL_BEAST, 1)
	TB.unit(m, 1, BASIC_DRAGON, 2)
	TB.card(m, 1, BASTION_WYRM, "extra")
	TB.to_battle(m)
	TB.special(m, 1, BRONZE_SALAMAN, 0)
	assert_str(TB.pend_kind(m)).is_not_equal("confirm")
