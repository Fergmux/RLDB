extends GdUnitTestSuite
## H1 WP-1 (design/design-review-2026-10-20.md 1.3, 1.4.2-1.4.6): spacing tokens and pad(), the
## depth shadows, the motion tokens, the button families and their states, the F3 / F4 factories,
## the gold selection colour, the scroll bar theme and the UI feedback sounds' wiring.

var _rm: bool
var _fast: bool


func before_test() -> void:
	_rm = UIStyle.reduce_motion
	_fast = UIStyle.fast_anim
	UIStyle.reduce_motion = false
	UIStyle.fast_anim = false
	Sfx._reset_hover()
	Sfx._reset_ui()


func after_test() -> void:
	UIStyle.reduce_motion = _rm
	UIStyle.fast_anim = _fast


func test_space_tokens_follow_the_4px_scale() -> void:
	var want := {"xs": 4, "sm": 8, "md": 12, "lg": 16, "xl": 24, "xxl": 32, "xxxl": 48}
	for k in want:
		assert_int(UIStyle.sp(k)).is_equal(int(want[k]))
		assert_int(UIStyle.sp(k) % 4).is_equal(0)


func test_pad_sets_stylebox_margins_from_tokens() -> void:
	var sb := StyleBoxFlat.new()
	UIStyle.pad(sb, "lg", "sm")
	assert_float(sb.content_margin_left).is_equal(16.0)
	assert_float(sb.content_margin_right).is_equal(16.0)
	assert_float(sb.content_margin_top).is_equal(8.0)
	assert_float(sb.content_margin_bottom).is_equal(8.0)


func test_pad_reaches_the_flat_box_inside_a_surface_box() -> void:
	var inner := StyleBoxFlat.new()
	var box := UiSurface.box(inner, UiSurface.LEATHER, 0.5)
	UIStyle.pad(box, "xl")
	assert_float(inner.content_margin_left).is_equal(24.0)
	assert_float(box.content_margin_top).is_equal(24.0)


func test_pad_sets_container_constants() -> void:
	var m: MarginContainer = auto_free(UIStyle.margin("xl", "md"))
	assert_int(m.get_theme_constant("margin_left")).is_equal(24)
	assert_int(m.get_theme_constant("margin_top")).is_equal(12)
	var v: VBoxContainer = auto_free(VBoxContainer.new())
	UIStyle.pad(v, "md")
	assert_int(v.get_theme_constant("separation")).is_equal(12)
	var g: GridContainer = auto_free(GridContainer.new())
	UIStyle.pad(g, "md", "lg")
	assert_int(g.get_theme_constant("h_separation")).is_equal(12)
	assert_int(g.get_theme_constant("v_separation")).is_equal(16)


func test_lift_applies_the_depth_table() -> void:
	var sb := UIStyle.lift(StyleBoxFlat.new(), UIStyle.DEPTH_RAISED)
	assert_int(sb.shadow_size).is_equal(10)
	assert_float(sb.shadow_offset.y).is_equal(4.0)
	assert_float(sb.shadow_color.a).is_equal_approx(0.55, 0.001)
	var modal := UIStyle.lift(StyleBoxFlat.new(), UIStyle.DEPTH_MODAL)
	assert_int(modal.shadow_size).is_equal(40)
	assert_float(modal.shadow_offset.y).is_equal(16.0)
	var table := UIStyle.lift(StyleBoxFlat.new(), UIStyle.DEPTH_TABLE)
	assert_float(table.shadow_color.a).is_equal(0.0)


func test_floating_depth_lights_the_top_edge() -> void:
	var sb := UIStyle.lift(StyleBoxFlat.new(), UIStyle.DEPTH_FLOATING)
	assert_int(sb.border_width_top).is_equal(1)
	assert_that(sb.border_color).is_equal(UIStyle.DEPTH_FLOAT_RIM)


func test_motion_tokens_scale_with_fast_animations() -> void:
	assert_float(UIStyle.motion("panel_in")).is_equal_approx(0.26, 0.0001)
	assert_float(UIStyle.motion("count")).is_equal_approx(0.4, 0.0001)
	UIStyle.fast_anim = true
	assert_float(UIStyle.motion("panel_in")).is_equal_approx(0.13, 0.0001)


func test_breathe_is_static_under_reduce_motion() -> void:
	assert_float(UIStyle.breathe(0.6)).is_equal_approx(1.0 + UIStyle.BREATHE_AMP, 0.0001)
	UIStyle.reduce_motion = true
	assert_float(UIStyle.breathe(0.6)).is_equal(1.0)


func test_tween_in_out_of_tree_leaves_the_node_at_rest() -> void:
	var c: Control = auto_free(Control.new())
	c.modulate.a = 0.3
	assert_object(UIStyle.tween_in(c)).is_null()
	assert_float(c.modulate.a).is_equal(1.0)
	assert_that(c.scale).is_equal(Vector2.ONE)


func test_tween_in_starts_from_the_panel_in_pose() -> void:
	var c: Control = auto_free(Control.new())
	add_child(c)
	c.position = Vector2(10, 40)
	var tw := UIStyle.tween_in(c)
	assert_object(tw).is_not_null()
	assert_float(c.modulate.a).is_equal(0.0)
	assert_float(c.scale.x).is_equal_approx(UIStyle.PANEL_IN_SCALE, 0.0001)
	assert_float(c.position.y).is_equal_approx(40.0 + UIStyle.PANEL_IN_RISE, 0.0001)
	tw.custom_step(5.0)
	assert_float(c.position.y).is_equal_approx(40.0, 0.0001)
	assert_float(c.modulate.a).is_equal(1.0)


func test_tween_in_under_reduce_motion_is_a_fade_only() -> void:
	UIStyle.reduce_motion = true
	var c: Control = auto_free(Control.new())
	add_child(c)
	c.position = Vector2(10, 40)
	UIStyle.tween_in(c)
	assert_that(c.scale).is_equal(Vector2.ONE)
	assert_float(c.position.y).is_equal(40.0)
	assert_float(c.modulate.a).is_equal(0.0)


func test_danger_family_is_ember_with_light_text() -> void:
	var b: Button = auto_free(UIStyle.danger_button("Concede"))
	var n := UiSurface.flat_of(b.get_theme_stylebox("normal"))
	assert_that(n.bg_color).is_equal(UIStyle.EMBER)
	assert_that(b.get_theme_color("font_color")).is_equal(UIStyle.EMBER_TEXT)
	assert_str(String(b.get_meta(Sfx.FAMILY_META))).is_equal("danger")


func test_secondary_hover_borders_gold() -> void:
	var b: Button = auto_free(UIStyle.secondary_button("Keep playing"))
	var h := UiSurface.flat_of(b.get_theme_stylebox("hover"))
	assert_that(h.border_color).is_equal(Color(UIStyle.GOLD, 0.9))
	assert_that(b.get_theme_color("font_hover_color")).is_equal(UIStyle.GOLD_HI)
	assert_float((b as JuicyButton).hover_inner_glow.a).is_greater(0.0)


func test_disabled_state_is_readable_and_flat_for_every_family() -> void:
	for f in ["primary", "secondary", "danger", "wine"]:
		var st := UIStyle.button_styles(f)
		var d := st["disabled"] as StyleBoxFlat
		assert_object(d).is_not_null()   # a plain flat box: no grain
		assert_that(d.bg_color).is_equal(UIStyle.PANEL)
		assert_that(d.border_color).is_equal(UIStyle.DISABLED_EDGE)
		assert_int(d.shadow_size).is_equal(0)
	var b: Button = auto_free(UIStyle.primary_button("Start"))
	assert_that(b.get_theme_color("font_disabled_color")).is_equal(UIStyle.DISABLED)


func test_pressed_state_sits_one_pixel_lower() -> void:
	var st := UIStyle.button_styles("secondary")
	var n: StyleBox = st["normal"]
	var p: StyleBox = st["pressed"]
	assert_float(p.content_margin_top - n.content_margin_top).is_equal(1.0)


func test_size_button_applies_height_width_and_padding() -> void:
	var b: Button = auto_free(UIStyle.size_button(UIStyle.secondary_button("Ok"), "hero"))
	assert_float(b.custom_minimum_size.y).is_equal(52.0)
	assert_float(b.custom_minimum_size.x).is_equal(float(UIStyle.BUTTON_MIN_W))
	assert_float(b.get_theme_stylebox("normal").content_margin_left).is_equal(float(UIStyle.BUTTON_PAD_X))


func test_wine_button_keeps_its_leather_face() -> void:
	var b: Button = auto_free(UIStyle.wine_button("Pass"))
	assert_that(UiSurface.flat_of(b.get_theme_stylebox("normal")).bg_color).is_equal(UIStyle.WINE)


func test_selection_is_gold_not_blue() -> void:
	assert_that(UIStyle.SELECT).is_equal(UIStyle.GOLD_HI)
	assert_that(UIStyle.SELECT).is_not_equal(UIStyle.PREVIEW)


func test_inset_style_is_engraved_with_an_inner_shadow() -> void:
	var d := UIStyle.inset_style()
	assert_that(d.base.bg_color).is_equal(UIStyle.PANEL_INK)
	assert_float(d.engrave_dark.a).is_equal_approx(0.7, 0.001)
	assert_float(d.inner_shadow_px).is_equal(UIStyle.INSET_SHADOW_PX)
	assert_float(d.content_margin_left).is_equal(12.0)


func test_chip_style_tints_the_fill_and_border() -> void:
	var col := UIStyle.GOOD
	var d := UIStyle.chip_style(col)
	assert_that(d.base.bg_color).is_equal(UIStyle.PANEL_INK.lerp(col, UIStyle.CHIP_FILL_A))
	assert_float(d.base.border_color.a).is_equal_approx(UIStyle.CHIP_EDGE_A, 0.001)


func test_band_colors_fade_over_the_band_depth() -> void:
	var r := Rect2(0, 10, 50, 40)
	var pts := PackedVector2Array([Vector2(0, 10), Vector2(0, 13), Vector2(0, 16), Vector2(0, 40)])
	var cols := DepthBox.band_colors(pts, r, Color(0, 0, 0, 0.6), 6.0)
	assert_float(cols[0].a).is_equal_approx(0.6, 0.0001)
	assert_float(cols[1].a).is_equal_approx(0.3, 0.0001)
	assert_float(cols[2].a).is_equal(0.0)
	assert_float(cols[3].a).is_equal(0.0)


func test_scrollbar_theme_has_an_8px_track_and_content_gap() -> void:
	var th := UIStyle.apply_scrollbar_theme(Theme.new())
	var track := th.get_stylebox("scroll", "VScrollBar")
	assert_float(track.get_minimum_size().x).is_equal(float(UIStyle.SCROLL_TRACK_W))
	assert_int(th.get_constant("scrollbar_v_separation", "ScrollContainer")).is_equal(UIStyle.SCROLL_CONTENT_GAP)
	var grab := th.get_stylebox("grabber", "VScrollBar") as StyleBoxFlat
	assert_int(grab.border_width_left + grab.border_width_right).is_equal(UIStyle.SCROLL_TRACK_W - UIStyle.SCROLL_THUMB_W)


func test_check_boxes_click_with_the_toggle_latch() -> void:
	var cb: CheckBox = auto_free(CheckBox.new())
	cb.button_pressed = true
	assert_str(Sfx.button_sound(cb)).is_equal("toggle_on")
	cb.button_pressed = false
	assert_str(Sfx.button_sound(cb)).is_equal("toggle_off")


func test_folder_tabs_click_with_the_tab_cue() -> void:
	var ft: FolderTabs = auto_free(FolderTabs.new())
	var t := ft.add_tab("a", "Alpha")
	assert_str(Sfx.button_sound(t)).is_equal("tab")


func test_hover_cue_is_rate_limited_to_one_per_60ms() -> void:
	assert_bool(Sfx.hover_at(1000)).is_true()
	assert_bool(Sfx.hover_at(1030)).is_false()
	assert_bool(Sfx.hover_at(1061)).is_true()
	assert_int(Sfx.debug_hover.size()).is_equal(2)


func test_hover_cue_skips_disabled_and_opted_out_buttons() -> void:
	var b: Button = auto_free(UIStyle.secondary_button("X"))
	b.disabled = true
	assert_bool(Sfx.hover(b)).is_false()
	b.disabled = false
	b.set_meta(Sfx.HOVER_META, "none")
	assert_bool(Sfx.hover(b)).is_false()


func test_new_ui_sounds_are_registered_and_ranked_under_back() -> void:
	for n in ["ui_hover", "panel_open", "panel_close", "tab", "toggle_on", "toggle_off", "hp_low_heartbeat"]:
		assert_bool(Sfx.NAMES.has(n)).is_true()
	assert_int(int(Sfx.UI_PRIORITY["panel_close"])).is_less(int(Sfx.UI_PRIORITY["back"]))
	assert_int(int(Sfx.UI_PRIORITY["tab"])).is_greater(int(Sfx.UI_PRIORITY["click_secondary"]))
	assert_bool(Sfx.UI_PRIORITY.has("ui_hover")).is_false()


func test_a_dismissing_choice_plays_only_the_close_cue() -> void:
	# "Keep playing" dismisses the dialog: panel_close outranks its own plain click in that frame.
	var d := ConfirmDialog.open(self, "Concede?", "Sure?", "Concede", func(): pass)
	await await_idle_frame()
	Sfx._reset_ui()
	d.press("Keep playing")
	assert_array(Sfx.debug_ui).contains_exactly(["panel_close"])


func test_an_action_choice_keeps_its_own_click() -> void:
	var d := ConfirmDialog.open(self, "Concede?", "Sure?", "Concede", func(): pass)
	await await_idle_frame()
	Sfx._reset_ui()
	d.press("Concede")
	assert_bool(Sfx.debug_ui.has("panel_close")).is_false()
	assert_int(Sfx.debug_ui.size()).is_equal(1)


func test_focus_ring_shows_for_code_focus() -> void:
	var b: JuicyButton = UIStyle.secondary_button("Keep playing") as JuicyButton
	b.focus_mode = Control.FOCUS_ALL
	add_child(b)
	auto_free(b)
	assert_bool(b.focus_ring_shown()).is_false()
	b.grab_focus()
	assert_bool(b.focus_ring_shown()).is_true()
	b.release_focus()
	assert_bool(b.focus_ring_shown()).is_false()
