class_name CardLayouts
extends RefCounted
## Per-kind card-face layouts in card-face space (base units, scaled by the painter). Redesigned
## 2026-10-18 around the square card art, which is the largest thing on every card:
##
## - FIELD (85x128 "board" unit): square art across the top, the name banner over the art's
##   lower edge, big ATK / DEF badges in the bottom strip. Rules live in the sidebar and inspector.
## - FIELD Power / Trap (85x128): the same art and banner, a short rules text in the bottom strip.
## - TALL (hand 120x180, mini, big 224x336 = the hand layout scaled): square art; the ATK / DEF badges
##   sit on the art's lower corners so the rules text below the banner gets the whole width.
##
## Everywhere: cost gem on the art's top left, Type pip on its top right, statuses and Runes as
## icons over the art's lower edge (CardStatusIcons), the banner right under them.

## Corner radius (base units) of the 85x128 board kinds and of the tall kinds.
const RADIUS_SMALL := 6.0
const RADIUS_TALL := 8.0
## Rules-text well fill on the tall kinds.
const TEXT_WELL := Color(0.847, 0.8, 0.69, 0.07)

## Geometry (base units): rects are [x, y, w, h], points [x, y]; "gem_r" is the cost gem radius.
## "icons" is [x0, x1, bottom y, icon size, rows].
const FIELD := {"art": [3, 3, 79, 79], "banner": [2, 73, 81, 19], "gem": [12, 12], "gem_r": 9.0, "pip": [73, 12],
	"icons": [4, 81, 72, 14.0, 2], "atk": [1, 93, 36, 34], "def": [48, 93, 36, 34], "text": [5, 94, 75, 31],
	"f_name": 10.5, "f_name_min": 9.0, "f_gem": 12.0, "f_stat": 17.0, "f_text": 8.5}
const TALL := {"art": [4, 4, 112, 112], "banner": [2, 100, 116, 19], "gem": [16, 16], "gem_r": 11.5, "pip": [104, 16],
	"icons": [6, 114, 98, 13.0, 2], "icons_unit": [35, 85, 98, 13.0, 3], "atk": [0, 66, 36, 34], "def": [84, 67, 36, 33],
	"line": [6, 120, 108, 10], "text": [4, 131, 112, 45],
	"f_name": 12.5, "f_name_min": 8.0, "f_gem": 14.0, "f_stat": 18.0, "f_line": 9.5, "f_text": 10.0}
## Smallest rules-text size, as a fraction of the layout's text size.
const TEXT_MIN_K := 0.5


static func _is_unit(pt: CardPainter) -> bool:
	return String(pt.view.get("category", "")) in CardWidget.UNIT_CATS


static func _r(pt: CardPainter, a: Array) -> Rect2:
	return pt.r(a[0], a[1], a[2], a[3])


## Compact 85x128 field unit: art, banner, ATK / DEF.
static func draw_square(pt: CardPainter) -> void:
	var g := FIELD
	CardFaceParts.frame(pt, RADIUS_SMALL)
	CardArt.draw(pt, _r(pt, g["art"]))
	_art_corners(pt, g)
	_icons(pt, g["icons"], 0.0)
	# H14: the full name on one line, shrunk then condensed to fit (never ellipsised).
	CardFaceParts.name_plate(pt, _r(pt, g["banner"]), g["f_name"], 0.0, 0.0, pt.accent(), g["f_name_min"], true)
	if _is_unit(pt):
		CardStatBadge.draw(pt, _r(pt, g["atk"]), true, g["f_stat"])
		CardStatBadge.draw(pt, _r(pt, g["def"]), false, g["f_stat"])
	CardFaceParts.gem(pt, pt.p(g["gem"][0], g["gem"][1]), float(g["gem_r"]) * pt.s, pt.fs(g["f_gem"]))


## Field Power / Trap (85x128): art, banner, short rules text.
static func draw_power(pt: CardPainter) -> void:
	var g := FIELD
	CardFaceParts.frame(pt, RADIUS_SMALL)
	CardArt.draw(pt, _r(pt, g["art"]))
	_icons(pt, g["icons"], 0.0)
	CardFaceParts.name_plate(pt, _r(pt, g["banner"]), g["f_name"], 0.0, 0.0, pt.accent(), g["f_name_min"], true)
	var txt := CardText.card_text(pt.view)
	if txt != "":
		var t: Array = g["text"]
		var tp := CardTextLayout.fit_para(txt, UIStyle.font_body(), pt.fs(g["f_text"]), maxi(CardPainter.MIN_FS - 1, pt.fs(g["f_text"] * 0.7)), float(t[2]) * pt.s, float(t[3]) * pt.s)
		pt.para_text(tp, pt.p(t[0], t[1]), Color(UIStyle.TEXT, 0.9), CardTextLayout.shown_text(tp, txt))
	CardFaceParts.gem(pt, pt.p(g["gem"][0], g["gem"][1]), float(g["gem_r"]) * pt.s, pt.fs(g["f_gem"]))


## Tall card (hand / mini 120x180 base, big 224x336 drawn from the same layout at a larger scale):
## art with the ATK / DEF badges on its lower corners, banner, race / Type line, rules text well.
static func draw_tall(pt: CardPainter, _big: bool = false) -> void:
	var g := TALL
	var s := pt.s
	var is_unit := _is_unit(pt)
	CardFaceParts.frame(pt, RADIUS_TALL)
	CardArt.draw(pt, _r(pt, g["art"]))
	_art_corners(pt, g)
	_icons(pt, g["icons_unit"] if is_unit else g["icons"], 0.5)
	# Race / Type line (units) or the card kind (Spells, Traps, Powers).
	var ln: Array = g["line"]
	var line_fs := pt.fs(g["f_line"])
	if is_unit:
		CardFaceParts.race_type_line(pt, pt.p(ln[0], ln[1]), float(ln[2]) * s, float(ln[3]) * s, line_fs)
	else:
		# H21: the kind (Spell, Trap, Power) sits on the left, where a unit shows its race.
		pt.text_at(UIStyle.font_italic(), UIStyle.CATEGORY_NAMES.get(pt.view.get("category", ""), ""), pt.p(ln[0], ln[1]), line_fs, UIStyle.MUTED, float(ln[2]) * s, HORIZONTAL_ALIGNMENT_LEFT, float(ln[3]) * s)
	# Rules text well: the whole text always fits, the size steps down until it does (user feedback).
	var t: Array = g["text"]
	var rules := CardText.card_text(pt.view)
	if pt.view.get("support", "full") == "unimplemented":
		rules = "[Effect not implemented] " + rules
	pt.round_rect(_r(pt, t), TEXT_WELL, 3.0 * s)
	if rules != "":
		var tp := CardTextLayout.fit_para(rules, UIStyle.font_body(), pt.fs(g["f_text"]), maxi(5, pt.fs(g["f_text"] * TEXT_MIN_K)), (float(t[2]) - 6.0) * s, (float(t[3]) - 3.0) * s)
		pt.para_text(tp, pt.p(float(t[0]) + 3.0, float(t[1]) + 1.5), UIStyle.TEXT, CardTextLayout.shown_text(tp, rules))
	else:
		# No rules (Basic Units, #75): a small engraved filigree with a diamond, never a lone glyph that
		# reads as a missing asset.
		var wr := _r(pt, t)
		flourish(pt.ci, wr.get_center(), minf(wr.size.x * 0.62, 72.0 * s), s, FLOURISH)
	CardFaceParts.name_plate(pt, _r(pt, g["banner"]), g["f_name"], 0.0, 0.0, pt.accent(), g["f_name_min"])
	if is_unit:
		CardStatBadge.draw(pt, _r(pt, g["atk"]), true, g["f_stat"])
		CardStatBadge.draw(pt, _r(pt, g["def"]), false, g["f_stat"])
	CardFaceParts.gem(pt, pt.p(g["gem"][0], g["gem"][1]), float(g["gem_r"]) * s, pt.fs(g["f_gem"]))


## The Type pip on the art's top right (same size as the cost gem, user feedback).
static func _art_corners(pt: CardPainter, g: Dictionary) -> void:
	CardFaceParts.type_pip(pt, pt.p(g["pip"][0], g["pip"][1]), float(g["gem_r"]) / TypeIcons.PIP_K * pt.s)


static func _icons(pt: CardPainter, a: Array, align: float) -> void:
	CardStatusIcons.draw_rows(pt, a[0], a[1], a[2], a[3], a[4], align)


## Name plate across the middle of an own face-down set card, in screen orientation (widget space).
## The back stays identical for every kind: no kind-coloured stripe on the plate (bronze).
static func draw_set_name(pt: CardPainter) -> void:
	var s := pt.s
	var h := 22.0 * s
	CardFaceParts.name_plate(pt, Rect2(pt.cr.position.x + 5.0 * s, pt.cr.get_center().y - h / 2.0, pt.cr.size.x - 10.0 * s, h),
		FIELD["f_name"], 0.0, 0.0, UIStyle.CATEGORY_COLORS.get("", UIStyle.BRONZE), FIELD["f_name_min"])


## #75: the vanilla card's filigree (bronze 40%).
const FLOURISH := Color(0.478, 0.353, 0.188, 0.4)
## Inlaid empty zone (#22): a darker recess under a thin share of the zone tint, the inner shadow's
## depth and alpha, the dark rim and the gold lip on the lit bottom / right edges.
const ZONE_RECESS_A := 0.16
const ZONE_FILL_A := 0.3
const ZONE_SHADOW_PX := 7.0
const ZONE_SHADOW_A := 0.42
const ZONE_RIM := Color(0, 0, 0, 0.42)
const ZONE_LIP := Color(0.831, 0.651, 0.29, 0.1)
## D10 follow-up: the engraved zone mark: its face alpha, the dark cut above it, the lit edge below it
## and its size as a share of the zone's short side (was a flat 0.17 white at 0.25).
const MARK_A := 0.09
const MARK_CUT_A := 0.2
const MARK_LIT := Color(0.94, 0.81, 0.48, 0.07)
const MARK_K := 0.2
## Zone pick (#28): the target fill, the inner glow (px, alpha at rest / hovered).
const PICK_FILL_A := 0.08
const PICK_GLOW_PX := 12.0
const PICK_GLOW_A := 0.34
const PICK_GLOW_HOVER_A := 0.62
## A mote rising over the hovered zone pick: its loop (s) and rise (share of the zone height).
const MOTE_PERIOD := 1.6
const MOTE_RISE := 0.55


## Empty zone (#22): an inlaid recess in the table rather than a flat panel laid over it. A thin share of
## the zone tint over a darker recess, an inner shadow falling from the rim (heavier at the top: the
## light is above), a dark rim and a faint gold lip catching the light on the bottom and right edges.
## The kind mark (sword / eye / crown) is engraved (D10). `highlighted` = a zone pick (#28): a light
## target fill, a breathing inner glow and a gold border; the zone under the pointer (`pt.hover`)
## lifts its glow to PICK_GLOW_HOVER_A and sends a mote up.
static func draw_empty(pt: CardPainter, size: Vector2, highlighted: bool) -> void:
	var s := pt.s
	var role := "unit"
	match pt.size_kind:
		"trap": role = "trap"
		"power": role = "power"
	var tint: Color = UIStyle.ZONE_TINT[role]
	var r := Rect2(Vector2.ZERO, size)
	var rad := 8.0 * s
	pt.round_rect(r, Color(0, 0, 0, ZONE_RECESS_A), rad)
	pt.round_rect(r, Color(tint, ZONE_FILL_A), rad)
	inner_shadow(pt.ci, r, rad, ZONE_SHADOW_PX * s, ZONE_SHADOW_A)
	pt.ring(ZONE_RIM, 1.0, r, rad)
	_lip(pt.ci, r, rad, ZONE_LIP)
	if highlighted:
		var k := UIStyle.breathe(float(Time.get_ticks_msec()) / 1000.0, 0.12)
		var ga := (PICK_GLOW_HOVER_A if pt.hover else PICK_GLOW_A) * k
		pt.round_rect(r, Color(UIStyle.TARGET, PICK_FILL_A), rad)
		inner_shadow(pt.ci, r, rad, PICK_GLOW_PX, minf(1.0, ga), UIStyle.TARGET)
		pt.ring(UIStyle.GOLD_HI if pt.hover else UIStyle.GOLD, 2.0, r, rad)
		if pt.hover and not UIStyle.reduce_motion:
			var ph := fmod(float(Time.get_ticks_msec()) / 1000.0 / MOTE_PERIOD, 1.0)
			var mp := Vector2(r.get_center().x + sin(ph * TAU) * 4.0 * s, r.end.y - 10.0 * s - ph * r.size.y * MOTE_RISE)
			var ma := sin(ph * PI)
			pt.ci.draw_circle(mp, 5.0 * s, Color(UIStyle.GOLD_HI, 0.18 * ma), true, -1.0, true)
			pt.ci.draw_circle(mp, 2.0 * s, Color(1.0, 0.95, 0.8, 0.85 * ma), true, -1.0, true)
	engraved_mark(pt.ci, {"unit": "sword", "trap": "eye", "power": "crown"}[role], r.get_center(), minf(size.x, size.y) * MARK_K,
		1.6 if highlighted else 1.0)
	# Zones never show a text label ("Front 1", "Trap / Spell 2", ...) — user feedback 2026-10-16.


## D10: a kind mark engraved into the table: a dark cut 1 px above, a lit edge 1 px below and a faint
## warm face (MARK_A). `k` scales every alpha (a zone pick shows it a little more).
static func engraved_mark(ci: CanvasItem, kind: String, c: Vector2, r: float, k: float = 1.0) -> void:
	CardArt.draw_glyph(ci, kind, c + Vector2(0, -1.0), r, Color(0, 0, 0, MARK_CUT_A * k))
	CardArt.draw_glyph(ci, kind, c + Vector2(0, 1.0), r, Color(MARK_LIT, MARK_LIT.a * k))
	CardArt.draw_glyph(ci, kind, c, r, Color(1.0, 0.93, 0.8, MARK_A * k))


## Inner shadow (or inner glow in `col`) `px` deep inside the rounded rect `r`: concentric 1 px rings
## fading inwards, each a little lower than the last so the top edge carries more of it.
static func inner_shadow(ci: CanvasItem, r: Rect2, rad: float, px: float, a: float, col: Color = Color.BLACK) -> void:
	var n := maxi(2, ceili(px))
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(1)
	sb.anti_aliasing = true
	for i in n:
		var t := float(i) / float(n)
		var rr := Rect2(r.position + Vector2(i, i * 1.25), r.size - Vector2(2.0 * i, i * 1.5))
		if rr.size.x < 4.0 or rr.size.y < 4.0:
			break
		sb.border_color = Color(col, a * (1.0 - t) * (1.0 - t))
		sb.set_corner_radius_all(maxi(1, roundi(rad - i * 0.5)))
		ci.draw_style_box(sb, rr)


## The faint gold lip on the bottom and right edges of a recess (straight runs between the corners).
static func _lip(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
	ci.draw_line(Vector2(r.position.x + rad, r.end.y - 0.5), Vector2(r.end.x - rad, r.end.y - 0.5), col, 1.0, true)
	ci.draw_line(Vector2(r.end.x - 0.5, r.position.y + rad), Vector2(r.end.x - 0.5, r.end.y - rad), col, 1.0, true)


## #75: a horizontal filigree `w` wide centred on `c`: two tapering rules from a centre diamond, a small
## scroll curling up at each end and a dot beyond it. `s` is the card scale.
static func flourish(ci: CanvasItem, c: Vector2, w: float, s: float, col: Color) -> void:
	var half := w / 2.0
	var gap := 6.0 * s
	var lw := maxf(1.0, 0.9 * s)
	for dir in [-1.0, 1.0]:
		var a := c + Vector2(dir * gap, 0)
		var b := c + Vector2(dir * (half - 5.0 * s), 0)
		ci.draw_polyline_colors(PackedVector2Array([a, b]), PackedColorArray([col, Color(col, col.a * 0.35)]), lw, true)
		var sc := b + Vector2(0, -2.2 * s)
		ci.draw_arc(sc, 2.2 * s, PI / 2.0 - dir * PI * 1.1, PI / 2.0, 10, Color(col, col.a * 0.8), lw, true)
		ci.draw_circle(c + Vector2(dir * half, 0), 0.9 * s, Color(col, col.a * 0.7), true, -1.0, true)
	var d := 3.6 * s
	var dia := PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)])
	ci.draw_colored_polygon(dia, Color(col, col.a * 0.55))
	dia.append(dia[0])
	ci.draw_polyline(dia, col, lw, true)
