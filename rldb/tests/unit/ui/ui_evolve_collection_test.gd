extends GdUnitTestSuite
## L23 (design/owner-feedback-2026-11-05.md): Symbiote Larva (156) and Symbiote Siphonophore (157) are
## evolution-only. They are hidden from every collection surface (draft pools, reward offers, the deck
## builder, the card library, starter decks) through the one predicate CardDB.is_collectible, and a
## saved deck or series holding them gets their base card (Symbiote Spawn, 155).

const SPAWN := 155
const LARVA := 156
const SIPHONOPHORE := 157
const MAGE := 1


func test_only_the_evolved_forms_are_not_collectible() -> void:
	assert_bool(CardDB.is_collectible(SPAWN)).is_true()
	assert_bool(CardDB.is_collectible(LARVA)).is_false()
	assert_bool(CardDB.is_collectible(SIPHONOPHORE)).is_false()
	assert_bool(CardDB.is_collectible(-5)).is_false()
	var ids := CardDB.collectible().map(func(d): return int(d["id"]))
	assert_int(ids.size()).is_equal(CardDB.all().size() - 2)
	assert_array(ids).not_contains([LARVA, SIPHONOPHORE])
	assert_array(ids).contains([SPAWN])


func test_evolution_chain_helpers() -> void:
	assert_int(CardDB.evolves_into(SPAWN)).is_equal(LARVA)
	assert_int(CardDB.evolves_into(LARVA)).is_equal(SIPHONOPHORE)
	assert_int(CardDB.evolves_into(SIPHONOPHORE)).is_equal(-1)
	assert_int(CardDB.evolves_into(MAGE)).is_equal(-1)
	assert_int(CardDB.evolution_base(SIPHONOPHORE)).is_equal(SPAWN)
	assert_int(CardDB.evolution_base(LARVA)).is_equal(SPAWN)
	assert_int(CardDB.evolution_base(MAGE)).is_equal(MAGE)
	assert_array(CardDB.sanitize_deck([LARVA, MAGE, SIPHONOPHORE, 99999])).is_equal([SPAWN, MAGE, SPAWN, 99999])


func test_draft_pools_and_reward_offers_never_hold_an_evolved_form() -> void:
	var s := Series.new()
	s.setup({"seed": 3, "best_of": 1})
	for cat in ["unit", "spell", "trap", "power", "extra"]:
		var pool: Array = s._draft_pool(cat)
		assert_array(pool).not_contains([LARVA, SIPHONOPHORE])
		var rewards: Array = Series.reward_pool(cat)
		assert_array(rewards).not_contains([LARVA, SIPHONOPHORE])
	assert_array(s._draft_pool("unit")).contains([SPAWN])
	assert_array(Series.reward_pool("unit")).contains([SPAWN])


func test_starter_decks_hold_only_collectible_cards() -> void:
	for dk in Series.load_starters():
		for id in dk["main"] + dk["extra"]:
			assert_bool(CardDB.is_collectible(int(id))).override_failure_message("%s holds %d" % [dk["name"], int(id)]).is_true()


func test_deck_builder_and_card_library_hide_the_evolved_forms() -> void:
	var db := DeckBuilder.new()
	add_child(db)
	auto_free(db)
	assert_object(db.browser.cell(LARVA)).is_null()
	assert_object(db.browser.cell(SIPHONOPHORE)).is_null()
	assert_object(db.browser.cell(SPAWN)).is_not_null()
	var cl := CardListScreen.new()
	add_child(cl)
	auto_free(cl)
	assert_object(cl.browser.cell(LARVA)).is_null()
	assert_object(cl.browser.cell(SIPHONOPHORE)).is_null()
	assert_object(cl.browser.cell(SPAWN)).is_not_null()


func test_custom_deck_with_an_evolved_form_locks_in_its_base_card() -> void:
	var s := Series.new()
	s.setup({"seed": 3, "best_of": 1})
	assert_str(s.submit(0, {"t": "custom_deck", "name": "Old", "cards": [LARVA, MAGE, SIPHONOPHORE]})).is_empty()
	assert_array(s.decks[0]).is_equal([SPAWN, MAGE, SPAWN])


func test_saved_series_with_an_evolved_form_resumes_with_its_base_card() -> void:
	var s := Series.new()
	s.setup({"seed": 3, "best_of": 1})
	s.submit(0, {"t": "pick_starter", "index": 0})
	s.submit(1, {"t": "pick_starter", "index": 1})
	var d := s.to_save()
	d["decks"][0] = [LARVA, MAGE, MAGE]
	var back := Series.from_save(JSON.parse_string(JSON.stringify(d)))
	assert_object(back).is_not_null()
	assert_array(back.decks[0]).is_equal([SPAWN, MAGE, MAGE])


func test_saved_custom_deck_lists_its_base_card() -> void:
	assert_str(DeckStore.PATH).is_equal(DeckStore.TEST_PATH)   # never the player's decks
	DeckStore.save_deck("L23 evolve test", [SIPHONOPHORE, MAGE])
	var found := DeckStore.list().filter(func(e): return e["name"] == "L23 evolve test")
	DeckStore.delete_deck("L23 evolve test")
	assert_int(found.size()).is_equal(1)
	assert_array(found[0]["cards"]).is_equal([SPAWN, MAGE])
