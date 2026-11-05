extends GdUnitTestSuite
## L8 (owner feedback 2026-11-05): status badges on cards are enamelled, effect-coloured vector art
## (CardStatusIcons.badge), large enough to read on a field card, and the status tooltip repeats the
## badge with the name in its accent colour (StatusTip).

const ALL := ["rune", "retain", "eternal", "pierce", "cleanse", "medic", "infiltrate", "nimble",
	"reveal", "burn", "paralyse", "curse", "poison", "blind", "debilitate"]


func after_test() -> void:
	StatusTip.hide_all()


func test_every_status_has_an_enamelled_badge() -> void:
	for s in ALL:
		assert_object(CardStatusIcons.badge(s)).override_failure_message("no badge for %s" % s).is_not_null()


func test_badges_are_rasterised_for_4k_inspect_sizes() -> void:
	# The inspector badge is about 60 px at 4K; 256 px (with mipmaps) keeps it crisp with headroom.
	for s in ALL:
		var t := CardStatusIcons.badge(s)
		assert_int(t.get_width()).override_failure_message(s).is_greater_equal(256)


func test_every_status_has_its_own_accent_colour() -> void:
	var seen := {}
	for s in ALL:
		assert_bool(CardStatusIcons.ACCENT.has(s)).override_failure_message(s).is_true()
		var c: Color = CardStatusIcons.accent(s)
		assert_bool(seen.has(c.to_html())).override_failure_message("%s repeats a colour" % s).is_false()
		seen[c.to_html()] = true


func test_kind_of_matches_the_buff_and_debuff_lists() -> void:
	assert_int(CardStatusIcons.kind_of("rune")).is_equal(CardStatusIcons.KIND_RUNE)
	assert_int(CardStatusIcons.kind_of("eternal")).is_equal(CardStatusIcons.KIND_BUFF)
	assert_int(CardStatusIcons.kind_of("poison")).is_equal(CardStatusIcons.KIND_DEBUFF)


func test_a_field_card_row_still_holds_four_bigger_badges() -> void:
	var a: Array = CardLayouts.FIELD["icons"]
	var size := float(a[3])
	var gap := size * CardStatusIcons.GAP_K
	var per_row := int(floor((float(a[1]) - float(a[0]) + gap) / (size + gap)))
	assert_float(size).is_greater_equal(17.0)
	assert_int(per_row).is_equal(4)


func test_the_icon_hit_records_its_status_key() -> void:
	# Arrange
	var host: Control = auto_free(Control.new())
	add_child(host)
	var w := CardWidget.new()
	w.auto_hover = false
	w.setup({"uid": 1, "id": 1, "name": "Basic Mage", "category": "unit", "cost_kind": "ap", "cost": 1, "printed_cost": 1,
		"zone": "unit", "slot": 0, "face_up": true, "statuses": {"burn": 2}, "runes": 0, "text": "", "race": "Mage",
		"type": "Fire", "atk": 8, "def": 8, "printed_atk": 8, "printed_def": 8}, "board", "", false)
	host.add_child(w)
	# Act
	w.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	# Assert
	var hits := w.status_hits()
	assert_int(hits.size()).is_equal(1)
	assert_str(String(hits[0].get("key", ""))).is_equal("burn")


func test_the_tip_header_shows_the_badge_and_the_name_in_its_colour() -> void:
	var owner: Control = auto_free(Control.new())
	add_child(owner)
	StatusTip.show_for(owner, "Poison ×2", Rect2(100, 300, 16, 16), CardDB.STATUS_HELP["poison"], "poison")
	assert_str(StatusTip.shown_text()).is_equal("Poison ×2")
	assert_str(StatusTip.shown_key()).is_equal("poison")
	assert_object(StatusTip._tip._label.get_theme_color("font_color")).is_equal(CardStatusIcons.accent("poison"))
	assert_str(StatusTip._tip._kind.text).is_equal("Debuff")


func test_a_status_word_tip_names_the_status_next_to_its_badge() -> void:
	var owner: Control = auto_free(Control.new())
	add_child(owner)
	StatusTip.show_for(owner, "", Rect2(100, 300, 8, 16), CardDB.STATUS_HELP["eternal"], "eternal")
	assert_str(StatusTip.shown_text()).is_equal("Eternal")
	assert_str(StatusTip.shown_key()).is_equal("eternal")
	assert_str(StatusTip._tip._kind.text).is_equal("Buff")


func test_a_tip_without_a_key_has_no_badge() -> void:
	var owner: Control = auto_free(Control.new())
	add_child(owner)
	StatusTip.show_for(owner, "Poison ×1\nBurn ×1", Rect2(100, 300, 16, 16))
	assert_str(StatusTip.shown_key()).is_equal("")
	assert_str(StatusTip.shown_text()).is_equal("Poison ×1\nBurn ×1")
