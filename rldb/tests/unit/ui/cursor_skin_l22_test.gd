extends GdUnitTestSuite
## L22 (owner, 5 Nov): the game's own cursors. CursorSkin maps each Input.CursorShape to its art,
## stacks overlay modes (knife, target...), picks the baked size from the UI scale and DPI, and saves
## the "Custom cursor" setting; GameCursor swaps the board's modes one at a time.
## Story: design/owner-feedback-2026-11-05.md L22.

const PREFS := "user://test_cursor_skin_l22.cfg"


func before_test() -> void:
	CursorSkin.uninstall()
	CursorSkin.settings_path_override = PREFS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFS))


func after_test() -> void:
	CursorSkin.uninstall()
	CursorSkin.settings_path_override = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFS))


# ---------------------------------------------------------------- shape mapping

func test_l22_shapes_map_to_the_house_art() -> void:
	assert_str(String(CursorSkin.art_for(Input.CURSOR_ARROW))).is_equal("normal")
	assert_str(String(CursorSkin.art_for(Input.CURSOR_POINTING_HAND))).is_equal("pointer")
	assert_str(String(CursorSkin.art_for(Input.CURSOR_CROSS))).is_equal("target")
	assert_str(String(CursorSkin.art_for(Input.CURSOR_FORBIDDEN))).is_equal("forbidden")
	assert_str(String(CursorSkin.art_for(Input.CURSOR_HELP))).is_equal("help")


func test_l22_text_and_resize_shapes_keep_the_system_cursor() -> void:
	for shape in [Input.CURSOR_IBEAM, Input.CURSOR_VSIZE, Input.CURSOR_HSIZE, Input.CURSOR_HSPLIT]:
		assert_str(String(CursorSkin.art_for(shape))).is_equal("")
		assert_str(String(CursorSkin.art_for(shape, &"knife"))).is_equal("")


func test_l22_a_mode_reskins_arrow_pointer_and_help_only() -> void:
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_HELP]:
		assert_str(String(CursorSkin.art_for(shape, &"knife"))).is_equal("knife")
		assert_str(String(CursorSkin.art_for(shape, &"target_lock"))).is_equal("target_lock")
	assert_str(String(CursorSkin.art_for(Input.CURSOR_FORBIDDEN, &"knife"))).is_equal("forbidden")
	assert_str(String(CursorSkin.art_for(Input.CURSOR_CROSS, &"knife"))).is_equal("target")
	assert_str(String(CursorSkin.art_for(Input.CURSOR_ARROW, &"deny"))).is_equal("forbidden")


func test_l22_every_art_and_mode_has_baked_images_at_every_size() -> void:
	var arts: Array = CursorSkin.ART.keys()
	for m in CursorSkin.MODES:
		assert_bool(arts.has(CursorSkin.MODES[m])).override_failure_message("mode %s has no art" % m).is_true()
	for key in arts:
		for n in CursorSkin.SIZES:
			var tex := CursorSkin.texture(key, n)
			assert_object(tex).override_failure_message("%s_%d missing" % [key, n]).is_not_null()
			assert_int(tex.get_width()).is_equal(n)
			assert_int(tex.get_height()).is_equal(n)


func test_l22_each_hotspot_sits_on_the_drawn_art() -> void:
	# The click lands where the cursor visibly points: the hotspot pixel is (mostly) opaque art.
	for key in CursorSkin.ART:
		for n in CursorSkin.SIZES:
			var img := CursorSkin.texture(key, n).get_image()
			img.decompress()
			var h := CursorSkin.hotspot_px(CursorSkin.hotspot_units(key), n)
			assert_float(img.get_pixelv(h).a).override_failure_message("%s_%d hotspot %s is transparent" % [key, n, h]).is_greater(0.3)


# ---------------------------------------------------------------- modes

func test_l22_modes_stack_and_clear_back_to_the_one_below() -> void:
	CursorSkin.set_mode(&"knife")
	assert_str(String(CursorSkin.active_mode())).is_equal("knife")
	CursorSkin.set_mode(&"target")
	assert_str(String(CursorSkin.active_mode())).is_equal("target")
	CursorSkin.clear_mode(&"target")
	assert_str(String(CursorSkin.active_mode())).is_equal("knife")
	CursorSkin.clear_mode(&"knife")
	assert_str(String(CursorSkin.active_mode())).is_equal("")


func test_l22_setting_a_mode_twice_does_not_reorder_it() -> void:
	CursorSkin.set_mode(&"knife")
	CursorSkin.set_mode(&"target")
	CursorSkin.set_mode(&"knife")
	assert_str(String(CursorSkin.active_mode())).is_equal("target")
	CursorSkin.clear_mode(&"target")
	assert_str(String(CursorSkin.active_mode())).is_equal("knife")


func test_l22_clear_mode_without_a_name_clears_every_mode() -> void:
	CursorSkin.set_mode(&"knife")
	CursorSkin.set_mode(&"target_lock")
	CursorSkin.clear_mode()
	assert_str(String(CursorSkin.active_mode())).is_equal("")
	assert_bool(CursorSkin.has_mode(&"knife")).is_false()


func test_l22_unknown_modes_are_ignored() -> void:
	CursorSkin.set_mode(&"sparkles")
	assert_str(String(CursorSkin.active_mode())).is_equal("")
	CursorSkin.clear_mode(&"sparkles")
	assert_str(String(CursorSkin.active_mode())).is_equal("")


func test_l22_suspending_hides_modes_without_forgetting_them() -> void:
	CursorSkin.set_mode(&"knife")
	CursorSkin.set_suspended(true)
	assert_str(String(CursorSkin.active_mode())).is_equal("")
	assert_str(String(CursorSkin.current_art(Input.CURSOR_ARROW))).is_equal("normal")
	CursorSkin.set_suspended(false)
	assert_str(String(CursorSkin.current_art(Input.CURSOR_ARROW))).is_equal("knife")


func test_l22_apply_sets_the_mode_image_at_the_current_size() -> void:
	CursorSkin.force_size(48)
	assert_str(String(CursorSkin.applied()[Input.CURSOR_ARROW])).is_equal("normal@48")
	assert_str(String(CursorSkin.applied()[Input.CURSOR_POINTING_HAND])).is_equal("pointer@48")
	CursorSkin.set_mode(&"knife")
	assert_str(String(CursorSkin.applied()[Input.CURSOR_ARROW])).is_equal("knife@48")
	assert_str(String(CursorSkin.applied()[Input.CURSOR_POINTING_HAND])).is_equal("knife@48")
	assert_str(String(CursorSkin.applied()[Input.CURSOR_FORBIDDEN])).is_equal("forbidden@48")
	CursorSkin.force_size(64)
	assert_str(String(CursorSkin.applied()[Input.CURSOR_ARROW])).is_equal("knife@64")
	CursorSkin.clear_mode()
	assert_str(String(CursorSkin.applied()[Input.CURSOR_ARROW])).is_equal("normal@64")


# ---------------------------------------------------------------- the setting

func test_l22_custom_cursor_is_on_by_default() -> void:
	assert_bool(CursorSkin.is_enabled()).is_true()


func test_l22_turning_it_off_restores_every_system_cursor_at_once() -> void:
	CursorSkin.install()
	assert_str(String(CursorSkin.applied()[Input.CURSOR_ARROW])).is_equal("normal@32")
	CursorSkin.set_mode(&"knife")
	CursorSkin.set_enabled(false)
	for shape in CursorSkin.SHAPES:
		assert_str(String(CursorSkin.applied().get(shape, ""))).is_equal("")
	assert_str(String(CursorSkin.current_art(Input.CURSOR_ARROW))).is_equal("")
	CursorSkin.set_enabled(true)
	assert_str(String(CursorSkin.applied()[Input.CURSOR_ARROW])).is_equal("knife@32")
	assert_str(String(CursorSkin.applied()[Input.CURSOR_CROSS])).is_equal("target@32")


func test_l22_the_setting_persists_and_keeps_other_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("ui", "reduce_motion", true)
	cf.save(PREFS)
	CursorSkin.set_enabled(false)
	CursorSkin.uninstall()   # forget the loaded value, as a restart would
	CursorSkin.settings_path_override = PREFS
	assert_bool(CursorSkin.is_enabled()).is_false()
	var back := ConfigFile.new()
	assert_int(back.load(PREFS)).is_equal(OK)
	assert_bool(bool(back.get_value("ui", "reduce_motion", false))).is_true()
	assert_bool(bool(back.get_value("ui", CursorSkin.SETTINGS_KEY, true))).is_false()


func test_l22_automated_runs_save_to_the_test_settings_file() -> void:
	CursorSkin.settings_path_override = ""
	assert_str(DeckStore.PATH).is_equal(DeckStore.TEST_PATH)
	assert_str(CursorSkin.settings_path()).is_equal(CursorSkin.TEST_SETTINGS_PATH)


func test_l22_settings_form_has_the_custom_cursor_toggle() -> void:
	CursorSkin.set_enabled(false)
	var form := auto_free(SettingsForm.new()) as SettingsForm
	var cb: CheckBox = form.controls["custom_cursor"]
	assert_bool(cb.button_pressed).is_false()
	cb.button_pressed = true   # emits toggled
	assert_bool(CursorSkin.is_enabled()).is_true()


# ---------------------------------------------------------------- size

func test_l22_size_steps_with_the_ui_scale() -> void:
	assert_int(CursorSkin.size_for_scale(1.0)).is_equal(32)
	assert_int(CursorSkin.size_for_scale(1.29)).is_equal(32)
	assert_int(CursorSkin.size_for_scale(1.3)).is_equal(48)
	assert_int(CursorSkin.size_for_scale(1.74)).is_equal(48)
	assert_int(CursorSkin.size_for_scale(1.75)).is_equal(64)
	assert_int(CursorSkin.size_for_scale(3.0)).is_equal(64)


func test_l22_ui_scale_follows_the_window_and_the_screen_dpi() -> void:
	# 1080p full screen at 100%: 32 px. 1440p: 48 px. 4K: 64 px.
	assert_int(CursorSkin.size_for_scale(CursorSkin.ui_scale(Vector2(1920, 1080), 96))).is_equal(32)
	assert_int(CursorSkin.size_for_scale(CursorSkin.ui_scale(Vector2(2560, 1440), 96))).is_equal(48)
	assert_int(CursorSkin.size_for_scale(CursorSkin.ui_scale(Vector2(3840, 2160), 96))).is_equal(64)
	# A small window on a 150% screen still gets the 150% cursor.
	assert_int(CursorSkin.size_for_scale(CursorSkin.ui_scale(Vector2(1600, 1000), 144))).is_equal(48)
	# Never below the smallest size.
	assert_float(CursorSkin.ui_scale(Vector2(800, 500), 96)).is_equal(1.0)
	assert_float(CursorSkin.ui_scale(Vector2.ZERO, 0)).is_equal(1.0)


func test_l22_retina_scale_is_counted_in_logical_points() -> void:
	# macOS Retina: a 3200x2000 px window at scale 2 is 1600x1000 points: the 32 px cursor.
	assert_int(CursorSkin.size_for_scale(CursorSkin.ui_scale(Vector2(3200, 2000), 192, 2.0))).is_equal(32)


func test_l22_hotspots_land_on_a_pixel_centre_at_every_size() -> void:
	assert_object(CursorSkin.hotspot_px(Vector2(3, 3), 32)).is_equal(Vector2i(1, 1))
	assert_object(CursorSkin.hotspot_px(Vector2(3, 3), 48)).is_equal(Vector2i(2, 2))
	assert_object(CursorSkin.hotspot_px(Vector2(3, 3), 64)).is_equal(Vector2i(3, 3))
	assert_object(CursorSkin.hotspot_px(Vector2(32, 32), 32)).is_equal(Vector2i(16, 16))
	for key in CursorSkin.ART:
		for n in CursorSkin.SIZES:
			var u := CursorSkin.hotspot_units(key)
			var moved := (u + CursorSkin.snap_shift(u, n)) * float(n) / 64.0
			var want := Vector2(CursorSkin.hotspot_px(u, n)) + Vector2(0.5, 0.5)
			assert_float(moved.distance_to(want)).is_less(0.001)


# ---------------------------------------------------------------- buttons

func test_l22_dropdowns_and_check_boxes_get_the_pointer() -> void:
	var ob := auto_free(OptionButton.new()) as OptionButton
	var cb := auto_free(CheckBox.new()) as CheckBox
	CursorSkin.wire_button(ob)
	CursorSkin.wire_button(cb)
	assert_int(ob.mouse_default_cursor_shape).is_equal(Control.CURSOR_POINTING_HAND)
	assert_int(cb.mouse_default_cursor_shape).is_equal(Control.CURSOR_POINTING_HAND)


func test_l22_a_button_that_chose_the_arrow_keeps_it() -> void:
	var b := auto_free(Button.new()) as Button
	b.mouse_default_cursor_shape = Control.CURSOR_ARROW
	CursorSkin.wire_button(b)
	assert_int(b.mouse_default_cursor_shape).is_equal(Control.CURSOR_ARROW)


func test_l22_a_disabled_button_drops_the_pointer_until_enabled() -> void:
	var b := auto_free(JuicyButton.new()) as JuicyButton
	CursorSkin.wire_button(b)
	assert_int(b.mouse_default_cursor_shape).is_equal(Control.CURSOR_POINTING_HAND)
	b.disabled = true
	CursorSkin.sync_disabled(b)
	assert_int(b.mouse_default_cursor_shape).is_equal(Control.CURSOR_ARROW)
	b.disabled = false
	CursorSkin.sync_disabled(b)
	assert_int(b.mouse_default_cursor_shape).is_equal(Control.CURSOR_POINTING_HAND)


func test_l22_a_disabled_button_showing_forbidden_keeps_it() -> void:
	var b := auto_free(JuicyButton.new()) as JuicyButton
	b.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	b.disabled = true
	CursorSkin.wire_button(b)
	assert_int(b.mouse_default_cursor_shape).is_equal(Control.CURSOR_FORBIDDEN)


# ---------------------------------------------------------------- the game screen's modes

func test_l22_game_cursor_swaps_its_one_mode() -> void:
	var gs := auto_free(GameScreen.new()) as GameScreen
	var gc := GameCursor.new(gs)
	CursorSkin.set_mode(&"knife")   # someone else's mode stays underneath
	gc.set_mode(&"target")
	gc.set_mode(&"target_lock")
	assert_bool(CursorSkin.has_mode(&"target")).is_false()
	assert_str(String(CursorSkin.active_mode())).is_equal("target_lock")
	gc.set_mode(&"")
	assert_str(String(CursorSkin.active_mode())).is_equal("knife")


func test_l22_game_cursor_shows_no_mode_without_a_game() -> void:
	var gs := auto_free(GameScreen.new()) as GameScreen
	var gc := GameCursor.new(gs)
	assert_str(String(gc.want_mode())).is_equal("")
