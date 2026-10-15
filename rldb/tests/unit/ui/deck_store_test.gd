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
