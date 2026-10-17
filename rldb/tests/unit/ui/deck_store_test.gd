extends GdUnitTestSuite
## DeckStore persistence and the DeckBuilder pure helpers (filtering, counts).

var _backup: String = ""
var _had_file: bool = false


func before_test() -> void:
	_had_file = FileAccess.file_exists(DeckStore.PATH)
	_backup = FileAccess.get_file_as_string(DeckStore.PATH) if _had_file else ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DeckStore.PATH))


func after_test() -> void:
	if _had_file:
		var f := FileAccess.open(DeckStore.PATH, FileAccess.WRITE)
		f.store_string(_backup)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DeckStore.PATH))


func _extra_id() -> int:
	for d in CardDB.all():
		if CardDB.is_extra_category(d["category"]):
			return int(d["id"])
	return -1


func test_round_trip_save_list_replace_delete() -> void:
	assert_array(DeckStore.list()).is_empty()
	DeckStore.save_deck("A", [1, 1, 2])
	DeckStore.save_deck("B", [3])
	assert_int(DeckStore.list().size()).is_equal(2)
	DeckStore.save_deck("A", [5])
	var a: Dictionary = DeckStore.list().filter(func(e): return e["name"] == "A")[0]
	assert_array(a["cards"]).is_equal([5])
	DeckStore.delete_deck("A")
	assert_int(DeckStore.list().size()).is_equal(1)
	assert_str(DeckStore.list()[0]["name"]).is_equal("B")


func test_split_counts_routes_extra_deck_cards() -> void:
	var e := _extra_id()
	assert_int(e).is_not_equal(-1)
	var c := DeckStore.split_counts([1, 1, e])
	assert_int(c["main"]).is_equal(2)
	assert_int(c["extra"]).is_equal(1)


func test_counts_round_trip() -> void:
	var cards := [3, 1, 3, 3, 2]
	var counts := DeckBuilder.cards_to_counts(cards)
	assert_int(counts[3]).is_equal(3)
	assert_array(DeckBuilder.counts_to_cards(counts)).is_equal([1, 2, 3, 3, 3])


func test_filters() -> void:
	var total := CardDB.all().size()
	var any := 0
	var fusion := 0
	var dragon_text := 0
	for d in CardDB.all():
		if DeckBuilder.matches(d, "", "", "", "", ""):
			any += 1
		if DeckBuilder.matches(d, "", "", "", "", "kind:fusion"):
			fusion += 1
			assert_str(d["category"]).is_equal("fusion")
		if DeckBuilder.matches(d, "DRAGON", "", "", "", ""):
			dragon_text += 1
		if DeckBuilder.matches(d, "", "", "", "Dragon", ""):
			assert_str(d["race"]).is_equal("Dragon")
	assert_int(any).is_equal(total)
	assert_int(fusion).is_greater(0)
	assert_int(dragon_text).is_greater(0)
	assert_int(dragon_text).is_less(total)


func _main_id() -> int:
	for d in CardDB.all():
		if not CardDB.is_extra_category(d["category"]):
			return int(d["id"])
	return -1


func _fill(id: int, n: int) -> Array:
	var a := []
	a.resize(n)
	a.fill(id)
	return a


## F16 / owner answers section 1: combined Main + Extra at most 99, Extra at most 15 within it.
func test_validate_caps_combined_and_extra() -> void:
	var m := _main_id()
	var e := _extra_id()
	assert_str(DeckStore.validate(_fill(m, 84) + _fill(e, 15))).is_empty()
	assert_str(DeckStore.validate(_fill(m, 85) + _fill(e, 15))).contains("99")
	assert_str(DeckStore.validate(_fill(m, 100))).contains("99")
	assert_str(DeckStore.validate(_fill(m, 10) + _fill(e, 16))).contains("15")
	assert_str(DeckStore.validate([])).is_empty()


func test_add_block_reason_boundaries() -> void:
	var m := _main_id()
	var e := _extra_id()
	assert_str(DeckStore.add_block_reason(98, 0, m)).is_empty()
	assert_str(DeckStore.add_block_reason(99, 0, m)).is_not_empty()
	assert_str(DeckStore.add_block_reason(84, 15, m)).is_not_empty()
	assert_str(DeckStore.add_block_reason(83, 15, m)).is_empty()
	assert_str(DeckStore.add_block_reason(10, 14, e)).is_empty()
	assert_str(DeckStore.add_block_reason(10, 15, e)).is_not_empty()


## Oversized saves from before the cap are listed intact, never trimmed.
func test_oversized_save_lists_intact() -> void:
	DeckStore.save_deck("Legacy", _fill(_main_id(), 120))
	assert_int(DeckStore.list()[0]["cards"].size()).is_equal(120)


func test_series_start_rejects_over_cap_custom_deck() -> void:
	var m := _main_id()
	var e := _extra_id()
	var s := Series.new()
	s.setup({"seed": 3})
	assert_str(s.submit(0, {"t": "custom_deck", "cards": _fill(m, 100)})).contains("99")
	assert_str(s.submit(0, {"t": "custom_deck", "cards": _fill(m, 5) + _fill(e, 16)})).contains("15")
	assert_bool(s.deck_ready[0]).is_false()
	assert_str(s.submit(0, {"t": "custom_deck", "cards": _fill(m, 84) + _fill(e, 15)})).is_empty()
	assert_bool(s.deck_ready[0]).is_true()


func test_automated_runs_never_use_the_players_deck_file() -> void:
	assert_str(DeckStore.PATH).is_equal(DeckStore.TEST_PATH)
	assert_str(DeckStore.PATH).is_not_equal(DeckStore.PLAYER_PATH)
