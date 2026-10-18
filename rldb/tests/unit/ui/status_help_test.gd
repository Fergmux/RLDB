extends GdUnitTestSuite
## Owner feedback 2026-10-18: hovering a status name wherever it is written shows its effect; a
## tooltip that names a status gets a separate section with the effect (StatusHelp, StatusTip).

const _UNIT := {"uid": 13, "id": 13, "name": "Chaos Witch", "category": "unit", "cost_kind": "ap", "cost": 3,
	"printed_cost": 3, "zone": "hand", "slot": 0, "face_up": true, "statuses": {"poison": 2}, "runes": 0,
	"text": "On Summon: Apply 2 Poison to a Unit.", "race": "Mage", "type": "Dark", "atk": 24, "def": 28,
	"printed_atk": 24, "printed_def": 28}


func after_test() -> void:
	StatusTip.hide_for(null)


func test_status_words_and_their_inflections_are_found_with_their_keys() -> void:
	var sp := StatusHelp.spans("Apply 1 Poison. Paralysed units cannot move. 3 Runes. poison stays plain.")
	assert_array(sp.map(func(x): return x["key"])).is_equal(["poison", "paralyse", "rune"])
	assert_int(int(sp[0]["from"])).is_equal(8)
	assert_int(int(sp[0]["to"])).is_equal(14)
	assert_str(StatusHelp.key_at("Apply 1 Poison.", 10)).is_equal("poison")
	assert_str(StatusHelp.key_at("Apply 1 Poison.", 2)).is_equal("")
	assert_array(StatusHelp.keys_in("Blind then Blind and Burn")).is_equal(["blind", "burn"])


func test_linkify_wraps_plain_status_words_and_never_inside_links_or_tags() -> void:
	var src := "[color=#fff]Apply 1 [b]Burn[/b][/color] to [url=card:5]Eternal Burner[/url]."
	var out := StatusHelp.linkify(src)
	assert_str(out).contains("[url=status:burn]Burn[/url]")
	assert_str(out).contains("[url=card:5]Eternal Burner[/url]")
	assert_str(out).not_contains("status:eternal")
	assert_str(StatusHelp.linkify("No statuses here.")).is_equal("No statuses here.")


func test_a_tooltip_naming_a_status_gets_an_effect_section() -> void:
	assert_object(StatusHelp.tooltip("Summon in Attack stance")).is_null()
	var t: Control = auto_free(StatusHelp.tooltip("Apply 1 Infiltrate to a unit"))
	assert_object(t).is_not_null()
	var texts := []
	for n in t.find_children("*", "Label", true, false):
		texts.append((n as Label).text)
	assert_array(texts).contains([String(CardDB.STATUS_HELP["infiltrate"])])
	assert_array(texts).contains(["Apply 1 Infiltrate to a unit"])


func test_a_status_icon_tip_has_the_name_and_an_effect_section() -> void:
	var host: Control = auto_free(Control.new())
	add_child(host)
	var w := CardWidget.new()
	w.auto_hover = false
	w.setup(_UNIT, "hand")
	host.add_child(w)
	w.position = Vector2(40, 60)
	w.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	var h: Dictionary = w.status_hits()[0]
	var mv := InputEventMouseMotion.new()
	mv.position = (h["rect"] as Rect2).get_center()
	w._gui_input(mv)
	assert_str(StatusTip.shown_text()).is_equal("Poison ×2")
	assert_str(StatusTip.shown_detail()).is_equal(String(CardDB.STATUS_HELP["poison"]))
	StatusTip.hide_for(w)


func test_hovering_a_status_name_in_a_cards_rules_text_shows_its_effect() -> void:
	var host: Control = auto_free(Control.new())
	add_child(host)
	var v := _UNIT.duplicate(true)
	v["statuses"] = {}
	var w := CardWidget.new()
	w.auto_hover = false
	w.setup(v, "big")
	host.add_child(w)
	w.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	# Scan the card for a point over the word "Poison" in the rules text.
	var found := Vector2(-1, -1)
	var y := 0.0
	while y < w.size.y and found.x < 0:
		var x := 0.0
		while x < w.size.x:
			if w.text_status_at(Vector2(x, y)) == "poison":
				found = Vector2(x, y)
				break
			x += 2.0
		y += 2.0
	assert_float(found.x).override_failure_message("no point over 'Poison' in the rules text").is_greater_equal(0.0)
	assert_str(w._get_tooltip(found)).is_equal("")
	var mv := InputEventMouseMotion.new()
	mv.position = found
	w._gui_input(mv)
	assert_str(StatusTip.shown_detail()).is_equal(String(CardDB.STATUS_HELP["poison"]))
	assert_str(w.text_status_at(Vector2(2, 2))).is_equal("")
	StatusTip.hide_for(w)


func test_hovering_a_status_word_in_a_label_shows_its_effect() -> void:
	var l: Label = auto_free(UIStyle.label("Apply 1 Burn now", 16, UIStyle.TEXT))
	add_child(l)
	StatusHelp.watch_label(l)
	await get_tree().process_frame
	var r := l.get_character_bounds(9)                         # the "u" of Burn
	StatusHelp._label_hover(l, r.get_center())
	assert_str(StatusTip.shown_detail()).is_equal(String(CardDB.STATUS_HELP["burn"]))
	StatusHelp._label_hover(l, l.get_character_bounds(1).get_center())
	assert_str(StatusTip.shown_detail()).is_equal("")
	assert_int(l.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
