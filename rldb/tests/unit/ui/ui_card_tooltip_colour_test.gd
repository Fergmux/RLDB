extends GdUnitTestSuite
## H8 (owner feedback 21 Oct 2026): the card tooltip colours its separate effect and info sections
## like the right details panel (the same timing colours and accent-bar blocks).


func _blocks(t: Control, name: String) -> Array:
	return t.find_children("*", "PanelContainer", true, false).filter(func(n): return String(n.get_meta(&"tip_section", "")) == name)


func test_card_tooltip_has_one_coloured_block_per_rules_part() -> void:
	# Arrange: Ultimate Dragon (Materials, Once per turn, On Destruction)
	var v := MatchView.def_view(151)
	# Act
	var t: Control = auto_free(StatusHelp.card_tooltip(v))
	# Assert
	var rules := _blocks(t, "TipRule")
	assert_int(rules.size()).is_equal(3)
	assert_object((rules[0] as PanelContainer).get_theme_stylebox("panel")).is_instanceof(StyleBoxFlat)
	var bar := ((rules[0] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat).border_color
	var want := CardDetailsPanel.timing_color("Materials")
	assert_float(bar.r).is_equal_approx(want.r, 0.01)
	assert_float(bar.b).is_equal_approx(want.b, 0.01)


func test_card_tooltip_status_blocks_use_buff_and_debuff_colours() -> void:
	var t: Control = auto_free(StatusHelp.card_tooltip(MatchView.def_view(151)))
	var st := _blocks(t, "TipStatus")
	assert_int(st.size()).is_greater_equal(1)
	var bar := ((st[0] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat).border_color
	assert_float(bar.r).is_equal_approx(UIStyle.BAD.r, 0.01)


func test_card_tooltip_keeps_caller_lines_around_the_card() -> void:
	var v := MatchView.def_view(62)
	var text := "Target\n" + CardText.tooltip_for(v) + "\n\nRight-click to inspect"
	var t: Control = auto_free(StatusHelp.tooltip_for_card(v, text))
	assert_str(String(t.name)).is_equal("CardTooltip")
	var labels := t.find_children("*", "Label", true, false).map(func(l): return String((l as Label).text))
	assert_array(labels).contains(["Target", "Right-click to inspect"])


func test_hidden_card_gets_no_card_tooltip() -> void:
	assert_object(StatusHelp.card_tooltip({"hidden": true})).is_null()


func test_unrelated_text_keeps_the_plain_tooltip() -> void:
	var v := MatchView.def_view(62)
	assert_object(StatusHelp.tooltip_for_card(v, "Pick something")).is_null()
