extends GdUnitTestSuite
## F03-07: Power slot display mapping between perspectives (180 degree rotation for the opponent's block).

const B := GameBoardView


func test_own_view_is_row_major() -> void:
	assert_that(B.power_cell(1, 0)).is_equal(Vector2i(0, 0))
	assert_that(B.power_cell(1, 1)).is_equal(Vector2i(1, 0))
	assert_that(B.power_cell(1, 2)).is_equal(Vector2i(0, 1))
	assert_that(B.power_cell(1, 3)).is_equal(Vector2i(1, 1))


func test_opponent_view_mirrors_both_axes() -> void:
	# owner top-left -> bottom-right, top-right -> bottom-left, bottom-left -> top-right, bottom-right -> top-left
	assert_that(B.power_cell(0, 0)).is_equal(Vector2i(1, 1))
	assert_that(B.power_cell(0, 1)).is_equal(Vector2i(0, 1))
	assert_that(B.power_cell(0, 2)).is_equal(Vector2i(1, 0))
	assert_that(B.power_cell(0, 3)).is_equal(Vector2i(0, 0))


func test_every_slot_maps_to_a_distinct_cell_per_side() -> void:
	for side in 2:
		var seen := {}
		for s in 4:
			seen[B.power_cell(side, s)] = true
		assert_int(seen.size()).is_equal(4)
