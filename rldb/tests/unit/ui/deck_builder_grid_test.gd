extends GdUnitTestSuite
## DeckBuilder (F03-24 grid, F15-F24 production pass): one cell per card, a catalogue click selects
## and adds a copy, a deck-tile click selects and removes one, preview Add / Remove, caps, canonical order, Delete visibility, Esc.
## Backs up and restores the player's saved decks.

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


func _first(extra: bool) -> int:
	for d in CardDB.all():
		if CardDB.is_extra_category(d["category"]) == extra:
			return int(d["id"])
	return -1


func _fill(id: int, n: int) -> Array:
	var a := []
	a.resize(n)
	a.fill(id)
	return a


func _contains_text(n: Node, needle: String) -> bool:
	if (n is Label and (n as Label).text.contains(needle)) or (n is Button and (n as Button).text.contains(needle)):
		return n.is_visible_in_tree()
	for c in n.get_children():
		if _contains_text(c, needle):
			return true
	return false


func test_grid_has_one_cell_per_catalogue_card() -> void:
	var db := _builder()
	assert_int(db.browser.grid.get_child_count()).is_equal(CardDB.all().size())
	assert_int(db.visible_cell_count()).is_equal(CardDB.all().size())
	db.set_filters("zzzz-no-such-card")
	assert_int(db.visible_cell_count()).is_equal(0)


func test_left_click_selects_exact_variant_and_adds_one() -> void:
	var db := _builder()
	var v := _variants()
	assert_int(v.size()).is_equal(2)
	var w := db.cell_widget(v[1])
	w.pressed.emit(w)
	assert_int(db.preview_id()).is_equal(v[1])
	assert_int(int(db.counts.get(v[1], 0))).is_equal(1)
	assert_int(int(db.counts.get(v[0], 0))).is_equal(0)
	w.pressed.emit(w)
	assert_int(int(db.counts.get(v[1], 0))).is_equal(2)
	assert_bool(db.dirty).is_true()


func test_selecting_without_click_does_not_edit() -> void:
	var db := _builder()
	var v := _variants()
	db.show_preview(v[0])
	db.browser.select(v[1])
	assert_int(db.preview_id()).is_equal(v[1])
	assert_bool(db.counts.is_empty()).is_true()
	assert_bool(db.dirty).is_false()


func test_preview_add_and_remove_edit_the_selected_card() -> void:
	var db := _builder()
	var v := _variants()
	db.show_preview(v[1])
	db.add_button().pressed.emit()
	db.add_button().pressed.emit()
	assert_int(int(db.counts.get(v[1], 0))).is_equal(2)
	assert_int(int(db.counts.get(v[0], 0))).is_equal(0)
	assert_str(db.cell_count_text(v[1])).is_equal("x2")
	db.remove_button().pressed.emit()
	assert_int(int(db.counts.get(v[1], 0))).is_equal(1)
	db.remove_button().pressed.emit()
	db.remove_button().pressed.emit()   # already zero: no negative count
	assert_bool(db.counts.has(v[1])).is_false()
	assert_bool(db.remove_button().disabled).is_true()
	assert_str(db.cell_count_text(v[1])).is_equal("")


func test_no_plus_minus_buttons_on_entries() -> void:
	var db := _builder()
	var id := _first(false)
	db.add_card(id, 2)
	for n in [db.browser.cell(id), db.deck_widget(id).get_parent()]:
		for c in n.find_children("*", "Button", true, false):
			assert_bool((c as Control).is_visible_in_tree()).is_false()


func test_quantity_tag_sits_below_the_card() -> void:
	var db := _builder()
	var id := _first(false)
	db.add_card(id, 3)
	await get_tree().process_frame
	await get_tree().process_frame
	var w := db.deck_widget(id)
	var tag := db.deck_tag(id)
	assert_str((tag.get_node("Text") as Label).text).is_equal("x3")
	assert_float(tag.get_global_rect().position.y).is_greater_equal(w.get_global_rect().end.y)
	var ctag: Control = db.browser.cell(id).get_meta("tag")
	assert_float(ctag.get_global_rect().position.y).is_greater_equal(db.cell_widget(id).get_global_rect().end.y)


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


func test_deck_tile_click_selects_and_removes_one() -> void:
	var db := _builder()
	var id := _first(false)
	var other := _first(true)
	db.show_preview(other)
	db.add_card(id, 3)
	var w := db.deck_widget(id)
	w.pressed.emit(w)
	assert_int(db.preview_id()).is_equal(id)
	assert_int(int(db.counts[id])).is_equal(2)
	w.pressed.emit(w)
	assert_int(int(db.counts[id])).is_equal(1)
	db.ui_remove()
	assert_object(db.deck_widget(id)).is_null()
	assert_int(db.preview_id()).is_equal(id)


func test_main_and_extra_sections_and_catalogue_mark() -> void:
	var db := _builder()
	var main := _first(false)
	var extra := _first(true)
	db.add_card(main)
	db.add_card(extra, 3)
	assert_bool(db._sections["main"]["box"].visible).is_true()
	assert_bool(db._sections["extra"]["box"].visible).is_true()
	assert_str((db._sections["extra"]["value"] as Label).text).is_equal("3")
	assert_bool(db.browser._cells[extra]["glow"].visible).is_true()
	assert_str(db.cell_count_text(extra)).is_equal("x3")


## F17: deck tiles follow canonical catalogue order, not insertion order, across edits and loads.
func test_deck_order_is_catalogue_order_regardless_of_insertion() -> void:
	var db := _builder()
	var mains := []
	for d in CardDB.all():
		if not CardDB.is_extra_category(d["category"]):
			mains.append(int(d["id"]))
		if mains.size() == 5:
			break
	for id in [mains[4], mains[1], mains[3], mains[0], mains[2]]:
		db.add_card(id)
	var flow: HFlowContainer = db._sections["main"]["flow"]
	var order := flow.get_children().map(func(t): return int(t.get_meta("card_id")))
	assert_array(order).is_equal(mains)
	db.remove_card(mains[2])
	db.add_card(mains[2])
	order = flow.get_children().map(func(t): return int(t.get_meta("card_id")))
	assert_array(order).is_equal(mains)
	db.set_filters("zzzz")   # filtering the catalogue never reorders the deck
	order = flow.get_children().map(func(t): return int(t.get_meta("card_id")))
	assert_array(order).is_equal(mains)


func test_catalogue_sorted_uses_index_not_id() -> void:
	assert_array(DeckBuilder.catalogue_sorted([5, 9, 2], {9: 0, 2: 1, 5: 2})).is_equal([9, 2, 5])
	assert_array(DeckBuilder.catalogue_sorted([7, 1], {1: 0})).is_equal([1, 7])


## F16: Add becomes unavailable at 99 combined or 15 Extra; nothing goes past the caps.
func test_caps_block_add_through_availability() -> void:
	var db := _builder()
	var main := _first(false)
	var extra := _first(true)
	assert_int(db.add_card(extra, 20)).is_equal(15)
	db.show_preview(extra)
	assert_bool(db.add_button().disabled).is_true()
	assert_bool(db.ui_add()).is_false()
	assert_int(int(db.counts[extra])).is_equal(15)
	assert_int(db.add_card(main, 100)).is_equal(84)
	db.show_preview(main)
	assert_bool(db.add_button().disabled).is_true()
	assert_int(DeckBuilder.counts_to_cards(db.counts).size()).is_equal(99)
	db.ui_remove()
	assert_bool(db.add_button().disabled).is_false()


## Existing oversized saves open intact, can shrink, and cannot be saved until legal.
func test_oversized_save_loads_intact_and_save_waits_until_legal() -> void:
	var db := _builder()
	var main := _first(false)
	DeckStore.save_deck("Legacy", _fill(main, 101))
	db.load_cards("Legacy", DeckStore.list()[0]["cards"])
	assert_int(int(db.counts[main])).is_equal(101)
	assert_bool(db.save()).is_false()
	assert_str(db.name_error()).contains("99")
	assert_int(DeckStore.list()[0]["cards"].size()).is_equal(101)
	db.remove_card(main)
	db.remove_card(main)
	assert_bool(db.save()).is_true()
	assert_int(DeckStore.list()[0]["cards"].size()).is_equal(99)


## F16: summary values sit in fixed-width slots (room for 99) so the pills never change width.
func test_summary_chip_width_is_stable() -> void:
	var db := _builder()
	await get_tree().process_frame
	var chip: Control = db._chip_vals["total"].get_parent().get_parent()
	var w0 := chip.get_combined_minimum_size().x
	db.add_card(_first(false), 9)
	var w1 := chip.get_combined_minimum_size().x
	db.add_card(_first(false), 50)
	var w2 := chip.get_combined_minimum_size().x
	assert_float(w1).is_equal(w0)
	assert_float(w2).is_equal(w0)


## F15: no catalogue count and no "Click to..." instructions.
func test_no_count_or_instruction_clutter() -> void:
	var db := _builder()
	assert_bool(_contains_text(db, "of %d cards" % CardDB.all().size())).is_false()
	assert_bool(_contains_text(db, "click a card")).is_false()
	assert_bool(_contains_text(db, "Click to")).is_false()


## F20: tab labels carry no counts.
func test_deck_tabs_have_no_counts() -> void:
	var db := _builder()
	DeckStore.save_deck("One", [1])
	db._refresh_saved()
	assert_str(db._tab_saved.text).is_equal("Saved Decks")
	assert_str(db._tab_starters.text).is_equal("Starter Decks")


## F23: Delete only while an actual saved deck is loaded.
func test_delete_visible_only_for_loaded_saved_deck() -> void:
	var db := _builder()
	assert_bool(db.delete_button().visible).is_false()
	db.add_card(_first(false))
	assert_bool(db.delete_button().visible).is_false()
	db.deck_name_edit.text = "Mine"
	db.save()
	assert_bool(db.delete_button().visible).is_true()
	db.new_deck()
	assert_bool(db.delete_button().visible).is_false()
	db._load_named("Mine")
	assert_bool(db.delete_button().visible).is_true()
	db._copy_starter_cards("Starter", [1, 2])
	assert_bool(db.delete_button().visible).is_false()


func _esc() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	return e


## F21: Esc = Back (with the unsaved question); with an inspector open it only closes that.
func test_escape_runs_back_flow_and_respects_inspector() -> void:
	var db := _builder()
	var closed := [0]
	db.closed.connect(func(): closed[0] += 1)
	var id := _first(false)
	db.inspect_card(id)
	db._input(_esc())
	assert_int(closed[0]).is_equal(0)
	CardInspector.close_all()
	db.add_card(id)   # unsaved edits: Esc asks first
	db._input(_esc())
	assert_int(closed[0]).is_equal(0)
	assert_bool(db._modal_open()).is_true()
	db._input(_esc())   # Esc again cancels the question
	await get_tree().process_frame
	assert_bool(db._modal_open()).is_false()
	assert_int(closed[0]).is_equal(0)
	db.dirty = false
	db._input(_esc())
	db._input(_esc())   # never navigates twice
	assert_int(closed[0]).is_equal(1)


## F24: rapid UI edits land in the data immediately, one per click, never negative.
func test_rapid_ui_edits_are_exact() -> void:
	var db := _builder()
	var id := _first(false)
	db.show_preview(id)
	for i in 12:
		db.ui_add()
	assert_int(int(db.counts[id])).is_equal(12)
	for i in 20:
		db.ui_remove()
	assert_bool(db.counts.has(id)).is_false()
	assert_object(db.deck_widget(id)).is_null()


func test_dominant_types_ranks_by_frequency() -> void:
	var water := -1
	var fire := -1
	for d in CardDB.all():
		if d["type"] == "Water" and water < 0:
			water = int(d["id"])
		if d["type"] == "Fire" and fire < 0:
			fire = int(d["id"])
	assert_array(DeckBuilder.dominant_types([fire, water, water])).is_equal(["Water", "Fire"])


## F19: deck-construction stats show one prominent value per stat, no Base / Current split;
## a dynamic stat reads "?"; live-match panels keep the Base line.
func test_construction_stats_have_no_base_split() -> void:
	var db := _builder()
	var dyn := -1
	var plain := -1
	for d in CardDB.all():
		if d["race"] != null and d["atk"] == null and dyn < 0:
			dyn = int(d["id"])
		if d["race"] != null and d["atk"] != null and plain < 0:
			plain = int(d["id"])
	db.show_preview(plain)
	assert_int(db._details.count_text("Base:")).is_equal(0)
	assert_bool(db._details.all_text().contains(str(CardDB.get_def(plain)["atk"]))).is_true()
	db.show_preview(dyn)
	assert_int(db._details.count_text("Base:")).is_equal(0)
	assert_int(db._details.count_text("?")).is_greater(0)
	var live: CardDetailsPanel = auto_free(CardDetailsPanel.new())
	live.show_card(MatchView.summary_view(Series.card_summary(plain)))
	assert_int(live.count_text("Base:")).is_equal(2)
