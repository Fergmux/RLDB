extends GdUnitTestSuite
## Responses, trigger ordering, immediate defeat and card-specific acceptance checks.


func _battle_match() -> MatchEngine:
	var m := TB.make()
	TB.to_turn2(m)
	TB.to_battle(m)
	return m


func test_trap_prompt_suspends_active_player_indefinitely() -> void:
	var m := _battle_match()
	TB.set_card(m, 0, 45, 0)                    # Magic Cylinder, column 1
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	var d := TB.unit(m, 0, TB.WATER, 0, "atk", 8)
	TB.attack(m, a, d)
	assert_str(m.pending["kind"]).is_equal("trap_response")
	assert_int(m.pending["player"]).is_equal(0)
	assert_str(m.submit(1, {"t": "next_phase"})).is_equal("Waiting for the opponent.")
	assert_str(m.submit(1, {"t": "attack", "uid": a})).is_equal("Waiting for the opponent.")
	assert_str(m.submit(1, {"t": "choose", "id": m.pending["id"], "indices": [0]})).is_equal("This choice belongs to the other player.")
	assert_str(m.phase).is_equal("battle")


func test_magic_cylinder_resolves_hp_loss_first_then_battle_continues() -> void:
	var m := _battle_match()
	var mc := TB.set_card(m, 0, 45, 0)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	var d := TB.unit(m, 0, TB.WATER, 0, "atk", 8)
	TB.attack(m, a, d)
	assert_str(TB.choose(m, ["Activate Magic Cylinder"])).is_empty()
	assert_int(m.players[1]["hp"]).is_equal(50)
	assert_str(m.cards[d]["zone"]).is_equal("spent")
	assert_int(m.players[0]["hp"]).is_equal(58)
	assert_str(m.cards[a]["zone"]).is_equal("unit")
	assert_int(m.current_cost(mc)).is_equal(2)
	assert_bool(TB.log_index(m, "loses 10 HP") < TB.log_index(m, "Battle:")).is_true()


func test_magic_cylinder_lethal_ends_game_before_battle() -> void:
	var m := _battle_match()
	TB.set_card(m, 0, 45, 0)
	m.players[1]["hp"] = 10
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	var d := TB.unit(m, 0, TB.WATER, 0, "atk", 8)
	TB.attack(m, a, d)
	TB.choose(m, ["Activate"])
	assert_int(m.winner).is_equal(0)
	assert_str(m.cards[d]["zone"]).is_equal("unit")
	assert_int(TB.log_index(m, "Battle:")).is_equal(-1)


func test_passing_on_trap_lets_battle_resolve() -> void:
	var m := _battle_match()
	TB.set_card(m, 0, 45, 0)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	var d := TB.unit(m, 0, TB.WATER, 0, "atk", 8)
	TB.attack(m, a, d)
	TB.choose(m, ["Skip"])
	assert_str(m.cards[d]["zone"]).is_equal("spent")
	assert_int(m.players[1]["hp"]).is_equal(60)


func test_mirror_force_destroys_attacker_so_battle_does_not_resolve() -> void:
	var m := _battle_match()
	TB.set_card(m, 0, 46, 2)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 30)
	for s in [1, 2, 3]:
		TB.unit(m, 1, TB.WATER, s, "atk")
	var d := TB.unit(m, 0, TB.WATER, 0, "atk", 8)
	TB.attack(m, a, d)
	TB.choose(m, ["Activate Mirror Force"])
	assert_str(m.cards[a]["zone"]).is_equal("spent")
	assert_str(m.cards[d]["zone"]).is_equal("unit")
	assert_int(m.field_units(1).size()).is_equal(0)
	assert_int(m.players[0]["hp"]).is_equal(60)


func test_mirror_force_needs_attacker_with_four_field_cards() -> void:
	var m := _battle_match()
	TB.set_card(m, 0, 46, 2)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 30)
	var d := TB.unit(m, 0, TB.WATER, 0, "atk", 8)
	TB.attack(m, a, d)
	assert_bool(m.pending.is_empty()).is_true()
	assert_str(m.cards[d]["zone"]).is_equal("spent")


func test_trap_owner_orders_multiple_eligible_traps() -> void:
	var m := _battle_match()
	TB.set_card(m, 0, 45, 0)                    # Magic Cylinder
	TB.set_card(m, 0, 47, 0 + 1)                # Damage Conversion, column 2 (not attacked column)
	TB.set_card(m, 0, 51, 2)                    # Rushed Recklessly (any attack)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	var d := TB.unit(m, 0, TB.WATER, 0, "atk", 8)
	TB.attack(m, a, d)
	var labels: Array = m.pending["options"].map(func(o): return o["label"])
	assert_array(labels).contains(["Skip", "Skip for the rest of this turn", "Activate Magic Cylinder", "Activate Rushed Recklessly"])
	assert_array(labels).not_contains(["Activate Damage Conversion"])
	TB.choose(m, ["Activate Rushed Recklessly"])
	assert_str(m.pending["kind"]).is_equal("trap_response")
	TB.choose(m, ["Activate Magic Cylinder"])
	assert_int(m.players[1]["hp"]).is_equal(50)


func test_traps_cannot_activate_on_own_turn() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	TB.set_card(m, 1, 49, 0)                    # Trap Hole owned by active player
	var u := TB.card(m, 1, 28)
	m.submit(1, {"t": "summon", "uid": u})
	TB.choose(m, ["Front row, column 1"])
	TB.choose(m, ["Attack"])
	assert_bool(m.pending.is_empty() or m.pending["kind"] != "trap_response").is_true()


func test_own_hp_reaching_zero_in_ordered_loss_ends_before_second_step() -> void:
	var m := TB.make()
	var avatar := TB.unit(m, 0, 14, 0)          # Avatar: lose 6 then opponent loses 6
	m.players[0]["hp"] = 6
	m.destroy(avatar, "effect", -1, 1)
	m.run()
	assert_int(m.winner).is_equal(1)
	assert_int(m.players[1]["hp"]).is_equal(60)


func test_narzyl_destroying_crevasse_resolves_narzyl_rune_before_crevasse_paralyse() -> void:
	var m := _battle_match()
	var narzyl := TB.unit(m, 1, 18, 0)          # Corrupted Narzyl 10/0 (active player)
	var crevasse := TB.unit(m, 0, 100, 0)       # Gaping Crevasse 0/10
	TB.attack(m, narzyl, crevasse)
	var rune_i := TB.log_index(m, "gains 1 Rune")
	var para_i := TB.log_index(m, "gains 2 Paralyse")
	assert_int(rune_i).is_greater(0)
	assert_int(para_i).is_greater(rune_i)
	assert_int(m.status_count(narzyl, "paralyse")).is_equal(2)
	assert_int(m.status_count(narzyl, "rune")).is_equal(1)


func test_necrovast_destruction_can_move_exhausted_card_to_draw() -> void:
	var m := TB.make()
	var nv := TB.unit(m, 0, 64, 0)
	var ex := TB.card(m, 0, 28, "exhaust")
	m.destroy(nv, "effect", -1, 1)
	m.run()
	assert_str(m.pending["kind"]).is_equal("select")
	TB.choose_uids(m, [ex])
	assert_str(m.cards[ex]["zone"]).is_equal("draw")


func test_ordinary_effect_cannot_return_card_from_exhaust() -> void:
	var m := TB.make()
	var ex := TB.card(m, 0, 28, "exhaust")
	var f := m.make_frame(-1, 0, [], "")
	assert_bool(ex in m.select(f, {"kind": "spent", "side": "self"})).is_false()


func test_hypnotised_unit_cannot_be_sacrificed_and_returns_at_end_of_turn() -> void:
	var m := TB.make()
	var victim := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	var spell := TB.card(m, 0, 180)
	assert_str(m.submit(0, {"t": "cast", "uid": spell})).is_empty()
	assert_str(TB.choose_uids(m, [victim])).is_empty()    # sole legal target is still chosen by the player
	assert_int(m.cards[victim]["ctl"]).is_equal(0)
	assert_str(m.validate(0, {"t": "sacrifice", "uid": victim})).contains("temporarily controlled")
	TB.to_turn2(m)
	assert_int(m.cards[victim]["ctl"]).is_equal(1)


## Takes control of `victim` for player 0 with Hypnotise.
func _hypnotise(m: MatchEngine, victim: int) -> void:
	var spell := TB.card(m, 0, 180)
	m.players[0]["ap"] = 10
	assert_str(m.submit(0, {"t": "cast", "uid": spell})).is_empty()
	assert_str(TB.choose_uids(m, [victim])).is_empty()


func test_hypnotise_cannot_be_cast_without_a_free_zone() -> void:
	# Ruling 2026-10-16: no target zone, so the Spell cannot be played at all.
	var m := TB.make()
	TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	for s in 6:
		TB.unit(m, 0, TB.WATER, s)
	var spell := TB.card(m, 0, 180)
	m.players[0]["ap"] = 10
	assert_str(m.validate(0, {"t": "cast", "uid": spell})).contains("free zone")


func test_hypnotised_unit_returns_to_its_original_zone() -> void:
	var m := TB.make()
	var victim := TB.unit(m, 1, TB.WATER, 4, "atk", 10)
	_hypnotise(m, victim)
	TB.to_turn2(m)
	assert_int(m.cards[victim]["ctl"]).is_equal(1)
	assert_int(m.cards[victim]["slot"]).is_equal(4)
	assert_int(m.players[1]["units"][4]).is_equal(victim)


func test_hypnotised_unit_goes_to_spent_when_its_zone_was_filled() -> void:
	var m := TB.make()
	var victim := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	_hypnotise(m, victim)
	TB.unit(m, 1, TB.WATER, 0)
	TB.to_turn2(m)
	assert_str(m.cards[victim]["zone"]).is_equal("spent")
	assert_bool(victim in m.players[1]["spent"]).is_true()


func test_hypnotised_unit_keeps_its_statuses_when_it_returns() -> void:
	var m := TB.make()
	var victim := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	_hypnotise(m, victim)
	m.apply_status(victim, "rune", 2)
	TB.to_turn2(m)
	assert_int(m.status_count(victim, "rune")).is_equal(2)


func test_hypnotised_unit_can_be_ritual_material_and_goes_to_its_owners_spent() -> void:
	# Ruling 2026-10-16: it cannot be sacrificed, but it can be tributed (Ritual, Fusion).
	var m := TB.make()
	var victim := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	m.apply_status(victim, "rune", 3)
	_hypnotise(m, victim)
	var roma := TB.card(m, 0, 96, "extra")
	assert_str(m.submit(0, {"t": "ritual", "uid": roma})).is_empty()
	assert_str(TB.choose_uids(m, [victim])).is_empty()
	TB.choose(m, ["Front row, column 1"])
	TB.choose(m, ["Attack"])
	assert_int(m.atk_of(roma)).is_equal(36)
	assert_bool(victim in m.players[1]["spent"]).is_true()


# ---------------------------------------------------------------- Sneaky Snunday

func _cast(m: MatchEngine, p: int, id: int, target: int = -1) -> int:
	var uid := TB.card(m, p, id)
	m.players[p]["ap"] = 10
	var e := m.submit(p, {"t": "cast", "uid": uid})
	assert_str(e).is_empty()
	if target != -1:
		assert_str(TB.choose_uids(m, [target])).is_empty()   # the target is always the player's choice
	return uid


func test_snunday_reverses_shimmer_serum_atk_but_not_blind() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0, "atk", 10)
	_cast(m, 0, 154)
	_cast(m, 0, 182, u)
	assert_int(m.atk_of(u)).is_equal(0)
	assert_int(m.status_count(u, "blind")).is_equal(1)


# 2026-10-18: Damage is not a "loss", so Sneaky Snunday no longer turns it into healing.
func test_snunday_no_longer_turns_divine_serpent_damage_into_healing() -> void:
	var m := TB.make()
	TB.unit(m, 0, 159, 1)
	TB.unit(m, 0, 160, 3)
	_cast(m, 0, 154)
	var head := TB.card(m, 0, 158)
	m.submit(0, {"t": "summon", "uid": head})
	TB.choose(m, ["Front row, column 1"])
	TB.choose(m, ["Attack"])
	assert_int(m.players[1]["hp"]).is_equal(30)


func test_divine_serpent_damages_opponent_without_reversal() -> void:
	var m := TB.make()
	TB.unit(m, 0, 159, 1)
	TB.unit(m, 0, 160, 3)
	var head := TB.card(m, 0, 158)
	m.players[0]["ap"] = 5
	m.submit(0, {"t": "summon", "uid": head})
	TB.choose(m, ["Front row, column 1"])
	TB.choose(m, ["Attack"])
	assert_int(m.players[1]["hp"]).is_equal(30)


# L15 (2026-11-05): Sneaky Snunday reverses ATK/DEF only, so the AP next turn is not reversed.
func test_delayed_gratification_under_snunday_still_gives_plus_one_ap() -> void:
	var m := TB.make()
	_cast(m, 0, 154)
	_cast(m, 0, 41)
	assert_str(m.pending["kind"]).is_equal("select")   # which Hand card gets Retain
	m.submit(0, {"t": "choose", "id": m.pending["id"], "indices": [0]})
	TB.to_turn2(m)
	for i in 3:
		m.submit(1, {"t": "next_phase"})
	assert_int(m.active).is_equal(0)
	assert_int(m.players[0]["ap"]).is_equal(GameCore.BASE_AP + 1)


func test_snunday_flips_continuous_aura_while_active_and_restores_after() -> void:
	var m := TB.make()
	TB.unit(m, 0, 159, 0)                       # Divine Serpent - Body: adjacent +10 DEF
	var friend := TB.unit(m, 0, TB.WATER, 1, "atk", 8, 20)
	assert_int(m.def_of(friend)).is_equal(30)
	_cast(m, 0, 154)
	assert_int(m.def_of(friend)).is_equal(10)
	TB.to_turn2(m)
	assert_int(m.def_of(friend)).is_equal(30)


# L15 (2026-11-05): "all new and ongoing" gains are reversed, so a gain from before Snunday is too.
func test_snunday_reverses_an_already_resolved_gain() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0, "atk", 10)
	_cast(m, 0, 182, u)                         # Shimmer Serum +10 before the reversal
	assert_int(m.atk_of(u)).is_equal(20)
	_cast(m, 0, 154)
	assert_int(m.atk_of(u)).is_equal(0)


func test_snunday_does_not_reverse_battle_damage_or_ap_payment() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	var spell := TB.card(m, 1, 154)
	m.submit(1, {"t": "cast", "uid": spell})
	assert_int(m.players[1]["ap"]).is_equal(1)
	TB.to_battle(m)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 12)
	TB.attack(m, a, -1)
	assert_int(m.players[0]["hp"]).is_equal(48)


func test_controller_orders_own_simultaneous_triggers() -> void:
	var m := TB.make()
	var zealot := TB.unit(m, 1, 17, 0)                  # start of turn: Rune
	var neva := TB.unit(m, 1, 161, 1)                   # start of turn: Eternal
	TB.to_turn2(m)
	assert_str(m.pending["kind"]).is_equal("order")
	TB.choose(m, ["Neva"])
	assert_int(TB.log_index(m, "Neva the Divine Mother gains 1 Eternal")).is_less(TB.log_index(m, "Accursed Zealot gains 1 Rune"))
	assert_int(m.status_count(zealot, "rune")).is_equal(1)
	assert_int(m.status_count(neva, "eternal")).is_equal(1)
