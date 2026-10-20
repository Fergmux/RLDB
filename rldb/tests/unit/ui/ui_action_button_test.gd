extends GdUnitTestSuite
## H2 (owner feedback 21 Oct 2026): the card action buttons are forged gold-and-metal plates with
## distinct hover, press and disabled states, a glyph per action and the shared sounds.

const Btn := GameActionRow.ActionButton


func test_action_button_states_differ_by_face_and_rim() -> void:
	# Arrange / Act
	var st := Btn.styles()
	var n := UiSurface.flat_of(st["normal"])
	var h := UiSurface.flat_of(st["hover"])
	var p := UiSurface.flat_of(st["pressed"])
	var d := UiSurface.flat_of(st["disabled"])
	# Assert: hover is warmer with a gold glow, pressed is darker and sits lower, disabled is plain
	assert_bool(h.bg_color.v > n.bg_color.v).is_true()
	assert_bool(p.bg_color.v < n.bg_color.v).is_true()
	assert_bool(h.shadow_color.r > h.shadow_color.b).is_true()
	assert_float(p.content_margin_top).is_greater(n.content_margin_top)
	assert_bool(st["disabled"] is UiSurface.SurfaceBox).is_false()
	assert_bool(st["normal"] is UiSurface.SurfaceBox).is_true()
	assert_object(d).is_not_null()


func test_action_button_reports_its_plate_state() -> void:
	var b: Btn = auto_free(Btn.new("Summon", "summon"))
	assert_str(b.plate_state()).is_equal("normal")
	b._hover = true
	assert_str(b.plate_state()).is_equal("hover")
	b._down = true
	assert_str(b.plate_state()).is_equal("pressed")
	b.disabled = true
	assert_str(b.plate_state()).is_equal("disabled")


func test_keyboard_pick_wears_the_hover_rim() -> void:
	var b: Btn = auto_free(Btn.new("Attack", "attack", "", true))
	assert_str(b.plate_state()).is_equal("hover")
	assert_int(UiSurface.flat_of(b.get_theme_stylebox("normal")).border_width_top).is_equal(2)


func test_action_button_keeps_its_label_and_leaves_the_click_to_run_action() -> void:
	# run_action plays confirm (or deny), so the button itself makes no second click.
	var b: Btn = auto_free(Btn.new("Set", "set"))
	assert_str(b.text).is_equal("Set")
	assert_str(Sfx.button_sound(b)).is_empty()
	assert_bool(b is JuicyButton).is_true()


func test_action_button_label_leaves_room_for_the_glyph() -> void:
	var b: Btn = auto_free(Btn.new("Summon", "summon"))
	assert_float(b.get_theme_stylebox("normal").content_margin_left).is_greater_equal(Btn.GLYPH_W)
