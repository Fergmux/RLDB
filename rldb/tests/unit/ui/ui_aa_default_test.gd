extends GdUnitTestSuite
## F13: 4x MSAA is the default; an explicit saved choice is kept; a legacy file's 8x (the old default,
## always written) becomes 4x while any other legacy level is kept as a choice.


func _cf(values: Dictionary) -> ConfigFile:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("ui", k, values[k])
	return cf


func test_no_saved_level_uses_the_4x_default() -> void:
	assert_int(UIStyle.DEFAULT_AA).is_equal(4)
	assert_array(UIStyle.aa_from(ConfigFile.new())).is_equal([4, false])
	assert_array(UIStyle.aa_from(_cf({"reduce_motion": true}))).is_equal([4, false])


func test_legacy_old_default_becomes_4x() -> void:
	assert_array(UIStyle.aa_from(_cf({"aa_level": 8}))).is_equal([4, false])


func test_legacy_non_default_levels_are_kept_as_choices() -> void:
	for lv in [0, 2, 4]:
		assert_array(UIStyle.aa_from(_cf({"aa_level": lv}))).is_equal([lv, true])


func test_explicit_choices_are_kept_including_8x() -> void:
	for lv in [0, 2, 4, 8]:
		assert_array(UIStyle.aa_from(_cf({"aa_level": lv, "aa_explicit": true}))).is_equal([lv, true])


func test_unknown_level_falls_back_to_the_default() -> void:
	assert_array(UIStyle.aa_from(_cf({"aa_level": 3, "aa_explicit": true}))).is_equal([4, false])


func test_levels_map_to_root_viewport_msaa_and_the_project_default_matches() -> void:
	assert_int(UIStyle.msaa_for(0)).is_equal(Viewport.MSAA_DISABLED)
	assert_int(UIStyle.msaa_for(2)).is_equal(Viewport.MSAA_2X)
	assert_int(UIStyle.msaa_for(4)).is_equal(Viewport.MSAA_4X)
	assert_int(UIStyle.msaa_for(8)).is_equal(Viewport.MSAA_8X)
	assert_int(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d"))).is_equal(Viewport.MSAA_4X)
