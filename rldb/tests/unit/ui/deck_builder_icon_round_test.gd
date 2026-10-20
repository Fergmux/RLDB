extends GdUnitTestSuite
## J1 (owner, 22 Oct: "on the saved decks list, edit/delete icons are not round, they should be"):
## the deck builder's saved-deck rows give their pencil (rename) and cross (delete) buttons a
## square box, so the fully rounded stylebox draws a circle. The row's HBoxContainer used to
## stretch them to the row height (28 x 36 px), which drew a pill.

const DECKS := ["J1 Round A", "J1 Round B"]


func before_test() -> void:
	assert_str(DeckStore.PATH).is_equal(DeckStore.TEST_PATH)   # never the player's decks
	for n in DECKS:
		DeckStore.save_deck(n, _cards())


func after_test() -> void:
	for n in DECKS:
		DeckStore.delete_deck(n)


func _cards() -> Array:
	var out := []
	for d in CardDB.all():
		if d["category"] == "unit" and out.size() < 6:
			out.append(int(d["id"]))
	return out


func _builder() -> DeckBuilder:
	var host := Control.new()
	host.size = Vector2(1600, 1000)
	add_child(host)
	auto_free(host)
	var db := DeckBuilder.new()
	host.add_child(db)
	return db


func _icon_buttons(db: DeckBuilder) -> Array:
	var out := []
	for c in db.find_children("*", "Button", true, false):
		if c is DeckBuilder.IconBtn:
			out.append(c)
	return out


func test_saved_deck_icons_are_square_so_they_draw_round() -> void:
	var db := _builder()
	for i in 4:
		await get_tree().process_frame
	var btns := _icon_buttons(db)
	assert_int(btns.size()).is_greater_equal(DECKS.size() * 2)
	for b in btns:
		var bb := b as Control
		assert_float(bb.size.x).is_equal_approx(bb.size.y, 0.5)
		# The disc is drawn as a circle filling the box; no rectangular stylebox shows behind it.
		assert_float((b as DeckBuilder.IconBtn).disc_radius()).is_equal_approx(bb.size.x / 2.0, 0.01)
		assert_bool(bb.get_theme_stylebox("normal") is StyleBoxEmpty).is_true()
		assert_bool(bb.get_theme_stylebox("hover") is StyleBoxEmpty).is_true()


func test_icon_button_stays_square_in_a_taller_row() -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(200, 60)
	add_child(row)
	auto_free(row)
	var b := DeckBuilder._icon_btn("cross", 28, "Delete", true)
	row.add_child(b)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_vector(b.size).is_equal(Vector2(28, 28))
	# Centred in the row, not pinned to its top.
	assert_float(b.position.y).is_equal_approx((row.size.y - 28.0) / 2.0, 0.5)
