extends GdUnitTestSuite
## Final review #13 (design/review-final-2026-11-05.md): on mini cards, long rules text touched the
## bottom rim (Raging Inferno in the Extra Deck offer). The rules paragraph was fitted to within 1.5
## base units of its well, 2.7 units from the frame's gold filet. Checked for every card (all 191) at
## every size that shows rules text: the tall layout (hand 120, mini 90 / 150 / 210, big 224 wide) and
## the field Power / Trap (85 wide on the board, larger in windows that scale up).

## Least room (base units) between the last line's box and the frame's inner filet (the sides keep
## 4.2 to the ink; the bottom needs more to look as clear). It was 2.7 for the longest texts.
const RIM_ROOM := 6.0
## Card scales (face width / base width) that show rules text.
const TALL_SCALES := [0.75, 1.0, 1.25, 1.4, 1.75, 224.0 / 120.0]
const FIELD_SCALES := [1.0, 1.2, 1.5]
## CardTextLayout.fit_para lets a paragraph overrun its box by half a pixel.
const FIT_SLACK := 0.51
## From this scale up (the 150 px Extra Deck offer, the 210 px hover, the 224 px inspector) the whole
## text must show. A hand card at rest (120) draws at the 6 px floor and may end in an ellipsis: its
## hover grows it to 210 px to read in full (owner feedback 2026-10-18).
const READ_SCALE := 1.25
## The card with by far the longest rules text.
const LONGEST := "Akiramari"


func _texts() -> Array:
	var out := []
	for d in CardDB.all():
		var v := MatchView.def_view(int(d["id"]))
		var txt := CardText.card_text(v)
		if txt != "":
			out.append([int(d["id"]), String(d["name"]), txt])
	return out


func test_tall_rules_text_keeps_clear_of_the_bottom_rim_for_every_card_and_size() -> void:
	var bad := []
	for s in TALL_SCALES:
		var rim: float = (CardWidget.SIZES["hand"].y - CardLayouts.FRAME_W) * s
		for e in _texts():
			var tp := CardLayouts.tall_rules_para(e[2], s)
			var bottom := CardLayouts.tall_text_rect(s).position.y + tp.get_size().y
			if rim - bottom < RIM_ROOM * s - FIT_SLACK:
				bad.append("%s @%.2f: %.1f px from the rim" % [e[1], s, rim - bottom])
	assert_array(bad).override_failure_message("text too near the rim:\n%s" % "\n".join(bad.slice(0, 12))).is_empty()


func test_tall_rules_text_is_never_cut_at_reading_sizes() -> void:
	var cut := []
	for s in TALL_SCALES:
		if s < READ_SCALE:
			continue
		for e in _texts():
			var tp := CardLayouts.tall_rules_para(e[2], s)
			# The one exception: Akiramari's 391 characters (the next longest is 308) cannot fit the 150 px
			# offer card even at the 6 px floor with the tightest leading; it ends in an ellipsis there and
			# reads in full from 168 px up (and in its tooltip and inspector).
			if CardTextLayout.shown_text(tp, e[2]) != e[2] and not (e[1] == LONGEST and s < 1.3):
				cut.append("%s @%.2f" % [e[1], s])
	assert_array(cut).override_failure_message("cut:\n%s" % "\n".join(cut.slice(0, 12))).is_empty()


func test_a_status_word_at_a_line_start_never_redraws_the_whole_line() -> void:
	# A status word opening the line: no plain range may end at 0 (TextServer reads that as no clip).
	var ranges := StatusHelp.plain_ranges([Vector2(0, 22)])
	assert_array(ranges).is_equal([Vector2(22, -1)])
	# Mid-line words keep the text before, between and after them.
	assert_array(StatusHelp.plain_ranges([Vector2(10, 20), Vector2(30, 40)])) \
		.is_equal([Vector2(-1, 10), Vector2(20, 30), Vector2(40, -1)])


func test_field_power_text_keeps_clear_of_the_bottom_rim() -> void:
	var bad := []
	for s in FIELD_SCALES:
		var rim: float = (CardWidget.SIZES["power"].y - CardLayouts.FRAME_W) * s
		for e in _texts():
			var tp := CardLayouts.power_rules_para(e[2], s)
			var bottom := CardLayouts.power_text_rect(s).position.y + tp.get_size().y
			if rim - bottom < RIM_ROOM * s - FIT_SLACK:
				bad.append("%s @%.2f: %.1f px from the rim" % [e[1], s, rim - bottom])
	assert_array(bad).override_failure_message("power text too near the rim:\n%s" % "\n".join(bad.slice(0, 12))).is_empty()
