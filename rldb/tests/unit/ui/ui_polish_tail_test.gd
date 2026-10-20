extends GdUnitTestSuite
## H1 polish tail and leftovers (design review #33, #37, #49, #59, #66, #67, #82, #92): the prompt
## title split, the series medallion, the draft slots, the pause panel's wait count and the count
## tag. Nothing here writes a user file.


# ---------------------------------------------------------------- #33 prompt title

func test_a_title_ending_with_the_card_name_splits_it_onto_its_own_line() -> void:
	var parts := GamePromptBanner.split_title("Choose a stance for Bastion Wyrm, the Eternal Guardian.", "Bastion Wyrm, the Eternal Guardian")
	assert_array(parts).is_equal(["Choose a stance for", "Bastion Wyrm, the Eternal Guardian"])


func test_other_titles_stay_whole() -> void:
	assert_array(GamePromptBanner.split_title("Choose a target", "Basic Mage")).is_equal(["Choose a target", ""])
	assert_array(GamePromptBanner.split_title("Basic Mage attacks: respond?", "Basic Mage")).is_equal(["Basic Mage attacks: respond?", ""])
	assert_array(GamePromptBanner.split_title("Place Basic Mage in a zone", "Basic Mage")).is_equal(["Place Basic Mage in a zone", ""])
	assert_array(GamePromptBanner.split_title("Summon Hydra", "Hydra")).is_equal(["Summon Hydra", ""])   # one word left: no split


# ---------------------------------------------------------------- #49 series medallion

func test_medallion_sockets_follow_the_series() -> void:
	var m: SeriesMedallion = auto_free(SeriesMedallion.new().setup(3, [0, 1], 2))
	assert_str(m.socket_state(0)).is_equal("won")
	assert_str(m.socket_state(1)).is_equal("lost")
	assert_str(m.socket_state(2)).is_equal("next")


func test_medallion_of_a_finished_series_has_no_next_socket() -> void:
	var m: SeriesMedallion = auto_free(SeriesMedallion.new().setup(3, [0, 0], -1))
	assert_str(m.socket_state(2)).is_equal("empty")


# ---------------------------------------------------------------- #59 draft slots

func test_draft_slots_show_every_pick_in_rows_of_four() -> void:
	var s: DraftSlots = auto_free(DraftSlots.new().setup(20, ["unit", "spell"]))
	assert_int(s.total).is_equal(20)
	assert_int(s.kinds.size()).is_equal(2)
	var rows := 5
	assert_float(s.custom_minimum_size.y).is_equal(rows * DraftSlots.SLOT.y + (rows - 1) * DraftSlots.GAP.y + 8.0)
	s.size = s.custom_minimum_size
	assert_float(s.slot_pos(4).y).is_greater(s.slot_pos(3).y)
	assert_float(s.slot_pos(4).x).is_equal(s.slot_pos(0).x)


func test_draft_slots_never_hide_a_pick() -> void:
	var s: DraftSlots = auto_free(DraftSlots.new().setup(2, ["unit", "spell", "trap"]))
	assert_int(s.total).is_equal(3)


# ---------------------------------------------------------------- #67 pause

func test_pause_wait_counts_minutes_and_seconds() -> void:
	var e: GameSeriesOverlay.Elapsed = auto_free(GameSeriesOverlay.Elapsed.new(Time.get_ticks_msec() - 75500))
	assert_str(e.text).is_equal("Waiting 1:15")


# ---------------------------------------------------------------- #82 count tag

func test_count_tag_is_a_dark_chip_not_a_gold_button() -> void:
	var t: PanelContainer = auto_free(DeckBuilder.count_tag())
	var sb := t.get_theme_stylebox("panel")
	assert_bool(sb is DepthBox).is_true()
	assert_bool((sb as DepthBox).base.bg_color.v < 0.35).is_true()
	var l := t.get_node("Text") as Label
	assert_bool(l.get_theme_color("font_color").is_equal_approx(UIStyle.GOLD_HI)).is_true()
