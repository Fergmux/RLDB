extends GdUnitTestSuite
## Owner feedback 22 Oct, J30: drafting the last card no longer locks the deck in. The draft waits
## on "Confirm selections" (`draft_confirm`), so the basic unit can still be changed after every
## card is drafted. Each seat confirms its own draft; the series starts when both have. The bot
## confirms on its own. Story: design/owner-feedback-2026-10-22.md J30.

const SMALL := {"unit": 2, "spell": 1, "trap": 0, "power": 0, "extra": 0}


func _series() -> Series:
	var s := Series.new()
	s.setup({"seed": 13, "deck_mode": "draft", "draft_quota": SMALL})
	return s


func _pick_all(s: Series, p: int) -> void:
	var guard := 0
	while int(s.draft[p]["step"]) < int(s.draft[p]["total"]) and guard < 20:
		assert_str(s.submit(p, {"t": "draft_pick", "index": 0})).is_empty()
		guard += 1


func test_j30_last_pick_does_not_lock_the_deck_in() -> void:
	var s := _series()
	_pick_all(s, 0)
	assert_bool(s.deck_ready[0]).is_false()
	var v: Dictionary = s.view_for(0)["draft"]
	assert_bool(bool(v["complete"])).is_true()
	assert_array(v["offer"]).is_empty()
	assert_int(v["picked"].size()).is_equal(3)


func test_j30_basic_unit_can_change_after_every_card_is_drafted() -> void:
	var s := _series()
	_pick_all(s, 0)
	assert_str(s.submit(0, {"t": "draft_basic", "basic_type": "Fire", "basic_race": "Dragon"})).is_empty()
	assert_str(s.submit(0, {"t": "draft_confirm"})).is_empty()
	assert_bool(s.deck_ready[0]).is_true()
	var basic := Series.basic_for("Fire", "Dragon")
	assert_int(s.decks[0].count(basic)).is_equal(int(s.cfg["draft"]["basic_copies"]))
	assert_int(s.decks[0].size()).is_equal(3 + int(s.cfg["draft"]["basic_copies"]))


func test_j30_confirm_is_refused_until_every_card_is_drafted() -> void:
	var s := _series()
	s.submit(0, {"t": "draft_pick", "index": 0})
	assert_str(s.submit(0, {"t": "draft_confirm"})).contains("Draft")
	assert_bool(s.deck_ready[0]).is_false()


func test_j30_no_more_picks_or_tabs_once_complete() -> void:
	var s := _series()
	_pick_all(s, 0)
	assert_str(s.submit(0, {"t": "draft_pick", "index": 0})).is_not_empty()
	assert_str(s.submit(0, {"t": "draft_category", "category": "unit"})).is_not_empty()
	assert_int(s.draft[0]["picked"].size()).is_equal(3)


func test_j30_both_seats_must_confirm_before_the_first_game() -> void:
	var s := _series()
	_pick_all(s, 0)
	_pick_all(s, 1)
	assert_str(s.submit(0, {"t": "draft_confirm"})).is_empty()
	assert_str(s.stage).is_equal(Series.STAGE_DECKS)
	# The other seat sees that this one is done; its own draft still waits on its confirm.
	assert_bool(bool(s.view_for(1)["draft"]["opponent"]["complete"])).is_true()
	assert_bool(s.deck_ready[1]).is_false()
	assert_str(s.submit(1, {"t": "draft_confirm"})).is_empty()
	assert_str(s.stage).is_equal(Series.STAGE_GAME)


func test_j30_confirmed_draft_cannot_be_changed() -> void:
	var s := _series()
	_pick_all(s, 0)
	s.submit(0, {"t": "draft_confirm"})
	assert_str(s.submit(0, {"t": "draft_basic", "basic_type": "Fire", "basic_race": "Dragon"})).contains("locked")
	assert_str(s.submit(0, {"t": "draft_confirm"})).contains("locked")


func test_j30_bot_confirms_its_finished_draft() -> void:
	var s := _series()
	var bot := BotBrain.new(1, 3)
	var guard := 0
	while not s.deck_ready[1] and guard < 20:
		var cmd := bot.series_command(s)
		assert_dict(cmd).is_not_empty()
		assert_str(s.submit(1, cmd)).is_empty()
		guard += 1
	assert_bool(s.deck_ready[1]).is_true()
	assert_int(s.draft[1]["picked"].size()).is_equal(3)
