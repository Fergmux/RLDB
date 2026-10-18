extends GdUnitTestSuite
## Behaviour of the cards changed or added by the 18 October 2026 card database
## (design/card-database-update-2026-10-18.md). Test names carry the card id (test_cNNN_...) for
## the support ledger; shared tests list their ids in an `# @cards` comment. Each new effect is
## tested with its target rules and no-target case, and each removed effect is shown not to run.

const MAGE_WATER := 1
const BEAST_WATER := 4
const MONSTER_WATER := 5
const MAGE_FIRE := 110
const MAGE_LIGHT := 105
const MONSTER_DARK := 129
const FLEDGLING_DRAKE := 33          # Fire Dragon, cost 0; "apply 4 Burn to a Unit in this Column"
const MAGENTRIC := 69                # Unit, cost 2
const SACRED_OFFERINGS := 83         # Spell, cost 1: Apply 1 Rune to a Unit
const MAGIC_CYLINDER := 45           # Trap
const MAGICAL_COUNCIL := 139         # Power, cost 2
const SABOTEURS_GUILD := 166         # Power, cost 2
const PRESERVATION_JAR := 92         # Power, cost 2
const MARKED_BY_THE_ABYSS := 149     # Power: cannot be activated with a 0-cost card in the deck
const ENERGY_DISPEL := 140
const COUNTER_TRANSMUTATION := 184
const DRAKO := 185
const BRONZE_SALAMAN := 186
const FENCE := 187
const NECRO := 188


func _opts(m: MatchEngine) -> Array:
	return m.pending.get("options", []).map(func(o): return int(o["v"]))


## Passes every phase of the active player's turn so the other player's turn starts.
func _pass_turn(m: MatchEngine) -> void:
	CF.end_turn(m)


# ---------------------------------------------------------------- Light and Dark

func test_light_and_dark_replace_heavenly_and_necrotic_in_the_type_cycle() -> void:
	assert_str(CardDB.TYPE_ADVANTAGE["Light"]).is_equal("Dark")
	assert_str(CardDB.TYPE_ADVANTAGE["Dark"]).is_equal("Physical")
	assert_str(CardDB.TYPE_ADVANTAGE["Physical"]).is_equal("Light")
	assert_bool(CardDB.TYPE_ADVANTAGE.has("Heavenly") or CardDB.TYPE_ADVANTAGE.has("Necrotic")).is_false()
	assert_array(CardDB.ELEMENTS).contains_exactly(["Water", "Fire", "Earth", "Lightning", "Light", "Dark", "Physical"])
	for d in CardDB.all():
		if CardDB.is_unit_category(d["category"]):
			assert_bool(d["type"] in CardDB.ELEMENTS or d["type"] == "").override_failure_message("%d %s" % [d["id"], d["type"]]).is_true()


func test_a_light_unit_beats_a_dark_unit_by_type_advantage() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	TB.to_battle(m)
	var light := TB.unit(m, 1, MAGE_LIGHT, 0)
	var dark := TB.unit(m, 0, MONSTER_DARK, 0)
	assert_str(TB.attack(m, light, dark)).is_empty()
	assert_str(CF.zone(m, dark)).is_equal("spent")
	assert_int(CF.hp(m, 0)).is_equal(60 - 6)


# ---------------------------------------------------------------- wording: Damage and Heal

func test_hp_changes_are_logged_as_damage_and_healing() -> void:
	var m := TB.make()
	m.change_hp(1, -6, "")
	m.change_hp(0, 4, "")
	assert_str(TB.log_text(m)).contains("Player 2 takes 6 Damage (HP 54).")
	assert_str(TB.log_text(m)).contains("Player 1 heals 4 HP (HP 64).")
	assert_str(TB.log_text(m)).not_contains("loses 6 HP")


func test_status_help_speaks_of_damage_and_healing() -> void:
	assert_str(CardDB.STATUS_HELP["burn"]).contains("takes Damage")
	assert_str(CardDB.STATUS_HELP["poison"]).contains("take Damage")
	assert_str(CardDB.STATUS_HELP["medic"]).contains("Heal")


# ---------------------------------------------------------------- Tag Teams

func test_c009_tag_team_f_destroyed_takes_every_cheap_unit_in_its_column_with_it() -> void:
	var m := TB.make()
	var ttf := TB.unit(m, 0, 9, 0)
	var own_back := TB.unit(m, 0, MAGE_WATER, 3)             # cost 1, same column
	var foe_front := TB.unit(m, 1, FLEDGLING_DRAKE, 0)       # cost 0, same column
	var foe_back := TB.unit(m, 1, MAGENTRIC, 3)              # cost 2: survives
	var other_col := TB.unit(m, 0, MAGE_FIRE, 1)             # cost 1, other column: survives
	TB.kill(m, ttf)
	assert_str(CF.zone(m, own_back)).is_equal("spent")
	assert_str(CF.zone(m, foe_front)).is_equal("spent")
	assert_str(CF.zone(m, foe_back)).is_equal("unit")
	assert_str(CF.zone(m, other_col)).is_equal("unit")


func test_c009_tag_team_f_on_destroy_spares_extra_deck_units() -> void:
	var m := TB.make()
	var ttf := TB.unit(m, 0, 9, 0)
	var arcane := TB.unit(m, 1, 170, 0)                     # Grandmother Kaya: no ordinary cost
	TB.kill(m, ttf)
	assert_str(CF.zone(m, arcane)).is_equal("unit")


func test_c010_tag_team_w_search_is_now_optional() -> void:
	var m := TB.make(7, 0)
	TB.unit(m, 0, MAGE_WATER, 3)
	var mage := TB.card(m, 0, MAGE_FIRE, "draw")
	TB.summon(m, 0, 10, 0)
	assert_array(_opts(m)).contains_exactly_in_any_order([-1, mage])
	CF.decline(m)
	assert_str(CF.zone(m, mage)).is_equal("draw")


func test_c010_tag_team_w_destroyed_destroys_every_spell_trap_in_its_column() -> void:
	var m := TB.make()
	var ttw := TB.unit(m, 0, 10, 0)
	var own_set := TB.set_card(m, 0, SACRED_OFFERINGS, 0)
	var foe_set := TB.set_card(m, 1, MAGIC_CYLINDER, 0)
	m.apply_status(foe_set, "reveal", 1)                     # revealed: still a Spell/Trap
	var other := TB.set_card(m, 1, SACRED_OFFERINGS, 1)
	TB.kill(m, ttw)
	assert_str(CF.zone(m, own_set)).is_equal("spent")
	assert_str(CF.zone(m, foe_set)).is_equal("spent")
	assert_str(CF.zone(m, other)).is_equal("backrow")


func test_c011_tag_team_j_destroyed_destroys_a_chosen_power() -> void:
	var m := TB.make()
	var ttj := TB.unit(m, 0, 11, 0)
	var own_pw := TB.power(m, 0, MAGICAL_COUNCIL, 0)
	var foe_pw := TB.power(m, 1, SABOTEURS_GUILD, 0)
	TB.kill(m, ttj)
	assert_array(_opts(m)).contains_exactly_in_any_order([own_pw, foe_pw])   # mandatory: no Skip
	TB.choose_uids(m, [foe_pw])
	assert_str(CF.zone(m, foe_pw)).is_equal("spent")
	assert_str(CF.zone(m, own_pw)).is_equal("power")
	assert_bool(CardDB.get_def(11)["keywords"].has("reveal")).is_false()


func test_c011_tag_team_j_destroyed_with_no_power_does_nothing() -> void:
	var m := TB.make()
	var ttj := TB.unit(m, 0, 11, 0)
	var revealed := TB.set_card(m, 1, MAGIC_CYLINDER, 0)
	m.apply_status(revealed, "reveal", 1)                    # the old "destroy all Reveal" is gone
	TB.kill(m, ttj)
	assert_bool(m.pending.is_empty()).is_true()
	assert_str(CF.zone(m, revealed)).is_equal("backrow")


# ---------------------------------------------------------------- "Facedown" became "Spell/Trap"

func test_c023_auric_can_destroy_a_revealed_spell_trap_now() -> void:
	var m := TB.make()
	var auric := TB.unit(m, 0, 23, 0)
	var revealed := TB.set_card(m, 1, MAGIC_CYLINDER, 0)
	m.apply_status(revealed, "reveal", 1)
	TB.ability(m, auric)
	TB.choose(m, ["Destroy a Spell/Trap"])
	assert_array(CF.offered(m)).contains_exactly([revealed])
	TB.choose_uids(m, [revealed])
	assert_str(CF.zone(m, revealed)).is_equal("spent")
	assert_int(CF.hp(m, 0)).is_equal(50)                      # Take 10 Damage is the cost


func test_c026_brinekeeper_destroyed_takes_all_your_spell_traps_revealed_or_not() -> void:
	var m := TB.make()
	var brine := TB.unit(m, 0, 26, 0)
	var hidden := TB.set_card(m, 0, MAGIC_CYLINDER, 0)
	var revealed := TB.set_card(m, 0, SACRED_OFFERINGS, 1)
	m.apply_status(revealed, "reveal", 1)
	var foe := TB.set_card(m, 1, MAGIC_CYLINDER, 0)
	TB.kill(m, brine)
	assert_str(CF.zone(m, hidden)).is_equal("spent")
	assert_str(CF.zone(m, revealed)).is_equal("spent")
	assert_str(CF.zone(m, foe)).is_equal("backrow")


func test_a_destroyed_set_card_is_logged_as_a_set_spell_trap() -> void:
	var m := TB.make()
	var hidden := TB.set_card(m, 1, MAGIC_CYLINDER, 0)
	TB.kill(m, hidden, 0)
	assert_str(TB.log_text(m)).contains("A set Spell/Trap is destroyed.")
	assert_str(TB.log_text(m)).not_contains("Magic Cylinder")


# ---------------------------------------------------------------- Chaos Witch

func test_c013_chaos_witch_is_dark_by_default_and_imposes_nothing_until_it_acts() -> void:
	assert_str(CardDB.get_def(13)["type"]).is_equal("Dark")
	var m := TB.make()
	var witch := TB.unit(m, 0, 13, 0)
	var mage := TB.unit(m, 0, MAGE_FIRE, 1)
	assert_str(m.unit_type(witch)).is_equal("Dark")
	assert_str(m.unit_type(mage)).is_equal("Fire")


func test_c013_chaos_witch_type_change_is_one_shot_and_survives_the_witch() -> void:
	var m := TB.make()
	var witch := TB.unit(m, 0, 13, 0)
	var own_mage := TB.unit(m, 0, MAGE_FIRE, 1)
	var foe_mage := TB.unit(m, 1, MAGE_WATER, 0)
	var beast := TB.unit(m, 1, BEAST_WATER, 1)
	assert_str(TB.ability(m, witch)).is_empty()
	TB.choose(m, ["Earth"])
	assert_str(m.unit_type(witch)).is_equal("Earth")
	assert_str(m.unit_type(own_mage)).is_equal("Earth")
	assert_str(m.unit_type(foe_mage)).is_equal("Earth")
	assert_str(m.unit_type(beast)).is_equal("Water")
	var late := TB.unit(m, 0, MAGE_FIRE, 2)                  # not ongoing: a later Mage keeps its Type
	assert_str(m.unit_type(late)).is_equal("Fire")
	TB.kill(m, witch)
	if not m.pending.is_empty():
		CF.decline(m)
	assert_str(m.unit_type(own_mage)).is_equal("Earth")      # no longer controlled by the Witch
	assert_str(m.unit_type(foe_mage)).is_equal("Earth")


func test_c013_a_second_witch_can_change_the_mages_again() -> void:
	var m := TB.make()
	var w1 := TB.unit(m, 0, 13, 0)
	var w2 := TB.unit(m, 0, 13, 1)
	var mage := TB.unit(m, 1, MAGE_WATER, 0)
	TB.ability(m, w1)
	TB.choose(m, ["Fire"])
	TB.ability(m, w2)
	TB.choose(m, ["Lightning"])
	assert_str(m.unit_type(mage)).is_equal("Lightning")
	assert_str(m.unit_type(w1)).is_equal("Lightning")        # the first Witch is a Mage too


# ---------------------------------------------------------------- Shimmer Serum

func test_c182_shimmer_serum_raises_the_targets_cost_not_its_own() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, MAGE_WATER, 0)
	var spell := TB.cast(m, 0, 182)
	TB.choose_uids(m, [u])
	assert_int(m.status_count(u, "blind")).is_equal(1)
	assert_int(m.status_count(u, "infiltrate")).is_equal(1)
	assert_int(m.atk_of(u)).is_equal(8 + 20)
	assert_int(m.current_cost(u)).is_equal(2)
	assert_int(m.current_cost(spell)).is_equal(0)             # the Spell's own cost is unchanged
	m.move_to_pile(u, "hand")
	assert_int(m.current_cost(u)).is_equal(2)                 # permanent: kept off the Field
	m.turn += 2
	m.move_to_pile(u, "spent")
	assert_int(m.current_cost(u)).is_equal(2)


func test_c182_shimmer_serum_atk_gain_lasts_this_turn_only() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, MAGE_WATER, 0)
	TB.cast(m, 0, 182)
	TB.choose_uids(m, [u])
	_pass_turn(m)
	assert_int(m.atk_of(u)).is_equal(8)


# ---------------------------------------------------------------- Divine Serpents

# @cards 158,159,160
func test_divine_serpents_deal_30_damage_then_destroy_every_serpent_you_control() -> void:
	var m := TB.make()
	var head := TB.unit(m, 0, 158, 0)
	var body := TB.unit(m, 0, 159, 1)
	var bystander := TB.unit(m, 0, MAGE_WATER, 2)
	var soul := TB.summon(m, 0, 160, 4)
	assert_int(CF.hp(m, 1)).is_equal(30)
	for u in [head, body, soul]:
		assert_str(CF.zone(m, u)).is_equal("spent")
	assert_str(CF.zone(m, bystander)).is_equal("unit")


# @cards 158,159,160
func test_divine_serpent_without_two_adjacent_serpents_does_nothing() -> void:
	var m := TB.make()
	var head := TB.unit(m, 0, 158, 0)
	var soul := TB.summon(m, 0, 160, 2)                      # not adjacent to the Head
	assert_int(CF.hp(m, 1)).is_equal(60)
	assert_str(CF.zone(m, head)).is_equal("unit")
	assert_str(CF.zone(m, soul)).is_equal("unit")


# ---------------------------------------------------------------- Sneaky Snunday

func test_c154_sneaky_snunday_no_longer_reverses_damage_or_healing() -> void:
	var m := TB.make()
	var brew := TB.power(m, 0, 167, 0)                       # Shaman's Snunday Brew
	TB.cast(m, 0, 154)
	assert_bool(m.reversal_active()).is_true()
	TB.ability(m, brew)
	TB.choose(m, ["Heal 4 HP"])
	assert_int(CF.hp(m, 0)).is_equal(64)


func test_c154_sneaky_snunday_still_reverses_stat_gains() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, MAGE_WATER, 0)
	TB.cast(m, 0, 154)
	TB.cast(m, 0, 182)                                         # Shimmer Serum: +20 ATK this turn
	TB.choose_uids(m, [u])
	assert_int(m.atk_of(u)).is_equal(0)                        # 8 - 20, floored at 0


# @cards 154,163
func test_plan_b_healing_is_not_reversed_by_sneaky_snunday() -> void:
	var m := CF.p1_main()
	var plan := TB.set_card(m, 0, 163, 0)
	var mine := TB.unit(m, 0, MAGE_WATER, 1)
	m.reversal_turn = m.turn
	m.reversal_count = 1
	var u := TB.unit(m, 1, MAGE_FIRE, 0)
	TB.ability(m, TB.power(m, 1, 167, 0))                      # an activation Plan B answers
	assert_str(TB.pend_kind(m)).is_equal("mode")
	TB.choose(m, ["Opponent takes 4 Damage"])
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	TB.choose(m, ["Activate Plan B"])
	TB.choose_uids(m, [mine])
	assert_int(CF.hp(m, 0)).is_equal(60 + 10 - 4)
	assert_str(CF.zone(m, plan)).is_equal("spent")
	assert_str(CF.zone(m, u)).is_equal("unit")


# ---------------------------------------------------------------- Traps

func test_c049_trap_hole_now_answers_a_one_cost_summon() -> void:
	var m := CF.p1_main()
	TB.set_card(m, 0, 49, 0)
	var u := TB.summon(m, 1, MAGE_FIRE, 0)
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	TB.choose(m, ["Activate Trap hole"])
	assert_int(m.status_count(u, "paralyse")).is_equal(3)


func test_c140_energy_dispel_destroys_the_activating_unit_but_does_not_negate() -> void:
	var m := TB.make()
	var drake := TB.unit(m, 0, FLEDGLING_DRAKE, 0)
	var foe := TB.unit(m, 1, MAGE_WATER, 0)
	var ed := TB.set_card(m, 1, ENERGY_DISPEL, 0)
	assert_str(TB.ability(m, drake)).is_empty()
	TB.choose_uids(m, [foe])
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	TB.choose(m, ["Activate Energy Dispel"])
	assert_str(CF.zone(m, drake)).is_equal("spent")
	assert_int(m.status_count(foe, "burn")).is_equal(4)       # the effect still resolves
	assert_str(CF.zone(m, ed)).is_equal("spent")              # not exhausted any more
	assert_int(m.current_cost(ed)).is_equal(2)               # Field -> Spent: permanently +1


func test_c140_energy_dispel_destroys_a_resolving_spell_and_the_spell_still_resolves() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, MAGE_WATER, 0)
	var ed := TB.set_card(m, 1, ENERGY_DISPEL, 0)
	var spell := TB.cast(m, 0, SACRED_OFFERINGS)
	TB.choose_uids(m, [u])
	TB.choose(m, ["Activate Energy Dispel"])
	assert_str(CF.zone(m, spell)).is_equal("spent")
	assert_int(m.status_count(u, "rune")).is_equal(1)
	assert_int(m.current_cost(ed)).is_equal(2)


func test_c140_energy_dispel_is_not_offered_for_a_card_that_already_left_the_field() -> void:
	var m := TB.make()
	var dm := TB.unit(m, 0, 15, 0)                            # Da Mage: optional On Destroy
	TB.set_card(m, 1, ENERGY_DISPEL, 0)
	TB.kill(m, dm, 1)
	assert_bool(m.pending.is_empty()).is_true()


func test_c140_energy_dispel_destroyed_face_down_keeps_its_name_private() -> void:
	var m := TB.make()
	var ed := TB.set_card(m, 1, ENERGY_DISPEL, 0)
	TB.kill(m, ed, 0)
	assert_int(m.current_cost(ed)).is_equal(2)
	assert_str(TB.log_text(m)).not_contains("Energy Dispel")
	var priv := m.log_entries.filter(func(e): return String(e["priv"].get(1, "")).contains("Energy Dispel's cost"))
	assert_int(priv.size()).is_equal(1)


func test_c184_counter_transmutation_plays_a_power_from_spent_for_free() -> void:
	var m := TB.make()
	var ct := TB.set_card(m, 1, COUNTER_TRANSMUTATION, 0)
	var st := TB.set_card(m, 1, SACRED_OFFERINGS, 1)
	var pw := TB.card(m, 1, MAGICAL_COUNCIL, "spent")
	var ap := CF.ap(m, 1)
	TB.kill(m, st, 0)
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	assert_int(int(m.pending["player"])).is_equal(1)
	TB.choose(m, ["Activate Counter Transmutation"])
	assert_array(CF.offered(m)).contains_exactly([pw])
	TB.choose_uids(m, [pw])
	assert_str(TB.pend_kind(m)).is_equal("slot")
	TB.choose(m, ["Power zone 1"])
	assert_str(CF.zone(m, pw)).is_equal("power")
	assert_int(int(m.cards[pw]["ctl"])).is_equal(1)
	assert_int(CF.ap(m, 1)).is_equal(ap)                     # no cost paid
	assert_str(CF.zone(m, ct)).is_equal("spent")
	assert_bool(m.player_has_flag(1, "spells_cost_less")).is_true()


func test_c184_response_panel_names_a_public_destroyed_card_and_hides_a_face_down_one() -> void:
	var m := TB.make()
	TB.set_card(m, 1, COUNTER_TRANSMUTATION, 0)
	TB.card(m, 1, MAGICAL_COUNCIL, "spent")
	var hidden := TB.set_card(m, 0, MAGIC_CYLINDER, 2)        # player 0's own Trap, face down
	TB.kill(m, hidden, 0)
	var pv: Dictionary = MatchView.build(m, 1)["pending"]
	assert_str(String(pv["prompt"])).contains("a set Spell/Trap destroyed")
	var card: Dictionary = pv["mentions"][0]["card"]
	assert_bool(card.get("hidden", false)).is_true()
	assert_str(String(card["zone"])).is_equal("backrow")
	assert_bool(card.has("name")).is_false()
	CF.decline(m)
	var shown := TB.set_card(m, 0, MAGIC_CYLINDER, 1)
	m.apply_status(shown, "reveal", 1)
	TB.kill(m, shown, 0)
	pv = MatchView.build(m, 1)["pending"]
	assert_str(String(pv["mentions"][0]["card"]["name"])).is_equal("Magic Cylinder")


func test_c184_counter_transmutation_answers_a_destroyed_trap_of_either_side() -> void:
	var m := TB.make()
	TB.set_card(m, 1, COUNTER_TRANSMUTATION, 0)
	TB.card(m, 1, MAGICAL_COUNCIL, "spent")
	var own := TB.set_card(m, 0, MAGIC_CYLINDER, 2)
	TB.kill(m, own, 0)                                         # player 0 destroys its own Trap
	assert_str(TB.pend_kind(m)).is_equal("trap_response")


func test_c184_counter_transmutation_is_not_offered_without_a_power_or_a_free_zone() -> void:
	var m := TB.make()
	TB.set_card(m, 1, COUNTER_TRANSMUTATION, 0)
	var st := TB.set_card(m, 1, SACRED_OFFERINGS, 1)
	TB.kill(m, st, 0)
	assert_bool(m.pending.is_empty()).is_true()               # no Power in Spent
	var m2 := TB.make()
	TB.set_card(m2, 1, COUNTER_TRANSMUTATION, 0)
	TB.card(m2, 1, MAGICAL_COUNCIL, "spent")
	for s in 4:
		TB.power(m2, 1, PRESERVATION_JAR, s)
	var st2 := TB.set_card(m2, 1, SACRED_OFFERINGS, 1)
	TB.kill(m2, st2, 0)
	assert_bool(m2.pending.is_empty()).is_true()              # every Power zone is full


func test_c184_counter_transmutation_ignores_destroyed_units_and_used_cards() -> void:
	var m := TB.make()
	TB.set_card(m, 1, COUNTER_TRANSMUTATION, 0)
	TB.card(m, 1, MAGICAL_COUNCIL, "spent")
	TB.kill(m, TB.unit(m, 1, MAGE_WATER, 0), 0)
	assert_bool(m.pending.is_empty()).is_true()
	var target := TB.unit(m, 0, MAGE_WATER, 1)
	var spell := TB.cast(m, 0, SACRED_OFFERINGS)               # used, not destroyed
	TB.choose_uids(m, [target])
	assert_str(CF.zone(m, spell)).is_equal("spent")
	assert_bool(m.pending.is_empty()).is_true()


func test_c184_counter_transmutation_cannot_play_marked_by_the_abyss_with_a_zero_cost_deck() -> void:
	var m := TB.make()
	TB.set_card(m, 1, COUNTER_TRANSMUTATION, 0)
	TB.card(m, 1, MARKED_BY_THE_ABYSS, "spent")
	TB.card(m, 1, FLEDGLING_DRAKE, "draw")                    # a 0-cost card in the deck
	var st := TB.set_card(m, 1, SACRED_OFFERINGS, 1)
	TB.kill(m, st, 0)
	assert_bool(m.pending.is_empty()).is_true()


# ---------------------------------------------------------------- Powers

func test_c168_tactical_arrangements_costs_1_and_draws_before_the_discard() -> void:
	assert_int(CardDB.get_def(168)["cost"]).is_equal(1)
	var m := TB.make()
	for u in m.players[0]["hand"].duplicate():
		m.move_to_pile(u, "spent")
	var pw := TB.power(m, 0, 168, 0)
	assert_str(TB.ability(m, pw)).is_empty()                   # usable with an empty Hand
	assert_int(m.players[0]["hand"].size()).is_equal(1)
	var drawn: int = m.players[0]["hand"][0]
	assert_array(CF.offered(m)).contains_exactly([drawn])
	TB.choose_uids(m, [drawn])
	assert_str(CF.zone(m, drawn)).is_equal("spent")


func test_c169_options_draws_one_card_per_copy_at_the_start_of_your_turn() -> void:
	var m := TB.make()
	TB.power(m, 0, 169, 0)
	TB.power(m, 0, 169, 1)
	_pass_turn(m)
	_pass_turn(m)
	assert_int(m.active).is_equal(0)
	assert_int(m.players[0]["hand"].size()).is_equal(GameCore.BASE_DRAW + 2)
	var idx := TB.log_index(m, "Trigger: Options")
	assert_int(idx).is_greater(TB.log_index(m, "Player 1 draws 4 cards"))


func test_c178_reinforcements_costs_2_and_cuts_unit_costs_by_2() -> void:
	assert_int(CardDB.get_def(178)["cost"]).is_equal(2)
	var m := TB.make()
	TB.power(m, 0, 178, 0)
	var one := TB.card(m, 0, MAGE_WATER)
	var two := TB.card(m, 0, MAGENTRIC)
	var three := TB.card(m, 0, 13)
	assert_int(m.current_cost(three)).is_equal(3)              # nobody controls a unit yet
	TB.unit(m, 1, MAGE_WATER, 0)
	assert_int(m.current_cost(one)).is_equal(0)
	assert_int(m.current_cost(two)).is_equal(0)
	assert_int(m.current_cost(three)).is_equal(1)
	TB.unit(m, 0, MAGE_WATER, 0)
	assert_int(m.current_cost(three)).is_equal(3)              # you control a unit too


func test_c088_elemental_mastery_adds_6_per_copy() -> void:
	var m := TB.make()
	assert_int(m.type_bonus(0)).is_equal(6)
	TB.power(m, 0, 88, 0)
	assert_int(m.type_bonus(0)).is_equal(12)
	TB.power(m, 0, 88, 1)
	assert_int(m.type_bonus(0)).is_equal(18)


# @cards 44,82,89
func test_renamed_and_recosted_powers_and_spells() -> void:
	assert_str(CardDB.get_def(82)["name"]).is_equal("Fusion Ceremony")
	assert_str(CardDB.get_def(89)["name"]).is_equal("Fusion Laboratory")
	assert_int(CardDB.get_def(89)["cost"]).is_equal(1)
	assert_int(CardDB.get_def(44)["cost"]).is_equal(2)


# ---------------------------------------------------------------- Arcane stat changes and Boom, Tritu

# @cards 170,172,173,174,175,176
func test_arcane_units_carry_the_new_stats() -> void:
	var want := {170: [4, 10], 172: [18, 10], 173: [20, 14], 174: [8, 18], 175: [26, 20]}
	for id in want:
		var d := CardDB.get_def(id)
		assert_array([d["atk"], d["def"]]).override_failure_message(str(id)).is_equal(want[id])
	assert_object(CardDB.get_def(176)["atk"]).is_null()
	assert_object(CardDB.get_def(176)["def"]).is_null()


func test_c175_boom_destroyed_gives_your_units_10_def_without_asking() -> void:
	var m := TB.make()
	var boom := TB.unit(m, 0, 175, 0)
	var mine := TB.unit(m, 0, MAGE_WATER, 1)
	var foe := TB.unit(m, 1, MAGE_WATER, 0)
	TB.kill(m, boom)
	assert_bool(m.pending.is_empty()).is_true()
	assert_int(m.def_of(mine)).is_equal(18)
	assert_int(m.def_of(foe)).is_equal(8)


func test_c176_tritu_becomes_the_combined_atk_and_def_of_the_other_water_units() -> void:
	var m := TB.make()
	TB.unit(m, 0, MAGE_WATER, 1)                               # 8/8
	TB.unit(m, 1, BEAST_WATER, 0, "atk", 12, 20)               # 12/20
	TB.unit(m, 1, MAGE_FIRE, 1)                                # not Water
	var tritu := TB.special(m, 0, 176, 0)
	assert_int(m.atk_of(tritu)).is_equal(20)
	assert_int(m.def_of(tritu)).is_equal(28)


func test_c018_corrupted_narzyl_still_gains_a_rune_when_it_destroys_by_battle() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	TB.to_battle(m)
	var narzyl := TB.unit(m, 1, 18, 0, "atk", 20)
	var foe := TB.unit(m, 0, MAGE_WATER, 0)
	TB.attack(m, narzyl, foe)
	assert_str(CF.zone(m, foe)).is_equal("spent")
	assert_int(m.status_count(narzyl, "rune")).is_equal(1)


# ---------------------------------------------------------------- Drako, Councillor of The Order

func test_c185_drako_searches_a_power_from_draw_or_spent_with_a_discount() -> void:
	var m := TB.make(7, 0)
	var in_draw := TB.card(m, 0, MAGICAL_COUNCIL, "draw")
	var in_spent := TB.card(m, 0, PRESERVATION_JAR, "spent")
	TB.card(m, 0, SACRED_OFFERINGS, "draw")                   # not a Power
	TB.special(m, 0, DRAKO, 0)
	assert_array(_opts(m)).contains_exactly_in_any_order([-1, in_draw, in_spent])
	TB.choose_uids(m, [in_spent])
	assert_str(CF.zone(m, in_spent)).is_equal("hand")
	assert_int(m.current_cost(in_spent)).is_equal(1)
	m.turn += 2
	assert_int(m.current_cost(in_spent)).is_equal(2)


func test_c185_drako_destroys_a_power_and_gains_1_ap_only_when_it_was_yours() -> void:
	var m := TB.make()
	var drako := TB.unit(m, 0, DRAKO, 0)
	var own := TB.power(m, 0, MAGICAL_COUNCIL, 0)
	var foe := TB.power(m, 1, SABOTEURS_GUILD, 0)
	assert_str(TB.ability(m, drako)).is_empty()
	var ap := CF.ap(m, 0)
	TB.choose_uids(m, [own])
	assert_str(CF.zone(m, own)).is_equal("spent")
	assert_int(CF.ap(m, 0)).is_equal(ap + 1)
	m.turn += 2
	m.active = 0
	assert_str(TB.ability(m, drako)).is_empty()
	ap = CF.ap(m, 0)
	TB.choose_uids(m, [foe])
	assert_str(CF.zone(m, foe)).is_equal("spent")
	assert_int(CF.ap(m, 0)).is_equal(ap)


func test_c185_drako_ability_needs_a_power_on_the_field() -> void:
	var m := TB.make()
	var drako := TB.unit(m, 0, DRAKO, 0)
	assert_str(TB.ability(m, drako)).is_equal("No legal target.")


# ---------------------------------------------------------------- Bronze Salaman

func test_c186_bronze_salaman_is_a_1_rune_light_dragon_in_the_lone_warrior_deck() -> void:
	var d := CardDB.get_def(BRONZE_SALAMAN)
	assert_array([d["category"], d["race"], d["type"], d["cost_kind"], d["cost"], d["atk"], d["def"]]) \
		.is_equal(["ritual", "Dragon", "Light", "ritual", 1, 20, 20])
	var decks: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/starter_decks.json"))["decks"]
	var lone: Dictionary = decks.filter(func(x): return String(x["name"]).begins_with("Lone Warrior"))[0]
	assert_array(lone["extra"].map(func(x): return int(x))).contains([BRONZE_SALAMAN])
	assert_int(lone["extra"].size()).is_equal(3)


func test_c186_bronze_salaman_offers_a_fusion_summon_as_it_lands() -> void:
	var m := TB.make()
	var beast := TB.unit(m, 0, BEAST_WATER, 1)
	var dragon := TB.unit(m, 0, 2, 2)
	var wyrm := TB.card(m, 0, 93, "extra")                    # Bastion Wyrm: Beast + Dragon
	TB.special(m, 0, BRONZE_SALAMAN, 0)
	assert_str(TB.pend_kind(m)).is_equal("confirm")
	TB.choose(m, ["Yes"])
	assert_str(CF.finish_fusion(m, wyrm, [beast, dragon], "Front row, column 2")).is_empty()
	assert_str(CF.zone(m, wyrm)).is_equal("unit")


# @cards 8,186
func test_no_fusion_prompt_when_no_fusion_summon_is_possible() -> void:
	var m := TB.make()
	TB.special(m, 0, BRONZE_SALAMAN, 0)
	assert_bool(m.pending.is_empty()).is_true()
	TB.unit(m, 0, MAGE_WATER, 4)                                 # Tag Team - S partner, no Fusion unit
	TB.summon(m, 0, 8, 1)
	assert_bool(m.pending.is_empty()).is_true()


func test_c186_bronze_salaman_sacrificed_can_retain_a_card_in_hand() -> void:
	var m := TB.make()
	var bronze := TB.unit(m, 0, BRONZE_SALAMAN, 0)
	var h := TB.card(m, 0, SACRED_OFFERINGS)
	assert_str(m.submit(0, {"t": "sacrifice", "uid": bronze})).is_empty()
	assert_bool(_opts(m).has(-1)).is_true()                    # optional
	TB.choose_uids(m, [h])
	assert_int(m.status_count(h, "retain")).is_equal(1)


func test_c186_bronze_salaman_tributed_for_a_ritual_can_retain_a_card() -> void:
	var m := TB.make()
	var bronze := TB.unit(m, 0, BRONZE_SALAMAN, 0)
	m.apply_status(bronze, "rune", 3)
	var null_u := TB.card(m, 0, 65, "extra")                  # The Creeping Null: 3 Runes
	var h := TB.card(m, 0, SACRED_OFFERINGS)
	assert_str(m.submit(0, {"t": "ritual", "uid": null_u, "stance": "atk"})).is_empty()
	TB.choose_uids(m, [bronze])
	TB.choose(m, ["Front row, column 1"])
	# The tribute's trigger resolves as the material leaves, before the Ritual unit lands.
	assert_bool(_opts(m).has(h)).is_true()
	TB.choose_uids(m, [h])
	assert_int(m.status_count(h, "retain")).is_equal(1)
	if not m.pending.is_empty():
		CF.decline(m)                                           # The Creeping Null's own prompts
	assert_str(CF.zone(m, null_u)).is_equal("unit")


# ---------------------------------------------------------------- Fence of the Marked Claw

func test_c187_fence_searches_a_monster_with_a_discount() -> void:
	var m := TB.make(7, 0)
	var monster := TB.card(m, 0, MONSTER_WATER, "draw")
	TB.card(m, 0, BEAST_WATER, "draw")
	TB.special(m, 0, FENCE, 0)
	assert_array(_opts(m)).contains_exactly_in_any_order([-1, monster])
	TB.choose_uids(m, [monster])
	assert_str(CF.zone(m, monster)).is_equal("hand")
	assert_int(m.current_cost(monster)).is_equal(0)


func test_c187_fence_can_apply_a_rune_whenever_a_spell_is_activated() -> void:
	var m := TB.make()
	var fence := TB.unit(m, 0, FENCE, 0)
	var target := TB.unit(m, 0, MAGE_WATER, 1)
	TB.cast(m, 0, SACRED_OFFERINGS)
	TB.choose_uids(m, [target])                                # Sacred Offerings' own target
	assert_str(TB.pend_kind(m)).is_equal("select")
	assert_bool(_opts(m).has(-1)).is_true()                    # Fence's Rune is optional
	TB.choose_uids(m, [fence])
	assert_int(m.status_count(fence, "rune")).is_equal(1)
	assert_int(m.status_count(target, "rune")).is_equal(1)


func test_c187_fence_answers_the_opponents_spells_too() -> void:
	var m := CF.p1_main()
	var fence := TB.unit(m, 0, FENCE, 0)
	TB.cast(m, 1, SACRED_OFFERINGS)
	TB.choose_uids(m, [fence])
	assert_int(int(m.pending.get("player", -1))).is_equal(0)
	TB.choose_uids(m, [fence])
	assert_int(m.status_count(fence, "rune")).is_equal(2)


func test_c187_fence_ignores_traps_and_powers() -> void:
	var m := TB.make()
	TB.unit(m, 0, FENCE, 0)
	var pw := TB.card(m, 0, PRESERVATION_JAR)
	m.players[0]["ap"] = 5
	m.submit(0, {"t": "power", "uid": pw})
	TB.choose(m, ["Power zone 1"])
	assert_bool(m.pending.is_empty()).is_true()


# ---------------------------------------------------------------- Necro, the Loathsome

func test_c188_necro_materials_are_a_mage_plus_a_debuffed_unit() -> void:
	var m := TB.make()
	var mage := TB.unit(m, 0, MAGE_WATER, 0)
	var other := TB.unit(m, 0, BEAST_WATER, 1)
	assert_bool(CF.fusion_mats_ok(m, NECRO, [mage, other])).is_false()
	m.apply_status(other, "poison", 1)
	assert_bool(CF.fusion_mats_ok(m, NECRO, [mage, other])).is_true()
	var d := CardDB.get_def(NECRO)
	assert_array([d["race"], d["type"], d["atk"], d["def"]]).is_equal(["Mage", "Dark", 32, 0])


func test_c188_necro_copies_every_debuff_on_the_other_units() -> void:
	var m := TB.make()
	var a := TB.unit(m, 1, MAGE_WATER, 0)
	var b := TB.unit(m, 0, BEAST_WATER, 1)
	m.apply_status(a, "poison", 2)
	m.apply_status(b, "burn", 3)
	m.apply_status(b, "pierce", 1)                              # a Buff: not copied
	var necro := TB.special(m, 0, NECRO, 0)
	assert_int(m.status_count(necro, "poison")).is_equal(2)
	assert_int(m.status_count(necro, "burn")).is_equal(3)
	assert_int(m.status_count(necro, "pierce")).is_equal(0)
	assert_int(m.status_count(a, "poison")).is_equal(2)          # copies, not moves


func test_c188_necro_doubles_its_debuffs_and_spreads_them_to_an_opponents_unit() -> void:
	var m := TB.make()
	var necro := TB.unit(m, 0, NECRO, 0)
	m.apply_status(necro, "poison", 2)
	m.apply_status(necro, "burn", 1)
	var foe := TB.unit(m, 1, MAGE_WATER, 0)
	m.apply_status(foe, "poison", 1)
	TB.unit(m, 0, BEAST_WATER, 1)                               # own units are not offered
	assert_str(TB.ability(m, necro)).is_empty()
	assert_array(_opts(m)).contains_exactly([foe])
	TB.choose_uids(m, [foe])
	assert_int(m.status_count(necro, "poison")).is_equal(4)
	assert_int(m.status_count(necro, "burn")).is_equal(2)
	assert_int(m.status_count(foe, "poison")).is_equal(1 + 4)
	assert_int(m.status_count(foe, "burn")).is_equal(2)


func test_c188_necro_ability_needs_a_debuff_and_is_once_per_turn() -> void:
	var m := TB.make()
	var necro := TB.unit(m, 0, NECRO, 0)
	TB.unit(m, 1, MAGE_WATER, 0)
	assert_str(TB.ability(m, necro)).is_equal("Condition not met.")
	m.apply_status(necro, "burn", 1)
	assert_str(TB.ability(m, necro)).is_empty()
	TB.choose_uids(m, [_opts(m)[0]])
	assert_str(TB.ability(m, necro)).is_equal("Already used this turn.")


func test_c188_a_copied_debilitate_suppresses_necros_own_ability() -> void:
	var m := TB.make()
	var foe := TB.unit(m, 1, MAGE_WATER, 0)
	m.apply_status(foe, "debilitate", 1)
	var necro := TB.special(m, 0, NECRO, 0)
	assert_int(m.status_count(necro, "debilitate")).is_equal(1)
	assert_str(TB.ability(m, necro)).is_equal("Debilitated: effects suppressed.")


func test_c188_target_cleanse_prevents_the_spread() -> void:
	var m := TB.make()
	var necro := TB.unit(m, 0, NECRO, 0)
	m.apply_status(necro, "poison", 1)
	var foe := TB.unit(m, 1, MAGE_WATER, 0)
	m.apply_status(foe, "cleanse", 1)
	TB.ability(m, necro)
	TB.choose_uids(m, [foe])
	assert_int(m.status_count(foe, "poison")).is_equal(0)
	assert_int(m.status_count(foe, "cleanse")).is_equal(0)
	assert_int(m.status_count(necro, "poison")).is_equal(2)
