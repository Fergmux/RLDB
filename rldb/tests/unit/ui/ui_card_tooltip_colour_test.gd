extends GdUnitTestSuite
## H8 (owner feedback 21 Oct 2026): the card tooltip colours its separate effect and info sections
## like the right details panel (the same timing colours and accent-bar blocks).


func _blocks(t: Control, name: String) -> Array:
	return t.find_children("*", "PanelContainer", true, false).filter(func(n): return String(n.get_meta(&"tip_section", "")) == name)


func test_card_tooltip_has_one_coloured_block_per_rules_part() -> void:
	# Arrange: Ultimate Dragon (Materials, On Summon since 2026-11-03, Once per turn, On Destruction)
	var v := MatchView.def_view(151)
	# Act
	var t: Control = auto_free(StatusHelp.card_tooltip(v))
	# Assert
	var rules := _blocks(t, "TipRule")
	assert_int(rules.size()).is_equal(4)
	assert_object((rules[0] as PanelContainer).get_theme_stylebox("panel")).is_instanceof(StyleBoxFlat)
	var bar := ((rules[0] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat).border_color
	var want := CardDetailsPanel.timing_color("Materials")
	assert_float(bar.r).is_equal_approx(want.r, 0.01)
	assert_float(bar.b).is_equal_approx(want.b, 0.01)


func test_card_tooltip_has_no_status_descriptions() -> void:
	# J16 (owner, 22 Oct): the card tooltip no longer explains the statuses its text names (they
	# confused); the details panel's status words still explain themselves on hover.
	# Arrange: Ultimate Dragon names a status in its rules
	var v := MatchView.def_view(151)
	var key: String = StatusHelp.keys_in(CardText.card_text(v))[0]
	var help := CardDetailsPanel._strip_status_prefix(StatusHelp.describe(key))
	# Act
	var t: Control = auto_free(StatusHelp.tooltip_for_card(v, CardText.tooltip_for(v) + "\n\nRight-click to inspect"))
	# Assert
	assert_array(_blocks(t, "TipStatus")).is_empty()
	var labels := t.find_children("*", "Label", true, false).map(func(l): return String((l as Label).text))
	for l in labels:
		assert_str(String(l)).not_contains(help)


func test_card_widget_tooltip_with_other_text_adds_no_status_section() -> void:
	# J16: a card's tooltip whose text is not its own card text falls back to the plain tooltip, never
	# to one with a status-description section.
	var v := MatchView.def_view(151)
	var key: String = StatusHelp.keys_in(CardText.card_text(v))[0]
	assert_object(StatusHelp.tooltip_for_card(v, "Apply 1 %s" % key.capitalize())).is_null()


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
