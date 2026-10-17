extends GdUnitTestSuite
## Card catalogue screen (F14) and the shared CardBrowser: search, filters, sort, selection
## preview, inspection, no-results state, keyboard navigation and Esc = Back.


func after_test() -> void:
	CardInspector.close_all()


func _screen() -> CardListScreen:
	var s := CardListScreen.new()
	add_child(s)
	auto_free(s)
	return s


func test_opens_with_every_card_and_first_selected() -> void:
	var s := _screen()
	assert_int(s.browser.visible_count()).is_equal(CardDB.all().size())
	assert_int(s.shown_id()).is_equal(int(CardDB.all()[0]["id"]))
	assert_bool(s.preview_is_empty()).is_false()


func test_click_selects_into_preview_and_right_click_inspects() -> void:
	var s := _screen()
	var id := int(CardDB.all()[5]["id"])
	var w := s.browser.cell_widget(id)
	w.pressed.emit(w)
	assert_int(s.shown_id()).is_equal(id)
	assert_bool(w.selected).is_true()
	assert_bool(s.browser.cell_widget(int(CardDB.all()[0]["id"])).selected).is_false()
	w.right_pressed.emit(w)
	assert_int(CardInspector.open_count()).is_equal(1)


func test_search_and_no_results_state() -> void:
	var s := _screen()
	s.browser.set_query("dragon")
	var n := s.browser.visible_count()
	assert_int(n).is_greater(0)
	assert_int(n).is_less(CardDB.all().size())
	assert_bool(s.browser.visible_ids().has(s.shown_id())).is_true()
	s.browser.set_query("zzzz-no-such-card")
	assert_int(s.browser.visible_count()).is_equal(0)
	assert_bool(s.browser._no_match.visible).is_true()
	assert_bool(s.preview_is_empty()).is_true()
	s.browser.clear_filters()
	assert_int(s.browser.visible_count()).is_equal(CardDB.all().size())
	assert_bool(s.browser._no_match.visible).is_false()
	assert_bool(s.preview_is_empty()).is_false()


func test_category_filter_and_sort_by_name() -> void:
	var s := _screen()
	var b := s.browser
	for i in b.cat_opt.item_count:
		if b.cat_opt.get_item_metadata(i) == "fusion":
			b.cat_opt.select(i)
	b.refresh()
	for id in b.visible_ids():
		assert_str(CardDB.get_def(int(id))["category"]).is_equal("fusion")
	b.cat_opt.select(0)
	b.sort_opt.select(1)   # Name
	b.refresh()
	var names: Array = b.visible_ids().map(func(id): return String(CardDB.get_def(int(id))["name"]).to_lower())
	var sorted := names.duplicate()
	sorted.sort()
	assert_array(names).is_equal(sorted)


func test_search_matches_race_and_type_words() -> void:
	for d in CardDB.all():
		if d["type"] != null and String(d["type"]) != "":
			assert_bool(CardBrowser.matches(d, String(d["type"]), "", "", "", "")).is_true()
			break


func test_keyboard_moves_selection() -> void:
	var s := _screen()
	var ids := s.browser.visible_ids()
	s.browser.move_selection(1)
	assert_int(s.shown_id()).is_equal(int(ids[1]))
	s.browser.move_selection(-5)
	assert_int(s.shown_id()).is_equal(int(ids[0]))


func _esc() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	return e


func test_escape_closes_inspector_first_then_backs_out_once() -> void:
	var s := _screen()
	var closed := [0]
	s.closed.connect(func(): closed[0] += 1)
	s.inspect_card(s.shown_id())
	s._input(_esc())
	assert_int(closed[0]).is_equal(0)
	CardInspector.close_all()
	s._input(_esc())
	s._input(_esc())
	assert_int(closed[0]).is_equal(1)
