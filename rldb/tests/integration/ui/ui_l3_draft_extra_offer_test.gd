extends GdUnitTestSuite
## L3 (owner, 5 Nov): the Extra Deck draft offer shows one Fusion, one Ritual and one Arcane, in that
## order, each named by a small chip in its kind's colour. A pick plays the draft_pick cue.
## Story: design/owner-feedback-2026-11-05.md L3.

const DIR := "user://test_saves_l3"


func before_test() -> void:
	SeriesStore.DIR = DIR
	DirAccess.make_dir_recursive_absolute(DIR)


func after_test() -> void:
	for fn in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, fn])


func _screen() -> Array:
	var host: LocalHost = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 33, "best_of": 3, "deck_mode": "draft", "names": ["Ann", "Bea"], "mode": "local"})
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 900)
	add_child(gs)
	await gs.attach(host.seats[0])
	for i in 4:
		await await_idle_frame()
	return [host, gs]


func _offer_cards(gs: GameScreen) -> Array:
	var row = gs.overlays.overlay_box.find_child("Offer", true, false)
	return [] if row == null else row.find_children("*", "CardWidget", true, false)


func test_l3_extra_offer_cards_carry_their_kind_chips_in_order() -> void:
	var r := await _screen()
	var host: LocalHost = r[0]
	var gs: GameScreen = r[1]
	host.handle(0, {"t": "draft_category", "category": "extra"})
	await await_idle_frame()
	var row: Node = gs.overlays.overlay_box.find_child("Offer", true, false)
	var chips := row.find_children("KindChip_*", "", true, false).map(func(c): return String(c.name))
	assert_array(chips).is_equal(["KindChip_fusion", "KindChip_ritual", "KindChip_arcane"])
	var kinds := _offer_cards(gs).map(func(w): return String((w as CardWidget).view["category"]))
	assert_array(kinds).is_equal(["fusion", "ritual", "arcane"])


func test_l3_other_categories_have_no_kind_chips() -> void:
	var r := await _screen()
	var host: LocalHost = r[0]
	var gs: GameScreen = r[1]
	host.handle(0, {"t": "draft_category", "category": "spell"})
	await await_idle_frame()
	var row: Node = gs.overlays.overlay_box.find_child("Offer", true, false)
	assert_array(row.find_children("KindChip_*", "", true, false)).is_empty()
	assert_int(_offer_cards(gs).size()).is_equal(3)


func test_l3_a_draft_pick_plays_the_draft_pick_cue_and_lands() -> void:
	var r := await _screen()
	var host: LocalHost = r[0]
	var gs: GameScreen = r[1]
	host.handle(0, {"t": "draft_category", "category": "extra"})
	await await_idle_frame()
	var w: CardWidget = _offer_cards(gs)[1]
	var id := int(w.view["id"])
	Sfx.debug_ui.clear()
	w.pressed.emit(w)
	assert_array(Sfx.debug_ui).contains(["draft_pick"])
	assert_array(host.series.draft[0]["picked"]).is_equal([id])
