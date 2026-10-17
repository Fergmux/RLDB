extends GdUnitTestSuite
## F06-04 "Change basic units" (every basic unit at once, one pick, no-op refused), F06-05 the
## per-seat draft setup (category order followed, invalid orders refused) and F06-06 (no basic
## category; the chosen basic unit arrives as `basic_copies` copies). Design:
## design/playtest-feedback-06.md.

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
	assert_str(s.submit(0, {"t": "draft_setup", "order": ["unit", "spell"], "basic_type": "Heavenly", "basic_race": "Warrior"})).is_empty()
	assert_int(s.draft[0]["picked"].count(HEAVENLY_WARRIOR)).is_equal(copies)
	assert_int(int(s.view_for(0)["draft"]["basic"]["id"])).is_equal(HEAVENLY_WARRIOR)
	s.submit(0, {"t": "draft_pick", "index": 0})
	s.submit(0, {"t": "draft_pick", "index": 0})
	assert_bool(s.deck_ready[0]).is_true()
	assert_int(s.decks[0].count(HEAVENLY_WARRIOR)).is_equal(copies)
	assert_int(_basics(s.decks[0]).size()).is_equal(copies)
	assert_int(s.decks[0].size()).is_equal(copies + 2)


func test_f06_06_illegal_basic_choice_is_refused() -> void:
	var s := _draft_series({"unit": 1})
	assert_str(s.submit(0, {"t": "draft_setup", "order": ["unit"], "basic_type": "Fire", "basic_race": "Elf"})).contains("Type and a Race")
	assert_str(s.submit(0, {"t": "draft_setup", "order": ["unit"]})).contains("Type and a Race")
	assert_bool(s.draft[0]["setup_done"]).is_false()


func test_f06_06_default_basic_is_first_type_and_race() -> void:
	var d := CardDB.get_def(Series.default_basic())
	assert_str(String(d["type"])).is_equal(CardDB.ELEMENTS[0])
	assert_str(String(d["race"])).is_equal(Series.basic_races()[0])
	var s := _draft_series()
	assert_int(int(s.view_for(0)["draft"]["basic"]["id"])).is_equal(Series.default_basic())


# ---------------------------------------------------------------- F06-05

func test_f06_05_no_picks_before_setup() -> void:
	var s := _draft_series()
	var dv: Dictionary = s.view_for(0)["draft"]
	assert_bool(dv["setup_done"]).is_false()
	assert_array(dv["offer"]).is_empty()
	assert_array(dv["cat_order"]).is_equal(["unit", "spell", "trap", "power", "extra"])
	assert_str(s.submit(0, {"t": "draft_pick", "index": 0})).contains("start drafting")


func test_f06_05_draft_follows_the_seat_order() -> void:
	var s := _draft_series({"unit": 2, "spell": 1, "trap": 0, "power": 1, "extra": 1})
	var order := ["extra", "power", "spell", "unit"]
	assert_str(s.submit(0, {"t": "draft_setup", "order": order, "basic_type": "Fire", "basic_race": "Dragon"})).is_empty()
	assert_str(s.submit(1, BotBrain.draft_setup_command(s))).is_empty()
	var seen := []
	while not s.deck_ready[0]:
		var dv: Dictionary = s.view_for(0)["draft"]
		seen.append(String(dv["category"]))
		var picked := int(dv["offer"][0]["id"])
		assert_str(s.submit(0, {"t": "draft_pick", "index": 0})).is_empty()
		var cat: String = CardDB.get_def(picked)["category"]
		var want: String = seen[-1]
		assert_bool(cat in Series.EXTRA_CATEGORIES if want == "extra" else cat == want).is_true()
	assert_array(seen).is_equal(["extra", "power", "spell", "unit", "unit"])
	# The other seat keeps the default order.
	assert_str(String(s.view_for(1)["draft"]["category"])).is_equal("unit")
	assert_str(String(s.view_for(0)["draft"]["composition"])).is_equal("1 Extra Deck, 1 Power, 1 Spell, 2 Unit")


func test_f06_05_invalid_orders_are_refused() -> void:
	var s := _draft_series({"unit": 2, "spell": 1, "trap": 0, "power": 1, "extra": 1})
	var ok := {"basic_type": "Fire", "basic_race": "Dragon"}
	for bad in [["unit", "spell", "power"], ["unit", "spell", "power", "extra", "trap"],
			["unit", "unit", "power", "extra"], ["unit", "spell", "power", "basic"], ["unit", "spell", "power", 4], "unit", null]:
		var cmd := ok.duplicate()
		cmd["t"] = "draft_setup"
		if bad != null:
			cmd["order"] = bad
		assert_str(s.submit(0, cmd)).override_failure_message("order %s accepted" % [bad]).is_not_empty()
	assert_bool(s.draft[0]["setup_done"]).is_false()
	var good := ok.duplicate()
	good["t"] = "draft_setup"
	good["order"] = ["spell", "unit", "extra", "power"]
	assert_str(s.submit(0, good)).is_empty()
	assert_str(s.submit(0, good)).contains("already")


func test_f06_05_other_seat_offers_are_not_in_the_view() -> void:
	var s := _draft_series()
	s.submit(0, BotBrain.draft_setup_command(s))
	s.submit(1, BotBrain.draft_setup_command(s))
	var v0: Dictionary = s.view_for(0)
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


func test_f06_05_bot_setup_is_deterministic() -> void:
	var s := _draft_series()
	assert_dict(BotBrain.draft_setup_command(s)).is_equal(BotBrain.draft_setup_command(s))
	assert_str(s.submit(1, BotBrain.draft_setup_command(s))).is_empty()


# ---------------------------------------------------------------- network

func test_f06_net_sanitizes_draft_setup_and_reward_commands() -> void:
	var ok := {"t": "draft_setup", "order": ["unit", "spell"], "basic_type": "Fire", "basic_race": "Dragon"}
	assert_str(NetSession.sanitize_command(ok)).is_empty()
	assert_str(NetSession.sanitize_command({"t": "reward_basic", "to_type": "Fire", "to_race": "Dragon"})).is_empty()
	assert_str(NetSession.sanitize_command({"t": "reward_basic", "from_id": 4.0, "to_type": "Fire"})).is_empty()
	assert_str(NetSession.sanitize_command({"t": "draft_setup", "order": "unit"})).is_not_empty()
	assert_str(NetSession.sanitize_command({"t": "draft_setup", "order": [1, 2]})).is_not_empty()
	var long := []
	for i in 40:
		long.append("unit")
	assert_str(NetSession.sanitize_command({"t": "draft_setup", "order": long})).is_not_empty()
	assert_str(NetSession.sanitize_command({"t": "draft_setup", "basic_type": 7})).is_not_empty()
	assert_str(NetSession.sanitize_command({"t": "draft_setup", "basic_colour": "red"})).is_not_empty()
