extends GdUnitTestSuite
## WP-2 / D3: TitleText tier parameters (design review 1.4.1), sweep timing with an injected
## clock, stacked-layer maths and the in-place Label restyle.

const T := TitleText.Tier

var _rm: bool
var _fast: bool
var _now: float = 50.0


func before_test() -> void:
	_rm = UIStyle.reduce_motion
	_fast = UIStyle.fast_anim
	UIStyle.reduce_motion = false
	UIStyle.fast_anim = false
	_now = 50.0


func after_test() -> void:
	UIStyle.reduce_motion = _rm
	UIStyle.fast_anim = _fast


func _clock() -> float:
	return _now


func test_hero_tier_matches_spec() -> void:
	var p := TitleText.params(T.HERO)
	assert_int(int(p["size"])).is_equal(88)
	var stops: PackedFloat32Array = p["stops"]
	for i in 4:
		assert_float(stops[i]).is_equal_approx([0.0, 0.45, 0.55, 1.0][i], 0.0001)
	assert_array(Array(p["colors"])).is_equal([Color("fff1c4"), Color("f0cf7a"), Color("b8862e"), Color("e2b75a")])
	assert_float(float(p["outline"])).is_equal(2.0)
	assert_that(p["outline_color"]).is_equal(Color("2a1a08"))
	var sh: Array = p["shadows"]
	assert_int(sh.size()).is_equal(2)
	assert_that(sh[0]["offset"]).is_equal(Vector2(0, 3))
	assert_float(float(sh[0]["blur"])).is_equal(0.0)
	assert_that(sh[0]["color"]).is_equal(Color(0, 0, 0, 0.85))
	assert_that(sh[1]["offset"]).is_equal(Vector2(0, 8))
	assert_float(float(sh[1]["blur"])).is_equal(18.0)
	assert_that(sh[1]["color"]).is_equal(Color(0, 0, 0, 0.6))
	assert_float(float(p["glow"])).is_equal(14.0)
	assert_that(p["glow_color"]).is_equal(Color(UIStyle.GOLD, 0.30))
	assert_str(String(p["sweep"])).is_equal(TitleText.SWEEP_LOOP)


func test_defeat_tier_uses_the_ember_palette() -> void:
	var p := TitleText.params(T.HERO_DEFEAT)
	assert_array(Array(p["colors"])).is_equal([Color("ffd0c4"), Color("e8605a"), Color("8e2a22"), Color("c4473d")])
	assert_that(p["glow_color"]).is_equal(Color(Color("e8605a"), 0.30))
	assert_that(p["outline_color"]).is_equal(Color("2a0806"))


func test_screen_tier_matches_spec() -> void:
	var p := TitleText.params(T.SCREEN)
	assert_array(Array(p["colors"])).is_equal([Color("f6dc96"), Color("d4a64a"), Color("a97c34")])
	assert_float(float(p["outline"])).is_equal(1.0)
	assert_that(p["outline_color"]).is_equal(Color("1a1208"))
	var sh: Array = p["shadows"]
	assert_that(sh[0]["offset"]).is_equal(Vector2(0, 2))
	assert_that(sh[0]["color"]).is_equal(Color(0, 0, 0, 0.8))
	assert_that(sh[1]["offset"]).is_equal(Vector2(0, 4))
	assert_float(float(sh[1]["blur"])).is_equal(8.0)
	assert_float(float(p["glow"])).is_equal(0.0)
	assert_str(String(p["sweep"])).is_equal(TitleText.SWEEP_ONCE)


func test_section_tier_is_flat_gold_with_hard_shadow_and_underline() -> void:
	var p := TitleText.params(T.SECTION)
	assert_array(Array(p["colors"])).is_equal([UIStyle.GOLD, UIStyle.GOLD])
	assert_float(float(p["outline"])).is_equal(0.0)
	var sh: Array = p["shadows"]
	assert_int(sh.size()).is_equal(1)
	assert_that(sh[0]["offset"]).is_equal(Vector2(0, 1))
	assert_that(sh[0]["color"]).is_equal(Color(0, 0, 0, 0.9))
	assert_bool(bool(p["underline"])).is_true()
	assert_int(int(p["spacing"])).is_greater(0)
	assert_str(String(p["sweep"])).is_equal(TitleText.SWEEP_NONE)


func test_menu_tier_is_ivory_and_hovers_to_the_screen_gradient() -> void:
	var p := TitleText.params(T.MENU)
	assert_array(Array(p["colors"])).is_equal([UIStyle.TEXT, UIStyle.TEXT])
	assert_array(Array(p["hover_colors"])).is_equal(Array(TitleText.params(T.SCREEN)["colors"]))
	assert_that(p["outline_color"]).is_equal(Color(0, 0, 0, 0.7))
	assert_float(float(p["hover_glow"])).is_equal(10.0)


func test_loop_sweep_runs_a_pass_every_period() -> void:
	assert_float(TitleText.sweep_phase(TitleText.SWEEP_LOOP, 0.45)).is_equal_approx(0.5, 0.0001)
	assert_float(TitleText.sweep_phase(TitleText.SWEEP_LOOP, 3.0)).is_equal(-1.0)
	assert_float(TitleText.sweep_phase(TitleText.SWEEP_LOOP, 6.45)).is_equal_approx(0.5, 0.0001)
	assert_float(TitleText.sweep_phase(TitleText.SWEEP_LOOP, -0.1)).is_equal(-1.0)


func test_once_sweep_plays_one_pass_and_none_never() -> void:
	assert_float(TitleText.sweep_phase(TitleText.SWEEP_ONCE, 0.0)).is_equal(0.0)
	assert_float(TitleText.sweep_phase(TitleText.SWEEP_ONCE, 0.9)).is_equal(-1.0)
	assert_float(TitleText.sweep_phase(TitleText.SWEEP_ONCE, 6.45)).is_equal(-1.0)
	assert_float(TitleText.sweep_phase(TitleText.SWEEP_NONE, 0.45)).is_equal(-1.0)


func test_stacked_layers_total_the_requested_alpha() -> void:
	var n := 7
	var a := TitleText.layer_alpha(0.6, n)
	assert_float(1.0 - pow(1.0 - a, n)).is_equal_approx(0.6, 0.0001)
	assert_float(TitleText.layer_alpha(0.6, 1)).is_equal(0.6)
	assert_int(TitleText.blur_layers(18.0)).is_equal(TitleText.MAX_BLUR_LAYERS)
	assert_int(TitleText.blur_layers(8.0)).is_equal(4)
	assert_int(TitleText.blur_layers(0.5)).is_equal(1)


func test_hero_sweep_follows_the_injected_clock() -> void:
	var t: TitleText = auto_free(TitleText.make("RLDB", T.HERO))
	t.clock = _clock
	add_child(t)
	assert_float(t.current_sweep_phase()).is_equal(-1.0)   # waiting for the first-pass delay
	_now += TitleText.SWEEP_FIRST_DELAY + TitleText.SWEEP_DURATION * 0.25
	assert_float(t.current_sweep_phase()).is_equal_approx(0.25, 0.0001)
	_now += TitleText.SWEEP_PERIOD
	assert_float(t.current_sweep_phase()).is_equal_approx(0.25, 0.0001)


func test_reduce_motion_removes_the_sweep_only() -> void:
	UIStyle.reduce_motion = true
	var t: TitleText = auto_free(TitleText.make("DEFEAT", T.HERO_DEFEAT))
	t.clock = _clock
	add_child(t)
	t.play_sweep()
	_now += TitleText.SWEEP_FIRST_DELAY + 0.3
	assert_float(t.current_sweep_phase()).is_equal(-1.0)
	assert_float(float(TitleText.params(T.HERO_DEFEAT)["glow"])).is_greater(0.0)


func test_screen_title_sweeps_once_when_played() -> void:
	var t: TitleText = auto_free(TitleText.make("SETTINGS", T.SCREEN))
	t.clock = _clock
	add_child(t)
	_now += 5.0
	assert_float(t.current_sweep_phase()).is_equal(-1.0)
	t.play_sweep()
	_now += 0.45
	assert_float(t.current_sweep_phase()).is_equal_approx(0.5, 0.0001)


func test_make_uses_the_tier_size_by_default() -> void:
	var t: TitleText = auto_free(TitleText.make("CHOOSE YOUR DECK", T.SCREEN))
	assert_int(t.effective_font_size()).is_equal(36)
	var t2: TitleText = auto_free(TitleText.make("CHOOSE YOUR DECK", T.SCREEN, 30))
	assert_int(t2.effective_font_size()).is_equal(30)
	assert_float(t.get_combined_minimum_size().x).is_greater(t2.get_combined_minimum_size().x)


func test_shrink_to_fit_reduces_the_size_to_the_width() -> void:
	var t: TitleText = auto_free(TitleText.make("BOOM, COUNCILLOR OF THE ORDER", T.SCREEN, 20))
	t.shrink_to_fit = true
	t.min_font_size = 12
	t.size = Vector2(200, 30)
	assert_int(t.effective_font_size()).is_less(20)
	assert_int(t.effective_font_size()).is_greater_equal(12)


func test_apply_follows_the_label_text_and_colour() -> void:
	var l: Label = auto_free(UIStyle.label("Ben", 18, UIStyle.TEXT, false, true))
	add_child(l)
	var t := TitleText.apply(l, T.SECTION)
	assert_that(l.self_modulate.a).is_equal(0.0)
	assert_str(t.text).is_equal("Ben")
	assert_int(t.effective_font_size()).is_equal(18)
	l.text = "Ana"
	l.add_theme_color_override("font_color", UIStyle.GOLD_HI)
	t._sync_from_label()
	assert_str(t.text).is_equal("Ana")
	assert_that(t.fill_color).is_equal(UIStyle.GOLD_HI)
	# A second apply re-tiers the same overlay rather than stacking a new one.
	var t2 := TitleText.apply(l, T.SCREEN)
	assert_object(t2).is_same(t)
	assert_int(t2.tier).is_equal(T.SCREEN)


func test_apply_reserves_room_for_the_underline() -> void:
	var l: Label = auto_free(UIStyle.label("GAME LOG", 18, UIStyle.GOLD, false, true))
	add_child(l)
	var plain_h := l.get_combined_minimum_size().y
	var t := TitleText.apply(l, T.SECTION)
	assert_float(l.get_combined_minimum_size().y).is_greater_equal(plain_h + t.underline_room() - 0.5)
	t.show_underline = false
	assert_float(t.underline_room()).is_equal(0.0)


func test_style_label_fallback_sets_outline_and_shadow() -> void:
	var l: Label = auto_free(Label.new())
	TitleText.style_label(l, T.SCREEN)
	assert_int(l.get_theme_font_size("font_size")).is_equal(36)
	assert_that(l.get_theme_color("font_shadow_color")).is_equal(Color(0, 0, 0, 0.8))
	assert_int(l.get_theme_constant("shadow_offset_y")).is_equal(2)
	assert_int(l.get_theme_constant("outline_size")).is_greater(0)


func test_cap_height_is_measured_from_the_font() -> void:
	var h := TitleText.cap_height(TitleText.tier_font(T.HERO), 100)
	assert_float(h).is_between(60.0, 80.0)
