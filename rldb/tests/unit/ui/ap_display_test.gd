extends GdUnitTestSuite
## F02-06: AP slot capacity / filled / spent policy of the plate's AP gems (ApGemRow, WP-3).
## Intent change (H1 WP-3, design review #21): before the first turn the row shows two idle, dark
## sockets with "AP 0/2" instead of no sockets and "AP 0".

const G := preload("res://src/ui/board/ap_gems.gd")


func _case(ap: int, start: int, peak: int, cap: int, filled: int, spent: int) -> void:
	assert_int(G.capacity_for(ap, start, peak)).is_equal(cap)
	assert_int(G.filled_for(ap, start, peak)).is_equal(filled)
	assert_int(G.spent_for(ap, start, peak)).is_equal(spent)


func test_ordinary_two_ap_turn_shows_exactly_two_slots() -> void:
	_case(2, 2, 2, 2, 2, 0)


func test_spending_keeps_spent_slots_visible() -> void:
	_case(1, 2, 2, 2, 1, 1)
	_case(0, 2, 2, 2, 0, 2)


func test_three_ap_allowance() -> void:
	_case(3, 3, 3, 3, 3, 0)
	_case(1, 3, 3, 3, 1, 2)


func test_gained_above_allowance_expands_slots() -> void:
	_case(3, 2, 4, 4, 3, 1)
	_case(5, 2, 5, 5, 5, 0)


func test_before_first_turn_shows_two_idle_sockets() -> void:
	_case(0, 0, 0, 0, 0, 0)
	assert_int(G.slots_for(0, 0, 0)).is_equal(G.IDLE_SLOTS)
	var g: ApGemRow = auto_free(G.new())
	assert_int(g.slots()).is_equal(2)
	assert_str(g.ap_text()).is_equal("AP 0/2")


func test_large_capacity_is_not_capped() -> void:
	_case(14, 2, 14, 14, 14, 0)
	_case(0, 2, 25, 25, 0, 25)


func test_text_shows_current_over_capacity() -> void:
	var g: ApGemRow = auto_free(G.new())
	g.ap = 1
	g.ap_start = 2
	g.ap_peak = 2
	assert_str(g.ap_text()).is_equal("AP 1/2")


func _pv(ap: int, extra: Dictionary = {}) -> Dictionary:
	var pv := {"name": "P", "hp": 60, "ap": ap, "counts": {"hand": 0, "draw": 0, "spent": 0, "exhaust": 0, "extra": 0}}
	pv.merge(extra)
	return pv


func test_plate_reads_new_fields_with_fallback() -> void:
	var plate: PlayerPlate = auto_free(PlayerPlate.new())
	plate.update_from(_pv(3, {"ap_start": 2, "ap_peak": 4}), true, true, "", "")
	assert_int(plate.ap_gems.capacity()).is_equal(4)
	assert_int(plate.ap_gems.filled()).is_equal(3)
	# Older views without ap_start / ap_peak fall back to the current AP.
	plate.update_from(_pv(2), true, true, "", "")
	assert_int(plate.ap_gems.capacity()).is_equal(2)
	plate.update_from(_pv(0), false, true, "", "")
	assert_int(plate.ap_gems.capacity()).is_equal(0)
	assert_int(plate.ap_gems.slots()).is_equal(G.IDLE_SLOTS)   # the idle sockets, never an empty row
