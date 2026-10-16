extends GdUnitTestSuite
## F03-25 / F03-27: the input-required banner and the Type declaration buttons.


func _screen_with_type_choice(card_id: int) -> Array:
	SeriesStore.DIR = "user://test_saves"
	var host: LocalHost = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 11, "best_of": 1, "deck_mode": "starter", "names": ["A", "B"]})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	var m: MatchEngine = host.series.game
	while m.turn < 2 or m.phase != "main1":
		m.submit(m.active, {"t": "next_phase"})
	var a := m.active
	var uid := TB.unit(m, a, card_id, 0, "atk")
	TB.ability(m, uid, 0)
	assert_str(m.pending.get("kind", "")).is_equal("mode")
	host.broadcast()
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 900)
	add_child(gs)
	await gs.attach(host.seats[a])
	await await_idle_frame()
	return [gs, host, m, uid, a]


func _type_buttons(gs: GameScreen) -> Array:
	return gs.prompt.banner_flow.get_children().filter(func(b): return b.has_meta("type_choice"))


func test_waang_offers_only_its_four_types_in_type_colours() -> void:
	var r := await _screen_with_type_choice(102)
	var gs: GameScreen = r[0]
	var btns := _type_buttons(gs)
	var names := btns.map(func(b): return String(b.get_meta("type_choice")))
	assert_array(names).is_equal(["Water", "Fire", "Earth", "Lightning"])
	for b in btns:
		var t: String = b.get_meta("type_choice")
		var sb := (b as Button).get_theme_stylebox("normal") as StyleBoxFlat
		assert_that(sb.bg_color).is_equal(UIStyle.type_color(t))
		assert_bool(b.get_child_count() > 0 and b.get_child(0) is TypeIcons.TypeBadge).is_true()
		assert_str((b.get_child(0) as TypeIcons.TypeBadge).type_name).is_equal(t)


func test_chaos_witch_offers_all_seven_types() -> void:
	var r := await _screen_with_type_choice(13)
	assert_int(_type_buttons(r[0]).size()).is_equal(7)


func test_clicking_a_type_button_declares_that_type() -> void:
	var r := await _screen_with_type_choice(102)
	var gs: GameScreen = r[0]
	var m: MatchEngine = r[2]
	var uid: int = r[3]
	for b in _type_buttons(gs):
		if b.get_meta("type_choice") == "Earth":
			(b as Button).pressed.emit()
	assert_bool(m.pending.is_empty()).is_true()
	assert_str(str(m.cards[uid]["type_o"])).is_equal("Earth")


func test_type_button_text_is_readable_in_every_state() -> void:
	for t in UIStyle.TYPE_COLORS.keys():
		if t == "":
			continue
		var b: Button = auto_free(GamePromptBanner.type_button(t))
		for state in ["normal", "hover", "pressed"]:
			var fill: Color = (b.get_theme_stylebox(state) as StyleBoxFlat).bg_color
			var key := "font_color" if state == "normal" else "font_%s_color" % state
			var txt: Color = b.get_theme_color(key)
			assert_float(GamePromptBanner._contrast(fill, txt)).is_greater(4.0)


func test_non_type_mode_choice_is_not_type_styled() -> void:
	var pd := {"kind": "mode", "options": [{"label": "10 Burn"}, {"label": "Water"}]}
	assert_bool(GamePromptBanner.is_type_choice(pd)).is_false()
	assert_bool(GamePromptBanner.is_type_choice({"kind": "mode", "options": [{"label": "Fire"}, {"label": "Water"}]})).is_true()


func test_banner_is_clear_of_board_zones_and_plates() -> void:
	var r := await _screen_with_type_choice(102)
	var gs: GameScreen = r[0]
	await await_idle_frame()
	assert_bool(gs.prompt.ctx_banner.visible).is_true()
	var br := gs.prompt.ctx_banner.get_global_rect()
	for k in gs.board.slots:
		assert_bool(br.intersects((gs.board.slots[k]["zone_node"] as Control).get_global_rect())).is_false()
	for pl in gs.board.plates:
		assert_bool(br.intersects((pl as Control).get_global_rect())).is_false()
	for side in 2:
		for z in gs.board.piles[side]:
			assert_bool(br.intersects((gs.board.piles[side][z] as Control).get_global_rect())).is_false()
	assert_str(gs.prompt.banner_tag.text).contains("YOUR DECISION")
