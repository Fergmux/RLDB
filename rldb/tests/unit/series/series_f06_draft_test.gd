extends GdUnitTestSuite
## F06-04 "Change basic units" (every basic unit at once, one pick, no-op refused), F06-06 (no
## basic category; the chosen basic unit arrives as `basic_copies` copies) and the owner's
## 2026-10-18 draft: no setup step, categories drafted in any order (an offer is kept when you
## switch away), the basic unit changeable at any time. Design: design/playtest-feedback-06.md.

const FIRE_DRAGON := 111
const WATER_BEAST := 4
const HEAVENLY_WARRIOR := 107


func _rewards_series() -> Series:
	var s := Series.new()
	s.setup({"seed": 11, "best_of": 3})
	s.submit(0, {"t": "pick_starter", "index": 0})
	s.submit(1, {"t": "pick_starter", "index": 1})
	s.submit(s.game.active, {"t": "concede"})
	return s


func _draft_series(quota: Dictionary = {}) -> Series:
	var s := Series.new()
	var o := {"seed": 5, "deck_mode": "draft"}
	if not quota.is_empty():
		o["draft_quota"] = quota
	s.setup(o)
	return s


func _basics(deck: Array) -> Array:
	return deck.filter(func(id): return CardDB.get_def(id)["category"] == "basic_unit")


# ---------------------------------------------------------------- F06-04

func test_f06_04_reward_changes_every_basic_unit_and_spends_one_pick() -> void:
	var s := _rewards_series()
	# After rewards a deck can hold several basic ids: make that so.
	s.decks[0].append(HEAVENLY_WARRIOR)
	var n := _basics(s.decks[0]).size()
	assert_int(n).is_greater(3)
	var size_before: int = s.decks[0].size()
	assert_str(s.submit(0, {"t": "reward_basic", "to_type": "Fire", "to_race": "Dragon"})).is_empty()
	assert_int(s.rewards[0]["left"]).is_equal(3)
	assert_int(s.decks[0].size()).is_equal(size_before)
	assert_int(s.decks[0].count(FIRE_DRAGON)).is_equal(n)
	assert_int(_basics(s.decks[0]).size()).is_equal(n)
	assert_str(String(s.rewards[0]["taken"][-1])).is_equal("Changed %d basic units to Basic Dragon (Fire)" % n)


func test_f06_04_no_op_change_is_refused_without_spending_a_pick() -> void:
	var s := _rewards_series()
	var b: int = _basics(s.decks[0])[0]
	var d := CardDB.get_def(b)
	var err := s.submit(0, {"t": "reward_basic", "to_type": d["type"], "to_race": d["race"]})
	assert_str(err).contains("already")
	assert_int(s.rewards[0]["left"]).is_equal(4)
	assert_str(s.submit(0, {"t": "reward_basic", "to_type": "Nope", "to_race": "Mage"})).contains("Type and a Race")
	assert_int(s.rewards[0]["left"]).is_equal(4)


func test_f06_04_mixed_basics_matching_one_id_still_change() -> void:
	var s := _rewards_series()
	for i in s.decks[0].size():
		if CardDB.get_def(s.decks[0][i])["category"] == "basic_unit":
			s.decks[0][i] = FIRE_DRAGON
	s.decks[0].append(WATER_BEAST)
	# Not a no-op: one basic unit is not yet a Fire Dragon.
	assert_str(s.submit(0, {"t": "reward_basic", "to_type": "Fire", "to_race": "Dragon"})).is_empty()
	assert_int(s.decks[0].count(WATER_BEAST)).is_equal(0)


func test_f06_04_legacy_from_id_command_keeps_that_race() -> void:
	var s := _rewards_series()
	s.decks[0].append(WATER_BEAST)
	assert_str(s.submit(0, {"t": "reward_basic", "from_id": WATER_BEAST, "to_type": "Fire"})).is_empty()
	var fire_beast := Series.basic_for("Fire", "Beast")
	assert_bool(_basics(s.decks[0]).all(func(id): return id == fire_beast)).is_true()


func test_f06_04_no_basic_units_is_explained() -> void:
	var s := _rewards_series()
	s.decks[0] = s.decks[0].filter(func(id): return CardDB.get_def(id)["category"] != "basic_unit")
	assert_str(s.submit(0, {"t": "reward_basic", "to_type": "Fire", "to_race": "Dragon"})).contains("no basic units")


# ---------------------------------------------------------------- F06-06

func test_f06_06_composition_has_no_basic_category() -> void:
	assert_bool("basic" in Series.DRAFT_CATEGORIES).is_false()
	assert_bool(Series.DRAFT_LABELS.has("basic")).is_false()
	assert_bool(Series.default_draft_quota().has("basic")).is_false()
	assert_bool(Series.load_mode_config()["draft"]["quota"].has("basic")).is_false()
	# A pre-F06-06 override with a basic count is accepted and the count ignored.
	var s := _draft_series({"basic": 1, "unit": 2})
	assert_bool(s.cfg["draft"]["quota"].has("basic")).is_false()
	assert_int(int(s.view_for(0)["draft"]["total"])).is_equal(2)
	assert_str(Series.validate_draft_quota({"basic": 1, "unit": 2})).is_empty()


func test_f06_06_chosen_basic_unit_gives_basic_copies_copies() -> void:
	var s := _draft_series({"unit": 1, "spell": 1})
	var copies := int(s.cfg["draft"]["basic_copies"])
	assert_int(copies).is_equal(3)
	assert_str(s.submit(0, {"t": "draft_basic", "basic_type": "Light", "basic_race": "Warrior"})).is_empty()
	assert_int(int(s.view_for(0)["draft"]["basic"]["id"])).is_equal(HEAVENLY_WARRIOR)
	s.submit(0, {"t": "draft_pick", "index": 0})
	s.submit(0, {"t": "draft_pick", "index": 0})
	assert_bool(s.deck_ready[0]).is_true()
	assert_int(s.decks[0].count(HEAVENLY_WARRIOR)).is_equal(copies)
	assert_int(_basics(s.decks[0]).size()).is_equal(copies)
	assert_int(s.decks[0].size()).is_equal(copies + 2)


func test_basic_unit_can_change_at_any_point_of_the_draft() -> void:
	var s := _draft_series({"unit": 2})
	assert_str(s.submit(0, {"t": "draft_pick", "index": 0})).is_empty()
	assert_str(s.submit(0, {"t": "draft_basic", "basic_type": "Fire", "basic_race": "Dragon"})).is_empty()
	assert_str(s.submit(0, {"t": "draft_basic", "basic_type": "Light", "basic_race": "Warrior"})).is_empty()
	assert_str(s.submit(0, {"t": "draft_pick", "index": 0})).is_empty()
	assert_bool(s.deck_ready[0]).is_true()
	assert_array(_basics(s.decks[0])).is_equal([HEAVENLY_WARRIOR, HEAVENLY_WARRIOR, HEAVENLY_WARRIOR])


func test_f06_06_illegal_basic_choice_is_refused() -> void:
	var s := _draft_series({"unit": 1})
	var before: int = s.draft[0]["basic"]
	assert_str(s.submit(0, {"t": "draft_basic", "basic_type": "Fire", "basic_race": "Elf"})).contains("Type and a Race")
	assert_str(s.submit(0, {"t": "draft_basic"})).contains("Type and a Race")
	assert_int(s.draft[0]["basic"]).is_equal(before)


func test_f06_06_default_basic_is_first_type_and_race() -> void:
	var d := CardDB.get_def(Series.default_basic())
	assert_str(String(d["type"])).is_equal(CardDB.ELEMENTS[0])
	assert_str(String(d["race"])).is_equal(Series.basic_races()[0])
	var s := _draft_series()
	assert_int(int(s.view_for(0)["draft"]["basic"]["id"])).is_equal(Series.default_basic())


# ---------------------------------------------------------------- any-order draft (2026-10-18)

func test_draft_starts_at_once_with_the_first_category_open() -> void:
	var s := _draft_series()
	var dv: Dictionary = s.view_for(0)["draft"]
	assert_array(dv["offer"]).is_not_empty()
	assert_str(String(dv["category"])).is_equal("unit")
	assert_array(dv["categories"]).is_equal(["unit", "spell", "trap", "power", "extra"])
	assert_str(s.submit(0, {"t": "draft_pick", "index": 0})).is_empty()


func test_categories_are_drafted_in_any_order() -> void:
	var s := _draft_series({"unit": 2, "spell": 1, "trap": 0, "power": 1, "extra": 1})
	var seen := []
	for cat in ["extra", "unit", "power", "spell", "unit"]:
		assert_str(s.submit(0, {"t": "draft_category", "category": cat})).is_empty()
		var dv: Dictionary = s.view_for(0)["draft"]
		assert_str(String(dv["category"])).is_equal(cat)
		var picked := int(dv["offer"][0]["id"])
		assert_str(s.submit(0, {"t": "draft_pick", "index": 0})).is_empty()
		var c: String = CardDB.get_def(picked)["category"]
		assert_bool(c in Series.EXTRA_CATEGORIES if cat == "extra" else c == cat).override_failure_message("%s from %s" % [c, cat]).is_true()
		seen.append(cat)
	assert_bool(s.deck_ready[0]).is_true()


func test_switching_category_keeps_its_offer() -> void:
	var s := _draft_series({"unit": 2, "spell": 2})
	s.submit(0, {"t": "draft_category", "category": "spell"})
	var first: Array = s.draft[0]["offer"].duplicate()
	s.submit(0, {"t": "draft_category", "category": "unit"})
	s.submit(0, {"t": "draft_category", "category": "spell"})
	assert_array(s.draft[0]["offer"]).is_equal(first)


func test_a_finished_category_cannot_be_opened_and_the_next_one_opens() -> void:
	var s := _draft_series({"unit": 1, "spell": 1, "trap": 0, "power": 0, "extra": 0})
	s.submit(0, {"t": "draft_category", "category": "spell"})
	assert_str(s.submit(0, {"t": "draft_pick", "index": 0})).is_empty()
	assert_str(s.submit(0, {"t": "draft_category", "category": "spell"})).contains("No picks left")
	assert_str(s.submit(0, {"t": "draft_category", "category": "trap"})).contains("No picks left")
	assert_str(String(s.view_for(0)["draft"]["category"])).is_equal("unit")
	assert_int(int(s.view_for(0)["draft"]["left"]["spell"])).is_equal(0)


func test_f06_05_other_seat_offers_are_not_in_the_view() -> void:
	var s := _draft_series()
	var v0: Dictionary = s.view_for(0)
	s.view_for(1)
	var dv: Dictionary = v0["draft"]
	assert_array(dv["offer"]).is_not_empty()
	assert_array(dv["opponent"].keys()).contains_exactly_in_any_order(["setup_done", "step", "total"])
	var other_offer: Array = s.draft[1]["offer"]
	var text := var_to_str(dv["opponent"])
	for id in other_offer:
		assert_bool(text.contains(str(id))).is_false()


func test_f06_05_bot_completes_a_draft_series() -> void:
	var s := Series.new()
	s.setup({"seed": 21, "best_of": 1, "deck_mode": "draft"})
	var bots := [BotBrain.new(0, 11), BotBrain.new(1, 12)]
	var refused := []
	var steps := 0
	while s.stage != Series.STAGE_OVER and steps < 6000:
		steps += 1
		var acted := false
		for p in 2:
			var cmd: Dictionary = bots[p].series_command(s) if s.stage != Series.STAGE_GAME else bots[p].decide(s.game)
			if cmd.is_empty():
				continue
			var err := s.submit(p, cmd)
			if err != "":
				refused.append("%s -> %s" % [cmd, err])
				s.submit(p, {"t": "next_phase"} if s.stage == Series.STAGE_GAME and s.game.pending.is_empty() else {"t": "concede"})
			acted = true
			break
		if not acted:
			break
	assert_array(refused).is_empty()
	assert_str(s.stage).is_equal(Series.STAGE_OVER)
	assert_int(s.history.size()).is_equal(1)


# ---------------------------------------------------------------- network

func test_f06_net_sanitizes_draft_and_reward_commands() -> void:
	assert_str(NetSession.sanitize_command({"t": "draft_category", "category": "spell"})).is_empty()
	assert_str(NetSession.sanitize_command({"t": "draft_basic", "basic_type": "Fire", "basic_race": "Dragon"})).is_empty()
	assert_str(NetSession.sanitize_command({"t": "reward_basic", "to_type": "Fire", "to_race": "Dragon"})).is_empty()
	assert_str(NetSession.sanitize_command({"t": "reward_basic", "from_id": 4.0, "to_type": "Fire"})).is_empty()
	assert_str(NetSession.sanitize_command({"t": "draft_category", "category": 3})).is_not_empty()
	assert_str(NetSession.sanitize_command({"t": "draft_basic", "basic_type": 7})).is_not_empty()
	assert_str(NetSession.sanitize_command({"t": "draft_basic", "basic_colour": "red"})).is_not_empty()


# ---------------------------------------------------------------- Add a basic unit (2026-10-18)

func test_add_a_basic_unit_reward_copies_the_decks_basic_and_spends_a_pick() -> void:
	var s := _rewards_series()
	var basic := Series.deck_basic(s.decks[0])
	assert_int(basic).is_not_equal(-1)
	var n: int = s.decks[0].count(basic)
	var size_before: int = s.decks[0].size()
	assert_str(s.submit(0, {"t": "reward_extra_basic"})).is_empty()
	assert_int(s.decks[0].size()).is_equal(size_before + 1)
	assert_int(s.decks[0].count(basic)).is_equal(n + 1)
	assert_int(s.rewards[0]["left"]).is_equal(3)
	assert_str(String(s.rewards[0]["taken"][-1])).is_equal("Added another %s" % Series.basic_label(basic))


func test_add_a_basic_unit_matches_the_most_common_basic() -> void:
	assert_int(Series.deck_basic([WATER_BEAST, FIRE_DRAGON, FIRE_DRAGON, 13])).is_equal(FIRE_DRAGON)
	assert_int(Series.deck_basic([13, 20])).is_equal(-1)


func test_add_a_basic_unit_without_basics_is_refused_and_keeps_the_pick() -> void:
	var s := _rewards_series()
	s.decks[0] = s.decks[0].filter(func(id): return CardDB.get_def(id)["category"] != "basic_unit")
	assert_str(s.submit(0, {"t": "reward_extra_basic"})).contains("no basic units")
	assert_int(s.rewards[0]["left"]).is_equal(4)
