extends GdUnitTestSuite
## H25 (owner, 21 Oct: "I don't want to have to scroll that middle pane ever"): the deck builder's
## card details pane fits every card in data/cards.json without scrolling at the smallest supported
## window, 1280x800. The project stretches canvas_items with "expand" from a 1600x1000 base, so a
## 1280x800 window lays out at 1600x1000 (scale 0.8): the builder runs in a host of that layout size.
## Also checks the rules are split by timing (one block per effect) as in the match details panel.

const LAYOUT_1280X800 := Vector2(1600, 1000)


func _builder(host_size: Vector2) -> DeckBuilder:
	var host := Control.new()
	host.size = host_size
	add_child(host)
	auto_free(host)
	var db := DeckBuilder.new()
	host.add_child(db)
	return db


func _settle() -> void:
	for i in 3:
		await get_tree().process_frame


func test_details_pane_fits_every_card_without_scrolling_at_1280x800() -> void:
	var db := _builder(LAYOUT_1280X800)
	await _settle()
	assert_array(db._pane.find_children("*", "ScrollContainer", true, false)).is_empty()
	var misfits := []
	for d in CardDB.all():
		var id := int(d["id"])
		db.show_preview(id)
		await _settle()
		var f := db.preview_fit()
		assert_float(float(f["room"])).is_greater(0.0)
		if float(f["need"]) > float(f["room"]) or float(f["used"]) > float(f["room"]) + 0.5:
			misfits.append("%d %s: need %d, used %d, room %d" % [id, d["name"], f["need"], f["used"], f["room"]])
	assert_array(misfits).is_empty()


## The worst cases again with copies in the deck: a Fusion with materials and the longest unit,
## with the gem row holding many copies (the gems wrap inside a fixed height).
func test_long_cards_with_many_copies_still_fit() -> void:
	var db := _builder(LAYOUT_1280X800)
	await _settle()
	var longest := -1
	var longest_len := -1
	var fusion := -1
	for d in CardDB.all():
		var n := MatchView._rules_text(d).length()
		if n > longest_len:
			longest_len = n
			longest = int(d["id"])
		if d["category"] == "fusion" and String(d["condition"]) != "" and fusion < 0:
			fusion = int(d["id"])
	for id in [longest, fusion]:
		db.add_card(id, DeckStore.MAX_EXTRA if DeckStore.is_extra(id) else 40)
		db.show_preview(id)
		await _settle()
		var f := db.preview_fit()
		assert_float(float(f["used"])).is_less_equal(float(f["room"]) + 0.5)


## The pane draws one rule block per timing part, with its heading, like the match panel.
func test_rules_are_split_into_timing_sections() -> void:
	var db := _builder(LAYOUT_1280X800)
	await _settle()
	var id := -1
	for d in CardDB.all():
		if d["category"] == "fusion" and String(d["condition"]) != "" and String(d["on_summon"]) != "":
			id = int(d["id"])
			break
	db.show_preview(id)
	var text := db._details.all_text()
	assert_bool(text.contains("MATERIALS")).is_true()
	assert_bool(text.contains("ON SUMMON")).is_true()
	var parts := MatchView.rules_parts(CardDB.get_def(id))
	assert_int(db.details_view(id)["text_parts"].size()).is_equal(parts.size())
	# The body no longer repeats "Materials:" inline (it is the block's heading).
	assert_bool(text.contains("Materials:")).is_false()
