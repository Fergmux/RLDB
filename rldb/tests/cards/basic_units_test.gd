extends GdUnitTestSuite
## F26 -- Basic Units (35 ids). Their semantics are genuinely shared (1 AP, 8/8, no
## effect), so each test runs over every Basic Unit id and asserts that id's own Race/Type.
## Type advantage uses CardDB.TYPE_ADVANTAGE so each Type is checked against its own victim.

const ALL_BASICS := "1,2,3,4,5,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134"


func test_basic_unit_ids_are_the_35_known_cards() -> void:
	var expected := Array(ALL_BASICS.split(",")).map(func(s): return int(s))
	expected.sort()
	assert_array(CF.basic_ids()).is_equal(expected)


# @cards 1,2,3,4,5,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134
func test_basic_units_summon_for_one_ap_as_8_8_with_their_race_and_type() -> void:
	var bad := []
	for id in CF.basic_ids():
		var m := CF.make()
		var d := CardDB.get_def(id)
		var u := TB.summon(m, 0, id, 0)
		if CF.ap(m, 0) != 19: bad.append("%d ap %d" % [id, CF.ap(m, 0)])
		if CF.zone(m, u) != "unit": bad.append("%d zone %s" % [id, CF.zone(m, u)])
		if m.atk_of(u) != 8 or m.def_of(u) != 8: bad.append("%d stats %d/%d" % [id, m.atk_of(u), m.def_of(u)])
		if m.unit_race(u) != d["race"] or m.unit_type(u) != d["type"]: bad.append("%d race/type %s/%s" % [id, m.unit_race(u), m.unit_type(u)])
		if not m.pending.is_empty(): bad.append("%d left a prompt %s" % [id, CF.labels(m)])
	assert_array(bad).is_empty()


# @cards 1,2,3,4,5,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134
func test_basic_units_have_no_ability_and_no_destruction_effect() -> void:
	var bad := []
	for id in CF.basic_ids():
		var m := CF.make()
		var u := TB.unit(m, 0, id, 0)
		var hp_before := [CF.hp(m, 0), CF.hp(m, 1)]
		if TB.ability(m, u) == "": bad.append("%d accepted an ability" % id)
		TB.kill(m, u)
		if CF.zone(m, u) != "spent": bad.append("%d went to %s" % [id, CF.zone(m, u)])
		if not m.pending.is_empty(): bad.append("%d destruction prompted" % id)
		if [CF.hp(m, 0), CF.hp(m, 1)] != hp_before: bad.append("%d changed HP" % id)
	assert_array(bad).is_empty()


# @cards 1,2,3,4,5,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134
func test_basic_units_win_battle_only_against_the_type_they_beat() -> void:
	var bad := []
	for id in CF.basic_ids():
		var t: String = CardDB.get_def(id)["type"]
		var victim_type: String = CardDB.TYPE_ADVANTAGE.get(t, "")
		var victim := -1
		for v in CF.basic_ids():
			if CardDB.get_def(v)["type"] == victim_type:
				victim = v
				break
		if victim == -1:
			bad.append("%d has no advantage victim" % id)
			continue
		# Advantaged attacker: 8 + 6 beats 8.
		var m := CF.p1_battle()
		var a := TB.unit(m, 1, id, 0)
		var dfd := TB.unit(m, 0, victim, 0)
		var e := TB.attack(m, a, dfd)
		if e != "": bad.append("%d attack: %s" % [id, e])
		if CF.zone(m, dfd) != "spent" or CF.zone(m, a) != "unit": bad.append("%d vs %d: %s/%s" % [id, victim, CF.zone(m, a), CF.zone(m, dfd)])
		# Reversed: the victim Type attacking this Type loses its attacker.
		var m2 := CF.p1_battle()
		var a2 := TB.unit(m2, 1, victim, 0)
		var d2 := TB.unit(m2, 0, id, 0)
		TB.attack(m2, a2, d2)
		if CF.zone(m2, a2) != "spent" or CF.zone(m2, d2) != "unit": bad.append("%d attacked by %d: %s/%s" % [id, victim, CF.zone(m2, a2), CF.zone(m2, d2)])
	assert_array(bad).is_empty()
