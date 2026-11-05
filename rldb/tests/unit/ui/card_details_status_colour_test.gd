extends GdUnitTestSuite
## Final L-batch review (design/review-final-2026-11-05.md, item b): the card details pane writes each
## status name in its badge's accent colour (CardStatusIcons.accent), not generic buff green / debuff
## red, so the row matches the badge on the card, the status tip and the application effect.

const UNIT := 23   # Auric the Divine Father: any unit will do


func _find_label(n: Node, text: String) -> Label:
	if n is Label and (n as Label).text == text:
		return n
	for c in n.get_children():
		var f := _find_label(c, text)
		if f != null:
			return f
	return null


func _panel_for(statuses: Dictionary, runes: int) -> CardDetailsPanel:
	var m := TB.make()
	var uid := TB.unit(m, 0, UNIT, 0)
	for s in statuses:
		m.cards[uid]["st"][s] = int(statuses[s])
	m.cards[uid]["runes"] = runes
	var p: CardDetailsPanel = auto_free(CardDetailsPanel.new())
	p.show_card(MatchView.card_view(m, uid, 0), [])
	return p


func test_status_names_use_each_badge_accent_colour() -> void:
	var p := _panel_for({"poison": 2, "burn": 1, "nimble": 1}, 3)
	for pair in [["Poison ×2", "poison"], ["Burn ×1", "burn"], ["Nimble ×1", "nimble"], ["Rune ×3", "rune"]]:
		var l := _find_label(p, String(pair[0]))
		assert_object(l).override_failure_message("no label %s" % pair[0]).is_not_null()
		var got: Color = l.get_theme_color("font_color")
		assert_str(got.to_html()).override_failure_message(String(pair[0])) \
			.is_equal(CardStatusIcons.accent(String(pair[1])).to_html())


func test_two_debuffs_get_different_colours() -> void:
	var p := _panel_for({"poison": 1, "burn": 1}, 0)
	var a: Color = _find_label(p, "Poison ×1").get_theme_color("font_color")
	var b: Color = _find_label(p, "Burn ×1").get_theme_color("font_color")
	assert_bool(a.is_equal_approx(b)).is_false()


func test_status_color_matches_badge_accent() -> void:
	for s in ["rune", "poison", "burn", "eternal", "cleanse"]:
		assert_str(CardDetailsPanel.status_color(s).to_html()).is_equal(CardStatusIcons.accent(s).to_html())
