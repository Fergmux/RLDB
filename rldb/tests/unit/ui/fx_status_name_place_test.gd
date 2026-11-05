extends GdUnitTestSuite
## Final L-batch review (design/review-final-2026-11-05.md): a status application's floating name
## ("Burn", "Poison ×2") rose from above its card and, for a second, covered the ATK / DEF of the
## card in the row above. It now rises inside its own card, under the badge stamp.

const CARD_A := Vector2(400, 300)
const CARD_B := Vector2(485, 425)    # a field card at 1600x1000 (85 x 125)
const LABEL := Vector2(64, 24)


func test_name_starts_inside_its_own_card() -> void:
	var p := FxStatus.name_origin(CARD_A, CARD_B, LABEL)
	assert_float(p.y).is_greater_equal(CARD_A.y)
	assert_float(p.y + LABEL.y).is_less_equal(CARD_B.y)


func test_name_stays_inside_its_card_through_the_rise() -> void:
	var p := FxStatus.name_origin(CARD_A, CARD_B, LABEL)
	assert_float(p.y - FxStatus.NAME_RISE).is_greater_equal(CARD_A.y)


func test_name_sits_below_the_badge_stamp() -> void:
	# The stamp pops centred at STAMP_Y of the card's height; the name's centre is lower.
	var p := FxStatus.name_origin(CARD_A, CARD_B, LABEL)
	var stamp_y := CARD_A.y + (CARD_B.y - CARD_A.y) * FxStatus.STAMP_Y
	assert_float(p.y + LABEL.y / 2.0).is_greater(stamp_y)


func test_name_is_centred_across_the_card() -> void:
	var p := FxStatus.name_origin(CARD_A, CARD_B, LABEL)
	assert_float(p.x + LABEL.x / 2.0).is_equal_approx((CARD_A.x + CARD_B.x) / 2.0, 0.01)
