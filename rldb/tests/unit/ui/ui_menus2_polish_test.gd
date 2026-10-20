extends GdUnitTestSuite
## H1 menus pass, part 2 (design review WP-7 / WP-8 menus side, D3, D5): the OrnatePanel headline
## and open / close motion (#106), the deck select (#53-#55, #58), the draft offer and pips (#56,
## #57), the rewards and deck select SECTION headers, the tutorial menu rows (#97), the tutorial
## sidebar header, footer and hint (#98-#101) and the lesson / tutorial complete cards (#102,
## #103). Nothing here writes a settings file or a deck: tutorial progress runs in memory.

var _rm: bool


func before_test() -> void:
	_rm = UIStyle.reduce_motion
	UIStyle.reduce_motion = false


func after_test() -> void:
	UIStyle.reduce_motion = _rm


# ---------------------------------------------------------------- OrnatePanel (#106, D3)

func test_ornate_headline_is_a_screen_title_over_a_rule() -> void:
	# Arrange
	var p: OrnatePanel = auto_free(OrnatePanel.new(12, 24))
	# Act
	var t := p.add_headline("Deck locked in")
	# Assert: SCREEN tier, upper case, at the top of the content column with the rule under it.
	assert_int(t.tier).is_equal(TitleText.Tier.SCREEN)
	assert_int(t.font_size).is_equal(OrnatePanel.HEADLINE_PX)
	assert_str(t.text).is_equal("DECK LOCKED IN")
	var v := p.content()
	assert_object(v.get_child(0)).is_same(t)
	assert_bool(v.get_child(1) is Ornate.Rule).is_true()


func test_ornate_headline_respects_index_and_is_reused() -> void:
	var p: OrnatePanel = auto_free(OrnatePanel.new())
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(Control.new())
	var t := p.add_headline("First", 24, true, 1)
	assert_object(p.content()).is_same(v)
	assert_object(v.get_child(1)).is_same(t)
	var again := p.add_headline("Second")
	assert_object(again).is_same(t)
	assert_str(t.text).is_equal("SECOND")
	assert_int(v.get_child_count()).is_equal(3)


func test_ornate_appear_fades_in_and_settles() -> void:
	# Arrange
	var p: OrnatePanel = OrnatePanel.new()
	p.size = Vector2(200, 120)
	add_child(p)
	# Act
	p.appear()
	# Assert: starts transparent and scaled down, ends at rest.
	assert_float(p.modulate.a).is_less(0.05)
	assert_float(p.scale.x).is_less(1.0)
	await await_millis(600)
	assert_float(p.modulate.a).is_equal_approx(1.0, 0.001)
	assert_vector(p.scale).is_equal_approx(Vector2.ONE, Vector2(0.001, 0.001))
	p.free()


func test_ornate_appear_under_reduce_motion_is_a_fade_only() -> void:
	UIStyle.reduce_motion = true
	var p: OrnatePanel = OrnatePanel.new()
	p.size = Vector2(200, 120)
	add_child(p)
	p.appear()
	assert_vector(p.scale).is_equal(Vector2.ONE)
	await await_millis(300)
	assert_float(p.modulate.a).is_equal_approx(1.0, 0.001)
	p.free()


func test_ornate_dismiss_frees_once_and_runs_done() -> void:
	var p: OrnatePanel = OrnatePanel.new()
	p.size = Vector2(200, 120)
	add_child(p)
	var calls := [0]
	p.dismiss(true, func(): calls[0] += 1)
	p.dismiss(true, func(): calls[0] += 10)   # ignored: already closing
	assert_bool(p.dismissing).is_true()
	assert_int(p.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	await await_millis(500)
	assert_bool(is_instance_valid(p)).is_false()
	assert_int(calls[0]).is_equal(1)


func test_ornate_reopen_after_dismiss_restores_clicks() -> void:
	var p: OrnatePanel = OrnatePanel.new()
	p.size = Vector2(200, 120)
	add_child(p)
	p.dismiss(false)
	await await_millis(400)
	assert_bool(p.visible).is_false()
	p.visible = true
	p.appear(false)
	assert_bool(p.dismissing).is_false()
	assert_int(p.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	p.free()


func test_wait_plate_uses_the_screen_headline_under_its_rune() -> void:
	var w: WaitPlate = auto_free(WaitPlate.new("Deck locked in", "Waiting", [{"text": "A", "done": true}]))
	assert_object(w.headline).is_not_null()
	assert_int(w.headline.tier).is_equal(TitleText.Tier.SCREEN)
	assert_bool(w.content().get_child(0) is WaitPlate.Rune).is_true()
	assert_object(w.content().get_child(1)).is_same(w.headline)
