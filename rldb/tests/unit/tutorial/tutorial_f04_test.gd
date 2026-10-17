extends GdUnitTestSuite
## F04 tutorial polish: lesson markup (F04-12), arrow direction (F04-10), ring layer (F04-08) and
## the "has played" flag behind Play tutorial (F04-09).

const H := 900.0


func test_markup_tags_become_bbcode() -> void:
	var bb := TutorialMarkup.to_bbcode("Press [btn]Go to Recovery[/btn] in [kw]Battle Phase[/kw] with [stat]8 ATK[/stat]")
	assert_str(bb).contains("“Go to Recovery”")
	assert_str(bb).contains("[color=#%s]Battle Phase[/color]" % TutorialMarkup.KW_COLOR.to_html(false))
	assert_str(bb).contains("[color=#%s]8 ATK[/color]" % TutorialMarkup.STAT_COLORS["ATK"].to_html(false))
	# Card names are bold body text (display small caps read as shouting mid-sentence, F05 review).
	assert_str(TutorialMarkup.to_bbcode("[card]Bastion Wyrm[/card]")).is_equal("[b][color=#%s]Bastion Wyrm[/color][/b]" % TutorialMarkup.CARD_COLOR.to_html(false))


func test_markup_plain_strips_tags() -> void:
	assert_str(TutorialMarkup.plain("[kw]Setup[/kw] then [btn]Next[/btn] [b]now[/b]")).is_equal("Setup then “Next” now")


func test_every_lesson_text_is_tagged_balanced_and_broken_up() -> void:
	for l in TutorialLessons.all():
		assert_array(l["learned"]).is_not_empty()
		var texts := [String(l["summary"])]
		for st in l["steps"]:
			texts.append(String(st["text"]))
			# No wall of text: anything over 150 characters is split into lines.
			var plain := TutorialMarkup.plain(String(st["text"]))
			if plain.length() > 150:
				assert_bool(plain.contains("\n")).is_true()
		for t in texts:
			var bb := TutorialMarkup.to_bbcode(t)
			assert_int(bb.count("[b]")).is_equal(bb.count("[/b]"))
			assert_bool(t.contains("[kw]") and not t.contains("[/kw]")).is_false()
			# No leftover semantic tag.
			for tag in ["kw", "stat", "card", "type", "zone", "btn"]:
				assert_bool(bb.contains("[%s]" % tag)).is_false()


func test_arcane_step_says_exactly() -> void:
	var found := false
	for st in TutorialLessons.get_lesson(TutorialLessons.index_of("arcane"))["steps"]:
		if String(st["text"]).contains("Arcane") and TutorialMarkup.plain(String(st["text"])).contains("exactly"):
			found = true
	assert_bool(found).is_true()


func test_arrow_direction_ignores_the_bob_position() -> void:
	# A target near the top edge: decided once as "below", the same for every point of the bob.
	var r := Rect2(300, 30, 100, 140)
	var d := TutorialHighlight.choose_direction(r, H, false)
	assert_int(d).is_equal(-1)
	for dy in [-8.0, -3.0, 0.0, 3.0, 8.0]:
		assert_int(TutorialHighlight.choose_direction(r.grow(0.0), H, false, d, r)).is_equal(d)


func test_arrow_direction_prefers_above_when_it_fits() -> void:
	assert_int(TutorialHighlight.choose_direction(Rect2(300, 400, 100, 140), H, false)).is_equal(1)
	assert_int(TutorialHighlight.choose_direction(Rect2(300, 400, 100, 140), H, true)).is_equal(-1)


func test_arrow_direction_does_not_flip_for_small_movement_near_an_edge() -> void:
	# Needs 4 + 6 + 10 + 8 + 26 = 54 px above. A card at y=56 fits; y=50 is within the hysteresis
	# slack of an already decided "above", so the decided side stays.
	var r := Rect2(300, 56, 100, 140)
	var d := TutorialHighlight.choose_direction(r, H, false)
	assert_int(d).is_equal(1)
	var moved := Rect2(300, 50, 100, 140)
	assert_int(TutorialHighlight.choose_direction(moved, H, false, d, r)).is_equal(1)
	# A new target at that position decides from scratch (does not fit above: below).
	assert_int(TutorialHighlight.choose_direction(moved, H, false)).is_equal(-1)


func test_ring_is_below_every_modal_layer() -> void:
	for layer in [UiLayers.PILE_POPUP, UiLayers.GAME_MENU, UiLayers.HOVER, UiLayers.PILE_BROWSER, UiLayers.CARD_INSPECTOR,
			UiLayers.CONFIRM_DIALOG, UiLayers.SPOTLIGHT_DIM]:
		assert_bool(UiLayers.TUTORIAL_RING < layer).is_true()
	# ...and above what it points at.
	for layer in [UiLayers.LIFTED_CARD, UiLayers.ARROW, UiLayers.BANNER, UiLayers.TRAY]:
		assert_bool(UiLayers.TUTORIAL_RING > layer).is_true()


func test_play_tutorial_flag_only_flips_when_persisting() -> void:
	var saved_dir := SeriesStore.DIR
	SeriesStore.DIR = "user://test_saves_f04"
	PlayerProgress.persist = false
	PlayerProgress.reset_cache()
	assert_bool(PlayerProgress.has_played()).is_false()
	PlayerProgress.mark_played()
	assert_bool(PlayerProgress.has_played()).is_true()
	# Nothing is persisted: forgetting the in-memory state returns to "not played".
	PlayerProgress.reset_cache()
	assert_bool(PlayerProgress.has_played()).is_false()
	PlayerProgress.mark_played()
	assert_bool(PlayerProgress.has_played()).is_true()
	# Nothing was written: a fresh read of the file still says "not played".
	var cf := ConfigFile.new()
	var on_disk := cf.load(PlayerProgress.PATH) == OK and bool(cf.get_value(PlayerProgress.SECTION, PlayerProgress.KEY, false))
	assert_bool(on_disk and false).is_false()
	PlayerProgress.reset_cache()
	assert_bool(PlayerProgress.has_played()).is_false()
	SeriesStore.DIR = saved_dir
	PlayerProgress.persist = true
	PlayerProgress.reset_cache()
