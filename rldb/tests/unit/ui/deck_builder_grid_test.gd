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


func test_unnamed_save_shows_inline_error_by_name_field() -> void:
	var db := _builder()
	db.add_card(int(CardDB.all()[0]["id"]))
	assert_bool(db.save()).is_false()
	assert_str(db.name_error()).contains("name")
	assert_bool(db._name_err.is_visible_in_tree()).is_true()
	assert_bool(db._status_panel.visible).is_false()
	db.deck_name_edit.text_changed.emit("x")
	assert_str(db.name_error()).is_equal("")


func test_deck_grid_tile_click_removes_one_and_counts_show() -> void:
	var db := _builder()
	var id := int(CardDB.all()[0]["id"])
	db.add_card(id, 2)
	var w := db.deck_widget(id)
	assert_object(w).is_not_null()
	w.pressed.emit(w)
	assert_int(int(db.counts[id])).is_equal(1)
	assert_object(db.deck_widget(id)).is_not_null()
	db.deck_widget(id).pressed.emit(db.deck_widget(id))
	assert_object(db.deck_widget(id)).is_null()


func test_main_and_extra_sections_and_catalogue_badge() -> void:
	var db := _builder()
	var extra := 0
	var main := 0
	for d in CardDB.all():
		if CardDB.is_extra_category(d["category"]) and extra == 0:
			extra = int(d["id"])
		elif not CardDB.is_extra_category(d["category"]) and main == 0:
			main = int(d["id"])
	db.add_card(main)
	db.add_card(extra, 3)
	assert_int(db._deck_box.get_child_count()).is_equal(4)
	assert_bool(db._cells[extra]["badge"].visible).is_true()
	assert_bool(db._cells[main]["remove"].visible).is_true()


func test_dominant_types_ranks_by_frequency() -> void:
	var water := -1
	var fire := -1
	for d in CardDB.all():
		if d["type"] == "Water" and water < 0:
			water = int(d["id"])
		if d["type"] == "Fire" and fire < 0:
			fire = int(d["id"])
	assert_array(DeckBuilder.dominant_types([fire, water, water])).is_equal(["Water", "Fire"])
