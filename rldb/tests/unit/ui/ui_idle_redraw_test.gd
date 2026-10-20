extends GdUnitTestSuite
## Performance regression guard (H7, 21 Oct: "I'm only getting like 80 fps, before I was getting 240").
## Godot turns processing on at NOTIFICATION_READY for any script that defines _process, so a
## set_process(false) in _init() is silently undone. These widgets then redrew every frame forever:
## 40 buttons and 8 piles on the deck choice cost ~10 ms a frame. Each test puts an idle widget in
## the tree and checks that it neither processes nor redraws on its own.

const FRAMES := 6


func _idle_draws(c: CanvasItem) -> int:
	var n := [0]
	c.draw.connect(func(): n[0] += 1)
	for i in FRAMES:
		await get_tree().process_frame
	return n[0]


func _settle(c: Control) -> void:
	if c.anchor_right == 0.0:   # full-rect overlays (CtaCue) take their parent's size
		c.size = Vector2(120, 80)
	add_child(c)
	for i in 3:
		await get_tree().process_frame


func test_idle_juicy_button_does_not_process_or_redraw() -> void:
	# Arrange
	var b: JuicyButton = auto_free(JuicyButton.new())
	b.text = "Idle"
	await _settle(b)
	# Act
	var draws: int = await _idle_draws(b)
	# Assert
	assert_bool(b.is_processing()).is_false()
	assert_int(draws).is_equal(0)


func test_idle_pile_stack_does_not_process_or_redraw() -> void:
	var p: PileStack = auto_free(PileStack.new())
	await _settle(p)
	var draws: int = await _idle_draws(p)
	assert_bool(p.is_processing()).is_false()
	assert_int(draws).is_equal(0)


func test_ready_pile_stack_still_animates() -> void:
	var p: PileStack = auto_free(PileStack.new())
	await _settle(p)
	p.set_pile(30, true, true)
	var draws: int = await _idle_draws(p)
	assert_bool(p.is_processing()).is_equal(not UIStyle.reduce_motion)
	if not UIStyle.reduce_motion:
		assert_int(draws).is_greater_equal(FRAMES - 1)


func test_hidden_zone_ring_does_not_process() -> void:
	var z: ZoneRing = auto_free(ZoneRing.new())
	await _settle(z)
	assert_bool(z.is_processing()).is_false()


func test_off_cta_cue_does_not_process_or_redraw() -> void:
	var c: CtaCue = auto_free(CtaCue.new())
	await _settle(c)
	var draws: int = await _idle_draws(c)
	assert_bool(c.is_processing()).is_false()
	assert_int(draws).is_equal(0)


func test_motes_share_one_antialiased_disc_texture() -> void:
	# H7: motes are textured quads of one cached disc, not circles tessellated every frame.
	var a := AmbientMotes.disc_texture()
	var b := AmbientMotes.disc_texture()
	var img := a.get_image()
	var mid := AmbientMotes.DISC_TEX / 2
	assert_object(a).is_same(b)
	assert_float(img.get_pixel(mid, mid).a).is_equal(1.0)
	assert_float(img.get_pixel(0, 0).a).is_equal(0.0)
	assert_bool(img.has_mipmaps()).is_true()


func test_series_medallion_breathes_without_redrawing_the_coin() -> void:
	# H7: only the next socket's rings redraw each frame, on their own small overlay.
	var m: SeriesMedallion = auto_free(SeriesMedallion.new().setup(3, [0], 1))
	m.custom_minimum_size.x = 200
	await _settle(m)
	var breath: Control = m.get_child(0, true)
	var bn := [0]
	breath.draw.connect(func(): bn[0] += 1)
	var coin: int = await _idle_draws(m)
	assert_int(coin).is_equal(0)
	if not UIStyle.reduce_motion:
		assert_int(bn[0]).is_greater_equal(FRAMES - 1)


func test_game_log_stops_redrawing_once_fresh_lines_rest() -> void:
	# H7: a [fresh] line kept the log's RichTextLabel redrawing every frame for the rest of the game.
	# Arrange: a log label with one line arriving now.
	var log := GameLog.new(null)
	var label: RichTextLabel = auto_free(RichTextLabel.new())
	label.bbcode_enabled = true
	label.size = Vector2(300, 200)
	label.install_effect(LogFreshFx.new())
	add_child(label)
	log.label = label
	var t0 := Time.get_ticks_msec()
	label.append_text("[fresh t=%d]A line[/fresh]\n" % t0)
	# Act
	log._settle_fresh_at(t0 + int(LogFreshFx.GLOW_S * 1000.0))
	await get_tree().process_frame
	var while_animating := label.is_processing_internal()
	await await_millis(int(LogFreshFx.GLOW_S * 1000.0) + 200)
	# Assert: it animated, then went still; a new fresh line animates again.
	assert_bool(while_animating).is_true()
	assert_bool(label.is_processing_internal()).is_false()
	label.append_text("[fresh t=%d]Next[/fresh]\n" % Time.get_ticks_msec())
	await get_tree().process_frame
	assert_bool(label.is_processing_internal()).is_true()


func test_idle_card_widget_does_not_process() -> void:
	var w: CardWidget = auto_free(CardWidget.new())
	await _settle(w)
	assert_bool(w.is_processing()).is_false()


func test_draft_slots_breathe_without_redrawing_the_grid() -> void:
	# J31: only the next slot's gold ring breathes; it redraws on its own layer, not the whole grid.
	# Arrange: 8 picks, two made (by kind only, so no card widgets).
	var s: DraftSlots = auto_free(DraftSlots.new().setup(8, ["unit", "spell"]))
	s.size = Vector2(300, 200)
	await _settle(s)
	var ring: Control = s.get_child(0, true)
	var rn := [0]
	ring.draw.connect(func(): rn[0] += 1)
	# Act
	var grid: int = await _idle_draws(s)
	# Assert
	assert_int(grid).is_equal(0)
	if not UIStyle.reduce_motion:
		assert_int(rn[0]).is_greater_equal(FRAMES - 1)


func test_details_empty_art_breathes_without_redrawing() -> void:
	# J31: the engraving breathes by its layer's alpha (modulate), so nothing is repainted per frame.
	# Arrange
	var art: DetailsEmptyArt = auto_free(DetailsEmptyArt.new())
	art.size = Vector2(300, 400)
	await _settle(art)
	var layer: Control = art.get_child(0, true)
	var ln := [0]
	layer.draw.connect(func(): ln[0] += 1)
	var a0 := layer.modulate.a
	# Act
	var draws: int = await _idle_draws(art)
	await await_millis(300)
	# Assert
	assert_int(draws).is_equal(0)
	assert_int(ln[0]).is_equal(0)
	if not UIStyle.reduce_motion:
		assert_bool(absf(layer.modulate.a - a0) > 0.0001).is_true()


func test_draft_pips_breathe_without_redrawing_the_row() -> void:
	# J31: only the current pip breathes; it redraws on its own layer, not the row of 12.
	var p: Control = auto_free(DeckSelectView.DraftPips.new(3, 12))
	await _settle(p)
	var pip: Control = p.get_child(0, true)
	var pn := [0]
	pip.draw.connect(func(): pn[0] += 1)
	var row: int = await _idle_draws(p)
	assert_int(row).is_equal(0)
	if not UIStyle.reduce_motion:
		assert_int(pn[0]).is_greater_equal(FRAMES - 1)
