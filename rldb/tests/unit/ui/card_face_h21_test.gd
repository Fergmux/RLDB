extends GdUnitTestSuite
## 21 Oct owner batch, card face (design/owner-feedback-2026-10-21.md H10, H12, H14, H16, H17, H19,
## H20, H21): rules text never runs past its well, selection brackets draw above the zones, card
## names stay on one line at a shrunk size, and the face parts keep their places.

## Dante (#36): the longest unit rules text in the database.
const LONG_TEXT_ID := 36
## The left-pane subject card size (GamePromptBanner.SUBJECT_CARD).
const PANE := Vector2(64, 96)


func _widget(v: Dictionary, kind: String, sz: Vector2 = Vector2.ZERO, rotated: bool = false) -> CardWidget:
	var host: Control = auto_free(Control.new())
	add_child(host)
	var w := CardWidget.new()
	w.auto_hover = false
	w.setup(v, kind, "", rotated)
	host.add_child(w)
	if sz != Vector2.ZERO:
		GameUi.resize_card(w, sz)
	return w


func _view(id: int, zone: String = "hand") -> Dictionary:
	var v := MatchView.summary_view(Series.card_summary(id))
	v["zone"] = zone
	return v


func _trace(w: CardWidget) -> Array:
	w.set_text_tracing(true)
	await get_tree().process_frame
	await get_tree().process_frame
	return w.text_trace()


# ---------------------------------------------------------------- H10 rules text fits

func test_fit_para_too_long_text_is_cut_to_the_box_with_an_ellipsis() -> void:
	var txt := CardText.card_text(_view(LONG_TEXT_ID))
	var w := 56.0
	var h := 22.0
	var tp := CardTextLayout.fit_para(txt, UIStyle.font_body(), 6, 6, w, h)
	var shown := CardTextLayout.shown_text(tp, txt)
	var drawn_h := 0.0
	for i in tp.get_line_count():
		drawn_h += tp.get_line_size(i).y
	assert_float(drawn_h).is_less_equal(h + 0.5)
	assert_str(shown).ends_with(CardTextLayout.ELLIPSIS)
	assert_bool(txt.begins_with(shown.trim_suffix(CardTextLayout.ELLIPSIS))).is_true()


func test_fit_para_text_that_fits_is_shown_whole() -> void:
	var tp := CardTextLayout.fit_para("Draw a card.", UIStyle.font_body(), 10, 6, 100.0, 40.0)
	assert_str(CardTextLayout.shown_text(tp, "")).is_equal("Draw a card.")


func test_left_pane_card_rules_text_stays_inside_its_well() -> void:
	for id in [LONG_TEXT_ID, 147, 45, 182, 185]:
		var w := _widget(_view(id), "mini", PANE)
		var s := PANE.x / CardWidget.SIZES["hand"].x
		var t: Array = CardLayouts.TALL["text"]
		var well_bottom := (float(t[1]) + float(t[3])) * s
		var paras := (await _trace(w)).filter(func(r): return r[0] == "para")
		assert_int(paras.size()).is_equal(1)
		var r: Array = paras[0]
		assert_float((r[2] as Vector2).y + float(r[4])).override_failure_message("card %d text runs past its well" % id).is_less_equal(well_bottom + 0.5)


# ---------------------------------------------------------------- H12 selection brackets

func test_selected_card_draws_above_later_zones_and_drops_back_when_cleared() -> void:
	var row: Control = auto_free(Control.new())
	add_child(row)
	var zone_a := CardWidget.new().setup(null, "board")
	var zone_b := CardWidget.new().setup(null, "board")
	row.add_child(zone_a)
	row.add_child(zone_b)
	var card := CardWidget.new().setup(_view(LONG_TEXT_ID, "unit"), "board")
	zone_a.add_child(card)
	card.set_marks(false, true)
	assert_int(card.z_index).is_greater(zone_b.z_index)
	assert_bool(card.z_as_relative).is_true()
	card.set_marks(false, false)
	assert_int(card.z_index).is_equal(0)


## The name records of a widget's last draw: "line" traces whose text is (part of) the card name.
func _name_lines(trace: Array, nm: String) -> Array:
	return trace.filter(func(r): return r[0] == "line" and (nm.begins_with(String(r[1]).trim_suffix(CardTextLayout.ELLIPSIS)) or String(r[1]).ends_with(")")))


# ---------------------------------------------------------------- H14 / H19 one-line names

func test_long_names_show_whole_on_one_line_on_every_kind() -> void:
	# Anduras (#99), Drako (#185), Saviour Appears (#165), Infernogate (#58).
	for id in [99, 185, 165, 58]:
		for kind in ["board", "hand", "big"]:
			var v := _view(id, "unit" if kind == "board" else "hand")
			var nm := String(v["name"])
			var w := _widget(v, kind)
			var lines := _name_lines(await _trace(w), nm)
			assert_int(lines.size()).override_failure_message("%s on %s: %d name lines" % [nm, kind, lines.size()]).is_equal(1)
			assert_str(String(lines[0][1])).is_equal(nm)


func test_name_fit_shrinks_first_then_condenses_within_the_plate() -> void:
	var font := UIStyle.font_display(600)
	var short_fit := CardTextLayout.fit_name_line("Dante", 75.0, 10.5, 9.0, font, 1.0)
	assert_float(float(short_fit[1])).is_equal(1.0)
	var nm := "Anduras, Fisherman of the Ocean Tribe"
	var fit := CardTextLayout.fit_name_line(nm, 75.0, 10.5, 9.0, font, 1.0)
	assert_float(float(fit[1])).is_less(1.0)
	assert_float(font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[0])).x * float(fit[1])).is_less_equal(75.01)


# ---------------------------------------------------------------- H21 kind line on the left

func test_spell_trap_and_power_kind_line_is_left_aligned_like_the_race() -> void:
	# Shimmer Serum (Spell), Magic Cylinder (Trap), Marked by the Abyss (Power).
	for id in [182, 45, 149]:
		var v := _view(id)
		var kind_name := String(UIStyle.CATEGORY_NAMES[v["category"]])
		var w := _widget(v, "hand")
		var rows := (await _trace(w)).filter(func(r): return r[0] == "line" and String(r[1]) == kind_name)
		assert_int(rows.size()).is_equal(1)
		assert_int(int(rows[0][5])).is_equal(HORIZONTAL_ALIGNMENT_LEFT)


# ---------------------------------------------------------------- H16 rounded art window

func test_art_window_corner_is_concentric_with_the_frame_corner() -> void:
	var pt := CardPainter.new(null)
	pt.s = 1.0
	var r := CardLayouts.art_radius(pt, CardLayouts.RADIUS_SMALL, CardLayouts.FIELD)
	var inset := float(CardLayouts.FIELD["art"][0])
	assert_float(r).is_equal_approx(CardLayouts.RADIUS_SMALL - inset + CardLayouts.ART_RADIUS_EXTRA, 0.001)
	assert_float(r).is_greater(1.0)


func test_rounded_window_outline_stays_inside_and_cuts_the_corner() -> void:
	var rect := Rect2(3, 3, 79, 79)
	var pts := CardGeometry.round_rect_pts(rect, 4.0)
	for p in pts:
		assert_bool(rect.grow(0.01).has_point(p)).is_true()
	assert_bool(pts.has(rect.position)).is_false()


# ---------------------------------------------------------------- overlay layer (performance)

func test_animated_selection_repaints_only_the_overlay_not_the_face() -> void:
	var was := UIStyle.reduce_motion
	UIStyle.reduce_motion = false
	var w := _widget(_view(LONG_TEXT_ID, "unit"), "board")
	w.set_marks(true, true)
	w.set_ready(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var before := w.face_draws
	for i in 4:
		await get_tree().process_frame
	UIStyle.reduce_motion = was
	assert_bool(w.is_processing()).is_true()
	assert_int(w.face_draws).is_equal(before)


func test_overlay_layer_is_internal_and_takes_the_dim() -> void:
	var w := _widget(_view(LONG_TEXT_ID, "unit"), "board")
	assert_int(w.get_child_count()).is_equal(0)
	w.set_marks(false, false, true)
	var ov := w.get_child(0, true) as CanvasItem
	assert_object(ov.self_modulate).is_equal(w.self_modulate)


func test_selected_card_stays_under_the_fx_vignette() -> void:
	assert_int(CardWidget.SELECTED_Z).is_less(FxPlayer.VIGNETTE_Z)
