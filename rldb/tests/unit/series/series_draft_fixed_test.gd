extends GdUnitTestSuite
## Owner feedback 22 Oct, J26: the draft has a fixed composition (4 Unit, 2 Spell, 2 Trap,
## 1 Power, 3 Extra Deck) and the menu no longer offers per-category counts. Series saved with the
## old, larger composition (and the old `draft_quota` menu key) still restore and play on.
## Story: design/owner-feedback-2026-10-22.md J26.

const FIXED := {"unit": 4, "spell": 2, "trap": 2, "power": 1, "extra": 3}


func _draft_series() -> Series:
	var s := Series.new()
	s.setup({"seed": 21, "deck_mode": "draft", "best_of": 3})
	return s


func test_j26_default_composition_is_the_fixed_one() -> void:
	assert_dict(Series.default_draft_quota()).is_equal(FIXED)


func test_j26_new_draft_uses_the_fixed_counts() -> void:
	var s := _draft_series()
	assert_dict(s.draft[0]["left"]).is_equal(FIXED)
	assert_int(int(s.draft[0]["total"])).is_equal(12)
	assert_str(String(s.view_for(0)["draft"]["composition"])).is_equal("4 Unit, 2 Spell, 2 Trap, 1 Power, 3 Extra Deck")


func test_j26_drafted_deck_has_twelve_picks_and_the_basics() -> void:
	var s := _draft_series()
	var picked := {}
	var guard := 0
	while s.stage == Series.STAGE_DECKS and guard < 80:
		for p in 2:
			if s.deck_ready[p]:
				continue
			var st: Dictionary = s.draft[p]
			if int(st["step"]) < int(st["total"]):
				var cat := String(st["current"])
				assert_str(s.submit(p, {"t": "draft_pick", "index": 0})).is_empty()
				if p == 0:
					picked[cat] = int(picked.get(cat, 0)) + 1
			else:
				assert_str(s.submit(p, {"t": "draft_confirm"})).is_empty()
		guard += 1
	assert_str(s.stage).is_equal(Series.STAGE_GAME)
	assert_dict(picked).is_equal(FIXED)
	assert_int(s.decks[0].size()).is_equal(12 + int(s.cfg["draft"]["basic_copies"]))


## A series saved between games by a build with the old 9 / 3 / 3 / 2 / 3 composition, which also
## kept the menu's `draft_quota` key in its config, restores and carries on to the next game.
func test_j26_old_save_with_old_composition_restores_and_plays_on() -> void:
	var s := Series.new()
	s.setup({"seed": 4, "deck_mode": "draft", "best_of": 3,
		"draft_quota": {"unit": 9, "spell": 3, "trap": 3, "power": 2, "extra": 3}})
	# Finish both drafts the old way (the authority's quota is whatever the save says).
	var guard := 0
	while s.stage == Series.STAGE_DECKS and guard < 120:
		for p in 2:
			if s.deck_ready[p]:
				continue
			if int(s.draft[p]["step"]) < int(s.draft[p]["total"]):
				s.submit(p, {"t": "draft_pick", "index": 0})
			else:
				s.submit(p, {"t": "draft_confirm"})
		guard += 1
	s.submit(s.game.active, {"t": "concede"})
	assert_str(s.stage).is_equal(Series.STAGE_REWARDS)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s.to_save()))
	saved["cfg"]["draft"]["quota"]["basic"] = 2     # a pre-F06-06 key too
	assert_bool(Series.is_valid_save(saved)).is_true()
	var r := Series.from_save(saved)
	assert_int(r.decks[0].size()).is_equal(20 + 3)
	assert_str(r.stage).is_equal(Series.STAGE_REWARDS)
	for p in 2:
		assert_str(r.submit(p, {"t": "reward_finish"})).is_empty()
	assert_str(r.stage).is_equal(Series.STAGE_FIRST)
