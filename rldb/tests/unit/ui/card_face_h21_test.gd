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
