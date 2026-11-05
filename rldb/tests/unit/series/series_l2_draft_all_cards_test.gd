extends GdUnitTestSuite
## L2 (owner, 5 Nov): every one of the 191 cards can be drafted and lands where it should. Each
## non-basic card is offered in its draft category, picked through the normal `draft_pick` command,
## confirmed, and found in the right zone of game 1 (Fusion / Ritual / Arcane in the Extra Deck,
## everything else in the Main Deck: Draw or the opening Hand). Every basic unit is reachable through
## the basic-unit picker and is dealt into the Main Deck. The three 3 Nov cards (189 Owlbear Druid,
## 190 Snow Tiger Paladin, 191 Do Not Open Box) are checked by name as well.
## Story: design/owner-feedback-2026-11-05.md L2.

const NEW_CARDS := [189, 190, 191]


## The draft category a card is drafted in ("extra" for Fusion, Ritual and Arcane).
func _cat(id: int) -> String:
	var c := String(CardDB.get_def(id)["category"])
	return "extra" if c in Series.EXTRA_CATEGORIES else c


## Drafts card `id` for seat 0 (one pick in its category), lets seat 1 draft, starts game 1.
func _draft_one(id: int) -> Series:
	var cat := _cat(id)
	var s := Series.new()
	s.setup({"seed": 11, "deck_mode": "draft", "best_of": 3, "draft_quota": {cat: 1}})
	s.submit(0, {"t": "draft_category", "category": cat})
	var offer: Array = s.draft[0]["offers"][cat]
	var i := offer.find(id)
	if i == -1:
		offer[0] = id   # put the card in the offer (the offer is the authority's, as dealt)
		i = 0
	s.draft[0]["offer"] = offer
	assert_str(s.submit(0, {"t": "draft_pick", "index": i})).is_empty()
	assert_str(s.submit(0, {"t": "draft_confirm"})).is_empty()
	assert_str(s.submit(1, {"t": "draft_pick", "index": 0})).is_empty()
	assert_str(s.submit(1, {"t": "draft_confirm"})).is_empty()
	return s


## The zone ("extra" or "main") of the first copy of `id` in seat p's game, or "" when absent.
func _zone_of(m: MatchEngine, p: int, id: int) -> String:
	for uid in m.players[p]["extra"]:
		if int(m.cards[uid]["id"]) == id:
			return "extra"
	for z in ["draw", "hand"]:
		for uid in m.players[p][z]:
			if int(m.cards[uid]["id"]) == id:
				return "main"
	return ""


func test_l2_every_non_basic_card_is_in_its_draft_pool() -> void:
	var s := Series.new()
	s.setup({"seed": 3, "deck_mode": "draft"})
	var missing := []
	for d in CardDB.all():
		if d["category"] == "basic_unit":
			continue
		var offered := int(d["id"]) in s._draft_pool(_cat(int(d["id"])))
		# L23: evolution-only cards (Symbiote Larva, Siphonophore) are never offered; every other card is.
		if offered != CardDB.is_collectible(int(d["id"])):
			missing.append("%d %s" % [int(d["id"]), d["name"]])
	assert_array(missing).is_empty()


func test_l2_every_non_basic_card_drafts_into_the_right_deck() -> void:
	var wrong := []
	var n := 0
	for d in CardDB.all():
		var id := int(d["id"])
		if d["category"] == "basic_unit" or not CardDB.is_collectible(id):
			continue   # L23: evolution-only cards are not draftable
		var s := _draft_one(id)
		var want := "extra" if CardDB.is_extra_category(String(d["category"])) else "main"
		if not (id in s.decks[0]) or s.stage != Series.STAGE_GAME or _zone_of(s.game, 0, id) != want:
			wrong.append("%d %s: in deck %s, zone '%s' (want %s)" % [id, d["name"], id in s.decks[0], _zone_of(s.game, 0, id) if s.game != null else "-", want])
		n += 1
	assert_array(wrong).is_empty()
	assert_int(n).is_equal(CardDB.all().filter(func(d): return d["category"] != "basic_unit" and CardDB.is_collectible(int(d["id"]))).size())


func test_l2_the_three_new_cards_draft_into_the_right_deck() -> void:
	for id in NEW_CARDS:
		var s := _draft_one(id)
		var want := "extra" if id != 191 else "main"
		assert_str(_zone_of(s.game, 0, id)).override_failure_message("%d" % id).is_equal(want)
		assert_array(s.decks[0]).contains([id])


func test_l2_every_basic_unit_can_be_chosen_and_is_dealt_into_the_main_deck() -> void:
	var wrong := []
	for d in CardDB.all():
		if d["category"] != "basic_unit":
			continue
		var s := Series.new()
		s.setup({"seed": 5, "deck_mode": "draft", "draft_quota": {"spell": 1}})
		var err := s.submit(0, {"t": "draft_basic", "basic_type": d["type"], "basic_race": d["race"]})
		s.submit(0, {"t": "draft_pick", "index": 0})
		s.submit(0, {"t": "draft_confirm"})
		s.submit(1, {"t": "draft_pick", "index": 0})
		s.submit(1, {"t": "draft_confirm"})
		if err != "" or s.game == null or _zone_of(s.game, 0, int(d["id"])) != "main":
			wrong.append("%d %s (%s %s): %s" % [int(d["id"]), d["name"], d["type"], d["race"], err])
	assert_array(wrong).is_empty()
	assert_int(CardDB.all().size()).is_equal(191)
