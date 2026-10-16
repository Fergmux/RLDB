extends GdUnitTestSuite
## DeckBuilder card grid (F03-24): one cell per card, click adds the exact id, right-click inspects,
## save/load/rename round trip. Backs up and restores the player's saved decks.

var _backup: String = ""
var _had_file: bool = false


func before_test() -> void:
	_had_file = FileAccess.file_exists(DeckStore.PATH)
	_backup = FileAccess.get_file_as_string(DeckStore.PATH) if _had_file else ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DeckStore.PATH))


func after_test() -> void:
	CardInspector.close_all()
	if _had_file:
		var f := FileAccess.open(DeckStore.PATH, FileAccess.WRITE)
		f.store_string(_backup)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DeckStore.PATH))


func _builder() -> DeckBuilder:
	var db := DeckBuilder.new()
	add_child(db)
	auto_free(db)
	return db


## Two catalogue cards with the same name stem (e.g. Basic Mage Water / Heavenly) but different Types.
func _variants() -> Array:
	var seen := {}
	for d in CardDB.all():
		if d["category"] != "basic_unit":
			continue
		var stem := String(d["name"]).split(" (")[0]
		if seen.has(stem):
			return [seen[stem], int(d["id"])]
		seen[stem] = int(d["id"])
	return []


func test_grid_has_one_cell_per_catalogue_card() -> void:
	var db := _builder()
	assert_int(db._grid.get_child_count()).is_equal(CardDB.all().size())
	assert_int(db.visible_cell_count()).is_equal(CardDB.all().size())
	db.set_filters("zzzz-no-such-card")
	assert_int(db.visible_cell_count()).is_equal(0)


func test_left_click_adds_exact_id_for_same_name_variants() -> void:
	var db := _builder()
	var v := _variants()
	assert_int(v.size()).is_equal(2)
	var w := db.cell_widget(v[1])
	w.pressed.emit(w)
	assert_int(db.counts.size()).is_equal(1)
	assert_int(int(db.counts.get(v[1], 0))).is_equal(1)
	assert_int(int(db.counts.get(v[0], 0))).is_equal(0)


func test_right_click_inspects_without_changing_deck() -> void:
	var db := _builder()
	var id := int(CardDB.all()[0]["id"])
	var w := db.cell_widget(id)
	w.right_pressed.emit(w)
	assert_int(CardInspector.open_count()).is_equal(1)
	assert_bool(db.counts.is_empty()).is_true()
	assert_bool(db.dirty).is_false()


func test_save_load_rename_round_trip() -> void:
	var db := _builder()
	var v := _variants()
	db.add_card(v[0], 2)
	db.add_card(v[1])
	db.deck_name_edit.text = "Grid Deck"
	assert_bool(db.save()).is_true()
	db.new_deck()
	assert_bool(db.counts.is_empty()).is_true()
	var saved: Dictionary = DeckStore.list()[0]
	db.load_cards(saved["name"], saved["cards"])
	assert_int(int(db.counts.get(v[0], 0))).is_equal(2)
	assert_int(int(db.counts.get(v[1], 0))).is_equal(1)
	db.deck_name_edit.text = "Renamed Deck"
	assert_bool(db.rename_loaded()).is_true()
	assert_int(DeckStore.list().size()).is_equal(1)
	assert_str(DeckStore.list()[0]["name"]).is_equal("Renamed Deck")
	assert_int(DeckStore.list()[0]["cards"].size()).is_equal(3)
