extends GdUnitTestSuite
## H1 WP-4 (design review #14, #34, #35, #60, #61, #65, #69-#71, #89): destructive confirms are the
## Danger family with the cancel focused, one primary per view, segmented choices, status lines
## apart from buttons and text links for escape hatches.


func _family(b: Button) -> String:
	return String(b.get_meta(Sfx.FAMILY_META, ""))


func test_danger_confirm_focuses_the_cancel() -> void:
	var d := ConfirmDialog.open(self, "Concede?", "Your opponent wins.", "Concede", func(): pass, "Keep playing", "Concede", "danger")
	await await_idle_frame()
	assert_str(_family(d.button_for("Concede"))).is_equal("danger")
	assert_str(_family(d.button_for("Keep playing"))).is_equal("secondary")
	assert_object(d.focus_button()).is_same(d.button_for("Keep playing"))
	assert_bool(d.button_for("Keep playing").has_focus()).is_true()
	d.close(false)


func test_primary_confirm_focuses_the_confirm() -> void:
	var d := ConfirmDialog.open(self, "Accept?", "Join?", "Join", func(): pass)
	await await_idle_frame()
	assert_str(_family(d.button_for("Join"))).is_equal("primary")
	assert_object(d.focus_button()).is_same(d.button_for("Join"))
	d.close(false)


func test_confirm_buttons_are_standard_size() -> void:
	var d := ConfirmDialog.open(self, "Delete deck", "Sure?", "Delete", func(): pass, "Cancel", "Deck builder", "danger")
	await await_idle_frame()
	var b := d.button_for("Delete")
	assert_float(b.custom_minimum_size.y).is_equal(ConfirmDialog.BUTTON_H)
	assert_float(b.custom_minimum_size.x).is_equal(ConfirmDialog.BUTTON_W)
	d.close(false)


func test_segmented_choice_fills_the_chosen_segment_gold() -> void:
	var seg: SegmentedChoice = auto_free(SegmentedChoice.new(["I go first", "My opponent goes first"], 1))
	assert_str(_family(seg.buttons[0])).is_equal("secondary")
	assert_str(_family(seg.buttons[1])).is_equal("primary")
	assert_str(seg.buttons[1].text).starts_with(SegmentedChoice.CHECK.strip_edges())
	assert_str(seg.buttons[0].text).is_equal("I go first")


func test_segmented_choice_joins_inner_corners() -> void:
	var seg: SegmentedChoice = auto_free(SegmentedChoice.new(["A", "B"], -1))
	var left := UiSurface.flat_of(seg.buttons[0].get_theme_stylebox("normal"))
	var right := UiSurface.flat_of(seg.buttons[1].get_theme_stylebox("normal"))
	assert_int(left.corner_radius_top_left).is_equal(SegmentedChoice.RADIUS)
	assert_int(left.corner_radius_top_right).is_equal(0)
	assert_int(right.corner_radius_top_left).is_equal(0)
	assert_int(right.border_width_left).is_equal(0)


func test_segmented_choice_emits_the_pressed_index() -> void:
	var seg: SegmentedChoice = auto_free(SegmentedChoice.new(["A", "B"], -1))
	var got := []
	seg.chosen.connect(func(i): got.append(i))
	seg.buttons[1].pressed.emit()
	assert_array(got).contains_exactly([1])


func test_stance_answers_are_ember_and_steel() -> void:
	var atk: Button = auto_free(GamePromptBanner.stance_button("Attack stance", "Attack stance"))
	var def: Button = auto_free(GamePromptBanner.stance_button("Defense stance", "Defense stance"))
	assert_str(_family(atk)).is_equal("danger")
	assert_str(_family(def)).is_equal("steel")
	assert_float(atk.custom_minimum_size.y).is_equal(GamePromptBanner.STANCE_H)


func test_text_link_underlines_only_on_hover() -> void:
	var l: TextLink = auto_free(TextLink.make("Cancel"))
	assert_bool(l.flat).is_true()
	assert_bool(l.hovered()).is_false()
	l.mouse_entered.emit()
	assert_bool(l.hovered()).is_true()
	assert_str(Sfx.button_sound(l)).is_equal("back")
