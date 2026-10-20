extends GdUnitTestSuite
## Post-duel rewards layout (2026-10-20, E1-E3): the result plate fits its line, the chosen-reward
## list is one aligned row per reward with an icon per kind, and option tiles are all one size.


func _panels() -> GameRewardPanels:
	return GameRewardPanels.new(null)


func test_result_plate_fits_its_line_instead_of_the_full_width() -> void:
	var host := VBoxContainer.new()
	host.custom_minimum_size = Vector2(700, 0)
	add_child(host)
	auto_free(host)
	var plate := _panels()._result_plate("Ben won game 1 (turn 2, HP 60-60).")
	host.add_child(plate)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(plate.size.x).is_less(host.size.x - 100.0)
	assert_float(plate.size.x).is_greater(100.0)
	assert_int(plate.size_flags_horizontal).is_equal(Control.SIZE_SHRINK_CENTER)


func test_reward_kind_reads_each_kind_of_taken_sentence() -> void:
	assert_str(GameRewardPanels.reward_kind("Added Fire Dragon")["kind"]).is_equal("add")
	assert_str(GameRewardPanels.reward_kind("Added Fire Dragon")["detail"]).is_equal("Fire Dragon")
	assert_str(GameRewardPanels.reward_kind("Added another Basic Mage (Fire)")["kind"]).is_equal("extra_basic")
	assert_str(GameRewardPanels.reward_kind("Added another Basic Mage (Fire)")["detail"]).is_equal("Basic Mage (Fire)")
	assert_str(GameRewardPanels.reward_kind("Removed Hot Stove")["kind"]).is_equal("remove")
	assert_str(GameRewardPanels.reward_kind("Changed 3 basic units to Basic Beast (Earth)")["kind"]).is_equal("basic")
	assert_str(GameRewardPanels.reward_kind("Changed 3 basic units to Basic Beast (Earth)")["detail"]).is_equal("3 basic units to Basic Beast (Earth)")
	assert_str(GameRewardPanels.reward_kind("Something new")["kind"]).is_equal("other")


func test_every_kind_has_its_own_icon_and_colour() -> void:
	var icons := {}
	for t in ["Added A", "Added another A", "Removed A", "Changed 1 basic unit to A"]:
		var k := GameRewardPanels.reward_kind(t)
		assert_bool(String(k["icon"]) != "").is_true()
		icons[String(k["kind"])] = k["color"]
	assert_int(icons.size()).is_equal(4)


func test_ledger_row_never_wraps_and_keeps_the_full_text_as_tooltip() -> void:
	var long_text := "Changed 12 basic units to An Extremely Long Basic Unit Name (Lightning)"
	var row := _panels()._ledger_row(long_text, false)
	add_child(row)
	auto_free(row)
	var labels := row.find_children("*", "Label", true, false)
	for l in labels:
		assert_int((l as Label).autowrap_mode).is_equal(TextServer.AUTOWRAP_OFF)
	assert_str(row.tooltip_text).is_equal(long_text)
	assert_float(row.custom_minimum_size.y).is_equal(GameRewardPanels.LEDGER_ROW_H)


func test_equal_size_is_the_widest_and_the_tallest() -> void:
	var sz := GameRewardPanels.equal_size([Vector2(120, 200), Vector2(180, 150), Vector2(90, 260)])
	assert_vector(sz).is_equal(Vector2(180, 260))


func test_equalize_grows_every_tile_to_the_largest_one() -> void:
	var a := Control.new()
	a.custom_minimum_size = Vector2(100, 120)
	var b := Control.new()
	b.custom_minimum_size = Vector2(140, 210)
	add_child(a)
	add_child(b)
	auto_free(a)
	auto_free(b)
	_panels().equalize([a, b])
	assert_vector(a.custom_minimum_size).is_equal(Vector2(140, 210))
	assert_vector(b.custom_minimum_size).is_equal(Vector2(140, 210))


func test_reward_kind_tiles_are_all_the_same_width() -> void:
	var row := _panels()._kinds_row()
	row.custom_minimum_size = Vector2(740, 0)
	add_child(row)
	auto_free(row)
	await get_tree().process_frame
	await get_tree().process_frame
	var w0 := (row.get_child(0) as Control).size.x
	for c in row.get_children():
		assert_float((c as Control).size.x).is_equal_approx(w0, 1.0)
		assert_float((c as Control).size.y).is_equal_approx((row.get_child(0) as Control).size.y, 1.0)
