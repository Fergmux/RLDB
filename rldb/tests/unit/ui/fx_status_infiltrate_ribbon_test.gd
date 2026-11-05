extends GdUnitTestSuite
## QA 2026-11-05 leftover (design/qa-final-2026-11-05.md): Infiltrate's curled shadow tendril could
## cross itself; draw_colored_polygon then failed to triangulate ("Invalid polygon data") and the
## tendril was not drawn. FxStatusArt.draw_ribbon draws such a ribbon as a strip of quads instead.


func _ribbon(curl: float) -> Array:
	# A tapered ribbon along a spiral: a strong curl makes its outline cross itself.
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var p := Vector2(10, 50)
	var d := Vector2(1, 0)
	var segs := 16
	var pts := PackedVector2Array()
	for j in segs + 1:
		pts.append(p)
		var f := float(j) / float(segs)
		d = d.rotated(curl * f * f * 0.2)
		p += d * 6.0
	for j in pts.size():
		var tang := (pts[mini(j + 1, segs)] - pts[maxi(j - 1, 0)]).normalized()
		var w := 9.0 * (1.0 - float(j) / float(segs)) + 0.5
		left.append(pts[j] + tang.orthogonal() * w)
		right.append(pts[j] - tang.orthogonal() * w)
	return [left, right]


## Draws the ribbon inside `ci`'s draw (drawing is only allowed there) and returns draw_ribbon's result.
func _draw_in(ci: Control, r: Array) -> PackedInt32Array:
	var out := [PackedInt32Array([-1])]
	ci.draw.connect(func(): out[0] = FxStatusArt.draw_ribbon(ci, r[0], r[1], Color.BLACK), CONNECT_ONE_SHOT)
	ci.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	return out[0]


func test_self_crossing_ribbon_is_drawn_as_a_strip() -> void:
	# Arrange
	var ci: Control = auto_free(Control.new())
	add_child(ci)
	# A ribbon twisted on itself, as a sharply curled tendril's edges are: its two edges swap sides.
	var r := [PackedVector2Array([Vector2(0, 0), Vector2(10, 10), Vector2(20, 0)]),
		PackedVector2Array([Vector2(0, 10), Vector2(10, 0), Vector2(20, 10)])]
	var outline: PackedVector2Array = (r[0] as PackedVector2Array).duplicate()
	var back: PackedVector2Array = (r[1] as PackedVector2Array).duplicate()
	back.reverse()
	outline.append_array(back)
	assert_bool(Geometry2D.triangulate_polygon(outline).is_empty()).is_true()   # the fixture does cross
	# Act
	var idx: PackedInt32Array = await _draw_in(ci, r)
	# Assert: 2 quads, two triangles each
	assert_int(idx.size()).is_equal(2 * 6)


func test_simple_ribbon_is_still_one_polygon() -> void:
	var ci: Control = auto_free(Control.new())
	add_child(ci)
	var r := _ribbon(0.5)
	var idx: PackedInt32Array = await _draw_in(ci, r)
	assert_int(idx.size()).is_equal(0)


func test_ribbon_strip_indices_pair_the_two_edges() -> void:
	assert_array(Array(FxStatusArt.ribbon_strip(3))).is_equal([0, 1, 3, 1, 4, 3, 1, 2, 4, 2, 5, 4])
