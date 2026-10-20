extends GdUnitTestSuite
## Design review #93: in the Fusion-method picker each method's card and its button are one tile;
## hovering the tile lights its rim and gives the button its hover face, and a click on the tile
## picks the method.


func _tile() -> Array:
	var t: GameDetails.MethodTile = auto_free(GameDetails.MethodTile.new())
	add_child(t)
	var b := UIStyle.button("Cast", 14)
	t.col.add_child(b)
	var picked := [0]
	var lifts := []
	t.bind(null, b, func(): picked[0] += 1, func(on: bool): lifts.append(on))
	return [t, b, picked, lifts]


func test_hover_lights_the_rim_and_the_button_together() -> void:
	var r := _tile()
	var t: GameDetails.MethodTile = r[0]
	var b: Button = r[1]
	t.set_hover(true)
	var sb := t.get_theme_stylebox("panel") as StyleBoxFlat
	assert_object(sb.border_color).is_equal(UIStyle.GOLD_HI)
	assert_object(b.get_theme_stylebox("normal")).is_same(b.get_theme_stylebox("hover"))
	t.set_hover(false)
	assert_bool(b.has_theme_stylebox_override("normal")).is_false()


func test_click_on_the_tile_picks_the_method() -> void:
	var r := _tile()
	var t: GameDetails.MethodTile = r[0]
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	t._gui_input(e)
	assert_int(int(r[2][0])).is_equal(1)


func test_method_card_is_150_px_wide() -> void:
	assert_float(GameDetails.METHOD_CARD.x).is_equal(150.0)
