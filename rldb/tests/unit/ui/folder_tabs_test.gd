extends GdUnitTestSuite
## FolderTabs (2026-10-20, F3): the shared folder-tab widget. The open tab and the pane are one
## shape; closed tabs keep the pane's top border running under them; tabs start after a margin.


func _tabs(keys: Array = ["a", "b", "c"]) -> FolderTabs:
	var ft := FolderTabs.new()
	ft.custom_minimum_size = Vector2(600, 300)
	for k in keys:
		ft.add_tab(String(k), "Tab %s" % k)
	add_child(ft)
	auto_free(ft)
	return ft


func test_first_tab_opens_by_default() -> void:
	var ft := _tabs()
	assert_str(ft.selected).is_equal("a")
	assert_bool(ft.is_open("a")).is_true()


func test_select_changes_the_open_tab_and_reports_it() -> void:
	var ft := _tabs()
	var got := []
	ft.tab_selected.connect(func(k): got.append(k))
	ft.tab("c").pressed.emit()
	assert_str(ft.selected).is_equal("c")
	assert_array(got).is_equal(["c"])
	ft.tab("c").pressed.emit()   # already open: nothing more
	assert_array(got).is_equal(["c"])


func test_silent_select_does_not_emit() -> void:
	var ft := _tabs()
	var got := []
	ft.tab_selected.connect(func(k): got.append(k))
	ft.select("b", false)
	assert_str(ft.selected).is_equal("b")
	assert_array(got).is_empty()


func test_a_disabled_tab_cannot_be_opened() -> void:
	var ft := FolderTabs.new()
	add_child(ft)
	auto_free(ft)
	ft.add_tab("a", "A")
	ft.add_tab("b", "B", {"disabled": true})
	ft.select("b")
	assert_str(ft.selected).is_equal("a")


func test_tabs_start_after_the_left_margin() -> void:
	var ft := _tabs()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(ft.tab_rect("a").position.x).is_greater_equal(ft.left_margin)
	assert_float(ft.tab_rect("b").position.x).is_greater(ft.tab_rect("a").end.x)


func test_the_pane_sits_directly_below_the_tab_strip() -> void:
	var ft := _tabs()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(ft.pane.position.y).is_equal(ft.tab_height)
	assert_float(ft.tab_rect("a").end.y).is_equal_approx(ft.tab_height, 0.6)


## The pane's top border has a gap exactly under the open tab (the tab joins the pane) and runs
## unbroken everywhere else, so under closed tabs it is continuous.
func test_top_border_is_broken_only_under_the_open_tab() -> void:
	var none := FolderTabs.top_border_spans(600.0, 0.0, 0.0)
	assert_int(none.size()).is_equal(1)
	var spans := FolderTabs.top_border_spans(600.0, 100.0, 220.0)
	assert_int(spans.size()).is_equal(2)
	assert_float(spans[0][1]).is_less_equal(100.0)
	assert_float(spans[1][0]).is_greater_equal(220.0)
	# Nothing of the border is missing outside the open tab's foot (plus its flares).
	assert_float(spans[0][0]).is_equal(none[0][0])
	assert_float(spans[1][1]).is_equal(none[0][1])
	assert_float(spans[1][0] - spans[0][1]).is_less_equal(120.0 + 2.0 * FolderTabs.FLARE)


func test_pane_content_is_laid_out_inside_the_pane() -> void:
	var ft := _tabs()
	var c := Control.new()
	c.custom_minimum_size = Vector2(50, 40)
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ft.pane.add_child(c)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(c.global_position.y).is_greater_equal(ft.global_position.y + ft.tab_height)
	assert_float(ft.get_combined_minimum_size().y).is_greater_equal(ft.tab_height + 40.0)
