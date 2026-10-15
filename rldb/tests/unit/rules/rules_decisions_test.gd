extends GdUnitTestSuite
## User decision answers (design/decision-register-answers.md) and later confirmations
## C-03/C-04. Each test names the decision it pins down.


func _battle() -> MatchEngine:
	var m := TB.make()
	TB.to_turn2(m)
	TB.to_battle(m)
	return m


# P-13: Burn after a completed attack, win or lose; not on declaration or cancellation.
func test_p13_burn_applies_after_completed_losing_attack() -> void:
	var m := _battle()
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 5)
	m.apply_status(a, "burn", 3)
	var d := TB.unit(m, 0, TB.WATER, 0, "atk", 20)
	TB.attack(m, a, d)
	assert_int(m.players[1]["hp"]).is_equal(60 - 15 - 3)
	assert_bool(TB.log_index(m, "Battle:") < TB.log_index(m, "Burn on")).is_true()


func test_p13_burn_not_applied_when_attack_is_cancelled() -> void:
	var m := _battle()
	TB.set_card(m, 0, 46, 2)                              # Mirror Force
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 30)
	m.apply_status(a, "burn", 5)
	for s in [1, 2, 3]:
		TB.unit(m, 1, TB.WATER, s, "def")
	TB.attack(m, a, TB.unit(m, 0, TB.WATER, 0))
	TB.choose(m, ["Activate Mirror Force"])
	assert_int(m.players[1]["hp"]).is_equal(60)


# P-12: Pierce is consumed only when excess damage is actually dealt.
func test_p12_pierce_kept_when_attack_deals_no_damage() -> void:
	var m := _battle()
	var il := TB.unit(m, 1, 177, 0)                       # The Illusionist: no battle damage
	m.apply_status(il, "pierce", 1)
	TB.attack(m, il, TB.unit(m, 0, TB.WATER, 0, "def", 0, 5))
	assert_int(m.status_count(il, "pierce")).is_equal(1)
	assert_int(m.players[0]["hp"]).is_equal(60)


# P-22: On Summon resolves before summon-response Traps.
func test_p22_on_summon_resolves_before_summon_trap() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	TB.set_card(m, 0, 49, 0)                              # Trap hole (2+ cost summons)
	var u := TB.summon(m, 1, 78, 0)                       # Abraxus: On Summon Cleanse 1
	assert_str(m.pending["kind"]).is_equal("trap_response")
	assert_int(m.status_count(u, "cleanse")).is_equal(1)
	TB.choose(m, ["Activate Trap hole"])
	assert_int(m.status_count(u, "paralyse")).is_equal(0)   # its Cleanse blocks the Paralyse


# P-23 / C-03: Magic Cylinder and Damage Conversion: attacks on your unit in the trap's column only.
func test_p23_magic_cylinder_ignores_direct_attacks() -> void:
	var m := _battle()
	TB.set_card(m, 0, 45, 0)
	var a := TB.unit(m, 1, 162, 0)                        # Diggie can attack directly
	TB.unit(m, 0, TB.WATER, 2)
	m.submit(1, {"t": "attack", "uid": a})
	TB.choose(m, ["directly"])
	assert_bool(m.pending.is_empty()).is_true()


func test_p23_magic_cylinder_triggers_from_attacker_in_another_column() -> void:
	var m := _battle()
	TB.set_card(m, 0, 45, 2)                              # column 3
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 10)        # attacker in column 1
	var d := TB.unit(m, 0, TB.WATER, 2)                   # defender in column 3
	TB.attack(m, a, d)
	assert_str(m.pending["kind"]).is_equal("trap_response")


func test_c03_damage_conversion_ignores_direct_attacks() -> void:
	var m := _battle()
	TB.set_card(m, 0, 47, 0)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	TB.attack(m, a, -1)
	assert_bool(m.pending.is_empty()).is_true()
	assert_int(m.players[0]["hp"]).is_equal(50)


# P-26: Nimble moves only in Main Phases.
func test_p26_nimble_cannot_move_during_battle() -> void:
	var m := _battle()
	var u := TB.unit(m, 1, TB.WATER, 0)
	m.apply_status(u, "nimble", 1)
	assert_str(m.validate(1, {"t": "move", "uid": u})).contains("Main Phase")


# P-19: Elemental Mastery and Options stack.
func test_p19_two_elemental_masteries_give_24_advantage() -> void:
	var m := _battle()
	TB.power(m, 1, 88, 0)
	TB.power(m, 1, 88, 1)
	var water := TB.unit(m, 1, TB.WATER, 0, "atk", 8)
	TB.attack(m, water, TB.unit(m, 0, TB.FIRE, 0, "atk", 10))
	assert_int(m.players[0]["hp"]).is_equal(60 - 22)


func test_p19_two_options_draw_six() -> void:
	var m := TB.make()
	TB.power(m, 1, 169, 0)
	TB.power(m, 1, 169, 1)
	TB.to_turn2(m)
	assert_int(m.players[1]["hand"].size()).is_equal(6)


# S-01: two Sneaky Snundays cancel; S-04: self-cost changes reverse, floored at zero.
func test_s01_two_snundays_cancel() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0, "atk", 10)
	TB.cast(m, 0, 154)
	TB.cast(m, 0, 154)
	TB.cast(m, 0, 182)                                    # Shimmer Serum +16
	TB.choose_uids(m, [u])                                # target is always the player's choice
	assert_int(m.atk_of(u)).is_equal(26)


func test_s04_shimmer_cost_change_reverses_but_never_below_zero() -> void:
	var m := TB.make()
	var own := TB.unit(m, 0, TB.WATER, 0, "atk", 10)
	TB.cast(m, 0, 154)
	var s := TB.cast(m, 0, 182)
	TB.choose_uids(m, [own])
	assert_int(m.current_cost(s)).is_equal(0)
	assert_int(m.cards[s]["cost_p"]).is_equal(0)


func test_s04_magic_cylinder_cost_change_reverses_under_snunday() -> void:
	var m := _battle()
	var mc := TB.set_card(m, 0, 45, 0)
	TB.cast(m, 1, 154)                                    # active player's reversal applies this turn
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	TB.attack(m, a, TB.unit(m, 0, TB.WATER, 0))
	TB.choose(m, ["Activate Magic Cylinder"])
	assert_int(m.current_cost(mc)).is_equal(0)            # 1 - 1


# P-20: Plan B destroys in selected order, each chain fully resolved, healing last.
func test_p20_plan_b_resolves_each_destruction_chain_before_the_next() -> void:
	var m := _battle()
	TB.set_card(m, 0, 163, 2)                             # Plan B
	TB.set_card(m, 0, 87, 1)                              # Shared Fate
	var d1 := TB.unit(m, 0, TB.WATER, 0)
	var d2 := TB.unit(m, 0, 155, 1)                       # Symbiote - Black
	var foe := TB.unit(m, 1, TB.WATER, 2, "def", 0, 50)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 5)
	TB.attack(m, a, d1)
	TB.choose(m, ["Activate Plan B"])
	TB.choose_uids(m, [d2, d1])                           # ordered selection
	assert_str(m.pending["kind"]).is_equal("trap_response")   # Shared Fate after the first destruction
	TB.choose(m, ["Activate Shared Fate"])
	TB.choose_uids(m, [foe]) if m.pending.get("kind", "") == "select" else null
	var i_sym := TB.log_index(m, "Symbiote - Black is destroyed")
	var i_fate := TB.log_index(m, "activates Trap Shared Fate")
	var i_d1 := TB.log_index(m, "Basic Mage (Water) is destroyed")
	var i_heal := TB.log_index(m, "(Plan B, 2 destroyed)")
	assert_bool(i_sym < i_fate and i_fate < i_d1 and i_d1 < i_heal).is_true()
	assert_int(m.players[0]["hp"]).is_equal(80)


# P-24: triggered effects (On Summon) are effect activations the opponent may answer.
func test_p24_on_summon_trigger_can_be_negated_by_energy_dispel() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	TB.set_card(m, 0, 140, 0)                             # Energy Dispel
	var u := TB.summon(m, 1, 24, 0)                       # Chidori Monk: On Summon Infiltrate
	assert_str(m.pending["kind"]).is_equal("trap_response")
	TB.choose(m, ["Activate Energy Dispel"])
	assert_int(m.status_count(u, "infiltrate")).is_equal(0)
	assert_str(m.cards[u]["zone"]).is_equal("spent")


# P-11/P-20 detail: a destroyed card's own effects resolve before listening Traps.
func test_destroyed_cards_own_effect_resolves_before_listening_trap() -> void:
	var m := _battle()
	TB.set_card(m, 0, 86, 1)                              # Get Well Soon
	var cosmic := TB.unit(m, 0, 31, 0)                    # On Destruction: you can apply 3 Medic
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 60)
	TB.attack(m, a, cosmic)
	assert_str(m.pending["kind"]).is_equal("select")      # Cosmic Dragon's own effect first
	assert_int(m.pending["player"]).is_equal(0)


# P-27: no dummy response prompts by default.
func test_p27_no_prompt_without_a_legal_response() -> void:
	var m := TB.make()
	m.config.erase("hidden_response_windows")
	TB.to_turn2(m)
	TB.to_battle(m)
	TB.set_card(m, 0, 83, 2)                              # face-down Spell, cannot respond
	TB.attack(m, TB.unit(m, 1, TB.WATER, 0, "atk", 10), -1)
	assert_bool(m.pending.is_empty()).is_true()


# User decision 2026-10-15: Plan B must destroy at least one card.
func test_plan_b_rejects_zero_targets() -> void:
	var m := _battle()
	TB.set_card(m, 0, 163, 2)
	var d1 := TB.unit(m, 0, TB.WATER, 0)
	TB.unit(m, 0, TB.WATER, 1)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 5)
	TB.attack(m, a, d1)
	TB.choose(m, ["Activate Plan B"])
	assert_int(int(m.pending["min"])).is_equal(1)
	assert_str(m.submit(0, {"t": "choose", "id": m.pending["id"], "indices": []})).is_not_empty()
	assert_str(m.pending["kind"]).is_equal("select")


func test_plan_b_not_offered_without_another_own_card() -> void:
	var m := _battle()
	TB.set_card(m, 0, 163, 2)                             # Plan B is the only card defender controls
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 5)
	m.submit(1, {"t": "attack", "uid": a})
	if m.pending.get("kind", "") == "attack_target":
		TB.choose(m, ["directly"])
	assert_bool(m.pending.get("kind", "") == "trap_response").is_false()
