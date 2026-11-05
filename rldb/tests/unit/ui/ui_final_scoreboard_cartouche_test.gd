extends GdUnitTestSuite
## Final review #11 (design/review-final-2026-11-05.md): the series scoreboard's "BEST OF n" caption
## and game dots were cramped in the centre cartouche (an 11 px caption 3 px under the rim, 3.4 px
## dots nearly touching the lower rim). Each must sit inside the cartouche with room to breathe, at a
## legible size, without the plaque outgrowing the top strip.

## The least room (px, layout) between the caption, the dots and the cartouche's rim, and between the
## caption and the dots.
const RIM_ROOM := 4.0
const GAP_ROOM := 4.0
## The smallest legible caption (layout px; 1280x800 draws it at 0.8x) and dot radius.
const MIN_CAPTION_PX := 12
const MIN_DOT_R := 3.8


func _board(best: int, results: Array) -> SeriesScoreboard:
	var sc := [0, 0]
	for r in results:
		sc[int(r)] += 1
	var md := {"best_of": best, "need": best / 2 + 1, "names": ["Maximiliana Thornwood", "Bartholomew Ashgrave"],
		"scores": sc, "results": results, "turns": [], "forfeit": [], "current": mini(results.size(), best - 1),
		"over": false, "winner": -1, "leader": -1 if sc[0] == sc[1] else (0 if sc[0] > sc[1] else 1),
		"me": 0, "stage": "game", "playing": true}
	var sb: SeriesScoreboard = auto_free(SeriesScoreboard.new())
	sb.show_model(md, "t")
	return sb


func _inside(inner: Rect2, outer: Rect2, room: float) -> bool:
	return inner.position.x >= outer.position.x + room and inner.position.y >= outer.position.y + room \
		and inner.end.x <= outer.end.x - room and inner.end.y <= outer.end.y - room


func test_caption_and_dots_breathe_inside_the_cartouche_for_every_series_length() -> void:
	for best in [3, 5, 7]:
		# Arrange: the middle game in play (its ring breathing round its dot).
		var sb := _board(best, [0, 1])
		# Act
		var cart := sb.cartouche_rect()
		var cap := sb.caption_rect()
		var dots := sb.dots_rect()
		# Assert
		assert_bool(_inside(cap, cart, RIM_ROOM)).override_failure_message("caption %s in %s, bo%d" % [cap, cart, best]).is_true()
		assert_bool(_inside(dots, cart, RIM_ROOM)).override_failure_message("dots %s in %s, bo%d" % [dots, cart, best]).is_true()
		assert_float(dots.position.y - cap.end.y).override_failure_message("caption to dots, bo%d" % best).is_greater_equal(GAP_ROOM)


func test_caption_and_dots_are_legible_sizes() -> void:
	assert_int(SeriesScoreboard.CAPTION_PX).is_greater_equal(MIN_CAPTION_PX)
	assert_float(SeriesScoreboard.DOT_R).is_greater_equal(MIN_DOT_R)
	# Neighbouring dots (and the breathing ring) never touch.
	assert_float(SeriesScoreboard.DOT_STEP - 2.0 * SeriesScoreboard.DOT_R).is_greater_equal(4.0)


func test_plaque_stays_inside_the_top_strip_with_a_margin() -> void:
	var sb := _board(5, [])
	assert_float(sb.size.y).is_less_equal(GameScreen.TOP_H - 4.0)
	# The gems and laurels sit clear of the wider cartouche.
	assert_float(sb.gem_pos(true, 0).x + SeriesScoreboard.GEM_R).is_less_equal(sb.cartouche_rect().position.x - 4.0)
	assert_float(sb.gem_pos(false, 0).x - SeriesScoreboard.GEM_R).is_greater_equal(sb.cartouche_rect().end.x + 4.0)
