extends GdUnitTestSuite
## Owner feedback 22 Oct. J28: the draft list's rows carry what the duel's pile rows do (full card
## views: kind, cost, Race and Type, a Fusion's materials, keywords). J29: the "cards you have
## drafted so far" grid shows the drafted cards themselves, with the duel's card tooltip.
## Story: design/owner-feedback-2026-10-22.md J28 J29.

## A Fusion unit (Razeon Storm), a unit (Dante) and a spell (Fog of War) from data/cards.json.
const FUSION := 56
const UNIT := 36
const SPELL := 81


func _summaries(ids: Array) -> Array:
	return ids.map(func(id): return Series.card_summary(int(id)))


func test_j28_draft_views_are_full_card_views() -> void:
	var vs := GameDetails.draft_views(_summaries([FUSION, UNIT, SPELL]))
	assert_int(vs.size()).is_equal(3)
	for v in vs:
		assert_bool(v.has("text_parts")).is_true()
		assert_bool(v.has("keywords")).is_true()
	assert_str(String(vs[0]["category"])).is_equal("fusion")


func test_j28_a_fusion_row_names_its_materials() -> void:
	var v: Dictionary = GameDetails.draft_views(_summaries([FUSION]))[0]
	var cost := GameDetails.row_cost(v)
	assert_str(String(cost.get("kind", ""))).is_equal("fusion")
	assert_str(String(cost.get("text", ""))).is_not_empty()


func test_j28_two_copies_stay_two_rows() -> void:
	var vs := GameDetails.draft_views(_summaries([UNIT, UNIT]))
	assert_int(int(vs[0]["uid"])).is_not_equal(int(vs[1]["uid"]))


func test_j29_grid_holds_the_drafted_cards() -> void:
	var vs := GameDetails.draft_views(_summaries([FUSION, UNIT]))
	var s: DraftSlots = auto_free(DraftSlots.new().setup(12, vs))
	add_child(s)
	await get_tree().process_frame
	assert_int(s.cards.size()).is_equal(2)
	var w: CardWidget = s.cards[0]
	assert_int(int(w.view["id"])).is_equal(FUSION)
	assert_bool(bool(w.view["face_up"])).is_true()
	assert_vector(w.size).is_equal(DraftSlots.SLOT)
	assert_vector(w.position).is_equal(s.slot_pos(0))
	assert_str(w.tooltip_text).is_not_empty()


func test_j29_grid_card_has_the_coloured_card_tooltip() -> void:
	var vs := GameDetails.draft_views(_summaries([FUSION]))
	var s: DraftSlots = auto_free(DraftSlots.new().setup(12, vs))
	add_child(s)
	var w: CardWidget = s.cards[0]
	var tip = auto_free(w._make_custom_tooltip(w.tooltip_text))
	assert_object(tip).is_not_null()
	assert_bool(tip is Label).is_false()


func test_j29_kind_only_picks_stay_drawn_slots() -> void:
	var s: DraftSlots = auto_free(DraftSlots.new().setup(12, ["unit", "spell"]))
	assert_int(s.kinds.size()).is_equal(2)
	assert_bool(s.cards.all(func(c): return c == null)).is_true()
