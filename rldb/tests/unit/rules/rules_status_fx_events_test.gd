extends GdUnitTestSuite
## L batch final QA (design/qa-final-2026-11-05.md): every way a status leaves or grows on a Field card
## has its L8 presentation event, so the badge the player watches never vanishes or jumps silently.
##   - Cleanse / Curse clearing the opposite class: "status_expire" for each status cleared, and for the
##     Cleanse / Curse stack that paid for it;
##   - a Cleanse / Curse stack used up by a prevention: "status_expire" after the ward flash;
##   - Burn paid out after an attack: "status_tick" then "status_expire";
##   - debuffs doubled in place (Mimic, Necro): a "status" event with the stacks added.

const FIRE_ATTACKER := TB.FIRE


func _fx(m: MatchEngine, from_entry: int) -> Array:
	var out := []
	for i in range(from_entry, m.log_entries.size()):
		for e in m.log_entries[i]["fx"]:
			if String(e.get("k", "")).begins_with("status"):
				out.append([String(e["k"]), String(e.get("s", "")), int(e.get("n", 0))])
	return out


func test_cleanse_clearing_debuffs_emits_an_expire_for_each_and_for_the_used_cleanse() -> void:
	# Arrange
	var m := TB.make()
	var u := TB.unit(m, 0, TB.FILLER, 1)
	m.apply_status(u, "poison", 2)
	m.apply_status(u, "burn", 4)
	var at := m.log_entries.size()
	# Act
	m.apply_status(u, "cleanse", 1)
	# Assert
	var got := _fx(m, at)
	assert_array(got).contains_exactly([["status", "cleanse", 1], ["status_expire", "poison", 0],
		["status_expire", "burn", 0], ["status_expire", "cleanse", 0]])
	assert_int(m.status_count(u, "cleanse")).is_equal(0)


func test_curse_clearing_buffs_emits_expires() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.FILLER, 1)
	m.apply_status(u, "eternal", 1)
	var at := m.log_entries.size()
	m.apply_status(u, "curse", 2)
	assert_array(_fx(m, at)).contains_exactly([["status", "curse", 2], ["status_expire", "eternal", 0]])
	assert_int(m.status_count(u, "curse")).is_equal(1)


func test_a_ward_used_up_by_a_prevention_expires_after_its_flash() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.FILLER, 1)
	m.apply_status(u, "cleanse", 1)
	var at := m.log_entries.size()
	m.apply_status(u, "poison", 3)
	assert_array(_fx(m, at)).contains_exactly([["status_blocked", "poison", 3], ["status_expire", "cleanse", 0]])


func test_a_ward_with_stacks_left_does_not_expire() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.FILLER, 1)
	m.apply_status(u, "cleanse", 2)
	var at := m.log_entries.size()
	m.apply_status(u, "poison", 3)
	assert_array(_fx(m, at)).contains_exactly([["status_blocked", "poison", 3]])


func test_burn_after_an_attack_ticks_then_expires() -> void:
	var m := TB.make()
	var a := TB.unit(m, 1, FIRE_ATTACKER, 0)
	TB.p1_battle(m)
	m.apply_status(a, "burn", 4)
	var at := m.log_entries.size()
	TB.attack(m, a, -1)
	var got := _fx(m, at).filter(func(x): return x[1] == "burn")
	assert_array(got).contains_exactly([["status_tick", "burn", 4], ["status_expire", "burn", 0]])


func test_doubled_debuffs_show_the_stacks_added() -> void:
	var m := TB.make()
	var u := TB.unit(m, 1, TB.FILLER, 1)
	m.apply_status(u, "poison", 3)
	var at := m.log_entries.size()
	var f := m.make_frame(-1, 0, [], "test")
	m._op_double_debuffs(f, {"side": "any"})
	assert_int(m.status_count(u, "poison")).is_equal(6)
	assert_array(_fx(m, at)).contains_exactly([["status", "poison", 3]])
