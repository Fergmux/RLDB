extends GdUnitTestSuite
## L17 (owner feedback 2026-11-05): "atk/def indicators on the card on the field are slightly too large,
## they just overlap the border of the card, they should just fit within the bounds of the card border
## ... same for the cost/type circles, nudge them inset slightly to avoid the card edge".
##
## Every jewel set into a card face (cost gem of each cost kind, Type pip, ATK and DEF badges) must sit
## inside the frame's border: its solid outline (out to the setting's dark edge) at least SOLID_MARGIN
## base units in from the border's inner edge, and its drop shadow inside that edge. Checked for the
## field layout (field units, Powers, Traps, Defense units) and the tall layout (hand, mini in the deck
## builder and prompts, big in the draft, inspector and details), at the painter scales they are drawn at.

## Base units a jewel's solid outline keeps clear of the border's inner edge.
const SOLID_MARGIN := 0.3
## Painter scales: mini (90 px wide), field / hand, a large field card, big (224 px) and the inspector.
const SCALES := [0.75, 1.0, 1.25, 224.0 / 120.0, 2.6]
const KINDS := ["ap", "fusion", "ritual", "arcane"]


## The frame's border width (base units) at painter scale `s` (CardFaceParts.frame: an integer px width).
func _border(s: float) -> float:
	return float(maxi(2, roundi(2.8 * s))) / s


## How far `p` lies inside the rounded rect `r` with corner radius `rad` (negative: outside).
func _inside(p: Vector2, r: Rect2, rad: float) -> float:
	var d := minf(minf(p.x - r.position.x, r.end.x - p.x), minf(p.y - r.position.y, r.end.y - p.y))
	if rad <= 0.0:
		return d
	var cx := clampf(p.x, r.position.x + rad, r.end.x - rad)
	var cy := clampf(p.y, r.position.y + rad, r.end.y - rad)
	var c := Vector2(cx, cy)
	if c.is_equal_approx(p):
		return d
	return minf(d, rad - c.distance_to(p))


## Every jewel of layout `g` (base `size`, outer corner radius `radius`) that crosses the border, as text.
func _crossings(g: Dictionary, size: Vector2, radius: float, unit: bool) -> Array:
	var bad := []
	for s in SCALES:
		var bw := _border(s)
		var inner := Rect2(Vector2(bw, bw), size - Vector2(bw, bw) * 2.0)
		var rad := maxf(0.0, float(roundi(radius * s)) / s - bw)
		for kind in KINDS:
			for j in CardLayouts.jewel_outlines(g, kind, s, unit):
				var worst := INF
				for p in j["solid"]:
					worst = minf(worst, _inside(p, inner, rad))
				var worst_sh := INF
				for p in j["shadow"]:
					worst_sh = minf(worst_sh, _inside(p, inner, rad))
				if worst < SOLID_MARGIN or worst_sh < 0.0:
					bad.append("%s %s s=%.2f: solid %.2f, shadow %.2f" % [j["name"], kind, s, worst, worst_sh])
	return bad


func test_field_card_jewels_fit_inside_the_border() -> void:
	# Arrange / Act
	var bad := _crossings(CardLayouts.FIELD, CardWidget.SIZES["board"], CardLayouts.RADIUS_SMALL, true)
	# Assert
	assert_array(bad).is_empty()


func test_field_power_and_trap_jewels_fit_inside_the_border() -> void:
	var bad := _crossings(CardLayouts.FIELD, CardWidget.SIZES["power"], CardLayouts.RADIUS_SMALL, false)
	assert_array(bad).is_empty()


func test_tall_card_jewels_fit_inside_the_border() -> void:
	var bad := _crossings(CardLayouts.TALL, CardWidget.SIZES["hand"], CardLayouts.RADIUS_TALL, true)
	assert_array(bad).is_empty()


## The gem keeps the same clearance from the card edge whatever its shape: the Ritual lozenge and the
## Arcane hexagon sit further in by exactly the distance their points stand out past the round gem.
func test_every_cost_shape_keeps_the_same_edge_clearance() -> void:
	for g in [CardLayouts.FIELD, CardLayouts.TALL]:
		var r := float(g["gem_r"])
		var ap_edge := CardLayouts.gem_center(g, "ap").x - r
		for kind in KINDS:
			var c := CardLayouts.gem_center(g, kind)
			assert_float(c.x - r * CardFaceParts.gem_reach(kind)).is_equal_approx(ap_edge, 0.001)
			assert_float(c.y).is_equal_approx(c.x, 0.001)


## The nudge stays small: the field jewels keep at least 95 % of their size (owner: "they don't need to
## be reduced by much") and the gem stays in the top-left corner of the art.
func test_field_jewels_shrink_only_slightly() -> void:
	var g: Dictionary = CardLayouts.FIELD
	assert_float(float(g["gem_r"])).is_greater_equal(9.8 * 0.95)
	assert_float(float(g["atk"][3])).is_greater_equal(34.0 * 0.9)
	assert_float(float(g["def"][3])).is_greater_equal(34.0 * 0.9)
	assert_float(CardLayouts.gem_center(g, "ap").x).is_less(16.0)
