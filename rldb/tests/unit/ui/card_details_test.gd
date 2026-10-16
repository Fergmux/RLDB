extends GdUnitTestSuite
## CardDetailsPanel (F02-08, feedback 04): sections per card kind, full rules text exactly once,
## "Once per turn" captions, no notes / "No statuses" clutter, empty state.

const UNIT_ABIL := 23       # Auric the Divine Father: once-per-turn ability with HP cost
const UNIT_AURA := 20       # ATK/DEF aura from opposing units (dynamic modifiers)
const SPELL := 182
const TRAP := 45
const POWER := 149
const FUSION := 141
const RITUAL := 63
const ARCANE := 176


func _view(m: MatchEngine, uid: int) -> Dictionary:
	return MatchView.card_view(m, uid, 0)


func _panel() -> CardDetailsPanel:
	return auto_free(CardDetailsPanel.new())


func _assert_rules_once(p: CardDetailsPanel, v: Dictionary) -> void:
	assert_array(v["text_parts"]).is_not_empty()
	for part0 in v["text_parts"]:
		var part := CardDetailsPanel.split_once_per_turn(part0)   # "Once per turn" becomes the caption
		assert_int(p.count_text(String(part["t"]))).is_equal(1)
		assert_bool(p.all_text().contains(String(part["k"]).to_upper())).is_true()


func test_unit_with_statuses_modifiers_and_abilities() -> void:
	var m := TB.make()
	var uid := TB.unit(m, 0, UNIT_ABIL, 0)
	m.cards[uid]["st"]["burn"] = 3
	m.cards[uid]["st"]["retain"] = 1
	m.cards[uid]["runes"] = 2
	TB.unit(m, 1, 1, 0)
	var v := _view(m, uid)
	var p := _panel()
	p.show_card(v, ["Cannot attack: it is not your Battle Phase."])
	for s in ["identity", "stats", "rules", "statuses"]:
		assert_bool(p.sections.has(s)).is_true()
	assert_bool(p.sections.has("notes")).is_false()          # feedback 04: no Notes section
	_assert_rules_once(p, v)
	for a in v["abilities"]:
		# Never duplicated; omitted when the rules text already states it.
		assert_int(p.count_text(String(a["label"]))).is_less_equal(1)
	assert_bool(p.all_text().contains("ONCE PER TURN")).is_true()
	assert_bool(p.all_text().contains("On-card buttons".to_upper())).is_false()
	assert_bool(p.all_text().contains("Burn ×3")).is_true()
	assert_bool(p.all_text().contains("Retain ×1")).is_true()
	assert_bool(p.all_text().contains("Rune ×2")).is_true()
	assert_bool(p.all_text().contains("Debuff")).is_true()
	assert_bool(p.all_text().contains("Buff")).is_true()
	assert_bool(p.all_text().contains(String(v["race"]))).is_true()
	assert_bool(p.all_text().contains("Race:")).is_false()
	assert_bool(p.all_text().contains("Attack stance")).is_true()
	assert_int(p.count_text("Cannot attack")).is_equal(0)
	# The burn explanation appears once, without repeating the status name prefix.
	assert_int(p.count_text("its controller loses HP equal to Burn")).is_equal(1)


func test_unit_modifiers_listed_once() -> void:
	var m := TB.make()
	var uid := TB.unit(m, 0, UNIT_AURA, 0)
	TB.unit(m, 1, 1, 0)
	TB.unit(m, 1, 1, 1)
	var v := _view(m, uid)
	var p := _panel()
	p.show_card(v, [])
	assert_bool(v.get("stat_parts", []).is_empty()).is_false()
	assert_bool(p.all_text().contains("Modifiers")).is_true()
	for part in v["stat_parts"]:
		assert_int(p.count_text(String(part))).is_equal(1)
	assert_bool(p.all_text().contains(str(v["atk"]))).is_true()


func test_stat_markers_and_flags() -> void:
	var v := {"uid": 1, "name": "Test", "category": "unit", "cost_kind": "ap", "cost_text": "3 AP", "cost": 3, "printed_cost": 2,
		"zone": "unit", "statuses": {}, "runes": 0, "text": "", "text_parts": [], "support": "full",
		"race": "Mage", "type": "", "printed_atk": 10, "printed_def": 10, "atk": 14, "def": 6, "stat_parts": ["+4 ATK from X"],
		"stance": "def", "protected": true, "attacked": true, "new": true, "controlled_until": 5}
	var p := _panel()
	p.show_card(v, [])
	var t := p.all_text()
	assert_bool(t.contains("No type")).is_true()
	assert_bool(t.contains("Type:")).is_false()
	assert_bool(t.contains("3 AP (base 2)")).is_true()
	assert_bool(t.contains("Cost")).is_false()
	assert_bool(t.contains("Defense stance")).is_true()
	assert_bool(t.contains("Protected")).is_true()
	assert_bool(t.contains("Summoned this turn")).is_false()   # feedback 04: tags removed
	assert_bool(t.contains("Attacked this turn")).is_false()
	assert_bool(t.contains("Controlled until end of turn 5")).is_true()
	assert_bool(t.contains("No statuses.")).is_false()         # nothing shown when there are none
	assert_bool(t.contains("No effect text.")).is_false()
	assert_bool(p.sections.has("rules")).is_false()          # no effect: no Rules section
	assert_int(p.count_text("Base: 10")).is_equal(2)
	assert_int(p.count_text("printed 10")).is_equal(0)


func _non_unit(id: int, zone: String) -> Dictionary:
	var m := TB.make()
	var uid: int
	if zone == "backrow":
		uid = TB.set_card(m, 0, id, 0)
	else:
		uid = TB.card(m, 0, id, zone)
	return _view(m, uid)


func test_spell_has_no_unit_sections() -> void:
	var v := _non_unit(SPELL, "hand")
	var p := _panel()
	p.show_card(v, [])
	assert_bool(p.sections.has("identity")).is_true()
	assert_bool(p.sections.has("rules")).is_true()
	assert_bool(p.sections.has("stats")).is_false()
	assert_bool(p.sections.has("statuses")).is_false()
	assert_bool(p.all_text().contains("No statuses.")).is_false()
	_assert_rules_once(p, v)
	assert_bool(p.all_text().contains("Spell")).is_true()
	assert_bool(p.all_text().contains("SPELL")).is_false()       # category badge is not capitalised


func test_trap_and_power() -> void:
	var p := _panel()
	for id in [TRAP, POWER]:
		var v := _non_unit(id, "backrow" if id == TRAP else "hand")
		p.show_card(v, [])
		assert_bool(p.sections.has("stats")).is_false()
		_assert_rules_once(p, v)
		assert_bool(p.all_text().contains(String(v["name"]))).is_true()


func test_special_cost_cards_show_cost_text() -> void:
	var p := _panel()
	for id in [RITUAL, ARCANE]:
		var v := _non_unit(id, "extra")
		p.show_card(v, [])
		assert_bool(p.all_text().contains(String(v["cost_text"]))).is_true()
		assert_bool(p.sections.has("stats")).is_true()
		_assert_rules_once(p, v)


func test_empty_state() -> void:
	var p := _panel()
	p.show_card({}, [])
	assert_int(p.sections.size()).is_equal(1)
	assert_str(p.sections[0]).is_equal("empty")
	p.show_empty("Nothing here")
	assert_str(p.all_text()).is_equal("Nothing here")
	assert_int(p.sections.size()).is_equal(1)


func test_rebuild_replaces_previous_content() -> void:
	var p := _panel()
	var v1 := _non_unit(SPELL, "hand")
	var v2 := _non_unit(TRAP, "backrow")
	p.show_card(v1, [])
	p.show_card(v2, [])
	assert_bool(p.all_text().contains(String(v1["name"]))).is_false()
	assert_bool(p.all_text().contains(String(v2["name"]))).is_true()


func test_once_per_turn_lead_becomes_caption() -> void:
	var part := CardDetailsPanel.split_once_per_turn({"k": "On Field", "t": "Once per turn: you can Apply 1 Pierce to a Unit."})
	assert_str(String(part["k"])).is_equal("Once per turn")
	assert_str(String(part["t"])).is_equal("You can Apply 1 Pierce to a Unit.")
	var plain := CardDetailsPanel.split_once_per_turn({"k": "On Summon", "t": "Draw a card."})
	assert_str(String(plain["k"])).is_equal("On Summon")


func test_notes_are_not_shown() -> void:
	var v := _non_unit(SPELL, "hand")
	v["support"] = "partial"
	var p := _panel()
	p.show_card(v, ["Cannot cast: Not enough AP."])
	assert_bool(p.sections.has("notes")).is_false()
	assert_bool(p.all_text().contains("Not enough AP")).is_false()


## Feedback 07: a Fusion unit shows only the "Fusion Unit" tag, not a separate "Fusion" cost tag.
func test_fusion_unit_has_no_separate_fusion_tag() -> void:
	var v := _non_unit(FUSION, "extra")
	var p := _panel()
	p.show_card(v, [])
	var tags := []
	for ch in p.get_children():
		if ch is HFlowContainer:
			for chip in ch.get_children():
				tags.append(chip)
			break
	assert_bool(p.all_text().contains("Fusion Unit")).is_true()
	assert_int(tags.size()).is_equal(3)                   # Fusion Unit, race, type
