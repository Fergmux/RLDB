class_name CardFaceParts
extends RefCounted
## Shared card-face parts drawn in card-face space: the layered frame, the name plate, the cost gem
## (shape per cost kind), the damage-type pip and the race / type line. All values are read from
## the painter's view at draw time, so runtime changes show immediately.

## Text colour for a reduced / increased AP cost on the gem.
const COST_CHEAP := Color("0d5a24")
const COST_DEAR := Color("8a1a14")
## Card body fill and its pebbled-leather grain (strength 0..1, tile span in base units).
const BODY := Color("1d1a18")
const BODY_GRAIN := 0.55
const BODY_TILE := 210.0
## Name plate fill and its brushed-metal grain.
const PLATE := Color(0.102, 0.086, 0.075, 0.94)
const PLATE_GRAIN := 0.45
const PLATE_TILE := 150.0
## H17: depth (base units) of the gilded setting round the cost gem, and the round gem's table size.
const GEM_SETTING := 2.5
const GEM_TABLE_K := 0.6
## Dark gap (base units) between the cost gem's setting and its stone.
const GEM_GAP := 0.5


## Card body: kind-coloured border with a drop shadow (larger while hovered), inner gradient and a
## gold top highlight. `radius` is in base units.
static func frame(pt: CardPainter, radius: float) -> void:
	var ci := pt.ci
	var s := pt.s
	var sb := pt.sbox(BODY, pt.accent(), maxi(2, roundi(2.8 * s)), roundi(radius * s))
	# Depth 2 at rest, depth 3 while hovered (design review #32): the shadow grows and falls further.
	sb.shadow_color = Color(0, 0, 0, 0.6 if pt.hover else 0.5)
	sb.shadow_size = roundi((16.0 if pt.hover else 7.0) * s)
	sb.shadow_offset = pt.shadow_off((7.0 if pt.hover else 3.0) * s)
	ci.draw_style_box(sb, Rect2(Vector2.ZERO, pt.ps))
	var inset := 3.0 * s
	UiSurface.draw_round(ci, Rect2(inset, inset, pt.ps.x - 2 * inset, pt.ps.y - 2 * inset), maxf(0.0, (radius - 3.0) * s), UiSurface.PEBBLE, BODY, BODY_GRAIN, BODY_TILE * s)
	pt.vgrad(Rect2(inset, inset, pt.ps.x - 2 * inset, pt.ps.y - 2 * inset), Color(pt.accent().darkened(0.7), 0.45), Color(0, 0, 0, 0.45))
	ci.draw_line(Vector2(radius * s, 3.5 * s), Vector2(pt.ps.x - radius * s, 3.5 * s), Color(UIStyle.GOLD_HI, 0.4), maxf(1.0, s), true)


## Name plate. The full name always shows on one line (H14 / H19, 21 Oct: it replaced the two-line
## split and the field ellipsis): from `fs_max` it shrinks to `fs_min`, then condenses
## (CardTextLayout.fit_name_line). `stripe` is the colour of the kind stripe along the plate's foot.
## `one_line` is kept for callers; every plate is one line now.
static func name_plate(pt: CardPainter, rect: Rect2, fs_max: float, reserve_l: float, reserve_r: float, stripe: Color, fs_min: float = 9.0, one_line: bool = false) -> void:
	var ci := pt.ci
	var s := pt.s
	pt.round_rect(rect, PLATE, 4.0 * s, Color(UIStyle.GOLD, 0.65), maxf(1.0, s))
	UiSurface.draw_round(ci, rect.grow(-maxf(1.0, s)), 3.0 * s, UiSurface.METAL, PLATE, PLATE_GRAIN, PLATE_TILE * s, rect.position)
	ci.draw_rect(Rect2(rect.position.x + 3 * s, rect.end.y - 3.0 * s, rect.size.x - 6 * s, 2.0 * s), stripe)
	var font := UIStyle.font_display(600)
	var avail := rect.size.x - (reserve_l + reserve_r) * s - 6.0 * s
	var nm: String = pt.view["name"]
	var x := rect.position.x + (reserve_l + 3.0) * s
	# H14 / H19 (21 Oct): the whole name on one line, centred (2026-10-16), on every card: shrunk, then
	# condensed, never wrapped and never ellipsised.
	var fit := CardTextLayout.fit_name_line(nm, avail, fs_max, fs_min, font, s)
	pt.text_squeezed(font, nm, Vector2(x, rect.position.y), avail, int(fit[0]), UIStyle.TEXT, float(fit[1]), rect.size.y - 3.0 * s)


## Cost gem centred on `c` (radius `r` px, text size `fs` px), upright on a rotated card: circle (AP),
## ringed circle (Fusion), diamond (Ritual) or hexagon (Arcane).
static func gem(pt: CardPainter, c: Vector2, r: float, fs: int) -> void:
	var ci := pt.ci
	pt.upright_begin(c)
	var kind := String(pt.view.get("cost_kind", "ap"))
	var col: Color = UIStyle.COST_COLORS.get(kind, UIStyle.COST_COLORS["ap"])
	var s := pt.s
	var band := maxf(1.4, GEM_SETTING * s)
	# H17: a faceted gem in a gilded setting, the AP gems' look. The shape still says the cost kind:
	# a round brilliant (AP: topaz, Fusion: sapphire with a ring engraved round its table), a lozenge
	# (Ritual) or a hexagon (Arcane).
	var outer: PackedVector2Array
	var girdle_n := 8
	var rot := PI / 8.0
	match kind:
		"ritual":
			outer = CardGeometry.poly(c, r * 1.24, 4, PI / 2.0)
			girdle_n = 4
			rot = PI / 2.0
		"arcane":
			outer = CardGeometry.poly(c, r * 1.1, 6, 0.0)
			girdle_n = 6
			rot = 0.0
		_:
			outer = CardGeometry.poly(c, r, 24, 0.0)
	CardJewel.drop_shadow(ci, outer, c, s)
	var inner := CardJewel.setting(ci, outer, c, band, s)
	# A dark ink gap between the metal and the stone (as in the AP sockets) so the gem reads apart.
	ci.draw_colored_polygon(inner, CardJewel.GEM_EDGE)
	var gr := c.distance_to(inner[0]) - GEM_GAP * s
	var girdle := CardGeometry.grow_pts(inner, c, -GEM_GAP * s) if girdle_n != 8 else CardGeometry.poly(c, gr, 8, rot)
	var dark_text := kind == "ap"
	var pal: Array = [ApGemRow.TOPAZ_HI, ApGemRow.TOPAZ, ApGemRow.TOPAZ_LO] if kind == "ap" else []
	CardJewel.gem(ci, girdle, c, col, GEM_TABLE_K if girdle_n == 8 else 0.58, false, not dark_text, pal)
	if kind == "fusion":
		ci.draw_arc(c, gr * 0.74, 0.0, TAU, 24, Color(col.darkened(0.6), 0.85), maxf(1.0, 0.9 * s), true)
	var txt := cost_text(pt.view)
	var tc := cost_color(pt.view)
	pt.text_c(UIStyle.font_display(700), txt, c + Vector2(0, 0.5 * s), fs, tc, 0.0 if tc == UIStyle.ON_GOLD else 1.5)
	CardJewel.sparkle(ci, c + CardJewel.LIGHT.normalized() * gr * 0.68, maxf(0.9, gr * 0.16), 0.9)
	pt.upright_end()


## Text on the cost gem: "F" (Fusion), else the current cost (Ritual Runes / Arcane total / AP);
## a Ritual / Arcane view without a current cost (summaries) shows the printed cost.
static func cost_text(view: Dictionary) -> String:
	match String(view.get("cost_kind", "ap")):
		"fusion": return "F"
		"ritual", "arcane":
			var cur = view.get("cost")
			var pc = view.get("printed_cost")
			if cur != null and view.has("uid") and int(view["uid"]) >= 0:
				return str(cur)
			return "?" if pc == null else str(pc)
	var c = view.get("cost")
	return "?" if c == null else str(c)


## Gem text colour: green / red when a cost is below / above the printed cost (Ritual / Arcane
## gems are white at their printed cost).
static func cost_color(view: Dictionary) -> Color:
	if String(view.get("cost_kind", "ap")) in ["ritual", "arcane"] and view.has("uid") and int(view["uid"]) >= 0:
		var rc = view.get("cost")
		var rp = view.get("printed_cost")
		if rc != null and rp != null and rc != rp:
			return COST_CHEAP if rc < rp else COST_DEAR
		return Color.WHITE
	if String(view.get("cost_kind", "ap")) == "ap":
		var c = view.get("cost")
		var pc = view.get("printed_cost")
		if c != null and pc != null:
			if c < pc:
				return COST_CHEAP
			if c > pc:
				return COST_DEAR
		return UIStyle.ON_GOLD
	return Color.WHITE


## Damage-type pip on the art. Reads view.type at draw time so type changes show immediately.
static func type_pip(pt: CardPainter, c: Vector2, r: float) -> void:
	# Only a real damage Type gets a pip; Spells/Traps/Powers and typeless units show none (the
	# race/type line already says "No type").
	var view := pt.view
	if not view.has("type") or view.get("type") == null or String(view.get("type")) == "":
		return
	var t = view.get("type")
	pt.upright_begin(c)
	TypeIcons.draw_pip_jewel(pt.ci, "" if t == null else str(t), c, r)
	pt.upright_end()


## Race left-aligned and damage Type right-aligned on one line `width` wide (no icon: the type pip
## on the art already shows it). Read from view.race / view.type at draw time.
static func race_type_line(pt: CardPainter, pos: Vector2, width: float, line_h: float, fs: int) -> void:
	var font := UIStyle.font_italic()
	var rv = pt.view.get("race")
	var tv = pt.view.get("type")
	var race: String = "No race" if (rv == null or str(rv) == "") else str(rv)
	var typ: String = "No type" if (tv == null or str(tv) == "") else str(tv)
	var col := UIStyle.MUTED
	var tw := minf(font.get_string_size(typ, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, width * 0.5)
	typ = CardTextLayout.ellipsize(font, typ, fs, tw + 0.5)
	var race_w := width - tw - 6.0 * pt.s
	pt.text_at(font, CardTextLayout.ellipsize(font, race, fs, race_w), pos, fs, col, race_w, HORIZONTAL_ALIGNMENT_LEFT, line_h)
	pt.text_at(font, typ, pos, fs, col, width, HORIZONTAL_ALIGNMENT_RIGHT, line_h)
