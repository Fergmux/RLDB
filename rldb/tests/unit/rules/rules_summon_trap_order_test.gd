extends GdUnitTestSuite
## Owner feedback 2026-10-18: Traps answering a summon resolve after the summoned unit's own On
## Summon effects, both the summon Traps (Trap Hole) and the effect-activation ones (Energy Dispel).

const CHIDORI_MONK := 24           # On Summon: this unit gains 1 Infiltrate
const TRAP_HOLE := 49
const ENERGY_DISPEL := 140


func _summon_into(trap_id: int) -> Dictionary:
	var m := TB.make()
	TB.to_turn2(m)
	TB.set_card(m, 0, trap_id, 0)
	var u := TB.card(m, 1, CHIDORI_MONK)
	m.players[1]["ap"] = 5
	assert_str(m.submit(1, {"t": "summon", "uid": u, "stance": "atk"})).is_empty()
	TB.choose(m, ["Front row, column 1"])
	return {"m": m, "u": u}


func test_trap_hole_is_offered_after_the_on_summon_effect() -> void:
	var r := _summon_into(TRAP_HOLE)
	var m: MatchEngine = r["m"]
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	assert_int(m.status_count(r["u"], "infiltrate")).is_equal(1)


func test_energy_dispel_answers_the_on_summon_effect_after_it_resolves() -> void:
	var r := _summon_into(ENERGY_DISPEL)
	var m: MatchEngine = r["m"]
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	assert_str(String(m.pending["prompt"])).contains("Chidori Monk's effect")
	assert_int(m.status_count(r["u"], "infiltrate")).is_equal(1)
	TB.choose(m, ["Activate Energy Dispel"])
	assert_str(m.cards[r["u"]]["zone"]).is_not_equal("unit")
