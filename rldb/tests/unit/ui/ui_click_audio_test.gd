extends GdUnitTestSuite
## F22 / F25: every button clicks through one shared hook, gold and brown buttons have distinct clicks,
## navigation back has one back sound, disabled buttons stay silent and one action makes one UI sound.

var _nodes: Array = []


func before_test() -> void:
	Sfx.install_button_sounds()
	Sfx._reset_ui()


func after_test() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			n.free()
	_nodes.clear()
	Sfx._reset_ui()


func _add(b: Node) -> Node:
	_nodes.append(b)
	add_child(b)
	return b


func test_shared_buttons_resolve_their_family_click() -> void:
	assert_str(Sfx.button_sound(_add(UIStyle.button("Play")))).is_equal("click_secondary")
	assert_str(Sfx.button_sound(_add(UIStyle.primary_button("Start")))).is_equal("click_primary")
	assert_str(Sfx.button_sound(_add(MenuItem.new("Decks")))).is_equal("click_primary")


func test_back_controls_play_the_back_sound() -> void:
	for t in ["Back", "< Back", "Back to menu", "Cancel", "Close", "Exit tutorial", "Leave lobby"]:
		assert_str(Sfx.button_sound(_add(UIStyle.button(t)))).is_equal("back")
	assert_str(Sfx.button_sound(_add(UIStyle.primary_button("Back to menu")))).is_equal("back")
	assert_str(Sfx.button_sound(_add(MenuItem.new("Back", 22, true)))).is_equal("back")
	assert_bool(Sfx.is_back_text("Backrow")).is_true()   # documented: label prefix rule
	assert_bool(Sfx.is_back_text("Play")).is_false()


func test_gold_styled_plain_button_is_the_primary_family() -> void:
	var b: Button = _add(Button.new())
	b.text = "Use"
	b.add_theme_stylebox_override("normal", UIStyle.flat(UIStyle.GOLD))
	assert_str(Sfx.button_sound(b)).is_equal("click_primary")
	var brown: Button = _add(Button.new())
	brown.text = "Tab"
	brown.add_theme_stylebox_override("normal", UIStyle.flat(Color(0.085, 0.07, 0.056, 0.95), UIStyle.BRONZE, 2))
	assert_str(Sfx.button_sound(brown)).is_equal("click_secondary")


func test_meta_override_and_silence() -> void:
	var b: Button = _add(UIStyle.button("Add"))
	b.set_meta(Sfx.BUTTON_META, "deck_add")
	assert_str(Sfx.button_sound(b)).is_equal("deck_add")
	b.set_meta(Sfx.BUTTON_META, "none")
	assert_str(Sfx.button_sound(b)).is_equal("")


func test_a_press_makes_exactly_one_sound_even_with_a_handler_sound() -> void:
	var b: Button = _add(UIStyle.button("Back"))
	b.pressed.connect(func(): Sfx.play("cancel"))   # a site that still plays its own sound
	b.pressed.emit()
	assert_array(Sfx.debug_ui).is_equal(["back"])
	Sfx._reset_ui()
	var c: Button = _add(UIStyle.button("Choose"))
	c.pressed.connect(func(): Sfx.play("confirm"))
	c.pressed.emit()
	assert_array(Sfx.debug_ui).is_equal(["confirm"])


func test_button_is_wired_once_across_tree_reentry() -> void:
	var b: Button = _add(UIStyle.primary_button("Go"))
	remove_child(b)
	add_child(b)
	b.pressed.emit()
	assert_array(Sfx.debug_ui).is_equal(["click_primary"])


func test_disabled_button_is_silent() -> void:
	var b: Button = _add(UIStyle.primary_button("Go"))
	b.disabled = true
	# A disabled BaseButton emits no `pressed`; the hook also refuses one that slips through.
	Sfx.ButtonHook.new().on_pressed(b)
	assert_array(Sfx.debug_ui).is_empty()


func test_ui_coalescing_rules() -> void:
	Sfx._reset_ui()
	assert_int(Sfx.ui_decide("click_secondary", 10)).is_equal(Sfx.PLAY)
	Sfx.play("click_secondary")
	var f := Engine.get_process_frames()
	assert_int(Sfx.ui_decide("back", f)).is_equal(Sfx.REPLACE)
	assert_int(Sfx.ui_decide("select", f)).is_equal(Sfx.DROP)
	assert_int(Sfx.ui_decide("click_secondary", f)).is_equal(Sfx.DROP)
	assert_int(Sfx.ui_decide("select", f + 1)).is_equal(Sfx.PLAY)


func test_ui_and_deck_sounds_exist() -> void:
	for n in ["click_primary", "click_secondary", "back", "deck_add", "deck_remove"]:
		assert_bool(Sfx.NAMES.has(n)).is_true()
		assert_bool(Sfx.UI_PRIORITY.has(n)).is_true()
		assert_bool(ResourceLoader.exists("res://assets/audio/sfx/%s.wav" % n)).is_true()
