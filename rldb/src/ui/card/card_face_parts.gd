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
const PLATE_GRAIN := 0.7
const PLATE_TILE := 150.0


## Card body: kind-coloured border with a drop shadow (larger while hovered), inner gradient and a
## gold top highlight. `radius` is in base units.
static func frame(pt: CardPainter, radius: float) -> void:
	var ci := pt.ci
	var s := pt.s
	var sb := pt.sbox(BODY, pt.accent(), maxi(2, roundi(2.8 * s)), roundi(radius * s))
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = roundi((14.0 if pt.hover else 7.0) * s)
	sb.shadow_offset = pt.shadow_off(3.0 * s)
	ci.draw_style_box(sb, Rect2(Vector2.ZERO, pt.ps))
	var inset := 3.0 * s
	UiSurface.draw_round(ci, Rect2(inset, inset, pt.ps.x - 2 * inset, pt.ps.y - 2 * inset), maxf(0.0, (radius - 3.0) * s), UiSurface.PEBBLE, BODY, BODY_GRAIN, BODY_TILE * s)
	pt.vgrad(Rect2(inset, inset, pt.ps.x - 2 * inset, pt.ps.y - 2 * inset), Color(pt.accent().darkened(0.7), 0.45), Color(0, 0, 0, 0.45))
	ci.draw_line(Vector2(radius * s, 3.5 * s), Vector2(pt.ps.x - radius * s, 3.5 * s), Color(UIStyle.GOLD_HI, 0.4), maxf(1.0, s), true)


## Name plate. One line when the name fits at a legible size, otherwise two lines (split before a
## trailing "(Type)") so "Basic Mage (Water)" and "(Fire)" stay distinguishable (D9). `stripe` is
## the colour of the kind stripe along the plate's foot.
static func name_plate(pt: CardPainter, rect: Rect2, fs_max: float, reserve_l: float, reserve_r: float, stripe: Color, fs_min: float = 9.0) -> void:
	var ci := pt.ci
	var s := pt.s
	pt.round_rect(rect, PLATE, 4.0 * s, Color(UIStyle.GOLD, 0.65), maxf(1.0, s))
	UiSurface.draw_round(ci, rect.grow(-maxf(1.0, s)), 3.0 * s, UiSurface.METAL, PLATE, PLATE_GRAIN, PLATE_TILE * s, rect.position)
	ci.draw_rect(Rect2(rect.position.x + 3 * s, rect.end.y - 3.0 * s, rect.size.x - 6 * s, 2.0 * s), stripe)
	var font := UIStyle.font_display(600)
	var avail := rect.size.x - (reserve_l + reserve_r) * s - 6.0 * s
	var nm: String = pt.view["name"]
	var x := rect.position.x + (reserve_l + 3.0) * s
	var fs := CardTextLayout.fit_name(nm, avail, fs_max, fs_min, font, s)
	# Names are centred on the plate (user feedback 2026-10-16).
	if font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= avail:
		pt.text_at(font, nm, Vector2(x, rect.position.y), fs, UIStyle.TEXT, avail, HORIZONTAL_ALIGNMENT_CENTER, rect.size.y - 3.0 * s)
		return
	var parts := CardTextLayout.split_name(nm)
	var inner_h := rect.size.y - 3.0 * s
	var fs2 := mini(roundi(fs_max * s), floori(inner_h / 2.0 / 1.05))
	if parts.size() == 2 and fs2 >= 7:
		var longest := parts[0] if parts[0].length() >= parts[1].length() else parts[1]
		while fs2 > 7 and font.get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x > avail:
			fs2 -= 1
		var lh := float(fs2) * 1.05
		var y0 := rect.position.y + (inner_h - 2.0 * lh) / 2.0
		for k in 2:
			pt.text_at(font, CardTextLayout.ellipsize(font, parts[k], fs2, avail), Vector2(x, y0 + float(k) * lh), fs2, UIStyle.TEXT if k == 0 else UIStyle.MUTED, avail, HORIZONTAL_ALIGNMENT_CENTER, lh)
		return
	pt.text_at(font, CardTextLayout.ellipsize(font, nm, fs, avail), Vector2(x, rect.position.y), fs, UIStyle.TEXT, avail, HORIZONTAL_ALIGNMENT_CENTER, inner_h)


## Cost gem centred on `c` (radius `r` px, text size `fs` px), upright on a rotated card: circle (AP),
## ringed circle (Fusion), diamond (Ritual) or hexagon (Arcane).
static func gem(pt: CardPainter, c: Vector2, r: float, fs: int) -> void:
	var ci := pt.ci
	pt.upright_begin(c)
	var kind := String(pt.view.get("cost_kind", "ap"))
	var col: Color = UIStyle.COST_COLORS.get(kind, UIStyle.COST_COLORS["ap"])
	var dark := col.darkened(0.7)
	var bw := maxf(1.5, 2.0 * pt.s)
	match kind:
		"ritual":
			var rr := r * 1.22
			ci.draw_colored_polygon(CardGeometry.poly(c, rr, 4, PI / 4.0), dark)
			ci.draw_colored_polygon(CardGeometry.poly(c, rr - bw * 1.3, 4, PI / 4.0), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -(rr - bw * 1.3)), c + Vector2(rr - bw * 1.3, 0), c + Vector2(0, 0), c + Vector2(-(rr - bw * 1.3), 0)]), col.lightened(0.25))
		"arcane":
			var rh := r * 1.08
			ci.draw_colored_polygon(CardGeometry.poly(c, rh, 6, 0.0), dark)
			ci.draw_colored_polygon(CardGeometry.poly(c, rh - bw, 6, 0.0), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-(rh - bw), 0), c + Vector2(-(rh - bw) / 2.0, -(rh - bw) * 0.866), c + Vector2((rh - bw) / 2.0, -(rh - bw) * 0.866), c + Vector2(rh - bw, 0)]), col.lightened(0.25))
		"fusion":
			ci.draw_circle(c, r, dark, true, -1.0, true)
			ci.draw_circle(c, r - bw, col, true, -1.0, true)
			ci.draw_arc(c, r * 0.68, 0.0, TAU, 28, dark, maxf(1.0, 1.5 * pt.s), true)
			ci.draw_circle(c + Vector2(-r * 0.25, -r * 0.3), r * 0.28, Color(1, 1, 1, 0.25), true, -1.0, true)
		_:
			ci.draw_circle(c, r, dark, true, -1.0, true)
			ci.draw_circle(c, r - bw, col, true, -1.0, true)
			ci.draw_circle(c + Vector2(-r * 0.22, -r * 0.3), r * 0.38, Color(1, 1, 1, 0.28), true, -1.0, true)
	var txt := cost_text(pt.view)
	var tc := cost_color(pt.view)
	pt.text_c(UIStyle.font_display(700), txt, c + Vector2(0, 0.5 * pt.s), fs, tc, 0.0 if tc == UIStyle.ON_GOLD else 1.5)
	pt.upright_end()


## Text on the cost gem: "F" (Fusion), the printed cost (Ritual / Arcane) or the current AP cost.
static func cost_text(view: Dictionary) -> String:
	match String(view.get("cost_kind", "ap")):
		"fusion": return "F"
		"ritual", "arcane":
			var pc = view.get("printed_cost")
			return "?" if pc == null else str(pc)
	var c = view.get("cost")
	return "?" if c == null else str(c)


## Gem text colour: green / red when an AP cost is below / above the printed cost.
static func cost_color(view: Dictionary) -> Color:
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
	TypeIcons.draw_pip(pt.ci, "" if t == null else str(t), c, r)
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
