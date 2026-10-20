extends GdUnitTestSuite
## Owner feedback 2026-10-21, piles beside the unit zones:
## H4: the count medallion is centred on the top card (ignoring the name plate) and sits exactly in the
## ring of the card back. H18: an empty pile's count keeps the size and place of a full pile's.
## H15: the name sits on the face-down card's name plate, at the pile's foot.

## A pile the size the board draws (a Power zone: GameBoardView.POWER_W x UNIT_SIZE).
const PILE_SIZE := Vector2(80, 120)


func _pile(n: int) -> PileStack:
	UIStyle.reduce_motion = true
	var ps: PileStack = auto_free(PileStack.new())
	ps.size = PILE_SIZE
	ps.set_pile(n, false)
	return ps


func after() -> void:
	UIStyle.reduce_motion = false


## The ring CardBack.draw_art draws around its emblem for a back filling `card`.
static func _back_ring(card: Rect2) -> Dictionary:
	var inner := card.grow(-5.0 * card.size.x / PileStack.BACK_BASE_W)
	return {"c": card.get_center(), "r": minf(inner.size.x, inner.size.y) * 0.34 * 0.8}


func test_full_pile_count_sits_in_the_card_back_ring() -> void:
	var ps := _pile(12)
	var g := ps.medal_geometry()
	var ring := _back_ring(ps.top_rect())
	assert_vector(g["c"]).is_equal_approx(ring["c"], Vector2(0.01, 0.01))
	assert_float(g["r"]).is_equal_approx(ring["r"], 0.01)


func test_count_ignores_the_name_plate() -> void:
	var ps := _pile(5)
	var g := ps.medal_geometry()
	assert_float((g["c"] as Vector2).y).is_equal_approx(ps.top_rect().get_center().y, 0.01)
	assert_bool(ps.plate_rect().position.y > (g["c"] as Vector2).y + float(g["r"])).is_true()


func test_empty_pile_count_keeps_full_size_and_place() -> void:
	var empty := _pile(0)
	var one := _pile(1)   # a one-layer pile: its top card is the pile rect, as for an empty pile
	var full := _pile(18)
	assert_float(empty.medal_geometry()["r"]).is_equal_approx(full.medal_geometry()["r"], 0.001)
	assert_vector(empty.medal_geometry()["c"]).is_equal_approx(one.medal_geometry()["c"], Vector2(0.001, 0.001))


func test_name_plate_sits_at_the_pile_foot() -> void:
	for n in [0, 4, 30]:
		var ps := _pile(n)
		var top := ps.top_rect()
		var pr := ps.plate_rect()
		var inset := PileStack.PLATE_INSET * PileStack.back_scale(top.size.x)
		assert_float(pr.end.y).is_equal_approx(top.end.y - inset, 0.01)
		assert_float(pr.get_center().x).is_equal_approx(top.get_center().x, 0.01)
		assert_float(pr.size.y).is_equal_approx(PileStack.PLATE_H * PileStack.back_scale(top.size.x), 0.01)
