extends GdUnitTestSuite
## L23 follow-up (5 Nov): in the match sidebar's card details pane the Evolve section of Symbiote
## Spawn / Larva sat below the fold. The art crop now yields to the text (it shrinks, down to
## GameDetails.ART_MIN_H, so the sections fit when they can), and when some still run below the fold
## the scroll cue names them ("Scroll for Evolve, Statuses") instead of a bare "Scroll for more".
## Story: design/owner-feedback-2026-11-05.md L23 (follow-up).

const SPAWN := 155
const LARVA := 156
const AKIRAMARI := 146

var host: LocalHost
var gs: GameScreen
var m: MatchEngine
var me: int


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	UIStyle.reduce_motion = true
	host = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 11, "best_of": 1, "deck_mode": "starter", "names": ["Ana", "Ben"], "mode": "local"})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	m = host.series.game
	me = m.active
	gs = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	await gs.attach(host.seats[me])
	gs.skip_effects()
	await await_idle_frame()


func after_test() -> void:
	UIStyle.reduce_motion = false


func _select(uid: int) -> void:
	host.broadcast()
	gs.skip_effects()
	await await_idle_frame()
	gs.selection.select(uid)
	for i in 6:
		await await_idle_frame()


func _crop() -> Control:
	for ch in gs.details.details_view.get_children():
		if ch is CardDetailsPanel.ArtCrop:
			return ch
	return null


func _content_h() -> float:
	return gs.details.details_view.get_combined_minimum_size().y


## Adds `n` permanent modifiers to unit `u` (one Modifiers line each): makes its details overflow
## whatever height the headless sidebar gives the pane.
func _lengthen(u: int, n: int) -> void:
	for i in n:
		m.cards[u]["mods"].append({"atk": 1, "def": 0, "until": "perm", "src": "Test effect %d" % i})


func test_art_crop_yields_to_a_long_cards_rules() -> void:
	# Arrange
	var u := TB.unit(m, me, AKIRAMARI, 4)
	_lengthen(u, 18)
	# Act
	await _select(u)
	# Assert: at the full crop the card would overflow; the crop shrank (not below its floor) and
	# the card now fits, or the crop is at its floor.
	var scroll_h: float = gs.details.details_scroll.size.y
	var cap := GameDetails.art_crop_height(scroll_h)
	var crop := _crop()
	assert_object(crop).is_not_null()
	var h := crop.custom_minimum_size.y
	assert_float(_content_h() - h + cap).override_failure_message("precondition: overflows at the full crop").is_greater(scroll_h)
	assert_float(h).is_less(cap)
	assert_float(h).is_greater_equal(GameDetails.ART_MIN_H)
	var rest := _content_h() - h
	assert_float(h).is_equal_approx(clampf(floorf(scroll_h - rest), GameDetails.ART_MIN_H, cap), 1.0)


func test_short_card_keeps_the_full_art_crop() -> void:
	# Arrange
	var u := TB.unit(m, me, TB.WATER, 4)
	# Act
	await _select(u)
	# Assert
	var cap := GameDetails.art_crop_height(gs.details.details_scroll.size.y)
	assert_float(_crop().custom_minimum_size.y).is_equal(cap)
	assert_bool(gs.details.scroll_cue.shown).is_false()


func test_scroll_cue_names_the_evolve_section_when_it_is_below_the_fold() -> void:
	# Arrange: Symbiote Spawn with statuses and many modifiers, so its details overflow even with the
	# crop at its floor.
	TB.unit(m, me, TB.WATER, 1)
	var u := TB.unit(m, me, SPAWN, 4)
	for s in ["eternal", "nimble", "pierce"]:
		m.apply_status(u, s, 1)
	_lengthen(u, 24)
	# Act
	await _select(u)
	# Assert
	var scroll_h: float = gs.details.details_scroll.size.y
	assert_float(_content_h()).is_greater(scroll_h)
	var cue: ScrollCue = gs.details.scroll_cue
	assert_bool(cue.shown).is_true()
	var below: PackedStringArray = gs.details.details_view.sections_below(scroll_h)
	assert_array(Array(below)).is_not_empty()
	assert_str(cue.text()).contains(below[0])
	if below.has("Evolve"):
		assert_str(cue.text()).contains("Evolve")


func test_larva_evolve_section_is_visible_or_named() -> void:
	# Arrange
	TB.unit(m, me, TB.WATER, 0)
	var u := TB.unit(m, me, LARVA, 3)
	m.apply_status(u, "eternal", 1)
	# Act
	await _select(u)
	# Assert
	var scroll_h: float = gs.details.details_scroll.size.y
	var below: PackedStringArray = gs.details.details_view.sections_below(scroll_h)
	if below.has("Evolve"):
		assert_str(gs.details.scroll_cue.text()).contains("Evolve")
	else:
		assert_bool(gs.details.details_view.all_text().contains("EVOLVE")).is_true()
