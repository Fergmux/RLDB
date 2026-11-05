extends GdUnitTestSuite
## L19 (design/owner-feedback-2026-11-05.md): "the fusion card should already be destroyed by the time
## the fusion happens". Whatever a summon uses up (the Spell or Trap doing the summoning, Field / Hand /
## Spent materials, a method unit that destroys or exhausts itself) is in its destination pile before
## the summoned unit's On Summon effects resolve or pick targets. A tributed material's own "If this
## Unit is Tributed" effect resolves once the summoned unit has landed (so it may pick it), before
## that unit's On Summon.

const FUSION_CEREMONY := 82
const ABYSSLORD := 59           # Mage + Water; On Summon: "You can Destroy a Spell/Trap."
const AMBUSH := 42
const TRAP_HOLE := 49
const DEFCON_2 := 52            # opponent summons a 2+ cost unit: a 2-cost or lower unit from Spent, this column
const SWEEPER := 29             # On Summon: you can Reveal a Spell/Trap in this column
const RADABLAST := 77           # a 2-cost unit
const SEPPUKU := 68
const SPARKY := 74              # Mage; if Tributed: apply 1 Infiltrate to a unit
const UNSTABLE_FUSIONS := 137   # Units in Hand may be Fusion materials (exhausted)
const CREEPING_NULL := 65       # Ritual, 3 Runes; On Summon: you can apply 1 Rune to a unit
const TYDE := 172               # Arcane 3; On Summon: you can add a Beast from Draw
const BASIC_BEAST := 4

const DESTROY_PROMPT := "Destroy a Spell or Trap?"


## Answers the Fusion summon's own prompts (Fusion unit, materials, zone, stance) and stops at the
## first prompt that is not one of them. Returns that prompt's text ("" when nothing is pending).
func _drive_fusion(m: MatchEngine, fu: int, mats: Array, zone: String = "Front row, column 1") -> String:
	var left := mats.duplicate()
	for _i in 12:
		if m.pending.is_empty():
			return ""
		var pd := m.pending
		var hit := -1
		var prompt := String(pd["prompt"])
		var fusion_prompt := prompt.begins_with("Choose a Fusion unit") or prompt.contains("for the summon of")
		for o in pd["options"]:
			var v = o.get("v", -1)
			if pd["kind"] == "select" and fusion_prompt and (int(v) == fu or int(v) in left):
				hit = int(v)
				break
		if hit != -1:
			left.erase(hit)
			assert_str(TB.choose_uids(m, [hit])).is_empty()
		elif pd["kind"] == "slot":
			assert_str(TB.choose(m, [zone])).is_empty()
		elif pd["kind"] == "stance":
			assert_str(TB.choose(m, ["Attack"])).is_empty()
		else:
			return String(pd["prompt"])
	return String(m.pending.get("prompt", ""))


func _ceremony_setup(m: MatchEngine) -> Dictionary:
	var a := TB.unit(m, 0, TB.WATER, 0)
	var b := TB.unit(m, 0, TB.WATER, 1)
	var fu := TB.card(m, 0, ABYSSLORD, "extra")
	var foe_set := TB.set_card(m, 1, TRAP_HOLE, 2)       # something the On Summon can still destroy
	return {"a": a, "b": b, "fu": fu, "foe_set": foe_set}


func test_set_fusion_ceremony_is_not_offered_to_the_fusion_units_on_summon() -> void:
	var m := TB.make()
	var s := _ceremony_setup(m)
	var fc := TB.set_card(m, 0, FUSION_CEREMONY, 0)
	m.players[0]["ap"] = 10
	assert_str(m.submit(0, {"t": "activate_set", "uid": fc})).is_empty()
	assert_str(_drive_fusion(m, s["fu"], [s["a"], s["b"]])).is_equal(DESTROY_PROMPT)
	var offered := CF.offered(m)
	assert_bool(fc in offered).is_false()
	assert_bool(s["foe_set"] in offered).is_true()
	assert_str(CF.zone(m, fc)).is_equal("spent")


func test_cast_fusion_ceremony_is_in_spent_before_the_on_summon() -> void:
	var m := TB.make()
	var s := _ceremony_setup(m)
	var fc := TB.cast(m, 0, FUSION_CEREMONY)
	assert_str(_drive_fusion(m, s["fu"], [s["a"], s["b"]])).is_equal(DESTROY_PROMPT)
	assert_str(CF.zone(m, fc)).is_equal("spent")


func test_field_materials_are_in_spent_before_the_on_summon() -> void:
	var m := TB.make()
	var s := _ceremony_setup(m)
	TB.cast(m, 0, FUSION_CEREMONY)
	assert_str(_drive_fusion(m, s["fu"], [s["a"], s["b"]])).is_equal(DESTROY_PROMPT)
	assert_str(CF.zone(m, s["a"])).is_equal("spent")
	assert_str(CF.zone(m, s["b"])).is_equal("spent")
	assert_str(CF.zone(m, s["fu"])).is_equal("unit")
	CF.decline(m)
	assert_str(CF.zone(m, s["foe_set"])).is_equal("backrow")


func test_hand_materials_are_exhausted_before_the_on_summon() -> void:
	var m := TB.make()
	TB.power(m, 0, UNSTABLE_FUSIONS, 0)
	var a := TB.card(m, 0, TB.WATER)
	var b := TB.card(m, 0, TB.WATER)
	var fu := TB.card(m, 0, ABYSSLORD, "extra")
	TB.set_card(m, 1, TRAP_HOLE, 2)
	TB.cast(m, 0, FUSION_CEREMONY)
	assert_str(_drive_fusion(m, fu, [a, b])).is_equal(DESTROY_PROMPT)
	assert_str(CF.zone(m, a)).is_equal("exhaust")
	assert_str(CF.zone(m, b)).is_equal("exhaust")


func test_seppuku_is_destroyed_before_the_fusion_units_on_summon() -> void:
	var m := TB.make()
	var sepp := TB.unit(m, 0, SEPPUKU, 3)
	var s := _ceremony_setup(m)
	assert_str(TB.ability(m, sepp)).is_empty()
	assert_str(_drive_fusion(m, s["fu"], [s["a"], s["b"]])).is_equal(DESTROY_PROMPT)
	assert_str(CF.zone(m, sepp)).is_equal("spent")
	assert_bool(TB.log_index(m, "Seppuku is destroyed") < TB.log_index(m, "Trigger: Abysslord")).is_true()


func test_a_tributed_materials_own_effect_resolves_after_the_fusion_unit_lands() -> void:
	var m := TB.make()
	var sparky := TB.unit(m, 0, SPARKY, 0)
	var b := TB.unit(m, 0, TB.WATER, 1)
	var fu := TB.card(m, 0, ABYSSLORD, "extra")
	TB.set_card(m, 1, TRAP_HOLE, 2)
	TB.cast(m, 0, FUSION_CEREMONY)
	var first := _drive_fusion(m, fu, [sparky, b])
	assert_str(first).contains("Infiltrate")                  # Sparky's own effect comes first ...
	assert_str(CF.zone(m, fu)).is_equal("unit")               # ... once Abysslord is on the Field,
	assert_bool(fu in CF.offered(m)).is_true()                # so it may pick Abysslord
	assert_str(CF.zone(m, sparky)).is_equal("spent")
	assert_str(TB.choose_uids(m, [fu])).is_empty()
	assert_int(m.status_count(fu, "infiltrate")).is_equal(1)
	assert_str(String(m.pending.get("prompt", ""))).is_equal(DESTROY_PROMPT)   # then its On Summon


func test_tributed_material_effects_and_the_summon_share_one_fx_batch() -> void:
	# Presentation: the material events and the summon reach the client together, so the Fusion set
	# piece plays whole before the material's prompt.
	var m := TB.make()
	var sparky := TB.unit(m, 0, SPARKY, 0)
	var b := TB.unit(m, 0, TB.WATER, 1)
	var fu := TB.card(m, 0, ABYSSLORD, "extra")
	TB.cast(m, 0, FUSION_CEREMONY)
	_drive_fusion(m, fu, [sparky, b])
	var kinds := []
	for e in m.log_entries:
		for fx in e["fx"]:
			kinds.append(String(fx["k"]))
	assert_bool("summon" in kinds).is_true()
	assert_int(kinds.count("material")).is_equal(2)


func test_ritual_material_is_in_spent_before_the_on_summon() -> void:
	var m := TB.make()
	var mat := TB.unit(m, 0, BASIC_BEAST, 0)
	m.apply_status(mat, "rune", 3)
	var null_u := TB.card(m, 0, CREEPING_NULL, "extra")
	assert_str(m.submit(0, {"t": "ritual_tribute", "uid": mat, "target": null_u})).is_empty()
	TB.choose(m, ["Front row, column 1"])
	if TB.pend_kind(m) == "stance":
		TB.choose(m, ["Attack"])
	assert_str(String(m.pending.get("prompt", ""))).contains("Rune")
	assert_str(CF.zone(m, mat)).is_equal("spent")
	assert_str(CF.zone(m, null_u)).is_equal("unit")


func test_arcane_materials_are_exhausted_before_the_on_summon() -> void:
	var m := TB.make()
	var mats := [TB.card(m, 0, TB.WATER, "spent"), TB.card(m, 0, TB.WATER, "spent"), TB.card(m, 0, TB.WATER, "spent")]
	TB.card(m, 0, BASIC_BEAST, "draw")
	var tyde := TB.card(m, 0, TYDE, "extra")
	assert_str(m.submit(0, {"t": "arcane", "uid": tyde})).is_empty()
	assert_str(TB.choose_uids(m, mats)).is_empty()
	TB.choose(m, ["Front row, column 1"])
	if TB.pend_kind(m) == "stance":
		TB.choose(m, ["Attack"])
	assert_str(String(m.pending.get("prompt", ""))).contains("Beast")
	for u in mats:
		assert_str(CF.zone(m, u)).is_equal("exhaust")


func test_set_ambush_is_in_spent_once_its_first_unit_lands() -> void:
	var m := TB.make()
	TB.card(m, 0, TB.WATER)
	TB.card(m, 0, TB.WATER)
	var amb := TB.set_card(m, 0, AMBUSH, 0)
	assert_str(m.submit(0, {"t": "activate_set", "uid": amb})).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("slot")
	assert_str(CF.zone(m, amb)).is_equal("backrow")           # still resolving before anything lands
	TB.choose(m, ["Front row, column 1"])
	assert_str(TB.pend_kind(m)).is_equal("slot")              # the second unit's zone
	assert_str(CF.zone(m, amb)).is_equal("spent")


func test_a_summoning_trap_is_not_offered_to_the_summoned_units_on_summon() -> void:
	var m := TB.make()
	var defcon := TB.set_card(m, 1, DEFCON_2, 0)
	var sweeper := TB.card(m, 1, SWEEPER, "spent")
	var mine := TB.set_card(m, 0, TRAP_HOLE, 0)               # also in column 1
	TB.summon(m, 0, RADABLAST, 2)
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	assert_str(TB.choose(m, ["Activate Saviour"])).is_empty()
	assert_str(TB.choose_uids(m, [sweeper])).is_empty()
	if TB.pend_kind(m) == "slot":
		TB.choose(m, ["Front row, column 1"])
	assert_str(String(m.pending.get("prompt", ""))).contains("Reveal")
	assert_bool(defcon in CF.offered(m)).is_false()
	assert_bool(mine in CF.offered(m)).is_true()
	assert_str(CF.zone(m, defcon)).is_equal("spent")
