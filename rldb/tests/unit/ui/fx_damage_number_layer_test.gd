extends GdUnitTestSuite
## H23 (owner feedback 2026-10-21): on a killing blow the floating "HP lost" number appeared under the
## loser's player plate. The struck plate is raised above its own blast (UI review F12: FX + 1), while the
## numbers sat in the fx layer at FX, so the plate covered them. Every damage / HP number must draw above
## a raised plate: the killing overflow, the big strike number and the plain HP floater, for both seats.


func _screen() -> GameScreen:
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	return gs


## The z a CanvasItem finally draws at (its own z_index plus every relative ancestor's).
static func _abs_z(n: CanvasItem) -> int:
	var z := n.z_index
	var cur: CanvasItem = n
	while cur.z_as_relative:
		var p := cur.get_parent()
		if not (p is CanvasItem):
			break
		cur = p
		z += cur.z_index
	return z


## The fx-layer labels showing `text`.
func _labels(gs: GameScreen, text: String) -> Array:
	var out := []
	for n in gs.fx_layer.get_children():
		if n is Label and (n as Label).text == text:
			out.append(n)
	return out


func test_killing_overflow_number_draws_above_the_raised_plate() -> void:
	for p in 2:
		var gs := _screen()
		var pl: PlayerPlate = gs.plate_of(p)
		var ctx := {"plate_c": pl.get_global_rect().get_center(), "col": Color.ORANGE, "pl": pl, "dmg": 15}
		gs.fx._strike._overflow(ctx, 900.0)
		var nums := _labels(gs, "-15")
		assert_int(nums.size()).is_equal(1)
		assert_int(_abs_z(pl)).is_greater(UiLayers.FX)   # the plate still reads above its blast
		assert_int(_abs_z(nums[0])).is_greater(_abs_z(pl))
		gs.fx.finish_all()


func test_big_strike_number_and_hp_floater_draw_above_a_raised_plate() -> void:
	for p in 2:
		var gs := _screen()
		var pl: PlayerPlate = gs.plate_of(p)
		pl.z_index = UiLayers.FX + 1   # as FxStrike / FxSerpent raise a struck plate
		gs.fx.damage_number(pl.get_global_rect().get_center(), 9, Color.RED, 84)
		gs.fx.float_text("-4", Color.RED, pl.hp_anchor(), 28, 22.0, 0.7)
		var big := _labels(gs, "-9")
		var small := _labels(gs, "-4")
		assert_int(big.size()).is_equal(1)
		assert_int(small.size()).is_equal(1)
		assert_int(_abs_z(big[0])).is_greater(_abs_z(pl))
		assert_int(_abs_z(small[0])).is_greater(_abs_z(pl))
		gs.fx.finish_all()
