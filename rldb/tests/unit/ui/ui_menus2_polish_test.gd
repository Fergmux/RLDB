extends GdUnitTestSuite
## H1 menus pass, part 2 (design review WP-7 / WP-8 menus side, D3, D5): the OrnatePanel headline
## and open / close motion (#106), the deck select (#53-#55, #58), the draft offer and pips (#56,
## #57), the rewards and deck select SECTION headers, the tutorial menu rows (#97), the tutorial
## sidebar header, footer and hint (#98-#101) and the lesson / tutorial complete cards (#102,
## #103). Nothing here writes a settings file or a deck: tutorial progress runs in memory.

var _rm: bool


func before_test() -> void:
	_rm = UIStyle.reduce_motion
	UIStyle.reduce_motion = false


func after_test() -> void:
	UIStyle.reduce_motion = _rm


# ---------------------------------------------------------------- OrnatePanel (#106, D3)

func test_ornate_headline_is_a_screen_title_over_a_rule() -> void:
	# Arrange
	var p: OrnatePanel = auto_free(OrnatePanel.new(12, 24))
	# Act
	var t := p.add_headline("Deck locked in")
	# Assert: SCREEN tier, upper case, at the top of the content column with the rule under it.
	assert_int(t.tier).is_equal(TitleText.Tier.SCREEN)
	assert_int(t.font_size).is_equal(OrnatePanel.HEADLINE_PX)
	assert_str(t.text).is_equal("DECK LOCKED IN")
	var v := p.content()
	assert_object(v.get_child(0)).is_same(t)
	assert_bool(v.get_child(1) is Ornate.Rule).is_true()


func test_ornate_headline_respects_index_and_is_reused() -> void:
	var p: OrnatePanel = auto_free(OrnatePanel.new())
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(Control.new())
	var t := p.add_headline("First", 24, true, 1)
	assert_object(p.content()).is_same(v)
	assert_object(v.get_child(1)).is_same(t)
	var again := p.add_headline("Second")
	assert_object(again).is_same(t)
	assert_str(t.text).is_equal("SECOND")
	assert_int(v.get_child_count()).is_equal(3)


func test_ornate_appear_fades_in_and_settles() -> void:
	# Arrange
	var p: OrnatePanel = OrnatePanel.new()
	p.size = Vector2(200, 120)
	add_child(p)
	# Act
	p.appear()
	# Assert: starts transparent and scaled down, ends at rest.
	assert_float(p.modulate.a).is_less(0.05)
	assert_float(p.scale.x).is_less(1.0)
	await await_millis(600)
	assert_float(p.modulate.a).is_equal_approx(1.0, 0.001)
	assert_vector(p.scale).is_equal_approx(Vector2.ONE, Vector2(0.001, 0.001))
	p.free()


func test_ornate_appear_under_reduce_motion_is_a_fade_only() -> void:
	UIStyle.reduce_motion = true
	var p: OrnatePanel = OrnatePanel.new()
	p.size = Vector2(200, 120)
	add_child(p)
	p.appear()
	assert_vector(p.scale).is_equal(Vector2.ONE)
	await await_millis(300)
	assert_float(p.modulate.a).is_equal_approx(1.0, 0.001)
	p.free()


func test_ornate_dismiss_frees_once_and_runs_done() -> void:
	var p: OrnatePanel = OrnatePanel.new()
	p.size = Vector2(200, 120)
	add_child(p)
	var calls := [0]
	p.dismiss(true, func(): calls[0] += 1)
	p.dismiss(true, func(): calls[0] += 10)   # ignored: already closing
	assert_bool(p.dismissing).is_true()
	assert_int(p.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	await await_millis(500)
	assert_bool(is_instance_valid(p)).is_false()
	assert_int(calls[0]).is_equal(1)


func test_ornate_reopen_after_dismiss_restores_clicks() -> void:
	var p: OrnatePanel = OrnatePanel.new()
	p.size = Vector2(200, 120)
	add_child(p)
	p.dismiss(false)
	await await_millis(400)
	assert_bool(p.visible).is_false()
	p.visible = true
	p.appear(false)
	assert_bool(p.dismissing).is_false()
	assert_int(p.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	p.free()


func test_wait_plate_uses_the_screen_headline_under_its_rune() -> void:
	var w: WaitPlate = auto_free(WaitPlate.new("Deck locked in", "Waiting", [{"text": "A", "done": true}]))
	assert_object(w.headline).is_not_null()
	assert_int(w.headline.tier).is_equal(TitleText.Tier.SCREEN)
	assert_bool(w.content().get_child(0) is WaitPlate.Rune).is_true()
	assert_object(w.content().get_child(1)).is_same(w.headline)


# ---------------------------------------------------------------- deck select (#53-#55, #58)

func test_deck_select_empty_custom_is_a_flat_empty_state() -> void:
	# Arrange
	var dv := DeckSelectView.new(null)
	# Act
	var es: Control = auto_free(dv._empty_custom())
	# Assert: no frame nested in the modal's frame, a 44 px secondary action (#54, #55).
	assert_bool(es is OrnatePanel).is_false()
	assert_array(es.find_children("*", "OrnatePanel", true, false)).is_empty()
	assert_array(es.find_children("*", "EngravedIcon", true, false)).has_size(1)
	var b: Button = es.find_child("Action", true, false)
	assert_object(b).is_not_null()
	assert_float(b.custom_minimum_size.y).is_equal(float(UIStyle.BUTTON_H["standard"]))


func test_folder_tabs_trailing_slot_keeps_the_inset_from_the_frame() -> void:
	# Arrange
	var ft: FolderTabs = auto_free(FolderTabs.new())
	ft.add_tab("a", "Structure")
	ft.set_trailing(UIStyle.label("hint", 13))
	# Act
	ft.size = Vector2(1000, 300)
	var r := ft.trailing_rect()
	# Assert: 24 px from the pane's right frame (#58), on the closed tabs' label band.
	assert_float(ft.trailing_inset).is_equal(24.0)
	assert_float(r.end.x).is_equal_approx(1000.0 - 24.0, 0.01)
	assert_float(r.position.y).is_equal_approx(FolderTabs.DROP * 0.6, 0.01)
	assert_float(r.end.y).is_equal_approx(ft.tab_height, 0.01)


func test_folder_tabs_baseline_shift_aligns_a_smaller_face() -> void:
	var ft: FolderTabs = auto_free(FolderTabs.new())
	# The same face and size needs no shift; a smaller face moves down onto the baseline.
	assert_float(ft.baseline_shift(UIStyle.font_display(600), ft.font_size)).is_equal_approx(0.0, 0.001)
	assert_float(ft.baseline_shift(UIStyle.font_italic(), 13)).is_greater(0.0)
	ft.set_trailing(UIStyle.label("hint", 13), UIStyle.font_italic(), 13)
	var m: MarginContainer = ft.find_child("Baseline", true, false)
	assert_object(m).is_not_null()
	assert_int(m.get_theme_constant("margin_top")).is_greater(0)


# ---------------------------------------------------------------- draft (#56, #57)

func test_draft_offer_cards_are_larger_on_tall_windows() -> void:
	assert_float(DeckSelectView.offer_width(1000.0)).is_equal(DeckSelectView.OFFER_W)
	assert_float(DeckSelectView.offer_width(900.0)).is_equal(DeckSelectView.OFFER_W_SHORT)
	assert_float(DeckSelectView.OFFER_W_SHORT).is_greater(float(CardWidget.SIZES["big"].x))


func test_draft_offer_sig_changes_with_the_offer_only() -> void:
	var a := {"step": 3, "category": "unit", "offer": [{"id": 1}, {"id": 2}]}
	var b := {"step": 3, "category": "unit", "offer": [{"id": 1}, {"id": 2}], "left": {"unit": 4}}
	var c := {"step": 4, "category": "unit", "offer": [{"id": 1}, {"id": 2}]}
	assert_int(DeckSelectView.offer_sig(a)).is_equal(DeckSelectView.offer_sig(b))
	assert_int(DeckSelectView.offer_sig(a)).is_not_equal(DeckSelectView.offer_sig(c))


func test_draft_pips_group_in_fours() -> void:
	# Arrange / Act
	var gap_in := DeckSelectView.DraftPips.pip_x(3) - DeckSelectView.DraftPips.pip_x(2)
	var gap_group := DeckSelectView.DraftPips.pip_x(4) - DeckSelectView.DraftPips.pip_x(3)
	# Assert
	assert_float(gap_in).is_equal(DeckSelectView.PIP_PITCH)
	assert_float(gap_group).is_equal(DeckSelectView.PIP_PITCH + DeckSelectView.PIP_GROUP_GAP)
	assert_float(DeckSelectView.DraftPips.row_width(20)).is_equal(20 * DeckSelectView.PIP_PITCH + 4 * DeckSelectView.PIP_GROUP_GAP)
	var p: Control = auto_free(DeckSelectView.DraftPips.new(0, 40))
	assert_float(p.custom_minimum_size.x).is_equal(DeckSelectView.DraftPips.row_width(DeckSelectView.PIP_MAX))


# ---------------------------------------------------------------- rewards SECTION headers

func test_reward_captions_are_section_titles() -> void:
	var cap: Label = auto_free(GameRewardPanels.section_caption("Rewards chosen"))
	var tt: TitleText = cap.get_meta(&"title_text")
	assert_int(tt.tier).is_equal(TitleText.Tier.SECTION)
	assert_bool(tt.show_underline).is_false()
	assert_str(cap.text).is_equal("REWARDS CHOSEN")


func test_reward_sub_panel_title_is_a_section_title() -> void:
	var pv: Array = GameRewardPanels._reward_panel("Choose a card type", "")
	auto_free(pv[0])
	var t: Label = (pv[0] as Node).find_child("PanelTitle", true, false)
	assert_int((t.get_meta(&"title_text") as TitleText).tier).is_equal(TitleText.Tier.SECTION)
