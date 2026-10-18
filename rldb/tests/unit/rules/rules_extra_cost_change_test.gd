extends GdUnitTestSuite
## Owner rule 2026-10-18: a card that raises another card's cost (Shimmer Serum: "permanently
## costs +1") raises a Ritual unit's Rune cost and an Arcane unit's exact Spent total as well.

const CREEPING_NULL := 65          # Ritual unit, 3 Runes
const BASIC_BEAST := 4


func _arcane_id() -> int:
	CardDB.ensure_loaded()
	for d in CardDB.all():
		if d["cost_kind"] == "arcane" and d["cost"] != null:
			return int(d["id"])
	return -1


func test_a_permanent_cost_increase_raises_the_rune_cost() -> void:
	var m := TB.make()
	var null_u := TB.card(m, 0, CREEPING_NULL, "extra")
	var mat := TB.unit(m, 0, BASIC_BEAST, 0)
	m.apply_status(mat, "rune", 3)
	assert_str(m.validate(0, {"t": "ritual", "uid": null_u})).is_empty()
	m.change_cost_perm(null_u, 1)
	assert_int(int(m.extra_cost(null_u))).is_equal(4)
	assert_str(m.cost_text(null_u)).is_equal("4 Rune")
	assert_str(m.validate(0, {"t": "ritual", "uid": null_u})).is_not_empty()
	m.apply_status(mat, "rune", 1)
	assert_str(m.validate(0, {"t": "ritual", "uid": null_u})).is_empty()


func test_a_permanent_cost_increase_raises_the_arcane_total() -> void:
	var id := _arcane_id()
	assert_int(id).is_not_equal(-1)
	var m := TB.make()
	var a := TB.card(m, 0, id, "extra")
	var printed := int(CardDB.get_def(id)["cost"])
	m.change_cost_perm(a, 1)
	assert_int(int(m.extra_cost(a))).is_equal(printed + 1)
	assert_str(m.cost_text(a)).is_equal("%d Arcane" % (printed + 1))
	var v := MatchView.card_view(m, a, 0)
	assert_int(int(v["cost"])).is_equal(printed + 1)
	assert_int(int(v["printed_cost"])).is_equal(printed)
