extends GdUnitTestSuite
## L3 (owner, 5 Nov): "When drafting the extra deck category, the three results should always be one
## fusion one ritual and one arcane, not a random mixture of the three". Shown in a fixed order:
## Fusion, Ritual, Arcane. A kind with nothing to offer gives its slot to the other kinds; the offer
## stays in kind order. The between-game "Add a card: Extra Deck" reward offers the same.
## Story: design/owner-feedback-2026-11-05.md L3.

const ORDER := ["fusion", "ritual", "arcane"]


func _kinds(ids: Array) -> Array:
	return ids.map(func(id): return String(CardDB.get_def(int(id))["category"]))


func _draft_extra_offer(seed_value: int) -> Array:
	var s := Series.new()
	s.setup({"seed": seed_value, "deck_mode": "draft"})
	s.submit(0, {"t": "draft_category", "category": "extra"})
	return s.draft[0]["offer"]


func test_l3_draft_extra_offer_is_one_of_each_kind_in_order() -> void:
	for seed_value in range(1, 41):
		assert_array(_kinds(_draft_extra_offer(seed_value))).override_failure_message("seed %d" % seed_value).is_equal(ORDER)


func test_l3_draft_extra_offer_in_the_view_keeps_the_order() -> void:
	var s := Series.new()
	s.setup({"seed": 9, "deck_mode": "draft"})
	s.submit(0, {"t": "draft_category", "category": "extra"})
	var offer: Array = s.view_for(0)["draft"]["offer"]
	assert_array(offer.map(func(c): return String(c["category"]))).is_equal(ORDER)


func test_l3_a_new_extra_offer_after_a_pick_is_one_of_each_again() -> void:
	var s := Series.new()
	s.setup({"seed": 12, "deck_mode": "draft"})
	s.submit(0, {"t": "draft_category", "category": "extra"})
	for i in 2:
		assert_str(s.submit(0, {"t": "draft_pick", "index": i})).is_empty()
		s.submit(0, {"t": "draft_category", "category": "extra"})
		assert_array(_kinds(s.draft[0]["offer"])).is_equal(ORDER)


func test_l3_extra_offers_vary_within_each_kind() -> void:
	var seen := {"fusion": {}, "ritual": {}, "arcane": {}}
	for seed_value in range(1, 41):
		var offer := _draft_extra_offer(seed_value)
		for i in 3:
			seen[ORDER[i]][int(offer[i])] = true
	for k in ORDER:
		assert_int(seen[k].size()).override_failure_message(k).is_greater(3)


func test_l3_reward_extra_offer_is_one_of_each_kind_in_order() -> void:
	var s := Series.new()
	s.setup({"seed": 30, "best_of": 3, "deck_mode": "starter"})
	s.submit(0, {"t": "pick_starter", "index": 0})
	s.submit(1, {"t": "pick_starter", "index": 1})
	s.submit(0, {"t": "concede"})
	assert_str(s.submit(0, {"t": "reward_type", "category": "extra"})).is_empty()
	assert_array(_kinds(s.rewards[0]["offer"])).is_equal(ORDER)


func test_l3_an_empty_kind_gives_its_slot_to_the_others_in_kind_order() -> void:
	var s := Series.new()
	s.setup({"seed": 4, "deck_mode": "draft"})
	var pools := Series.extra_pools()
	pools["ritual"] = []
	var offer: Array = s._extra_offer(3, pools)
	assert_int(offer.size()).is_equal(3)
	var kinds := _kinds(offer)
	assert_bool(kinds.has("ritual")).is_false()
	assert_str(kinds[0]).is_equal("fusion")
	assert_str(kinds[2]).is_equal("arcane")   # the borrowed card sorts with its own kind
	assert_int({offer[0]: 1, offer[1]: 1, offer[2]: 1}.size()).is_equal(3)   # no card offered twice


func test_l3_too_few_extra_cards_makes_a_shorter_offer() -> void:
	var s := Series.new()
	s.setup({"seed": 4, "deck_mode": "draft"})
	var offer: Array = s._extra_offer(3, {"fusion": [56], "ritual": [], "arcane": []})
	assert_array(offer).is_equal([56])
	assert_array(s._extra_offer(3, {"fusion": [], "ritual": [], "arcane": []})).is_empty()


func test_l3_a_larger_offer_keeps_one_of_each_then_fills_in_kind_order() -> void:
	var s := Series.new()
	s.setup({"seed": 6, "deck_mode": "draft", "draft": {"offer": 5}})
	s.submit(0, {"t": "draft_category", "category": "extra"})
	var kinds := _kinds(s.draft[0]["offer"])
	assert_int(kinds.size()).is_equal(5)
	for k in ORDER:
		assert_bool(kinds.has(k)).is_true()
	var idx := kinds.map(func(k): return ORDER.find(k))
	var sorted_idx := idx.duplicate()
	sorted_idx.sort()
	assert_array(idx).is_equal(sorted_idx)


func test_l3_every_offered_card_passes_the_offer_predicate() -> void:
	for seed_value in range(1, 11):
		for id in _draft_extra_offer(seed_value):
			assert_bool(Series.is_offerable(int(id))).is_true()
