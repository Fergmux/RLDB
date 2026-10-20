extends GdUnitTestSuite
## F03-03 / F03-22 / F03-23: tag sizing, Modifiers lists only real changes, the Protecting tag.

const AURA_UNIT := 20       # ATK/DEF aura from opposing units (dynamic modifiers)


func _panel() -> CardDetailsPanel:
	return auto_free(CardDetailsPanel.new())


func _unit_view(extra: Dictionary = {}) -> Dictionary:
	var v := {"uid": 1, "name": "Test", "category": "unit", "cost_kind": "ap", "cost_text": "3 AP", "cost": 3, "printed_cost": 3,
		"zone": "unit", "statuses": {}, "runes": 0, "text": "", "text_parts": [], "support": "full",
		"race": "Mage", "type": "Fire", "printed_atk": 10, "printed_def": 10, "atk": 10, "def": 10, "stat_parts": ["Base 10/10"],
		"stance": "atk"}
	v.merge(extra, true)
	return v


func test_modifiers_section_omits_the_base_line() -> void:
	var p := _panel()
	p.show_card(_unit_view({"atk": 14, "stat_parts": ["Base 10/10", "Buff +4/+0 (this turn)"]}))
	assert_bool(p.all_text().contains("Modifiers")).is_true()
	assert_bool(p.all_text().contains("Buff +4/+0")).is_true()
	assert_bool(p.all_text().contains("Base 10/10")).is_false()


func test_unmodified_card_has_no_modifiers_section() -> void:
	var p := _panel()
	p.show_card(_unit_view())
	assert_bool(p.all_text().contains("Modifiers")).is_false()
	assert_array(CardDetailsPanel.modifier_parts(_unit_view())).is_empty()


func test_base_stats_stay_in_the_stat_tiles() -> void:
	var p := _panel()
	p.show_card(_unit_view({"atk": 14, "stat_parts": ["Base 10/10", "Buff +4/+0"]}))
	assert_int(p.count_text("Base: 10")).is_equal(2)


func test_real_modifier_on_a_live_unit_is_listed_without_base() -> void:
	var m := TB.make()
	var uid := TB.unit(m, 0, AURA_UNIT, 0)
	TB.unit(m, 1, 1, 0)
	TB.unit(m, 1, 1, 1)
	var v := MatchView.card_view(m, uid, 0)
	for part in CardDetailsPanel.modifier_parts(v):
		assert_bool(String(part).begins_with("Base ")).is_false()
	assert_int(v["stat_parts"].size() - CardDetailsPanel.modifier_parts(v).size()).is_equal(1)


func test_protecting_true_for_front_unit_with_a_unit_directly_behind() -> void:
	var m := TB.make()
	var front := TB.unit(m, 0, 1, 0)
	var rear := TB.unit(m, 0, 1, 3)
	assert_bool(MatchView.card_view(m, front, 0)["protecting"]).is_true()
	assert_bool(MatchView.card_view(m, front, 0)["protected"]).is_false()
	assert_bool(MatchView.card_view(m, rear, 0)["protected"]).is_true()
	assert_bool(MatchView.card_view(m, rear, 0)["protecting"]).is_false()


func test_protecting_false_when_the_rear_zone_is_empty() -> void:
	var m := TB.make()
	var front := TB.unit(m, 0, 1, 0)
	assert_bool(MatchView.card_view(m, front, 0)["protecting"]).is_false()


func test_protecting_false_for_a_diagonal_rear_unit() -> void:
	var m := TB.make()
	var front := TB.unit(m, 0, 1, 0)
	TB.unit(m, 0, 1, 4)      # rear row, next column
	assert_bool(MatchView.card_view(m, front, 0)["protecting"]).is_false()


func test_protection_tags_are_not_shown_in_the_details() -> void:
	# J8 (owner, 22 Oct): no Protected / Protecting tags in the details pane (the flags stay in the view).
	var p := _panel()
	p.show_card(_unit_view({"protecting": true, "protected": true}))
	assert_bool(p.all_text().contains("Protecting")).is_false()
	assert_bool(p.all_text().contains("Protected")).is_false()


func test_tags_with_and_without_icons_share_one_height() -> void:
	var p := _panel()
	add_child(p)
	p.show_card(_unit_view({"protecting": true}))
	await await_idle_frame()
	await await_idle_frame()
	var heights := []
	for ch in p.get_children():
		if ch is HFlowContainer:
			for chip in ch.get_children():
				heights.append(int((chip as Control).size.y))
	assert_int(heights.size()).is_greater_equal(4)   # category, cost, race, type
	for h in heights:
		assert_int(h).is_equal(heights[0])
