extends GdUnitTestSuite
## D12 (owner feedback 20 Oct 2026): hoverable status words are coloured and underlined wherever they
## are written, and their effect text no longer says "(buff)" / "(debuff)" (the classification stays
## in data: CardDB.is_buff / is_debuff).


func after_test() -> void:
	StatusTip.hide_for(null)


func test_status_effect_text_has_no_buff_or_debuff_tag() -> void:
	for k in CardDB.STATUS_HELP:
		var t := String(CardDB.STATUS_HELP[k])
		assert_str(t).not_contains("(buff)")
		assert_str(t).not_contains("(debuff)")
		assert_str(StatusHelp.describe(k)).is_equal(t)
	assert_bool(CardDB.is_buff("pierce")).is_true()
	assert_bool(CardDB.is_debuff("poison")).is_true()


func test_linkified_status_words_are_coloured_and_underlined() -> void:
	var out := StatusHelp.linkify("Apply 1 Poison.")
	assert_str(out).contains("[color=#%s]" % UIStyle.STATUS_LINK.to_html(false))
	assert_str(out).contains("[u][url=status:poison]Poison[/url][/u]")


func test_a_watched_label_with_a_status_draws_its_own_highlighted_text() -> void:
	var l: Label = auto_free(UIStyle.label("Apply 1 Burn now", 16, UIStyle.TEXT))
	add_child(l)
	StatusHelp.watch_label(l)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(l.get_theme_color("font_color").a).is_equal(0.0)      # the ink child draws the text
	l.text = "Nothing special"
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(l.get_theme_color("font_color").a).is_equal(1.0)      # restored: no status, plain label


func test_the_details_status_row_drops_the_help_prefix() -> void:
	assert_str(CardDetailsPanel._strip_status_prefix(String(CardDB.STATUS_HELP["burn"]))).starts_with("When this unit attacks")
	assert_str(CardDetailsPanel._strip_status_prefix(String(CardDB.STATUS_HELP["rune"]))).starts_with("A unit with enough Runes")
