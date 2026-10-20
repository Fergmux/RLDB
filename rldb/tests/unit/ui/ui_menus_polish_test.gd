extends GdUnitTestSuite
## H1 menus pass (design review WP-2, WP-5, WP-7, WP-8, menus side): the shared settings form, the
## MENU-tier menu items, the page header, the grid gutters, the preview facts, the engraved empty
## states, the ambient motes and the main menu's header tags. Nothing here writes a settings file:
## no toggle is pressed.

var _rm: bool


func before_test() -> void:
	_rm = UIStyle.reduce_motion
	UIStyle.reduce_motion = false


func after_test() -> void:
	UIStyle.reduce_motion = _rm


# ---------------------------------------------------------------- settings form (#9-#12)

func test_settings_form_has_every_control_on_the_grid() -> void:
	# Arrange / Act
	var f: SettingsForm = auto_free(SettingsForm.new())
	# Assert: one builder for both settings screens, every option present.
	for k in ["window_mode", "aa", "music", "music_mute", "sfx", "sfx_mute", "reduce_motion", "fast_anim", "share"]:
		assert_bool(f.controls.has(k)).override_failure_message("missing " + k).is_true()
	assert_float(SettingsForm.form_width()).is_equal(SettingsForm.LABEL_W + SettingsForm.COL_GAP + SettingsForm.CONTROL_W)
	var row: Control = f.find_child("Row_window_mode", true, false)
	assert_float(row.custom_minimum_size.y).is_equal(SettingsForm.ROW_H)
	assert_vector((f.controls["window_mode"] as Control).custom_minimum_size).is_equal(SettingsForm.DROPDOWN)


func test_settings_form_extra_toggles_and_share_note() -> void:
	var f: SettingsForm = auto_free(SettingsForm.new(Callable(), [{"key": "privacy", "text": "Privacy screen", "on": true, "toggled": func(_on): pass}]))
	var cb: CheckBox = f.controls["privacy"]
	assert_bool(cb is SettingsForm.HouseCheck).is_true()
	assert_bool(cb.button_pressed).is_true()
	assert_float((cb as SettingsForm.HouseCheck).tick).is_equal(1.0)
	var note: Label = f.find_child("ShareNote", true, false)
	assert_str(note.text).is_equal(Telemetry.PRIVACY_NOTE)
	assert_int(note.get_theme_font_size("font_size")).is_equal(SettingsForm.NOTE_FONT)
	assert_int((note.get_parent() as MarginContainer).get_theme_constant("margin_left")).is_equal(SettingsForm.NOTE_INDENT)


func test_settings_form_mute_is_a_speaker_toggle() -> void:
	var f: SettingsForm = auto_free(SettingsForm.new())
	var sp: Button = f.controls["music_mute"]
	assert_bool(sp is SettingsForm.SpeakerToggle).is_true()
	assert_bool(sp.toggle_mode).is_true()
	assert_bool(sp.button_pressed).is_equal(Music.is_muted())


func test_gem_knob_is_cached() -> void:
	assert_object(SettingsForm.gem_knob(false)).is_same(SettingsForm.gem_knob(false))
	assert_int(SettingsForm.gem_knob(true).get_width()).is_equal(22)


# ---------------------------------------------------------------- menu items (#3, #4)

func test_menu_item_text_is_a_menu_tier_title() -> void:
	var mi: MenuItem = auto_free(MenuItem.new("Play", 34))
	assert_object(mi.title).is_not_null()
	assert_int(mi.title.tier).is_equal(TitleText.Tier.MENU)
	assert_str(mi.title.text).is_equal("Play")
	assert_int(mi.title.font_size).is_equal(34)


func test_menu_item_hover_blends_to_gold_and_back() -> void:
	var mi: MenuItem = auto_free(MenuItem.new("Play", 34))
	mi._to_hl(1.0)   # out of the tree: snaps
	assert_float(mi.hl).is_equal(1.0)
	assert_float(mi.title.hover).is_equal(1.0)
	mi._to_hl(0.0)
	assert_float(mi.title.hover).is_equal(0.0)


func test_active_item_stays_gold() -> void:
	var mi: MenuItem = auto_free(MenuItem.new("Settings", 34))
	mi.active = true
	assert_float(mi.title.hover).is_equal(1.0)


func test_back_item_is_muted_with_a_glyph_and_keeps_the_back_sound() -> void:
	var mi: MenuItem = auto_free(MenuItem.new("Back", MainMenu.BACK_ITEM_SIZE, true))
	assert_str(mi.title.text).is_equal(MenuItem.BACK_GLYPH + "Back")
	assert_that(mi.title.fill_color).is_equal(UIStyle.MUTED)
	assert_str(Sfx.button_sound(mi)).is_equal("back")
	# Review #4: 15% smaller than its siblings, not 30%.
	assert_float(float(MainMenu.BACK_ITEM_SIZE) / float(MainMenu.SUB_ITEM_SIZE)).is_between(0.84, 0.88)


# ---------------------------------------------------------------- main menu (#7)

func test_leaf_tags_name_section_and_context() -> void:
	assert_array(MainMenu.leaf_tags("settings")).is_equal(["Options", "This device"])
	assert_array(MainMenu.leaf_tags("credits")).is_equal(["About", "v" + SteamBridge.build_version()])
	assert_array(MainMenu.leaf_tags("bot")).is_equal(["Play · local", "Against the bot"])
	assert_str(String(MainMenu.leaf_tags("unknown")[0])).is_equal("Main menu")


func test_center_panel_title_is_a_screen_tier_title() -> void:
	var pv: Array = MainMenu._center_panel("Settings", "", "Options", "This device")
	var p: HousePanel = auto_free(pv[0])
	var tt: TitleText = p.get_meta(&"headline")
	assert_int(tt.tier).is_equal(TitleText.Tier.SCREEN)
	assert_str(p.tag_label.text).is_equal("THIS DEVICE")


# ---------------------------------------------------------------- page header (#73)

func test_page_header_has_screen_title_and_standard_back() -> void:
	var h: PageHeader = auto_free(PageHeader.new("Card Catalogue"))
	assert_str(h.title.text).is_equal("CARD CATALOGUE")
	assert_int(h.title.tier).is_equal(TitleText.Tier.SCREEN)
	assert_int(h.title.font_size).is_equal(PageHeader.TITLE_SIZE)
	assert_float(h.back.custom_minimum_size.y).is_equal(float(UIStyle.BUTTON_H["standard"]))
	assert_str(Sfx.button_sound(h.back)).is_equal("back")
	var fired := [false]
	h.back_pressed.connect(func(): fired[0] = true)
	h.back.pressed.emit()
	assert_bool(fired[0]).is_true()


# ---------------------------------------------------------------- grid gutters (#74)

func test_grid_gutters_are_equal_both_ways() -> void:
	assert_int(2 * CardBrowser.CELL_PAD + CardBrowser.GRID_MIN_GAP).is_equal(16)
	assert_int(2 * CardBrowser.CELL_PAD + CardBrowser.ROW_GAP).is_equal(16)


func test_grid_columns_and_centring_inset() -> void:
	var w := 1000.0
	var cols := CardBrowser.grid_columns(w)
	assert_int(cols).is_equal(int(floor(w / CardBrowser.CELL_W)))
	var inset := CardBrowser.grid_inset(w)
	assert_float(inset * 2.0 + cols * CardBrowser.CELL_W).is_between(w - 1.0, w)
	assert_int(CardBrowser.grid_columns(10.0)).is_equal(1)


# ---------------------------------------------------------------- preview facts (#77, #80)

func test_usage_text_counts_copies_and_decks() -> void:
	var decks := [{"name": "A", "cards": [5, 5, 7]}, {"name": "B", "cards": [5]}, {"name": "C", "cards": [9]}]
	assert_str(PreviewFacts.usage_text(5, decks)).is_equal("×3 across 2 saved decks.")
	assert_str(PreviewFacts.usage_text(9, decks)).is_equal("×1 across 1 saved deck.")
	assert_str(PreviewFacts.usage_text(4, decks)).is_equal("Not in any of your saved decks yet.")
	assert_str(PreviewFacts.usage_text(4, [])).is_equal("You have no saved decks yet.")


func test_kind_text_names_category_and_cost() -> void:
	assert_str(PreviewFacts.kind_text({"category": "basic_unit", "cost_kind": "ap", "cost": 1})).is_equal("Basic Unit  ·  1 AP")
	assert_str(PreviewFacts.kind_text({"category": "fusion", "cost_kind": "fusion", "cost": null})).is_equal("Fusion Unit  ·  Fusion summon")
	assert_str(PreviewFacts.kind_text({})).is_equal("")


func test_copy_gems_fill_and_overflow() -> void:
	var g: PreviewFacts.CopyGems = auto_free(PreviewFacts.CopyGems.new())
	g.set_count(2)
	assert_int(g._row.filled).is_equal(2)
	assert_str(g._more.text).is_equal("")
	g.set_count(5)
	assert_int(g._row.filled).is_equal(PreviewFacts.SOCKETS)
	assert_str(g._more.text).is_equal("+2")


func test_rules_placeholder_only_without_rules() -> void:
	CardDB.ensure_loaded()
	var id := int(CardDB.all()[0]["id"])
	var f: PreviewFacts = auto_free(PreviewFacts.new(true))
	f.show_card(id, false, 1)
	assert_bool(f._rules.visible).is_true()
	assert_int(f.copies_shown()).is_equal(1)
	f.show_card(id, true, 0)
	assert_bool(f._rules.visible).is_false()


# ---------------------------------------------------------------- empty states (#54, #79, #96)

func test_empty_state_has_icon_title_body_and_action() -> void:
	var called := [false]
	var e: VBoxContainer = auto_free(EngravedIcon.empty_state("magnifier", "No cards match", "Try again.", "Clear filters", func(): called[0] = true))
	assert_int(e.find_children("*", "EngravedIcon", true, false).size()).is_equal(1)
	assert_str((e.find_child("Title", true, false) as Label).text).is_equal("No cards match")
	var b: Button = e.find_child("Action", true, false)
	assert_float(b.custom_minimum_size.y).is_equal(float(UIStyle.BUTTON_H["standard"]))
	b.pressed.emit()
	assert_bool(called[0]).is_true()
	assert_bool((e as Node) is PanelContainer).is_false()   # no box: laid on the surface


func test_engraved_icon_breathes_and_rests_under_reduce_motion() -> void:
	var icon: EngravedIcon = auto_free(EngravedIcon.new("trophy", 64.0))
	icon.clock = func() -> float: return 0.6   # a quarter of the 2.4 s loop: the peak
	assert_float(icon.glow_level()).is_greater(1.0)
	UIStyle.reduce_motion = true
	assert_float(icon.glow_level()).is_equal(1.0)


# ---------------------------------------------------------------- ambient motes (#6)

func test_ambient_motes_are_deterministic() -> void:
	var a: AmbientMotes = auto_free(AmbientMotes.new(12, [], 7))
	var b: AmbientMotes = auto_free(AmbientMotes.new(12, [], 7))
	a.size = Vector2(1600, 900)
	b.size = Vector2(1600, 900)
	assert_int(a.count()).is_equal(12)
	for i in 12:
		assert_vector(a.mote_state(i, 3.0)["pos"]).is_equal(b.mote_state(i, 3.0)["pos"])


func test_ambient_motes_rest_under_reduce_motion() -> void:
	var m: AmbientMotes = auto_free(AmbientMotes.new(8))
	m.size = Vector2(1600, 900)
	assert_vector(m.mote_state(0, 1.0)["pos"]).is_not_equal(m.mote_state(0, 4.0)["pos"])
	UIStyle.reduce_motion = true
	assert_vector(m.mote_state(0, 1.0)["pos"]).is_equal(m.mote_state(0, 4.0)["pos"])


# ---------------------------------------------------------------- privacy screen (#68)

## Regression: the hand-over screen sat under the coin flip and game-end layers, so a coin flip
## played over the "Pass to" plate and its veil showed the board layout through it.
func test_privacy_backdrop_covers_the_board_fx_layers() -> void:
	var b: PrivacyBackdrop = auto_free(PrivacyBackdrop.new())
	for layer in [UiLayers.COIN_FLIP, UiLayers.GAME_END, UiLayers.PILE_POPUP, UiLayers.FX]:
		assert_int(b.z_index).is_greater(layer)
	assert_int(b.z_index).is_less(UiLayers.GAME_MENU)
	assert_int(b.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)


func test_privacy_sigil_rests_under_reduce_motion() -> void:
	var b: PrivacyBackdrop = auto_free(PrivacyBackdrop.new())
	b.clock = func() -> float: return 30.0
	assert_float(b.sigil_angle()).is_greater(0.0)
	UIStyle.reduce_motion = true
	assert_float(b.sigil_angle()).is_equal(0.0)
